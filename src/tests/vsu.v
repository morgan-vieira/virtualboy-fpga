`timescale 1ns/1ps
`default_nettype none

module vsu_tb;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    logic reset_n = 1'b0;
    logic ce = 1'b1;
    logic sel = 1'b0;
    logic [26:1] addr = 26'd0;
    logic we = 1'b0;
    logic [1:0] be = 2'd0;
    logic [15:0] wdata = 16'd0;
    logic signed [15:0] sample_left;
    logic signed [15:0] sample_right;
    integer first_filtered_sample;

    vsu dut (.*);

    task automatic write8(input logic [10:0] byte_offset, input logic [7:0] value);
        @(negedge clk);
        sel = 1'b1;
        we = 1'b1;
        be = 2'b01;
        addr = {15'd0, byte_offset[10:1]};
        wdata = {8'hxx, value};
        @(negedge clk);
        sel = 1'b0;
        we = 1'b0;
        be = 2'b00;
    endtask

    task automatic write8_high(
        input logic [10:0] byte_offset,
        input logic [7:0] value
    );
        @(negedge clk);
        sel = 1'b1;
        we = 1'b1;
        be = 2'b10;
        addr = {15'd0, byte_offset[10:1]};
        wdata = {value, 8'hxx};
        @(negedge clk);
        sel = 1'b0;
        we = 1'b0;
        be = 2'b00;
    endtask

    task automatic expect_samples(
        input logic [9:0] left,
        input logic [9:0] right,
        input string what
    );
        @(negedge clk);
        dut.sample_divider = 9'd479;
        ce = 1'b1;
        repeat (8) @(posedge clk);
        #1;
        if (dut.digital_left !== left || dut.digital_right !== right)
            $fatal(1, "%0s: got L=%0d R=%0d, expected L=%0d R=%0d",
                   what, dut.digital_left, dut.digital_right, left, right);
        @(negedge clk);
        ce = 1'b0;
    endtask

    task automatic configure_channel(
        input integer channel,
        input logic [7:0] volume,
        input logic [3:0] bank
    );
        logic [10:0] base;
        begin
            base = 11'h400 + channel * 11'h040;
            write8(base + 11'h004, volume);
            write8(base + 11'h008, 8'h00);
            write8(base + 11'h00c, 8'h00);
            write8(base + 11'h010, 8'hf0);
            write8(base + 11'h018, {4'd0, bank});
            write8(base, 8'h80);
        end
    endtask

    task automatic step_envelope;
        @(negedge clk);
        dut.base_clock_divider = 2'd3;
        dut.envelope_counter[0] = 4'd1;
        dut.envelope_divider[0] = 19'd1;
        ce = 1'b1;
        @(posedge clk);
        @(negedge clk);
        ce = 1'b0;
    endtask

    task automatic step_sweep;
        @(negedge clk);
        dut.base_clock_divider = 2'd3;
        dut.sweep_elapsed = dut.sweep_frame_period - 19'd1;
        ce = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        ce = 1'b0;
    endtask

    task automatic step_noise;
        @(negedge clk);
        dut.base_clock_divider = 2'd3;
        dut.frequency_counter[5] = 15'd1;
        ce = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        ce = 1'b0;
    endtask

    task automatic expect_noise_period(
        input logic [2:0] tap,
        input integer transient_length,
        input logic [14:0] cycle_start,
        input integer expected
    );
        integer length;
        begin
            write8(11'h554, {1'b0, tap, 4'd0});
            for (length = 0; length < transient_length; length = length + 1)
                step_noise();
            if (dut.noise_lfsr !== cycle_start)
                $fatal(1, "tap %0d transient ended at %0d, expected %0d",
                       tap, dut.noise_lfsr, cycle_start);
            for (length = 0; length < expected; length = length + 1)
                step_noise();
            if (dut.noise_lfsr !== cycle_start)
                $fatal(1, "tap %0d did not repeat after %0d samples",
                       tap, expected);
        end
    endtask

    initial begin
        repeat (4) @(negedge clk);
        reset_n = 1'b1;

        expect_samples(0, 0, "reset silence");

        write8_high(11'h405, 8'hab);
        if (dut.left_level[0] !== 4'ha || dut.right_level[0] !== 4'hb)
            $fatal(1, "high byte register write was not accepted");
        write8(11'h406, 8'h3c);
        if (dut.left_level[0] !== 4'h3 || dut.right_level[0] !== 4'hc)
            $fatal(1, "VSU address bit one was not ignored");
        write8_high(11'h001, 8'd55);
        if (dut.wave_ram[0] !== 6'd0)
            $fatal(1, "unaligned waveform byte was accepted");

        write8(11'h000, 8'd0);
        write8(11'h004, 8'd63);
        write8(11'h404, 8'hf8);
        write8(11'h408, 8'hfe);
        write8(11'h40c, 8'h07);
        write8(11'h410, 8'hf0);
        write8(11'h418, 8'h00);
        write8(11'h400, 8'h80);

        ce = 1'b0;
        expect_samples(0, 0, "position zero");
        @(negedge clk);
        dut.wave_position[0] = 5'd0;
        dut.frequency_counter[0] = 15'd2;
        dut.base_clock_divider = 2'd0;
        ce = 1'b1;
        repeat (7) @(posedge clk);
        #1;
        if (dut.wave_position[0] !== 5'd0)
            $fatal(1, "frequency advanced before the second VSU tick");
        @(posedge clk);
        #1;
        if (dut.wave_position[0] !== 5'd1)
            $fatal(1, "frequency did not advance on the second VSU tick");
        @(negedge clk);
        ce = 1'b0;
        expect_samples(114, 63, "frequency advances with stereo gain");

        write8(11'h580, 8'h01);
        expect_samples(0, 0, "global stop");

        // Every wavetable channel owns its phase, bank, and stereo gain.
        // The chosen samples make each contribution visible in the sum.
        write8(11'h000, 8'd0);
        write8(11'h080, 8'd63);
        write8(11'h100, 8'd32);
        write8(11'h180, 8'd16);
        write8(11'h200, 8'd48);
        configure_channel(0, 8'hf0, 4'd0);
        configure_channel(1, 8'h0f, 4'd1);
        configure_channel(2, 8'h80, 4'd2);
        configure_channel(3, 8'h40, 4'd3);
        configure_channel(4, 8'h04, 4'd4);
        expect_samples(40, 138, "five-channel stereo mix");

        write8(11'h4c0, 8'h00);
        expect_samples(32, 138, "individual channel stop");
        write8(11'h580, 8'h01);
        expect_samples(0, 0, "five-channel global stop");

        write8(11'h000, 8'd63);
        write8(11'h400, 8'ha0);
        expect_samples(114, 0, "interval restart");
        @(negedge clk);
        dut.base_clock_divider = 2'd0;
        ce = 1'b1;
        repeat (76800) @(posedge clk);
        @(negedge clk);
        ce = 1'b0;
        expect_samples(0, 0, "interval expiry");

        write8(11'h410, 8'hf0);
        write8(11'h414, 8'h01);
        write8(11'h400, 8'h80);
        expect_samples(114, 0, "decay starts at the written level");
        step_envelope();
        expect_samples(106, 0, "decay lowers the envelope");

        write8(11'h410, 8'h08);
        write8(11'h414, 8'h01);
        write8(11'h400, 8'h80);
        expect_samples(0, 0, "growth starts at the written level");
        step_envelope();
        expect_samples(7, 0, "growth raises the envelope");

        write8(11'h410, 8'h10);
        write8(11'h414, 8'h03);
        write8(11'h400, 8'h80);
        step_envelope();
        expect_samples(0, 0, "repeating decay reaches zero");
        step_envelope();
        expect_samples(7, 0, "repeat reloads the written level");

        write8(11'h508, 8'h00);
        write8(11'h50c, 8'h04);
        write8(11'h514, 8'h40);
        write8(11'h51c, 8'h13);
        write8(11'h500, 8'h80);
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd896)
            $fatal(1, "downward sweep produced %0d", dut.effective_frequency[4]);

        write8(11'h508, 8'h00);
        write8(11'h50c, 8'h04);
        write8(11'h51c, 8'h1b);
        write8(11'h500, 8'h80);
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd1152)
            $fatal(1, "upward sweep produced %0d", dut.effective_frequency[4]);

        write8(11'h508, 8'hf8);
        write8(11'h50c, 8'h07);
        write8(11'h500, 8'h80);
        if (dut.interval_control[4][7] !== 1'b0)
            $fatal(1, "sweep overflow did not stop channel five");

        write8(11'h508, 8'he8);
        write8(11'h50c, 8'h03);
        write8(11'h514, 8'h00);
        write8(11'h500, 8'h80);
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd1000)
            $fatal(1, "disabled sweep changed the frequency");

        write8(11'h508, 8'hf8);
        write8(11'h50c, 8'h07);
        write8(11'h500, 8'h80);
        if (dut.interval_control[4][7] !== 1'b0)
            $fatal(1, "disabled sweep overflow did not stop channel five");

        write8(11'h280, 8'd16);
        write8(11'h284, 8'hf0);
        write8(11'h508, 8'he8);
        write8(11'h50c, 8'h03);
        write8(11'h514, 8'h50);
        write8(11'h51c, 8'h10);
        write8(11'h500, 8'h80);
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd1016 ||
            dut.modulation_position !== 6'd1)
            $fatal(1, "positive modulation step failed");
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd984 ||
            dut.modulation_position !== 6'd2)
            $fatal(1, "negative modulation step failed");

        write8(11'h280, 8'd99);
        if (dut.modulation_ram[0] !== 8'd16)
            $fatal(1, "active channel allowed modulation RAM write");

        dut.modulation_position = 6'd0;
        write8(11'h508, 8'he8);
        if (dut.modulation_frequency[10:0] !== 11'd1000)
            $fatal(1, "low frequency write did not lock modulation low byte");
        write8_high(11'h405, 8'hff);
        if (dut.modulation_frequency[10:0] !== 11'd1000)
            $fatal(1, "odd VSU write cleared the modulation byte lock");
        write8(11'h404, 8'hff);
        if (dut.modulation_frequency[10:0] !== 11'd1016)
            $fatal(1, "even VSU write did not clear modulation byte lock");

        dut.modulation_position = 6'd32;
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd1000 ||
            dut.modulation_position !== 6'd32)
            $fatal(1, "one-shot modulation did not stop at entry 32");

        write8(11'h514, 8'h70);
        step_sweep();
        if (dut.effective_frequency[4] !== 11'd1016 ||
            dut.modulation_position !== 6'd1)
            $fatal(1, "repeating modulation did not wrap to entry zero");

        write8(11'h500, 8'h00);
        write8(11'h280, 8'd99);
        if (dut.modulation_ram[0] !== 8'd99)
            $fatal(1, "inactive channel blocked modulation RAM write");

        write8(11'h580, 8'h01);
        write8(11'h544, 8'hf0);
        write8(11'h548, 8'hff);
        write8(11'h54c, 8'h07);
        write8(11'h550, 8'hf0);
        write8(11'h554, 8'h00);
        write8(11'h540, 8'h80);
        expect_samples(114, 0, "noise starts from the first feedback bit");
        step_noise();
        if (dut.noise_lfsr !== 15'd1 || dut.frequency_counter[5] !== 15'd10)
            $fatal(1, "noise first step or 500 kHz period failed");
        expect_samples(114, 0, "noise scales a set bit to 63");

        write8(11'h554, 8'h00);
        dut.noise_lfsr = 15'h4000;
        step_noise();
        if (dut.noise_lfsr[0] !== 1'b0)
            $fatal(1, "tap zero did not use bit 14");
        write8(11'h554, 8'h10);
        dut.noise_lfsr = 15'h4000;
        step_noise();
        if (dut.noise_lfsr[0] !== 1'b1)
            $fatal(1, "tap one did not use bit 10");

        write8(11'h554, 8'h70);
        if (dut.noise_lfsr !== 15'd0)
            $fatal(1, "noise EV1 write did not reset the LFSR");
        dut.noise_lfsr = 15'h1234;
        write8(11'h540, 8'h80);
        if (dut.noise_lfsr !== 15'd0)
            $fatal(1, "noise INT write did not reset the LFSR");

        expect_noise_period(3'd0, 0, 15'd0, 32767);
        expect_noise_period(3'd1, 4, 15'd15, 1953);
        expect_noise_period(3'd2, 1, 15'd1, 254);
        expect_noise_period(3'd3, 7, 15'd124, 217);
        expect_noise_period(3'd4, 6, 15'd63, 73);
        expect_noise_period(3'd5, 7, 15'd127, 63);
        expect_noise_period(3'd6, 5, 15'd31, 42);
        expect_noise_period(3'd7, 3, 15'd7, 28);

        write8(11'h580, 8'h01);
        write8(11'h000, 8'd12);
        write8(11'h540, 8'h80);
        write8(11'h000, 8'd34);
        if (dut.wave_ram[0] !== 6'd12)
            $fatal(1, "active noise channel did not lock waveform RAM");
        write8(11'h580, 8'h01);
        write8(11'h000, 8'd34);
        if (dut.wave_ram[0] !== 6'd34)
            $fatal(1, "inactive channels did not unlock waveform RAM");

        write8(11'h410, 8'h00);
        write8(11'h414, 8'h01);
        write8(11'h400, 8'h80);
        step_envelope();
        if (!dut.envelope_terminal[0])
            $fatal(1, "one-shot envelope did not latch its endpoint");
        write8(11'h414, 8'h03);
        step_envelope();
        if (dut.envelope_level[0] !== 4'd0)
            $fatal(1, "terminal envelope resumed without an INT write");
        write8(11'h400, 8'h80);
        step_envelope();
        if (dut.envelope_level[0] !== 4'd0 ||
            dut.envelope_terminal[0] !== 1'b0)
            $fatal(1, "INT did not restart the terminal envelope frame");
        step_envelope();
        if (dut.envelope_level[0] !== 4'd0)
            $fatal(1, "zero reload envelope changed unexpectedly");

        write8(11'h580, 8'h01);
        write8(11'h410, 8'hf0);
        write8(11'h418, 8'h07);
        write8(11'h400, 8'h80);
        expect_samples(0, 0, "invalid wave bank is silent");
        if (dut.interval_control[0][7] !== 1'b1)
            $fatal(1, "invalid wave bank stopped the active channel");

        @(negedge clk);
        dut.wave_position[0] = 5'd19;
        dut.frequency_counter[0] = 15'd7;
        dut.envelope_counter[0] = 4'd6;
        write8(11'h400, 8'h00);
        if (dut.wave_position[0] !== 5'd0 ||
            dut.frequency_counter[0] !== 15'd2048 ||
            dut.envelope_counter[0] !== 4'd1)
            $fatal(1, "disabled INT write did not reset channel timing");

        write8(11'h508, 8'h00);
        write8(11'h50c, 8'h04);
        write8(11'h514, 8'h40);
        write8(11'h51c, 8'h21);
        write8(11'h500, 8'h80);
        dut.sweep_elapsed = 19'd6000;
        write8(11'h51c, 8'h31);
        if (dut.sweep_frame_period !== 19'd14400)
            $fatal(1, "longer sweep interval did not extend current frame");
        dut.sweep_elapsed = 19'd13000;
        write8(11'h51c, 8'h21);
        if (dut.sweep_frame_period !== 19'd14400 ||
            dut.sweep_next_period !== 19'd9600)
            $fatal(1, "elapsed sweep frame did not retain its old period");

        write8(11'h508, 8'hf8);
        write8(11'h50c, 8'h07);
        write8(11'h51c, 8'h18);
        if (dut.interval_control[4][7] !== 1'b0)
            $fatal(1, "S5SWP overflow write did not stop channel five");

        write8(11'h580, 8'h01);
        write8(11'h000, 8'd63);
        write8(11'h404, 8'hf0);
        write8(11'h410, 8'hf0);
        write8(11'h418, 8'h00);
        write8(11'h400, 8'h80);
        @(negedge clk);
        dut.sample_divider = 9'd0;
        dut.mix_active = 1'b0;
        dut.digital_left = 10'h3ff;
        dut.filter_previous_left = 17'sd0;
        dut.filter_state_left = 18'sd0;
        ce = 1'b1;
        repeat (479) @(posedge clk);
        #1;
        if (dut.digital_left !== 10'h3ff || dut.mix_active !== 1'b0)
            $fatal(1, "mixer published before the 480-cycle sample period");
        @(posedge clk);
        repeat (6) @(posedge clk);
        #1;
        if (dut.digital_left !== 10'd114 || sample_left <= 16'sd0)
            $fatal(1, "41.7 kHz mixer did not publish the documented level");
        first_filtered_sample = sample_left;
        @(negedge clk);
        dut.sample_divider = 9'd479;
        repeat (7) @(posedge clk);
        #1;
        if (sample_left >= first_filtered_sample || sample_left <= 16'sd0)
            $fatal(1, "DC-block filter did not decay a constant input");

        $finish;
    end

endmodule

`default_nettype wire
