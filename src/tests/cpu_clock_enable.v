`timescale 1ns/1ps
//
// Pins the architectural-time invariant: exactly INC enables in every MOD
// consecutive clocks, no drift across many windows, and consecutive enables
// never closer than floor(MOD/INC) clocks nor farther than ceil(MOD/INC).
// The count is what makes a frame exactly 400,000 CPU cycles; the gap bound
// is what tells the CPU's per-tick design that adjacent-clock enables
// happen and one clock of room between ticks is all it may assume.
// Checked against the module's own parameters -- the mapping from PLL
// counters to those parameters lives in the module header and the fit
// report, where a bench cannot reach.
//

module cpu_clock_enable_tb;

    localparam INC = 625;
    localparam MOD = 1248;
    localparam WINDOWS = 25;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    reg reset_n = 1'b0;
    wire ce;

    cpu_clock_enable #(
        .INC(INC),
        .MOD(MOD)
    ) dut (
        .clk(clk),
        .reset_n(reset_n),
        .ce(ce)
    );

    integer window, i, pulses, total, gap;

    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1'b1;

        total = 0;
        gap = 0;
        for (window = 0; window < WINDOWS; window = window + 1) begin
            pulses = 0;
            for (i = 0; i < MOD; i = i + 1) begin
                @(negedge clk);
                if (ce) begin
                    pulses = pulses + 1;
                    // gap counts the clocks between pulses, so spacing of
                    // 1 or 2 shows as 0 or 1
                    if (total + pulses > 1 && (gap < MOD / INC - 1 || gap > MOD / INC))
                        $fatal(1, "gap of %0d clocks between enables, expected %0d or %0d",
                               gap, MOD / INC - 1, MOD / INC);
                    gap = 0;
                end else begin
                    gap = gap + 1;
                end
            end
            if (pulses !== INC)
                $fatal(1, "window %0d: %0d enables in %0d clocks, expected %0d",
                       window, pulses, MOD, INC);
            total = total + pulses;
        end

        if (total !== INC * WINDOWS)
            $fatal(1, "%0d enables across %0d windows, expected %0d",
                   total, WINDOWS, INC * WINDOWS);

        $finish;
    end

    initial begin
        #1_000_000;
        $fatal(1, "timed out");
    end

endmodule
