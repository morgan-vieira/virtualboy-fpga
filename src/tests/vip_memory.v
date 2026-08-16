`timescale 1ns/1ps
`default_nettype none

module vip_memory_tb;
    logic clk = 1'b0;
    logic reset_n = 1'b0;
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
    logic dram_ready = 1'b1;
    logic display_eye = 1'b0;
    logic display_buffer = 1'b0;
    logic [8:0] display_x = '0;
    logic [7:0] display_y = '0;
    logic [1:0] display_pixel;
    logic [7:0] display_column_index = '0;
    logic [15:0] display_column;
    logic [7:0] dram_lo [0:65535];
    logic [7:0] dram_hi [0:65535];

    vip_memory dut (.*);

    always #5 clk = ~clk;
    always #7 display_clk = ~display_clk;

    always_ff @(posedge clk) begin
        if (dram_req) begin
            if (dram_we && dram_be[0]) dram_lo[dram_addr] <= dram_wdata[7:0];
            if (dram_we && dram_be[1]) dram_hi[dram_addr] <= dram_wdata[15:8];
            dram_rdata <= {dram_hi[dram_addr], dram_lo[dram_addr]};
        end
    end

    task automatic cpu_write(input logic [26:0] address, input logic [1:0] lanes,
                             input logic [15:0] data);
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = address[26:1];
        cpu_we = 1'b1;
        cpu_be = lanes;
        cpu_wdata = data;
        @(negedge clk);
        cpu_sel = 1'b0;
        cpu_we = 1'b0;
    endtask

    task automatic cpu_read(input logic [26:0] address, output logic [15:0] data);
        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = address[26:1];
        cpu_we = 1'b0;
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

    task automatic expect_pixel(input logic eye, input logic buffer_id,
                                input logic [8:0] x, input logic [7:0] y,
                                input logic [1:0] expected);
        @(negedge display_clk);
        display_eye = eye;
        display_buffer = buffer_id;
        display_x = x;
        display_y = y;
        @(negedge display_clk);
        #1;
        if (display_pixel !== expected)
            $fatal(1, "eye %0d buffer %0d (%0d,%0d): pixel %0d, expected %0d",
                   eye, buffer_id, x, y, display_pixel, expected);
    endtask

    task automatic expect_column(input logic eye, input logic [7:0] index,
                                 input logic [15:0] expected);
        @(negedge display_clk);
        display_eye = eye;
        display_column_index = index;
        repeat (3) @(negedge display_clk);
        #1;
        if (display_column !== expected)
            $fatal(1, "eye %0d column %0d: %04x, expected %04x",
                   eye, index, display_column, expected);
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
        expect_column(1'b0, 8'h7A, 16'h1234);
        expect_column(1'b1, 8'h7A, 16'h5678);

        cpu_write(27'h0020100, 2'b11, 16'hAABB);
        cpu_write(27'h0020100, 2'b01, 16'hCCDD);
        expect_read(27'h0020100, 16'hAADD, "low byte lane");
        cpu_write(27'h0020100, 2'b10, 16'hEEFF);
        expect_read(27'h0020100, 16'hEEDD, "high byte lane");

        cpu_write(27'h0040000, 2'b11, 16'hDEAD);
        expect_read(27'h0040000, 16'h0000, "unmapped memory");

        @(negedge clk);
        cpu_sel = 1'b1;
        cpu_addr = 27'h0020200 >> 1;
        cpu_we = 1'b1;
        cpu_be = 2'b11;
        cpu_wdata = 16'h1111;
        draw_req = 1'b1;
        draw_addr = 19'h20200 >> 1;
        draw_we = 1'b1;
        draw_be = 2'b11;
        draw_wdata = 16'h2222;
        @(negedge clk);
        cpu_sel = 1'b0;
        cpu_we = 1'b0;
        draw_req = 1'b0;
        draw_we = 1'b0;
        expect_read(27'h0020200, 16'h2222, "drawing port priority");

        expect_pixel(1'b0, 1'b0, 9'd0, 8'd0, 2'd0);
        expect_pixel(1'b0, 1'b0, 9'd0, 8'd1, 2'd1);
        expect_pixel(1'b0, 1'b0, 9'd0, 8'd2, 2'd2);
        expect_pixel(1'b0, 1'b0, 9'd0, 8'd3, 2'd3);
        expect_pixel(1'b0, 1'b1, 9'd0, 8'd0, 2'd3);
        expect_pixel(1'b1, 1'b0, 9'd0, 8'd0, 2'd2);
        expect_pixel(1'b1, 1'b1, 9'd0, 8'd0, 2'd1);

        cpu_read(27'h0020000, value);
        if (value !== 16'hABCD) $fatal(1, "final read failed");
        $finish;
    end

    initial begin
        #100_000;
        $fatal(1, "timed out");
    end
endmodule
