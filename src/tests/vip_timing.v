`timescale 1ns/1ps

// vip_timing: the 20 ms schedule, game-frame gating, framebuffer ownership,
// the overtime level, and the column-table pointers under LOCK.

module vip_timing_tb;
  reg clk=0, reset_n=0, display_reset=0, draw_reset=0;
  reg display_enable=1, sync_enable=1, draw_enable=1, column_lock=0;
  reg [3:0] frmcyc=1;
  reg [4:0] sbcmp=7;
  reg draw_busy=0, draw_done=0, strip_begin=0, sbout=0;
  reg [4:0] strip_number=0;
  wire fclk, scan_ready, draw_start, draw_buffer, display_buffer;
  wire draw_overtime;
  wire [3:0] display_busy;
  wire [15:0] events;
  wire [7:0] cta_l, cta_r;

  vip_timing #(.FRAME_CYCLES(20), .LEFT_START(3), .LEFT_END(8),
    .FCLK_END(10), .RIGHT_START(13), .RIGHT_END(18),
    .CTA_GROUP_CLOCKS(2)) dut (.*);
  always #5 clk=~clk;

  task automatic tick;
    begin @(posedge clk); #1; end
  endtask

  integer n;
  initial begin
    repeat(2) tick(); reset_n=1;
    tick();
    // Reset displays buffer 0, so the first draw targets buffer 1
    // [beetle-vb VIP_Power; MiSTer framebuffer owner].
    if (!events[4] || !events[3] || !draw_start || !fclk)
      $fatal(1,"first display frame wrong");
    if (draw_buffer !== 1'b1 || display_buffer !== 1'b0)
      $fatal(1,"reset buffer assignment wrong");
    if (!scan_ready) $fatal(1,"scanner should always be ready");
    for(n=0;n<8;n=n+1) tick();
    if (!events[1]) $fatal(1,"left-end event missing");
    // The left window walked the column pointer down from 0xFA.
    if (cta_l >= 8'hFA) $fatal(1,"CTA left pointer never advanced: %02x", cta_l);
    for(n=8;n<18;n=n+1) tick();
    if (!events[2]) $fatal(1,"right-end event missing");
    tick(); tick();
    if (!events[4] || events[3] || draw_start)
      $fatal(1,"FRMCYC skipped-frame behavior wrong");

    // No draw completed, so the next game frame targets buffer 1 again.
    repeat(20) tick();
    if (!events[4] || !events[3] || !draw_start || draw_buffer !== 1'b1)
      $fatal(1,"sampled game-frame start wrong");

    // Completion parks the buffer as pending; the display switches only at
    // the next game-frame start, and the following draw targets buffer 0.
    draw_done=1; tick(); draw_done=0;
    if (!events[14]) $fatal(1,"draw completion event missing");
    if (display_buffer !== 1'b0)
      $fatal(1,"display switched before the game-frame boundary");
    n=0;
    while (!(events[3] && events[4]) && n < 80) begin tick(); n=n+1; end
    if (n == 80) $fatal(1,"no game frame after completion");
    if (display_buffer !== 1'b1 || draw_buffer !== 1'b0 || !draw_start)
      $fatal(1,"pending buffer not consumed at game start");

    strip_number=7; strip_begin=1; tick(); strip_begin=0;
    if (!events[13]) $fatal(1,"SBHIT missing");
    // SBOUT already high suppresses a second hit.
    sbout=1; strip_begin=1; tick(); strip_begin=0; sbout=0;
    if (events[13]) $fatal(1,"SBHIT fired while SBOUT held");

    // A busy renderer at a game-frame start raises TIMEERR once and holds
    // the overtime level until the draw finally completes.
    draw_busy=1;
    n=0;
    while (!events[15] && n < 60) begin tick(); n=n+1; end
    if (!events[15] || draw_start) $fatal(1,"TIMEERR behavior wrong");
    if (!draw_overtime) $fatal(1,"overtime level not held");
    tick();
    n=0;
    while (!events[3] && n < 60) begin tick(); n=n+1; end
    if (events[15]) $fatal(1,"TIMEERR repeated while overtime held");
    draw_busy=0; draw_done=1; tick(); draw_done=0;
    if (draw_overtime) $fatal(1,"overtime did not clear at completion");

    display_reset=1; tick(); display_reset=0;
    if (display_busy != 0)
      $fatal(1,"DPRST did not clear display busy");
    while (!events[4]) tick();
    if (!events[3])
      $fatal(1,"DPRST did not resume on FCLK");

    // LOCK prevents the decrement; the eye start still reloads 0xFA, so a
    // locked frame serves the field-start entry to every column group.
    while (fclk && display_busy != 0) tick();
    column_lock=1;
    while (!(fclk && display_busy != 0)) tick();
    repeat(4) tick();
    if (cta_l !== 8'hFA) $fatal(1,"LOCK did not hold CTA at the reload: %02x", cta_l);
    column_lock=0;

    $display("vip_timing: PASS");
    $finish;
  end
endmodule
