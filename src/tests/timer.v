`timescale 1ns/1ps
//
// Exercises the timer through its bus registers against absolute
// architectural time. ce fires every second clock and ce_count counts the
// same pulses the prescaler sees, so the 20 us grid is knowable in advance:
// with the prescaler free-running from reset, fast-mode decrements may only
// land on multiples of 400 ce and slow-mode ones on multiples of 2000 --
// asserted at every measurement, which is what pins the always-running tick
// counter across disables and writes.
//
// The behavior checks follow TODO section 6 line by line: the reset
// counter/reload disagreement, reads returning the live counter, a reload
// write restarting the interval in flight, the rate-change decrement both
// with the tick counter zero and non-zero, the faulty Z-Stat-Clr, the
// disable-and-clear write that acknowledges nothing, both acknowledge
// paths, write-induced zeroes enabled and disabled, and the reload-of-zero
// that raises no interrupt while zero status shows.
//

module timer_tb;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    // ce as a tick, not a clock: every second cycle, nothing like the
    // hardware's 125/832 -- the timer may only count pulses.
    reg ce = 1'b0;
    always @(posedge clk) ce <= ~ce;

    integer ce_count = 0;

    reg         reset_n = 1'b0;
    reg         sel = 1'b0;
    reg  [26:1] a = 26'd0;
    reg         we = 1'b0;
    reg  [1:0]  be = 2'b00;
    reg  [15:0] wd = 16'd0;
    wire [15:0] rdata;
    wire        irq;

    timer dut (
        .clk(clk),
        .reset_n(reset_n),
        .ce(ce),
        .sel(sel),
        .addr(a),
        .we(we),
        .be(be),
        .wdata(wd),
        .rdata(rdata),
        .irq(irq)
    );

    always @(posedge clk) if (reset_n && ce) ce_count = ce_count + 1;

    localparam [26:1] TLR = {3'd2, 16'h0000, 7'h0C};   // 0x02000018
    localparam [26:1] THR = {3'd2, 16'h0000, 7'h0E};   // 0x0200001C
    localparam [26:1] TCR = {3'd2, 16'h0000, 7'h10};   // 0x02000020

    // ------------------------------------------------------------------
    // Bus plumbing, mem_bus device shape: sel one clock, answer the next.
    // ------------------------------------------------------------------

    task automatic bus_write(input [26:1] address, input [1:0] lanes,
                             input [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b1; a = address; be = lanes; wd = value;
            @(negedge clk);
            sel = 1'b0; we = 1'b0;
        end
    endtask

    // A register write the way software does it: byte store, low lane.
    // The high lane carries x so a lane leak lands as x, never as luck.
    task automatic write8(input [26:1] address, input [7:0] value);
        bus_write(address, 2'b01, {8'hxx, value});
    endtask

    task automatic read16(input [26:1] address, output [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b0; a = address;
            @(negedge clk);
            sel = 1'b0;
            #1;
            value = rdata;
        end
    endtask

    task automatic expect16(input [26:1] address, input [15:0] expected,
                            input string what);
        reg [15:0] value;
        begin
            read16(address, value);
            if (value !== expected)
                $fatal(1, "%0s: addr %07x read %04x, expected %04x",
                       what, address, value, expected);
        end
    endtask

    task automatic expect_irq(input v, input string what);
        if (irq !== v)
            $fatal(1, "%0s: irq is %b, expected %b", what, irq, v);
    endtask

    // Z-Stat rides TCR bit 1; the rest of the read byte is pinned too, so
    // a stuck unused bit or a dropped always-set Z-Stat-Clr cannot hide.
    task automatic expect_tcr(input clk_sel, input int_en, input z_stat,
                              input enb, input string what);
        expect16(TCR, {8'd0, 3'b111, clk_sel, int_en, 1'b1, z_stat, enb},
                 what);
    endtask

    task automatic wait_until_ce(input integer target);
        while (ce_count < target) @(negedge clk);
    endtask

    // Watches the live counter for its next change and reports when it
    // moved, in absolute ce. The grid assertions ride on this timestamp.
    task automatic wait_change(input integer max_ce, input string what,
                               output integer at_ce);
        reg [15:0] v;
        integer guard;
        begin
            v = dut.counter;
            guard = ce_count + max_ce;
            while (dut.counter === v) begin
                @(negedge clk);
                if (ce_count > guard)
                    $fatal(1, "%0s: counter stuck at %04x for %0d ce",
                           what, v, max_ce);
            end
            at_ce = ce_count;
        end
    endtask

    task automatic expect_grid(input integer at_ce, input integer grid,
                               input string what);
        if (at_ce % grid !== 0)
            $fatal(1, "%0s: change at ce %0d, off the %0d-ce grid",
                   what, at_ce, grid);
    endtask

    // Waits for the counter to sit at a value. Wanted where a change-watch
    // would lie: a reload tick that lands the value already held moves
    // nothing, so counting changes miscounts ticks.
    task automatic wait_value(input [15:0] want, input integer max_ce,
                              input string what);
        integer guard;
        begin
            guard = ce_count + max_ce;
            while (dut.counter !== want) begin
                @(negedge clk);
                if (ce_count > guard)
                    $fatal(1, "%0s: counter %04x never reached %04x in %0d ce",
                           what, dut.counter, want, max_ce);
            end
        end
    endtask

    integer t0, t1;
    reg [15:0] v16;

    initial begin
        repeat (8) @(negedge clk);
        reset_n = 1'b1;
        ce_count = 0;

        // ---- reset state: TCR 0xE4, counter 0xFFFF, and the documented
        // counter/reload disagreement -- a TLR write pairs the new low
        // byte with the reload's high byte, which must be 0x00, not the
        // counter's 0xFF [Scroll, System Reset > Timer] ----
        expect_tcr(0, 0, 0, 0, "reset TCR");
        expect16(TLR, 16'h00ff, "reset TLR");
        expect16(THR, 16'h00ff, "reset THR");
        write8(TLR, 8'h34);
        expect16(TLR, 16'h0034, "counter low after TLR write");
        expect16(THR, 16'h0000, "reset reload high byte is zero");

        // ---- decode edges: an odd-lane write misses the register, an
        // off-register halfword reads zero, a halfword write takes only
        // its low byte, and the block mirrors through the region ----
        bus_write(TLR, 2'b10, {8'h77, 8'hxx});
        expect16(TLR, 16'h0034, "odd byte lane ignored");
        expect16({3'd2, 16'h0000, 7'h0D}, 16'h0000, "0x1A reads zero");
        bus_write(THR, 2'b11, 16'hab12);
        expect16(THR, 16'h0012, "halfword write takes the low byte");
        expect16({3'd2, 16'habcd, 7'h0C}, 16'h0034, "mirror through the region");

        // ---- fast mode counts on the 400-ce grid: reload 5, enabled at
        // 20 us. The first tick after a write reloads instead of
        // decrementing, then every 400 ce, and hitting zero sets Z-Stat
        // but no interrupt with Tim-Z-Int off ----
        write8(THR, 8'h00);
        write8(TLR, 8'h05);
        write8(TCR, 8'h11);
        wait_change(900, "first fast decrement", t0);
        expect_grid(t0, 400, "first fast decrement");
        expect16(TLR, 16'h0004, "live counter read mid-count");
        wait_change(500, "second fast decrement", t1);
        if (t1 - t0 !== 400)
            $fatal(1, "fast interval: %0d ce, expected 400", t1 - t0);
        wait_change(500, "3 to 2", t0);
        wait_change(500, "2 to 1", t0);
        wait_change(500, "1 to 0", t0);
        expect_grid(t0, 400, "decrement to zero");
        expect16(TLR, 16'h0000, "counter at zero");
        expect_irq(1'b0, "no irq with Tim-Z-Int off");
        expect_tcr(1, 0, 1, 1, "Z-Stat set at zero");
        wait_change(500, "reload after zero", t1);
        if (t1 - t0 !== 400)
            $fatal(1, "zero-to-reload interval: %0d ce, expected 400", t1 - t0);
        expect16(TLR, 16'h0005, "counter reloaded");
        expect_tcr(1, 0, 1, 1, "Z-Stat sticky through the reload");

        // ---- a reload write mid-interval restarts the tick in flight:
        // written 200 ce past a decrement, the tick at +400 reloads
        // instead of decrementing, so the first decrement lands at +800
        // rather than +400 ----
        wait_change(500, "decrement before restart", t0);
        wait_until_ce(t0 + 200);
        write8(TLR, 8'h05);
        expect16(TLR, 16'h0005, "reload write loads the counter at once");
        wait_change(900, "first decrement after restart", t1);
        if (t1 - t0 !== 800)
            $fatal(1, "restart: decrement %0d ce after the last, expected 800",
                   t1 - t0);

        // ---- Z-Stat-Clr acts when the counter is non-zero ----
        write8(TCR, 8'h15);
        expect_tcr(1, 0, 0, 1, "Z-Stat-Clr with counter non-zero");

        // ---- slow mode rides the modulo-5 wrap: decrements land on the
        // 2000-ce grid the tick counter has kept since reset ----
        write8(TCR, 8'h01);
        write8(TLR, 8'h05);
        wait_change(4500, "first slow decrement", t0);   // pending eats a wrap
        expect_grid(t0, 2000, "first slow decrement");
        wait_change(2500, "second slow decrement", t1);
        if (t1 - t0 !== 2000)
            $fatal(1, "slow interval: %0d ce, expected 2000", t1 - t0);

        // ---- the rate-change quirk, both ways. Just after a wrap the
        // tick counter is zero: switching 0 to 1 decrements nothing.
        // Mid-cycle it is non-zero: the switch decrements at once,
        // before any 400-ce tick can [Scroll, Timer Control] ----
        wait_until_ce(t1 + 200);          // tick counter still zero
        v16 = dut.counter;
        write8(TCR, 8'h11);
        repeat (4) @(negedge clk);
        if (dut.counter !== v16)
            $fatal(1, "rate change with tick counter zero decremented");
        write8(TCR, 8'h01);               // back to slow, no quirk on 1->0
        wait_until_ce(t1 + 600);          // one 20 us tick in: non-zero
        v16 = dut.counter;
        write8(TCR, 8'h11);
        repeat (4) @(negedge clk);
        if (dut.counter !== v16 - 16'd1)
            $fatal(1, "rate change with tick counter non-zero: %04x, expected %04x",
                   dut.counter, v16 - 16'd1);
        write8(TCR, 8'h00);

        // ---- the zero interrupt through counting: reload 2, 20 us,
        // Tim-Z-Int on. Disabling alone acknowledges nothing; clearing
        // Tim-Z-Int does; re-enabling it does not replay an acknowledged
        // interrupt; Z-Stat survives until Z-Stat-Clr acts disabled ----
        write8(TLR, 8'h02);
        write8(TCR, 8'h19);
        wait_value(16'h0000, 2000, "count to zero");
        expect_irq(1'b1, "irq on reaching zero");
        write8(TCR, 8'h18);                    // disable, Tim-Z-Int still set
        expect_irq(1'b1, "disable alone is no acknowledge");
        expect_tcr(1, 1, 1, 0, "Z-Stat held while disabled");
        write8(TCR, 8'h10);                    // clear Tim-Z-Int: acknowledge
        expect_irq(1'b0, "Tim-Z-Int clear acknowledges");
        expect_tcr(1, 0, 1, 0, "Z-Stat outlives the acknowledge");
        write8(TCR, 8'h18);                    // re-arm, timer still off
        repeat (8) @(negedge clk);
        expect_irq(1'b0, "an acknowledged interrupt does not replay");
        write8(TCR, 8'h14);                    // Z-Stat-Clr, disabled at zero
        expect_tcr(1, 0, 0, 0, "Z-Stat-Clr acts disabled at zero");

        // ---- enabling at zero sets Z-Stat again (beetle-vb's tick
        // behavior; MiSTer never re-raises status) and the faulty clear
        // leaves it: enabled at zero, Z-Stat-Clr does nothing ----
        write8(TCR, 8'h11);
        repeat (4) @(negedge clk);
        expect_tcr(1, 0, 1, 1, "Z-Stat sets on enabling at zero");
        expect_irq(1'b0, "no irq from enabling at zero");
        write8(TCR, 8'h15);
        expect_tcr(1, 0, 1, 1, "faulty clear: enabled at zero holds");

        // ---- disable-and-clear in one write acknowledges nothing: with
        // the irq latched, TCR taking T-Enb low and Z-Stat-Clr high in
        // the same write leaves both status and interrupt; the same write
        // repeated once disabled clears both [Scroll, Timer Control] ----
        write8(TLR, 8'h02);
        write8(TCR, 8'h19);
        wait_value(16'h0000, 2000, "count to zero again");
        expect_irq(1'b1, "irq latched before disable-and-clear");
        // Past the reload the counter is non-zero, which is the one state
        // that tells this rule apart from the faulty clear above.
        wait_value(16'h0002, 600, "counter reloads while status holds");
        write8(TCR, 8'h0c);
        expect_irq(1'b1, "disable-and-clear acknowledges nothing");
        expect_tcr(0, 1, 1, 0, "disable-and-clear leaves Z-Stat");
        write8(TCR, 8'h0c);
        expect_irq(1'b0, "the same write acts once disabled");
        expect_tcr(0, 1, 0, 0, "Z-Stat cleared once disabled");

        // ---- a reload write that lands the counter on zero is itself
        // the interrupt condition, no tick involved ----
        write8(TCR, 8'h19);
        write8(THR, 8'h00);
        write8(TLR, 8'h07);
        write8(TLR, 8'h00);
        repeat (4) @(negedge clk);
        expect_irq(1'b1, "write-induced zero raises at once");
        expect_tcr(1, 1, 1, 1, "write-induced zero sets Z-Stat");
        write8(TCR, 8'h11);
        expect_irq(1'b0, "acknowledged again");

        // ---- the timer loading a reload of zero raises nothing: counter
        // and reload both zero, enabled, Tim-Z-Int on -- ticks keep
        // reloading zero, Z-Stat shows, the interrupt never fires ----
        write8(TCR, 8'h19);
        wait_until_ce(ce_count + 1300);        // three-plus 20 us ticks
        expect_irq(1'b0, "reload of zero never interrupts");
        expect_tcr(1, 1, 1, 1, "zero status shows all the while");

        // ---- a write-induced zero fires even disabled -- MiSTer's
        // reading -- but Z-Stat needs the timer enabled ----
        write8(TCR, 8'h0c);                    // disable, clear the slate
        write8(TCR, 8'h0c);
        expect_irq(1'b0, "slate clear");
        write8(TCR, 8'h08);                    // disabled, Tim-Z-Int on
        write8(TLR, 8'h05);
        write8(TLR, 8'h00);
        repeat (4) @(negedge clk);
        expect_irq(1'b1, "write-induced zero fires disabled");
        expect_tcr(0, 1, 0, 0, "Z-Stat stays clear disabled");
        write8(TCR, 8'h00);
        expect_irq(1'b0, "final acknowledge");

        // ---- the grid held through every disable and write above:
        // one more slow decrement still lands on the 2000-ce line ----
        write8(TLR, 8'h05);
        write8(TCR, 8'h01);
        wait_change(4500, "closing slow decrement", t0);
        expect_grid(t0, 2000, "tick counter free-ran throughout");

        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "timed out");
    end

endmodule
