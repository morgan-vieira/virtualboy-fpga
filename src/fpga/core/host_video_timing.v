//
// Host raster for the Pocket's scaler.
//
// Not the Virtual Boy's display. The real machine scans a mirror on a fixed 20 ms
// schedule and never produces a raster at all; that timeline belongs to the VIP.
// This hands APF the conventional frame it wants, at the machine's frame rate.
//
// 12,288,000 Hz over 480x512 is 245,760 clocks, which is exactly 20 ms. The Sacred
// Tech Scroll gives the display frame as a fixed 20 ms / 50 Hz [VIP > Drawing and
// Display Procedures > Frame Types]; beetle-vb ships 50.27 instead (libretro.cpp,
// MEDNAFEN_CORE_TIMING_FPS). We follow the document, because it is exact at this
// pixel clock and 50.27 is not.
//
// The scaler captures exactly the width video.json declares, so a data enable
// narrower than that leaves the rest of each line as whatever the line buffer held.
//

module host_video_timing #(
    parameter H_ACTIVE = 'd384,
    parameter H_BPORCH = 'd10,
    parameter H_TOTAL  = 'd480,
    parameter V_ACTIVE = 'd224,
    parameter V_BPORCH = 'd10,
    parameter V_TOTAL  = 'd512
) (
    input  wire         clk,
    input  wire         reset_n,

    output reg          de,
    output reg          hs,
    output reg          vs,

    // Position within the active area, valid only while de is high. Registered
    // alongside de, so a source driving colour combinationally from these stays
    // aligned. A source needing a cycle to fetch a pixel would want them earlier.
    output reg  [9:0]   x,
    output reg  [9:0]   y
);

    reg [9:0] h_count;
    reg [9:0] v_count;

always @(posedge clk or negedge reset_n) begin

    if(~reset_n) begin

        h_count <= 0;
        v_count <= 0;
        de <= 0;
        hs <= 0;
        vs <= 0;
        x <= 0;
        y <= 0;

    end else begin
        hs <= 0;
        vs <= 0;

        if(h_count == H_TOTAL-1) begin
            h_count <= 0;

            if(v_count == V_TOTAL-1) begin
                v_count <= 0;
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

        de <= (h_count >= H_BPORCH) && (h_count < H_BPORCH+H_ACTIVE) &&
              (v_count >= V_BPORCH) && (v_count < V_BPORCH+V_ACTIVE);

        x <= h_count - H_BPORCH;
        y <= v_count - V_BPORCH;
    end
end

endmodule
