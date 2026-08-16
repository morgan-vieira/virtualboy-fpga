`default_nettype none

// First wavetable channel. Timing follows beetle-vb's vsu.c.
module vsu (
    input logic clk, input logic reset_n, input logic ce,
    input logic sel, input logic [26:1] addr, input logic we,
    input logic [1:0] be, input logic [15:0] wdata,
    output logic signed [15:0] sample_left,
    output logic signed [15:0] sample_right
);
    logic [5:0] wave_ram [0:159];
    logic [7:0] interval_control;
    logic [3:0] left_level, right_level;
    logic [10:0] frequency;
    logic [15:0] envelope_control;
    logic [3:0] wave_bank;
    logic [11:0] frequency_counter;
    logic [4:0] wave_position;
    logic [5:0] interval_counter;
    logic [14:0] interval_divider;
    logic [10:0] offset;
    logic aligned_write;
    logic [7:0] write_byte;
    logic [3:0] register_index;
    logic [7:0] wave_index;
    logic channel_one_write;
    logic global_stop_write;

    assign offset = {addr[10:1], 1'b0};
    assign aligned_write = sel && we && be[0] && offset[1:0] == 2'b00;
    assign write_byte = wdata[7:0];
    assign register_index = offset[5:2];
    assign wave_index = offset[9:2];
    assign channel_one_write = aligned_write && offset[10:6] == 5'b10000;
    assign global_stop_write = aligned_write && offset == 11'h580 && write_byte[0];

    integer wave_reset_index;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (wave_reset_index = 0; wave_reset_index < 160;
                 wave_reset_index = wave_reset_index + 1)
                wave_ram[wave_reset_index] <= 6'd0;
            interval_control <= 8'd0;
            left_level <= 4'd0;
            right_level <= 4'd0;
            frequency <= 11'd0;
            envelope_control <= 16'd0;
            wave_bank <= 4'd0;
            frequency_counter <= 12'd0;
            wave_position <= 5'd0;
            interval_counter <= 6'd0;
            interval_divider <= 15'd0;
        end else begin
            if (aligned_write && offset < 11'h280)
                wave_ram[wave_index] <= write_byte[5:0];

            if (global_stop_write)
                interval_control[7] <= 1'b0;

            if (channel_one_write) begin
                unique case (register_index)
                    4'h0: begin
                        interval_control <= write_byte & 8'hbf;
                        if (write_byte[7]) begin
                            frequency_counter <= 12'd2048 - frequency;
                            wave_position <= 5'd0;
                            interval_counter <= {1'b0, write_byte[4:0]} + 6'd1;
                            interval_divider <= 15'd19200;
                        end
                    end
                    4'h1: begin
                        left_level <= write_byte[7:4];
                        right_level <= write_byte[3:0];
                    end
                    4'h2: frequency[7:0] <= write_byte;
                    4'h3: frequency[10:8] <= write_byte[2:0];
                    4'h4: begin
                        envelope_control[7:0] <= write_byte;
                        envelope_control[15:12] <= write_byte[7:4];
                    end
                    4'h5: envelope_control[9:8] <= write_byte[1:0];
                    4'h6: wave_bank <= write_byte[3:0];
                    default: begin end
                endcase
            end else if (ce && interval_control[7]) begin
                if (frequency_counter <= 12'd1) begin
                    frequency_counter <= 12'd2048 - frequency;
                    wave_position <= wave_position + 5'd1;
                end else begin
                    frequency_counter <= frequency_counter - 12'd1;
                end
                if (interval_divider <= 15'd1) begin
                    interval_divider <= 15'd19200;
                    if (interval_control[5]) begin
                        if (interval_counter <= 6'd1) begin
                            interval_counter <= 6'd0;
                            interval_control[7] <= 1'b0;
                        end else begin
                            interval_counter <= interval_counter - 6'd1;
                        end
                    end
                end else begin
                    interval_divider <= interval_divider - 15'd1;
                end
            end
        end
    end

    logic [5:0] wave_sample;
    logic [7:0] left_gain, right_gain;
    logic [7:0] left_gain_product, right_gain_product;
    logic signed [6:0] centered_sample;
    logic signed [15:0] left_product, right_product;
    always_comb begin
        wave_sample = wave_bank < 5 ? wave_ram[{wave_bank[2:0], wave_position}] : 6'd0;
        left_gain_product = envelope_control[15:12] * left_level;
        right_gain_product = envelope_control[15:12] * right_level;
        left_gain = left_gain_product == 0 ? 8'd0 : (left_gain_product >> 3) + 8'd1;
        right_gain = right_gain_product == 0 ? 8'd0 : (right_gain_product >> 3) + 8'd1;
        centered_sample = $signed({1'b0, wave_sample}) - 7'sd32;
        left_product = centered_sample * $signed({1'b0, left_gain});
        right_product = centered_sample * $signed({1'b0, right_gain});
        sample_left = interval_control[7] ? left_product <<< 2 : 16'sd0;
        sample_right = interval_control[7] ? right_product <<< 2 : 16'sd0;
    end
endmodule

`default_nettype wire
