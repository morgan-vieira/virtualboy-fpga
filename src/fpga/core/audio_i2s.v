`default_nettype none

// Transfers one stereo snapshot per frame, then emits Pocket's 64-bit I2S shape.
module audio_i2s (
    input  logic               source_clk,
    input  logic signed [15:0] source_left,
    input  logic signed [15:0] source_right,

    input  logic               mclk,
    input  logic               reset_n,
    output logic               dac,
    output logic               lrck
);

    logic request;
    logic request_s1;
    logic request_s2;
    logic acknowledge;
    logic signed [15:0] source_left_hold;
    logic signed [15:0] source_right_hold;

    always_ff @(posedge source_clk or negedge reset_n) begin
        if (!reset_n) begin
            request_s1 <= 1'b0;
            request_s2 <= 1'b0;
            acknowledge <= 1'b0;
            source_left_hold <= 16'sd0;
            source_right_hold <= 16'sd0;
        end else begin
            request_s1 <= request;
            request_s2 <= request_s1;
            if (request_s2 != acknowledge) begin
                source_left_hold <= source_left;
                source_right_hold <= source_right;
                acknowledge <= request_s2;
            end
        end
    end

    logic acknowledge_s1;
    logic acknowledge_s2;
    logic acknowledge_seen;
    logic signed [15:0] next_left;
    logic signed [15:0] next_right;
    logic signed [15:0] left_frame;
    logic signed [15:0] right_frame;
    logic [1:0] mclk_divider;
    logic [5:0] bit_count;

    always_ff @(posedge mclk or negedge reset_n) begin
        if (!reset_n) begin
            acknowledge_s1 <= 1'b0;
            acknowledge_s2 <= 1'b0;
            acknowledge_seen <= 1'b0;
            request <= 1'b0;
            next_left <= 16'sd0;
            next_right <= 16'sd0;
            left_frame <= 16'sd0;
            right_frame <= 16'sd0;
            mclk_divider <= 2'd0;
            bit_count <= 6'd0;
            dac <= 1'b0;
            lrck <= 1'b0;
        end else begin
            acknowledge_s1 <= acknowledge;
            acknowledge_s2 <= acknowledge_s1;
            mclk_divider <= mclk_divider + 2'd1;

            if (acknowledge_s2 != acknowledge_seen) begin
                next_left <= source_left_hold;
                next_right <= source_right_hold;
                acknowledge_seen <= acknowledge_s2;
            end

            if (mclk_divider == 2'd3) begin
                bit_count <= bit_count + 6'd1;
                dac <= 1'b0;

                if (bit_count == 6'd0) begin
                    lrck <= 1'b0;
                    left_frame <= next_left;
                    right_frame <= next_right;
                    if (acknowledge_s2 == request)
                        request <= ~request;
                end else if (bit_count <= 6'd16) begin
                    dac <= left_frame[16 - bit_count];
                end else if (bit_count == 6'd32) begin
                    lrck <= 1'b1;
                end else if (bit_count >= 6'd33 && bit_count <= 6'd48) begin
                    dac <= right_frame[48 - bit_count];
                end
            end
        end
    end

endmodule

`default_nettype wire
