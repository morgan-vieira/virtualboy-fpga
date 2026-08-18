`timescale 1ns/1ps
`default_nettype none

module vip_luma_curve_tb;
    logic [7:0] exposure = 8'd0;
    logic [7:0] luma;

    vip_luma_curve dut (.*);

    // The table is generated from the formula in the module header, so the
    // bench recomputes it rather than restating it.
    real want;
    integer i;
    integer expected;
    integer level;
    integer previous;

    initial begin
        previous = 0;
        for (i = 0; i < 256; i = i + 1) begin
            exposure = i[7:0];
            #1;
            want = 255.0 * ((i / 255.0) ** (1.4 / 2.2));
            expected = $rtoi(want + 0.5);
            if (luma !== expected[7:0])
                $fatal(1, "exposure %0d: luma %0d, want %0d",
                       i, luma, expected);
            level = luma;
            if (level < previous)
                $fatal(1, "curve fell at exposure %0d", i);
            previous = level;
        end

        exposure = 8'd0; #1;
        if (luma != 8'd0) $fatal(1, "dark is not black: %0d", luma);
        exposure = 8'd255; #1;
        if (luma != 8'd255) $fatal(1, "full drive is not full: %0d", luma);

        $display("vip_luma_curve: PASS");
        $finish;
    end
endmodule

`default_nettype wire
