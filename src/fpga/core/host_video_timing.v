//
// Host raster for the Pocket's scaler.
//
// Not the Virtual Boy's display. The real machine scans a mirror on a fixed 20 ms
// schedule and never produces a raster at all; that timeline belongs to the VIP.
// This hands APF the conventional frame it wants, at the machine's frame rate.
//
// 12,288,000 Hz over 245,760 clocks is exactly 20 ms. The Sacred Tech Scroll gives
// the display frame as a fixed 20 ms / 50 Hz [VIP > Drawing and Display Procedures
// > Frame Types]; beetle-vb ships 50.27 instead (libretro.cpp,
// MEDNAFEN_CORE_TIMING_FPS). We follow the document, because it is exact at this
// pixel clock and 50.27 is not.
//
// The active area is not fixed, because the stereo modes are not the same shape:
// 384x224 for the 2D pair and anaglyph, 768x224 and 384x448 for the interleaves,
// 512x384 for Cyberscope, up to 832x224 side by side. vip_stereo owns which, and
// picks each raster's totals to keep that 245,760-clock product where it can.
//
// The geometry is sampled once per frame, at the top of the blanking that
// precedes it, so a mode changed mid-picture takes effect on a frame boundary
// instead of tearing the raster it is in.
//
// The scaler captures exactly the width video.json declares, so a data enable
// narrower than that leaves the rest of each line as whatever the line buffer held.
//

module host_video_timing #(
    parameter H_BPORCH = 'd10,
    parameter V_BPORCH = 'd10
) (
    input  wire         clk,
    input  wire         reset_n,

    input  wire [10:0]  h_active,
    input  wire [10:0]  h_total,
    input  wire [10:0]  v_active,
    input  wire [10:0]  v_total,

    output reg          de,
    output reg          hs,
    output reg          vs,

    // Position within the active area, valid only while de is high. Registered
    // alongside de, so a source driving colour combinationally from these stays
    // aligned. A source needing a cycle to fetch a pixel would want them earlier.
    output reg  [10:0]  x,
    output reg  [10:0]  y
);

    reg [10:0] h_count;
    reg [10:0] v_count;

    // The frame in flight, so a change to the inputs cannot move a boundary
    // the counters have already passed.
    reg [10:0] h_active_q, h_total_q, v_active_q, v_total_q;

always @(posedge clk or negedge reset_n) begin

    if(~reset_n) begin

        h_count <= 0;
        v_count <= 0;
        de <= 0;
        hs <= 0;
        vs <= 0;
        x <= 0;
        y <= 0;
        h_active_q <= h_active;
        h_total_q <= h_total;
        v_active_q <= v_active;
        v_total_q <= v_total;

    end else begin
        hs <= 0;
        vs <= 0;

        if(h_count >= h_total_q-1) begin
            h_count <= 0;

            if(v_count >= v_total_q-1) begin
                v_count <= 0;
                h_active_q <= h_active;
                h_total_q <= h_total;
                v_active_q <= v_active;
                v_total_q <= v_total;
            end else begin
                v_count <= v_count + 1'b1;
            end
        end else begin
            h_count <= h_count + 1'b1;
        end

        // both sync pulses sit in the back porch, hs a few clocks after vs so they
        // never land on the same edge
        if(h_count == 0 && v_count == 0) begin
            vs <= 1;
        end
        if(h_count == 3) begin
            hs <= 1;
        end

        de <= (h_count >= H_BPORCH) && (h_count < H_BPORCH+h_active_q) &&
              (v_count >= V_BPORCH) && (v_count < V_BPORCH+v_active_q);

        x <= h_count - H_BPORCH;
        y <= v_count - V_BPORCH;
    end
end

endmodule
