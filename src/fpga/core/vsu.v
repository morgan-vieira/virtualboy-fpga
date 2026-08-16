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
    logic        envelope_terminal [0:CHANNEL_COUNT - 1];
    logic [3:0]  wave_bank [0:CHANNEL_COUNT - 1];

    logic [14:0] frequency_counter [0:CHANNEL_COUNT - 1];
    logic [4:0]  wave_position [0:CHANNEL_COUNT - 1];
    logic [5:0]  interval_counter [0:CHANNEL_COUNT - 1];
    logic [14:0] interval_divider [0:CHANNEL_COUNT - 1];
    logic [3:0]  envelope_counter [0:CHANNEL_COUNT - 1];
    logic [18:0] envelope_divider [0:CHANNEL_COUNT - 1];
    logic [7:0]  sweep_control;
    logic [18:0] sweep_elapsed;
    logic [18:0] sweep_frame_period;
    logic [18:0] sweep_next_period;
    logic [11:0] sweep_delta;
    logic [11:0] sweep_next_frequency;
    logic [11:0] sweep_pending_frequency;
    logic [11:0] sweep_pending_delta;
    logic [11:0] sweep_following_frequency;
    logic [10:0] sweep_write_frequency;
    logic [7:0]  sweep_write_control;
    logic [11:0] sweep_write_candidate;
    logic [5:0]  modulation_position;
    logic [1:0]  modulation_lock;
    logic [11:0] modulation_sum;
    logic [11:0] modulation_frequency;
    logic [14:0] noise_lfsr;
    logic        noise_feedback;
    logic        noise_sample;

    logic [10:0] offset;
    logic        write_accept;
    logic        memory_write;
    logic        high_byte_write;
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

    assign high_byte_write = be == 2'b10;
    assign offset = {addr[10:2], 1'b0, high_byte_write};
    assign write_accept = sel && we &&
        (be == 2'b01 || high_byte_write || (be == 2'b11 && !addr[1]));
    assign memory_write = write_accept && offset[1:0] == 2'b00;
    assign write_byte = high_byte_write ? wdata[15:8] : wdata[7:0];
    assign register_index = offset[5:2];
    assign wave_index = offset[9:2];
    assign modulation_index = offset[6:2];
    assign write_channel = offset[8:6];
    assign channel_write = write_accept && offset >= 11'h400 &&
                           offset < 11'h580;
    assign global_stop_write = write_accept && offset == 11'h580 && write_byte[0];
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
    assign modulation_sum = {1'b0, frequency[4]} +
        {{4{modulation_ram[modulation_position[4:0]][7]}},
         modulation_ram[modulation_position[4:0]]};
    always_comb begin
        modulation_frequency = modulation_sum;
        if (modulation_lock == 2'd1)
            modulation_frequency[7:0] = frequency[4][7:0];
        else if (modulation_lock == 2'd2)
            modulation_frequency[10:8] = frequency[4][10:8];
    end

    assign sweep_write_frequency = register_index == 4'h2 ?
        {effective_frequency[4][10:8], write_byte} :
        register_index == 4'h3 ?
        {write_byte[2:0], effective_frequency[4][7:0]} :
        effective_frequency[4];
    assign sweep_write_control = register_index == 4'h7 ?
        write_byte : sweep_control;

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

    function automatic logic [18:0] sweep_period(
        input logic slow,
        input logic [2:0] interval_value
    );
        logic [18:0] unit_period;
        begin
            unit_period = slow ? 19'd38400 : 19'd4800;
            unique case (interval_value)
                3'd0, 3'd1: sweep_period = unit_period;
                3'd2: sweep_period = unit_period << 1;
                3'd3: sweep_period = (unit_period << 1) + unit_period;
                3'd4: sweep_period = unit_period << 2;
                3'd5: sweep_period = (unit_period << 2) + unit_period;
                3'd6: sweep_period = (unit_period << 2) +
                                             (unit_period << 1);
                default: sweep_period = (unit_period << 2) +
                                                (unit_period << 1) + unit_period;
            endcase
        end
    endfunction

    function automatic logic [11:0] sweep_candidate(
        input logic [10:0] value,
        input logic [7:0] control
    );
        logic [10:0] delta;
        begin
            delta = value >> control[2:0];
            sweep_candidate = control[3] ?
                {1'b0, value} + {1'b0, delta} :
                {1'b0, value} - {1'b0, delta};
        end
    endfunction

    assign sweep_write_candidate = sweep_candidate(
        sweep_write_frequency, sweep_write_control);

    assign noise_feedback = noise_lfsr[7] ^
        noise_tap(noise_lfsr, envelope_control[5][14:12]) ^ 1'b1;

    integer channel_index;
    integer wave_reset_index;
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            base_clock_divider <= 2'd0;
            sweep_control <= 8'd0;
            sweep_elapsed <= 19'd0;
            sweep_frame_period <= 19'd4800;
            sweep_next_period <= 19'd4800;
            sweep_pending_frequency <= 12'd0;
            modulation_position <= 6'd0;
            modulation_lock <= 2'd0;
            noise_lfsr <= 15'd0;
            noise_sample <= 1'b1;
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
                envelope_terminal[channel_index] <= 1'b0;
                wave_bank[channel_index] <= 4'd0;
                frequency_counter[channel_index] <= 15'd0;
                wave_position[channel_index] <= 5'd0;
                interval_counter[channel_index] <= 6'd0;
                interval_divider[channel_index] <= 15'd0;
                envelope_counter[channel_index] <= 4'd1;
                envelope_divider[channel_index] <= 19'd76800;
            end
        end else begin
            if (write_accept) begin
                if (channel_write && write_channel == 3'd4 &&
                    register_index == 4'h2)
                    modulation_lock <= 2'd1;
                else if (channel_write && write_channel == 3'd4 &&
                         register_index == 4'h3)
                    modulation_lock <= 2'd2;
                else if (!offset[0])
                    modulation_lock <= 2'd0;
            end

            if (ce)
                base_clock_divider <= base_clock_divider + 2'd1;

            if (memory_write && offset < 11'h280 && !any_channel_active)
                wave_ram[wave_index] <= write_byte[5:0];
            if (memory_write && offset >= 11'h280 && offset < 11'h300 &&
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
                            if (channel_index == 5)
                                noise_sample <= noise_feedback;
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
                                if (envelope_control[channel_index][8] &&
                                    !envelope_terminal[channel_index]) begin
                                    if (envelope_control[channel_index][3]) begin
                                        if (envelope_level[channel_index] < 4'd15)
                                            envelope_level[channel_index] <=
                                                envelope_level[channel_index] + 4'd1;
                                        else if (envelope_control[channel_index][9])
                                            envelope_level[channel_index] <=
                                                envelope_control[channel_index][7:4];
                                        else
                                            envelope_terminal[channel_index] <= 1'b1;
                                    end else begin
                                        if (envelope_level[channel_index] > 4'd0)
                                            envelope_level[channel_index] <=
                                                envelope_level[channel_index] - 4'd1;
                                        else if (envelope_control[channel_index][9])
                                            envelope_level[channel_index] <=
                                                envelope_control[channel_index][7:4];
                                        else
                                            envelope_terminal[channel_index] <= 1'b1;
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
                    if (sweep_elapsed >= sweep_frame_period - 19'd1) begin
                        sweep_elapsed <= 19'd0;
                        sweep_frame_period <= sweep_next_period;
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
                                if (modulation_position == 6'd31)
                                    modulation_position <=
                                        envelope_control[4][13] ? 6'd0 : 6'd32;
                                else if (modulation_position < 6'd31)
                                    modulation_position <=
                                        modulation_position + 6'd1;
                                if (sweep_following_frequency[11])
                                    interval_control[4][7] <= 1'b0;
                            end
                        end
                    end else begin
                        sweep_elapsed <= sweep_elapsed + 19'd1;
                    end
                end
            end

            if (channel_write) begin
                unique case (register_index)
                    4'h0: begin
                        interval_control[write_channel] <= write_byte & 8'hbf;
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
                        envelope_terminal[write_channel] <= 1'b0;
                        if (write_channel == 3'd5)
                            noise_lfsr <= 15'd0;
                        if (write_channel == 3'd5)
                            noise_sample <= 1'b1;
                        if (write_channel == 3'd4) begin
                            sweep_elapsed <= 19'd0;
                            sweep_frame_period <= sweep_period(
                                sweep_control[7], sweep_control[6:4]);
                            sweep_next_period <= sweep_period(
                                sweep_control[7], sweep_control[6:4]);
                            modulation_position <= 6'd0;
                            sweep_pending_frequency <= sweep_next_frequency;
                            if (!envelope_control[4][12] &&
                                sweep_next_frequency[11])
                                interval_control[4][7] <= 1'b0;
                        end
                    end
                    4'h1: begin
                        left_level[write_channel] <= write_byte[7:4];
                        right_level[write_channel] <= write_byte[3:0];
                    end
                    4'h2: begin
                        frequency[write_channel][7:0] <= write_byte;
                        effective_frequency[write_channel][7:0] <= write_byte;
                        if (write_channel == 3'd4 &&
                            !envelope_control[4][12]) begin
                            sweep_pending_frequency <= sweep_write_candidate;
                            if (sweep_write_candidate[11])
                                interval_control[4][7] <= 1'b0;
                        end
                    end
                    4'h3: begin
                        frequency[write_channel][10:8] <= write_byte[2:0];
                        effective_frequency[write_channel][10:8] <= write_byte[2:0];
                        if (write_channel == 3'd4 &&
                            !envelope_control[4][12]) begin
                            sweep_pending_frequency <= sweep_write_candidate;
                            if (sweep_write_candidate[11])
                                interval_control[4][7] <= 1'b0;
                        end
                    end
                    4'h4: begin
                        envelope_control[write_channel][7:0] <= write_byte;
                        envelope_level[write_channel] <= write_byte[7:4];
                    end
                    4'h5: begin
                        envelope_control[write_channel][9:8] <= write_byte[1:0];
                        if (write_channel >= 3'd4)
                            envelope_control[write_channel][14:12] <= write_byte[6:4];
                        if (write_channel == 3'd4 && !write_byte[4]) begin
                            sweep_pending_frequency <= sweep_write_candidate;
                            if (sweep_write_candidate[11])
                                interval_control[4][7] <= 1'b0;
                        end
                        if (write_channel == 3'd5)
                            noise_lfsr <= 15'd0;
                        if (write_channel == 3'd5)
                            noise_sample <= 1'b1;
                    end
                    4'h6: begin
                        if (write_channel < 3'd5)
                            wave_bank[write_channel] <= {1'b0, write_byte[2:0]};
                    end
                    4'h7: begin
                        if (write_channel == 3'd4) begin
                            sweep_control <= write_byte;
                            sweep_next_period <= sweep_period(
                                write_byte[7], write_byte[6:4]);
                            if (sweep_elapsed < sweep_period(
                                write_byte[7], write_byte[6:4]))
                                sweep_frame_period <= sweep_period(
                                    write_byte[7], write_byte[6:4]);
                            if (!envelope_control[4][12]) begin
                                sweep_pending_frequency <= sweep_write_candidate;
                                if (sweep_write_candidate[11])
                                    interval_control[4][7] <= 1'b0;
                            end
                        end
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

    logic [8:0] sample_divider;
    logic       mix_active;
    logic [2:0] mix_index;
    logic [13:0] left_accumulator;
    logic [13:0] right_accumulator;
    logic [5:0] mix_wave_sample;
    logic [7:0] mix_left_gain;
    logic [7:0] mix_right_gain;
    logic       mix_sample_valid;
    logic [10:0] mix_left_contribution;
    logic [10:0] mix_right_contribution;
    logic [13:0] mix_left_sum;
    logic [13:0] mix_right_sum;
    logic [9:0] digital_left;
    logic [9:0] digital_right;
    logic       mix_channel_active [0:CHANNEL_COUNT - 1];
    logic [3:0] mix_channel_left [0:CHANNEL_COUNT - 1];
    logic [3:0] mix_channel_right [0:CHANNEL_COUNT - 1];
    logic [3:0] mix_channel_envelope [0:CHANNEL_COUNT - 1];
    logic [3:0] mix_channel_bank [0:CHANNEL_COUNT - 1];
    logic [4:0] mix_channel_position [0:CHANNEL_COUNT - 1];
    logic       mix_noise_bit;
    logic signed [16:0] filter_previous_left;
    logic signed [16:0] filter_previous_right;
    logic signed [17:0] filter_state_left;
    logic signed [17:0] filter_state_right;
    logic signed [17:0] filter_input_left;
    logic signed [17:0] filter_input_right;
    logic signed [18:0] filter_delta_left;
    logic signed [18:0] filter_delta_right;
    logic signed [35:0] filter_product_left;
    logic signed [35:0] filter_product_right;
    logic signed [17:0] filter_next_left;
    logic signed [17:0] filter_next_right;
    integer mix_reset_index;

    always_comb begin
        mix_sample_valid = mix_channel_active[mix_index];
        if (mix_index == 3'd5)
            mix_wave_sample = mix_noise_bit ? 6'd63 : 6'd0;
        else begin
            mix_sample_valid = mix_sample_valid &&
                               mix_channel_bank[mix_index] < 5;
            mix_wave_sample = mix_channel_bank[mix_index] < 5 ?
                wave_ram[{mix_channel_bank[mix_index][2:0],
                          mix_channel_position[mix_index]}] :
                6'd0;
        end
        mix_left_gain = channel_gain(
            mix_channel_envelope[mix_index], mix_channel_left[mix_index]);
        mix_right_gain = channel_gain(
            mix_channel_envelope[mix_index], mix_channel_right[mix_index]);
        mix_left_contribution = mix_sample_valid ?
            mix_wave_sample * mix_left_gain : 11'd0;
        mix_right_contribution = mix_sample_valid ?
            mix_wave_sample * mix_right_gain : 11'd0;
        mix_left_sum = left_accumulator + mix_left_contribution;
        mix_right_sum = right_accumulator + mix_right_contribution;
        filter_input_left = $signed({1'b0, mix_left_sum[13:4], 5'b00000});
        filter_input_right = $signed({1'b0, mix_right_sum[13:4], 5'b00000});
        filter_delta_left = filter_state_left + filter_input_left -
                            filter_previous_left;
        filter_delta_right = filter_state_right + filter_input_right -
                             filter_previous_right;
        filter_product_left = filter_delta_left * 17'sd65465;
        filter_product_right = filter_delta_right * 17'sd65465;
        filter_next_left = filter_product_left >>> 16;
        filter_next_right = filter_product_right >>> 16;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sample_divider <= 9'd0;
            mix_active <= 1'b0;
            mix_index <= 3'd0;
            left_accumulator <= 14'd0;
            right_accumulator <= 14'd0;
            digital_left <= 10'd0;
            digital_right <= 10'd0;
            filter_previous_left <= 17'sd0;
            filter_previous_right <= 17'sd0;
            filter_state_left <= 18'sd0;
            filter_state_right <= 18'sd0;
            mix_noise_bit <= 1'b0;
            for (mix_reset_index = 0; mix_reset_index < CHANNEL_COUNT;
                 mix_reset_index = mix_reset_index + 1) begin
                mix_channel_active[mix_reset_index] <= 1'b0;
                mix_channel_left[mix_reset_index] <= 4'd0;
                mix_channel_right[mix_reset_index] <= 4'd0;
                mix_channel_envelope[mix_reset_index] <= 4'd0;
                mix_channel_bank[mix_reset_index] <= 4'd0;
                mix_channel_position[mix_reset_index] <= 5'd0;
            end
            sample_left <= 16'sd0;
            sample_right <= 16'sd0;
        end else if (ce) begin
            if (sample_divider == 9'd479) begin
                sample_divider <= 9'd0;
                mix_active <= 1'b1;
                mix_index <= 3'd0;
                left_accumulator <= 14'd0;
                right_accumulator <= 14'd0;
                mix_noise_bit <= noise_sample;
                for (mix_reset_index = 0; mix_reset_index < CHANNEL_COUNT;
                     mix_reset_index = mix_reset_index + 1) begin
                    mix_channel_active[mix_reset_index] <=
                        interval_control[mix_reset_index][7];
                    mix_channel_left[mix_reset_index] <=
                        left_level[mix_reset_index];
                    mix_channel_right[mix_reset_index] <=
                        right_level[mix_reset_index];
                    mix_channel_envelope[mix_reset_index] <=
                        envelope_level[mix_reset_index];
                    mix_channel_bank[mix_reset_index] <=
                        wave_bank[mix_reset_index];
                    mix_channel_position[mix_reset_index] <=
                        wave_position[mix_reset_index];
                end
            end else begin
                sample_divider <= sample_divider + 9'd1;
            end

            if (mix_active) begin
                if (mix_index == 3'd5) begin
                    digital_left <= mix_left_sum[13:4];
                    digital_right <= mix_right_sum[13:4];
                    filter_previous_left <= filter_input_left[16:0];
                    filter_previous_right <= filter_input_right[16:0];
                    filter_state_left <= filter_next_left;
                    filter_state_right <= filter_next_right;
                    sample_left <= filter_next_left[15:0];
                    sample_right <= filter_next_right[15:0];
                    mix_active <= 1'b0;
                end else begin
                    mix_index <= mix_index + 3'd1;
                    left_accumulator <= mix_left_sum;
                    right_accumulator <= mix_right_sum;
                end
            end
        end
    end

endmodule

`default_nettype wire
