`default_nettype none

// Lays the VIP's two eyes out on the host's frame.
//
// The Virtual Boy draws one image per eye and shows them to one eye each.
// A Pocket has one screen, so something has to decide what a host pixel is:
// one eye, the other, both mixed, or nothing. beetle-vb already answered
// that and RetroArch users know the answers by name, so we take its modes
// rather than invent our own [mednafen/vb/vip.c, VIP_StartFrame for the
// geometry and the CopyFBColumnToTarget_* family for the mapping].
//
// Everything here is one shape: a colour for each eye, and a layout that
// decides which eye a host pixel comes from. beetle-vb reaches the same
// pair through three settings that fold together at libretro.cpp:436 --
// its Palette sets a left colour with the right one black, an anaglyph
// preset overrides both when it is not "disabled", and the four non-anaglyph
// modes take the Palette's colour for both eyes. 2D is not a mode there and
// is not one here: it is the pair whose right colour is black.
//
// So the menu is one flat list, and eight of its rows differ only in a
// colour. That is Morgan's call, 2026-08-18, and it costs one thing worth
// naming: the four layout rows carry no colour of their own, so they are
// red. beetle-vb lets its Palette reach them because it keeps the two
// settings apart.
//
// This module owns everything mode-shaped: the colours, the raster each
// layout needs, the scaler slot that describes it to APF, and which eye a
// host pixel comes from. Add a row here and nothing else has to learn
// about it -- except video.json, if the row needs a raster the file does
// not already declare.
//
// Timing: vb_x/vb_y are combinational, for the frame buffers to read this
// cycle. luma_left/luma_right come back one cycle later, so the eye choice
// is registered to meet them and rgb is aligned with the lumas.

module vip_stereo (
    input  logic        clk,

    // Holds still for a whole frame: the raster below is derived from it.
    input  logic [4:0]  mode,

    // The raster this layout wants, and the video.json slot that describes it.
    output logic [10:0] h_active,
    output logic [10:0] v_active,
    output logic [10:0] h_total,
    output logic [10:0] v_total,
    output logic [2:0]  scaler_slot,

    input  logic [10:0] host_x,
    input  logic [10:0] host_y,

    output logic [8:0]  vb_x,
    output logic [7:0]  vb_y,
    // Low where a host pixel belongs to neither eye, which is only the
    // margins CyberScope's two quarter-turned panels leave.
    output logic        mapped,

    input  logic [7:0]  luma_left,
    input  logic [7:0]  luma_right,

    output logic [23:0] rgb
);

    // beetle-vb's Palette values [libretro.cpp, vb_color_mode] and its
    // AnaglyphPreset_Colors table.
    localparam logic [23:0] C_BLACK   = 24'h000000;
    localparam logic [23:0] C_RED     = 24'hFF0000;
    localparam logic [23:0] C_WHITE   = 24'hFFFFFF;
    localparam logic [23:0] C_BLUE    = 24'h0000FF;
    localparam logic [23:0] C_CYAN    = 24'h00B7EB;
    localparam logic [23:0] C_ELCYAN  = 24'h00FFFF;
    localparam logic [23:0] C_GREEN   = 24'h00FF00;
    localparam logic [23:0] C_MAGENTA = 24'hFF00FF;
    localparam logic [23:0] C_YELLOW  = 24'hFFFF00;

    localparam logic [2:0] LAYOUT_BOTH   = 3'd0;  // both eyes on one pixel
    localparam logic [2:0] LAYOUT_SBS    = 3'd1;
    localparam logic [2:0] LAYOUT_CSCOPE = 3'd2;
    localparam logic [2:0] LAYOUT_HLI    = 3'd3;
    localparam logic [2:0] LAYOUT_VLI    = 3'd4;

    localparam logic [10:0] EYE_W = 11'd384;
    localparam logic [10:0] EYE_H = 11'd224;

    // CyberScope quarter-turns both eyes into a 512x384 frame; beetle-vb
    // puts the left panel at columns 16..239 and the right at 272..495.
    localparam logic [10:0] CS_LEFT  = 11'd16;
    localparam logic [10:0] CS_RIGHT = 11'd272;

    logic [2:0]  layout;
    logic [23:0] colour_l, colour_r;

    // The menu, in order. interact.json's Stereo Mode list is this table.
    always_comb begin
        layout   = LAYOUT_BOTH;
        colour_l = C_RED;
        colour_r = C_BLACK;

        case (mode)
            5'd0:  begin colour_l = C_RED;     end
            5'd1:  begin colour_l = C_WHITE;   end
            5'd2:  begin colour_l = C_BLUE;    end
            5'd3:  begin colour_l = C_CYAN;    end
            5'd4:  begin colour_l = C_ELCYAN;  end
            5'd5:  begin colour_l = C_GREEN;   end
            5'd6:  begin colour_l = C_MAGENTA; end
            5'd7:  begin colour_l = C_YELLOW;  end

            5'd8:  begin colour_l = C_RED;    colour_r = C_BLUE;   end
            5'd9:  begin colour_l = C_RED;    colour_r = C_CYAN;   end
            5'd10: begin colour_l = C_RED;    colour_r = C_ELCYAN; end
            5'd11: begin colour_l = C_RED;    colour_r = C_GREEN;  end
            5'd12: begin colour_l = C_YELLOW; colour_r = C_BLUE;   end

            5'd13: begin layout = LAYOUT_SBS;    colour_r = C_RED; end
            5'd14: begin layout = LAYOUT_CSCOPE; colour_r = C_RED; end
            5'd15: begin layout = LAYOUT_HLI;    colour_r = C_RED; end
            5'd16: begin layout = LAYOUT_VLI;    colour_r = C_RED; end

            default: begin end   // out of range reads as the first row
        endcase
    end

    // 12.288 MHz over 245,760 clocks is exactly 20 ms, the machine's frame
    // [host_video_timing]. Every raster below holds that product, so the
    // display buffer's swap point stays where it is instead of crawling --
    // except CyberScope's, and that one says why.
    always_comb begin
        h_active    = EYE_W;
        v_active    = EYE_H;
        h_total     = 11'd480;
        v_total     = 11'd512;
        scaler_slot = 3'd0;

        case (layout)
            LAYOUT_CSCOPE: begin
                h_active = 11'd512;
                v_active = 11'd384;
                // 581 x 423 is 245,763: three clocks long, and the closest
                // this gets. 245,760 has no factor pair that leaves room
                // for a 512x384 active area with porches, so the swap point
                // drifts a frame every ~27 minutes in this layout alone.
                h_total  = 11'd581;
                v_total  = 11'd423;
                scaler_slot = 3'd1;
            end
            LAYOUT_VLI: begin
                h_active = EYE_W + EYE_W;
                h_total  = 11'd1024;
                v_total  = 11'd240;
                scaler_slot = 3'd2;
            end
            LAYOUT_HLI: begin
                v_active = EYE_H + EYE_H;
                scaler_slot = 3'd3;
            end
            LAYOUT_SBS: begin
                // Same pixels as VLI, a different picture: its slot declares
                // 24:7 where VLI's declares 12:7.
                h_active = EYE_W + EYE_W;
                h_total  = 11'd1024;
                v_total  = 11'd240;
                scaler_slot = 3'd4;
            end
            default: begin end   // both eyes on one pixel, at native size
        endcase
    end

    logic        eye;
    logic [10:0] offset;

    always_comb begin
        eye    = 1'b0;
        mapped = 1'b1;
        vb_x   = host_x[8:0];
        vb_y   = host_y[7:0];
        offset = 11'd0;

        case (layout)
            // Both panels are quarter-turned, so a host row is a VIP column
            // and a host column is a VIP row -- opposite ways round, which
            // is what the accessory's mirrors undo.
            LAYOUT_CSCOPE: begin
                if (host_x >= CS_LEFT && host_x < CS_LEFT + EYE_H) begin
                    eye    = 1'b0;
                    offset = host_x - CS_LEFT;
                    vb_y   = offset[7:0];
                    offset = 11'd383 - host_y;
                    vb_x   = offset[8:0];
                end else if (host_x >= CS_RIGHT && host_x < CS_RIGHT + EYE_H) begin
                    eye    = 1'b1;
                    offset = CS_RIGHT + EYE_H - 11'd1 - host_x;
                    vb_y   = offset[7:0];
                    vb_x   = host_y[8:0];
                end else begin
                    mapped = 1'b0;
                    vb_x   = 9'd0;
                    vb_y   = 8'd0;
                end
            end

            LAYOUT_SBS: begin
                eye    = host_x >= EYE_W;
                offset = host_x >= EYE_W ? host_x - EYE_W : host_x;
                vb_x   = offset[8:0];
            end

            LAYOUT_VLI: begin
                eye  = host_x[0];
                vb_x = host_x[9:1];
            end

            LAYOUT_HLI: begin
                eye  = host_y[0];
                vb_y = host_y[8:1];
            end

            default: begin end   // both eyes read the same pixel straight through
        endcase
    end

    logic eye_q, mapped_q;

    always_ff @(posedge clk) begin
        eye_q    <= eye;
        mapped_q <= mapped;
    end

    // One expression for every row. Where a layout gives a host pixel to one
    // eye, the other eye's luma is zeroed and its term drops out; where both
    // eyes share the pixel, the two terms are ORed.
    //
    // That OR is beetle-vb's fast anaglyph path. It is exact only while no
    // channel carries both eyes, which is the condition beetle-vb itself
    // tests before falling back to summing linear light [Recalc3DModeStuff].
    // No row that shares a pixel shares a channel -- the 2D rows have a black
    // right eye, and each anaglyph pair splits the three channels -- so the
    // slow path has no input here. The four layout rows do put red in both
    // colours, and that is safe precisely because they never share a pixel.
    // src/tests/vip_stereo.v checks both halves of that over every row.
    logic [7:0] eff_left, eff_right;

    always_comb begin
        eff_left  = (layout == LAYOUT_BOTH || !eye_q) ? luma_left  : 8'd0;
        eff_right = (layout == LAYOUT_BOTH ||  eye_q) ? luma_right : 8'd0;
    end

    // A colour tints an eye by multiplying its encoded luma, which is what
    // beetle-vb does. 257/65536 is 1/255 to seven digits.
    function automatic logic [7:0] modulate(input logic [7:0] value,
                                            input logic [7:0] tint);
        logic [15:0] product;
        logic [23:0] scaled;
        begin
            product  = {8'd0, value} * {8'd0, tint};
            scaled   = {8'd0, product} * 24'd257 + 24'd32768;
            modulate = scaled[23:16];
        end
    endfunction

    function automatic logic [7:0] channel(input logic [7:0] tint_l,
                                           input logic [7:0] tint_r,
                                           input logic [7:0] left,
                                           input logic [7:0] right);
        begin
            channel = modulate(left, tint_l) | modulate(right, tint_r);
        end
    endfunction

    always_comb begin
        if (!mapped_q)
            rgb = 24'h000000;
        else
            rgb = {channel(colour_l[23:16], colour_r[23:16], eff_left, eff_right),
                   channel(colour_l[15:8],  colour_r[15:8],  eff_left, eff_right),
                   channel(colour_l[7:0],   colour_r[7:0],   eff_left, eff_right)};
    end

endmodule

`default_nettype wire
