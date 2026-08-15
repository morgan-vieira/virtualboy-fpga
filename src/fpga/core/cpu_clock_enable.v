`default_nettype none
//
// Architectural time for the NVC: a one-clock enable in the CPU domain
// that fires at exactly 20 MHz on average, phase-locked to the video clock.
// The real machine derives its 20 ms frame and its 20 MHz CPU from one
// oscillator, so a frame is exactly 400,000 CPU cycles; this reproduces that
// invariant against host_video_timing's 245,760-clock frame.
//
// The fraction is INC/MOD enables per clock. Both constants derive from
// the PLL's real output counters, not from nominal megahertz: with the
// video clock at VCO/C0 and this domain at VCO/C2, a frame is
// 245760*C0/C2 clocks, and INC/MOD = 400000 / that. The defaults assume
// C0/C2 = 52/16 (638.976 MHz VCO, 39.936 MHz here -- the 0.5.0 fit's
// achieved counters; only their 13:4 ratio matters), giving 798,720
// clocks per frame and a ratio of 625/1248. Check the fit report's PLL
// Usage Summary after any compile that touches the PLL: if the achieved
// ratio differs, these constants are wrong and every frame drifts by
// parts per million -- the bench pins the ratio, but only against the
// constants themselves.
//
// Consecutive enables sit 2 clocks apart, twice per MOD window only 1;
// consumers treat ce as a tick, never as a clock, and never assume a
// clock of room between ticks.
//

module cpu_clock_enable #(
    parameter INC = 625,
    parameter MOD = 1248
) (
    input  wire logic clk,
    input  wire logic reset_n,
    output logic      ce
);

    logic [$clog2(MOD+INC)-1:0] acc;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            acc <= '0;
            ce  <= 1'b0;
        end else if (acc + INC >= MOD) begin
            acc <= acc + INC - MOD;
            ce  <= 1'b1;
        end else begin
            acc <= acc + INC;
            ce  <= 1'b0;
        end
    end

endmodule

`default_nettype wire
