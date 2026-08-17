`timescale 1ns/1ps

module vip_registers_tb;
  reg clk = 0;
  reg reset_n = 0;
  reg sel = 0;
  reg [12:1] addr = 0;
  reg we = 0;
  reg [1:0] be = 0;
  reg [15:0] wdata = 0;
  wire [15:0] rdata;
  wire irq;
  reg fclk = 0;
  reg scan_ready = 0;
  reg [3:0] display_busy = 0;
  reg draw_busy = 0;
  reg draw_buffer = 0;
  reg draw_sbout = 0;
  reg [4:0] draw_sbcount = 0;
  reg draw_overtime = 0;
  reg [15:0] events = 0;
  reg draw_start = 0;
  reg first_group_done = 0;
  reg [7:0] cta_l = 8'hFA;
  reg [7:0] cta_r = 8'hFA;
  wire display_enable, sync_enable, refresh_enable, column_lock;
  wire draw_enable;
  wire [4:0] sbcmp;
  wire [3:0] frmcyc;
  wire [39:0] spt, active_spt;
  wire [31:0] gplt, jplt, active_gplt, active_jplt;
  wire [1:0] bkcol, active_bkcol;
  wire [7:0] brta_level, brtb_level, brtc_level, rest_level;
  wire display_reset, draw_reset;

  vip_registers dut (.*);
  always #5 clk = ~clk;

  task automatic wr(input [12:1] a, input [1:0] lanes, input [15:0] d);
    begin
      @(negedge clk); sel=1; we=1; addr=a; be=lanes; wdata=d;
      @(negedge clk); sel=0; we=0; be=0;
    end
  endtask

  task automatic expect_reg(input [12:1] a, input [15:0] value, input [127:0] what);
    begin
      addr=a; #1;
      if (rdata !== value) $fatal(1, "%0s: %04x expected %04x", what, rdata, value);
    end
  endtask

  initial begin
    repeat (3) @(posedge clk);
    reset_n=1;

    expect_reg(12'hC22, 16'd2, "VIP version");
    wr(12'hC11, 2'b11, 16'h0702);
    fclk=1; @(posedge clk); #1;
    if ({column_lock,sync_enable,refresh_enable,display_enable} !== 4'b1111)
      $fatal(1, "DPCTRL fields not stored");

    // A byte write to an even address performs a halfword write with the
    // source's full low 16 bits [scroll, VIP I/O Registers].
    wr(12'hC24, 2'b01, 16'h0123);
    expect_reg(12'hC24, 16'h0123, "even byte write mangles to halfword");
    // A byte write to an odd address writes the high lane over a zero low
    // byte, so SBCMP lands and XPEN clears.
    wr(12'hC21, 2'b10, 16'h1BFF);
    if (draw_enable || sbcmp != 5'h1B)
      $fatal(1, "odd byte write not mangled: sbcmp %02x en %b", sbcmp, draw_enable);
    wr(12'hC21, 2'b11, 16'h0002);
    if (!draw_enable) $fatal(1, "XPEN halfword write failed");

    // CTA reflects the live column pointers.
    cta_l = 8'h9C; cta_r = 8'hE1;
    expect_reg(12'hC18, 16'hE19C, "CTA readback");

    wr(12'hC30, 2'b01, 16'h00FF);
    wr(12'hC34, 2'b01, 16'h006C);
    wr(12'hC24, 2'b11, 16'h03AA);
    wr(12'hC38, 2'b01, 16'h0003);
    draw_start=1; @(posedge clk); #1; draw_start=0;
    if (active_gplt[7:0] != 8'hFC || active_jplt[7:0] != 8'h6C ||
        active_spt[9:0] != 10'h3AA || active_bkcol != 0)
      $fatal(1, "draw snapshot incorrect");
    first_group_done=1; @(posedge clk); #1; first_group_done=0;
    if (active_bkcol != 3) $fatal(1, "BKCOL did not delay one group");

    wr(12'hC01, 2'b11, 16'hFFFF);
    events=16'h4008; @(posedge clk); #1; events=0;
    if (!irq) $fatal(1, "enabled event did not assert IRQ");
    expect_reg(12'hC00, 16'h4008, "pending events");
    wr(12'hC02, 2'b11, 16'h0008);
    expect_reg(12'hC00, 16'h4000, "INTCLR");

    // Set wins when event and clear coincide.
    events=16'h4000;
    wr(12'hC02, 2'b11, 16'h4000);
    events=0;
    expect_reg(12'hC00, 16'h4000, "set-clear collision");

    wr(12'hC21, 2'b11, 16'h0001);
    expect_reg(12'hC00, 16'h0000, "XPRST pending clear");
    expect_reg(12'hC01, 16'h001F, "XPRST enable clear");
    if (draw_enable) $fatal(1, "XPRST did not disable drawing");

    draw_busy=1; draw_buffer=1; draw_sbout=1; draw_sbcount=17;
    draw_overtime=1;
    expect_reg(12'hC20, 16'h9118, "XPSTTS live fields");
    draw_busy=0;
    expect_reg(12'hC20, 16'h9110, "XPSTTS idle busy fields");

    $display("vip_registers: PASS");
    $finish;
  end
endmodule
