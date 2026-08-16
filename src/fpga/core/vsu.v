`default_nettype none

// Five wavetable channels and one noise channel.
module vsu (
    input  logic               clk,
    input  logic               reset_n,
    input  logic               ce,

    input  logic               sel,
    input  logic [26:1]        addr,
    input  logic               we,
    input  logic [1:0]         be,
    input  logic [15:0]        wdata,

    output logic signed [15:0] sample_left,
    output logic signed [15:0] sample_right
);

    localparam integer CHANNEL_COUNT = 6;

    logic [5:0] wave_ram [0:159];
    logic [7:0] modulation_ram [0:31];

    logic [7:0]  interval_control [0:CHANNEL_COUNT - 1];
    logic [3:0]  left_level [0:CHANNEL_COUNT - 1];
    logic [3:0]  right_level [0:CHANNEL_COUNT - 1];
    logic [10:0] frequency [0:CHANNEL_COUNT - 1];
    logic [10:0] effective_frequency [0:CHANNEL_COUNT - 1];
    logic [15:0] envelope_control [0:CHANNEL_COUNT - 1];
    logic [3:0]  envelope_level [0:CHANNEL_COUNT - 1];
    logic [3:0]  wave_bank [0:CHANNEL_COUNT - 1];

    logic [14:0] frequency_counter [0:CHANNEL_COUNT - 1];
    logic [4:0]  wave_position [0:CHANNEL_COUNT - 1];
    logic [5:0]  interval_counter [0:CHANNEL_COUNT - 1];
    logic [14:0] interval_divider [0:CHANNEL_COUNT - 1];
    logic [3:0]  envelope_counter [0:CHANNEL_COUNT - 1];
    logic [18:0] envelope_divider [0:CHANNEL_COUNT - 1];
    logic [7:0]  sweep_control;
    logic [2:0]  sweep_interval_counter;
    logic [15:0] sweep_clock_divider;
    logic [11:0] sweep_delta;
    logic [11:0] sweep_next_frequency;
    logic [11:0] sweep_pending_frequency;
    logic [11:0] sweep_pending_delta;
    logic [11:0] sweep_following_frequency;
    logic [5:0]  modulation_position;
    logic [11:0] modulation_frequency;
    logic [14:0] noise_lfsr;
    logic        noise_feedback;

    logic [10:0] offset;
    logic        aligned_write;
    logic [7:0]  write_byte;
    logic [3:0]  register_index;
    logic [7:0]  wave_index;
    logic [4:0]  modulation_index;
    logic [2:0]  write_channel;
    logic        channel_write;
    logic        global_stop_write;
    logic        any_channel_active;
    logic [1:0]  base_clock_divider;
    logic        base_tick;

    assign offset = {addr[10:1], 1'b0};
    assign aligned_write = sel && we && be[0] && offset[1:0] == 2'b00;
    assign write_byte = wdata[7:0];
    assign register_index = offset[5:2];
    assign wave_index = offset[9:2];
    assign modulation_index = offset[6:2];
    assign write_channel = offset[8:6];
    assign channel_write = aligned_write && offset >= 11'h400 &&
                           offset < 11'h580;
    assign global_stop_write = aligned_write && offset == 11'h580 && write_byte[0];
    assign any_channel_active = interval_control[0][7] |
                                interval_control[1][7] |
                                interval_control[2][7] |
                                interval_control[3][7] |
                                interval_control[4][7] |
                                interval_control[5][7];
    assign base_tick = ce && base_clock_divider == 2'd3;
    assign sweep_delta = {1'b0, effective_frequency[4]} >> sweep_control[2:0];
    assign sweep_next_frequency = sweep_control[3] ?
        {1'b0, effective_frequency[4]} + sweep_delta :
        {1'b0, effective_frequency[4]} - sweep_delta;
    assign sweep_pending_delta = sweep_pending_frequency >> sweep_control[2:0];
    assign sweep_following_frequency = sweep_control[3] ?
        sweep_pending_frequency + sweep_pending_delta :
        sweep_pending_frequency - sweep_pending_delta;
    assign modulation_frequency = {1'b0, frequency[4]} +
        {{4{modulation_ram[modulation_position[4:0]][7]}},
         modulation_ram[modulation_position[4:0]]};

    function automatic logic noise_tap(
        input logic [14:0] state,
        input logic [2:0] tap
    );
        unique case (tap)
            3'd0: noise_tap = state[14];
            3'd1: noise_tap = state[10];
            3'd2: noise_tap = state[13];
            3'd3: noise_tap = state[4];
            3'd4: noise_tap = state[8];
            3'd5: noise_tap = state[6];
            3'd6: noise_tap = state[9];
            3'd7: noise_tap = state[11];
            default: noise_tap = 1'b0;
        endcase
    endfunction

    function automatic logic [14:0] frequency_period(
        input logic [10:0] value,
        input logic noise
    );
        logic [14:0] base_period;
        begin
            base_period = 15'd2048 - value;
            frequency_period = noise ?
                (base_period << 3) + (base_period << 1) : base_period;
        end
    endfunction

    assign noise_feedback = noise_lfsr[7] ^
        noise_tap(noise_lfsr, envelope_control[5][14:12]) ^ 1'b1;

    integer channel_index;
    integer wave_reset_index;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            base_clock_divider <= 2'd0;
            sweep_control <= 8'd0;
            sweep_interval_counter <= 3'd0;
            sweep_clock_divider <= 16'd4800;
            sweep_pending_frequency <= 12'd0;
            modulation_position <= 6'd0;
            noise_lfsr <= 15'd0;
            for (wave_reset_index = 0; wave_reset_index < 160;
                 wave_reset_index = wave_reset_index + 1)
                wave_ram[wave_reset_index] <= 6'd0;
            for (wave_reset_index = 0; wave_reset_index < 32;
                 wave_reset_index = wave_reset_index + 1)
                modulation_ram[wave_reset_index] <= 8'd0;
            for (channel_index = 0; channel_index < CHANNEL_COUNT;
                 channel_index = channel_index + 1) begin
                interval_control[channel_index] <= 8'd0;
                left_level[channel_index] <= 4'd0;
                right_level[channel_index] <= 4'd0;
                frequency[channel_index] <= 11'd0;
                effective_frequency[channel_index] <= 11'd0;
                envelope_control[channel_index] <= 16'd0;
                envelope_level[channel_index] <= 4'd0;
                wave_bank[channel_index] <= 4'd0;
                frequency_counter[channel_index] <= 15'd0;
                wave_position[channel_index] <= 5'd0;
                interval_counter[channel_index] <= 6'd0;
                interval_divider[channel_index] <= 15'd0;
                envelope_counter[channel_index] <= 4'd1;
                envelope_divider[channel_index] <= 19'd76800;
            end
        end else begin
            if (ce)
                base_clock_divider <= base_clock_divider + 2'd1;

            if (aligned_write && offset < 11'h280 && !any_channel_active)
                wave_ram[wave_index] <= write_byte[5:0];
            if (aligned_write && offset >= 11'h280 && offset < 11'h300 &&
                !interval_control[4][7])
                modulation_ram[modulation_index] <= write_byte;

            if (base_tick) begin
                for (channel_index = 0; channel_index < CHANNEL_COUNT;
                     channel_index = channel_index + 1) begin
                    if (interval_control[channel_index][7]) begin
                        if (frequency_counter[channel_index] <= 15'd1) begin
                            frequency_counter[channel_index] <=
                                frequency_period(effective_frequency[channel_index],
                                                 channel_index == 5);
                            if (channel_index == 5)
                                noise_lfsr <= {noise_lfsr[13:0], noise_feedback};
                            else
                                wave_position[channel_index] <=
                                    wave_position[channel_index] + 5'd1;
                        end else begin
                            frequency_counter[channel_index] <=
                                frequency_counter[channel_index] - 15'd1;
                        end

                        if (interval_divider[channel_index] <= 15'd1) begin
                            interval_divider[channel_index] <= 15'd19200;
                            if (interval_control[channel_index][5]) begin
                                if (interval_counter[channel_index] <= 6'd1) begin
                                    interval_counter[channel_index] <= 6'd0;
                                    interval_control[channel_index][7] <= 1'b0;
                                end else begin
                                    interval_counter[channel_index] <=
                                        interval_counter[channel_index] - 6'd1;
                                end
                            end
                        end else begin
                            interval_divider[channel_index] <=
                                interval_divider[channel_index] - 15'd1;
                        end

                        if (envelope_divider[channel_index] <= 19'd1) begin
                            envelope_divider[channel_index] <= 19'd76800;
                            if (envelope_counter[channel_index] <= 4'd1) begin
                                envelope_counter[channel_index] <=
                                    {1'b0, envelope_control[channel_index][2:0]} + 4'd1;
                                if (envelope_control[channel_index][8]) begin
                                    if (envelope_control[channel_index][3]) begin
                                        if (envelope_level[channel_index] < 4'd15)
                                            envelope_level[channel_index] <=
                                                envelope_level[channel_index] + 4'd1;
                                        else if (envelope_control[channel_index][9])
                                            envelope_level[channel_index] <=
                                                envelope_control[channel_index][7:4];
                                    end else begin
                                        if (envelope_level[channel_index] > 4'd0)
                                            envelope_level[channel_index] <=
                                                envelope_level[channel_index] - 4'd1;
                                        else if (envelope_control[channel_index][9])
                                            envelope_level[channel_index] <=
                                                envelope_control[channel_index][7:4];
                                    end
                                end
                            end else begin
                                envelope_counter[channel_index] <=
                                    envelope_counter[channel_index] - 4'd1;
                            end
                        end else begin
                            envelope_divider[channel_index] <=
                                envelope_divider[channel_index] - 19'd1;
                        end
                    end
                end

                if (interval_control[4][7]) begin
                    if (sweep_clock_divider <= 16'd1) begin
                        sweep_clock_divider <= sweep_control[7] ?
                            16'd38400 : 16'd4800;
                        if (sweep_interval_counter <= 3'd1) begin
                            sweep_interval_counter <= sweep_control[6:4];
                            if (sweep_control[6:4] != 3'd0 &&
                                envelope_control[4][14]) begin
                                if (envelope_control[4][12]) begin
                                    if (modulation_position < 6'd32 ||
                                        envelope_control[4][13]) begin
                                        effective_frequency[4] <=
                                            modulation_frequency[10:0];
                                        modulation_position <=
                                            modulation_position < 6'd32 ?
                                            modulation_position + 6'd1 : 6'd1;
                                    end
                                end else begin
                                    effective_frequency[4] <=
                                        sweep_pending_frequency[10:0];
                                    sweep_pending_frequency <=
                                        sweep_following_frequency;
                                    if (sweep_following_frequency[11])
                                        interval_control[4][7] <= 1'b0;
                                end
                            end
                        end else begin
                            sweep_interval_counter <=
                                sweep_interval_counter - 3'd1;
                        end
                    end else begin
                        sweep_clock_divider <= sweep_clock_divider - 16'd1;
                    end
                end
            end

            if (channel_write) begin
                unique case (register_index)
                    4'h0: begin
                        interval_control[write_channel] <= write_byte & 8'hbf;
                        if (write_channel == 3'd5)
                            noise_lfsr <= 15'd0;
                        if (write_byte[7]) begin
                            frequency_counter[write_channel] <=
                                frequency_period(effective_frequency[write_channel],
                                                 write_channel == 3'd5);
                            wave_position[write_channel] <= 5'd0;
                            interval_counter[write_channel] <=
                                {1'b0, write_byte[4:0]} + 6'd1;
                            interval_divider[write_channel] <= 15'd19200;
                            envelope_counter[write_channel] <=
                                {1'b0, envelope_control[write_channel][2:0]} + 4'd1;
                            envelope_divider[write_channel] <= 19'd76800;
                            if (write_channel == 3'd4) begin
                                sweep_interval_counter <= sweep_control[6:4];
                                sweep_clock_divider <= sweep_control[7] ?
                                    16'd38400 : 16'd4800;
                                modulation_position <= 6'd0;
                                sweep_pending_frequency <= sweep_next_frequency;
                                if (!envelope_control[4][12] &&
                                    sweep_next_frequency[11])
                                    interval_control[4][7] <= 1'b0;
                            end
                        end
                    end
                    4'h1: begin
                        left_level[write_channel] <= write_byte[7:4];
                        right_level[write_channel] <= write_byte[3:0];
                    end
                    4'h2: begin
                        frequency[write_channel][7:0] <= write_byte;
                        effective_frequency[write_channel][7:0] <= write_byte;
                    end
                    4'h3: begin
                        frequency[write_channel][10:8] <= write_byte[2:0];
                        effective_frequency[write_channel][10:8] <= write_byte[2:0];
                    end
                    4'h4: begin
                        envelope_control[write_channel][7:0] <= write_byte;
                        envelope_level[write_channel] <= write_byte[7:4];
                    end
                    4'h5: begin
                        envelope_control[write_channel][9:8] <= write_byte[1:0];
                        if (write_channel >= 3'd4)
                            envelope_control[write_channel][14:12] <= write_byte[6:4];
                        if (write_channel == 3'd5)
                            noise_lfsr <= 15'd0;
                    end
                    4'h6: begin
                        if (write_channel < 3'd5)
                            wave_bank[write_channel] <= write_byte[3:0];
                    end
                    4'h7: begin
                        if (write_channel == 3'd4)
                            sweep_control <= write_byte;
                    end
                    default: begin end
                endcase
            end

            if (global_stop_write) begin
                for (channel_index = 0; channel_index < CHANNEL_COUNT;
                     channel_index = channel_index + 1)
                    interval_control[channel_index][7] <= 1'b0;
            end
        end
    end

    function automatic logic [7:0] channel_gain(
        input logic [3:0] envelope,
        input logic [3:0] level
    );
        logic [7:0] product;
        begin
            product = envelope * level;
            channel_gain = product == 0 ? 8'd0 : (product >> 3) + 8'd1;
        end
    endfunction

    logic [2:0] mix_index;
    logic signed [18:0] left_accumulator;
    logic signed [18:0] right_accumulator;
    logic [5:0] mix_wave_sample;
    logic [7:0] mix_left_gain;
    logic [7:0] mix_right_gain;
    logic signed [6:0] mix_centered_sample;
    logic signed [15:0] mix_left_product;
    logic signed [15:0] mix_right_product;
    logic signed [18:0] mix_left_contribution;
    logic signed [18:0] mix_right_contribution;

    always_comb begin
        if (mix_index == 3'd5)
            mix_wave_sample = noise_lfsr[0] ? 6'd63 : 6'd0;
        else
            mix_wave_sample = wave_bank[mix_index] < 5 ?
                wave_ram[{wave_bank[mix_index][2:0], wave_position[mix_index]}] :
                6'd0;
        mix_left_gain = channel_gain(
            envelope_level[mix_index], left_level[mix_index]);
        mix_right_gain = channel_gain(
            envelope_level[mix_index], right_level[mix_index]);
        mix_centered_sample = $signed({1'b0, mix_wave_sample}) - 7'sd32;
        mix_left_product = mix_centered_sample * $signed({1'b0, mix_left_gain});
        mix_right_product = mix_centered_sample * $signed({1'b0, mix_right_gain});
        mix_left_contribution = interval_control[mix_index][7] ?
            mix_left_product <<< 2 : 19'sd0;
        mix_right_contribution = interval_control[mix_index][7] ?
            mix_right_product <<< 2 : 19'sd0;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mix_index <= 3'd0;
            left_accumulator <= 19'sd0;
            right_accumulator <= 19'sd0;
            sample_left <= 16'sd0;
            sample_right <= 16'sd0;
        end else if (mix_index == 3'd5) begin
            sample_left <= left_accumulator + mix_left_contribution;
            sample_right <= right_accumulator + mix_right_contribution;
            mix_index <= 3'd0;
            left_accumulator <= 19'sd0;
            right_accumulator <= 19'sd0;
        end else begin
            mix_index <= mix_index + 3'd1;
            left_accumulator <= left_accumulator + mix_left_contribution;
            right_accumulator <= right_accumulator + mix_right_contribution;
        end
    end

endmodule

`default_nettype wire
