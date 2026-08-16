`default_nettype none

// Native 50 Hz VIP display schedule and game-frame scheduler.

module vip_timing #(
    parameter integer FRAME_CYCLES = 798720,
    parameter integer LEFT_START   = 119808,
    parameter integer LEFT_END     = 319488,
    parameter integer FCLK_END     = 399360,
    parameter integer RIGHT_START  = 519168,
    parameter integer RIGHT_END    = 718848
) (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        display_reset,
    input  logic        draw_reset,
    input  logic        display_enable,
    input  logic        sync_enable,
    input  logic        draw_enable,
    input  logic [3:0]  frmcyc,
    input  logic [4:0]  sbcmp,
    input  logic        draw_busy,
    input  logic        draw_done,
    input  logic        strip_begin,
    input  logic [4:0]  strip_number,
    output logic        fclk,
    output logic        scan_ready,
    output logic [3:0]  display_busy,
    output logic [15:0] events,
    output logic        draw_start,
    output logic        draw_buffer,
    output logic        display_buffer
);

    localparam integer COUNTER_BITS = $clog2(FRAME_CYCLES);
    logic [COUNTER_BITS-1:0] frame_cycle;
    logic [3:0] game_wait;
    logic next_draw_buffer;
    logic waiting_for_fclk;

    always_comb begin
        fclk = frame_cycle < FCLK_END;
        scan_ready = sync_enable && !waiting_for_fclk;
        display_busy = 4'd0;
        if (display_enable && sync_enable && !waiting_for_fclk) begin
            if (frame_cycle >= LEFT_START && frame_cycle < LEFT_END)
                display_busy[display_buffer ? 2 : 0] = 1'b1;
            if (frame_cycle >= RIGHT_START && frame_cycle < RIGHT_END)
                display_busy[display_buffer ? 3 : 1] = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            frame_cycle <= '0;
            game_wait <= 4'd0;
            events <= 16'd0;
            draw_start <= 1'b0;
            draw_buffer <= 1'b0;
            next_draw_buffer <= 1'b0;
            display_buffer <= 1'b1;
            waiting_for_fclk <= 1'b0;
        end else begin
            events <= 16'd0;
            draw_start <= 1'b0;

            if (frame_cycle == FRAME_CYCLES - 1) begin
                frame_cycle <= '0;
            end else begin
                frame_cycle <= frame_cycle + 1'b1;
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
                            if (draw_busy) begin
                                events[15] <= 1'b1;
                            end else begin
                                draw_start <= 1'b1;
                                draw_buffer <= next_draw_buffer;
                            end
                        end
                    end else begin
                        game_wait <= game_wait - 1'b1;
                    end
                end

                if (display_enable && sync_enable && !waiting_for_fclk &&
                    frame_cycle == LEFT_END)
                    events[1] <= 1'b1;
                if (display_enable && sync_enable && !waiting_for_fclk &&
                    frame_cycle == RIGHT_END)
                    events[2] <= 1'b1;

                if (strip_begin && strip_number == sbcmp)
                    events[13] <= 1'b1;

                if (draw_done) begin
                    events[14] <= 1'b1;
                    display_buffer <= draw_buffer;
                    next_draw_buffer <= !draw_buffer;
                end
            end

            if (draw_reset) begin
                draw_start <= 1'b0;
            end
        end
    end

endmodule

`default_nettype wire
