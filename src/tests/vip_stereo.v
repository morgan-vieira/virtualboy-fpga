`timescale 1ns/1ps
`default_nettype none

//
// Every row of the Stereo Mode menu: the colours it names, the raster it asks
// for, and where each host pixel comes from.
//
// The mappings come from beetle-vb's CopyFBColumnToTarget_* family and the
// geometry from VIP_StartFrame, both in mednafen/vb/vip.c; the colours from
// its Palette and AnaglyphPreset_Colors tables in libretro.cpp. The numbers
// below were read off those sources rather than off vip_stereo. Each layout
// is probed at its corners and at the seams either side of a boundary,
// because an off-by-one there is exactly what a maintainer cannot see: the
// picture still fills the screen, it is just wrong by a pixel.
//
// The eye a host pixel came from is not an output, so it is read back through
// the colour: the two lumas are driven to different values and the row's
// colours say which one reached the screen.
//

module vip_stereo_tb;
    // The menu, in interact.json's order.
    localparam integer ROWS = 17;
    localparam integer ROW_SBS    = 13;
    localparam integer ROW_CSCOPE = 14;
    localparam integer ROW_HLI    = 15;
    localparam integer ROW_VLI    = 16;

    // Full drive in one eye at a time reads the row's colour back directly.
    localparam logic [7:0] FULL = 8'hFF;

    // A host pixel every layout hands to the left eye: inside CyberScope's
    // left panel, left of side-by-side's seam, and on an even column and row
    // for the two interleaves.
    localparam logic [10:0] PROBE_X = 11'd100;
    localparam logic [10:0] PROBE_Y = 11'd100;

    logic clk = 1'b0;
    logic [4:0] mode = 5'd0;
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

    // Stage a host pixel and check where it lands.
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

    // Stage a host pixel, then read the colour it produces with the two eyes
    // driven to the given lumas.
    task automatic shade(input [10:0] hx, input [10:0] hy,
                         input [7:0] ll, input [7:0] lr,
                         output [23:0] got);
        begin
            @(negedge clk);
            host_x = hx;
            host_y = hy;
            @(posedge clk);
            #1;
            luma_left  = ll;
            luma_right = lr;
            #1;
            got = rgb;
        end
    endtask

    // The four single-eye layouts are red, so a pixel names its eye by which
    // luma reaches the red channel.
    task automatic expect_map(input string name,
                              input [10:0] hx, input [10:0] hy,
                              input logic want_mapped,
                              input [8:0] wx, input [7:0] wy,
                              input logic want_eye);
        logic [23:0] got, want_rgb;
        begin
            expect_pos(name, hx, hy, want_mapped, wx, wy);
            shade(hx, hy, 8'h40, 8'h80, got);
            want_rgb = !want_mapped ? 24'h000000
                     : want_eye    ? 24'h800000
                                   : 24'h400000;
            if (got !== want_rgb)
                $fatal(1, "%s (%0d,%0d): rgb %06x, expected %06x",
                       name, hx, hy, got, want_rgb);
        end
    endtask

    task automatic expect_raster(input string name, input [4:0] row,
                                 input [10:0] wha, input [10:0] wht,
                                 input [10:0] wva, input [10:0] wvt,
                                 input [2:0] wslot);
        begin
            mode = row;
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

    // v * tint / 255, the same rounding vip_stereo uses.
    function automatic logic [7:0] tinted(input [7:0] value, input [7:0] tint);
        integer scaled;
        begin
            scaled = ((value * tint) * 257 + 32768) / 65536;
            tinted = scaled[7:0];
        end
    endfunction

    // Every row's pair, from beetle-vb's Palette and preset tables.
    function automatic logic [47:0] want_colours(input integer row);
        begin
            case (row)
                0:  want_colours = {24'hFF0000, 24'h000000};
                1:  want_colours = {24'hFFFFFF, 24'h000000};
                2:  want_colours = {24'h0000FF, 24'h000000};
                3:  want_colours = {24'h00B7EB, 24'h000000};
                4:  want_colours = {24'h00FFFF, 24'h000000};
                5:  want_colours = {24'h00FF00, 24'h000000};
                6:  want_colours = {24'hFF00FF, 24'h000000};
                7:  want_colours = {24'hFFFF00, 24'h000000};
                8:  want_colours = {24'hFF0000, 24'h0000FF};
                9:  want_colours = {24'hFF0000, 24'h00B7EB};
                10: want_colours = {24'hFF0000, 24'h00FFFF};
                11: want_colours = {24'hFF0000, 24'h00FF00};
                12: want_colours = {24'hFFFF00, 24'h0000FF};
                default: want_colours = {24'hFF0000, 24'hFF0000};
            endcase
        end
    endfunction

    logic [23:0] only_left, only_right, both_eyes, got;
    logic [47:0] pair;
    logic [23:0] want_l, want_r;
    integer row, ch;

    initial begin
        repeat (2) @(posedge clk);

        // ---- the rasters, one per layout ----
        // All thirteen colour rows share the native raster and slot 0.
        expect_raster("2D (Red/Black)",     5'd0,  384, 480, 224, 512, 3'd0);
        expect_raster("2D (Yellow/Black)",  5'd7,  384, 480, 224, 512, 3'd0);
        expect_raster("Anaglyph (Red/Blue)",5'd8,  384, 480, 224, 512, 3'd0);
        expect_raster("Anaglyph (Yel/Blue)",5'd12, 384, 480, 224, 512, 3'd0);
        expect_raster("Side By Side",  ROW_SBS[4:0],    768, 1024, 224, 240, 3'd4);
        expect_raster("CyberScope",    ROW_CSCOPE[4:0], 512,  581, 384, 423, 3'd1);
        expect_raster("HLI",           ROW_HLI[4:0],    384,  480, 448, 512, 3'd3);
        expect_raster("VLI",           ROW_VLI[4:0],    768, 1024, 224, 240, 3'd2);
        // Out of range must not invent a raster.
        expect_raster("row 31",        5'd31, 384, 480, 224, 512, 3'd0);

        // ---- every row's colour pair ----
        // One eye at full drive at a time, so the pixel reads back the colour
        // that row names. This is also the check that the menu's order and
        // interact.json's agree.
        for (row = 0; row < ROWS; row = row + 1) begin
            mode = row[4:0];
            pair = want_colours(row);
            want_l = pair[47:24];
            want_r = pair[23:0];

            if (row < ROW_SBS) begin
                // Both eyes land on the same pixel here, so each eye's colour
                // is readable on its own and the pair is readable together.
                shade(PROBE_X, PROBE_Y, FULL, 8'd0, only_left);
                shade(PROBE_X, PROBE_Y, 8'd0, FULL, only_right);
                shade(PROBE_X, PROBE_Y, FULL, FULL, both_eyes);

                if (only_left !== want_l)
                    $fatal(1, "row %0d: left eye gave %06x, expected %06x",
                           row, only_left, want_l);
                if (only_right !== want_r)
                    $fatal(1, "row %0d: right eye gave %06x, expected %06x",
                           row, only_right, want_r);

                // The OR is exact only while no channel carries both eyes,
                // which is what beetle-vb tests before its slow path.
                for (ch = 0; ch < 3; ch = ch + 1) begin
                    if (only_left[8*ch +: 8] != 8'd0 &&
                        only_right[8*ch +: 8] != 8'd0)
                        $fatal(1, "row %0d channel %0d takes both eyes (%02x and %02x); the OR is wrong there",
                               row, ch, only_left[8*ch +: 8], only_right[8*ch +: 8]);
                end
                if (both_eyes !== (only_left | only_right))
                    $fatal(1, "row %0d: both eyes gave %06x, not %06x",
                           row, both_eyes, only_left | only_right);
                if (only_left === 24'd0)
                    $fatal(1, "row %0d leaves the left eye invisible", row);
            end else begin
                // A layout row gives the pixel to one eye, so the other's
                // term has to drop out even though both colours are red.
                shade(PROBE_X, PROBE_Y, FULL, 8'd0, only_left);
                shade(PROBE_X, PROBE_Y, 8'd0, FULL, only_right);
                if (only_left !== 24'hFF0000)
                    $fatal(1, "row %0d: left eye gave %06x, expected FF0000",
                           row, only_left);
                if (only_right !== 24'h000000)
                    $fatal(1, "row %0d: the right eye reached a left-eye pixel (%06x)",
                           row, only_right);
            end
        end

        // The cyan rows are the only ones whose tint is neither on nor off.
        mode = 5'd3;
        shade(PROBE_X, PROBE_Y, 8'd200, 8'd0, got);
        if (got !== {8'h00, tinted(8'd200, 8'hB7), tinted(8'd200, 8'hEB)})
            $fatal(1, "2D (Cyan/Black) at luma 200 gave %06x", got);
        if (tinted(8'd200, 8'hB7) !== 8'd144 || tinted(8'd200, 8'hEB) !== 8'd184)
            $fatal(1, "cyan tints are %0d and %0d, expected 144 and 184",
                   tinted(8'd200, 8'hB7), tinted(8'd200, 8'hEB));

        // ---- 2D and anaglyph read straight through ----
        mode = 5'd0;
        expect_pos("2D origin", 11'd0,   11'd0,   1'b1, 9'd0,   8'd0);
        expect_pos("2D corner", 11'd383, 11'd223, 1'b1, 9'd383, 8'd223);
        mode = 5'd8;
        expect_pos("anaglyph origin", 11'd0,   11'd0,   1'b1, 9'd0,   8'd0);
        expect_pos("anaglyph corner", 11'd383, 11'd223, 1'b1, 9'd383, 8'd223);

        // The right eye has to be reachable, or a duplicated eye passes every
        // check above. With the right eye alone lit, an anaglyph row shows it.
        mode = 5'd8;
        shade(11'd200, 11'd100, 8'd0, FULL, got);
        if (got !== 24'h0000FF)
            $fatal(1, "Anaglyph (Red/Blue) right eye gave %06x, expected 0000FF", got);

        // ---- CyberScope: two quarter-turned panels in a 512x384 frame ----
        mode = ROW_CSCOPE[4:0];
        expect_map("cscope left margin",  11'd15,  11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope left first",   11'd16,  11'd0,   1'b1, 9'd383, 8'd0,   1'b0);
        expect_map("cscope left bottom",  11'd16,  11'd383, 1'b1, 9'd0,   8'd0,   1'b0);
        expect_map("cscope left last",    11'd239, 11'd383, 1'b1, 9'd0,   8'd223, 1'b0);
        expect_map("cscope centre gap",   11'd240, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope gap end",      11'd271, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);
        expect_map("cscope right first",  11'd272, 11'd0,   1'b1, 9'd0,   8'd223, 1'b1);
        expect_map("cscope right last",   11'd495, 11'd383, 1'b1, 9'd383, 8'd0,   1'b1);
        expect_map("cscope right margin", 11'd496, 11'd0,   1'b0, 9'd0,   8'd0,   1'b0);

        // ---- Side by side: two pictures touching at 384 ----
        mode = ROW_SBS[4:0];
        expect_map("sbs left first",  11'd0,   11'd0,   1'b1, 9'd0,   8'd0,   1'b0);
        expect_map("sbs left last",   11'd383, 11'd0,   1'b1, 9'd383, 8'd0,   1'b0);
        expect_map("sbs right first", 11'd384, 11'd0,   1'b1, 9'd0,   8'd0,   1'b1);
        expect_map("sbs right last",  11'd767, 11'd223, 1'b1, 9'd383, 8'd223, 1'b1);

        // ---- Line interleaves: one eye per column, then per row ----
        mode = ROW_VLI[4:0];
        expect_map("vli even",   11'd0,   11'd7,   1'b1, 9'd0,   8'd7,   1'b0);
        expect_map("vli odd",    11'd1,   11'd7,   1'b1, 9'd0,   8'd7,   1'b1);
        expect_map("vli last L", 11'd766, 11'd223, 1'b1, 9'd383, 8'd223, 1'b0);
        expect_map("vli last R", 11'd767, 11'd223, 1'b1, 9'd383, 8'd223, 1'b1);

        mode = ROW_HLI[4:0];
        expect_map("hli even",   11'd10, 11'd0,   1'b1, 9'd10, 8'd0,   1'b0);
        expect_map("hli odd",    11'd10, 11'd1,   1'b1, 9'd10, 8'd0,   1'b1);
        expect_map("hli last L", 11'd10, 11'd446, 1'b1, 9'd10, 8'd223, 1'b0);
        expect_map("hli last R", 11'd10, 11'd447, 1'b1, 9'd10, 8'd223, 1'b1);

        $display("vip_stereo: PASS");
        $finish;
    end

    initial begin
        #500_000;
        $fatal(1, "timed out");
    end
endmodule

`default_nettype wire
