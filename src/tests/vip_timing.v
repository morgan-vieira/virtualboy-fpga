`timescale 1ns/1ps

module vip_timing_tb;
  reg clk=0, reset_n=0, display_reset=0, draw_reset=0;
  reg display_enable=1, sync_enable=1, draw_enable=1;
  reg [3:0] frmcyc=1;
  reg [4:0] sbcmp=7;
  reg draw_busy=0, draw_done=0, strip_begin=0;
  reg [4:0] strip_number=0;
  wire fclk, scan_ready, draw_start, draw_buffer, display_buffer;
  wire [3:0] display_busy;
  wire [15:0] events;

  vip_timing #(.FRAME_CYCLES(20), .LEFT_START(3), .LEFT_END(8),
    .FCLK_END(10), .RIGHT_START(13), .RIGHT_END(18)) dut (.*);
  always #5 clk=~clk;

  task automatic tick;
    begin @(posedge clk); #1; end
  endtask

  integer n;
  initial begin
    repeat(2) tick(); reset_n=1;
    tick();
    if (!events[4] || !events[3] || !draw_start || !fclk)
      $fatal(1,"first display frame wrong");
    for(n=0;n<8;n=n+1) tick();
    if (!events[1]) $fatal(1,"left-end event missing");
    for(n=8;n<18;n=n+1) tick();
    if (!events[2]) $fatal(1,"right-end event missing");
    tick(); tick();
    if (!events[4] || events[3] || draw_start)
      $fatal(1,"FRMCYC skipped-frame behavior wrong");

    repeat(20) tick();
    if (!events[4] || !events[3] || !draw_start || draw_buffer != 0)
      $fatal(1,"sampled game-frame start wrong");

    draw_done=1; tick(); draw_done=0;
    if (!events[14] || display_buffer != 0) $fatal(1,"draw completion wrong");

    strip_number=7; strip_begin=1; tick(); strip_begin=0;
    if (!events[13]) $fatal(1,"SBHIT missing");

    // Two display frames later, a busy renderer raises TIMEERR and no start.
    draw_busy=1;
    n=0;
    while (!events[15] && n < 60) begin tick(); n=n+1; end
    if (!events[15] || draw_start) $fatal(1,"TIMEERR behavior wrong");

    display_reset=1; tick(); display_reset=0;
    if (scan_ready || display_busy != 0)
      $fatal(1,"DPRST did not wait for FCLK");
    while (!events[4]) tick();
    if (!scan_ready || !events[3])
      $fatal(1,"DPRST did not resume on FCLK");

    $display("vip_timing: PASS");
    $finish;
  end
endmodule
