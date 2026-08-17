`timescale 1ns/1ps
//
// Exercises the SDRAM controller against a device model that behaves like an
// AS4C32M16MSA does, and fails the way a real part fails: it refuses to be
// read before it has been initialized, refuses a column access to a row
// nobody activated, refuses a refresh with a row still open, and drives its
// data late by tAC rather than the instant the clock edge arrives.
//
// The half-period relationship is the whole point of the model's clock. The
// part sees an inverted copy of the controller's clock (core_top forwards it
// through an output DDIO cell), so it samples our commands half a period
// after we launch them and drives read data half a period before we capture
// it. Model that wrong and every check still passes while hardware reads
// garbage, which is the failure this bench exists to catch.
//
// The handshake checks matter as much as the data. pocket_sram's release
// phase, which waits for req to fall, deadlocked vip_draw when a requester
// issued back-to-back accesses; this controller has no release phase, and
// the back-to-back sequence below is what holds it to that.
//

module pocket_sdram_tb;

    // 39.936 MHz, the CPU domain the controller shares.
    reg clk = 1'b0;
    always #12.52 clk = ~clk;

    // What the DDIO cell puts on the pin: an inverted copy, so the part's
    // sampling edge sits in the middle of one of ours.
    wire sdram_clk = ~clk;

    reg          reset_n = 1'b0;
    reg          req = 1'b0;
    reg  [24:0]  addr = 25'd0;
    reg          we = 1'b0;
    reg  [1:0]   be = 2'b11;
    reg  [15:0]  wdata = 16'd0;
    wire [15:0]  rdata;
    wire         ready;

    wire [12:0]  dram_a;
    wire [1:0]   dram_ba;
    wire [15:0]  dram_dq;
    wire [1:0]   dram_dqm;
    wire         dram_cke;
    wire         dram_ras_n;
    wire         dram_cas_n;
    wire         dram_we_n;

    pocket_sdram dut (
        .clk(clk),
        .reset_n(reset_n),
        .req(req),
        .addr(addr),
        .we(we),
        .be(be),
        .wdata(wdata),
        .rdata(rdata),
        .ready(ready),
        .dram_a(dram_a),
        .dram_ba(dram_ba),
        .dram_dq(dram_dq),
        .dram_dqm(dram_dqm),
        .dram_cke(dram_cke),
        .dram_ras_n(dram_ras_n),
        .dram_cas_n(dram_cas_n),
        .dram_we_n(dram_we_n)
    );

    sdram_model part (
        .clk(sdram_clk),
        .a(dram_a),
        .ba(dram_ba),
        .dq(dram_dq),
        .dqm(dram_dqm),
        .cke(dram_cke),
        .ras_n(dram_ras_n),
        .cas_n(dram_cas_n),
        .we_n(dram_we_n)
    );

    // The requester's half of the contract: hold req and its payload until
    // ready, sampled mid-cycle so no check races the controller's own edge,
    // then read the answer the cycle after.
    task automatic bus_write(input [24:0] a, input [1:0] lanes,
                             input [15:0] value);
        begin
            @(negedge clk);
            req = 1'b1; addr = a; we = 1'b1; be = lanes; wdata = value;
            do @(negedge clk); while (!ready);
            req = 1'b0; we = 1'b0;
        end
    endtask

    task automatic bus_read(input [24:0] a, output [15:0] value);
        begin
            @(negedge clk);
            req = 1'b1; addr = a; we = 1'b0; be = 2'b11; wdata = 16'hDEAD;
            do @(negedge clk); while (!ready);
            req = 1'b0;
            @(negedge clk);
            value = rdata;
        end
    endtask

    task automatic expect_read(input [24:0] a, input [15:0] expected,
                               input [127:0] what);
        reg [15:0] value;
        begin
            bus_read(a, value);
            if (value !== expected)
                $fatal(1, "%0s: word %07x read %04x, expected %04x",
                       what, a, value, expected);
        end
    endtask

    // Clocks from the request to ready. This is the number the CPU's wait
    // budget is spent against, so it is checked rather than assumed.
    task automatic read_latency(input [24:0] a, output integer clocks);
        begin
            @(negedge clk);
            req = 1'b1; addr = a; we = 1'b0; be = 2'b11;
            clocks = 1;
            while (!ready) begin
                @(negedge clk);
                clocks = clocks + 1;
            end
            req = 1'b0;
            @(negedge clk);
        end
    endtask

    reg [15:0] got_a, got_b;
    integer refreshes_before, refreshes_after;
    integer hit_clocks, miss_clocks;

    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1'b1;

        // Nothing may be asked of the part until it says it finished the
        // 200 us walk; the model fatals on any access before then.
        wait (part.initialized);

        bus_write(25'd0, 2'b11, 16'h1234);
        bus_write(25'd1, 2'b11, 16'h5678);
        expect_read(25'd0, 16'h1234, "first word");
        expect_read(25'd1, 16'h5678, "second word");

        // rdata holds between accesses, the way block RAM's does.
        repeat (5) @(negedge clk);
        if (rdata !== 16'h5678)
            $fatal(1, "rdata did not hold between accesses: %04x", rdata);

        // Byte lanes: each half of a halfword written alone.
        bus_write(25'd2, 2'b11, 16'h0000);
        bus_write(25'd2, 2'b01, 16'hFFAA);
        expect_read(25'd2, 16'h00AA, "low lane only");
        bus_write(25'd2, 2'b10, 16'h55FF);
        expect_read(25'd2, 16'h55AA, "high lane only");

        // A row miss and a bank change, which cost a precharge and an
        // activate the controller has to sequence itself.
        bus_write(25'h1000, 2'b11, 16'hBEEF);   // row 1
        bus_write(25'h0400, 2'b11, 16'hCAFE);   // bank 1
        expect_read(25'h1000, 16'hBEEF, "other row");
        expect_read(25'h0400, 16'hCAFE, "other bank");
        expect_read(25'd0, 16'h1234, "back to row 0");

        // What a cartridge read costs. The machine charges two wait states
        // for one at reset and one when the game sets ROM1W, which is three
        // and two 20 MHz cycles -- six and four of these clocks. A page hit
        // has to fit inside the tighter of those or every uncached read
        // steals time from the emulated CPU.
        expect_read(25'd0, 16'h1234, "warm the row");
        read_latency(25'd1, hit_clocks);
        if (hit_clocks > 4)
            $fatal(1, "a page hit took %0d clocks, the one-wait budget is 4",
                   hit_clocks);

        read_latency(25'h1000, miss_clocks);    // another row
        if (miss_clocks > 6)
            $fatal(1, "a row miss took %0d clocks, the two-wait budget is 6",
                   miss_clocks);

        // Back to back, the shape the CPU's word access has: the next
        // request goes out the moment ready lands, without req ever falling.
        // A controller that waited for req to drop would hang here.
        @(negedge clk);
        req = 1'b1; addr = 25'd0; we = 1'b0; be = 2'b11;
        do @(negedge clk); while (!ready);
        addr = 25'd1;                       // new access, req never dropped
        @(negedge clk);
        got_a = rdata;
        do @(negedge clk); while (!ready);
        req = 1'b0;
        @(negedge clk);
        got_b = rdata;
        if (got_a !== 16'h1234 || got_b !== 16'h5678)
            $fatal(1, "back-to-back reads gave %04x %04x, expected 1234 5678",
                   got_a, got_b);

        // Refresh keeps running underneath, and data survives it. 8192 rows
        // in 64 ms is one refresh every 7.8125 us; the controller aims at
        // 7.5 us, so 20 us must contain at least two.
        refreshes_before = part.refreshes;
        repeat (800) @(negedge clk);
        refreshes_after = part.refreshes;
        if (refreshes_after - refreshes_before < 2)
            $fatal(1, "only %0d refreshes in 20 us, expected at least 2",
                   refreshes_after - refreshes_before);
        expect_read(25'd0, 16'h1234, "after refresh");
        expect_read(25'h1000, 16'hBEEF, "other row after refresh");

        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "timed out");
    end

endmodule
