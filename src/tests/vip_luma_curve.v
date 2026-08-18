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

    task check(input [7:0] e, input [7:0] want_luma);
        begin
            exposure = e;
            #1;
            if (luma !== want_luma)
                $fatal(1, "exposure %0d: luma %0d, want %0d",
                       e, luma, want_luma);
        end
    endtask

    initial begin
        previous = 0;
        for (i = 0; i < 256; i = i + 1) begin
            exposure = i[7:0];
            #1;
            want = 255.0 * ((i / 255.0) ** (1.0 / 2.2));
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

        // The sweep above only proves the table and the bench agree. These
        // pin which curve that is, so changing the exponent in both places
        // still fails.
        check(8'd8,   8'd53);
        check(8'd33,  8'd101);
        check(8'd66,  8'd138);
        check(8'd132, 8'd189);
        check(8'd146, 8'd198);

        $display("vip_luma_curve: PASS");
        $finish;
    end
endmodule

`default_nettype wire
