`timescale 1ns/1ps

module vip_draw_tb;
  reg clk=0, reset_n=0, start=0, reset_draw=0, target_buffer=0;
  reg [39:0] spt=0;
  reg [31:0] gplt=32'h00000004;
  reg [31:0] jplt=0;
  reg [1:0] bkcol=0;
  wire busy,done,strip_begin,first_group_done;
  wire [4:0] strip_number;
  wire mem_req,mem_we;
  wire [18:1] mem_addr;
  wire [1:0] mem_be;
  wire [15:0] mem_wdata;
  reg [15:0] mem_rdata=0;
  wire mem_ready;
  reg [15:0] memory [0:262143];
  integer cycles;

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

  initial begin
    // Defined contents everywhere: an X address would poison mem_ready.
    for (cycles = 0; cycles < 262144; cycles = cycles + 1)
      memory[cycles] = 16'h0000;

    // World 31: an 8x8 normal background for both eyes.
    memory[18'h1EC00 + 31*16 + 0] = 16'hC000;
    memory[18'h1EC00 + 31*16 + 1] = 0;
    memory[18'h1EC00 + 31*16 + 2] = 0;
    memory[18'h1EC00 + 31*16 + 3] = 0;
    memory[18'h1EC00 + 31*16 + 4] = 0;
    memory[18'h1EC00 + 31*16 + 5] = 0;
    memory[18'h1EC00 + 31*16 + 6] = 0;
    memory[18'h1EC00 + 31*16 + 7] = 7;
    memory[18'h1EC00 + 31*16 + 8] = 7;
    memory[18'h1EC00 + 31*16 + 9] = 0;
    memory[18'h1EC00 + 31*16 + 10] = 0;
    // World 30 terminates processing.
    memory[18'h1EC00 + 30*16] = 16'h0040;
    memory[18'h10000] = 16'h0001;
    memory[18'h3C008] = 16'h5555;
    memory[18'h3C009] = 16'h5555;
    memory[18'h3C00A] = 16'h5555;
    memory[18'h3C00B] = 16'h5555;
    memory[18'h3C00C] = 16'h5555;
    memory[18'h3C00D] = 16'h5555;
    memory[18'h3C00E] = 16'h5555;
    memory[18'h3C00F] = 16'h5555;

    repeat(3) @(posedge clk); reset_n=1;
    @(negedge clk); start=1;
    @(negedge clk); start=0;
    cycles=0;
    while(!done && cycles < 200000) begin @(posedge clk); cycles=cycles+1; end
    if(!done) $fatal(1,"renderer did not finish");
    if(memory[0] !== 16'h5555 || memory[32] !== 16'h5555 ||
       memory[18'h08000] !== 16'h5555 || memory[18'h08020] !== 16'h5555)
      $fatal(1,"normal world pixels wrong: %04x %04x %04x %04x world=%04x map=%04x char=%04x",
        memory[0],memory[32],memory[18'h08000],memory[18'h08020],
        dut.world[0],dut.map_cell,dut.char_pixels);
    if(memory[8*32] !== 16'h0000) $fatal(1,"normal world exceeded W");
    if(memory[1] !== 16'h0000) $fatal(1,"normal world exceeded H");

    // H-bias uses independent signed offsets for each eye.
    @(negedge clk); reset_n=0;
    repeat(2) @(posedge clk); reset_n=1;
    memory[18'h1EC00 + 31*16 + 0] = 16'hD000;
    memory[18'h1EC00 + 31*16 + 7] = 7;
    memory[18'h1EC00 + 31*16 + 8] = 7;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0800;
    memory[18'h10800] = 1;
    memory[18'h10801] = 0;
    memory[18'h3C008] = 16'h1111;
    @(negedge clk); start=1; @(negedge clk); start=0;
    cycles=0;
    while(!done && cycles < 200000) begin @(posedge clk); cycles=cycles+1; end
    if(!done) $fatal(1,"H-bias renderer did not finish");
    if(memory[0][1:0] !== 2'd0 || memory[18'h08000][1:0] !== 2'd1)
      $fatal(1,"H-bias eye offsets wrong: %04x %04x",
        memory[0],memory[18'h08000]);

    // Object group 3: parallax places the same object at x=8 left, x=12 right.
    @(negedge clk); reset_n=0;
    repeat(2) @(posedge clk); reset_n=1;
    memory[18'h1EC00 + 31*16] = 16'hF000;
    memory[18'h1EC00 + 30*16] = 16'h0040;
    memory[18'h1F000+0] = 10;
    memory[18'h1F000+1] = 16'hC002;
    memory[18'h1F000+2] = 0;
    memory[18'h1F000+3] = 1;
    spt = 40'(1023 << 20);
    jplt = 32'h00000004;
    @(negedge clk); start=1; @(negedge clk); start=0;
    cycles=0;
    while(!done && cycles < 200000) begin @(posedge clk); cycles=cycles+1; end
    if(!done) $fatal(1,"object renderer did not finish");
    if(memory[8*32] !== 16'h5555 || memory[18'h08000+12*32] !== 16'h5555)
      $fatal(1,"object parallax wrong: %04x %04x",
        memory[8*32],memory[18'h08000+12*32]);
    if(memory[7*32] !== 0) $fatal(1,"object ignored left parallax");

    // Affine identity transform: one parameter element per output row.
    @(negedge clk); reset_n=0;
    repeat(2) @(posedge clk); reset_n=1;
    for(cycles=0;cycles<8;cycles=cycles+1)
      memory[18'h3C008+cycles] = 16'h5555;
    for(cycles=0;cycles<4096;cycles=cycles+1)
      memory[18'h11000+cycles] = 16'h0001;
    memory[18'h1EC00 + 31*16 + 0] = 16'hE001;
    memory[18'h1EC00 + 31*16 + 1] = 0;
    memory[18'h1EC00 + 31*16 + 2] = 0;
    memory[18'h1EC00 + 31*16 + 3] = 0;
    memory[18'h1EC00 + 31*16 + 7] = 383;
    memory[18'h1EC00 + 31*16 + 8] = 63;
    memory[18'h1EC00 + 31*16 + 9] = 16'h0000;
    for(cycles=0;cycles<224;cycles=cycles+1) begin
      memory[18'h10000+cycles*8+0] = 0;
      memory[18'h10000+cycles*8+1] = 0;
      memory[18'h10000+cycles*8+2] = cycles*8;
      memory[18'h10000+cycles*8+3] = 512;
      memory[18'h10000+cycles*8+4] = 0;
    end
    @(negedge clk); start=1; @(negedge clk); start=0;
    cycles=0;
    while(!done && cycles < 2000000) begin @(posedge clk); cycles=cycles+1; end
    if(!done) $fatal(1,"affine renderer did not finish");
    if(memory[0] !== 16'h5555 || memory[383*32+7] !== 16'h5555 ||
       memory[18'h08000] !== 16'h5555)
      $fatal(1,"full affine identity wrong: %04x %04x %04x",
        memory[0],memory[383*32+7],memory[18'h08000]);
    if(memory[8] !== 16'h0000 || memory[18'h08008] !== 16'h0000)
      $fatal(1,"affine world exceeded H: %04x %04x",
        memory[8],memory[18'h08008]);

    $display("vip_draw: PASS");
    $finish;
  end
endmodule
