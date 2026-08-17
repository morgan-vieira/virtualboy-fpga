`timescale 1ns/1ps
//
// Exercises the bridge-loaded cartridge across its two clock domains and all
// the way down to the memory it lives in: APF-shaped writes on the load side
// (32-bit words, file byte 0 in bits 31:24, sequential addresses), mem_bus
// shaped reads on the CPU side, and the real pocket_sdram in between driving
// a device model that enforces what a real part enforces.
//
// The checks that can fail on hardware are the ones pinned here: the byte
// swap into little-endian halfwords, the size mask recovered from the highest
// address written (which is what mirrors the reset vector into reach), the
// full-region mirror above the image, and a reload shrinking the mask rather
// than inheriting the old image's. The memory underneath is not stubbed,
// because a stub that answers instantly hides both the loader's crossing and
// the read handshake -- the shape that deadlocked vip_draw.
//
// Bridge words are spaced the way APF spaces them. Every 32-bit write is a
// whole eight-byte SPI transaction, so the loader's one-deep mailbox has
// hundreds of nanoseconds to drain; the load loop below holds to that spacing
// and the bench fails if a word is dropped anyway.
//

module cart_rom_tb;

    reg load_clk = 1'b0;
    always #6.7 load_clk = ~load_clk;   // ~74.25 MHz, the bridge domain

    reg clk = 1'b0;
    always #12.52 clk = ~clk;           // 39.936 MHz, the CPU domain

    wire sdram_clk = ~clk;              // what the DDIO cell puts on the pin

    reg         reset_n = 1'b0;
    reg         load_begin = 1'b0;
    reg         load_wr = 1'b0;
    reg  [31:0] load_addr = 32'd0;
    reg  [31:0] load_data = 32'd0;

    reg         sel = 1'b0;
    reg  [26:1] a = 26'd0;
    wire [15:0] rdata;
    wire        ready;

    wire        mem_req;
    wire [24:0] mem_addr;
    wire        mem_we;
    wire [15:0] mem_wdata;
    wire [15:0] mem_rdata;
    wire        mem_ready;

    wire [12:0] dram_a;
    wire [1:0]  dram_ba;
    wire [15:0] dram_dq;
    wire [1:0]  dram_dqm;
    wire        dram_cke;
    wire        dram_ras_n;
    wire        dram_cas_n;
    wire        dram_we_n;

    cart_rom dut (
        .load_clk(load_clk),
        .load_begin(load_begin),
        .load_wr(load_wr),
        .load_addr(load_addr),
        .load_data(load_data),
        .clk(clk),
        .sel(sel),
        .addr(a),
        .rdata(rdata),
        .ready(ready),
        .mem_req(mem_req),
        .mem_addr(mem_addr),
        .mem_we(mem_we),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    pocket_sdram memory (
        .clk(clk),
        .reset_n(reset_n),
        .req(mem_req),
        .addr(mem_addr),
        .we(mem_we),
        .be(2'b11),
        .wdata(mem_wdata),
        .rdata(mem_rdata),
        .ready(mem_ready),
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

    // One bridge word, APF-shaped: byte at `offset` rides bits 31:24. The
    // idle tail is the SPI transaction the next word cannot start before.
    task automatic bridge_word(input [31:0] offset, input [31:0] value);
        begin
            @(negedge load_clk);
            load_wr   = 1'b1;
            load_addr = offset;
            load_data = value;
            @(negedge load_clk);
            load_wr = 1'b0;
            repeat (64) @(negedge load_clk);
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

    // mem_bus device shape: hold the select until ready, read the answer the
    // cycle after.
    task automatic read_hword(input [26:1] address, output [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1;
            a = address;
            do @(negedge clk); while (!ready);
            sel = 1'b0;
            @(negedge clk);
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
    reg [15:0] first, second;

    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1'b1;
        wait (part.initialized);

        // A 32-byte image: byte k is k^0xA5, so every position is distinct
        // and a swapped or shifted byte cannot alias a correct one.
        begin_load();
        for (i = 0; i < 32; i = i + 4) begin
            bridge_word(i, {i[7:0] ^ 8'hA5, (i[7:0]+8'd1) ^ 8'hA5,
                            (i[7:0]+8'd2) ^ 8'hA5, (i[7:0]+8'd3) ^ 8'hA5});
        end
        repeat (8) @(negedge clk);

        // Little-endian halfwords out of big-endian bridge words.
        expect_hword(26'h3800000, {8'h01 ^ 8'hA5, 8'h00 ^ 8'hA5}, "hword 0");
        expect_hword(26'h3800001, {8'h03 ^ 8'hA5, 8'h02 ^ 8'hA5}, "hword 1");
        expect_hword(26'h380000B, {8'h17 ^ 8'hA5, 8'h16 ^ 8'hA5}, "hword 11");

        // The mask mirrors every 32 bytes: halfword 21 & 0xF = 5.
        expect_hword(26'h3800015, {8'h0B ^ 8'hA5, 8'h0A ^ 8'hA5}, "mirror in-window");

        // The reset vector's view: 0xFFFFFFF0 masked to 27 bits is the top
        // of the region, which must land on the image's own last 16 bytes.
        expect_hword(26'h3FFFFF8, {8'h11 ^ 8'hA5, 8'h10 ^ 8'hA5}, "top-of-space mirror");

        // Back to back, the shape a word load has on this bus: the second
        // halfword's select goes out the moment the first answers, without
        // the select ever falling.
        @(negedge clk);
        sel = 1'b1; a = 26'h3800000;
        do @(negedge clk); while (!ready);
        a = 26'h3800001;
        @(negedge clk);
        first = rdata;
        do @(negedge clk); while (!ready);
        sel = 1'b0;
        @(negedge clk);
        second = rdata;
        if (first !== {8'h01 ^ 8'hA5, 8'h00 ^ 8'hA5}
            || second !== {8'h03 ^ 8'hA5, 8'h02 ^ 8'hA5})
            $fatal(1, "back-to-back halfwords gave %04x %04x", first, second);

        // An image past 64KB. This is the one that hardware failed on
        // 2026-08-17: the bridge write decode lived in core_top and accepted
        // only the first 64KB of the slot, so a 2MB cartridge loaded its first
        // 32768 halfwords and nothing else, the recovered mask was 64KB, and
        // the reset vector read 0xFF fill instead of the vector table. The
        // load is sparse because only the addresses matter here -- a real
        // load writes every word, and writing 128KB of them would run the
        // bench for minutes without testing anything this does not.
        begin_load();
        bridge_word(32'h00000000, 32'h11111111);
        bridge_word(32'h00008000, 32'h22222222);   // 32KB in
        bridge_word(32'h00010000, 32'h33333333);   // past the old 64KB decode
        bridge_word(32'h0001FFFC, 32'h44444444);   // last word of a 128KB image
        repeat (8) @(negedge clk);

        expect_hword(26'h3808000, 16'h3333, "past 64KB, low halfword");
        expect_hword(26'h3808001, 16'h3333, "past 64KB, high halfword");
        expect_hword(26'h380FFFE, 16'h4444, "last word of the image");

        // The mask has to have grown with the image: the top of the address
        // space must reach the image's own last halfword, which is what the
        // reset vector depends on.
        expect_hword(26'h3FFFFFF, 16'h4444, "top-of-space reaches a 128KB image");

        // A write outside the slot's window is not ours. Bridge address
        // 0x01000000 is past the 16MB a game pak can hold, so it must neither
        // land in the image nor drag the mask up with it.
        bridge_word(32'h01000000, 32'hDEADDEAD);
        repeat (8) @(negedge clk);
        expect_hword(26'h3800000, 16'h1111, "foreign bridge write left the image alone");
        expect_hword(26'h3FFFFFF, 16'h4444, "foreign bridge write left the mask alone");

        // A reload shrinks the mask: 8 bytes now, and the same top-of-space
        // address must land inside the new image, not the old one.
        begin_load();
        bridge_word(0, 32'h11223344);
        bridge_word(4, 32'h55667788);
        repeat (8) @(negedge clk);
        expect_hword(26'h3800000, 16'h2211, "reload hword 0");
        expect_hword(26'h3800003, 16'h8877, "reload hword 3");
        expect_hword(26'h3FFFFF8, 16'h2211, "reload top-of-space mirror");

        $finish;
    end

    initial begin
        #4_000_000;
        $fatal(1, "timed out");
    end

endmodule
