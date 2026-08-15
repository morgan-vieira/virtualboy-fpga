`default_nettype none
//
// The NVC's timer: a 16-bit down-counter on a 20 us base tick [Scroll,
// Timer]. An internal tick counter increments modulo 5 every 20 us whether
// or not the timer is enabled; T-Clk-Sel decides if the counter decrements
// on every tick (20 us) or only when the tick counter wraps to zero
// (100 us). The base tick is 400 architectural cycles counted off ce, so
// 20 us is exact against cpu_clock_enable's 20 MHz and cannot drift from
// video. Bus accesses land a few fast clocks before their architectural
// instant (the fetch model in TODO section 3); the skew is under one CPU
// cycle and nothing software-visible can resolve it.
//
// Where the scroll runs out, MiSTer's vue.v decides, being the RTL
// reference: the base tick and tick counter free-run through writes, and a
// reload write turns the next count tick into a reload instead of a
// decrement -- which is what "resets the current timer tick to the
// beginning of its wait interval" comes out as on a base that never stops.
// beetle-vb (timer.c) instead defers the counter load to the next tick and
// restarts its divider on enable, but the scroll documents the immediate
// load and the always-running tick, so the document wins. Reset leaves the
// counter 0xFFFF and the reload 0x0000 [Scroll, System Reset > Timer] --
// the one moment they can differ. Both references reset the reload to
// 0xFFFF instead; we follow the document, and say so here on purpose.
//

module timer (
    input  wire logic        clk,
    input  wire logic        reset_n,
    input  wire logic        ce,       // architectural 20 MHz tick

    // mem_bus device shape: sel one clock, the answer registered the next.
    input  wire logic        sel,
    input  wire logic [26:1] addr,
    input  wire logic        we,
    input  wire logic [1:0]  be,
    input  wire logic [15:0] wdata,
    output logic      [15:0] rdata,

    // Held until acknowledged; core_top presents it at level 1 (0xFE10).
    output wire logic        irq
);

    localparam int TICKS_20US = 400;   // 20 us of 20 MHz architectural time

    logic [8:0]  presc;          // 0..399, one wrap per 20 us
    logic [2:0]  subtick;        // the scroll's modulo-5 tick counter
    logic [15:0] counter;
    logic [15:0] reload;
    logic        reload_pending; // next count tick reloads, not decrements
    logic        clk_sel;        // TCR bit 4: 1 = 20 us, 0 = 100 us
    logic        int_en;         // TCR bit 3, Tim-Z-Int
    logic        enb;            // TCR bit 0, T-Enb
    logic        z_stat;         // TCR bit 1, sticky until Z-Stat-Clr acts
    logic        irq_q;

    // Registers sit four bytes apart so byte, halfword and word accesses
    // all land [Scroll, Miscellaneous Hardware]; only byte lane 0 carries
    // a register, and odd-byte or off-register lanes fall through.
    // Decoding addr & 0xFF mirrors the block every 0x100 through the
    // region -- beetle-vb's HWCTRL choice (libretro.cpp), an
    // implementation choice rather than documented hardware.
    wire logic wr     = sel && we && be[0];
    wire logic wr_tlr = wr && addr[7:1] == 7'h0C;   // TLR, 0x02000018
    wire logic wr_thr = wr && addr[7:1] == 7'h0E;   // THR, 0x0200001C
    wire logic wr_tcr = wr && addr[7:1] == 7'h10;   // TCR, 0x02000020

    wire logic reload_wr = wr_tlr || wr_thr;

    // Writing either half loads the whole pair into the counter at once
    // [Scroll, Timer > Counter and Reload].
    wire logic [15:0] wr_counter = wr_thr ? {wdata[7:0], reload[7:0]}
                                          : {reload[15:8], wdata[7:0]};
    wire logic wr_zero_hit = reload_wr && counter != 16'd0
                                       && wr_counter == 16'd0;

    wire logic base_tick  = ce && presc == TICKS_20US - 1;
    // A reload write swallows a same-clock tick: the interval restarts.
    wire logic count_tick = base_tick && enb && (clk_sel || subtick == 3'd4)
                            && !reload_wr;

    // T-Clk-Sel switching 0 to 1 mid-interval decrements at once, and that
    // can itself raise the interrupt [Scroll, Timer Control]. MiSTer
    // decrements whether or not the timer is enabled and beetle-vb leaves
    // the quirk out, so MiSTer decides. subtick_now covers a write landing
    // on the base tick's own clock.
    wire logic [2:0] subtick_now = !base_tick ? subtick :
                                   subtick == 3'd4 ? 3'd0 : subtick + 3'd1;
    wire logic sel_tick = wr_tcr && !clk_sel && wdata[4]
                          && subtick_now != 3'd0;

    wire logic counter_tick = count_tick || sel_tick;
    wire logic zero_hit = counter_tick && !reload_pending
                          && counter == 16'd1;

    // Z-Stat-Clr acts when the counter is non-zero or the timer is off.
    // Enabled at zero it does nothing (the faulty clear), and clearing in
    // the write that also disables does nothing either -- old enb on
    // purpose, "while the timer is enabled" [Scroll, Timer Control]. A
    // same-clock decrement to zero outranks it, as in MiSTer.
    wire logic z_clr = wr_tcr && wdata[2]
                       && (!enb || (wdata[0] && counter != 16'd0))
                       && !zero_hit;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            presc          <= '0;
            // The scroll initializes the tick counter to zero and wonders
            // if hardware really holds 4 counting down; the wrap lands on
            // the same tick either way, and MiSTer counts up from zero.
            subtick        <= '0;
            counter        <= 16'hffff;
            reload         <= 16'h0000;
            reload_pending <= 1'b0;
            clk_sel        <= 1'b0;
            int_en         <= 1'b0;
            enb            <= 1'b0;
            z_stat         <= 1'b0;
            irq_q          <= 1'b0;
        end else begin
            // Both free-run even with the timer disabled [Scroll, Timer].
            if (ce) presc <= base_tick ? '0 : presc + 9'd1;
            if (base_tick) subtick <= subtick == 3'd4 ? 3'd0 : subtick + 3'd1;

            if (wr_tcr) begin
                clk_sel <= wdata[4];
                int_en  <= wdata[3];
                enb     <= wdata[0];
            end

            // A count tick: a pending or exhausted counter reloads, the
            // rest decrement. The timer loading a reload of zero raises
            // nothing [Scroll, Timer Zero Interrupt]; the interrupt gate
            // is old int_en, MiSTer's choice for a same-write flip.
            if (counter_tick) begin
                if (reload_pending) begin
                    counter        <= reload;
                    reload_pending <= 1'b0;
                end else if (counter == 16'd0) begin
                    counter <= reload;
                end else begin
                    counter <= counter - 16'd1;
                    if (counter == 16'd1 && int_en) irq_q <= 1'b1;
                end
            end

            // A reload write: the byte lands in the reload, the pair in
            // the counter, and the interval restarts through
            // reload_pending. Landing the counter on zero is itself an
            // interrupt condition, enabled or not -- MiSTer's reading of
            // the scroll's unqualified "by writing to the reload
            // registers"; beetle-vb doesn't model write-induced zeroes.
            if (reload_wr) begin
                if (wr_tlr) reload[7:0]  <= wdata[7:0];
                else        reload[15:8] <= wdata[7:0];
                counter        <= wr_counter;
                reload_pending <= 1'b1;
                if (wr_zero_hit && int_en) irq_q <= 1'b1;
            end

            // Z-Stat is a level made sticky: set whenever the counter sits
            // at zero enabled, cleared only by a Z-Stat-Clr that acts
            // [Scroll, Timer Control]. The order makes a same-clock set
            // win, which the faulty clear would force anyway.
            if (z_clr) z_stat <= 1'b0;
            if (enb && counter == 16'd0) z_stat <= 1'b1;

            // Acknowledge last so an explicit Tim-Z-Int clear always
            // lands; a surviving z_clr was already fenced off zero_hit.
            if (wr_tcr && (!wdata[3] || z_clr)) irq_q <= 1'b0;
        end
    end

    // Reads return the live counter -- which is why software is told to
    // stop the timer first -- and TCR's unused bits and Z-Stat-Clr read as
    // ones [Scroll, Timer > Counter and Reload; Timer Control]. The high
    // byte reads zero the way beetle-vb's byte-wide HWCTRL_Read comes
    // back zero-extended.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) rdata <= 16'd0;
        else if (sel) begin
            case (addr[7:1])
                7'h0C:   rdata <= {8'd0, counter[7:0]};
                7'h0E:   rdata <= {8'd0, counter[15:8]};
                7'h10:   rdata <= {8'd0, 3'b111, clk_sel, int_en, 1'b1,
                                   z_stat, enb};
                default: rdata <= 16'd0;
            endcase
        end
    end

    assign irq = irq_q;

endmodule

`default_nettype wire
