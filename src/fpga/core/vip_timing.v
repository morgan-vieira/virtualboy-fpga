`default_nettype none

// Native 50 Hz VIP display schedule, game-frame scheduler, framebuffer
// ownership, and the column-table pointers.
//
// Ownership follows both references (beetle-vb vip.c and MiSTer's
// vip_xp_framebuffer_owner, which agree): a completed draw waits as
// "pending", the display switches to it at the next game-frame start with
// XPEN set, and the new draw targets the other buffer. Reset displays
// buffer 0, so the first draw lands in buffer 1. XPRST aborts a draw
// without touching ownership (MiSTer; beetle-vb swaps instead, and the
// scroll is silent, so MiSTer decides).

module vip_timing #(
    parameter integer FRAME_CYCLES = 798720,
    parameter integer LEFT_START   = 119808,
    parameter integer LEFT_END     = 319488,
    parameter integer FCLK_END     = 399360,
    parameter integer RIGHT_START  = 519168,
    parameter integer RIGHT_END    = 718848,
    // One column-table entry serves four columns: 96 groups per 5 ms eye
    // window is exactly 2,080 clocks at 39.936 MHz [scroll, Column Table].
    parameter integer CTA_GROUP_CLOCKS = 2080
) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        display_reset,
    input  logic        draw_reset,
    input  logic        display_enable,
    input  logic        sync_enable,
    input  logic        draw_enable,
    input  logic        column_lock,
    input  logic [3:0]  frmcyc,
    input  logic [4:0]  sbcmp,
    input  logic        draw_busy,
    input  logic        draw_done,
    input  logic        strip_begin,
    input  logic [4:0]  strip_number,
    input  logic        sbout,
    output logic        fclk,
    output logic        scan_ready,
    output logic [3:0]  display_busy,
    output logic [15:0] events,
    output logic        draw_start,
    output logic        draw_overtime,
    output logic        draw_buffer,
    output logic        display_buffer,
    output logic [7:0]  cta_l,
    output logic [7:0]  cta_r
);

    localparam integer COUNTER_BITS = $clog2(FRAME_CYCLES);
    logic [COUNTER_BITS-1:0] frame_cycle;
    logic [3:0] game_wait;
    logic waiting_for_fclk;
    logic completed_valid;
    logic completed_target;
    logic [11:0] cta_group_clk;

    logic display_active;
    logic left_window, right_window;
    logic game_frame_fire;
    logic display_after;

    always_comb begin
        fclk = frame_cycle < FCLK_END;
        // MiSTer has no mirror servo and reports the scanner always ready.
        scan_ready = 1'b1;
        display_active = display_enable && sync_enable && !waiting_for_fclk;
        left_window = frame_cycle >= LEFT_START && frame_cycle < LEFT_END;
        right_window = frame_cycle >= RIGHT_START && frame_cycle < RIGHT_END;
        display_busy = 4'd0;
        if (display_active) begin
            if (left_window)
                display_busy[display_buffer ? 2 : 0] = 1'b1;
            if (right_window)
                display_busy[display_buffer ? 3 : 1] = 1'b1;
        end
        game_frame_fire = frame_cycle == 0 &&
                          (waiting_for_fclk || game_wait == 0);
        // A pending completed buffer is consumed at the same boundary that
        // starts the next draw.
        display_after = (game_frame_fire && draw_enable && completed_valid) ?
                        completed_target : display_buffer;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frame_cycle <= '0;
            game_wait <= 4'd0;
            events <= 16'd0;
            draw_start <= 1'b0;
            draw_overtime <= 1'b0;
            draw_buffer <= 1'b1;
            display_buffer <= 1'b0;
            completed_valid <= 1'b0;
            completed_target <= 1'b1;
            waiting_for_fclk <= 1'b0;
            cta_l <= 8'hFA;
            cta_r <= 8'hFA;
            cta_group_clk <= 12'd0;
        end else begin
            events <= 16'd0;
            draw_start <= 1'b0;

            if (frame_cycle == FRAME_CYCLES - 1) begin
                frame_cycle <= '0;
            end else begin
                frame_cycle <= frame_cycle + 1'b1;
            end

            // The internal column pointer reloads from the measured 0xFA
            // field-start value at each eye start and decrements per four
            // columns unless LOCK holds it [scroll, CTA; MiSTer's servo
            // constant].
            if (display_active && frame_cycle == LEFT_START) begin
                cta_l <= 8'hFA;
                cta_group_clk <= 12'd0;
            end else if (display_active && frame_cycle == RIGHT_START) begin
                cta_r <= 8'hFA;
                cta_group_clk <= 12'd0;
            end else if (display_active && (left_window || right_window)) begin
                if (cta_group_clk == CTA_GROUP_CLOCKS - 1) begin
                    cta_group_clk <= 12'd0;
                    if (!column_lock) begin
                        if (left_window) cta_l <= cta_l - 8'd1;
                        else cta_r <= cta_r - 8'd1;
                    end
                end else cta_group_clk <= cta_group_clk + 12'd1;
            end

            if (display_reset) begin
                waiting_for_fclk <= 1'b1;
                game_wait <= 4'd0;
            end else begin
                if (frame_cycle == 0) begin
                    waiting_for_fclk <= 1'b0;
                    events[4] <= 1'b1;
                    if (waiting_for_fclk || game_wait == 0) begin
                        game_wait <= frmcyc;
                        events[3] <= 1'b1;
                        if (draw_enable) begin
                            if (completed_valid) begin
                                display_buffer <= completed_target;
                                completed_valid <= 1'b0;
                            end
                            if (draw_busy) begin
                                if (!draw_overtime) events[15] <= 1'b1;
                                draw_overtime <= 1'b1;
                            end else begin
                                draw_start <= 1'b1;
                                draw_buffer <= !display_after;
                                draw_overtime <= 1'b0;
                            end
                        end
                    end else begin
                        game_wait <= game_wait - 1'b1;
                    end
                end

                if (display_active && frame_cycle == LEFT_END)
                    events[1] <= 1'b1;
                if (display_active && frame_cycle == RIGHT_END)
                    events[2] <= 1'b1;

                if (strip_begin && strip_number == sbcmp && !sbout)
                    events[13] <= 1'b1;

                if (draw_done) begin
                    events[14] <= 1'b1;
                    completed_valid <= 1'b1;
                    completed_target <= draw_buffer;
                    draw_overtime <= 1'b0;
                end
            end

            if (draw_reset) begin
                draw_start <= 1'b0;
                draw_overtime <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
