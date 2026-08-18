`default_nettype none

// Lays the VIP's two eyes out on the host's frame.
//
// The Virtual Boy draws one image per eye and shows them to one eye each.
// A Pocket has one screen, so something has to decide what a host pixel is:
// one eye, the other, both mixed, or nothing. beetle-vb already answered
// that six ways and RetroArch users know the answers by name, so we take its
// modes rather than invent our own [mednafen/vb/vip.c, VIP_StartFrame for
// the geometry and the CopyFBColumnToTarget_* family for the mapping].
//
// Two of the seven are not beetle-vb's: 2D (left eye) is what this core
// showed before there were modes, and 2D (right eye) is its other half.
// Most Pocket users have one screen and no glasses, so those are the
// default and its neighbour.
//
// This module owns everything mode-shaped: the raster each mode needs, the
// scaler slot that describes it to APF, which eye a host pixel comes from,
// and the colour. Add a mode here and nothing else has to learn about it.
//
// Timing: vb_x/vb_y are combinational, for the frame buffers to read this
// cycle. luma_left/luma_right come back one cycle later, so the eye choice
// is registered to meet them and rgb is aligned with the lumas.

module vip_stereo (
    input  logic        clk,

    // Hold still for a whole frame: the raster below is derived from them.
    input  logic [2:0]  mode,
    input  logic [2:0]  preset,
    input  logic [1:0]  separation,

    // The raster this mode wants, and the video.json slot that describes it.
    output logic [10:0] h_active,
    output logic [10:0] v_active,
    output logic [10:0] h_total,
    output logic [10:0] v_total,
    output logic [2:0]  scaler_slot,

    input  logic [10:0] host_x,
    input  logic [10:0] host_y,

    output logic [8:0]  vb_x,
    output logic [7:0]  vb_y,
    // Low where a host pixel belongs to neither eye: the side-by-side gap
    // and the margins Cyberscope's two panels leave.
    output logic        mapped,

    input  logic [7:0]  luma_left,
    input  logic [7:0]  luma_right,

    output logic [23:0] rgb
);

    localparam logic [2:0] MODE_2D_LEFT  = 3'd0;
    localparam logic [2:0] MODE_2D_RIGHT = 3'd1;
    localparam logic [2:0] MODE_ANAGLYPH = 3'd2;
    localparam logic [2:0] MODE_CSCOPE   = 3'd3;
    localparam logic [2:0] MODE_SBS      = 3'd4;
    localparam logic [2:0] MODE_VLI      = 3'd5;
    localparam logic [2:0] MODE_HLI      = 3'd6;

    localparam logic [10:0] EYE_W = 11'd384;
    localparam logic [10:0] EYE_H = 11'd224;

    // Cyberscope quarter-turns both eyes into a 512x384 frame; beetle-vb
    // puts the left panel at columns 16..239 and the right at 272..495.
    localparam logic [10:0] CS_LEFT  = 11'd16;
    localparam logic [10:0] CS_RIGHT = 11'd272;

    logic [10:0] sep_px;

    always_comb begin
        // Four separations, one scaler slot each, so video.json can declare
        // the 768 + separation width beetle-vb's geometry asks for.
        unique case (separation)
            2'd0: sep_px = 11'd0;
            2'd1: sep_px = 11'd16;
            2'd2: sep_px = 11'd32;
            2'd3: sep_px = 11'd64;
        endcase
    end

    // 12.288 MHz over 245,760 clocks is exactly 20 ms, the machine's frame
    // [host_video_timing]. Every raster below holds that product, so the
    // display buffer's swap point stays where it is instead of crawling --
    // except Cyberscope's, and that one says why.
    always_comb begin
        h_active    = EYE_W;
        v_active    = EYE_H;
        h_total     = 11'd480;
        v_total     = 11'd512;
        scaler_slot = 3'd0;

        case (mode)
            MODE_CSCOPE: begin
                h_active = 11'd512;
                v_active = 11'd384;
                // 581 x 423 is 245,763: three clocks long, and the closest
                // this gets. 245,760 has no factor pair that leaves room
                // for a 512x384 active area with porches, so the swap point
                // drifts a frame every ~27 minutes in this mode alone.
                h_total  = 11'd581;
                v_total  = 11'd423;
                scaler_slot = 3'd1;
            end
            MODE_SBS: begin
                h_active = EYE_W + sep_px + EYE_W;
                h_total  = 11'd1024;
                v_total  = 11'd240;
                scaler_slot = 3'd4 + {1'b0, separation};
            end
            MODE_VLI: begin
                h_active = EYE_W + EYE_W;
                h_total  = 11'd1024;
                v_total  = 11'd240;
                scaler_slot = 3'd2;
            end
            MODE_HLI: begin
                v_active = EYE_H + EYE_H;
                scaler_slot = 3'd3;
            end
            default: begin end   // the 384x224 modes keep the defaults
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

        case (mode)
            MODE_2D_RIGHT: eye = 1'b1;

            // Both panels are quarter-turned, so a host row is a VIP column
            // and a host column is a VIP row -- opposite ways round, which
            // is what the accessory's mirrors undo.
            MODE_CSCOPE: begin
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

            MODE_SBS: begin
                if (host_x < EYE_W) begin
                    eye  = 1'b0;
                    vb_x = host_x[8:0];
                end else if (host_x >= EYE_W + sep_px &&
                             host_x <  EYE_W + sep_px + EYE_W) begin
                    eye    = 1'b1;
                    offset = host_x - EYE_W - sep_px;
                    vb_x   = offset[8:0];
                end else begin
                    mapped = 1'b0;
                    vb_x   = 9'd0;
                end
            end

            MODE_VLI: begin
                eye  = host_x[0];
                vb_x = host_x[9:1];
            end

            MODE_HLI: begin
                eye  = host_y[0];
                vb_y = host_y[8:1];
            end

            default: begin end   // 2D (left eye) and anaglyph read straight through
        endcase
    end

    logic eye_q, mapped_q;

    always_ff @(posedge clk) begin
        eye_q    <= eye;
        mapped_q <= mapped;
    end

    // Anaglyph mixes both eyes into one pixel. beetle-vb tints each eye's
    // encoded luma by its preset colour and ORs the two, and falls back to
    // summing linear light only when a channel carries both eyes
    // [Recalc3DModeStuff]. None of the six presets does -- every one splits
    // the three channels between the eyes -- so the OR is exact and the slow
    // path has no input here. It would gain one if custom colours were ever
    // offered, which is the condition to re-read before adding them.
    //
    // beetle-vb's AnaglyphPreset_Colors [libretro.cpp].
    logic [23:0] colour_l, colour_r;

    always_comb begin
        case (preset)
            3'd0: begin colour_l = 24'hFF0000; colour_r = 24'h0000FF; end
            3'd1: begin colour_l = 24'hFF0000; colour_r = 24'h00B7EB; end
            3'd2: begin colour_l = 24'hFF0000; colour_r = 24'h00FFFF; end
            3'd3: begin colour_l = 24'hFF0000; colour_r = 24'h00FF00; end
            3'd4: begin colour_l = 24'h00FF00; colour_r = 24'hFF00FF; end
            default: begin colour_l = 24'hFFFF00; colour_r = 24'h0000FF; end
        endcase
    end

    // A preset tints each eye by multiplying its encoded luma, which is
    // what beetle-vb does. 257/65536 is 1/255 to seven digits.
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

    logic [7:0] mono;

    always_comb begin
        mono = eye_q ? luma_right : luma_left;

        if (!mapped_q)
            rgb = 24'h000000;
        else if (mode == MODE_ANAGLYPH)
            rgb = {channel(colour_l[23:16], colour_r[23:16], luma_left, luma_right),
                   channel(colour_l[15:8],  colour_r[15:8],  luma_left, luma_right),
                   channel(colour_l[7:0],   colour_r[7:0],   luma_left, luma_right)};
        else
            // Every other mode keeps the machine's red.
            rgb = {mono, 16'h0000};
    end

endmodule

`default_nettype wire
