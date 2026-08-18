`timescale 1ns/1ps
`default_nettype none

//
// Every mode's pixel mapping, by hand, plus the anaglyph composite.
//
// The mappings come from beetle-vb's CopyFBColumnToTarget_* family and the
// geometry from VIP_StartFrame, both in mednafen/vb/vip.c; the numbers below
// were read off that source rather than off vip_stereo. Each mode is probed at
// its corners and at the seams either side of a boundary, because an off-by-one
// there is exactly what a maintainer cannot see: the picture still fills the
// screen, it is just wrong by a pixel.
//
// The eye a host pixel came from is not an output, so it is read back through
// the colour: the two lumas are driven to different values and a red-mode pixel
// names which one it used.
//

module vip_stereo_tb;
    localparam logic [2:0] MODE_2D_LEFT  = 3'd0;
    localparam logic [2:0] MODE_2D_RIGHT = 3'd1;
    localparam logic [2:0] MODE_ANAGLYPH = 3'd2;
    localparam logic [2:0] MODE_CSCOPE   = 3'd3;
    localparam logic [2:0] MODE_SBS      = 3'd4;
    localparam logic [2:0] MODE_VLI      = 3'd5;
    localparam logic [2:0] MODE_HLI      = 3'd6;

    localparam logic [7:0] LEFT_MARK  = 8'h40;
    localparam logic [7:0] RIGHT_MARK = 8'h80;

    logic clk = 1'b0;
    logic [2:0] mode = MODE_2D_LEFT;
    logic [2:0] preset = 3'd0;
    logic [1:0] separation = 2'd0;
    logic [10:0] host_x = 11'd0;
    logic [10:0] host_y = 11'd0;
    logic [7:0] luma_left = 8'd0;
    logic [7:0] luma_right = 8'd0;

    logic [10:0] h_active, v_active, h_total, v_total;
    logic [2:0] scaler_slot;
    logic [8:0] vb_x;
    logic [7:0] vb_y;
    logic mapped;
    logic [23:0] rgb;

    vip_stereo dut (.*);

    always #5 clk = ~clk;

    // Stage a host pixel, check where it lands, then clock it in so the eye
    // choice reaches the colour stage.
    task automatic expect_pos(input string name,
                              input [10:0] hx, input [10:0] hy,
                              input logic want_mapped,
                              input [8:0] wx, input [7:0] wy);
        begin
            @(negedge clk);
            host_x = hx;
            host_y = hy;
            #1;
            if (mapped !== want_mapped)
                $fatal(1, "%s (%0d,%0d): mapped %0b, expected %0b",
                       name, hx, hy, mapped, want_mapped);
            if (want_mapped && (vb_x !== wx || vb_y !== wy))
                $fatal(1, "%s (%0d,%0d): VIP pixel (%0d,%0d), expected (%0d,%0d)",
                       name, hx, hy, vb_x, vb_y, wx, wy);
        end
    endtask

    task automatic expect_map(input string name,
                              input [10:0] hx, input [10:0] hy,
                              input logic want_mapped,
                              input [8:0] wx, input [7:0] wy,
                              input logic want_eye);
        logic [23:0] want_rgb;
        begin
            expect_pos(name, hx, hy, want_mapped, wx, wy);

            @(posedge clk);
            #1;
            luma_left  = LEFT_MARK;
            luma_right = RIGHT_MARK;
            #1;
            want_rgb = !want_mapped ? 24'h000000
                     : want_eye    ? {RIGHT_MARK, 16'h0000}
                                   : {LEFT_MARK, 16'h0000};
            if (rgb !== want_rgb)
                $fatal(1, "%s (%0d,%0d): rgb %06x, expected %06x",
                       name, hx, hy, rgb, want_rgb);
        end
    endtask

    task automatic expect_raster(input string name,
                                 input [10:0] wha, input [10:0] wht,
                                 input [10:0] wva, input [10:0] wvt,
                                 input [2:0] wslot);
        begin
            #1;
            if (h_active !== wha || h_total !== wht ||
                v_active !== wva || v_total !== wvt)
                $fatal(1, "%s: raster %0dx%0d in %0dx%0d, expected %0dx%0d in %0dx%0d",
                       name, h_active, v_active, h_total, v_total,
                       wha, wva, wht, wvt);
            if (scaler_slot !== wslot)
                $fatal(1, "%s: scaler slot %0d, expected %0d",
                       name, scaler_slot, wslot);
        end
    endtask

    // Stage an anaglyph pixel and return the colour it mixes to.
    task automatic mix(input [7:0] ll, input [7:0] lr, output [23:0] got);
        begin
            @(negedge clk);
            host_x = 11'd10;
            host_y = 11'd10;
            @(posedge clk);
            #1;
            luma_left  = ll;
            luma_right = lr;
            #1;
            got = rgb;
        end
    endtask

    task automatic expect_mix(input string name,
                              input [7:0] ll, input [7:0] lr,
                              input [23:0] want_rgb);
        logic [23:0] got;
        begin
            mix(ll, lr, got);
            if (got !== want_rgb)
                $fatal(1, "%s: rgb %06x, expected %06x", name, got, want_rgb);
        end
    endtask

    // v * tint / 255, the same rounding vip_stereo uses.
    function automatic logic [7:0] tinted(input [7:0] value, input [7:0] tint);
        integer scaled;
        begin
            scaled = ((value * tint) * 257 + 32768) / 65536;
            tinted = scaled[7:0];
        end
    endfunction

    logic [23:0] only_left, only_right, both_eyes;
    integer p, ch;

    initial begin
        repeat (2) @(posedge clk);

        // ---- the rasters, one per mode ----
        mode = MODE_2D_LEFT;  expect_raster("2D left",  384, 480, 224, 512, 3'd0);
        mode = MODE_2D_RIGHT; expect_raster("2D right", 384, 480, 224, 512, 3'd0);
        mode = MODE_ANAGLYPH; expect_raster("anaglyph", 384, 480, 224, 512, 3'd0);
        mode = MODE_CSCOPE;   expect_raster("cyberscope", 512, 581, 384, 423, 3'd1);
        mode = MODE_VLI;      expect_raster("VLI", 768, 1024, 224, 240, 3'd2);
        mode = MODE_HLI;      expect_raster("HLI", 384, 480, 448, 512, 3'd3);

        // Each separation is its own video.json slot, because the file cannot
        // declare a width that moves.
        mode = MODE_SBS;
        separation = 2'd0; expect_raster("SBS 0",  768, 1024, 224, 240, 3'd4);
        separation = 2'd1; expect_raster("SBS 16", 784, 1024, 224, 240, 3'd5);
        separation = 2'd2; expect_raster("SBS 32", 800, 1024, 224, 240, 3'd6);
        separation = 2'd3; expect_raster("SBS 64", 832, 1024, 224, 240, 3'd7);

        // ---- 2D, both halves ----
        mode = MODE_2D_LEFT;
        expect_map("2D left top",    11'd0,   11'd0,   1'b1, 9'd0,   8'd0,   1'b0);
        expect_map("2D left bottom", 11'd383, 11'd223, 1'b1, 9'd383, 8'd223, 1'b0);
        mode = MODE_2D_RIGHT;
        expect_map("2D right top",    11'd0,   11'd0,   1'b1, 9'd0,   8'd0,   1'b1);
        expect_map("2D right bottom", 11'd383, 11'd223, 1'b1, 9'd383, 8'd223, 1'b1);

        // ---- Cyberscope: two quarter-turned panels in a 512x384 frame ----
        mode = MODE_CSCOPE;
        expect_map("cscope left margin",  11'd15,  11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope left first",   11'd16,  11'd0,   1'b1, 9'd383, 8'd0,   1'b0);
        expect_map("cscope left bottom",  11'd16,  11'd383, 1'b1, 9'd0,   8'd0,   1'b0);
        expect_map("cscope left last",    11'd239, 11'd383, 1'b1, 9'd0,   8'd223, 1'b0);
        expect_map("cscope centre gap",   11'd240, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope gap end",      11'd271, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope right first",  11'd272, 11'd0,   1'b1, 9'd0,   8'd223, 1'b1);
        expect_map("cscope right last",   11'd495, 11'd383, 1'b1, 9'd383, 8'd0,   1'b1);
        expect_map("cscope right margin", 11'd496, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);

        // ---- Side by side, touching and separated ----
        mode = MODE_SBS;
        separation = 2'd0;
        expect_map("sbs0 left last",   11'd383, 11'd0,   1'b1, 9'd383, 8'd0,   1'b0);
        expect_map("sbs0 right first", 11'd384, 11'd0,   1'b1, 9'd0,   8'd0,   1'b1);
        expect_map("sbs0 right last",  11'd767, 11'd223, 1'b1, 9'd383, 8'd223, 1'b1);
        separation = 2'd2;
        expect_map("sbs32 left last",   11'd383, 11'd0, 1'b1, 9'd383, 8'd0, 1'b0);
        expect_map("sbs32 gap first",   11'd384, 11'd0, 1'b0, 9'd0,   8'd0, 1'b0);
        expect_map("sbs32 gap last",    11'd415, 11'd0, 1'b0, 9'd0,   8'd0, 1'b0);
        expect_map("sbs32 right first", 11'd416, 11'd5, 1'b1, 9'd0,   8'd5, 1'b1);
        expect_map("sbs32 right last",  11'd799, 11'd5, 1'b1, 9'd383, 8'd5, 1'b1);

        // ---- Line interleaves: one eye per column, then per row ----
        mode = MODE_VLI;
        expect_map("vli even",  11'd0,   11'd7,   1'b1, 9'd0,   8'd7,   1'b0);
        expect_map("vli odd",   11'd1,   11'd7,   1'b1, 9'd0,   8'd7,   1'b1);
        expect_map("vli last L", 11'd766, 11'd223, 1'b1, 9'd383, 8'd223, 1'b0);
        expect_map("vli last R", 11'd767, 11'd223, 1'b1, 9'd383, 8'd223, 1'b1);

        mode = MODE_HLI;
        expect_map("hli even",  11'd10, 11'd0,   1'b1, 9'd10, 8'd0,   1'b0);
        expect_map("hli odd",   11'd10, 11'd1,   1'b1, 9'd10, 8'd0,   1'b1);
        expect_map("hli last L", 11'd10, 11'd446, 1'b1, 9'd10, 8'd223, 1'b0);
        expect_map("hli last R", 11'd10, 11'd447, 1'b1, 9'd10, 8'd223, 1'b1);

        // ---- Anaglyph: every host pixel is both eyes ----
        // Anaglyph reads straight through, and its colour is checked below
        // rather than through the one-eye probe expect_map uses.
        mode = MODE_ANAGLYPH;
        expect_pos("anaglyph origin", 11'd0,   11'd0,   1'b1, 9'd0,   8'd0);
        expect_pos("anaglyph corner", 11'd383, 11'd223, 1'b1, 9'd383, 8'd223);

        // Red and blue: the left eye owns red, the right owns blue.
        preset = 3'd0;
        expect_mix("red & blue", 8'h6A, 8'hC8, {8'h6A, 8'h00, 8'hC8});

        // Red and cyan: the right eye's two channels are tinted, not full.
        preset = 3'd1;
        expect_mix("red & cyan", 8'h6A, 8'd200,
                   {8'h6A, tinted(8'd200, 8'hB7), tinted(8'd200, 8'hEB)});
        if (tinted(8'd200, 8'hB7) !== 8'd144)
            $fatal(1, "cyan green tint is %0d, expected 144", tinted(8'd200, 8'hB7));
        if (tinted(8'd200, 8'hEB) !== 8'd184)
            $fatal(1, "cyan blue tint is %0d, expected 184", tinted(8'd200, 8'hEB));

        // Green and magenta: the left eye owns green, the right red and blue.
        preset = 3'd4;
        expect_mix("green & magenta", 8'h11, 8'h99, {8'h99, 8'h11, 8'h99});

        // Yellow and blue: the left eye owns two channels.
        preset = 3'd5;
        expect_mix("yellow & blue", 8'h6A, 8'hC8, {8'h6A, 8'h6A, 8'hC8});

        // The OR that composites the two eyes is only exact while no channel
        // carries both of them; beetle-vb tests exactly that before falling
        // back to summing linear light [Recalc3DModeStuff]. Every preset,
        // including the values that fall through to the last one, has to
        // split the three channels between the eyes -- so light one eye at a
        // time, and no channel may answer twice.
        for (p = 0; p < 8; p = p + 1) begin
            preset = p[2:0];
            mix(8'hFF, 8'h00, only_left);
            mix(8'h00, 8'hFF, only_right);
            mix(8'hFF, 8'hFF, both_eyes);
            for (ch = 0; ch < 3; ch = ch + 1) begin
                if (only_left[8*ch +: 8] != 8'd0 && only_right[8*ch +: 8] != 8'd0)
                    $fatal(1, "preset %0d channel %0d takes both eyes (%02x and %02x); the OR is wrong there",
                           p, ch, only_left[8*ch +: 8], only_right[8*ch +: 8]);
            end
            if (both_eyes !== (only_left | only_right))
                $fatal(1, "preset %0d: both eyes gave %06x, not %06x",
                       p, both_eyes, only_left | only_right);
            if (only_left === 24'd0 || only_right === 24'd0)
                $fatal(1, "preset %0d leaves an eye invisible", p);
        end

        $display("vip_stereo: PASS");
        $finish;
    end

    initial begin
        #500_000;
        $fatal(1, "timed out");
    end
endmodule

`default_nettype wire
