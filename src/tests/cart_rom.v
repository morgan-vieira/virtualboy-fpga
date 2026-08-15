`timescale 1ns/1ps
//
// Exercises the bridge-loaded cartridge ROM across its two clock domains:
// APF-shaped writes on the load side (32-bit words, file byte 0 in bits
// 31:24, sequential addresses), mem_bus-shaped reads on the CPU side. The
// checks that can fail on hardware are the ones pinned here: the byte swap
// into little-endian halfwords, the size mask recovered from the highest
// address written (which is what mirrors the reset vector into reach), the
// full-region mirror above the 64KB window, and a reload shrinking the mask
// rather than inheriting the old image's.
//
// The domains are sequenced the way APF sequences them -- loads finish
// before reads begin -- so no check races the clock boundary, matching the
// reset-held-while-loading contract the module documents.
//

module cart_rom_tb;

    reg load_clk = 1'b0;
    always #6.7 load_clk = ~load_clk;   // ~74.25 MHz, the bridge domain

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg         load_begin = 1'b0;
    reg         load_wr = 1'b0;
    reg  [31:0] load_addr = 32'd0;
    reg  [31:0] load_data = 32'd0;

    reg         sel = 1'b0;
    reg  [26:1] a = 26'd0;
    wire [15:0] rdata;

    cart_rom dut (
        .load_clk(load_clk),
        .load_begin(load_begin),
        .load_wr(load_wr),
        .load_addr(load_addr),
        .load_data(load_data),
        .clk(clk),
        .sel(sel),
        .addr(a),
        .rdata(rdata)
    );

    // One bridge word, APF-shaped: byte at `offset` rides bits 31:24.
    task automatic bridge_word(input [31:0] offset, input [31:0] value);
        begin
            @(negedge load_clk);
            load_wr   = 1'b1;
            load_addr = offset;
            load_data = value;
            @(negedge load_clk);
            load_wr = 1'b0;
        end
    endtask

    task automatic begin_load;
        begin
            @(negedge load_clk);
            load_begin = 1'b1;
            @(negedge load_clk);
            load_begin = 1'b0;
        end
    endtask

    // mem_bus device shape: the answer lands the cycle after the access.
    task automatic read_hword(input [26:1] address, output [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1;
            a = address;
            @(negedge clk);
            sel = 1'b0;
            #1;
            value = rdata;
        end
    endtask

    task automatic expect_hword(input [26:1] address, input [15:0] expected,
                                input [127:0] what);
        reg [15:0] value;
        begin
            read_hword(address, value);
            if (value !== expected)
                $fatal(1, "%0s: addr %07x read %04x, expected %04x",
                       what, address, value, expected);
        end
    endtask

    integer i;

    initial begin
        // A 32-byte image: byte k is k^0xA5, so every position is distinct
        // and a swapped or shifted byte cannot alias a correct one.
        begin_load();
        for (i = 0; i < 32; i = i + 4) begin
            bridge_word(i, {i[7:0] ^ 8'hA5, (i[7:0]+8'd1) ^ 8'hA5,
                            (i[7:0]+8'd2) ^ 8'hA5, (i[7:0]+8'd3) ^ 8'hA5});
        end
        repeat (4) @(negedge clk);

        // Little-endian halfwords out of big-endian bridge words.
        expect_hword(26'h3800000, {8'h01 ^ 8'hA5, 8'h00 ^ 8'hA5}, "hword 0");
        expect_hword(26'h3800001, {8'h03 ^ 8'hA5, 8'h02 ^ 8'hA5}, "hword 1");
        expect_hword(26'h380000B, {8'h17 ^ 8'hA5, 8'h16 ^ 8'hA5}, "hword 11");

        // The mask mirrors every 32 bytes: halfword 21 & 0xF = 5.
        expect_hword(26'h3800015, {8'h0B ^ 8'hA5, 8'h0A ^ 8'hA5}, "mirror in-window");

        // The reset vector's view: 0xFFFFFFF0 masked to 27 bits is the top
        // of the region, which must land on the image's own last 16 bytes.
        expect_hword(26'h3FFFFF8, {8'h11 ^ 8'hA5, 8'h10 ^ 8'hA5}, "top-of-space mirror");

        // A reload shrinks the mask: 8 bytes now, and the same top-of-space
        // address must land inside the new image, not the old one.
        begin_load();
        bridge_word(0, 32'h11223344);
        bridge_word(4, 32'h55667788);
        repeat (4) @(negedge clk);
        expect_hword(26'h3800000, 16'h2211, "reload hword 0");
        expect_hword(26'h3800003, 16'h8877, "reload hword 3");
        expect_hword(26'h3FFFFF8, 16'h2211, "reload top-of-space mirror");

        $finish;
    end

    initial begin
        #1_000_000;
        $fatal(1, "timed out");
    end

endmodule
