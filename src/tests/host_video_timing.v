`timescale 1ns/1ps

//
// Drives two whole frames and checks the raster the Pocket's scaler is promised,
// cycle by cycle: a data enable window that is exactly 384x224 where x and y hold
// the pixel's coordinates on every active clock, hs pulses exactly 480 clocks
// apart and once per line, one vs per frame with neither sync inside the active
// window nor on the same clock as the other, and a frame that is exactly 245,760
// clocks. Together those pin every output on every clock: a raster that passes
// cannot differ from the intended one anywhere.
//
// The clock here is 10 ns for arithmetic that is easy to read. The frame period is
// checked in clocks rather than nanoseconds, and the one check that ties clocks to
// real time is the elaboration check below.
//

module host_video_timing_tb;

  localparam integer H_ACTIVE     = 384;
  localparam integer H_TOTAL      = 480;
  localparam integer V_ACTIVE     = 224;
  localparam integer V_TOTAL      = 512;
  localparam integer FRAME_CLOCKS = H_TOTAL * V_TOTAL;
  localparam integer PIXEL_HZ     = 12_288_000;
  localparam integer FRAMES_HZ    = 50;

  reg         clk = 1'b0;
  reg         reset_n = 1'b0;
  wire        de, hs, vs;
  wire [9:0]  x, y;

  host_video_timing #(
    .H_ACTIVE (H_ACTIVE),
    .H_TOTAL  (H_TOTAL),
    .V_ACTIVE (V_ACTIVE),
    .V_TOTAL  (V_TOTAL)
  ) dut (
    .clk     (clk),
    .reset_n (reset_n),
    .de      (de),
    .hs      (hs),
    .vs      (vs),
    .x       (x),
    .y       (y)
  );

  always #5 clk = ~clk;

  // A clean raster at the wrong frame rate is still the wrong frame rate.
  initial begin
    if (FRAME_CLOCKS != PIXEL_HZ / FRAMES_HZ)
      $fatal(1, "raster is %0d clocks; %0d Hz at %0d Hz pixel clock needs %0d",
             FRAME_CLOCKS, FRAMES_HZ, PIXEL_HZ, PIXEL_HZ / FRAMES_HZ);
  end

  // Call with the previous frame's vs just consumed. Runs to the next vs, so the
  // clock count it returns is the measured frame period rather than an assumed one.
  // Counting a fixed window instead would miss a frame that is a line short: the
  // window still contains exactly one vs.
  task automatic check_one_frame(input integer index);
    integer   c;
    integer   de_count;
    integer   hs_count;
    integer   lines;
    integer   run;
    integer   since_hs;
    reg [9:0] expected_y;
    reg       prev_de;
    reg       seen_hs;
    reg       seen_vs;
    begin
      c        = 0;
      de_count = 0;
      hs_count = 0;
      lines    = 0;
      run      = 0;
      since_hs = 0;
      expected_y = 10'd0;
      prev_de  = 1'b0;
      seen_hs  = 1'b0;
      seen_vs  = 1'b0;

      while (!seen_vs) begin
        @(posedge clk);
        #1;
        c = c + 1;
        since_hs = since_hs + 1;

        if (vs) seen_vs = 1'b1;

        if (de && hs) $fatal(1, "frame %0d: hs inside the active window", index);
        if (de && vs) $fatal(1, "frame %0d: vs inside the active window", index);
        if (hs && vs) $fatal(1, "frame %0d: hs and vs on the same clock", index);

        // Exact spacing, not just one per line: a raster whose lines trade clocks
        // still totals 245,760 and still counts 512 pulses.
        if (hs) begin
          hs_count = hs_count + 1;
          if (seen_hs && since_hs !== H_TOTAL)
            $fatal(1, "frame %0d: hs to hs was %0d clocks, expected %0d",
                   index, since_hs, H_TOTAL);
          seen_hs  = 1'b1;
          since_hs = 0;
        end

        if (de) begin
          de_count = de_count + 1;
          if (!prev_de) run = 0;
          // Every active clock, not just the line's first: x that sticks or skips
          // scrambles the pixel stream without changing any count.
          if (x !== run[9:0])
            $fatal(1, "frame %0d line %0d: x=%0d, expected %0d", index, lines, x, run);
          if (y !== expected_y)
            $fatal(1, "frame %0d line %0d: y=%0d, expected %0d", index, lines, y, expected_y);
          run = run + 1;
        end else if (prev_de) begin
          if (run !== H_ACTIVE)
            $fatal(1, "frame %0d line %0d: de ran %0d px, expected %0d",
                   index, lines, run, H_ACTIVE);
          lines = lines + 1;
          expected_y = expected_y + 10'd1;
        end
        prev_de = de;

        if (c > 2*FRAME_CLOCKS)
          $fatal(1, "frame %0d: no vs within two frames' worth of clocks", index);
      end

      // The one that sets the frame rate. 245,760 clocks is 20 ms at 12.288 MHz.
      if (c !== FRAME_CLOCKS)
        $fatal(1, "frame %0d: vs to vs was %0d clocks, expected %0d",
               index, c, FRAME_CLOCKS);
      if (de_count !== H_ACTIVE * V_ACTIVE)
        $fatal(1, "frame %0d: %0d active pixels, expected %0d",
               index, de_count, H_ACTIVE * V_ACTIVE);
      if (lines !== V_ACTIVE)
        $fatal(1, "frame %0d: %0d active lines, expected %0d", index, lines, V_ACTIVE);
      if (hs_count !== V_TOTAL)
        $fatal(1, "frame %0d: %0d hs pulses, expected one per line (%0d)",
               index, hs_count, V_TOTAL);
    end
  endtask

  integer frame;

  initial begin
    repeat (4) @(posedge clk);
    reset_n = 1'b1;

    // Measure from a frame boundary rather than from reset.
    @(posedge vs);

    for (frame = 0; frame < 2; frame = frame + 1) check_one_frame(frame);

    $finish;
  end

  initial begin
    #20_000_000;
    $fatal(1, "timed out before two frames completed");
  end

endmodule
