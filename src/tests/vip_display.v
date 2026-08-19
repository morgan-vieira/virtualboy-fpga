`timescale 1ns/1ps
`default_nettype none

module vip_display_tb;
    logic [8:0] x = 9'd0;
    logic [1:0] pixel = 2'd0;
    logic [7:0] brta = 8'd32;
    logic [7:0] brtb = 8'd64;
    logic [7:0] brtc = 8'd96;
    logic [7:0] rest = 8'd0;
    logic [15:0] column = 16'h00FF;
    logic [7:0] column_index;
    logic [7:0] luma;

    // The table belongs to vip_luma_curve's bench; this one pins the exposure
    // that reaches it. The numbers are after the MaxTime normalization --
    // 128 ticks of a column is full drive, so a level's ticks reach the
    // curve as round(ticks * 255 / 128), saturating -- which is what makes
    // these match what RetroArch renders for the same registers.
    logic [7:0] want_exposure = 8'd0;
    logic [7:0] want_luma;

    vip_display dut (.*);
    vip_luma_curve model (.exposure(want_exposure), .luma(want_luma));

    initial begin
        #1;
        if (column_index != 8'hFA || luma != 0)
            $fatal(1, "field start wrong");

        pixel = 1; want_exposure = 8'd63; #1;    // 32 ticks
        if (luma != want_luma) $fatal(1, "BRTA wrong: %0d", luma);
        pixel = 2; want_exposure = 8'd127; #1;   // 64 ticks
        if (luma != want_luma) $fatal(1, "BRTB wrong: %0d", luma);
        pixel = 3; want_exposure = 8'd255; #1;   // 192 ticks, past full drive
        if (luma != want_luma) $fatal(1, "BRTC accumulation wrong: %0d", luma);

        x = 9'd4; #1;
        if (column_index != 8'hF9) $fatal(1, "CTA did not walk");
        x = 9'd383; #1;
        if (column_index != 8'h9B) $fatal(1, "CTA final index wrong");

        pixel = 1;
        column = 16'h01FF; want_exposure = 8'd127; #1;   // 32 ticks twice
        if (luma != want_luma) $fatal(1, "repeat multiplier wrong: %0d", luma);
        column = 16'h0000; want_exposure = 8'd5; #1;     // clipped to 3 ticks
        if (luma != want_luma) $fatal(1, "column cutoff wrong: %0d", luma);
        rest = 3; #1;
        if (luma != 0) $fatal(1, "REST cutoff wrong: %0d", luma);

        $display("vip_display: PASS");
        $finish;
    end
endmodule

`default_nettype wire
