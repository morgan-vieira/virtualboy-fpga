`default_nettype none

// Virtual Boy video image processor.

module vip (
    input  logic        clk,
    input  logic        reset_n,
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
    input  logic        display_eye,
    input  logic [8:0]  display_x,
    input  logic [7:0]  display_y,
    output logic [1:0]  display_pixel,
    output logic [7:0]  display_luma
);

    logic register_sel;
    logic register_sel_q;
    logic [15:0] register_rdata;
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
    logic [15:0] display_column;
    logic fclk, scan_ready;
    logic [3:0] display_busy;
    logic [15:0] events;
    logic draw_start, draw_buffer, display_buffer;
    logic draw_busy, draw_done, strip_begin, first_group_done;
    logic [4:0] strip_number;
    logic draw_overtime;
    logic draw_req, draw_we, draw_ready;
    logic [18:1] draw_addr;
    logic [1:0] draw_be;
    logic [15:0] draw_wdata, draw_rdata;

    assign register_sel = cpu_sel && cpu_addr[18:1] >= 18'h2F000 &&
                          cpu_addr[18:1] < 18'h30000;
    assign cpu_ready = register_sel ? 1'b1 : memory_ready;
    assign cpu_rdata = register_sel_q ? register_rdata : memory_rdata;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) register_sel_q <= 1'b0;
        else if (cpu_sel) register_sel_q <= register_sel;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) draw_overtime <= 1'b0;
        else begin
            if (events[15]) draw_overtime <= 1'b1;
            if (draw_start || draw_reset) draw_overtime <= 1'b0;
        end
    end

    vip_registers registers (
        .clk(clk), .reset_n(reset_n), .sel(register_sel),
        .addr(cpu_addr[12:1]), .we(cpu_we), .be(cpu_be),
        .wdata(cpu_wdata), .rdata(register_rdata), .irq(irq),
        .fclk(fclk), .scan_ready(scan_ready), .display_busy(display_busy),
        .draw_busy(draw_busy), .draw_buffer(draw_buffer),
        .draw_sbout(strip_begin), .draw_sbcount(strip_number),
        .draw_overtime(draw_overtime), .events(events),
        .draw_start(draw_start), .first_group_done(first_group_done),
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

    vip_timing timing (
        .clk(clk), .reset_n(reset_n), .display_reset(display_reset),
        .draw_reset(draw_reset), .display_enable(display_enable),
        .sync_enable(sync_enable), .draw_enable(draw_enable),
        .frmcyc(frmcyc), .sbcmp(sbcmp), .draw_busy(draw_busy),
        .draw_done(draw_done), .strip_begin(strip_begin),
        .strip_number(strip_number), .fclk(fclk), .scan_ready(scan_ready),
        .display_busy(display_busy), .events(events), .draw_start(draw_start),
        .draw_buffer(draw_buffer), .display_buffer(display_buffer)
    );

    vip_draw drawing (
        .clk(clk), .reset_n(reset_n), .start(draw_start),
        .reset_draw(draw_reset), .target_buffer(draw_buffer),
        .spt(active_spt), .gplt(active_gplt), .jplt(active_jplt),
        .bkcol(active_bkcol), .busy(draw_busy), .done(draw_done),
        .strip_begin(strip_begin), .strip_number(strip_number),
        .first_group_done(first_group_done), .mem_req(draw_req),
        .mem_addr(draw_addr), .mem_we(draw_we), .mem_be(draw_be),
        .mem_wdata(draw_wdata), .mem_rdata(draw_rdata),
        .mem_ready(draw_ready)
    );

    vip_memory memory (
        .clk(clk), .reset_n(reset_n),
        .cpu_sel(cpu_sel && !register_sel), .cpu_addr(cpu_addr),
        .cpu_we(cpu_we), .cpu_be(cpu_be), .cpu_wdata(cpu_wdata),
        .cpu_rdata(memory_rdata), .ready(memory_ready),
        .draw_req(draw_req), .draw_addr(draw_addr), .draw_we(draw_we),
        .draw_be(draw_be), .draw_wdata(draw_wdata), .draw_rdata(draw_rdata),
        .draw_ready(draw_ready), .dram_req(dram_req), .dram_addr(dram_addr),
        .dram_we(dram_we), .dram_be(dram_be), .dram_wdata(dram_wdata),
        .dram_rdata(dram_rdata), .dram_ready(dram_ready),
        .display_clk(display_clk), .display_eye(display_eye),
        .display_buffer(display_buffer), .display_x(display_x),
        .display_y(display_y), .display_pixel(display_pixel),
        .display_column_index(display_column_index),
        .display_column(display_column)
    );

    vip_display display (
        .x(display_x), .pixel(display_pixel), .brta(brta_level),
        .brtb(brtb_level), .brtc(brtc_level), .rest(rest_level),
        .column(display_column), .column_index(display_column_index),
        .luma(display_luma)
    );

endmodule

`default_nettype wire
