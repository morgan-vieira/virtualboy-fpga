`default_nettype none

// Virtual Boy video image processor.
//
// The frame-schedule parameters exist for the benches, which shrink the
// 20 ms frame so full-system runs stay affordable; hardware always uses
// the defaults.

module vip #(
    parameter integer FRAME_CYCLES = 798720,
    parameter integer LEFT_START   = 119808,
    parameter integer LEFT_END     = 319488,
    parameter integer FCLK_END     = 399360,
    parameter integer RIGHT_START  = 519168,
    parameter integer RIGHT_END    = 718848
) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        ce,
    input  logic        cpu_sel,
    input  logic [26:1] cpu_addr,
    input  logic        cpu_we,
    input  logic [1:0]  cpu_be,
    input  logic [15:0] cpu_wdata,
    output logic [15:0] cpu_rdata,
    output logic        cpu_ready,
    output logic        irq,

    output logic        dram_req,
    output logic [15:0] dram_addr,
    output logic        dram_we,
    output logic [1:0]  dram_be,
    output logic [15:0] dram_wdata,
    input  logic [15:0] dram_rdata,
    input  logic        dram_ready,

    input  logic        display_clk,
    input  logic [8:0]  display_x,
    input  logic [7:0]  display_y,
    // Both eyes, every cycle. Which one reaches the screen -- or how the
    // two are mixed -- is vip_stereo's decision, not the VIP's.
    output logic [1:0]  display_pixel_left,
    output logic [1:0]  display_pixel_right,
    output logic [7:0]  display_luma_left,
    output logic [7:0]  display_luma_right
);

    logic register_sel;
    logic register_sel_q;
    logic [15:0] register_rdata;
    logic [15:0] register_rdata_q;
    logic [15:0] memory_rdata;
    logic memory_ready;
    logic display_reset, draw_reset;
    logic display_enable, sync_enable, refresh_enable, column_lock;
    logic draw_enable;
    logic [4:0] sbcmp;
    logic [3:0] frmcyc;
    logic [39:0] spt, active_spt;
    logic [31:0] gplt, jplt, active_gplt, active_jplt;
    logic [1:0] bkcol, active_bkcol;
    logic [7:0] brta_level, brtb_level, brtc_level, rest_level;
    logic [7:0] display_column_index;
    logic [15:0] display_column_left, display_column_right;
    logic fclk, scan_ready;
    logic [3:0] display_busy;
    logic [15:0] events;
    logic draw_start, draw_buffer, display_buffer;
    logic draw_busy, draw_done, strip_begin, first_group_done;
    logic [4:0] strip_number;
    logic draw_overtime, draw_sbout;
    logic [7:0] cta_l, cta_r;
    logic draw_req, draw_we, draw_ready;
    logic [18:1] draw_addr;
    logic [1:0] draw_be;
    logic [15:0] draw_wdata, draw_rdata;

    assign register_sel = cpu_sel && cpu_addr[18:1] >= 18'h2F000 &&
                          cpu_addr[18:1] < 18'h30000;
    assign cpu_ready = register_sel ? 1'b1 : memory_ready;
    // The register file answers combinationally off the live address, but
    // the CPU captures the cycle after ready, by which time the bus already
    // carries the next fetch; the answer is latched at the access.
    assign cpu_rdata = register_sel_q ? register_rdata_q : memory_rdata;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            register_sel_q <= 1'b0;
            register_rdata_q <= 16'd0;
        end else if (cpu_sel) begin
            register_sel_q <= register_sel;
            if (register_sel) register_rdata_q <= register_rdata;
        end
    end

    vip_registers registers (
        .clk(clk), .reset_n(reset_n), .sel(register_sel),
        .addr(cpu_addr[12:1]), .we(cpu_we), .be(cpu_be),
        .wdata(cpu_wdata), .rdata(register_rdata), .irq(irq),
        .fclk(fclk), .scan_ready(scan_ready), .display_busy(display_busy),
        .draw_busy(draw_busy), .draw_buffer(draw_buffer),
        .draw_sbout(draw_sbout), .draw_sbcount(strip_number),
        .draw_overtime(draw_overtime), .events(events),
        .draw_start(draw_start), .first_group_done(first_group_done),
        .cta_l(cta_l), .cta_r(cta_r),
        .display_enable(display_enable), .sync_enable(sync_enable),
        .refresh_enable(refresh_enable), .column_lock(column_lock),
        .draw_enable(draw_enable), .sbcmp(sbcmp), .frmcyc(frmcyc),
        .spt(spt), .gplt(gplt), .jplt(jplt), .bkcol(bkcol),
        .active_spt(active_spt), .active_gplt(active_gplt),
        .active_jplt(active_jplt), .active_bkcol(active_bkcol),
        .brta_level(brta_level), .brtb_level(brtb_level),
        .brtc_level(brtc_level), .rest_level(rest_level),
        .display_reset(display_reset), .draw_reset(draw_reset)
    );

    vip_timing #(
        .FRAME_CYCLES(FRAME_CYCLES), .LEFT_START(LEFT_START),
        .LEFT_END(LEFT_END), .FCLK_END(FCLK_END),
        .RIGHT_START(RIGHT_START), .RIGHT_END(RIGHT_END)
    ) timing (
        .clk(clk), .reset_n(reset_n), .display_reset(display_reset),
        .draw_reset(draw_reset), .display_enable(display_enable),
        .sync_enable(sync_enable), .draw_enable(draw_enable),
        .column_lock(column_lock),
        .frmcyc(frmcyc), .sbcmp(sbcmp), .draw_busy(draw_busy),
        .draw_done(draw_done), .strip_begin(strip_begin),
        .strip_number(strip_number), .sbout(draw_sbout),
        .fclk(fclk), .scan_ready(scan_ready),
        .display_busy(display_busy), .events(events), .draw_start(draw_start),
        .draw_overtime(draw_overtime),
        .draw_buffer(draw_buffer), .display_buffer(display_buffer),
        .cta_l(cta_l), .cta_r(cta_r)
    );

    vip_draw drawing (
        .clk(clk), .reset_n(reset_n), .ce(ce), .start(draw_start),
        .reset_draw(draw_reset), .target_buffer(draw_buffer),
        .spt(active_spt), .gplt(active_gplt), .jplt(active_jplt),
        .bkcol(active_bkcol), .busy(draw_busy), .done(draw_done),
        .strip_begin(strip_begin), .strip_number(strip_number),
        .first_group_done(first_group_done), .sbout(draw_sbout),
        .mem_req(draw_req),
        .mem_addr(draw_addr), .mem_we(draw_we), .mem_be(draw_be),
        .mem_wdata(draw_wdata), .mem_rdata(draw_rdata),
        .mem_ready(draw_ready)
    );

    vip_memory memory (
        .clk(clk), .reset_n(reset_n), .ce(ce),
        .cpu_sel(cpu_sel && !register_sel), .cpu_addr(cpu_addr),
        .cpu_we(cpu_we), .cpu_be(cpu_be), .cpu_wdata(cpu_wdata),
        .cpu_rdata(memory_rdata), .ready(memory_ready),
        .draw_req(draw_req), .draw_addr(draw_addr), .draw_we(draw_we),
        .draw_be(draw_be), .draw_wdata(draw_wdata), .draw_rdata(draw_rdata),
        .draw_ready(draw_ready), .dram_req(dram_req), .dram_addr(dram_addr),
        .dram_we(dram_we), .dram_be(dram_be), .dram_wdata(dram_wdata),
        .dram_rdata(dram_rdata), .dram_ready(dram_ready),
        .display_clk(display_clk),
        .display_buffer(display_buffer),
        .column_lock(column_lock),
        .cta_locked_left(cta_l), .cta_locked_right(cta_r),
        .display_x(display_x),
        .display_y(display_y),
        .display_pixel_left(display_pixel_left),
        .display_pixel_right(display_pixel_right),
        .display_column_index(display_column_index),
        .display_column_left(display_column_left),
        .display_column_right(display_column_right)
    );

    // Brightness is per eye, because the column table is: the same shade is
    // a different exposure in each eye's window. Both instances derive the
    // column index from the same x, so vip_memory only needs the one.
    vip_display display_left (
        .x(display_x), .pixel(display_pixel_left), .brta(brta_level),
        .brtb(brtb_level), .brtc(brtc_level), .rest(rest_level),
        .column(display_column_left), .column_index(display_column_index),
        .luma(display_luma_left)
    );

    vip_display display_right (
        .x(display_x), .pixel(display_pixel_right), .brta(brta_level),
        .brtb(brtb_level), .brtc(brtc_level), .rest(rest_level),
        .column(display_column_right), .column_index(),
        .luma(display_luma_right)
    );

endmodule

`default_nettype wire
