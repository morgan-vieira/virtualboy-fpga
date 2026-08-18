`timescale 1ns/1ps
`default_nettype none

// vip_memory: region decode, byte lanes, mirrors, the display port, and the
// owned-transaction arbitration with its measured CPU service times.

module vip_memory_tb;
    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic ce = 1'b0;
    logic display_clk = 1'b0;
    logic cpu_sel = 1'b0;
    logic [26:1] cpu_addr = '0;
    logic cpu_we = 1'b0;
    logic [1:0] cpu_be = '0;
    logic [15:0] cpu_wdata = '0;
    logic [15:0] cpu_rdata;
    logic ready;
    logic draw_req = 1'b0;
    logic [18:1] draw_addr = '0;
    logic draw_we = 1'b0;
    logic [1:0] draw_be = '0;
    logic [15:0] draw_wdata = '0;
    logic [15:0] draw_rdata;
    logic draw_ready;
    logic dram_req;
    logic [15:0] dram_addr;
    logic dram_we;
    logic [1:0] dram_be;
    logic [15:0] dram_wdata;
    logic [15:0] dram_rdata;
    logic dram_ready;
    logic display_buffer = 1'b0;
    logic column_lock = 1'b0;
    logic [7:0] cta_locked_left = '0;
    logic [7:0] cta_locked_right = '0;
    logic [8:0] display_x = '0;
    logic [7:0] display_y = '0;
    logic [1:0] display_pixel_left, display_pixel_right;
    logic [7:0] display_column_index = '0;
    logic [15:0] display_column_left, display_column_right;
    logic [7:0] dram_lo [0:65535];
    logic [7:0] dram_hi [0:65535];

    vip_memory dut (.*);

    always #5 clk = ~clk;
    always #7 display_clk = ~display_clk;
    always @(posedge clk) ce <= ~ce;
    integer ce_count = 0;
    always @(posedge clk) if (ce) ce_count = ce_count + 1;

    // pocket_sram's shape: three access cycles, a one-cycle ready pulse,
    // then a release phase that insists the request drop first. An
    // abandoned request parks here exactly as it parks the chip.
    logic [2:0] sram_state = '0;
    logic [15:0] sram_addr;
    logic sram_we_q;
    logic [15:0] sram_wdata_q;
    logic [1:0] sram_be_q;
    assign dram_ready = sram_state == 3'd4;
    always @(posedge clk) begin
        case (sram_state)
            3'd0: if (dram_req) begin
                sram_addr <= dram_addr;
                sram_we_q <= dram_we;
                sram_wdata_q <= dram_wdata;
                sram_be_q <= dram_be;
                sram_state <= 3'd1;
            end
            3'd1, 3'd2: sram_state <= sram_state + 3'd1;
            3'd3: begin
                if (sram_we_q) begin
                    if (sram_be_q[0]) dram_lo[sram_addr] <= sram_wdata_q[7:0];
                    if (sram_be_q[1]) dram_hi[sram_addr] <= sram_wdata_q[15:8];
                end else begin
                    dram_rdata <= {dram_hi[sram_addr], dram_lo[sram_addr]};
                end
                sram_state <= 3'd4;
            end
            3'd4: sram_state <= 3'd5;
            default: if (!dram_req) sram_state <= 3'd0;
        endcase
    end

    integer t0;

    task automatic cpu_write(input logic [26:0] address, input logic [1:0] lanes,
                             input logic [15:0] data);
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = address[26:1];
        cpu_we = 1'b1;
        cpu_be = lanes;
        cpu_wdata = data;
        @(posedge clk);
        while (!ready) @(posedge clk);
        @(negedge clk);
        cpu_sel = 1'b0;
        cpu_we = 1'b0;
    endtask

    task automatic cpu_read(input logic [26:0] address, output logic [15:0] data);
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = address[26:1];
        cpu_we = 1'b0;
        @(posedge clk);
        while (!ready) @(posedge clk);
        @(negedge clk);
        cpu_sel = 1'b0;
        @(negedge clk);
        data = cpu_rdata;
    endtask

    task automatic expect_read(input logic [26:0] address, input logic [15:0] expected,
                               input string what);
        logic [15:0] actual;
        cpu_read(address, actual);
        if (actual !== expected)
            $fatal(1, "%s: read %04x, expected %04x", what, actual, expected);
    endtask

    // Both eyes come out together now, so every check names both: an eye
    // wired to the other's frame buffer passes a one-eyed check.
    task automatic expect_pixel(input logic buffer_id,
                                input logic [8:0] x, input logic [7:0] y,
                                input logic [1:0] want_left,
                                input logic [1:0] want_right);
        @(negedge display_clk);
        display_buffer = buffer_id;
        display_x = x;
        display_y = y;
        @(negedge display_clk);
        #1;
        if (display_pixel_left !== want_left)
            $fatal(1, "left buffer %0d (%0d,%0d): pixel %0d, expected %0d",
                   buffer_id, x, y, display_pixel_left, want_left);
        if (display_pixel_right !== want_right)
            $fatal(1, "right buffer %0d (%0d,%0d): pixel %0d, expected %0d",
                   buffer_id, x, y, display_pixel_right, want_right);
    endtask

    task automatic expect_column(input logic [7:0] index,
                                 input logic [15:0] want_left,
                                 input logic [15:0] want_right);
        @(negedge display_clk);
        display_column_index = index;
        repeat (3) @(negedge display_clk);
        #1;
        if (display_column_left !== want_left)
            $fatal(1, "left column %0d: %04x, expected %04x",
                   index, display_column_left, want_left);
        if (display_column_right !== want_right)
            $fatal(1, "right column %0d: %04x, expected %04x",
                   index, display_column_right, want_right);
    endtask

    initial begin
        logic [15:0] value;

        repeat (2) @(posedge clk);
        reset_n = 1'b1;

        cpu_write(27'h0000000, 2'b11, 16'hE4E4);
        cpu_write(27'h0008000, 2'b11, 16'h1B1B);
        cpu_write(27'h0010000, 2'b11, 16'hAAAA);
        cpu_write(27'h0018000, 2'b11, 16'h5555);
        expect_read(27'h0000000, 16'hE4E4, "left frame buffer 0");
        expect_read(27'h0008000, 16'h1B1B, "left frame buffer 1");
        expect_read(27'h0010000, 16'hAAAA, "right frame buffer 0");
        expect_read(27'h0018000, 16'h5555, "right frame buffer 1");
        cpu_write(27'h0000002, 2'b11, 16'h369C);
        expect_read(27'h0000000, 16'hE4E4, "adjacent frame buffer word 0");
        expect_read(27'h0000002, 16'h369C, "adjacent frame buffer word 1");

        cpu_write(27'h0006000, 2'b11, 16'h1234);
        expect_read(27'h0078000, 16'h1234, "character mirror 0");
        cpu_write(27'h0006002, 2'b11, 16'h9ABC);
        expect_read(27'h0006000, 16'h1234, "adjacent character word 0");
        expect_read(27'h0006002, 16'h9ABC, "adjacent character word 1");
        cpu_write(27'h007E000, 2'b11, 16'h5678);
        expect_read(27'h001E000, 16'h5678, "character mirror 3");

        cpu_write(27'h0020000, 2'b11, 16'hABCD);
        expect_read(27'h00A0000, 16'hABCD, "VIP 512 KiB mirror");
        cpu_write(27'h003FFFE, 2'b11, 16'h1357);
        expect_read(27'h003FFFE, 16'h1357, "DRAM high address");

        cpu_write(27'h003DCF4, 2'b11, 16'h1234);
        cpu_write(27'h003DEF4, 2'b11, 16'h5678);
        expect_column(8'h7A, 16'h1234, 16'h5678);
        // With LOCK each eye serves its own locked entry to every column.
        cpu_write(27'h003DC02, 2'b11, 16'h9999);
        cpu_write(27'h003DE06, 2'b11, 16'h8888);
        column_lock = 1'b1;
        cta_locked_left = 8'h01;
        cta_locked_right = 8'h03;
        expect_column(8'h7A, 16'h9999, 16'h8888);
        column_lock = 1'b0;

        cpu_write(27'h0020100, 2'b11, 16'hAABB);
        cpu_write(27'h0020100, 2'b01, 16'hCCDD);
        expect_read(27'h0020100, 16'hAADD, "low byte lane");
        cpu_write(27'h0020100, 2'b10, 16'hEEFF);
        expect_read(27'h0020100, 16'hEEDD, "high byte lane");

        cpu_write(27'h0040000, 2'b11, 16'hDEAD);
        expect_read(27'h0040000, 16'h0000, "unmapped memory");

        // CPU service times follow the measured figures: a BRAM write is
        // ready inside three 20 MHz cycles, a read inside seven.
        @(negedge clk);
        cpu_sel = 1'b1; cpu_addr = 27'h0000100 >> 1; cpu_we = 1'b1;
        cpu_be = 2'b11; cpu_wdata = 16'h7777;
        t0 = ce_count;
        @(posedge clk);
        while (!ready) @(posedge clk);
        if (ce_count - t0 < 2 || ce_count - t0 > 4)
            $fatal(1, "write service time %0d ce", ce_count - t0);
        @(negedge clk); cpu_sel = 1'b0; cpu_we = 1'b0;
        @(negedge clk);
        cpu_sel = 1'b1; cpu_we = 1'b0;
        t0 = ce_count;
        @(posedge clk);
        while (!ready) @(posedge clk);
        if (ce_count - t0 < 6 || ce_count - t0 > 8)
            $fatal(1, "read service time %0d ce", ce_count - t0);
        @(negedge clk); cpu_sel = 1'b0;

        // Arbitration: a draw request raised mid-flight must not hijack the
        // CPU's in-progress DRAM read; both transactions complete.
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = 27'h0020000 >> 1;
        cpu_we = 1'b0;
        repeat (2) @(posedge clk);
        @(negedge clk);
        draw_req = 1'b1;
        draw_addr = 19'h20200 >> 1;
        draw_we = 1'b1;
        draw_be = 2'b11;
        draw_wdata = 16'h2222;
        @(posedge clk);
        while (!ready) @(posedge clk);
        @(negedge clk);
        cpu_sel = 1'b0;
        @(negedge clk);
        value = cpu_rdata;
        if (value !== 16'hABCD)
            $fatal(1, "draw hijacked an in-flight CPU read: %04x", value);
        while (!draw_ready) @(posedge clk);
        @(negedge clk);
        draw_req = 1'b0;
        draw_we = 1'b0;
        expect_read(27'h0020200, 16'h2222, "queued draw write landed");

        // Fresh grants prefer the drawing engine.
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = 27'h0020300 >> 1;
        cpu_we = 1'b1; cpu_be = 2'b11; cpu_wdata = 16'h1111;
        draw_req = 1'b1;
        draw_addr = 19'h20300 >> 1;
        draw_we = 1'b1; draw_be = 2'b11; draw_wdata = 16'h2222;
        @(posedge clk);
        while (!draw_ready) @(posedge clk);
        @(negedge clk);
        draw_req = 1'b0; draw_we = 1'b0;
        @(posedge clk);
        while (!ready) @(posedge clk);
        @(negedge clk);
        cpu_sel = 1'b0; cpu_we = 1'b0;
        expect_read(27'h0020300, 16'h1111, "held CPU write landed second");

        // Buffer 0 holds E4E4 left against AAAA right, buffer 1 1B1B
        // against 5555, so no pair of these agrees by accident.
        expect_pixel(1'b0, 9'd0, 8'd0, 2'd0, 2'd2);
        expect_pixel(1'b0, 9'd0, 8'd1, 2'd1, 2'd2);
        expect_pixel(1'b0, 9'd0, 8'd2, 2'd2, 2'd2);
        expect_pixel(1'b0, 9'd0, 8'd3, 2'd3, 2'd2);
        expect_pixel(1'b1, 9'd0, 8'd0, 2'd3, 2'd1);

        cpu_read(27'h0020000, value);
        if (value !== 16'hABCD) $fatal(1, "final read failed");
        $display("vip_memory: PASS");
        $finish;
    end

    initial begin
        #400_000;
        $fatal(1, "timed out");
    end
endmodule
