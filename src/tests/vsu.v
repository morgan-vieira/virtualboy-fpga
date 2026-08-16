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
        sel = 1'b1;
        we = 1'b1;
        be = 2'b01;
        addr = {15'd0, byte_offset[10:1]};
        wdata = {8'hxx, value};
        @(negedge clk);
        sel = 1'b0;
        we = 1'b0;
        be = 2'b00;
    endtask

    task automatic expect_samples(
        input logic signed [15:0] left,
        input logic signed [15:0] right,
        input string what
    );
        repeat (11) @(posedge clk);
        #1;
        if (sample_left !== left || sample_right !== right)
            $fatal(1, "%0s: got L=%0d R=%0d, expected L=%0d R=%0d",
                   what, sample_left, sample_right, left, right);
    endtask

    task automatic configure_channel(
        input integer channel,
        input logic [7:0] volume,
        input logic [3:0] bank
    );
        logic [10:0] base;
        begin
            base = 11'h400 + channel * 11'h040;
            write8(base + 11'h004, volume);
            write8(base + 11'h008, 8'h00);
            write8(base + 11'h00c, 8'h00);
            write8(base + 11'h010, 8'hf0);
            write8(base + 11'h018, {4'd0, bank});
            write8(base, 8'h80);
        end
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

        ce = 1'b0;
        expect_samples(-3712, -2048, "position zero and stereo gain");
        @(negedge clk);
        ce = 1'b1;
        repeat (2) @(posedge clk);
        @(negedge clk);
        ce = 1'b0;
        expect_samples(3596, 1984, "frequency advances after one tick");

        write8(11'h580, 8'h01);
        expect_samples(0, 0, "global stop");

        // Every wavetable channel owns its phase, bank, and stereo gain.
        // The chosen samples make each contribution visible in the sum.
        write8(11'h000, 8'd0);
        write8(11'h080, 8'd63);
        write8(11'h100, 8'd32);
        write8(11'h180, 8'd16);
        write8(11'h200, 8'd48);
        configure_channel(0, 8'hf0, 4'd0);
        configure_channel(1, 8'h0f, 4'd1);
        configure_channel(2, 8'h80, 4'd2);
        configure_channel(3, 8'h40, 4'd3);
        configure_channel(4, 8'h04, 4'd4);
        expect_samples(-4224, 4108, "five-channel stereo mix");

        write8(11'h4c0, 8'h00);
        expect_samples(-3712, 4108, "individual channel stop");
        write8(11'h580, 8'h01);
        expect_samples(0, 0, "five-channel global stop");

        write8(11'h400, 8'ha0);
        expect_samples(-3712, 0, "interval restart");
        @(negedge clk);
        ce = 1'b1;
        repeat (19200) @(posedge clk);
        @(negedge clk);
        ce = 1'b0;
        expect_samples(0, 0, "interval expiry");

        $finish;
    end

endmodule

`default_nettype wire
