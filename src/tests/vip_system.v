`timescale 1ns/1ps

// Full-system runs of the VIP conformance ROMs: the real CPU, mem_bus, and
// VIP with a pocket_sram-shaped DRAM model, each image executed through the
// reset vector to its success halt. The ROMs' own frame-buffer readback
// does the judging; the status word carries the verdict, so a failure names
// the exact check.
//
// The VIP is instantiated with a 4 ms frame so a run that would take
// hundreds of host milliseconds stays affordable; every draw still pays the
// full measured 2.73 ms service budget, so the shrink only trims the idle
// wait between game frames.

module vip_system_tb;

    localparam ROM_HWORDS = 8192;   // largest conformance image is 16KB

    reg clk = 1'b0;
    always #5 clk = ~clk;

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

    wire        vip_sel;
    wire [15:0] vip_rdata;
    wire        vip_ready;
    wire        vip_irq;

    cpu u_cpu (
        .clk(clk), .ce(ce), .reset_n(reset_n),
        .req(req), .addr(a), .we(we), .be(be), .wdata(wd),
        .rdata(cpu_rdata), .ready(cpu_ready),
        .irq_valid(vip_irq), .irq_level(4'd4),
        .dbg_pc(dbg_pc), .dbg_halted(dbg_halted)
    );

    wire        cart_rom_sel;
    reg  [15:0] cart_rom_rdata;

    mem_bus u_bus (
        .clk(clk), .reset_n(reset_n),
        .req(req), .addr(a), .we(we), .be(be), .wdata(wd),
        .rdata(cpu_rdata), .ready(cpu_ready),
        .vip_sel(vip_sel), .vsu_sel(), .misc_sel(),
        .exp_sel(), .cart_ram_sel(), .cart_rom_sel(cart_rom_sel),
        .vip_rdata(vip_rdata), .vip_ready(vip_ready),
        .misc_rdata(16'd0),
        .cart_ram_rdata(16'd0),
        .cart_rom_rdata(cart_rom_rdata),
        .cart_rom_ready(1'b1)
    );

    // Behavioral cartridge: the built image, mirrored by its size mask,
    // answering the cycle after its select the way cart_rom does.
    reg [15:0] rom [0:ROM_HWORDS-1];
    integer rom_mask;
    always @(posedge clk)
        if (req && a[26:24] == 3'd7)
            cart_rom_rdata <= rom[a[16:1] & rom_mask[15:0]];

    wire        dram_req;
    wire [15:0] dram_addr;
    wire        dram_we;
    wire [1:0]  dram_be;
    wire [15:0] dram_wdata;
    reg  [15:0] dram_rdata;
    wire        dram_ready;

    // vip-display's verdict is the picture, so the display port is driven.
    reg  [8:0] disp_x = 9'd0;
    reg  [7:0] disp_y = 8'd0;
    wire [1:0] disp_pixel, disp_pixel_right;
    wire [7:0] disp_luma, disp_luma_right;

    // The stripe sweep pins the exposures the ROM produces, not the table
    // entries they land in; vip_luma_curve's own bench owns the table.
    reg  [7:0] want_exposure;
    wire [7:0] want_luma;
    vip_luma_curve curve_model (.exposure(want_exposure), .luma(want_luma));

    vip #(
        .FRAME_CYCLES(159744), .LEFT_START(24000), .LEFT_END(63936),
        .FCLK_END(79872), .RIGHT_START(104000), .RIGHT_END(143808)
    ) u_vip (
        .clk(clk), .reset_n(reset_n), .ce(ce),
        .cpu_sel(vip_sel), .cpu_addr(a), .cpu_we(we), .cpu_be(be),
        .cpu_wdata(wd), .cpu_rdata(vip_rdata), .cpu_ready(vip_ready),
        .irq(vip_irq),
        .dram_req(dram_req), .dram_addr(dram_addr), .dram_we(dram_we),
        .dram_be(dram_be), .dram_wdata(dram_wdata), .dram_rdata(dram_rdata),
        .dram_ready(dram_ready),
        .display_clk(clk),
        .display_x(disp_x), .display_y(disp_y),
        .display_pixel_left(disp_pixel), .display_pixel_right(disp_pixel_right),
        .display_luma_left(disp_luma), .display_luma_right(disp_luma_right)
    );

    // pocket_sram's shape: three access cycles, a one-cycle ready pulse,
    // then a release phase that insists the request drop first. Contents
    // start as pseudorandom garbage, which is what the ROMs' DRAM clearing
    // loops exist for.
    reg [15:0] dram [0:65535];
    reg [2:0] sram_state = 3'd0;
    reg [15:0] sram_addr;
    reg sram_we_q;
    reg [15:0] sram_wdata_q;
    reg [1:0] sram_be_q;
    assign dram_ready = sram_state == 3'd4;
    always @(posedge clk) begin
        case (sram_state)
            3'd0: if (dram_req) begin
                sram_addr <= dram_addr;
                sram_we_q <= dram_we;
                sram_wdata_q <= dram_wdata;
                sram_be_q <= dram_be;
                sram_state <= 3'd1;
            end
            3'd1, 3'd2: sram_state <= sram_state + 3'd1;
            3'd3: begin
                if (sram_we_q) begin
                    if (sram_be_q[0]) dram[sram_addr][7:0] <= sram_wdata_q[7:0];
                    if (sram_be_q[1]) dram[sram_addr][15:8] <= sram_wdata_q[15:8];
                end else begin
                    dram_rdata <= dram[sram_addr];
                end
                sram_state <= 3'd4;
            end
            3'd4: sram_state <= 3'd5;
            default: if (!dram_req) sram_state <= 3'd0;
        endcase
    end

    // The status convention: check numbers land at WRAM 0x05000000.
    reg [15:0] status = 16'hffff;
    always @(posedge clk)
        if (req && we && a[26:24] == 3'd5 && a[16:1] == 16'd0)
            status <= wd;

    task automatic run_rom(input string name, input integer hwords,
                           input integer max_cycles);
        integer fd, i;
        string  path;
        begin
            reset_n = 1'b0;
            status = 16'hffff;
            path = {"../.roms/", name, ".hex"};
            fd = $fopen(path, "r");
            if (fd == 0)
                $fatal(1, "%0s: cannot open %0s; run pnpm run build:roms first",
                       name, path);
            $fclose(fd);
            $readmemh(path, rom);
            rom_mask = hwords - 1;
            for (i = 0; i < 65536; i = i + 1)
                dram[i] = 16'h5a5a ^ i[15:0];
            repeat (4) @(posedge clk);
            reset_n = 1'b1;
            i = 0;
            while (!dbg_halted && i < max_cycles) begin
                @(posedge clk);
                i = i + 1;
            end
            if (!dbg_halted) begin
                $display("fb0 l=%02x%02x fb1 l=%02x%02x xpstts-busy=%b%b",
                    u_vip.memory.fb_l0_hi[0], u_vip.memory.fb_l0_lo[0],
                    u_vip.memory.fb_l1_hi[0], u_vip.memory.fb_l1_lo[0],
                    u_vip.timing.draw_buffer, u_vip.drawing.busy);
                $fatal(1, "%0s: never halted in %0d cycles, status %04x pc %08x",
                       name, max_cycles, status, dbg_pc);
            end
            if (status !== 16'h600d)
                $fatal(1, "%0s: halted with status %04x, expected 600d",
                       name, status);
            $display("vip_system: %0s PASS", name);
        end
    endtask


    task automatic run_rom_status(input string name, input integer hwords,
                                  input [15:0] want,
                                  input integer max_cycles);
        integer fd, i;
        string  path;
        begin
            reset_n = 1'b0;
            status = 16'hffff;
            path = {"../.roms/", name, ".hex"};
            fd = $fopen(path, "r");
            if (fd == 0)
                $fatal(1, "%0s: cannot open %0s; run pnpm run build:roms first",
                       name, path);
            $fclose(fd);
            $readmemh(path, rom);
            rom_mask = hwords - 1;
            for (i = 0; i < 65536; i = i + 1)
                dram[i] = 16'h5a5a ^ i[15:0];
            repeat (4) @(posedge clk);
            reset_n = 1'b1;
            i = 0;
            while (status !== want && i < max_cycles) begin
                @(posedge clk);
                i = i + 1;
            end
            if (status !== want)
                $fatal(1, "%0s: status %04x never became %04x in %0d cycles, pc %08x",
                       name, status, want, max_cycles, dbg_pc);
            $display("vip_system: %0s PASS", name);
        end
    endtask

    // vip-display has no status word: it fills a frame buffer by hand and
    // the picture is the verdict. Nothing enables the drawing engine, so
    // the VIP never swaps buffers and either one can be the displayed one.
    task automatic run_vip_display(input integer hwords,
                                   input integer max_cycles);
        integer fd, i, x, y;
        reg [7:0] want;
        string  path;
        begin
            reset_n = 1'b0;
            path = "../.roms/vip-display.hex";
            fd = $fopen(path, "r");
            if (fd == 0)
                $fatal(1, "vip-display: cannot open %0s; run pnpm run build:roms first",
                       path);
            $fclose(fd);
            $readmemh(path, rom);
            rom_mask = hwords - 1;
            for (i = 0; i < 65536; i = i + 1)
                dram[i] = 16'h5a5a ^ i[15:0];
            disp_x = 9'd0;
            disp_y = 8'd0;
            repeat (4) @(posedge clk);
            reset_n = 1'b1;
            i = 0;
            while (!dbg_halted && i < max_cycles) begin
                @(posedge clk);
                i = i + 1;
            end
            if (!dbg_halted)
                $fatal(1, "vip-display: never halted in %0d cycles, pc %08x",
                       max_cycles, dbg_pc);
            // The ROM's own read-back of everything it programmed.
            if (status !== 16'h00ff)
                $fatal(1, "vip-display: read-back status %04x, expected 00ff",
                       status);

            for (i = 0; i < 12288; i = i + 512) begin
                if ({u_vip.memory.fb_l0_hi[i], u_vip.memory.fb_l0_lo[i]} !== 16'h5555)
                    $fatal(1, "vip-display: left buffer 0 word %0d is %04x, expected 5555",
                           i, {u_vip.memory.fb_l0_hi[i], u_vip.memory.fb_l0_lo[i]});
                if ({u_vip.memory.fb_l1_hi[i], u_vip.memory.fb_l1_lo[i]} !== 16'h5555)
                    $fatal(1, "vip-display: left buffer 1 word %0d is %04x, expected 5555",
                           i, {u_vip.memory.fb_l1_hi[i], u_vip.memory.fb_l1_lo[i]});
            end

            // Stripes four columns wide: the column table alternates the
            // repeat count, so shade 1 lands on exposure 64 against 128.
            for (y = 0; y < 224; y = y + 37) begin
                for (x = 0; x < 384; x = x + 1) begin
                    disp_x = x;
                    disp_y = y;
                    want_exposure = ((x >> 2) & 1) ? 8'd128 : 8'd64;
                    repeat (2) @(posedge clk);
                    #1;
                    want = want_luma;
                    if (disp_pixel !== 2'd1)
                        $fatal(1, "vip-display: pixel at (%0d,%0d) is %0d, expected 1",
                               x, y, disp_pixel);
                    if (disp_luma !== want)
                        $fatal(1, "vip-display: luma at (%0d,%0d) is %0d, expected %0d",
                               x, y, disp_luma, want);
                end
            end
            $display("vip_system: vip-display PASS");
        end
    endtask

    initial begin
        run_rom("vip-compose", 2048, 8000000);
        run_rom("vip-hbaff", 4096, 8000000);
        run_rom("vip-objx", 2048, 12000000);
        run_rom("vip-sched", 2048, 60000000);
        run_rom_status("vip-dpctrl", 1024, 16'h600d, 8000000);
        run_vip_display(512, 20000000);
        // Last on purpose. It needs none of the drawing machinery -- only a
        // device that answers late, which is the case the CPU's
        // two-halfword accesses got wrong -- and run_rom reloads the DRAM
        // array between images but not the VIP's own block RAM, so a ROM
        // inserted ahead of these changes what the timing-sensitive ones
        // start from. vip-sched spins in its check 8 if this runs first.
        run_rom("vip-word", 512, 2000000);
        $display("vip_system: PASS");
        $finish;
    end

endmodule
