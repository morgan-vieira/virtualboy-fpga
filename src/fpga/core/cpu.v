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
// V810 architecture manual disagree we follow the scroll and say so, with
// the cross-document contradictions recorded in docs/technical-notes/
// INDEX.md. The whole instruction set is implemented: floating point lives
// in cpu_fpu.v, and this file carries the bit strings, CAXI, the four
// extended instructions, and the instruction cache.
//
// Interrupts are checked between instructions -- and, per the manual's
// Table 6-2, DIV/DIVU, the floating-point operations and bit strings are
// additionally abortable mid-flight with a restore PC of the instruction
// itself. Nothing commits before an abort (results and flags land only at
// completion), so the re-execution after RETI is clean; the aborted
// instruction's remaining budget is forgiven and recharged when it reruns.
// The scroll says between-instructions only and beetle-vb agrees for
// everything but bit strings; the manual's Note 3 to Table 6-1 is explicit
// about aborted instructions, so we follow it (see INDEX.md). A bit string
// instruction is its own interrupt window: it processes one destination
// word (or one source word searched) per invocation, updates r26-r30, and
// leaves PC on itself until the string is done [Scroll, CPU > Bit Strings],
// so the ordinary between-instructions check services it.
//
// The instruction cache is the documented 128-entry, 8-byte-block direct-
// mapped cache with per-4-byte-subblock valid bits [beetle-vb RDCACHE's
// refinement of the scroll's single valid bit; the dump format exposes
// both, valid0 at bit 22 and valid1 at bit 23 of the spilled tag]. Fetches
// consult it only when CHCW.ICE is set; data accesses always bypass. The
// clear, dump and restore commands walk entry by entry, and interrupts are
// postponed until they finish because the walkers never pass through the
// FETCH1 check [Scroll, CPU > Instruction Cache]. Setting more than one
// command bit at once is undefined and does nothing here, matching
// beetle-vb's exact-match dispatch. The cache clears itself over the same
// walker out of reset -- whether real hardware does is not established
// [Scroll, System Reset > CPU]; beetle-vb zeroes it and we follow.
//
// The address trap is live: with PSW.AE set, a PC matching ADTRE raises
// 0xFFC0 before the fetch, restore at current PC [Scroll, CPU >
// Exceptions > Address Trap; MiSTer implements it, beetle-vb only stores
// the register].
//
// Cached-fetch timing: a hit charges one cycle per halfword, a miss adds
// the subblock fill at bus cost plus one [beetle RDCACHE's extra penalty],
// and a taken branch to a subblock-odd target adds one cycle while the
// cache is on [beetle BRANCH_ALIGN_CHECK]. A cached one-cycle 16-bit
// instruction is walk-limited at two clocks, which averages 1.0016 cycles
// instead of 1 -- the one place the ledger and the walk disagree, and the
// bench pins cache timing in clocks there rather than in ticks.
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
    input  wire logic        ready,

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

    typedef enum logic [5:0] {
        RESET1,      // one clock so the first fetch is a full req pulse
        FETCH1,      // request the first halfword; the interrupt check
        FETCH_END,   // 16-bit: hold for the drain, then execute off rdata.
                     // 32-bit: capture the low half and request the second
        EXEC2,       // 32-bit: hold for the drain, then execute
        MEM_LO,      // data access, low halfword (the only one for B/H)
        MEM_HI,      // word access, high halfword; word loads capture low
        MEM_CAP,     // load writeback off the last answer
        MUL_DONE,    // write high word to r30, low to reg2, set flags
        MPYHW_DONE,  // write the truncated product to reg2, no flags
        DIV_RUN,     // one quotient bit per clock; abortable
        DIV_DONE,    // negate, write remainder then quotient, set flags
        FP_WAIT,     // cpu_fpu in flight; abortable
        EXC_ENTER,   // the scroll's exception handling algorithm, one clock
        FATAL_WR,    // fatal exception: three words to 0x0/0x4/0x8
        HALTED,      // halt until an interrupt is accepted
        DEAD,        // fatal: stopped until reset

        // Generic word access: two halfword bus cycles plus, for reads, one
        // to capture the high answer. Callers park the return state in
        // wa_ret; everything word-shaped below rides this.
        WA_LO,
        WA_HI,
        WA_END,

        CAXI_CMP,    // compare the fetched lock word, start the write-back

        // One bit string invocation: one destination word computed or one
        // source word searched, registers written back, PC held until done.
        BS_START,    // top up the source buffer, then fetch what is next
        BS_FILL0,    // the buffer's low word arrived
        BS_FILL1,    // the buffer's high word arrived; read the destination
        BS_APPLY,    // bitwise: merge and start the destination write
        BS_SCAN,     // search: scan the buffered word
        BS_WB_A,     // writeback walk: r30 and, for bitwise, r26
        BS_WB_B,     // r27
        BS_WB_C,     // r28
        BS_WB_D,     // r29; decide completion versus reinvocation

        // Instruction cache. The lookup pair mirrors the bus fetch's two
        // clocks, so cached and uncached walks pace identically.
        IC_CHK,      // first halfword: hit holds here for a 16-bit execute
        IC_CHK2,     // second halfword: hit holds here for the execute
        IC_FILL,     // a fetched subblock lands in the arrays
        IC_LOOK,     // one clock for the arrays to answer, back to IC_CHK
        IC_LOOK2,    // likewise for IC_CHK2
        IC_CLR,      // the clear walker, also the reset initializer
        CD_RD,       // dump: present the array address
        CD_WR,       // dump: write the word out
        CD_STEP,     // dump: advance entry, subblock, phase
        CR_RD,       // restore: read the word in
        CR_ST        // restore: write the arrays, advance
    } state_t;

    state_t state;
    state_t state_q;      // last clock's state; state != state_q is entry

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

    // The executing instruction's own address, the restore PC when a long
    // instruction aborts on an interrupt [manual Table 6-1 Note 3].
    logic [31:0] exec_pc_q;

    // Generic word access plumbing. wa_a is a word address on the 27-bit
    // bus; wa_ret is where the walk resumes once the word moved.
    logic [26:2] wa_a;
    logic        wa_we;
    logic [31:0] wa_wdata, wa_rdata;
    state_t      wa_ret;

    // CAXI: the compare value and r30's exchange value, latched at execute.
    logic [31:0] caxi_cmp_q, caxi_new_q;

    // Bit string state. Bitwise operations stream the source through a
    // two-word read buffer topped up before each destination write; that
    // 64 bits of buffering is exactly why an overlapping destination only
    // corrupts the source when it starts 64 or more bits later [Scroll,
    // CPU > Bit Strings > Bitwise -- beetle-vb's single-word cache gets
    // that artifact wrong at 32 bits, so the document wins]. Searches use
    // the low word alone. Any exception entry invalidates the buffer,
    // forcing a reload on resume [beetle-vb Exception()].
    logic        bs_search, bs_down, bs_bit;
    logic [2:0]  bs_op;
    logic [31:0] bs_src, bs_dst, bs_len, bs_skip;
    logic [4:0]  bs_srcoff, bs_dstoff;
    logic [31:0] bs_buf0, bs_buf1;
    logic        bs_v0, bs_v1;
    logic        bs_active;      // an invocation already ran; prices resumes
    logic        bs_done;        // this invocation finished the instruction

    // The FPU. Start is a one-clock pulse; results are consumed on done.
    logic        fpu_start, fpu_abort;
    logic [3:0]  fpu_op;
    logic [31:0] fpu_a, fpu_b;
    wire  logic        fpu_done;
    wire  logic [31:0] fpu_result;
    wire  logic        fpu_wr, fpu_flags_wr, fpu_cy_wr;
    wire  logic        fpu_cy, fpu_s, fpu_z;
    wire  logic [5:0]  fpu_fpf;
    wire  logic        fpu_exc;
    wire  logic [15:0] fpu_exc_code;

    // Instruction cache arrays: 128 entries of two 4-byte subblocks, a
    // 22-bit tag and one valid bit per subblock [Scroll, CPU > Instruction
    // Cache; beetle-vb V810_CacheEntry_t]. MLAB on purpose -- the M10K
    // budget is spent -- with one registered read and one write port each.
    (* ramstyle = "MLAB" *) logic [31:0] ic_data [0:255];
    (* ramstyle = "MLAB" *) logic [23:0] ic_tagv [0:127];

    logic [31:0] ic_data_q;
    logic [23:0] ic_tagv_q;
    logic [23:0] ic_tagv_cur;     // the missed entry's tag word, for merging
    logic        ic_fill_hi;      // the miss being filled is pc+2's subblock

    // The clear walker (also reset init) and the dump/restore walkers.
    logic [11:0] cc_idx;
    logic [11:0] cc_cnt;
    logic [1:0]  cc_ph;
    logic [31:8] cd_sa;
    logic [6:0]  cd_idx;
    logic        cd_sub, cd_tags;

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

    // A whole word on the 16-bit bus: two halfword accesses, each one cycle
    // plus its region wait. Work RAM's word cost of 4 is what lines the bit
    // string charges up with the manual's 12-per-word slope (Table 5-13).
    function automatic logic [2:0] word_cost(input logic [2:0] region,
                                             input logic rom1w,
                                             input logic exp1w);
        return 3'd2 + {1'b0, region_wait(region, rom1w, exp1w)} * 3'd2;
    endfunction

    // Charged base cycles for the format VII group. The scroll documents
    // only ranges for the floating-point set; the points are the Cycle
    // Test totals measured on real hardware, taken from MiSTer's
    // fp_issue_cycles_fn, and every one sits inside its scroll range
    // (beetle-vb instead guesses each range's bottom). The extended four
    // are the scroll's own figures, which MiSTer matches.
    function automatic logic [7:0] vii_base(input logic [3:0] sub);
        case (sub)
            4'h0:    return 8'd7;    // CMPF.S   (scroll: 7-10)
            4'h2:    return 8'd8;    // CVT.WS   (scroll: 5-16)
            4'h3:    return 8'd14;   // CVT.SW   (scroll: 9-14)
            4'h4:    return 8'd22;   // ADDF.S   (scroll: 9-28)
            4'h5:    return 8'd26;   // SUBF.S   (scroll: 12-28)
            4'h6:    return 8'd26;   // MULF.S   (scroll: 8-30)
            4'h7:    return 8'd44;   // DIVF.S   (scroll: 44)
            4'h8:    return 8'd6;    // XB
            4'h9:    return 8'd1;    // XH
            4'hA:    return 8'd22;   // REV
            4'hB:    return 8'd13;   // TRNC.SW  (scroll: 9-14; manual: 8-14)
            default: return 8'd9;    // MPYHW
        endcase
    endfunction

    function automatic logic [31:0] rev32(input logic [31:0] v);
        logic [31:0] r;
        integer i;
        for (i = 0; i < 32; i = i + 1) r[i] = v[31 - i];
        return r;
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

    // Accept an interrupt: the one caller-chosen piece is the restore PC --
    // the next instruction between instructions, the instruction itself
    // when a long instruction aborts.
    task automatic accept_irq(input logic [31:0] restore);
        exc_code    <= {8'hFE, irq_level, 4'b0000};
        exc_handler <= {24'hFFFFFE, irq_level, 4'b0000};
        exc_restore <= restore;
        exc_is_irq  <= 1'b1;
        exc_level   <= irq_level;
        state       <= EXC_ENTER;
    endtask

    // Start a generic word access; the walk resumes in ret with the word
    // in wa_rdata (reads) or committed to the bus (writes).
    task automatic wa_read(input logic [31:0] a, input state_t ret);
        wa_a   <= a[26:2];
        wa_we  <= 1'b0;
        wa_ret <= ret;
        state  <= WA_LO;
    endtask

    task automatic wa_write(input logic [31:0] a, input logic [31:0] value,
                            input state_t ret);
        wa_a     <= a[26:2];
        wa_we    <= 1'b1;
        wa_wdata <= value;
        wa_ret   <= ret;
        state    <= WA_LO;
    endtask

    // The packed PSW image; psw_unpack is its inverse.
    wire logic [31:0] psw_now = {12'b0, psw_i, psw_np, psw_ep, psw_ae, psw_id,
                                 2'b00, psw_fp, psw_cy, psw_ov, psw_s, psw_z};

    // Interrupts are masked by ID, by either pending flag, and by level
    // (accepted when the level is at least PSW.I), and only ever checked
    // between instructions [Scroll, CPU > Interrupt Handling] -- plus the
    // abortable-instruction states named in the machine below.
    wire logic irq_ok = irq_valid && !psw_id && !psw_ep && !psw_np
                        && irq_level >= psw_i;

    // Cache lookup companions: the entry the arrays answered with, sliced
    // for the halfword being fetched. Tags cover the full 32-bit PC, so
    // mirrored fetch addresses occupy distinct entries, the way a 22-bit
    // tag over a 32-bit space must [Scroll, CPU > Instruction Cache].
    wire logic [31:0] pcp2 = pc + 32'd2;

    // A two-halfword access launches its second request from the state that
    // still has the first answer on rdata. That answer only lives for that
    // state's first clock: a device that inserts waits leaves rdata alone
    // while it works and replaces it the moment its own access completes,
    // so waiting for ready to take the earlier half reads the later one
    // instead. Everything that needs the earlier answer takes it on entry.
    wire logic first_clk = state != state_q;

    // The low halfword of a 32-bit instruction, stable for the whole of
    // FETCH_END so the second request cannot change what it decoded.
    wire logic [15:0] fetch_lo = first_clk ? rdata : ir_lo_q;

    wire logic [15:0] ic_half  = pc[1]   ? ic_data_q[31:16] : ic_data_q[15:0];
    wire logic [15:0] ic_half2 = pcp2[1] ? ic_data_q[31:16] : ic_data_q[15:0];
    wire logic ic_hit1 = ic_tagv_q[21:0] == pc[31:10]
                         && (pc[2] ? ic_tagv_q[23] : ic_tagv_q[22]);
    wire logic ic_hit2 = ic_tagv_q[21:0] == pcp2[31:10]
                         && (pcp2[2] ? ic_tagv_q[23] : ic_tagv_q[22]);

    // The instruction's first halfword: live off the bus or the cache for
    // a 16-bit execute, the captured copy once a 32-bit one moved on. ir2
    // is the second halfword, live from whichever source is holding it.
    wire logic [15:0] ir1      = state == FETCH_END ? fetch_lo
                               : state == IC_CHK    ? ic_half
                               : ir_lo_q;
    wire logic [15:0] ir2      = state == IC_CHK2 ? ic_half2 : rdata;
    wire logic [5:0]  opcode   = ir1[15:10];
    wire logic [4:0]  reg2_num = ir1[9:5];

    // The execute barrier: every fetch shape ends in one of these holds,
    // and fires on the first clock after the previous budget drains.
    wire logic exec_fire = ((state == FETCH_END && !is_32bit(rdata))
                            || state == EXEC2
                            || (state == IC_CHK && ic_hit1
                                && !is_32bit(ic_half))
                            || (state == IC_CHK2 && ic_hit2))
                           && owed == 8'd0;

    // ------------------------------------------------------------------
    // Bus outputs
    // ------------------------------------------------------------------

    // req is a one-clock pulse per requesting state, so every device sees
    // each access exactly once. The companions are plain functions of
    // state; only req qualifies them. FETCH_END and EXEC2 hold for the
    // drain without requesting, and rdata holds their answer meanwhile.
    // With the cache enabled FETCH1 requests nothing; the lookup states
    // own the fetch and only a miss's fill walks the bus.
    wire logic req_c = state == FETCH1    ? !irq_ok && !chcw_ice
                     : state == FETCH_END ? is_32bit(fetch_lo)
                     : state == MEM_LO || state == MEM_HI
                       || state == WA_LO || state == WA_HI
                       || state == FATAL_WR;

    assign req = reset_n && req_c;

    assign addr = state == FETCH_END ? pc[26:1] + 26'd1
                : state == MEM_LO    ? mem_ea[26:1]
                : state == MEM_HI    ? mem_ea_p2
                : state == WA_LO     ? {wa_a, 1'b0}
                : state == WA_HI     ? {wa_a, 1'b1}
                : state == FATAL_WR  ? {23'd0, fatal_idx}
                : pc[26:1];

    assign we = ((state == MEM_LO || state == MEM_HI) && mem_store)
                || ((state == WA_LO || state == WA_HI) && wa_we)
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

    assign wdata = state == WA_LO    ? wa_wdata[15:0]
                 : state == WA_HI    ? wa_wdata[31:16]
                 : state == MEM_HI   ? mem_data[31:16]
                 : state == FATAL_WR ? fatal_wdata
                 // A byte store routes its byte onto the selected lane but
                 // leaves the register's own bits 15:8 on the other one,
                 // which is what the VIP's mangled byte writes observe
                 // [scroll, VIP I/O Registers].
                 : mem_size == SIZE_B && state == MEM_LO
                 ? (mem_ea[0] ? {mem_data[7:0], mem_data[7:0]}
                              : mem_data[15:0])
                 : mem_data[15:0];

    assign dbg_pc     = pc;
    assign dbg_halted = state == HALTED || state == DEAD;

    // ------------------------------------------------------------------
    // The instruction cache's arrays
    // ------------------------------------------------------------------

    // One registered read and one write port each, with the addresses and
    // strobes decoded combinationally from the state so each array keeps a
    // single write site. Reads land in *_q on the following clock.
    logic       ic_data_we;
    logic [7:0] ic_data_ra, ic_data_wa;
    logic [31:0] ic_data_wd;
    logic       ic_tagv_we;
    logic [6:0] ic_tagv_ra, ic_tagv_wa;
    logic [23:0] ic_tagv_wd;

    always_comb begin : ic_read_addr
        logic [31:0] fetch_a;
        fetch_a = (state == IC_CHK && ic_hit1 && is_32bit(ic_half))
                  || state == IC_CHK2 || state == IC_LOOK2
                ? pcp2 : pc;
        if (state == CD_RD || state == CD_WR || state == CD_STEP) begin
            ic_data_ra = {cd_idx, cd_sub};
            ic_tagv_ra = cd_idx;
        end else begin
            ic_data_ra = {fetch_a[9:3], fetch_a[2]};
            ic_tagv_ra = fetch_a[9:3];
        end
    end

    always_comb begin : ic_write_decode
        logic [31:0] fill_a;
        logic        tag_same;
        ic_data_we = 1'b0;
        ic_data_wa = 8'd0;
        ic_data_wd = 32'd0;
        ic_tagv_we = 1'b0;
        ic_tagv_wa = 7'd0;
        ic_tagv_wd = 24'd0;
        case (state)
            IC_FILL: begin
                // A fetched subblock lands, its valid bit joins the entry:
                // a matching tag keeps the sibling subblock, a new tag
                // evicts it [beetle-vb RDCACHE].
                fill_a     = ic_fill_hi ? pcp2 : pc;
                tag_same   = ic_tagv_cur[21:0] == fill_a[31:10];
                ic_data_we = 1'b1;
                ic_data_wa = {fill_a[9:3], fill_a[2]};
                ic_data_wd = wa_rdata;
                ic_tagv_we = 1'b1;
                ic_tagv_wa = fill_a[9:3];
                ic_tagv_wd = {fill_a[2] ? 1'b1 : tag_same && ic_tagv_cur[23],
                              fill_a[2] ? tag_same && ic_tagv_cur[22] : 1'b1,
                              fill_a[31:10]};
            end
            IC_CLR: begin
                // Tag word then both subblocks, so a cleared entry dumps as
                // zeros the way beetle-vb's memset leaves it.
                if (cc_cnt != 12'd0 && cc_idx < 12'd128) begin
                    if (cc_ph == 2'd0) begin
                        ic_tagv_we = 1'b1;
                        ic_tagv_wa = cc_idx[6:0];
                    end else begin
                        ic_data_we = 1'b1;
                        ic_data_wa = {cc_idx[6:0], cc_ph[1]};
                    end
                end
            end
            CR_ST: begin
                if (cd_tags) begin
                    ic_tagv_we = 1'b1;
                    ic_tagv_wa = cd_idx;
                    ic_tagv_wd = wa_rdata[23:0];
                end else begin
                    ic_data_we = 1'b1;
                    ic_data_wa = {cd_idx, cd_sub};
                    ic_data_wd = wa_rdata;
                end
            end
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin : ic_data_ram
        if (ic_data_we) ic_data[ic_data_wa] <= ic_data_wd;
        ic_data_q <= ic_data[ic_data_ra];
    end

    always_ff @(posedge clk) begin : ic_tagv_ram
        if (ic_tagv_we) ic_tagv[ic_tagv_wa] <= ic_tagv_wd;
        ic_tagv_q <= ic_tagv[ic_tagv_ra];
    end

    // ------------------------------------------------------------------
    // The floating-point unit
    // ------------------------------------------------------------------

    cpu_fpu u_fpu (
        .clk(clk),
        .reset_n(reset_n),
        .start(fpu_start),
        .op(fpu_op),
        .a(fpu_a),
        .b(fpu_b),
        .abort(fpu_abort),
        .busy(),
        .done(fpu_done),
        .result(fpu_result),
        .wr_result(fpu_wr),
        .flags_wr(fpu_flags_wr),
        .cy_wr(fpu_cy_wr),
        .flag_cy(fpu_cy),
        .flag_s(fpu_s),
        .flag_z(fpu_z),
        .fp_flags(fpu_fpf),
        .exc(fpu_exc),
        .exc_code(fpu_exc_code)
    );

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
        logic [31:0] r1v, r2v, left, op_b, res, ea_raw, ea, pcn, btgt;
        logic [32:0] sum;
        logic [63:0] prod;
        logic [33:0] trial;
        logic [32:0] div_shift;
        logic        is32, bcond_taken;
        logic [4:0]  shn;
        logic [1:0]  fw, dwait;
        logic [2:0]  per;
        logic [3:0]  fcost, datac;
        logic [7:0]  base;
        logic [7:0]  charge;
        logic        forgive;
        logic [5:0]  navail, n6, soff6, doff6;
        logic [31:0] srcw, dstw, s_eff, bmask, sal, bfull, newdst;
        logic [63:0] win;
        logic        sfound;
        logic [5:0]  sk;
        logic [4:0]  idx5, foundpos;
        logic [31:0] dump_a;
        integer      bi;

        charge  = 8'd0;
        forgive = 1'b0;

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
            state_q <= RESET1;
            owed         <= 8'd0;
            prev_load    <= 1'b0;
            prev_muldiv  <= 1'b0;
            store_streak <= 2'd0;
            wcr_rom1w    <= 1'b0;   // slow at reset, both regions
            wcr_exp1w    <= 1'b0;
            // Whether reset touches the cache is not established [Scroll,
            // System Reset > CPU]; beetle-vb clears everything and we
            // follow, ICE included, via the walker RESET1 starts.
            chcw_ice  <= 1'b0;
            bs_active <= 1'b0;
            bs_v0     <= 1'b0;
            bs_v1     <= 1'b0;
            fpu_start <= 1'b0;
            fpu_abort <= 1'b0;
        end else begin
            // A write request lives exactly one clock, and so do the FPU
            // strobes.
            state_q   <= state;
            wb_en     <= 1'b0;
            wb30_en   <= 1'b0;
            fpu_start <= 1'b0;
            fpu_abort <= 1'b0;

            begin
                case (state)

                    // Reset can release mid-cycle; starting a clock late
                    // keeps the first fetch's req a clean full pulse. The
                    // clear walker then wipes the cache arrays before the
                    // first fetch, so a stale-valid bit cannot exist.
                    RESET1: begin
                        cc_idx <= 12'd0;
                        cc_cnt <= 12'd128;
                        cc_ph  <= 2'd0;
                        state  <= IC_CLR;
                    end

                    FETCH1: begin
                        if (irq_ok) begin
                            // Restore PC is the next instruction: the
                            // previous one completed and pc points past it
                            // -- or is a bit string mid-flight, which left
                            // pc on itself, the documented current-PC case.
                            accept_irq(pc);
                        end else if (psw_ae && pc[31:1] == adtre[31:1]) begin
                            // The address trap, checked before the fetch
                            // [Scroll, CPU > Exceptions > Address Trap].
                            // Entry clears AE, and the handler must move
                            // EIPC or the return re-traps -- documented, not
                            // guarded against. The scroll's priority list
                            // puts interrupts above the trap; MiSTer orders
                            // them the other way, and we follow the scroll.
                            raise(16'hFFC0, 32'hFFFF_FFC0, pc);
                        end else if (chcw_ice) begin
                            // The cache owns the fetch; the arrays answer
                            // next clock.
                            state <= IC_CHK;
                        end else if (ready) begin
                            state <= FETCH_END;
                        end
                    end

                    // A 32-bit instruction captures its low half and
                    // requests the second; a 16-bit one holds here for the
                    // barrier and executes below. rdata holds between
                    // accesses, so the hold costs nothing but time.
                    FETCH_END: begin
                        if (first_clk) ir_lo_q <= rdata;
                        if (is_32bit(fetch_lo) && ready) state <= EXEC2;
                    end

                    EXEC2: ;   // the barrier below owns this state

                    MEM_LO: if (ready) begin
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
                        // back-to-back on the bus. It is taken on entry
                        // because a waiting device overwrites it with its
                        // own answer the moment ready arrives.
                        if (first_clk && !mem_store)
                            mem_data[15:0] <= mem_wcr
                                ? {8'd0, 6'b111111, wcr_exp1w, wcr_rom1w}
                                : rdata;
                        if (ready) state <= mem_store ? FETCH1 : MEM_CAP;
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
                        // Abortable mid-flight [manual Table 6-2]: nothing
                        // has committed, so the divide reruns cleanly after
                        // RETI, its remaining budget forgiven.
                        if (irq_ok) begin
                            forgive = 1'b1;
                            accept_irq(exec_pc_q);
                        end else begin
                            div_shift = {div_rem, div_work[31]};
                            trial     = {1'b0, div_shift}
                                        - {2'b00, div_divisor};
                            div_rem   <= trial[33] ? div_shift[31:0]
                                                   : trial[31:0];
                            div_work  <= {div_work[30:0], ~trial[33]};
                            div_cnt   <= div_cnt - 5'd1;
                            if (div_cnt == 5'd0) state <= DIV_DONE;
                        end
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

                    MPYHW_DONE: begin
                        // The truncated product to reg2 alone: no flags and
                        // no r30 [Scroll, CPU > Nintendo > Extended].
                        gpr_write(dest_q, prod_w[31:0]);
                        state <= FETCH1;
                    end

                    FP_WAIT: begin
                        // Flags land before any exception is raised, and a
                        // killed result touches neither flags nor reg2.
                        // Abortable like the divide [manual Table 6-2].
                        if (fpu_done) begin
                            if (fpu_flags_wr) begin
                                psw_ov <= 1'b0;
                                psw_s  <= fpu_s;
                                psw_z  <= fpu_z;
                                if (fpu_cy_wr) psw_cy <= fpu_cy;
                            end
                            psw_fp <= psw_fp | fpu_fpf;
                            if (fpu_wr) gpr_write(dest_q, fpu_result);
                            if (fpu_exc)
                                raise(fpu_exc_code, 32'hFFFF_FF60, exec_pc_q);
                            else
                                state <= FETCH1;
                        end else if (irq_ok) begin
                            fpu_abort <= 1'b1;
                            forgive   = 1'b1;
                            accept_irq(exec_pc_q);
                        end
                    end

                    // ---- the generic word access ----

                    WA_LO: if (ready) begin
                        // The WCR snoop covers word-shaped writers too, the
                        // low halfword carrying both bits.
                        if (wa_we && wa_a[26:24] == 3'd2
                            && wa_a[7:2] == 6'h09) begin
                            wcr_rom1w <= wa_wdata[0];
                            wcr_exp1w <= wa_wdata[1];
                        end
                        state <= WA_HI;
                    end

                    WA_HI: begin
                        // Reads of the CPU's own WCR answer WCR | 0xFC on
                        // this path too, so CAXI and bit string sources see
                        // the same readback loads do. Taken on entry, for
                        // the reason MEM_HI gives.
                        if (first_clk && !wa_we)
                            wa_rdata[15:0] <= wa_a[26:24] == 3'd2
                                              && wa_a[7:2] == 6'h09
                                ? {8'd0, 6'b111111, wcr_exp1w, wcr_rom1w}
                                : rdata;
                        if (ready) state <= wa_we ? wa_ret : WA_END;
                    end

                    WA_END: begin
                        wa_rdata[31:16] <= wa_a[26:24] == 3'd2
                                           && wa_a[7:2] == 6'h09
                                         ? 16'd0 : rdata;
                        state <= wa_ret;
                    end

                    // ---- CAXI ----

                    CAXI_CMP: begin
                        // Compare flags exactly as CMP would set them, then
                        // the write happens either way: the exchange value
                        // on a match, the fetched word back on a mismatch
                        // [manual CAXI pp.51-52; beetle-vb agrees].
                        sum = {1'b0, caxi_cmp_q} - {1'b0, wa_rdata};
                        psw_cy <= sum[32];
                        psw_ov <= caxi_cmp_q[31] != wa_rdata[31]
                                  && sum[31] != caxi_cmp_q[31];
                        psw_s  <= sum[31];
                        psw_z  <= sum[31:0] == 32'd0;
                        gpr_write(dest_q, wa_rdata);
                        wa_write({5'd0, wa_a, 2'b00},
                                 sum[31:0] == 32'd0 ? caxi_new_q : wa_rdata,
                                 FETCH1);
                    end

                    // ---- one bit string invocation ----

                    BS_START: begin
                        if (bs_len == 32'd0) begin
                            // Length zero is valid: the registers write
                            // back masked and a search sets Z [manual
                            // SCH1BS p.88; beetle-vb bstr_subop].
                            if (bs_search) psw_z <= 1'b1;
                            bs_done <= 1'b1;
                            state   <= BS_WB_A;
                        end else if (bs_search) begin
                            if (bs_v0)
                                state <= BS_SCAN;
                            else begin
                                charge = {5'd0, word_cost(bs_src[26:24],
                                          wcr_rom1w, wcr_exp1w)};
                                wa_read(bs_src, BS_SCAN);
                            end
                        end else begin
                            // Top the two-word buffer up before touching
                            // the destination: those reads-ahead are the
                            // documented 64 bits of buffering.
                            if (!bs_v0) begin
                                charge = {5'd0, word_cost(bs_src[26:24],
                                          wcr_rom1w, wcr_exp1w)};
                                wa_read(bs_src, BS_FILL0);
                            end else if (!bs_v1) begin
                                charge = {5'd0,
                                          word_cost(bs_src[26:24],
                                          wcr_rom1w, wcr_exp1w)};
                                wa_read(bs_src + 32'd4, BS_FILL1);
                            end else begin
                                charge = {5'd0, word_cost(bs_dst[26:24],
                                          wcr_rom1w, wcr_exp1w)};
                                wa_read(bs_dst, BS_APPLY);
                            end
                        end
                    end

                    BS_FILL0: begin
                        bs_buf0 <= wa_rdata;
                        bs_v0   <= 1'b1;
                        charge = {5'd0, word_cost(bs_src[26:24],
                                  wcr_rom1w, wcr_exp1w)};
                        wa_read(bs_src + 32'd4, BS_FILL1);
                    end

                    BS_FILL1: begin
                        bs_buf1 <= wa_rdata;
                        bs_v1   <= 1'b1;
                        // The destination word always gets read, because
                        // every write is a read-modify-write of one word.
                        charge = {5'd0, word_cost(bs_dst[26:24],
                                  wcr_rom1w, wcr_exp1w)};
                        wa_read(bs_dst, BS_APPLY);
                    end

                    BS_APPLY: begin
                        // This destination word's bits: up to the word
                        // boundary or the string's end, whichever is first.
                        navail = 6'd32 - {1'b0, bs_dstoff};
                        n6 = bs_len < {26'd0, navail} ? bs_len[5:0] : navail;

                        dstw  = wa_rdata;
                        win   = {bs_buf1, bs_buf0} >> bs_srcoff;
                        s_eff = bs_op[2] ? ~win[31:0] : win[31:0];
                        bmask = n6 == 6'd32
                              ? 32'hFFFF_FFFF
                              : ((32'd1 << n6[4:0]) - 32'd1) << bs_dstoff;
                        sal   = s_eff << bs_dstoff;
                        case (bs_op[1:0])
                            2'b00:   bfull = dstw | sal;   // OR / ORN
                            2'b01:   bfull = dstw & sal;   // AND / ANDN
                            2'b10:   bfull = dstw ^ sal;   // XOR / XORN
                            default: bfull = sal;          // MOV / NOT
                        endcase
                        newdst = (dstw & ~bmask) | (bfull & bmask);

                        soff6 = {1'b0, bs_srcoff} + n6;
                        doff6 = {1'b0, bs_dstoff} + n6;
                        bs_srcoff <= soff6[4:0];
                        bs_dstoff <= doff6[4:0];
                        if (soff6 >= 6'd32) begin
                            // The buffer slides: the high word becomes the
                            // low one and the next top-up reads ahead.
                            bs_src  <= bs_src + 32'd4;
                            bs_buf0 <= bs_buf1;
                            bs_v1   <= 1'b0;
                        end
                        if (doff6 >= 6'd32) bs_dst <= bs_dst + 32'd4;
                        bs_len  <= bs_len - {26'd0, n6};
                        bs_done <= bs_len == {26'd0, n6};

                        charge = {5'd0, word_cost(bs_dst[26:24],
                                  wcr_rom1w, wcr_exp1w)};
                        wa_write(bs_dst, newdst, BS_WB_A);
                    end

                    BS_SCAN: begin
                        srcw = bs_v0 ? bs_buf0 : wa_rdata;
                        if (!bs_v0) begin
                            bs_buf0 <= wa_rdata;
                            bs_v0   <= 1'b1;
                        end
                        navail = bs_down ? {1'b0, bs_srcoff} + 6'd1
                                         : 6'd32 - {1'b0, bs_srcoff};
                        n6 = bs_len < {26'd0, navail} ? bs_len[5:0] : navail;

                        // First matching bit within this word's span, in
                        // the search direction.
                        sfound = 1'b0;
                        sk     = 6'd0;
                        for (bi = 0; bi < 32; bi = bi + 1) begin
                            idx5 = bs_down ? bs_srcoff - bi[4:0]
                                           : bs_srcoff + bi[4:0];
                            if (!sfound && bi[5:0] < n6
                                && srcw[idx5] == bs_bit) begin
                                sfound = 1'b1;
                                sk     = bi[5:0];
                            end
                        end

                        if (sfound) begin
                            // Skipped bits count; the string keeps the
                            // found bit; the pointer lands one bit before
                            // it in the search direction [manual SCH1BS;
                            // the scroll's "next bit following" disagrees
                            // and INDEX.md records it].
                            bs_skip <= bs_skip + {26'd0, sk};
                            bs_len  <= bs_len - {26'd0, sk};
                            foundpos = bs_down ? bs_srcoff - sk[4:0]
                                               : bs_srcoff + sk[4:0];
                            if (!bs_down) begin
                                if (foundpos == 5'd0) begin
                                    bs_srcoff <= 5'd31;
                                    bs_src    <= bs_src - 32'd4;
                                end else
                                    bs_srcoff <= foundpos - 5'd1;
                            end else begin
                                if (foundpos == 5'd31) begin
                                    bs_srcoff <= 5'd0;
                                    bs_src    <= bs_src + 32'd4;
                                end else
                                    bs_srcoff <= foundpos + 5'd1;
                            end
                            psw_z   <= 1'b0;
                            bs_done <= 1'b1;
                        end else begin
                            // Walked the whole span: cross into the next
                            // word. beetle-vb crosses downward one bit
                            // early (its !srcoff check is the upward
                            // condition); the manual's downward tables walk
                            // whole words, so we follow the manual.
                            bs_skip <= bs_skip + {26'd0, n6};
                            bs_len  <= bs_len - {26'd0, n6};
                            if (!bs_down) begin
                                bs_srcoff <= 5'd0;
                                bs_src    <= bs_src + 32'd4;
                            end else begin
                                bs_srcoff <= 5'd31;
                                bs_src    <= bs_src - 32'd4;
                            end
                            bs_v0 <= 1'b0;
                            if (bs_len == {26'd0, n6}) psw_z <= 1'b1;
                            bs_done <= bs_len == {26'd0, n6};
                        end
                        charge = 8'd1;   // the scan atop the word read
                        state  <= BS_WB_A;
                    end

                    // The registers write back through the one write site,
                    // two ports a clock; every invocation updates them so
                    // an interrupt handler sees the resume state [Scroll,
                    // CPU > Bit Strings].
                    BS_WB_A: begin
                        gpr_write_r30(bs_src);
                        if (!bs_search)
                            gpr_write(5'd26, {27'd0, bs_dstoff});
                        state <= BS_WB_B;
                    end

                    BS_WB_B: begin
                        gpr_write(5'd27, {27'd0, bs_srcoff});
                        state <= BS_WB_C;
                    end

                    BS_WB_C: begin
                        gpr_write(5'd28, bs_len);
                        state <= BS_WB_D;
                    end

                    BS_WB_D: begin
                        gpr_write(5'd29, bs_search ? bs_skip : bs_dst);
                        if (bs_done) begin
                            // Only now does PC move [Scroll, CPU > Bit
                            // Strings]; an unfinished string re-executes
                            // from FETCH1, which is the interrupt window.
                            pc        <= pc + 32'd2;
                            bs_active <= 1'b0;
                            bs_v0     <= 1'b0;
                            bs_v1     <= 1'b0;
                        end else
                            bs_active <= 1'b1;
                        state <= FETCH1;
                    end

                    // ---- the instruction cache ----

                    IC_CHK: begin
                        // A 16-bit hit holds here for the drain, owned by
                        // the execute block below; this case handles the
                        // 32-bit continuation and the miss.
                        if (!ic_hit1) begin
                            ic_tagv_cur <= ic_tagv_q;
                            ic_fill_hi  <= 1'b0;
                            charge = {5'd0, word_cost(pc[26:24], wcr_rom1w,
                                      wcr_exp1w)} + 8'd1;
                            wa_read({pc[31:2], 2'b00}, IC_FILL);
                        end else if (is_32bit(ic_half)) begin
                            ir_lo_q <= ic_half;
                            state   <= IC_CHK2;
                        end
                    end

                    IC_CHK2: begin
                        if (!ic_hit2) begin
                            ic_tagv_cur <= ic_tagv_q;
                            ic_fill_hi  <= 1'b1;
                            charge = {5'd0, word_cost(pcp2[26:24], wcr_rom1w,
                                      wcr_exp1w)} + 8'd1;
                            wa_read({pcp2[31:2], 2'b00}, IC_FILL);
                        end
                        // A hit holds for the execute block.
                    end

                    // The fill's array writes fire here (the comb decode
                    // keys on this state); the lookup then reruns and hits.
                    IC_FILL:  state <= ic_fill_hi ? IC_LOOK2 : IC_LOOK;
                    IC_LOOK:  state <= IC_CHK;
                    IC_LOOK2: state <= IC_CHK2;

                    IC_CLR: begin
                        // Entry by entry -- tag word, then both subblocks --
                        // so a cleared entry dumps as zeros. Counts clamp at
                        // entry 127 and never wrap [Scroll, CHCW]. No cycle
                        // charge, following beetle-vb's CacheClear.
                        if (cc_cnt == 12'd0 || cc_idx >= 12'd128)
                            state <= FETCH1;
                        else if (cc_ph == 2'd2) begin
                            cc_ph  <= 2'd0;
                            cc_idx <= cc_idx + 12'd1;
                            cc_cnt <= cc_cnt - 12'd1;
                        end else
                            cc_ph <= cc_ph + 2'd1;
                    end

                    // ---- cache dump: 128 8-byte blocks, then 128 4-byte
                    // tag words, at SA [Scroll, CPU > Instruction Cache].
                    // Interrupts wait; these states never pass FETCH1. ----

                    CD_RD: state <= CD_WR;   // the arrays answer

                    CD_WR: begin
                        dump_a = cd_tags
                               ? {cd_sa, 8'd0} + 32'd1024
                                 + {23'd0, cd_idx, 2'b00}
                               : {cd_sa, 8'd0} + {22'd0, cd_idx, cd_sub, 2'b00};
                        charge = {5'd0, word_cost(dump_a[26:24], wcr_rom1w,
                                  wcr_exp1w)};
                        wa_write(dump_a,
                                 cd_tags ? {8'd0, ic_tagv_q} : ic_data_q,
                                 CD_STEP);
                    end

                    CD_STEP: begin
                        if (!cd_tags) begin
                            if (!cd_sub) cd_sub <= 1'b1;
                            else begin
                                cd_sub <= 1'b0;
                                if (cd_idx == 7'd127) begin
                                    cd_tags <= 1'b1;
                                    cd_idx  <= 7'd0;
                                end else
                                    cd_idx <= cd_idx + 7'd1;
                            end
                            state <= CD_RD;
                        end else if (cd_idx == 7'd127)
                            state <= FETCH1;
                        else begin
                            cd_idx <= cd_idx + 7'd1;
                            state  <= CD_RD;
                        end
                    end

                    // ---- cache restore: the same 1,536 bytes read back
                    // into the arrays ----

                    CR_RD: begin
                        dump_a = cd_tags
                               ? {cd_sa, 8'd0} + 32'd1024
                                 + {23'd0, cd_idx, 2'b00}
                               : {cd_sa, 8'd0} + {22'd0, cd_idx, cd_sub, 2'b00};
                        charge = {5'd0, word_cost(dump_a[26:24], wcr_rom1w,
                                  wcr_exp1w)};
                        wa_read(dump_a, CR_ST);
                    end

                    CR_ST: begin
                        // The comb decode writes the arrays from wa_rdata.
                        if (!cd_tags) begin
                            if (!cd_sub) cd_sub <= 1'b1;
                            else begin
                                cd_sub <= 1'b0;
                                if (cd_idx == 7'd127) begin
                                    cd_tags <= 1'b1;
                                    cd_idx  <= 7'd0;
                                end else
                                    cd_idx <= cd_idx + 7'd1;
                            end
                            state <= CR_RD;
                        end else if (cd_idx == 7'd127)
                            state <= FETCH1;
                        else begin
                            cd_idx <= cd_idx + 7'd1;
                            state  <= CR_RD;
                        end
                    end

                    EXC_ENTER: begin
                        // The scroll's exception handling algorithm, in
                        // order: NP pending makes it fatal, EP pending
                        // duplexes it, otherwise the regular entry -- and
                        // only an interrupt touches the level field. Any
                        // entry invalidates the bit string read buffer, so
                        // a resumed string reloads it [beetle-vb
                        // Exception()].
                        bs_v0     <= 1'b0;
                        bs_v1     <= 1'b0;
                        bs_active <= 1'b0;
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

                    FATAL_WR: if (ready) begin
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
                        if (irq_ok) accept_irq(pc);   // already the one after
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

                    is32        = state == EXEC2 || state == IC_CHK2;
                    pcn         = pc + (is32 ? 32'd4 : 32'd2);
                    bcond_taken = cond_true(ir1[12:9], psw_cy, psw_ov,
                                            psw_s, psw_z);
                    ea_raw      = r1v + {{16{ir2[15]}}, ir2};
                    exec_pc_q   <= pc;

                    // The charge. A halfword fetch costs 1 plus its wait;
                    // two halfwords double it; a data access adds its
                    // region's wait on top of the zero-wait base. A cache
                    // hit costs 1 per halfword flat -- the documented base
                    // counts assume a hit -- and misses were charged their
                    // fill at IC_CHK.
                    fw    = region_wait(pc[26:24], wcr_rom1w, wcr_exp1w);
                    per   = chcw_ice ? 3'd1 : 3'd1 + {1'b0, fw};
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
                            6'h30, 6'h31, 6'h33:                // LD
                                base = prev_muldiv ? 8'd1
                                     : prev_load   ? 8'd4 : 8'd5;
                            // IN takes Table 5-11's flat figure with no
                            // context discount [MiSTer
                            // mem_load_tail_cycles_fn; resolves the
                            // scroll's "may be identical" the manual's way]
                            6'h38, 6'h39, 6'h3B:                // IN
                                base = 8'd5;
                            6'h34, 6'h35, 6'h37,
                            6'h3C, 6'h3D, 6'h3F:                // ST/OUT
                                base = store_streak >= 2'd2 ? 8'd4 : 8'd1;
                            default:             base = 8'd1;
                        endcase

                    dwait = region_wait(ea_raw[26:24], wcr_rom1w, wcr_exp1w);
                    datac = opcode[5:4] != 2'b11 || opcode[1:0] == 2'b10
                          ? 4'd0
                          : opcode[1:0] == 2'b11 ? {1'b0, dwait, 1'b0}
                                                 : {2'b0, dwait};

                    charge = (base > {4'd0, fcost} ? base : {4'd0, fcost})
                             + {4'd0, datac};

                    // The context the load/store rules read next time. The
                    // [1:0] != 2'b10 term excludes the holes and CAXI from
                    // both the load and store shapes.
                    prev_load   <= opcode[5:4] == 2'b11 && !opcode[2]
                                   && !opcode[3] && opcode[1:0] != 2'b10;
                    prev_muldiv <= opcode[5:2] == 4'b0010
                                   || opcode == 6'h3E;
                    store_streak <= opcode[5:4] == 2'b11 && opcode[2]
                                    && opcode[1:0] != 2'b10
                                  ? (store_streak == 2'd3
                                     ? 2'd3 : store_streak + 2'd1)
                                  : 2'd0;

                    // Defaults an instruction overrides as needed.
                    pc    <= pcn;
                    state <= FETCH1;

                    // Bcond is the one 3-bit opcode, decoded ahead of the
                    // 6-bit map. Base PC is the branch's own address. A
                    // taken branch to a subblock-odd target costs one more
                    // while the cache is on [beetle BRANCH_ALIGN_CHECK].
                    if (opcode[5:3] == 3'b100) begin
                        if (bcond_taken) begin
                            btgt = pc + {{23{ir1[8]}}, ir1[8:1], 1'b0};
                            if (chcw_ice && btgt[1]) charge = charge + 8'd1;
                            pc <= btgt;
                        end
                    end else begin
                        case (opcode)

                        // ---- register transfer: no flags ----
                        6'h00, 6'h10:                          // MOV
                            gpr_write(reg2_num, ir1[14]
                                ? {{27{ir1[4]}}, ir1[4:0]} : r1v);
                        6'h28:                                 // MOVEA
                            gpr_write(reg2_num, ea_raw);
                        6'h2F:                                 // MOVHI
                            gpr_write(reg2_num, r1v + {ir2, 16'd0});

                        // ---- add, subtract, compare ----
                        6'h01, 6'h11, 6'h29: begin             // ADD/ADDI
                            left = opcode == 6'h29 ? r1v : r2v;
                            op_b = opcode == 6'h11
                                 ? {{27{ir1[4]}}, ir1[4:0]}
                                 : opcode == 6'h29 ? {{16{ir2[15]}}, ir2}
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
                            op_b = opcode[5] ? {16'd0, ir2} : r1v;
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

                        // ---- jumps: every target drops bit 0, and the
                        // cache's alignment penalty applies like Bcond ----
                        6'h06: begin                           // JMP
                            btgt = {r1v[31:1], 1'b0};
                            if (chcw_ice && btgt[1]) charge = charge + 8'd1;
                            pc <= btgt;
                        end
                        6'h2A, 6'h2B: begin                    // JR/JAL
                            if (opcode == 6'h2B)
                                gpr_write(5'd31, pc + 32'd4);
                            btgt = pc + jump_disp(ir1, ir2);
                            if (chcw_ice && btgt[1]) charge = charge + 8'd1;
                            pc <= btgt;
                        end

                        6'h12:                                 // SETF
                            gpr_write(reg2_num, {31'd0,
                                cond_true(ir1[3:0], psw_cy, psw_ov,
                                          psw_s, psw_z)});

                        // ---- system registers ----
                        6'h1C: begin                           // LDSR
                            ldsr(ir1[4:0], r2v);
                            // CHCW's clear, dump and restore commands run
                            // as walkers; interrupts wait for them. More
                            // than one at once is undefined and does
                            // nothing [beetle-vb SetSREG's exact match].
                            if (ir1[4:0] == 5'd24)
                                case ({r2v[5], r2v[4], r2v[0]})
                                    3'b001: begin              // ICC
                                        cc_idx <= r2v[31:20];
                                        cc_cnt <= r2v[19:8];
                                        cc_ph  <= 2'd0;
                                        state  <= IC_CLR;
                                    end
                                    3'b010: begin              // ICD
                                        cd_sa   <= r2v[31:8];
                                        cd_idx  <= 7'd0;
                                        cd_sub  <= 1'b0;
                                        cd_tags <= 1'b0;
                                        state   <= CD_RD;
                                    end
                                    3'b100: begin              // ICR
                                        cd_sa   <= r2v[31:8];
                                        cd_idx  <= 7'd0;
                                        cd_sub  <= 1'b0;
                                        cd_tags <= 1'b0;
                                        state   <= CR_RD;
                                    end
                                    default: ;
                                endcase
                        end
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

                        // ---- bit strings: one invocation per execute,
                        // PC held until the string completes ----
                        6'h1F: begin
                            if (!ir1[3] && ir1[2]) begin
                                // Sub-opcodes 4-7 are invalid [Scroll,
                                // CPU > Opcode Map].
                                raise(16'hFF90, 32'hFFFF_FF90, pc);
                            end else begin
                                bs_search <= !ir1[3];
                                bs_down   <= ir1[0];
                                bs_bit    <= ir1[1];
                                bs_op     <= ir1[2:0];
                                // The five descriptor registers, at their
                                // documented masks; r29 raw doubles as the
                                // search's skip counter.
                                bs_dstoff <= gpr[5'd26][4:0];
                                bs_srcoff <= gpr[5'd27][4:0];
                                bs_len    <= gpr[5'd28];
                                bs_dst    <= {gpr[5'd29][31:2], 2'b00};
                                bs_skip   <= gpr[5'd29];
                                bs_src    <= {gpr[5'd30][31:2], 2'b00};
                                bs_done   <= 1'b0;
                                pc        <= pc;
                                state     <= BS_START;
                                // First invocations carry the documented
                                // intercept, resumes just their refetch;
                                // the word accesses charge as dispatched.
                                // Slopes land on Table 5-13/5-12 figures
                                // for one-wait memory; the intercepts are
                                // the tables' one-word columns.
                                charge = gpr[5'd28] == 32'd0
                                       ? (ir1[3] ? 8'd20 : 8'd13)
                                       : bs_active ? {4'd0, fcost}
                                       : ir1[3]    ? 8'd22 : 8'd26;
                            end
                        end

                        // ---- CAXI: word read, compare, word write ----
                        6'h3A: begin
                            caxi_cmp_q <= r2v;
                            caxi_new_q <= gpr[5'd30];
                            dest_q     <= reg2_num;
                            charge = (8'd26 > {4'd0, fcost}
                                      ? 8'd26 : {4'd0, fcost})
                                     + {4'd0, dwait, 2'b00};
                            wa_read({ea_raw[31:2], 2'b00}, CAXI_CMP);
                        end

                        // ---- format VII: floating point and Nintendo's
                        // extended four, told apart by the sub-opcode in
                        // the second halfword's top bits ----
                        6'h3E: begin
                            if (ir2[15:14] != 2'b00 || ir2[13:10] == 4'h1
                                || ir2[13:10] > 4'hC) begin
                                raise(16'hFF90, 32'hFFFF_FF90, pc);
                            end else begin
                                charge = vii_base(ir2[13:10]) > {4'd0, fcost}
                                       ? vii_base(ir2[13:10])
                                       : {4'd0, fcost};
                                case (ir2[13:10])
                                    4'h8:                      // XB
                                        gpr_write(reg2_num,
                                                  {r2v[31:16], r2v[7:0],
                                                   r2v[15:8]});
                                    4'h9:                      // XH
                                        gpr_write(reg2_num,
                                                  {r2v[15:0], r2v[31:16]});
                                    4'hA:                      // REV
                                        gpr_write(reg2_num, rev32(r1v));
                                    4'hC: begin                // MPYHW
                                        // reg2 times the low 17 bits of
                                        // reg1, sign-extended -- 17, not 16
                                        // [Scroll, CPU > Nintendo].
                                        mul_a  <= {r2v[31], r2v};
                                        mul_b  <= {r1v[16], {15{r1v[16]}},
                                                   r1v[16:0]};
                                        dest_q <= reg2_num;
                                        state  <= MPYHW_DONE;
                                    end
                                    default: begin             // the FPU
                                        fpu_start <= 1'b1;
                                        fpu_op    <= ir2[13:10];
                                        fpu_a     <= r2v;
                                        fpu_b     <= r1v;
                                        dest_q    <= reg2_num;
                                        state     <= FP_WAIT;
                                    end
                                endcase
                            end
                        end

                        // ---- 0x1B, 0x32 and 0x36 are the genuinely
                        // invalid opcodes ----
                        default: raise(16'hFF90, 32'hFFFF_FF90, pc);
                        endcase
                    end
                end
            end

            // Architectural time: an executing instruction's charge
            // accumulates and each ce drains one cycle; a tick landing on
            // the charge's own clock already drains it by one. An aborted
            // instruction's remainder is forgiven -- it recharges in full
            // when it reruns after RETI.
            if (forgive)
                owed <= 8'd0;
            else if (ce && owed + charge != 8'd0)
                owed <= owed + charge - 8'd1;
            else if (!ce && charge != 8'd0)
                owed <= owed + charge;
        end
    end

endmodule

`default_nettype wire
