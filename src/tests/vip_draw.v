`timescale 1ns/1ps

// vip_draw: rendering semantics and the measured strip pacing.
//
// Scenarios: the original normal/h-bias/object/affine paths, plus the
// world-size fields at their documented bit positions, base-map rounding,
// the >8-map arrangement, the overplane character fetched as a DRAM cell,
// the h-bias OR-one right-eye rule with 16-bit parameter wrap, affine
// unaligned-base rejection and MP eye selection, object group cycling and
// per-eye independence from world LON/RON, and the measured service
// budgets, SBOUT hold, and XPRST recovery.

module vip_draw_tb;
  reg clk=0, reset_n=0, start=0, reset_draw=0, target_buffer=0;
  reg [39:0] spt=0;
  reg [31:0] gplt=32'h000000e4;
  reg [31:0] jplt=0;
  reg [1:0] bkcol=0;
  wire busy,done,strip_begin,first_group_done,sbout;
  wire [4:0] strip_number;
  wire mem_req,mem_we;
  wire [18:1] mem_addr;
  wire [1:0] mem_be;
  wire [15:0] mem_wdata;
  reg [15:0] mem_rdata=0;
  wire mem_ready;
  reg [15:0] memory [0:262143];
  integer cycles;
  integer k;

  // Architectural 20 MHz time: one ce every two 39.936 MHz clocks is the
  // pacing the budgets count; the exact 625/1248 ratio is pinned elsewhere.
  reg ce = 0;
  always @(posedge clk) ce <= ~ce;
  integer ce_count = 0;
  always @(posedge clk) if (ce) ce_count = ce_count + 1;

  vip_draw dut(.*);
  always #5 clk=~clk;

  // DRAM answers through pocket_sram's handshake: three access cycles, a
  // one-cycle ready pulse, then a release phase that insists the request
  // drop before the next one. A request the renderer abandons parks this
  // model exactly the way it parks the chip, so the bench hangs instead
  // of passing on latency it never sees on hardware.
  wire dram_range = mem_addr >= 18'h10000 && mem_addr < 18'h20000;
  wire dram_sel = mem_req && dram_range;
  reg [2:0] sram_state = 0;  // 0 idle, 1-3 access, 4 response, 5 release
  reg [18:1] sram_addr;
  reg sram_we;
  reg [15:0] sram_wdata;
  reg [7:0] parked = 0;
  assign mem_ready = !dram_sel || sram_state == 3'd4;

  always @(posedge clk) begin
    parked <= (sram_state == 3'd5 && dram_sel) ? parked + 8'd1 : 8'd0;
    if (parked == 8'd64)
      $fatal(1,"abandoned DRAM request: renderer re-requested while the sram held an unconsumed access");
    case (sram_state)
      3'd0: if (dram_sel) begin
        sram_addr  <= mem_addr;
        sram_we    <= mem_we;
        sram_wdata <= mem_wdata;
        sram_state <= 3'd1;
      end
      3'd1, 3'd2: sram_state <= sram_state + 3'd1;
      3'd3: begin
        if (sram_we) memory[sram_addr] <= sram_wdata;
        else mem_rdata <= memory[sram_addr];
        sram_state <= 3'd4;
      end
      3'd4: sram_state <= 3'd5;
      default: if (!dram_sel) sram_state <= 3'd0;
    endcase
    if (mem_req && !dram_range) begin
      mem_rdata <= memory[mem_addr];
      if (mem_we) memory[mem_addr] <= mem_wdata;
    end
  end

  task clear_all;
    integer i;
    begin
      for (i = 0; i < 262144; i = i + 1) memory[i] = 16'h0000;
      // Characters: 1 solid raw-1, 2 solid raw-2, 3 solid raw-3,
      // 4 left-half raw-1, 5 lone top-left pixel.
      for (i = 0; i < 8; i = i + 1) begin
        memory[18'h3C000 + 8 + i]  = 16'h5555;
        memory[18'h3C000 + 16 + i] = 16'haaaa;
        memory[18'h3C000 + 24 + i] = 16'hffff;
        memory[18'h3C000 + 32 + i] = 16'h0055;
        memory[18'h3C000 + 40 + i] = 16'h0000;
      end
      memory[18'h3C000 + 40] = 16'h0001;
    end
  endtask

  task run_frame(input integer limit);
    begin
      @(negedge clk); start=1;
      @(negedge clk); start=0;
      cycles=0;
      while(!done && cycles < limit) begin @(posedge clk); cycles=cycles+1; end
      if(!done) $fatal(1,"renderer did not finish");
    end
  endtask

  task reset_dut;
    begin
      @(negedge clk); reset_n=0;
      repeat(2) @(posedge clk); reset_n=1;
    end
  endtask

  // Every frame now costs the measured service budgets, so give each run
  // room: 55k ce is ~110k clocks before engine work.
  localparam integer FRAME_LIMIT = 300000;
  integer start_ce, done_ce, t;

  initial begin
    clear_all;

    // --- S1: normal world, exact budgets, SBOUT hold ---------------------
    // World 31: an 8x8 normal background for both eyes; world 30 ends.
    memory[18'h1EC00 + 31*16 + 0] = 16'hC000;
    memory[18'h1EC00 + 31*16 + 7] = 7;
    memory[18'h1EC00 + 31*16 + 8] = 7;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    memory[18'h10000] = 16'h0001;

    repeat(3) @(posedge clk); reset_n=1;
    @(negedge clk); start=1;
    @(negedge clk); start=0;
    start_ce = ce_count;

    // Setup takes 32 ce before the first strip begins.
    cycles=0;
    while(!strip_begin && cycles < 1000) begin @(posedge clk); cycles=cycles+1; end
    if(!strip_begin) $fatal(1,"first strip never began");
    if(ce_count - start_ce < 30 || ce_count - start_ce > 36)
      $fatal(1,"draw setup interval wrong: %0d ce", ce_count - start_ce);

    // SBOUT rises with the strip and holds the documented 56 us.
    t = ce_count;
    @(posedge clk); @(posedge clk);
    if(!sbout) $fatal(1,"sbout did not rise at strip start");
    while(sbout) @(posedge clk);
    if(ce_count - t < 1110 || ce_count - t > 1130)
      $fatal(1,"sbout hold wrong: %0d ce", ce_count - t);

    cycles=0;
    while(!done && cycles < FRAME_LIMIT) begin @(posedge clk); cycles=cycles+1; end
    if(!done) $fatal(1,"renderer did not finish");
    done_ce = ce_count - start_ce;
    // 32 + 2033 + 27*1949 = 54,688 plus END intervals and engine work.
    if(done_ce < 54688 || done_ce > 58000)
      $fatal(1,"frame duration off the measured budget: %0d ce", done_ce);

    if(memory[0] !== 16'h5555 || memory[32] !== 16'h5555 ||
       memory[18'h08000] !== 16'h5555 || memory[18'h08020] !== 16'h5555)
      $fatal(1,"normal world pixels wrong: %04x %04x %04x %04x",
        memory[0],memory[32],memory[18'h08000],memory[18'h08020]);
    if(memory[8*32] !== 16'h0000) $fatal(1,"normal world exceeded W");
    if(memory[1] !== 16'h0000) $fatal(1,"normal world exceeded H");

    // --- S1b: H of 2 still draws eight rows; row eight stays clear -------
    reset_dut;
    memory[18'h1EC00 + 31*16 + 8] = 2;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'h5555)
      $fatal(1,"minimum height not applied: %04x", memory[0]);
    if(memory[1] !== 16'h0000) $fatal(1,"minimum height overdrew");

    // --- S1c: negative W draws nothing -----------------------------------
    reset_dut;
    memory[18'h1EC00 + 31*16 + 7] = 16'h1FFF;
    memory[18'h1EC00 + 31*16 + 8] = 7;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'h0000)
      $fatal(1,"negative W drew pixels: %04x", memory[0]);
    memory[18'h1EC00 + 31*16 + 7] = 7;

    // --- S2: size fields at their documented bits ------------------------
    // SCX=1 makes the background two maps wide; MX=512 lands in map 1.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC400;
    memory[18'h1EC00 + 31*16 + 4] = 512;
    memory[18'h11000] = 16'h0002;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'haaaa)
      $fatal(1,"SCX not read from bits 11:10: %04x", memory[0]);

    // SCY=1 makes it two maps tall; MY=512 lands in map 1.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC100;
    memory[18'h1EC00 + 31*16 + 4] = 0;
    memory[18'h1EC00 + 31*16 + 6] = 512;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'haaaa)
      $fatal(1,"SCY not read from bits 9:8: %04x", memory[0]);
    memory[18'h1EC00 + 31*16 + 6] = 0;
    memory[18'h11000] = 16'h0000;

    // Base 11 of a four-map background rounds down to 8.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC50B;
    memory[18'h18000] = 16'h0003;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'hffff)
      $fatal(1,"base map did not round down: %04x", memory[0]);
    memory[18'h18000] = 16'h0000;

    // Sixteen maps behave as two wide by four tall, repeating: map column
    // two aliases onto column zero rather than reaching map 2.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hCA00;
    memory[18'h1EC00 + 31*16 + 4] = 1024;
    memory[18'h10000] = 16'h0001;
    memory[18'h12000] = 16'h0002;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'h5555)
      $fatal(1,">8-map arrangement wrong: %04x", memory[0]);
    memory[18'h12000] = 16'h0000;
    memory[18'h1EC00 + 31*16 + 4] = 0;

    // --- S3: overplane ----------------------------------------------------
    // OVER set: out-of-bounds coordinates use the cell that the Overplane
    // Character register points at in DRAM.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC080;
    memory[18'h1EC00 + 31*16 + 4] = 16'h1FF8; // MX = -8
    memory[18'h1EC00 + 31*16 + 10] = 16'h0100;
    memory[18'h10100] = 16'h0002;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'haaaa)
      $fatal(1,"overplane cell not fetched from DRAM: %04x", memory[0]);

    // OVER clear: the same coordinates wrap to the far edge instead.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC000;
    memory[18'h10000 + 63] = 16'h0003;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'hffff)
      $fatal(1,"wrap without overplane wrong: %04x", memory[0]);
    memory[18'h10000 + 63] = 16'h0000;
    memory[18'h1EC00 + 31*16 + 4] = 0;
    memory[18'h1EC00 + 31*16 + 10] = 0;
    memory[18'h10100] = 16'h0000;

    // --- S4: h-bias -------------------------------------------------------
    // Independent signed offsets per eye through the OR-one rule.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 0] = 16'hD000;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0800;
    memory[18'h10800] = 1;
    memory[18'h10801] = 0;
    memory[18'h10000] = 16'h0004; // left-half-opaque character
    run_frame(FRAME_LIMIT);
    // Left shifted by one: source 3 at x=2 is opaque, source 4 at x=3 not.
    if(memory[2*32][1:0] !== 2'd1 || memory[3*32][1:0] !== 2'd0)
      $fatal(1,"h-bias left offset wrong: %04x %04x",
        memory[2*32],memory[3*32]);
    if(memory[18'h08000 + 3*32][1:0] !== 2'd1 ||
       memory[18'h08000 + 4*32][1:0] !== 2'd0)
      $fatal(1,"h-bias right offset wrong: %04x %04x",
        memory[18'h08000+3*32],memory[18'h08000+4*32]);

    // An odd Param Base serves HOFSTL to both eyes: the right eye shifts
    // by the left's two rather than its own zero.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0801;
    memory[18'h10801] = 2;
    memory[18'h10802] = 0;
    run_frame(FRAME_LIMIT);
    if(memory[18'h08000][1:0] !== 2'd1 ||
       memory[18'h08000 + 1*32][1:0] !== 2'd1)
      $fatal(1,"odd param base right eye not drawn: %04x %04x",
        memory[18'h08000],memory[18'h08000+1*32]);
    if(memory[18'h08000 + 2*32][1:0] !== 2'd0)
      $fatal(1,"odd param base did not alias the right eye: %04x",
        memory[18'h08000+2*32]);

    // The parameter index wraps at sixteen bits. DRAM halfword zero doubles
    // as the wrapped row's offset and as map cell (0,0), so character 4 is
    // rewritten to light only its right half: a shift of four lands source
    // pixel 4 on screen x0.
    reset_dut;
    for(k=0;k<8;k=k+1) memory[18'h3C000 + 32 + k] = 16'hFF00;
    memory[18'h1EC00 + 31*16 + 3] = 16'hFFFF; // GY = -1: row 1 is y=0
    memory[18'h1EC00 + 31*16 + 9] = 16'hFFFE;
    memory[18'h10000] = 4;                    // wrapped offset and cell
    memory[18'h10001] = 0;
    memory[18'h1EC00 + 31*16 + 6] = 16'h1FFF; // MY = -1
    run_frame(FRAME_LIMIT);
    if(memory[0][1:0] !== 2'd3)
      $fatal(1,"h-bias 16-bit wrap failed: %04x", memory[0]);
    memory[18'h1EC00 + 31*16 + 3] = 0;
    memory[18'h1EC00 + 31*16 + 6] = 0;
    memory[18'h10000] = 16'h0001;
    memory[18'h10001] = 0;

    // --- S5: objects ------------------------------------------------------
    // Parallax places the same object at x=8 left, x=12 right.
    reset_dut;
    clear_all;
    memory[18'h1EC00 + 31*16] = 16'hF000;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    memory[18'h1F000+0] = 10;
    memory[18'h1F000+1] = 16'hC002;
    memory[18'h1F000+2] = 0;
    memory[18'h1F000+3] = 1;
    spt = 40'(1023 << 20);
    jplt = 32'h000000e4;
    run_frame(FRAME_LIMIT);
    if(memory[8*32] !== 16'h5555 || memory[18'h08000+12*32] !== 16'h5555)
      $fatal(1,"object parallax wrong: %04x %04x",
        memory[8*32],memory[18'h08000+12*32]);
    if(memory[7*32] !== 0) $fatal(1,"object ignored left parallax");

    // Object eyes come from JLON/JRON alone; a world with only RON still
    // draws a JLON-only object to the left image.
    reset_dut;
    memory[18'h1EC00 + 31*16] = 16'h7000; // RON only, BGM=3
    memory[18'h1F000+1] = 16'h8000;       // JLON only, no parallax
    run_frame(FRAME_LIMIT);
    if(memory[10*32] !== 16'h5555)
      $fatal(1,"world RON blocked a left-eye object: %04x", memory[10*32]);
    if(memory[18'h08000+10*32] !== 16'h0000)
      $fatal(1,"JRON clear still drew right: %04x", memory[18'h08000+10*32]);

    // Group counter: four groups then back to three. Worlds 31..27 are all
    // object worlds; obj0 (group 0) and obj3 (group 3) share a spot, and
    // the fifth world redraws group 3 in front.
    reset_dut;
    memory[18'h1EC00 + 31*16] = 16'hF000;
    memory[18'h1EC00 + 30*16] = 16'hF000;
    memory[18'h1EC00 + 29*16] = 16'hF000;
    memory[18'h1EC00 + 28*16] = 16'hF000;
    memory[18'h1EC00 + 27*16] = 16'hF000;
    memory[18'h1EC00 + 26*16] = 16'h0040;
    spt = {10'd3, 10'd2, 10'd1, 10'd0};
    // obj0 draws colour 2, obj3 draws colour 1, both at x=20.
    memory[18'h1F000+0] = 20;
    memory[18'h1F000+1] = 16'hC000;
    memory[18'h1F000+2] = 0;
    memory[18'h1F000+3] = 2;
    memory[18'h1F000+12] = 20;
    memory[18'h1F000+13] = 16'hC000;
    memory[18'h1F000+14] = 0;
    memory[18'h1F000+15] = 1;
    run_frame(FRAME_LIMIT);
    if(memory[20*32] !== 16'h5555)
      $fatal(1,"object group counter did not wrap to 3: %04x", memory[20*32]);

    // End below start wraps through object 1,023.
    reset_dut;
    clear_all;
    memory[18'h1EC00 + 31*16] = 16'hF000;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    spt = {10'd3, 10'd5, 10'd0, 10'd0}; // group 3: end 3, start 6
    memory[18'h1F000 + 1023*4 + 0] = 30;
    memory[18'h1F000 + 1023*4 + 1] = 16'hC000;
    memory[18'h1F000 + 1023*4 + 2] = 0;
    memory[18'h1F000 + 1023*4 + 3] = 1;
    memory[18'h1F000 + 4*4 + 0] = 40;   // object 4 sits outside the group
    memory[18'h1F000 + 4*4 + 1] = 16'hC000;
    memory[18'h1F000 + 4*4 + 2] = 0;
    memory[18'h1F000 + 4*4 + 3] = 1;
    run_frame(2000000);
    if(memory[30*32] !== 16'h5555)
      $fatal(1,"wrapped group missed object 1023: %04x", memory[30*32]);
    if(memory[40*32] !== 16'h0000)
      $fatal(1,"wrapped group drew an excluded object: %04x", memory[40*32]);

    // --- S6: affine -------------------------------------------------------
    // Identity transform: one parameter element per output row.
    reset_dut;
    clear_all;
    for(k=0;k<4096;k=k+1)
      memory[18'h11000+k] = 16'h0001;
    memory[18'h1EC00 + 31*16 + 0] = 16'hE001;
    memory[18'h1EC00 + 31*16 + 7] = 383;
    memory[18'h1EC00 + 31*16 + 8] = 63;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0000;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    for(k=0;k<224;k=k+1) begin
      memory[18'h10000+k*8+0] = 0;
      memory[18'h10000+k*8+1] = 0;
      memory[18'h10000+k*8+2] = 16'(k*8);
      memory[18'h10000+k*8+3] = 512;
      memory[18'h10000+k*8+4] = 0;
    end
    run_frame(2000000);
    if(memory[0] !== 16'h5555 || memory[383*32+7] !== 16'h5555 ||
       memory[18'h08000] !== 16'h5555)
      $fatal(1,"full affine identity wrong: %04x %04x %04x",
        memory[0],memory[383*32+7],memory[18'h08000]);
    if(memory[8] !== 16'h0000 || memory[18'h08008] !== 16'h0000)
      $fatal(1,"affine world exceeded H: %04x %04x",
        memory[8],memory[18'h08008]);

    // Negative MP shifts only the left eye's sampling.
    reset_dut;
    for(k=0;k<8;k=k+1) begin
      memory[18'h10000+k*8+1] = 16'hFFF8; // MP = -8
      memory[18'h10000+k*8+2] = 16'(k*8);
    end
    memory[18'h1EC00 + 31*16 + 8] = 7;
    // The left eye samples from cell column 1; make it distinct while the
    // identity fill keeps column 0 at character 1.
    for(k=0;k<8;k=k+1)
      memory[18'h11000 + k*64 + 1] = 16'h0002;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'haaaa)
      $fatal(1,"negative MP did not shift the left eye: %04x", memory[0]);
    if(memory[18'h08000] !== 16'h5555)
      $fatal(1,"negative MP shifted the right eye: %04x", memory[18'h08000]);

    // An unaligned Param Base is rejected rather than guessed.
    reset_dut;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0001;
    run_frame(FRAME_LIMIT);
    if(memory[0] !== 16'h0000)
      $fatal(1,"unaligned affine base still drew: %04x", memory[0]);

    // --- S7: XPRST recovery ----------------------------------------------
    reset_dut;
    clear_all;
    memory[18'h1EC00 + 31*16 + 0] = 16'hC000;
    memory[18'h1EC00 + 31*16 + 7] = 7;
    memory[18'h1EC00 + 31*16 + 8] = 7;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    memory[18'h10000] = 16'h0001;
    @(negedge clk); start=1;
    @(negedge clk); start=0;
    repeat(2000) @(posedge clk);
    if(!busy) $fatal(1,"draw not busy before XPRST");
    t = ce_count;
    @(negedge clk); reset_draw=1;
    @(negedge clk); reset_draw=0;
    if(!busy) $fatal(1,"XPRST dropped busy without the recovery window");
    cycles=0;
    while(busy && cycles < 200) begin @(posedge clk); cycles=cycles+1; end
    if(busy) $fatal(1,"XPRST recovery never completed");
    if(ce_count - t < 22 || ce_count - t > 28)
      $fatal(1,"XPRST recovery interval wrong: %0d ce", ce_count - t);
    if(done) $fatal(1,"aborted draw still reported done");

    $display("vip_draw: PASS");
    $finish;
  end
endmodule
