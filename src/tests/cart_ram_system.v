`timescale 1ns/1ps
//
// The save RAM's whole reason to exist, run end to end: the real CPU, mem_bus
// and cart_ram executing the built cart-ram image across three power cycles,
// with the bridge standing in for APF on both sides of each one.
//
// A boot here is what the Pocket does. The slot is filled with 0xFF the first
// time, the way data.json's parameter bit 5 fills a save that has no file yet;
// the ROM runs and leaves its record behind; the slot is read back out over
// the bridge, which is the flush APF performs at shutdown; the cells are then
// scribbled over, because a real power cycle does not leave block RAM intact;
// and what was read out is written back in for the next boot.
//
// The verdict is the ROM's own: its status word carries a boot count kept in
// save RAM, so 0x5A01, 0x5A02, 0x5A03 across three runs is the save surviving,
// and a count stuck at 0x5A01 is the failure this whole feature is about. No
// simulation can prove APF holds up its end -- only a maintainer watching a
// Pocket quit and relaunch can -- but everything on this side of the bridge is
// proven before it gets there.
//

module cart_ram_system_tb;

    localparam ROM_HWORDS = 512;    // cart-ram.vb is 1KB
    localparam SAVE_BYTES = 8192;
    localparam SAVE_WORDS = SAVE_BYTES / 4;

    localparam [31:0] SLOT = 32'h01000000;

    reg clk = 1'b0;
    always #12.52 clk = ~clk;       // 39.936 MHz, the CPU domain

    reg bridge_clk = 1'b0;
    always #6.7 bridge_clk = ~bridge_clk;

    // Architectural time at the hardware's own 625/1248 ratio.
    reg        ce = 1'b0;
    reg [10:0] ce_acc = 11'd0;
    always @(posedge clk) begin
        if (ce_acc + 11'd625 >= 11'd1248) begin
            ce_acc <= ce_acc + 11'd625 - 11'd1248;
            ce     <= 1'b1;
        end else begin
            ce_acc <= ce_acc + 11'd625;
            ce     <= 1'b0;
        end
    end

    reg reset_n = 1'b0;

    wire        req, we;
    wire [26:1] a;
    wire [1:0]  be;
    wire [15:0] wd;
    wire [15:0] cpu_rdata;
    wire        cpu_ready;
    wire [31:0] dbg_pc;
    wire        dbg_halted;

    cpu u_cpu (
        .clk(clk), .ce(ce), .reset_n(reset_n),
        .req(req), .addr(a), .we(we), .be(be), .wdata(wd),
        .rdata(cpu_rdata), .ready(cpu_ready),
        .irq_valid(1'b0), .irq_level(4'd0),
        .dbg_pc(dbg_pc), .dbg_halted(dbg_halted)
    );

    wire        cart_rom_sel;
    reg  [15:0] cart_rom_rdata;
    wire        cart_ram_sel;
    wire [15:0] cart_ram_rdata;

    mem_bus u_bus (
        .clk(clk), .reset_n(reset_n),
        .req(req), .addr(a), .we(we), .be(be), .wdata(wd),
        .rdata(cpu_rdata), .ready(cpu_ready),
        .vip_sel(), .vsu_sel(), .misc_sel(),
        .exp_sel(), .cart_ram_sel(cart_ram_sel), .cart_rom_sel(cart_rom_sel),
        .vip_rdata(16'd0), .vip_ready(1'b1),
        .misc_rdata(16'd0),
        .cart_ram_rdata(cart_ram_rdata),
        .cart_rom_rdata(cart_rom_rdata),
        .cart_rom_ready(1'b1)
    );

    // Behavioral cartridge: the built image, mirrored by its size mask,
    // answering the cycle after its select the way cart_rom does.
    reg [15:0] rom [0:ROM_HWORDS-1];
    always @(posedge clk)
        if (req && a[26:24] == 3'd7)
            cart_rom_rdata <= rom[a[16:1] & (ROM_HWORDS - 1)];

    reg         load_begin = 1'b0;
    reg         bridge_wr = 1'b0;
    reg         bridge_rd = 1'b0;
    reg  [31:0] bridge_addr = 32'd0;
    reg  [31:0] bridge_wr_data = 32'd0;
    wire [31:0] bridge_rd_data;

    cart_ram uut (
        .bridge_clk(bridge_clk),
        .load_begin(load_begin),
        .bridge_wr(bridge_wr),
        .bridge_rd(bridge_rd),
        .bridge_addr(bridge_addr),
        .bridge_wr_data(bridge_wr_data),
        .bridge_rd_data(bridge_rd_data),
        .clk(clk),
        .sel(cart_ram_sel),
        .addr(a),
        .we(we),
        .be(be),
        .wdata(wd),
        .rdata(cart_ram_rdata)
    );

    // The status convention: check numbers land at WRAM 0x05000000.
    reg [15:0] status = 16'hffff;
    always @(posedge clk)
        if (req && we && a[26:24] == 3'd5 && a[16:1] == 16'd0)
            status <= wd;

    // The .sav on the SD card, as far as this bench is concerned. Eight
    // bridge clocks between accesses is generous for a five-clock walk; the
    // spacing APF actually holds is pinned in src/tests/cart_ram.v.
    reg [31:0] file [0:SAVE_WORDS-1];

    integer i;

    task automatic begin_load;
        begin
            @(negedge bridge_clk);
            load_begin = 1'b1;
            @(negedge bridge_clk);
            load_begin = 1'b0;
        end
    endtask

    task automatic bridge_write(input [31:0] offset, input [31:0] value);
        begin
            @(negedge bridge_clk);
            bridge_wr      = 1'b1;
            bridge_addr    = SLOT + offset;
            bridge_wr_data = value;
            @(negedge bridge_clk);
            bridge_wr = 1'b0;
            repeat (8) @(negedge bridge_clk);
        end
    endtask

    task automatic bridge_read(input [31:0] offset, output [31:0] value);
        begin
            @(negedge bridge_clk);
            bridge_rd   = 1'b1;
            bridge_addr = SLOT + offset;
            @(negedge bridge_clk);
            bridge_rd = 1'b0;
            repeat (8) @(negedge bridge_clk);
            value = bridge_rd_data;
        end
    endtask

    // A save file that does not exist yet: parameter bit 5 overwrites the
    // slot with 0xFF up to size_maximum, the way an erased SRAM reads.
    task automatic erase_file;
        integer w;
        begin
            for (w = 0; w < SAVE_WORDS; w = w + 1) file[w] = 32'hFFFFFFFF;
        end
    endtask

    task automatic load_slot;
        integer w;
        begin
            begin_load();
            for (w = 0; w < SAVE_WORDS; w = w + 1)
                bridge_write(w * 4, file[w]);
        end
    endtask

    task automatic flush_slot;
        integer w;
        reg [31:0] value;
        begin
            for (w = 0; w < SAVE_WORDS; w = w + 1) begin
                bridge_read(w * 4, value);
                file[w] = value;
            end
        end
    endtask

    // Block RAM does not survive a power cycle, and neither should anything
    // this bench proves. Only what went out through the bridge comes back.
    task automatic power_cycle;
        integer c;
        begin
            for (c = 0; c < SAVE_BYTES; c = c + 1)
                uut.cells[c] = 8'hA5 ^ c[7:0];
        end
    endtask

    task automatic run_rom(input [15:0] want, input integer max_cycles);
        integer c;
        begin
            reset_n = 1'b0;
            status  = 16'hffff;
            repeat (4) @(posedge clk);
            reset_n = 1'b1;
            c = 0;
            while (!dbg_halted && c < max_cycles) begin
                @(posedge clk);
                c = c + 1;
            end
            if (!dbg_halted)
                $fatal(1, "never halted in %0d cycles, status %04x pc %08x",
                       max_cycles, status, dbg_pc);
            if (status !== want)
                $fatal(1, "halted with status %04x, expected %04x, pc %08x",
                       status, want, dbg_pc);
        end
    endtask

    task automatic expect_record(input [31:0] expected, input [255:0] what);
        begin
            if (file[0] !== expected)
                $fatal(1, "%0s: the flushed save begins %08x, expected %08x",
                       what, file[0], expected);
        end
    endtask

    initial begin
        $readmemh("../.roms/cart-ram.hex", rom);

        // First launch of a cartridge that has never been saved.
        erase_file();
        load_slot();
        run_rom(16'h5a01, 400000);
        flush_slot();
        expect_record(32'h564201FE, "first boot");

        // Quit, power off, launch again. Twice, because a count that advances
        // once could be the fill and not the file.
        power_cycle();
        load_slot();
        run_rom(16'h5a02, 400000);
        flush_slot();
        expect_record(32'h564202FD, "second boot");

        power_cycle();
        load_slot();
        run_rom(16'h5a03, 400000);
        flush_slot();
        expect_record(32'h564203FC, "third boot");

        $display("cart_ram_system: PASS");
        $finish;
    end

    initial begin
        #200_000_000;
        $fatal(1, "timed out");
    end

endmodule
