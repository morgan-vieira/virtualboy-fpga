`timescale 1ns/1ps

//
// Drives whole frames and checks the raster the Pocket's scaler is promised,
// cycle by cycle: a data enable window that is exactly the declared size where x
// and y hold the pixel's coordinates on every active clock, hs pulses exactly a
// line apart and once per line, one vs per frame with neither sync inside the
// active window nor on the same clock as the other, and a frame that is exactly
// h_total * v_total clocks. Together those pin every output on every clock: a
// raster that passes cannot differ from the intended one anywhere.
//
// Every stereo mode gets its own raster now [vip_stereo], so every one of them is
// driven here, and the frame period each promises is checked against the 20 ms
// the machine's display frame takes. Cyberscope's is three clocks long and says
// so; the rest are exact.
//
// The clock here is 10 ns for arithmetic that is easy to read. The frame period is
// checked in clocks rather than nanoseconds.
//

module host_video_timing_tb;

  localparam integer PIXEL_HZ     = 12_288_000;
  localparam integer FRAMES_HZ    = 50;
  localparam integer FRAME_CLOCKS = PIXEL_HZ / FRAMES_HZ;

  reg         clk = 1'b0;
  reg         reset_n = 1'b0;
  reg  [10:0] h_active = 11'd384;
  reg  [10:0] h_total  = 11'd480;
  reg  [10:0] v_active = 11'd224;
  reg  [10:0] v_total  = 11'd512;
  wire        de, hs, vs;
  wire [10:0] x, y;

  // What check_one_frame measures against; held with the inputs the raster in
  // flight was sampled from.
  integer     want_h_active, want_h_total, want_v_active, want_v_total;

  host_video_timing dut (
    .clk      (clk),
    .reset_n  (reset_n),
    .h_active (h_active),
    .h_total  (h_total),
    .v_active (v_active),
    .v_total  (v_total),
    .de       (de),
    .hs       (hs),
    .vs       (vs),
    .x        (x),
    .y        (y)
  );

  always #5 clk = ~clk;

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
    reg [10:0] expected_y;
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
      expected_y = 11'd0;
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
        // still totals the frame and still counts one pulse each.
        if (hs) begin
          hs_count = hs_count + 1;
          if (seen_hs && since_hs !== want_h_total)
            $fatal(1, "frame %0d: hs to hs was %0d clocks, expected %0d",
                   index, since_hs, want_h_total);
          seen_hs  = 1'b1;
          since_hs = 0;
        end

        if (de) begin
          de_count = de_count + 1;
          if (!prev_de) run = 0;
          // Every active clock, not just the line's first: x that sticks or skips
          // scrambles the pixel stream without changing any count.
          if (x !== run[10:0])
            $fatal(1, "frame %0d line %0d: x=%0d, expected %0d", index, lines, x, run);
          if (y !== expected_y)
            $fatal(1, "frame %0d line %0d: y=%0d, expected %0d", index, lines, y, expected_y);
          run = run + 1;
        end else if (prev_de) begin
          if (run !== want_h_active)
            $fatal(1, "frame %0d line %0d: de ran %0d px, expected %0d",
                   index, lines, run, want_h_active);
          lines = lines + 1;
          expected_y = expected_y + 11'd1;
        end
        prev_de = de;

        if (c > 4*FRAME_CLOCKS)
          $fatal(1, "frame %0d: no vs within two frames' worth of clocks", index);
      end

      if (c !== want_h_total * want_v_total)
        $fatal(1, "frame %0d: vs to vs was %0d clocks, expected %0d",
               index, c, want_h_total * want_v_total);
      if (de_count !== want_h_active * want_v_active)
        $fatal(1, "frame %0d: %0d active pixels, expected %0d",
               index, de_count, want_h_active * want_v_active);
      if (lines !== want_v_active)
        $fatal(1, "frame %0d: %0d active lines, expected %0d",
               index, lines, want_v_active);
      if (hs_count !== want_v_total)
        $fatal(1, "frame %0d: %0d hs pulses, expected one per line (%0d)",
               index, hs_count, want_v_total);
    end
  endtask

  // The rasters vip_stereo asks for, one per stereo mode plus the widest and
  // narrowest side-by-side. `slack` is how far from 20 ms the mode is allowed
  // to be, in clocks: zero for every mode this pixel clock can serve exactly.
  task automatic check_mode(input string name,
                            input integer ha, input integer ht,
                            input integer va, input integer vt,
                            input integer slack);
    integer drift;
    begin
      // A raster with no blanking has nowhere to put a sync pulse.
      if (ht <= ha) $fatal(1, "%s: h_total %0d does not clear h_active %0d",
                           name, ht, ha);
      if (vt <= va) $fatal(1, "%s: v_total %0d does not clear v_active %0d",
                           name, vt, va);

      drift = ht * vt - FRAME_CLOCKS;
      if (drift < 0) drift = -drift;
      if (drift > slack)
        $fatal(1, "%s: raster is %0d clocks, %0d off the %0d that makes 20 ms",
               name, ht * vt, drift, FRAME_CLOCKS);

      // Take effect on the next boundary, then measure the frame after it so
      // the whole frame ran on one geometry.
      @(negedge clk);
      h_active = ha[10:0];
      h_total  = ht[10:0];
      v_active = va[10:0];
      v_total  = vt[10:0];
      @(posedge vs);
      @(posedge vs);
      want_h_active = ha;
      want_h_total  = ht;
      want_v_active = va;
      want_v_total  = vt;
      check_one_frame(0);
      check_one_frame(1);
    end
  endtask

  initial begin
    repeat (4) @(posedge clk);
    reset_n = 1'b1;

    check_mode("2D and anaglyph",  384, 480, 224, 512, 0);
    check_mode("Cyberscope",       512, 581, 384, 423, 3);
    check_mode("line interleave V", 768, 1024, 224, 240, 0);
    check_mode("line interleave H", 384, 480, 448, 512, 0);
    check_mode("side by side 0",   768, 1024, 224, 240, 0);
    check_mode("side by side 64",  832, 1024, 224, 240, 0);

    $display("host_video_timing: PASS");
    $finish;
  end

  initial begin
    #120_000_000;
    $fatal(1, "timed out before every mode's frames completed");
  end

endmodule
