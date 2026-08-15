`default_nettype none
//
// The NVC's processor: a V810 executing the integer instruction set, one
// instruction at a time over the halfword bus in mem_bus.
//
// This is the ~40 MHz rebuild of the 133 MHz multicycle machine: same
// architecture, same cost ledger, a walk short enough to live two clocks
// per architectural cycle. MiSTer's NECv810 proves the domain (one
// ~40 MHz clock, a 20 MHz enable, the whole machine against it); this
// reimplements the pattern, not the code, and far smaller.
//
// Two notions of time live here, as before. The state machine walks on
// `clk` -- a fetch is request one clock, answer the next, consumed live --
// while `ce` ticks architectural 20 MHz cycles (cpu_clock_enable). Each
// instruction charges a budget of architectural cycles into `owed` when it
// executes, owed drains one per tick, and the next execute is barred until
// it empties; the fetch walks ahead during the drain. The charge is
// max(documented base cycles, fetch halfwords x (1 + region wait)) plus a
// region wait per data access -- base counts assume a zero-wait bus [V810
// manual Table 5-11], so the wait controller's cycles stack on top, and
// uncached execution from two-wait cartridge ROM correctly costs three
// cycles per halfword. Load bases follow the scroll's context rules (5
// alone, 4 after a load, 1 after multiply/divide -- the "long instruction"
// set is beetle-vb's lastop choice); stores cost 1 for the first two
// consecutive, then 4. Exception entry charges nothing (unknown;
// beetle-vb agrees), and the icache that would bypass fetch costs is
// still TODO.
//
// The ledger is exact only while every walk fits inside its charge's
// drain, and ticks now come as close as adjacent clocks (625/1248, twice
// per window), so the walk margins are load-bearing: the longest walk
// between executes is five clocks (a word load) against a six-tick
// minimum drain, and the tight pairs -- a 16-bit instruction's two-clock
// walk against a two-tick charge, a 32-bit's three against two -- clear
// because the drain's zeroing tick and the next tick are never adjacent
// twice in a row. Anything that lengthens a walk (a registered bus
// command, a predecode stage) re-breaks this; the 133 MHz retiming went
// away for exactly that reason, and 25 ns closes the naked paths.
//
// Semantics follow the Sacred Tech Scroll's CPU chapters; where it and the
// V810 architecture manual disagree we follow the scroll and say so. The
// unimplemented groups -- floating point, bit strings, CAXI, the four
// extended instructions -- raise the illegal-opcode exception as a
// stand-in, which is deterministic and visible where silence would look
// like a hang. Interrupts are checked between instructions only [Scroll,
// CPU > List of Exceptions]; the manual's claim that DIV is abortable
// mid-flight is recorded in TODO, not implemented.
//
// Reset state is the documented three registers: PC 0xFFFFFFF0, PSW with
// only NP set, ECR 0x0000FFF0. Every other register stays undefined on
// purpose -- initializing them would hide ROMs that depend on garbage.
//

module cpu (
    input  wire logic        clk,
    // One architectural 20 MHz cycle per assertion; a tick, never a gate.
    input  wire logic        ce,
    input  wire logic        reset_n,

    // mem_bus master side. One access per req cycle, the answer on rdata
    // the following clock, holding between accesses. Address bit 0 never
    // leaves the CPU, and a word access is two halfword cycles, so both
    // unaligned rules are structural here.
    output logic             req,
    output logic [26:1]      addr,
    output logic             we,
    output logic [1:0]       be,
    output logic [15:0]      wdata,
    input  wire logic [15:0] rdata,

    // Interrupt request: level held while asserted.
    input  wire logic        irq_valid,
    input  wire logic [3:0]  irq_level,

    // Host-side observation only, for core_top's on-screen display.
    output logic [31:0]      dbg_pc,
    output logic             dbg_halted
);

    // ------------------------------------------------------------------
    // Architectural state
    // ------------------------------------------------------------------

    // r1-r31; r0 is absent and forced to zero on read. Deliberately not
    // reset [Scroll, System Reset: r1-r31 undefined].
    logic [31:0] gpr [1:31];

    logic [31:0] pc;

    // PSW, held as fields. Packed layout: bits 19-16 I, 15 NP, 14 EP,
    // 13 AE, 12 ID, 9-4 the floating-point flags, 3 CY, 2 OV, 1 S, 0 Z.
    logic [3:0]  psw_i;
    logic        psw_np, psw_ep, psw_ae, psw_id;
    logic [5:0]  psw_fp;   // FRO..FPR: storable and readable, unused here
    logic        psw_cy, psw_ov, psw_s, psw_z;

    // System registers. ECR is the only one reset defines; the rest stay
    // undefined like the program registers.
    logic [31:0] eipc, eipsw, fepc, fepsw, ecr, adtre, sr29, sr31;
    logic        chcw_ice;

    // The wait controller, living with the CPU's bus timing because this
    // is its only consumer (TODO section 2). One bit per slow region,
    // clear meaning two waits; both clear at reset. Written at 0x02000024
    // and read back as WCR | 0xFC [beetle-vb libretro.cpp], intercepted
    // here since the register is the CPU's own.
    logic        wcr_rom1w, wcr_exp1w;

    localparam logic [31:0] PIR_VALUE  = 32'h0000_5346;
    localparam logic [31:0] TKCW_VALUE = 32'h0000_00E0;
    localparam logic [31:0] SR30_VALUE = 32'h0000_0004;

    // PSW bits that exist; every PSW image is masked with this on the way
    // in [matching the manual's RFU rules; beetle-vb SetSREG agrees].
    localparam logic [31:0] PSW_MASK = 32'h000F_F3FF;

    // ------------------------------------------------------------------
    // Instruction machinery
    // ------------------------------------------------------------------

    typedef enum logic [3:0] {
        RESET1,      // one clock so the first fetch is a full req pulse
        FETCH1,      // request the first halfword; the interrupt check
        FETCH_END,   // 16-bit: hold for the drain, then execute off rdata.
                     // 32-bit: capture the low half and request the second
        EXEC2,       // 32-bit: hold for the drain, then execute
        MEM_LO,      // data access, low halfword (the only one for B/H)
        MEM_HI,      // word access, high halfword; word loads capture low
        MEM_CAP,     // load writeback off the last answer
        MUL_DONE,    // write high word to r30, low to reg2, set flags
        DIV_RUN,     // one quotient bit per clock
        DIV_DONE,    // negate, write remainder then quotient, set flags
        EXC_ENTER,   // the scroll's exception handling algorithm, one clock
        FATAL_WR,    // fatal exception: three words to 0x0/0x4/0x8
        HALTED,      // halt until an interrupt is accepted
        DEAD         // fatal: stopped until reset
    } state_t;

    state_t state;

    // Architectural cycles still owed by retired work: charged at execute
    // (fetch, base and data waits all at once), drained one per tick. The
    // next execute is barred until it empties, which is what makes every
    // span exactly its charge.
    logic [7:0] owed;

    // Timing context the scroll's load/store rules depend on.
    logic       prev_load, prev_muldiv;
    logic [1:0] store_streak;

    // Multiplier: operands registered at execute, the 33x33 signed
    // product consumed combinationally one clock later; the DSP path
    // closes 25 ns with ease.
    logic [32:0] mul_a, mul_b;
    logic        mul_signed;
    wire logic [65:0] prod_w = $signed(mul_a) * $signed(mul_b);

    // The low halfword of a 32-bit instruction, captured at FETCH_END; a
    // 16-bit instruction executes straight off rdata and never lands here.
    logic [15:0] ir_lo_q;

    // Memory access bookkeeping, latched at execute.
    typedef enum logic [1:0] { SIZE_B, SIZE_H, SIZE_W } msize_t;
    msize_t      mem_size;
    logic        mem_zext;       // IN.x zero-extends where LD.x sign-extends
    logic        mem_store;
    logic [31:0] mem_ea;         // aligned per size; bit 0 kept for the lane
    logic [26:1] mem_ea_p2;      // the word access's high halfword address
    logic [31:0] mem_data;       // store data, then low load halfword
    logic [4:0]  dest_q;         // writeback register for loads and divides
    logic        mem_wcr;        // this load reads the CPU's own WCR back

    // Divide bookkeeping.
    logic [31:0] div_work, div_divisor, div_rem;
    logic [4:0]  div_cnt;
    logic        div_neg_quot, div_neg_rem;

    // Exception bookkeeping, latched at the raise site.
    logic [15:0] exc_code;
    logic [31:0] exc_handler, exc_restore;
    logic        exc_is_irq;
    logic [3:0]  exc_level;
    logic [2:0]  fatal_idx;

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    // The first halfword alone says whether a second follows: every format
    // with top bits 101 and up is 32 bits [Scroll, CPU > Instruction
    // Formats]. Bcond's 100 is the only 3-bit opcode and is 16 bits.
    function automatic logic is_32bit(input logic [15:0] first_half);
        return first_half[15] && (first_half[14] || first_half[13]);
    endfunction

    // Every function here is pure -- state comes in through arguments --
    // because Quartus 21.1 silently drops module-scope reads made inside
    // automatic functions.

    // The sixteen condition codes shared by Bcond and SETF: bit 3 inverts
    // the condition selected by bits 2-0 [Scroll, CPU > Condition Numbers].
    function automatic logic cond_true(input logic [3:0] cond,
                                       input logic cy, input logic ov,
                                       input logic s, input logic z);
        logic base;
        case (cond[2:0])
            3'd0: base = ov;
            3'd1: base = cy;
            3'd2: base = z;
            3'd3: base = cy | z;
            3'd4: base = s;
            3'd5: base = 1'b1;
            3'd6: base = s ^ ov;
            3'd7: base = (s ^ ov) | z;
        endcase
        return cond[3] ? ~base : base;
    endfunction

    // Format IV displacement: disp26 rides its high bits in the first
    // halfword and its low bits in the second; bit 0 masked like every jump.
    function automatic logic [31:0] jump_disp(input logic [15:0] lo,
                                              input logic [15:0] hi);
        return {{6{lo[9]}}, lo[9:0], hi[15:1], 1'b0};
    endfunction

    function automatic logic [31:0] extend_byte(input logic [7:0] value,
                                                input logic zext);
        return zext ? {24'd0, value} : {{24{value[7]}}, value};
    endfunction

    // Wait states per bus access, by region [Development Manual Table
    // 4-4-3]: two for cartridge ROM and expansion until WCR's bit drops
    // them to one, one for everything else. VIP's real handshake is
    // variable (2-5); its documented minimum stands in until the VIP does.
    function automatic logic [1:0] region_wait(input logic [2:0] region,
                                               input logic rom1w,
                                               input logic exp1w);
        case (region)
            3'd0:    return 2'd2;
            3'd4:    return exp1w ? 2'd1 : 2'd2;
            3'd7:    return rom1w ? 2'd1 : 2'd2;
            default: return 2'd1;
        endcase
    endfunction

    // Register writes go through the one write port: the request is
    // registered here and committed by the block below on the next clock,
    // always before the next instruction's operand read. r0 discards at
    // the commit. An instruction writes at most one named destination plus
    // r30; the named port wins when they collide, which is the documented
    // "r30 first, destination second" ordering.
    logic        wb_en;
    logic [4:0]  wb_addr;
    logic [31:0] wb_data;
    logic        wb30_en;
    logic [31:0] wb30_data;

    task automatic gpr_write(input logic [4:0] index, input logic [31:0] value);
        wb_en   <= 1'b1;
        wb_addr <= index;
        wb_data <= value;
    endtask

    task automatic gpr_write_r30(input logic [31:0] value);
        wb30_en   <= 1'b1;
        wb30_data <= value;
    endtask

    // Bitwise results: Z and S computed, OV cleared, CY untouched. ANDI's
    // "clears S" documents the same outcome: its result is never negative.
    task automatic set_logic_flags(input logic [31:0] value);
        psw_ov <= 1'b0;
        psw_s  <= value[31];
        psw_z  <= value == 32'd0;
    endtask

    task automatic psw_unpack(input logic [31:0] value);
        psw_i  <= value[19:16];
        psw_np <= value[15];
        psw_ep <= value[14];
        psw_ae <= value[13];
        psw_id <= value[12];
        psw_fp <= value[9:4];
        psw_cy <= value[3];
        psw_ov <= value[2];
        psw_s  <= value[1];
        psw_z  <= value[0];
    endtask

    // LDSR: ECR, PIR, TKCW and register 30 ignore writes, reserved indexes
    // ignore them too [Scroll, CPU > CPU Control]. CHCW keeps only ICE; the
    // clear/dump/restore commands are ignored until the cache feature lands.
    task automatic ldsr(input logic [4:0] index, input logic [31:0] value);
        case (index)
            5'd0:  eipc  <= {value[31:1], 1'b0};
            5'd1:  eipsw <= value & PSW_MASK;
            5'd2:  fepc  <= {value[31:1], 1'b0};
            5'd3:  fepsw <= value & PSW_MASK;
            5'd5:  psw_unpack(value & PSW_MASK);
            5'd24: chcw_ice <= value[1];
            5'd25: adtre <= {value[31:1], 1'b0};
            5'd29: sr29  <= value;
            5'd31: sr31  <= value;
            default: ;
        endcase
    endtask

    // Raise an exception: code and handler chosen at the raise site,
    // restore PC per the exception's documented row.
    task automatic raise(input logic [15:0] code, input logic [31:0] handler,
                         input logic [31:0] restore);
        exc_code    <= code;
        exc_handler <= handler;
        exc_restore <= restore;
        exc_is_irq  <= 1'b0;
        state       <= EXC_ENTER;
    endtask

    // The packed PSW image; psw_unpack is its inverse.
    wire logic [31:0] psw_now = {12'b0, psw_i, psw_np, psw_ep, psw_ae, psw_id,
                                 2'b00, psw_fp, psw_cy, psw_ov, psw_s, psw_z};

    // Interrupts are masked by ID, by either pending flag, and by level
    // (accepted when the level is at least PSW.I), and only ever checked
    // between instructions [Scroll, CPU > Interrupt Handling].
    wire logic irq_ok = irq_valid && !psw_id && !psw_ep && !psw_np
                        && irq_level >= psw_i;

    // The instruction's first halfword: live off the bus for a 16-bit
    // execute, the captured copy once a 32-bit one moved on to EXEC2.
    wire logic [15:0] ir1      = state == FETCH_END ? rdata : ir_lo_q;
    wire logic [5:0]  opcode   = ir1[15:10];
    wire logic [4:0]  reg2_num = ir1[9:5];

    // The execute barrier: both fetch shapes end here, and fire on the
    // first clock after the previous instruction's budget drains.
    wire logic exec_fire = ((state == FETCH_END && !is_32bit(rdata))
                            || state == EXEC2)
                           && owed == 8'd0;

    // ------------------------------------------------------------------
    // Bus outputs
    // ------------------------------------------------------------------

    // req is a one-clock pulse per requesting state, so every device sees
    // each access exactly once. The companions are plain functions of
    // state; only req qualifies them. FETCH_END and EXEC2 hold for the
    // drain without requesting, and rdata holds their answer meanwhile.
    wire logic req_c = state == FETCH1    ? !irq_ok
                     : state == FETCH_END ? is_32bit(rdata)
                     : state == MEM_LO || state == MEM_HI
                       || state == FATAL_WR;

    assign req = reset_n && req_c;

    assign addr = state == FETCH_END ? pc[26:1] + 26'd1
                : state == MEM_LO    ? mem_ea[26:1]
                : state == MEM_HI    ? mem_ea_p2
                : state == FATAL_WR  ? {23'd0, fatal_idx}
                : pc[26:1];

    assign we = ((state == MEM_LO || state == MEM_HI) && mem_store)
                || state == FATAL_WR;

    assign be = state == MEM_LO && mem_size == SIZE_B
              ? (mem_ea[0] ? 2'b10 : 2'b01)
              : 2'b11;

    // Cause word, PSW, then PC, two halfwords each, for the fatal stores.
    wire logic [15:0] fatal_wdata =
          fatal_idx == 3'd0 ? exc_code
        : fatal_idx == 3'd1 ? 16'hFFFF
        : fatal_idx == 3'd2 ? psw_now[15:0]
        : fatal_idx == 3'd3 ? psw_now[31:16]
        : fatal_idx == 3'd4 ? exc_restore[15:0]
        : exc_restore[31:16];

    assign wdata = state == MEM_HI   ? mem_data[31:16]
                 : state == FATAL_WR ? fatal_wdata
                 : mem_size == SIZE_B && state == MEM_LO
                 ? {mem_data[7:0], mem_data[7:0]}
                 : mem_data[15:0];

    assign dbg_pc     = pc;
    assign dbg_halted = state == HALTED || state == DEAD;

    // ------------------------------------------------------------------
    // The register file's one write site
    // ------------------------------------------------------------------

    always_ff @(posedge clk) begin : gpr_commit
        if (wb30_en) gpr[5'd30] <= wb30_data;
        if (wb_en && wb_addr != 5'd0) gpr[wb_addr] <= wb_data;
    end

    // ------------------------------------------------------------------
    // The machine
    // ------------------------------------------------------------------

    always_ff @(posedge clk or negedge reset_n) begin : machine
        // Execute scratch: blocking-assigned before use, never read
        // across cycles.
        logic [31:0] r1v, r2v, left, op_b, res, ea_raw, ea, pcn;
        logic [32:0] sum;
        logic [63:0] prod;
        logic [33:0] trial;
        logic [32:0] div_shift;
        logic        is32, bcond_taken;
        logic [4:0]  shn;
        logic [1:0]  fw, dwait;
        logic [2:0]  per, datac;
        logic [3:0]  fcost;
        logic [7:0]  base;
        logic [7:0]  charge;

        charge = 8'd0;

        if (!reset_n) begin
            pc     <= 32'hFFFF_FFF0;
            psw_i  <= 4'd0;
            psw_np <= 1'b1;                 // PSW 0x00008000: only NP
            psw_ep <= 1'b0;
            psw_ae <= 1'b0;
            psw_id <= 1'b0;
            psw_fp <= 6'd0;
            psw_cy <= 1'b0;
            psw_ov <= 1'b0;
            psw_s  <= 1'b0;
            psw_z  <= 1'b0;
            ecr    <= 32'h0000_FFF0;
            state  <= RESET1;
            owed         <= 8'd0;
            prev_load    <= 1'b0;
            prev_muldiv  <= 1'b0;
            store_streak <= 2'd0;
            wcr_rom1w    <= 1'b0;   // slow at reset, both regions
            wcr_exp1w    <= 1'b0;
        end else begin
            // A write request lives exactly one clock.
            wb_en   <= 1'b0;
            wb30_en <= 1'b0;

            begin
                case (state)

                    // Reset can release mid-cycle; starting a clock late
                    // keeps the first fetch's req a clean full pulse.
                    RESET1: state <= FETCH1;

                    FETCH1: begin
                        if (irq_ok) begin
                            // Restore PC is the next instruction: the
                            // previous one completed and pc points past it.
                            exc_code    <= {8'hFE, irq_level, 4'b0000};
                            exc_handler <= {24'hFFFFFE, irq_level, 4'b0000};
                            exc_restore <= pc;
                            exc_is_irq  <= 1'b1;
                            exc_level   <= irq_level;
                            state       <= EXC_ENTER;
                        end else begin
                            state <= FETCH_END;
                        end
                    end

                    // A 32-bit instruction captures its low half and
                    // requests the second; a 16-bit one holds here for the
                    // barrier and executes below. rdata holds between
                    // accesses, so the hold costs nothing but time.
                    FETCH_END:
                        if (is_32bit(rdata)) begin
                            ir_lo_q <= rdata;
                            state   <= EXEC2;
                        end

                    EXEC2: ;   // the barrier below owns this state

                    MEM_LO: begin
                        if (mem_store && mem_ea[26:24] == 3'd2
                            && mem_ea[7:0] == 8'h24) begin
                            wcr_rom1w <= mem_data[0];
                            wcr_exp1w <= mem_data[1];
                        end
                        state <= mem_size == SIZE_W ? MEM_HI
                               : mem_store ? FETCH1 : MEM_CAP;
                    end

                    MEM_HI: begin
                        // A word load's low answer lands here while the
                        // high request goes out, keeping the two accesses
                        // back-to-back on the bus.
                        if (!mem_store)
                            mem_data[15:0] <= mem_wcr
                                ? {8'd0, 6'b111111, wcr_exp1w, wcr_rom1w}
                                : rdata;
                        state <= mem_store ? FETCH1 : MEM_CAP;
                    end

                    MEM_CAP: begin
                        // The WCR intercept: 0xFC | the two bits, high
                        // byte 0 [beetle-vb libretro.cpp HWCTRL_Read].
                        left = mem_wcr
                             ? {24'd0, 6'b111111, wcr_exp1w, wcr_rom1w}
                             : {16'd0, rdata};
                        case (mem_size)
                            SIZE_B: gpr_write(dest_q, extend_byte(
                                        mem_ea[0] && !mem_wcr ? left[15:8]
                                                              : left[7:0],
                                        mem_zext));
                            SIZE_H: gpr_write(dest_q, mem_zext
                                        ? {16'd0, left[15:0]}
                                        : {{16{left[15]}}, left[15:0]});
                            default: gpr_write(dest_q,
                                        {mem_wcr ? 16'd0 : rdata,
                                         mem_data[15:0]});
                        endcase
                        state <= FETCH1;
                    end

                    MUL_DONE: begin
                        // High word to r30 before the low word to reg2, so
                        // reg2 == r30 keeps the low word; Z and S consider
                        // only the low word.
                        prod = prod_w[63:0];
                        gpr_write_r30(prod[63:32]);
                        gpr_write(dest_q, prod[31:0]);
                        psw_ov <= mul_signed
                                ? prod[63:32] != {32{prod[31]}}
                                : prod[63:32] != 32'd0;
                        psw_s  <= prod[31];
                        psw_z  <= prod[31:0] == 32'd0;
                        state  <= FETCH1;
                    end

                    DIV_RUN: begin
                        div_shift = {div_rem, div_work[31]};
                        trial     = {1'b0, div_shift} - {2'b00, div_divisor};
                        div_rem   <= trial[33] ? div_shift[31:0] : trial[31:0];
                        div_work  <= {div_work[30:0], ~trial[33]};
                        div_cnt   <= div_cnt - 5'd1;
                        if (div_cnt == 5'd0) state <= DIV_DONE;
                    end

                    DIV_DONE: begin
                        // Remainder to r30 before the quotient to reg2, the
                        // same ordering rule as multiply. Quotient rounds
                        // toward zero; the remainder takes the dividend's
                        // sign.
                        res = div_neg_quot ? -div_work : div_work;
                        gpr_write_r30(div_neg_rem ? -div_rem : div_rem);
                        gpr_write(dest_q, res);
                        psw_ov <= 1'b0;
                        psw_s  <= res[31];
                        psw_z  <= res == 32'd0;
                        state  <= FETCH1;
                    end

                    EXC_ENTER: begin
                        // The scroll's exception handling algorithm, in
                        // order: NP pending makes it fatal, EP pending
                        // duplexes it, otherwise the regular entry -- and
                        // only an interrupt touches the level field.
                        if (psw_np) begin
                            fatal_idx <= 3'd0;
                            state     <= FATAL_WR;
                        end else if (psw_ep) begin
                            fepc       <= {exc_restore[31:1], 1'b0};
                            fepsw      <= psw_now & PSW_MASK;
                            ecr[31:16] <= exc_code;
                            psw_np     <= 1'b1;
                            psw_id     <= 1'b1;
                            psw_ae     <= 1'b0;
                            pc         <= 32'hFFFF_FFD0;
                            state      <= FETCH1;
                        end else begin
                            eipc      <= {exc_restore[31:1], 1'b0};
                            eipsw     <= psw_now & PSW_MASK;
                            ecr[15:0] <= exc_code;
                            psw_ep    <= 1'b1;
                            psw_id    <= 1'b1;
                            psw_ae    <= 1'b0;
                            if (exc_is_irq)
                                psw_i <= exc_level == 4'd15 ? 4'd15
                                                            : exc_level + 4'd1;
                            pc    <= exc_handler;
                            state <= FETCH1;
                        end
                    end

                    FATAL_WR: begin
                        // Cause word, PSW, then PC to 0x0/0x4/0x8, then
                        // stopped for good [Scroll, Exception handling
                        // algorithm].
                        fatal_idx <= fatal_idx + 3'd1;
                        if (fatal_idx == 3'd5) state <= DEAD;
                    end

                    HALTED: begin
                        // Wakes only into exception processing; with
                        // everything masked this never exits, and that is
                        // correct.
                        if (irq_ok) begin
                            exc_code    <= {8'hFE, irq_level, 4'b0000};
                            exc_handler <= {24'hFFFFFE, irq_level, 4'b0000};
                            exc_restore <= pc;   // already the one after
                            exc_is_irq  <= 1'b1;
                            exc_level   <= irq_level;
                            state       <= EXC_ENTER;
                        end
                    end

                    DEAD: ;

                    default: state <= FETCH1;
                endcase

                if (exec_fire) begin
                    // The one register-file read site: a 31-way mux per
                    // operand, here and nowhere else -- a read per use
                    // synthesized one network per call site once.
                    r1v = ir1[4:0] == 5'd0 ? 32'd0 : gpr[ir1[4:0]];
                    r2v = ir1[9:5] == 5'd0 ? 32'd0 : gpr[ir1[9:5]];

                    is32        = state == EXEC2;
                    pcn         = pc + (is32 ? 32'd4 : 32'd2);
                    bcond_taken = cond_true(ir1[12:9], psw_cy, psw_ov,
                                            psw_s, psw_z);
                    ea_raw      = r1v + {{16{rdata[15]}}, rdata};

                    // The charge. A halfword fetch costs 1 plus its wait;
                    // two halfwords double it; a data access adds its
                    // region's wait on top of the zero-wait base.
                    fw    = region_wait(pc[26:24], wcr_rom1w, wcr_exp1w);
                    per   = 3'd1 + {1'b0, fw};
                    fcost = is32 ? {per, 1'b0} : {1'b0, per};

                    if (opcode[5:3] == 3'b100)
                        base = bcond_taken ? 8'd3 : 8'd1;
                    else
                        case (opcode)
                            6'h08, 6'h0A:        base = 8'd13;  // MUL/MULU
                            6'h09:               base = 8'd38;  // DIV
                            6'h0B:               base = 8'd36;  // DIVU
                            6'h06, 6'h2A, 6'h2B: base = 8'd3;   // JMP/JR/JAL
                            6'h1C, 6'h1D:        base = 8'd8;   // LDSR/STSR
                            6'h18:               base = 8'd15;  // TRAP
                            6'h19:               base = 8'd10;  // RETI
                            6'h16, 6'h1E:        base = 8'd12;  // CLI/SEI
                            6'h30, 6'h31, 6'h33,
                            6'h38, 6'h39, 6'h3B:                // LD/IN
                                base = prev_muldiv ? 8'd1
                                     : prev_load   ? 8'd4 : 8'd5;
                            6'h34, 6'h35, 6'h37,
                            6'h3C, 6'h3D, 6'h3F:                // ST/OUT
                                base = store_streak >= 2'd2 ? 8'd4 : 8'd1;
                            default:             base = 8'd1;
                        endcase

                    dwait = region_wait(ea_raw[26:24], wcr_rom1w, wcr_exp1w);
                    datac = opcode[5:4] != 2'b11 || opcode[1:0] == 2'b10
                          ? 3'd0
                          : opcode[1:0] == 2'b11 ? {dwait, 1'b0}
                                                 : {1'b0, dwait};

                    charge = (base > {4'd0, fcost} ? base : {4'd0, fcost})
                             + {5'd0, datac};

                    // The context the load/store rules read next time. The
                    // [1:0] != 2'b10 term excludes the holes and CAXI from
                    // both the load and store shapes.
                    prev_load   <= opcode[5:4] == 2'b11 && !opcode[2]
                                   && opcode[1:0] != 2'b10;
                    prev_muldiv <= opcode[5:2] == 4'b0010;
                    store_streak <= opcode[5:4] == 2'b11 && opcode[2]
                                    && opcode[1:0] != 2'b10
                                  ? (store_streak == 2'd3
                                     ? 2'd3 : store_streak + 2'd1)
                                  : 2'd0;

                    // Defaults an instruction overrides as needed.
                    pc    <= pcn;
                    state <= FETCH1;

                    // Bcond is the one 3-bit opcode, decoded ahead of the
                    // 6-bit map. Base PC is the branch's own address.
                    if (opcode[5:3] == 3'b100) begin
                        if (bcond_taken)
                            pc <= pc + {{23{ir1[8]}}, ir1[8:1], 1'b0};
                    end else begin
                        case (opcode)

                        // ---- register transfer: no flags ----
                        6'h00, 6'h10:                          // MOV
                            gpr_write(reg2_num, ir1[14]
                                ? {{27{ir1[4]}}, ir1[4:0]} : r1v);
                        6'h28:                                 // MOVEA
                            gpr_write(reg2_num, ea_raw);
                        6'h2F:                                 // MOVHI
                            gpr_write(reg2_num, r1v + {rdata, 16'd0});

                        // ---- add, subtract, compare ----
                        6'h01, 6'h11, 6'h29: begin             // ADD/ADDI
                            left = opcode == 6'h29 ? r1v : r2v;
                            op_b = opcode == 6'h11
                                 ? {{27{ir1[4]}}, ir1[4:0]}
                                 : opcode == 6'h29 ? {{16{rdata[15]}}, rdata}
                                                   : r1v;
                            sum  = {1'b0, left} + {1'b0, op_b};
                            gpr_write(reg2_num, sum[31:0]);
                            psw_cy <= sum[32];
                            psw_ov <= left[31] == op_b[31]
                                      && sum[31] != left[31];
                            psw_s  <= sum[31];
                            psw_z  <= sum[31:0] == 32'd0;
                        end

                        6'h02, 6'h03, 6'h13: begin             // SUB/CMP
                            left = r2v;
                            op_b = opcode == 6'h13
                                 ? {{27{ir1[4]}}, ir1[4:0]} : r1v;
                            sum  = {1'b0, left} - {1'b0, op_b};
                            if (opcode == 6'h02)
                                gpr_write(reg2_num, sum[31:0]);
                            psw_cy <= sum[32];
                            psw_ov <= left[31] != op_b[31]
                                      && sum[31] != left[31];
                            psw_s  <= sum[31];
                            psw_z  <= sum[31:0] == 32'd0;
                        end

                        // ---- multiply: operands registered here, the
                        // product consumed next clock ----
                        6'h08, 6'h0A: begin                    // MUL/MULU
                            mul_signed <= opcode == 6'h08;
                            mul_a      <= {opcode == 6'h08 && r2v[31], r2v};
                            mul_b      <= {opcode == 6'h08 && r1v[31], r1v};
                            dest_q     <= reg2_num;
                            state      <= MUL_DONE;
                        end

                        // ---- divide ----
                        6'h09, 6'h0B: begin                    // DIV/DIVU
                            if (r1v == 32'd0) begin
                                // Zero division: reg2, r30 and the flags
                                // untouched; restore PC is this instruction
                                // [manual DIV p.58 for the untouched state].
                                raise(16'hFF80, 32'hFFFF_FF80, pc);
                            end else if (opcode == 6'h09
                                         && r2v == 32'h8000_0000
                                         && r1v == 32'hFFFF_FFFF) begin
                                // The one dividable overflow: dividend
                                // kept, zero remainder, OV set.
                                gpr_write_r30(32'd0);
                                gpr_write(reg2_num, 32'h8000_0000);
                                psw_ov <= 1'b1;
                                psw_s  <= 1'b1;
                                psw_z  <= 1'b0;
                            end else begin
                                div_work    <= opcode == 6'h09 && r2v[31]
                                             ? -r2v : r2v;
                                div_divisor <= opcode == 6'h09 && r1v[31]
                                             ? -r1v : r1v;
                                div_rem      <= 32'd0;
                                div_cnt      <= 5'd31;
                                div_neg_quot <= opcode == 6'h09
                                              && (r2v[31] ^ r1v[31]);
                                div_neg_rem  <= opcode == 6'h09 && r2v[31];
                                dest_q       <= reg2_num;
                                state        <= DIV_RUN;
                            end
                        end

                        // ---- bitwise: OV cleared, CY untouched ----
                        6'h0C, 6'h2C, 6'h0D, 6'h2D,
                        6'h0E, 6'h2E, 6'h0F: begin      // OR/AND/XOR/NOT
                            left = opcode[5] ? r1v : r2v;
                            op_b = opcode[5] ? {16'd0, rdata} : r1v;
                            res  = opcode[1:0] == 2'b00 ? left | op_b
                                 : opcode[1:0] == 2'b01 ? left & op_b
                                 : opcode[1:0] == 2'b10 ? left ^ op_b
                                 : ~r1v;
                            gpr_write(reg2_num, res);
                            set_logic_flags(res);
                        end

                        // ---- shifts: CY is the last bit shifted out,
                        // cleared when the amount is zero ----
                        6'h04, 6'h14, 6'h05,
                        6'h15, 6'h07, 6'h17: begin             // SHL/SHR/SAR
                            shn = ir1[14] ? ir1[4:0] : r1v[4:0];
                            if (opcode[1:0] == 2'b00) begin
                                res = r2v << shn;
                                psw_cy <= shn == 5'd0
                                        ? 1'b0
                                        : r2v[6'd32 - {1'b0, shn}];
                            end else begin
                                res = opcode[1]
                                    ? $unsigned($signed(r2v) >>> shn)
                                    : r2v >> shn;
                                psw_cy <= shn == 5'd0
                                        ? 1'b0 : r2v[shn - 5'd1];
                            end
                            gpr_write(reg2_num, res);
                            psw_ov <= 1'b0;
                            psw_s  <= res[31];
                            psw_z  <= res == 32'd0;
                        end

                        // ---- jumps: every target drops bit 0 ----
                        6'h06: pc <= {r1v[31:1], 1'b0};        // JMP
                        6'h2A: pc <= pc + jump_disp(ir1, rdata); // JR
                        6'h2B: begin                           // JAL
                            gpr_write(5'd31, pc + 32'd4);
                            pc <= pc + jump_disp(ir1, rdata);
                        end

                        6'h12:                                 // SETF
                            gpr_write(reg2_num, {31'd0,
                                cond_true(ir1[3:0], psw_cy, psw_ov,
                                          psw_s, psw_z)});

                        // ---- system registers ----
                        6'h1C: ldsr(ir1[4:0], r2v);            // LDSR
                        6'h1D: begin                           // STSR
                            // Reserved indexes read zero, register 31 the
                            // absolute value of whatever was last written
                            // [Scroll, CPU > System Registers].
                            case (ir1[4:0])
                                5'd0:  res = eipc;
                                5'd1:  res = eipsw;
                                5'd2:  res = fepc;
                                5'd3:  res = fepsw;
                                5'd4:  res = ecr;
                                5'd5:  res = psw_now;
                                5'd6:  res = PIR_VALUE;
                                5'd7:  res = TKCW_VALUE;
                                5'd24: res = {30'd0, chcw_ice, 1'b0};
                                5'd25: res = adtre;
                                5'd29: res = sr29;
                                5'd30: res = SR30_VALUE;
                                5'd31: res = sr31[31] ? -sr31 : sr31;
                                default: res = 32'd0;
                            endcase
                            gpr_write(reg2_num, res);
                        end

                        // ---- Nintendo's CLI/SEI, on opcodes NEC left
                        // unassigned ----
                        6'h16: psw_id <= 1'b0;                 // CLI
                        6'h1E: psw_id <= 1'b1;                 // SEI

                        6'h18:                                 // TRAP
                            raise(16'hFFA0 + {11'd0, ir1[4:0]},
                                  ir1[4] ? 32'hFFFF_FFB0 : 32'hFFFF_FFA0,
                                  pcn);

                        6'h19: begin                           // RETI
                            // NP selects the pair, matching the deeper of
                            // the two save levels.
                            if (psw_np) begin
                                pc <= {fepc[31:1], 1'b0};
                                psw_unpack(fepsw);
                            end else begin
                                pc <= {eipc[31:1], 1'b0};
                                psw_unpack(eipsw);
                            end
                        end

                        6'h1A: state <= HALTED;                // HALT

                        // ---- loads, inputs, stores, outputs. EA rounds
                        // down: bit 0 for halfwords, bits 1-0 for words ----
                        6'h30, 6'h31, 6'h33, 6'h38, 6'h39, 6'h3B,  // LD/IN
                        6'h34, 6'h35, 6'h37, 6'h3C, 6'h3D, 6'h3F: begin
                            ea = opcode[1:0] == 2'b11
                               ? {ea_raw[31:2], 2'b00}
                               : opcode[0] ? {ea_raw[31:1], 1'b0} : ea_raw;
                            mem_size  <= opcode[1:0] == 2'b11 ? SIZE_W
                                       : opcode[0] ? SIZE_H : SIZE_B;
                            mem_ea    <= ea;
                            mem_ea_p2 <= ea[26:1] + 26'd1;
                            mem_zext  <= opcode[3];
                            mem_store <= opcode[2];
                            mem_data  <= r2v;
                            dest_q    <= reg2_num;
                            // reads of 0x02000024 answer with our own WCR
                            mem_wcr   <= !opcode[2]
                                         && ea_raw[26:24] == 3'd2
                                         && ea_raw[7:0] == 8'h24;
                            state     <= MEM_LO;
                        end

                        // ---- everything else raises illegal-opcode:
                        // 0x1B/0x32/0x36 are genuinely invalid; bit strings
                        // (0x1F), CAXI (0x3A) and the format VII group
                        // (0x3E) are stand-ins until their features land ----
                        default: raise(16'hFF90, 32'hFFFF_FF90, pc);
                        endcase
                    end
                end
            end

            // Architectural time: an executing instruction's charge
            // accumulates and each ce drains one cycle; a tick landing on
            // the charge's own clock already drains it by one.
            if (ce && owed + charge != 8'd0)
                owed <= owed + charge - 8'd1;
            else if (!ce && charge != 8'd0)
                owed <= owed + charge;
        end
    end

endmodule

`default_nettype wire
