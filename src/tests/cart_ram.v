`timescale 1ns/1ps
//
// Exercises the save RAM across its two clock domains and in both directions:
// APF-shaped bridge writes at boot, CPU halfword and byte accesses while the
// game runs, and the bridge readback APF performs at shutdown to write the
// file back out.
//
// The checks that can only fail on hardware are the ones pinned here. The
// cells are eight bits wide, so a halfword reads 0xFF above the byte and a
// write to the upper lane alone does nothing. The bridge's byte order has to
// survive a round trip, or a save written on quit comes back scrambled on the
// next boot -- the one failure nobody would see until they had already lost a
// game's progress. And the size mask has to narrow to the loaded file the way
// the cartridge's narrows to the image, or a small save mirrors into a large
// one.
//
// Bridge words are spaced the way APF spaces them, for the reason
// src/tests/cart_rom.v records: a whole eight-byte SPI transaction per access.
// The watchdog below fails the bench if a request ever lands on a walk that
// has not finished, which is the assumption that spacing buys.
//

module cart_ram_tb;

    reg bridge_clk = 1'b0;
    always #6.7 bridge_clk = ~bridge_clk;   // ~74.25 MHz, the bridge domain

    reg clk = 1'b0;
    always #12.52 clk = ~clk;               // 39.936 MHz, the CPU domain

    reg         load_begin = 1'b0;
    reg         bridge_wr = 1'b0;
    reg         bridge_rd = 1'b0;
    reg  [31:0] bridge_addr = 32'd0;
    reg  [31:0] bridge_wr_data = 32'd0;
    wire [31:0] bridge_rd_data;
    wire [31:0] save_bytes;

    reg         sel = 1'b0;
    reg  [26:1] a = 26'd0;
    reg         we = 1'b0;
    reg  [1:0]  be = 2'b11;
    reg  [15:0] wdata = 16'd0;
    wire [15:0] rdata;

    localparam [31:0] SLOT = 32'h01000000;   // the save's bridge window
    localparam [26:1] BASE = 26'h3000000;    // 0x06000000 as a halfword index

    cart_ram dut (
        .bridge_clk(bridge_clk),
        .load_begin(load_begin),
        .bridge_wr(bridge_wr),
        .bridge_rd(bridge_rd),
        .bridge_addr(bridge_addr),
        .bridge_wr_data(bridge_wr_data),
        .bridge_rd_data(bridge_rd_data),
        .save_bytes(save_bytes),
        .clk(clk),
        .sel(sel),
        .addr(a),
        .we(we),
        .be(be),
        .wdata(wdata),
        .rdata(rdata)
    );

    // One request in flight, held by APF's own pacing. If that ever stops
    // being true the save corrupts silently, so say so loudly here instead.
    always @(posedge bridge_clk) begin
        if (dut.walking && (bridge_wr || bridge_rd) && dut.in_slot)
            $fatal(1, "bridge request landed on an unfinished walk");
    end

    task automatic begin_load;
        begin
            @(negedge bridge_clk);
            load_begin = 1'b1;
            @(negedge bridge_clk);
            load_begin = 1'b0;
        end
    endtask

    // One bridge word, APF-shaped: the byte at `offset` rides bits 31:24. The
    // idle tail is the SPI transaction the next access cannot start before.
    task automatic bridge_write(input [31:0] offset, input [31:0] value);
        begin
            @(negedge bridge_clk);
            bridge_wr      = 1'b1;
            bridge_addr    = SLOT + offset;
            bridge_wr_data = value;
            @(negedge bridge_clk);
            bridge_wr = 1'b0;
            repeat (64) @(negedge bridge_clk);
        end
    endtask

    task automatic bridge_read(input [31:0] offset, output [31:0] value);
        begin
            @(negedge bridge_clk);
            bridge_rd   = 1'b1;
            bridge_addr = SLOT + offset;
            @(negedge bridge_clk);
            bridge_rd = 1'b0;
            repeat (64) @(negedge bridge_clk);
            value = bridge_rd_data;
        end
    endtask

    task automatic expect_word(input [31:0] offset, input [31:0] expected,
                               input [255:0] what);
        reg [31:0] value;
        begin
            bridge_read(offset, value);
            if (value !== expected)
                $fatal(1, "%0s: bridge offset %0h read %08x, expected %08x",
                       what, offset, value, expected);
        end
    endtask

    // mem_bus device shape: the select goes out for one cycle and the answer
    // lands the cycle after.
    task automatic read_hword(input [26:1] address, output [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1;
            we  = 1'b0;
            a   = address;
            @(negedge clk);
            sel = 1'b0;
            value = rdata;
        end
    endtask

    task automatic expect_hword(input [26:1] address, input [15:0] expected,
                                input [255:0] what);
        reg [15:0] value;
        begin
            read_hword(address, value);
            if (value !== expected)
                $fatal(1, "%0s: addr %07x read %04x, expected %04x",
                       what, address, value, expected);
        end
    endtask

    task automatic write_hword(input [26:1] address, input [1:0] lanes,
                               input [15:0] value);
        begin
            @(negedge clk);
            sel   = 1'b1;
            we    = 1'b1;
            be    = lanes;
            a     = address;
            wdata = value;
            @(negedge clk);
            sel = 1'b0;
            we  = 1'b0;
            be  = 2'b11;
        end
    endtask

    reg [31:0] word;

    initial begin
        // A save the size of a commercial pak's, loaded sparsely: only the
        // addresses matter, and the last word is what sets the mask.
        begin_load();
        bridge_write(32'h0000, 32'h00112233);
        bridge_write(32'h0100, 32'h44556677);
        bridge_write(32'h1000, 32'h8899AABB);
        bridge_write(32'h1FFC, 32'hCCDDEEFF);   // last word of 8KB
        repeat (8) @(negedge clk);

        // File order: byte 0 of the word is the first cell, and a cell is one
        // byte at one halfword address. The upper byte is the pak's unwired
        // D8-D15.
        expect_hword(BASE + 26'h0, 16'hFF00, "cell 0");
        expect_hword(BASE + 26'h1, 16'hFF11, "cell 1");
        expect_hword(BASE + 26'h2, 16'hFF22, "cell 2");
        expect_hword(BASE + 26'h3, 16'hFF33, "cell 3");
        expect_hword(BASE + 26'h100, 16'hFF44, "cell 0x100");
        expect_hword(BASE + 26'h1000, 16'hFF88, "cell 0x1000");
        expect_hword(BASE + 26'h1FFF, 16'hFFFF, "last cell");

        // The number APF flushes by. It reported zero for a save with no file
        // on the card, so the first hardware run wrote no save at all; the
        // core has to name the size it was handed instead.
        if (save_bytes !== 32'd8192)
            $fatal(1, "save_bytes is %0d after an 8KB load, expected 8192",
                   save_bytes);

        // Two cells to an address bit the array does not have, and the whole
        // 16MB region above that.
        expect_hword(BASE + 26'h2000, 16'hFF00, "mirror past the array");
        expect_hword(26'h37FFFFF, 16'hFFFF, "top of the region reaches the last cell");

        // A halfword write stores its low byte and drops the upper one.
        write_hword(BASE + 26'h100, 2'b11, 16'hAA5A);
        expect_hword(BASE + 26'h100, 16'hFF5A, "halfword write keeps the low byte only");

        // The upper lane alone is a write the pak cannot make: one write
        // enable pin, no lane strobe, and only D0-D7 wired. MiSTer drops it.
        write_hword(BASE + 26'h100, 2'b10, 16'h7777);
        expect_hword(BASE + 26'h100, 16'hFF5A, "upper-lane write left the cell alone");

        // The low lane alone is what a byte store to an even address makes.
        write_hword(BASE + 26'h100, 2'b01, 16'h00C3);
        expect_hword(BASE + 26'h100, 16'hFFC3, "low-lane write stored");

        // The round trip that decides whether a save survives a power cycle:
        // what the CPU wrote comes back out of the bridge in file order, in
        // the same lane the load put it in, with its neighbours untouched.
        expect_word(32'h0100, 32'hC3556677, "readback of a CPU-modified word");
        expect_word(32'h0000, 32'h00112233, "readback of an untouched word");
        expect_word(32'h1FFC, 32'hCCDDEEFF, "readback of the last word");

        // A bridge write outside the save's window is not ours: not the
        // cells, and not the mask either.
        @(negedge bridge_clk);
        bridge_wr      = 1'b1;
        bridge_addr    = 32'h02000000;
        bridge_wr_data = 32'hDEADBEEF;
        @(negedge bridge_clk);
        bridge_wr = 1'b0;
        repeat (64) @(negedge bridge_clk);
        expect_hword(BASE + 26'h0, 16'hFF00, "foreign bridge write left cell 0 alone");
        expect_hword(BASE + 26'h1FFF, 16'hFFFF, "foreign bridge write left the mask alone");

        // A smaller save narrows the mask, the way a smaller image narrows
        // the cartridge's: 8 cells now, so the ninth is the first again.
        begin_load();
        bridge_write(32'h0000, 32'h01020304);
        bridge_write(32'h0004, 32'h05060708);
        repeat (8) @(negedge clk);
        expect_hword(BASE + 26'h0, 16'hFF01, "reload cell 0");
        expect_hword(BASE + 26'h7, 16'hFF08, "reload cell 7");
        expect_hword(BASE + 26'h8, 16'hFF01, "an 8-cell save mirrors at 8");
        expect_hword(26'h37FFFFF, 16'hFF08, "top of the region reaches an 8-cell save");

        // And the flush shrinks with it, or the file grows a mirror of itself.
        if (save_bytes !== 32'd8)
            $fatal(1, "save_bytes is %0d after an 8-byte load, expected 8",
                   save_bytes);

        $finish;
    end

    initial begin
        #4_000_000;
        $fatal(1, "timed out");
    end

endmodule
