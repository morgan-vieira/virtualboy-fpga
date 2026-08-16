`timescale 1ns/1ps
`default_nettype none

module audio_i2s_tb;

    logic source_clk = 1'b0;
    logic mclk = 1'b0;
    always #4 source_clk = ~source_clk;
    always #5 mclk = ~mclk;

    logic reset_n = 1'b0;
    logic signed [15:0] source_left = 16'sh8123;
    logic signed [15:0] source_right = 16'sh4567;
    logic dac;
    logic lrck;

    audio_i2s dut (.*);

    task automatic next_bit;
        begin
            do begin
                @(posedge mclk);
                #1;
            end while (dut.mclk_divider != 2'd0);
        end
    endtask

    integer slot;
    logic expected;

    initial begin
        repeat (4) @(posedge mclk);
        reset_n = 1'b1;

        while (dut.left_frame !== source_left)
            next_bit();
        while (dut.bit_count != 6'd1)
            next_bit();

        for (slot = 0; slot < 64; slot = slot + 1) begin
            if (lrck !== (slot >= 32))
                $fatal(1, "slot %0d: lrck=%b", slot, lrck);

            expected = 1'b0;
            if (slot >= 1 && slot <= 16)
                expected = source_left[16 - slot];
            else if (slot >= 33 && slot <= 48)
                expected = source_right[48 - slot];
            if (dac !== expected)
                $fatal(1, "slot %0d: dac=%b, expected %b", slot, dac, expected);

            next_bit();
        end

        $finish;
    end

endmodule

`default_nettype wire
