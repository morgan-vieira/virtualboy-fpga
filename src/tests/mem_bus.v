`timescale 1ns/1ps

//
// Drives the bus master port and checks the routing contract: exactly one
// select per region and none without req, every device's answer routed back
// on the cycle after the access, zero from the regions nothing drives, and
// work RAM that reads back what was written -- through its mirrors, honoring
// byte lanes, unwritten by traffic aimed at any other region, and undefined
// before the first write.
//
// Device answers are constants wired per region, so a select that fires in
// the wrong region or a mux that picks the wrong input reads back as the
// wrong constant rather than passing by luck.
//

module mem_bus_tb;

  localparam [15:0] VIP_DATA  = 16'h0A0A;
  localparam [15:0] MISC_DATA = 16'h0C0C;
  localparam [15:0] CRAM_DATA = 16'h0E0E;
  localparam [15:0] CROM_DATA = 16'h0F0F;

  reg         clk = 1'b0;
  reg         reset_n = 1'b0;
  reg         req = 1'b0;
  reg  [26:1] addr = 26'd0;
  reg         we = 1'b0;
  reg  [1:0]  be = 2'b00;
  reg  [15:0] wdata = 16'd0;
  wire [15:0] rdata;
  wire        vip_sel, vsu_sel, misc_sel, exp_sel, cart_ram_sel, cart_rom_sel;

  mem_bus dut (
    .clk            (clk),
    .reset_n        (reset_n),
    .req            (req),
    .addr           (addr),
    .we             (we),
    .be             (be),
    .wdata          (wdata),
    .rdata          (rdata),
    .vip_sel        (vip_sel),
    .vsu_sel        (vsu_sel),
    .misc_sel       (misc_sel),
    .exp_sel        (exp_sel),
    .cart_ram_sel   (cart_ram_sel),
    .cart_rom_sel   (cart_rom_sel),
    .vip_rdata      (VIP_DATA),
    .misc_rdata     (MISC_DATA),
    .cart_ram_rdata (CRAM_DATA),
    .cart_rom_rdata (CROM_DATA)
  );

  always #5 clk = ~clk;

  wire [5:0] sels = {vip_sel, vsu_sel, misc_sel, exp_sel, cart_ram_sel, cart_rom_sel};

  // One req cycle at a, checking the selects mid-cycle against expected.
  task automatic access(input [26:0] a, input write, input [1:0] lanes,
                        input [15:0] d, input [5:0] expected_sels);
    begin
      @(negedge clk);
      req   = 1'b1;
      we    = write;
      be    = lanes;
      addr  = a[26:1];
      wdata = d;
      #1;
      if (sels !== expected_sels)
        $fatal(1, "addr %07x: selects %06b, expected %06b", a, sels, expected_sels);
      @(negedge clk);
      req = 1'b0;
      we  = 1'b0;
    end
  endtask

  task automatic write_hw(input [26:0] a, input [1:0] lanes, input [15:0] d,
                          input [5:0] expected_sels);
    access(a, 1'b1, lanes, d, expected_sels);
  endtask

  // The answer is due the cycle after the access, sampled before anything else
  // is driven, so a device that answers late or never fails here. Reads drive
  // live byte lanes and junk wdata on purpose: only we may gate a write.
  task automatic read_hw(input [26:0] a, input [5:0] expected_sels,
                         output [15:0] d);
    begin
      access(a, 1'b0, 2'b11, 16'h6666, expected_sels);
      d = rdata;
    end
  endtask

  task automatic expect_read(input [26:0] a, input [5:0] expected_sels,
                             input [15:0] expected, input [127:0] what);
    reg [15:0] d;
    begin
      read_hw(a, expected_sels, d);
      if (d !== expected)
        $fatal(1, "%0s: addr %07x read %04x, expected %04x", what, a, d, expected);
    end
  endtask

  reg [15:0] d;
  integer    i;

  initial begin
    repeat (4) @(posedge clk);
    reset_n = 1'b1;

    // No req, no selects -- and rdata is zero out of reset, not x.
    @(negedge clk);
    #1;
    if (sels !== 6'b000000) $fatal(1, "selects asserted without req");
    if (rdata !== 16'd0)    $fatal(1, "rdata %04x out of reset, expected 0", rdata);

    // Each region hits exactly its own select, at both ends of the region.
    // Regions 3 (unmapped) and 5 (work RAM, internal) assert no select at all.
    expect_read(27'h0000000, 6'b100000, VIP_DATA,  "vip base");
    expect_read(27'h0FFFFFE, 6'b100000, VIP_DATA,  "vip top");
    expect_read(27'h2000000, 6'b001000, MISC_DATA, "misc base");
    expect_read(27'h2FFFFFE, 6'b001000, MISC_DATA, "misc top");
    expect_read(27'h6000000, 6'b000010, CRAM_DATA, "cart ram base");
    expect_read(27'h6FFFFFE, 6'b000010, CRAM_DATA, "cart ram top");
    expect_read(27'h7000000, 6'b000001, CROM_DATA, "cart rom base");
    expect_read(27'h7FFFFFE, 6'b000001, CROM_DATA, "cart rom top");

    // The regions nothing drives answer zero: VSU reads are undefined on its
    // 8-bit bus, expansion is unpopulated, unmapped is defined as zero.
    expect_read(27'h1000000, 6'b010000, 16'd0, "vsu read");
    expect_read(27'h3000000, 6'b000000, 16'd0, "unmapped read");
    expect_read(27'h4000000, 6'b000100, 16'd0, "expansion read");

    // Work RAM is undefined until written; a defined value here means
    // initialization logic crept in.
    read_hw(27'h5004000, 6'b000000, d);
    if (!$isunknown(d))
      $fatal(1, "unwritten work RAM read %04x, expected x", d);

    // Write and read back at both ends of the 64 KiB.
    write_hw(27'h5000000, 2'b11, 16'h1234, 6'b000000);
    write_hw(27'h500FFFE, 2'b11, 16'h5678, 6'b000000);
    expect_read(27'h5000000, 6'b000000, 16'h1234, "wram low");
    expect_read(27'h500FFFE, 6'b000000, 16'h5678, "wram high");

    // Mirrors: bits 16-23 are ignored, so every alias reads the same cell
    // and a write through an alias lands in it.
    expect_read(27'h5AB0000, 6'b000000, 16'h1234, "wram mirror read");
    write_hw(27'h5FF0000, 2'b11, 16'h9ABC, 6'b000000);
    expect_read(27'h5000000, 6'b000000, 16'h9ABC, "wram mirror write");

    // Byte lanes: each enable writes only its own byte.
    write_hw(27'h5000100, 2'b11, 16'hAABB, 6'b000000);
    write_hw(27'h5000100, 2'b01, 16'hCCDD, 6'b000000);
    expect_read(27'h5000100, 6'b000000, 16'hAADD, "low lane only");
    write_hw(27'h5000100, 2'b10, 16'hEEFF, 6'b000000);
    expect_read(27'h5000100, 6'b000000, 16'hEEDD, "high lane only");

    // Traffic aimed anywhere else must not land in work RAM, even at
    // addresses whose low bits alias a written cell.
    write_hw(27'h6000000, 2'b11, 16'hDEAD, 6'b000010);
    write_hw(27'h3000000, 2'b11, 16'hDEAD, 6'b000000);
    write_hw(27'h7000000, 2'b11, 16'hDEAD, 6'b000001);
    expect_read(27'h5000000, 6'b000000, 16'h9ABC, "wram after foreign writes");

    // A read cycle must not write.
    expect_read(27'h5000000, 6'b000000, 16'h9ABC, "wram after read");
    expect_read(27'h5000000, 6'b000000, 16'h9ABC, "wram after read, again");

    // The answer holds between accesses rather than drifting.
    read_hw(27'h5000000, 6'b000000, d);
    for (i = 0; i < 4; i = i + 1) begin
      @(negedge clk);
      if (rdata !== d)
        $fatal(1, "rdata drifted to %04x while idle, was %04x", rdata, d);
    end

    // Back-to-back: a CPU fetching sequentially never idles the bus. req
    // stays high across five accesses and every answer lands exactly one
    // cycle behind its own access -- a store read back on the very next
    // cycle, then answers crossing three region switches.
    @(negedge clk);
    req   = 1'b1;
    we    = 1'b1;
    be    = 2'b11;
    wdata = 16'hBEEF;
    addr  = 27'h5000200 >> 1;
    @(negedge clk);
    we    = 1'b0;
    wdata = 16'h6666;
    @(negedge clk);
    addr  = 27'h7000000 >> 1;
    if (rdata !== 16'hBEEF)
      $fatal(1, "store then next-cycle load read %04x, expected beef", rdata);
    @(negedge clk);
    addr  = 27'h0000000 >> 1;
    if (rdata !== CROM_DATA)
      $fatal(1, "back-to-back rom read %04x, expected %04x", rdata, CROM_DATA);
    @(negedge clk);
    addr  = 27'h5000200 >> 1;
    if (rdata !== VIP_DATA)
      $fatal(1, "back-to-back vip read %04x, expected %04x", rdata, VIP_DATA);
    @(negedge clk);
    req = 1'b0;
    if (rdata !== 16'hBEEF)
      $fatal(1, "final back-to-back load read %04x, expected beef", rdata);

    $finish;
  end

  initial begin
    #100_000;
    $fatal(1, "timed out");
  end

endmodule
