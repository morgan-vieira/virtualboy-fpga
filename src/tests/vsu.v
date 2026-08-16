`timescale 1ns/1ps
`default_nettype none

module vsu_tb;
    logic clk = 1'b0;
    always #5 clk = ~clk;
    logic reset_n = 1'b0;
    logic ce = 1'b1;
    logic sel = 1'b0;
    logic [26:1] addr = 26'd0;
    logic we = 1'b0;
    logic [1:0] be = 2'd0;
    logic [15:0] wdata = 16'd0;
    logic signed [15:0] sample_left;
    logic signed [15:0] sample_right;
    vsu dut (.*);

    task automatic write8(input logic [10:0] byte_offset, input logic [7:0] value);
        @(negedge clk);
        sel = 1'b1; we = 1'b1; be = 2'b01;
        addr = {15'd0, byte_offset[10:1]};
        wdata = {8'hxx, value};
        @(negedge clk);
        sel = 1'b0; we = 1'b0; be = 2'b00;
    endtask

    task automatic expect_samples(input logic signed [15:0] left,
        input logic signed [15:0] right, input string what);
        #1;
        if (sample_left !== left || sample_right !== right)
            $fatal(1, "%0s: got L=%0d R=%0d, expected L=%0d R=%0d",
                what, sample_left, sample_right, left, right);
    endtask

    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1'b1;
        expect_samples(0, 0, "reset silence");
        write8(11'h000, 8'd0);
        write8(11'h004, 8'd63);
        write8(11'h404, 8'hf8);
        write8(11'h408, 8'hfe);
        write8(11'h40c, 8'h07);
        write8(11'h410, 8'hf0);
        write8(11'h418, 8'h00);
        write8(11'h400, 8'h80);
        expect_samples(-3712, -2048, "position zero and stereo gain");
        repeat (2) @(posedge clk);
        expect_samples(3596, 1984, "frequency advances after one tick");
        write8(11'h580, 8'h01);
        expect_samples(0, 0, "global stop");
        write8(11'h400, 8'ha0);
        expect_samples(-3712, -2048, "interval restart");
        repeat (19200) @(posedge clk);
        expect_samples(0, 0, "interval expiry");
        $finish;
    end
endmodule

`default_nettype wire
