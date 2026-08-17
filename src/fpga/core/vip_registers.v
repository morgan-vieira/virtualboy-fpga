`default_nettype none

// VIP control registers and interrupt latch.
// Draw-time values are snapshotted because software writes are unsafe while XPBSY.
//
// Every write is a halfword write: a byte write to an even address uses the
// full 16 bits on the bus, and a byte write to an odd address uses the high
// lane shifted into place over a zero low byte [scroll, VIP I/O Registers].

module vip_registers (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        sel,
    input  logic [12:1] addr,
    input  logic        we,
    input  logic [1:0]  be,
    input  logic [15:0] wdata,
    output logic [15:0] rdata,
    output logic        irq,

    input  logic        fclk,
    input  logic        scan_ready,
    input  logic [3:0]  display_busy,
    input  logic        draw_busy,
    input  logic        draw_buffer,
    input  logic        draw_sbout,
    input  logic [4:0]  draw_sbcount,
    input  logic        draw_overtime,
    input  logic [15:0] events,
    input  logic        draw_start,
    input  logic        first_group_done,
    input  logic [7:0]  cta_l,
    input  logic [7:0]  cta_r,

    output logic        display_enable,
    output logic        sync_enable,
    output logic        refresh_enable,
    output logic        column_lock,
    output logic        draw_enable,
    output logic [4:0]  sbcmp,
    output logic [3:0]  frmcyc,
    output logic [39:0] spt,
    output logic [31:0] gplt,
    output logic [31:0] jplt,
    output logic [1:0]  bkcol,
    output logic [39:0] active_spt,
    output logic [31:0] active_gplt,
    output logic [31:0] active_jplt,
    output logic [1:0]  active_bkcol,
    output logic [7:0]  brta_level,
    output logic [7:0]  brtb_level,
    output logic [7:0]  brtc_level,
    output logic [7:0]  rest_level,
    output logic        display_reset,
    output logic        draw_reset
);

    localparam logic [15:0] INT_MASK   = 16'hE01F;
    localparam logic [15:0] DP_MASK    = 16'h801F;
    localparam logic [15:0] XP_MASK    = 16'hE000;

    logic [15:0] pending;
    logic [15:0] enable;
    logic [7:0] brta, brtb, brtc, rest;
    logic bkcol_pending;
    logic display_program, sync_program, fclk_q;

    logic [15:0] write_value;

    // The CPU routes an odd-address byte onto the high lane, so the mangled
    // halfword is {DIN[15:8], 0}; even-address bytes carry the source
    // register's full low 16 bits [scroll; MiSTer vip_host_beat_frontend].
    assign write_value = be == 2'b10 ? {wdata[15:8], 8'h00} : wdata;
    assign irq = |(pending & enable);
    assign brta_level = brta;
    assign brtb_level = brtb;
    assign brtc_level = brtc;
    assign rest_level = rest;

    always_comb begin
        rdata = 16'h0000;
        unique case (addr)
            12'hC00: rdata = pending;
            12'hC01: rdata = enable;
            12'hC10: rdata = {5'd0, column_lock, sync_enable,
                              refresh_enable, fclk, scan_ready,
                              display_busy, display_enable, 1'b0};
            12'hC12: rdata = {8'd0, brta};
            12'hC13: rdata = {8'd0, brtb};
            12'hC14: rdata = {8'd0, brtc};
            12'hC15: rdata = {8'd0, rest};
            12'hC17: rdata = {12'd0, frmcyc};
            12'hC18: rdata = {cta_r, cta_l};
            12'hC20: rdata = {draw_sbout, 2'd0, draw_sbcount, 3'd0,
                              draw_overtime, draw_busy && draw_buffer,
                              draw_busy && !draw_buffer,
                              draw_enable, 1'b0};
            12'hC22: rdata = 16'd2;
            12'hC24: rdata = {6'd0, spt[9:0]};
            12'hC25: rdata = {6'd0, spt[19:10]};
            12'hC26: rdata = {6'd0, spt[29:20]};
            12'hC27: rdata = {6'd0, spt[39:30]};
            12'hC30: rdata = {8'd0, gplt[7:0]};
            12'hC31: rdata = {8'd0, gplt[15:8]};
            12'hC32: rdata = {8'd0, gplt[23:16]};
            12'hC33: rdata = {8'd0, gplt[31:24]};
            12'hC34: rdata = {8'd0, jplt[7:0]};
            12'hC35: rdata = {8'd0, jplt[15:8]};
            12'hC36: rdata = {8'd0, jplt[23:16]};
            12'hC37: rdata = {8'd0, jplt[31:24]};
            12'hC38: rdata = {14'd0, bkcol};
            default: rdata = 16'h0000;
        endcase
    end

    always_comb begin
        display_reset = sel && we && addr == 12'hC11 && write_value[0];
        draw_reset = sel && we && addr == 12'hC21 && write_value[0];
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            pending <= 16'd0;
            enable <= 16'd0;
            display_enable <= 1'b0;
            sync_enable <= 1'b0;
            display_program <= 1'b0;
            sync_program <= 1'b0;
            fclk_q <= 1'b0;
            refresh_enable <= 1'b0;
            column_lock <= 1'b0;
            draw_enable <= 1'b0;
            sbcmp <= 5'd0;
            frmcyc <= 4'd0;
            brta <= 8'd0;
            brtb <= 8'd0;
            brtc <= 8'd0;
            rest <= 8'd0;
            spt <= 40'd0;
            gplt <= 32'd0;
            jplt <= 32'd0;
            bkcol <= 2'd0;
            active_spt <= 40'd0;
            active_gplt <= 32'd0;
            active_jplt <= 32'd0;
            active_bkcol <= 2'd0;
            bkcol_pending <= 1'b0;
        end else begin
            fclk_q <= fclk;
            // Hardware events win a same-cycle software clear.
            pending <= (((pending & ~(sel && we && addr == 12'hC02 ?
                         (write_value & INT_MASK) : 16'd0)) |
                        (events & INT_MASK)) & INT_MASK);

            if (sel && we) begin
                unique case (addr)
                    12'hC01: enable <= write_value & INT_MASK;
                    12'hC11: begin
                        column_lock <= write_value[10];
                        sync_program <= write_value[9];
                        refresh_enable <= write_value[8];
                        display_program <= write_value[1];
                    end
                    12'hC12: brta <= write_value[7:0];
                    12'hC13: brtb <= write_value[7:0];
                    12'hC14: brtc <= write_value[7:0];
                    12'hC15: rest <= write_value[7:0];
                    12'hC17: frmcyc <= write_value[3:0];
                    12'hC21: begin
                        sbcmp <= write_value[12:8];
                        draw_enable <= write_value[1];
                    end
                    12'hC24: spt[9:0] <= write_value[9:0];
                    12'hC25: spt[19:10] <= write_value[9:0];
                    12'hC26: spt[29:20] <= write_value[9:0];
                    12'hC27: spt[39:30] <= write_value[9:0];
                    12'hC30: gplt[7:0] <= write_value[7:0] & 8'hFC;
                    12'hC31: gplt[15:8] <= write_value[7:0] & 8'hFC;
                    12'hC32: gplt[23:16] <= write_value[7:0] & 8'hFC;
                    12'hC33: gplt[31:24] <= write_value[7:0] & 8'hFC;
                    12'hC34: jplt[7:0] <= write_value[7:0] & 8'hFC;
                    12'hC35: jplt[15:8] <= write_value[7:0] & 8'hFC;
                    12'hC36: jplt[23:16] <= write_value[7:0] & 8'hFC;
                    12'hC37: jplt[31:24] <= write_value[7:0] & 8'hFC;
                    12'hC38: begin
                        bkcol <= write_value[1:0];
                        bkcol_pending <= 1'b1;
                    end
                    default: begin end
                endcase
            end

            if (display_reset) begin
                pending <= (pending & ~DP_MASK) | (events & INT_MASK);
                enable <= enable & ~DP_MASK;
            end
            if (draw_reset) begin
                pending <= (pending & ~XP_MASK) | (events & INT_MASK);
                enable <= enable & ~XP_MASK;
                draw_enable <= 1'b0;
            end

            if (fclk && !fclk_q) begin
                sync_enable <= sync_program;
                display_enable <= display_program;
            end

            if (draw_start) begin
                active_spt <= spt;
                active_gplt <= gplt;
                active_jplt <= jplt;
                if (bkcol_pending)
                    bkcol_pending <= 1'b1;
                else
                    active_bkcol <= bkcol;
            end
            if (first_group_done && bkcol_pending) begin
                active_bkcol <= bkcol;
                bkcol_pending <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
