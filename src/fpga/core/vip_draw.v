`default_nettype none

// VIP world renderer. Eight horizontal rows are composed in parallel banks,
// then transposed into the hardware's column-major framebuffer layout.
//
// Normal and h-bias worlds blend one character row — eight pixels — per
// line-bank write, which is what keeps a full-width world inside the frame
// the way the silicon manages it. Affine worlds and objects walk per pixel,
// matching MiSTer's measured per-pixel affine cost.
//
// Scheduling follows MiSTer's measured coordinator (vip_render_storage.sv,
// an implementation choice): 32 ce of setup, then a per-strip service budget
// of 2033 ce (strip 0) or 1949 ce that pauses while a world is processed,
// 11 ce for an END world, 21/20 ce for a dummy world, and a 24 ce recovery
// window after XPRST during which XPBSY stays up. The budgets alone total
// 54,688 cycles, the scroll's ~2.8 ms erase-only frame. Active worlds run at
// engine speed rather than MiSTer's measured per-tile figures; CAVEATS.md
// records that deviation. SBOUT holds for the documented 56 us (1,120 ce).

module vip_draw (
    input  logic        clk,
    input  logic        reset_n,
    input  logic        ce,
    input  logic        start,
    input  logic        reset_draw,
    input  logic        target_buffer,
    input  logic [39:0] spt,
    input  logic [31:0] gplt,
    input  logic [31:0] jplt,
    input  logic [1:0]  bkcol,
    output logic        busy,
    output logic        done,
    output logic        strip_begin,
    output logic [4:0]  strip_number,
    output logic        first_group_done,
    output logic        sbout,

    output logic        mem_req,
    output logic [18:1] mem_addr,
    output logic        mem_we,
    output logic [1:0]  mem_be,
    output logic [15:0] mem_wdata,
    input  logic [15:0] mem_rdata,
    input  logic        mem_ready
);

    logic [15:0] line_l_q [0:7];
    logic [15:0] line_r_q [0:7];
    logic [15:0] world [0:10];

    typedef enum logic [5:0] {
        IDLE, SETUP, CLEAR, HEAD_REQ, HEAD_WAIT, WORLD_DELAY,
        WORLD_REQ, WORLD_WAIT, OVERPLANE_REQ, OVERPLANE_WAIT, WORLD_CHECKED,
        ROW_PREP, HBIAS_REQ, HBIAS_WAIT, HBIAS_RIGHT_REQ, HBIAS_RIGHT_WAIT,
        ROW_START, WORD_SETUP, WCELL_REQ, WCELL_WAIT, WCHAR_REQ, WCHAR_WAIT,
        W_PRIME, W_BLEND,
        AFFINE_PARAM_REQ, AFFINE_PARAM_WAIT, AFFINE_EYE_PREP, PIXEL_PREP,
        MAP_REQ, MAP_WAIT, CHAR_REQ, CHAR_WAIT, PIXEL_DRAW,
        OBJECT_PREP, OBJECT_REQ, OBJECT_WAIT, OBJECT_CHECK,
        OBJECT_PIXEL_PREP, OBJECT_CHAR_REQ, OBJECT_CHAR_WAIT,
        OBJECT_PIXEL_DRAW, OBJECT_NEXT, LINE_READ, LINE_WAIT, LINE_WRITE,
        NEXT_WORLD, WRITE_PREP, WRITE_PACK_WAIT, WRITE_LEFT,
        WRITE_LEFT_WAIT, WRITE_RIGHT, WRITE_RIGHT_WAIT, STRIP_PAD,
        NEXT_STRIP, RECOVERY, FINISH
    } state_t;
    state_t state;

    // Measured budgets, in 20 MHz ce ticks [MiSTer vip_render_storage.sv].
    localparam logic [15:0] SETUP_CE       = 16'd32;
    localparam logic [15:0] FIRST_STRIP_CE = 16'd2033;
    localparam logic [15:0] LATER_STRIP_CE = 16'd1949;
    localparam logic [5:0]  END_CE         = 6'd11;
    localparam logic [5:0]  DUMMY_FIRST_CE = 6'd21;
    localparam logic [5:0]  DUMMY_CE       = 6'd20;
    localparam logic [15:0] SBOUT_CE       = 16'd1120;
    localparam logic [7:0]  RECOVERY_CE    = 8'd24;

    logic [15:0] service_ce;
    logic [5:0]  world_elapsed, world_target;
    logic [7:0]  recovery_ce;
    logic [15:0] sbout_ce;
    logic        head_end;

    logic [5:0] clear_chunk;
    logic [5:0] world_index;
    logic [3:0] world_word;
    logic [2:0] row;
    logic eye;
    logic signed [16:0] pixel_x;
    logic signed [16:0] x_start, x_end;
    logic signed [16:0] source_x, source_y;
    logic signed [16:0] bias;
    logic [18:1] map_address;
    logic [15:0] hbias_index;
    logic [15:0] map_cell;
    logic [15:0] overplane_cell;
    // Per-pixel caches for the affine walk, whose consecutive pixels
    // usually share a cell and a character row.
    logic [18:1] cached_map_address;
    logic [15:0] cached_map_cell;
    logic map_cache_valid;
    logic [18:1] cached_char_address;
    logic [15:0] cached_char_pixels;
    logic char_cache_valid;
    logic [18:1] char_address;
    logic [18:1] object_char_address;
    logic [15:0] char_pixels;
    logic [8:0] write_x;
    logic [9:0] object_index, object_start;
    logic [1:0] object_group;
    logic [1:0] object_word;
    logic [15:0] object [0:3];
    logic [15:0] affine [0:4];
    logic [2:0] affine_word;
    logic [15:0] affine_base;
    logic [3:0] object_pixel;
    logic signed [16:0] object_screen_x;
    logic [7:0] object_row_delta;
    logic [1:0] object_raw_pixel, object_color_pixel;
    logic [2:0] object_char_column;
    logic [5:0] line_address;
    logic [2:0] line_row;
    logic [15:0] line_pattern, line_mask;
    logic line_eye;
    logic line_object;

    // Word-at-a-time background composition.
    logic signed [16:0] src_delta;
    logic [5:0] word_x, word_last;
    logic [15:0] cellA, cellB;
    logic [15:0] charA, charB;
    logic a_valid, b_valid;
    logic phase_b;

    logic [15:0] packed_left, packed_right;
    logic signed [16:0] screen_y;
    integer i;

    function automatic signed [16:0] sx10(input logic [9:0] value);
        sx10 = {{7{value[9]}}, value};
    endfunction

    function automatic signed [16:0] sx13(input logic [12:0] value);
        sx13 = {{4{value[12]}}, value};
    endfunction

    function automatic [1:0] palette_pixel(
        input logic [31:0] palettes,
        input logic [1:0] palette,
        input logic [1:0] pixel
    );
        logic [5:0] shift;
        begin
            shift = {palette, 3'b000} + {pixel, 1'b0};
            palette_pixel = 2'(palettes >> shift);
        end
    endfunction

    always_comb begin
        screen_y = $signed({9'd0, strip_number, 3'b000}) + $signed({14'd0, row});
        packed_left = 16'd0;
        packed_right = 16'd0;
        for (i = 0; i < 8; i = i + 1) begin
            packed_left[i*2 +: 2] = 2'(line_l_q[i] >> {write_x[2:0], 1'b0});
            packed_right[i*2 +: 2] = 2'(line_r_q[i] >> {write_x[2:0], 1'b0});
        end
    end

    // The blended character row for the current destination word.
    logic signed [16:0] word_s0;
    logic [2:0] word_k;
    logic signed [16:0] x_lo, x_hi;
    logic [15:0] word_pattern, word_mask;
    always_comb begin
        word_s0 = $signed({11'd0, word_x, 3'b000}) + src_delta;
        word_k = word_s0[2:0];
        x_lo = x_start < 0 ? 17'sd0 : x_start;
        x_hi = x_end > 383 ? 17'sd383 : x_end;
        word_pattern = 16'd0;
        word_mask = 16'd0;
        for (i = 0; i < 8; i = i + 1) begin
            logic [3:0] sp;
            logic [15:0] cell_i, char_i;
            logic [2:0] col;
            logic [1:0] raw_i;
            logic signed [16:0] dest_x;
            sp = {1'b0, word_k} + i[3:0];
            cell_i = sp[3] ? cellB : cellA;
            char_i = sp[3] ? charB : charA;
            col = cell_i[13] ? ~sp[2:0] : sp[2:0];
            raw_i = 2'(char_i >> {col, 1'b0});
            dest_x = $signed({11'd0, word_x, 3'b000}) + i;
            word_pattern[i*2 +: 2] = palette_pixel(gplt, cell_i[15:14], raw_i);
            if (raw_i != 2'd0 && dest_x >= x_lo && dest_x <= x_hi)
                word_mask[i*2 +: 2] = 2'b11;
        end
    end

    genvar bank;
    generate
        for (bank = 0; bank < 8; bank = bank + 1) begin : line_banks
            wire [15:0] blend_mask = state == W_BLEND ? word_mask : line_mask;
            wire [15:0] blend_pattern = state == W_BLEND ? word_pattern : line_pattern;
            wire blend_row_hit = state == W_BLEND ? row == bank[2:0]
                                                 : line_row == bank[2:0];
            wire blend_eye = state == W_BLEND ? eye : line_eye;
            wire writing = (state == W_BLEND || state == LINE_WRITE) &&
                           blend_row_hit;
            wire [5:0] write_address = state == CLEAR ? clear_chunk : line_address;
            wire [15:0] left_blend =
                (line_l_q[bank] & ~blend_mask) | (blend_pattern & blend_mask);
            wire [15:0] right_blend =
                (line_r_q[bank] & ~blend_mask) | (blend_pattern & blend_mask);
            wire [15:0] left_data = state == CLEAR ? {8{bkcol}} : left_blend;
            wire [15:0] right_data = state == CLEAR ? {8{bkcol}} : right_blend;

            vip_line_bank left (
                .clk(clk), .read_addr(line_address), .read_data(line_l_q[bank]),
                .write_enable(state == CLEAR || (writing && !blend_eye)),
                .write_addr(write_address), .write_data(left_data)
            );
            vip_line_bank right (
                .clk(clk), .read_addr(line_address), .read_data(line_r_q[bank]),
                .write_enable(state == CLEAR || (writing && blend_eye)),
                .write_addr(write_address), .write_data(right_data)
            );
        end
    endgenerate

    always_comb begin
        mem_req = 1'b0;
        mem_addr = 18'd0;
        mem_we = 1'b0;
        mem_be = 2'b11;
        mem_wdata = 16'd0;
        unique case (state)
            HEAD_REQ: begin
                mem_req = 1'b1;
                mem_addr = 18'h1EC00 + {world_index[4:0], 4'b0000};
            end
            WORLD_REQ: begin
                mem_req = 1'b1;
                mem_addr = 18'h1EC00 + {world_index[4:0], 4'b0000} + world_word;
            end
            OVERPLANE_REQ: begin
                // Overplane Character names a DRAM cell, not the cell itself
                // [beetle-vb vip_draw.inc; MiSTer vip_xp_bg_address].
                mem_req = 1'b1;
                mem_addr = {2'b01, world[10]};
            end
            MAP_REQ: begin
                // A request nobody consumes parks pocket_sram in RELEASE.
                mem_req = !map_skip && !(map_cache_valid &&
                                         map_address == cached_map_address);
                mem_addr = map_address;
            end
            WCELL_REQ: begin
                mem_req = !map_skip;
                mem_addr = map_address;
            end
            CHAR_REQ: begin
                mem_req = !(char_cache_valid &&
                            char_address == cached_char_address);
                mem_addr = char_address;
            end
            HBIAS_REQ, HBIAS_RIGHT_REQ, AFFINE_PARAM_REQ, OBJECT_REQ,
            OBJECT_CHAR_REQ, WCHAR_REQ: begin
                mem_req = 1'b1;
                mem_addr = state == WCHAR_REQ ? char_address :
                           state == OBJECT_CHAR_REQ ? object_char_address :
                           state == HBIAS_REQ ? {2'b01, hbias_index} :
                           // The right offset's address is the left's OR 2, so
                           // an odd Param Base serves HOFSTL to both eyes
                           // [scroll, H-Bias Worlds; MiSTer hbias streamer].
                           state == HBIAS_RIGHT_REQ ? {2'b01, hbias_index | 16'h0001} :
                           // Affine fields read at element base OR index
                           // [scroll, Affine Worlds; MiSTer param streamer].
                           state == AFFINE_PARAM_REQ ?
                               {2'b01, affine_base | {13'd0, affine_word}} :
                           18'h1F000 + {object_index, 2'b00} + object_word;
            end
            WRITE_LEFT: begin
                mem_req = 1'b1;
                mem_we = 1'b1;
                mem_addr = (target_buffer ? 18'h04000 : 18'h00000) +
                           {write_x, 5'b00000} + strip_number;
                mem_wdata = packed_left;
            end
            WRITE_RIGHT: begin
                mem_req = 1'b1;
                mem_we = 1'b1;
                mem_addr = (target_buffer ? 18'h0C000 : 18'h08000) +
                           {write_x, 5'b00000} + strip_number;
                mem_wdata = packed_right;
            end
            default: begin end
        endcase
    end

    logic [1:0] raw_pixel;
    logic [1:0] color_pixel;
    logic [2:0] char_column;
    always_comb begin
        char_column = source_x[2:0];
        if (map_cell[13]) char_column = 3'd7 - char_column;
        raw_pixel = 2'(char_pixels >> {char_column, 1'b0});
        color_pixel = palette_pixel(gplt, map_cell[15:14], raw_pixel);
        object_row_delta = screen_y[7:0] - object[2][7:0];
        object_char_column = object[3][13] ? 3'd7 - object_pixel[2:0] :
                                                    object_pixel[2:0];
        object_raw_pixel = 2'(char_pixels >> {object_char_column, 1'b0});
        object_color_pixel = palette_pixel(jplt, object[3][15:14], object_raw_pixel);
    end

    // World halfword 0: LON 15, RON 14, BGM 13:12, SCX 11:10, SCY 9:8,
    // OVER 7, END 6, Base 3:0 [scroll, World Attributes].
    logic [1:0] scx, scy;
    logic [3:0] maps_wide, effective_columns, effective_count;
    logic [3:0] map_base;
    integer bg_width, bg_height;
    integer wrapped_x, wrapped_y, map_x, map_y, map_number;
    logic outside;
    logic map_skip;
    logic signed [16:0] visual_height;
    logic signed [16:0] local_row;
    logic row_visible;
    logic signed [17:0] affine_column;
    logic signed [31:0] affine_x_calc, affine_y_calc;
    always_comb begin
        scx = world[0][11:10];
        scy = world[0][9:8];
        maps_wide = 4'd1 << scx;
        bg_width = 512 << scx;
        bg_height = 512 << scy;
        // More than eight maps become the tallest 8-map background of the
        // given height, repeated horizontally [scroll, Backgrounds].
        if ({1'b0, scx} + {1'b0, scy} > 3'd3)
            effective_columns = 4'd8 >> scy;
        else
            effective_columns = maps_wide;
        effective_count = effective_columns << scy;
        // Base rounds down to a multiple of the effective count [scroll].
        map_base = world[0][3:0] & ~(effective_count - 4'd1);
        outside = source_x < 0 || source_y < 0 ||
                  source_x >= bg_width || source_y >= bg_height;
        wrapped_x = source_x & (bg_width - 1);
        wrapped_y = source_y & (bg_height - 1);
        map_x = wrapped_x >> 9;
        map_y = wrapped_y >> 9;
        map_number = {28'd0, map_base} + (map_y * {28'd0, effective_columns}) +
                     (map_x & ({28'd0, effective_columns} - 1));
        map_address = 18'(18'h10000 + ((map_number & 15) << 12) +
                      (((wrapped_y & 511) >> 3) << 6) + ((wrapped_x & 511) >> 3));
        char_address = 18'h3C000 + {map_cell[10:0], 3'b000} +
                       (map_cell[12] ? 3'd7 - source_y[2:0] : source_y[2:0]);
        map_skip = outside && world[0][7];

        // Normal and h-bias worlds draw at least eight rows; affine worlds
        // draw exactly H+1 [scroll, World Attributes; MiSTer decode].
        visual_height = $signed(world[8]) + 17'sd1;
        if (world[0][13:12] != 2'b10 && visual_height < 17'sd8)
            visual_height = 17'sd8;
        local_row = screen_y - $signed(world[3]);
        row_visible = local_row >= 0 && local_row < visual_height;

        affine_column = {pixel_x[16], pixel_x} - {x_start[16], x_start};
        if ($signed(affine[1]) < 0 && !eye)
            affine_column = affine_column - $signed(affine[1]);
        if ($signed(affine[1]) >= 0 && eye)
            affine_column = affine_column + $signed(affine[1]);
        // 26-bit accumulators, Q13.3 shifted to Q7.9 [MiSTer affine DDA].
        affine_x_calc = ($signed(affine[0]) <<< 6) +
                        $signed(affine[3]) * affine_column;
        affine_y_calc = ($signed(affine[2]) <<< 6) +
                        $signed(affine[4]) * affine_column;
    end

    // Service states spend the strip budget; world states pause it
    // [MiSTer coordinator].
    logic service_state;
    assign service_state = state == CLEAR || state == WRITE_PREP ||
                           state == WRITE_PACK_WAIT || state == WRITE_LEFT ||
                           state == WRITE_LEFT_WAIT || state == WRITE_RIGHT ||
                           state == WRITE_RIGHT_WAIT || state == STRIP_PAD;

    // The walk shared by every per-row engine when a row or eye finishes:
    // right eye next, then the next row, then the next world.
    task automatic advance_row_eye;
        begin
            if (!eye && world[0][14]) begin
                eye <= 1'b1;
                state <= world[0][13:12] == 2'b10 ? AFFINE_EYE_PREP : ROW_PREP;
            end else if (row == 3'd7) begin
                state <= NEXT_WORLD;
            end else begin
                row <= row + 3'd1;
                eye <= 1'b0;
                state <= ROW_PREP;
            end
        end
    endtask

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            strip_begin <= 1'b0;
            first_group_done <= 1'b0;
            strip_number <= 5'd0;
            object_group <= 2'd3;
            sbout <= 1'b0;
            sbout_ce <= 16'd0;
            service_ce <= 16'd0;
            world_elapsed <= 6'd0;
            world_target <= 6'd0;
            recovery_ce <= 8'd0;
            head_end <= 1'b0;
        end else begin
            done <= 1'b0;
            strip_begin <= 1'b0;
            first_group_done <= 1'b0;

            // SBOUT holds 56 us from each strip start, re-arming only once
            // it has cleared [scroll's formal figure; beetle-vb and MiSTer].
            if (strip_begin && !sbout) begin
                sbout <= 1'b1;
                sbout_ce <= SBOUT_CE;
            end else if (ce && sbout_ce != 16'd0) begin
                sbout_ce <= sbout_ce - 16'd1;
                if (sbout_ce == 16'd1) sbout <= 1'b0;
            end

            if (ce && service_state && service_ce != 16'd0)
                service_ce <= service_ce - 16'd1;

            if (reset_draw) begin
                // XPRST holds XPBSY through a short recovery window
                // [MiSTer coordinator].
                state <= busy ? RECOVERY : IDLE;
                recovery_ce <= RECOVERY_CE;
                sbout <= 1'b0;
                sbout_ce <= 16'd0;
            end else unique case (state)
                IDLE: if (start) begin
                    busy <= 1'b1;
                    service_ce <= SETUP_CE;
                    state <= SETUP;
                end
                SETUP: if (ce) begin
                    if (service_ce <= 16'd1) begin
                        strip_number <= 5'd0;
                        clear_chunk <= 6'd0;
                        world_index <= 6'd31;
                        object_group <= 2'd3;
                        strip_begin <= 1'b1;
                        service_ce <= FIRST_STRIP_CE;
                        state <= CLEAR;
                    end else service_ce <= service_ce - 16'd1;
                end
                RECOVERY: if (ce) begin
                    if (recovery_ce <= 8'd1) begin
                        busy <= 1'b0;
                        state <= IDLE;
                    end else recovery_ce <= recovery_ce - 8'd1;
                end
                CLEAR: begin
                    if (clear_chunk == 47) begin
                        world_elapsed <= 6'd0;
                        state <= HEAD_REQ;
                    end else clear_chunk <= clear_chunk + 1'b1;
                end
                HEAD_REQ: begin
                    if (ce) world_elapsed <= world_elapsed + 6'd1;
                    if (mem_ready) state <= HEAD_WAIT;
                end
                HEAD_WAIT: begin
                    if (ce) world_elapsed <= world_elapsed + 6'd1;
                    world[0] <= mem_rdata;
                    if (mem_rdata[6]) begin
                        // END terminates the walk after its measured interval.
                        head_end <= 1'b1;
                        world_target <= END_CE;
                        state <= WORLD_DELAY;
                    end else if (mem_rdata[15:14] == 2'b00) begin
                        // A dummy world costs its interval and nothing else.
                        head_end <= 1'b0;
                        world_target <= strip_number == 5'd0 ?
                                        DUMMY_FIRST_CE : DUMMY_CE;
                        state <= WORLD_DELAY;
                    end else begin
                        world_word <= 4'd1;
                        state <= WORLD_REQ;
                    end
                end
                WORLD_DELAY: begin
                    if (ce) world_elapsed <= world_elapsed + 6'd1;
                    if (world_elapsed >= world_target) begin
                        if (head_end) begin
                            write_x <= 0;
                            state <= WRITE_PREP;
                        end else state <= NEXT_WORLD;
                    end
                end
                WORLD_REQ: if (mem_ready) state <= WORLD_WAIT;
                WORLD_WAIT: begin
                    world[world_word] <= mem_rdata;
                    if (world_word == 10) begin
                        if (world[0][7] && world[0][13:12] != 2'b11)
                            state <= OVERPLANE_REQ;
                        else state <= WORLD_CHECKED;
                    end
                    else begin world_word <= world_word + 1'b1; state <= WORLD_REQ; end
                end
                OVERPLANE_REQ: if (mem_ready) state <= OVERPLANE_WAIT;
                OVERPLANE_WAIT: begin
                    overplane_cell <= mem_rdata;
                    state <= WORLD_CHECKED;
                end
                WORLD_CHECKED: begin
                    if (world[0][13:12] == 2'b11) begin
                        state <= OBJECT_PREP;
                    end else begin
                        row <= 0;
                        eye <= 0;
                        state <= ROW_PREP;
                    end
                end
                ROW_PREP: begin
                    if (!row_visible) begin
                        if (row == 7) state <= NEXT_WORLD;
                        else row <= row + 1'b1;
                    end else begin
                        if (world[0][13:12] == 2'b10) begin
                            // Element base wraps at 16 bits; an unaligned
                            // Param Base is rejected rather than guessed
                            // [MiSTer affine streamer; corruption is #2].
                            affine_word <= 0;
                            affine_base <= world[9] + {local_row[12:0], 3'b000};
                            if (world[9][2:0] != 3'b000) begin
                                if (row == 7) state <= NEXT_WORLD;
                                else row <= row + 1'b1;
                            end else state <= AFFINE_PARAM_REQ;
                        end else begin
                            x_start <= sx10(world[1][9:0]) +
                                       (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                            x_end <= sx10(world[1][9:0]) +
                                     (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0])) +
                                     sx13(world[7][12:0]);
                            bias <= 0;
                            source_y <= sx13(world[6][12:0]) + local_row;
                            if (world[0][13:12] == 2'b01) begin
                                hbias_index <= world[9] + {local_row[14:0], 1'b0};
                                state <= eye ? HBIAS_RIGHT_REQ : HBIAS_REQ;
                            end else state <= ROW_START;
                        end
                    end
                end
                HBIAS_REQ: if (mem_ready) state <= HBIAS_WAIT;
                HBIAS_WAIT: begin bias <= sx13(mem_rdata[12:0]); state <= ROW_START; end
                HBIAS_RIGHT_REQ: if (mem_ready) state <= HBIAS_RIGHT_WAIT;
                HBIAS_RIGHT_WAIT: begin bias <= sx13(mem_rdata[12:0]); state <= ROW_START; end
                ROW_START: begin
                    // A skipped eye still spends no pixels; a window that
                    // never meets the screen advances immediately.
                    if ((!eye && !world[0][15]) || x_lo > x_hi) begin
                        advance_row_eye;
                    end else begin
                        src_delta <= sx13(world[4][12:0]) +
                            (eye ? $signed({{2{world[5][14]}}, world[5][14:0]}) :
                                   -$signed({{2{world[5][14]}}, world[5][14:0]})) +
                            bias - x_start;
                        word_x <= x_lo[8:3];
                        word_last <= x_hi[8:3];
                        a_valid <= 1'b0;
                        b_valid <= 1'b0;
                        state <= WORD_SETUP;
                    end
                end
                WORD_SETUP: begin
                    line_address <= word_x;
                    if (!a_valid) begin
                        source_x <= word_s0;
                        phase_b <= 1'b0;
                        state <= WCELL_REQ;
                    end else if (word_k != 3'd0 && !b_valid) begin
                        source_x <= {word_s0[16:3] + 14'sd1, 3'b000};
                        phase_b <= 1'b1;
                        state <= WCELL_REQ;
                    end else state <= W_PRIME;
                end
                WCELL_REQ: begin
                    if (outside && world[0][7]) begin
                        map_cell <= overplane_cell;
                        state <= WCHAR_REQ;
                    end else if (mem_ready) state <= WCELL_WAIT;
                end
                WCELL_WAIT: begin
                    map_cell <= mem_rdata;
                    state <= WCHAR_REQ;
                end
                WCHAR_REQ: if (mem_ready) state <= WCHAR_WAIT;
                WCHAR_WAIT: begin
                    if (phase_b) begin
                        cellB <= map_cell;
                        charB <= mem_rdata;
                        b_valid <= 1'b1;
                    end else begin
                        cellA <= map_cell;
                        charA <= mem_rdata;
                        a_valid <= 1'b1;
                    end
                    state <= WORD_SETUP;
                end
                W_PRIME: state <= W_BLEND;
                W_BLEND: begin
                    if (word_x == word_last) begin
                        advance_row_eye;
                    end else begin
                        word_x <= word_x + 6'd1;
                        if (word_k != 3'd0) begin
                            cellA <= cellB;
                            charA <= charB;
                            b_valid <= 1'b0;
                        end else a_valid <= 1'b0;
                        state <= WORD_SETUP;
                    end
                end
                AFFINE_PARAM_REQ: if (mem_ready) state <= AFFINE_PARAM_WAIT;
                AFFINE_PARAM_WAIT: begin
                    affine[affine_word] <= mem_rdata;
                    if (affine_word == 4) begin
                        eye <= 0;
                        state <= AFFINE_EYE_PREP;
                    end else begin
                        affine_word <= affine_word + 1'b1;
                        state <= AFFINE_PARAM_REQ;
                    end
                end
                AFFINE_EYE_PREP: begin
                    x_start <= sx10(world[1][9:0]) +
                               (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                    x_end <= sx10(world[1][9:0]) +
                             (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0])) +
                             {7'd0, world[7][9:0]};
                    pixel_x <= sx10(world[1][9:0]) +
                               (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                    map_cache_valid <= 1'b0;
                    char_cache_valid <= 1'b0;
                    state <= PIXEL_PREP;
                end
                PIXEL_PREP: begin
                    if (pixel_x < 0) pixel_x <= 0;
                    else if (pixel_x > x_end || pixel_x > 383) begin
                        if (!eye && world[0][14]) begin
                            eye <= 1;
                            state <= AFFINE_EYE_PREP;
                        end
                        else if (row == 7) state <= NEXT_WORLD;
                        else begin row <= row + 1'b1; eye <= 0; state <= ROW_PREP; end
                    end else if ((!eye && !world[0][15]) || (eye && !world[0][14])) begin
                        pixel_x <= x_end + 17'sd1;
                    end else begin
                        source_x <= 17'(affine_x_calc[25:9]);
                        source_y <= 17'(affine_y_calc[25:9]);
                        state <= MAP_REQ;
                    end
                end
                MAP_REQ: begin
                    if (outside && world[0][7]) begin
                        map_cell <= overplane_cell;
                        state <= CHAR_REQ;
                    end else if (map_cache_valid &&
                                 map_address == cached_map_address) begin
                        map_cell <= cached_map_cell;
                        state <= CHAR_REQ;
                    end else if (mem_ready) state <= MAP_WAIT;
                end
                MAP_WAIT: begin
                    map_cell <= mem_rdata;
                    cached_map_cell <= mem_rdata;
                    cached_map_address <= map_address;
                    map_cache_valid <= 1'b1;
                    state <= CHAR_REQ;
                end
                CHAR_REQ: begin
                    if (char_cache_valid && char_address == cached_char_address) begin
                        char_pixels <= cached_char_pixels;
                        state <= PIXEL_DRAW;
                    end else if (mem_ready) state <= CHAR_WAIT;
                end
                CHAR_WAIT: begin
                    char_pixels <= mem_rdata;
                    cached_char_pixels <= mem_rdata;
                    cached_char_address <= char_address;
                    char_cache_valid <= 1'b1;
                    state <= PIXEL_DRAW;
                end
                PIXEL_DRAW: begin
                    if (raw_pixel != 0) begin
                        line_address <= pixel_x[8:3];
                        line_row <= row;
                        line_mask <= 16'h0003 << {pixel_x[2:0], 1'b0};
                        line_pattern <= {14'd0, color_pixel} << {pixel_x[2:0], 1'b0};
                        line_eye <= eye;
                        line_object <= 1'b0;
                        state <= LINE_READ;
                    end else begin
                        pixel_x <= pixel_x + 1'b1;
                        state <= PIXEL_PREP;
                    end
                end
                OBJECT_PREP: begin
                    // Group boundaries wrap at ten bits, so a group can span
                    // object 1,023 back to zero [scroll; MiSTer group tracker].
                    unique case (object_group)
                        2'd0: begin object_index <= spt[9:0]; object_start <= 0; end
                        2'd1: begin object_index <= spt[19:10]; object_start <= spt[9:0] + 10'd1; end
                        2'd2: begin object_index <= spt[29:20]; object_start <= spt[19:10] + 10'd1; end
                        default: begin object_index <= spt[39:30]; object_start <= spt[29:20] + 10'd1; end
                    endcase
                    object_word <= 0;
                    state <= OBJECT_REQ;
                end
                OBJECT_REQ: if (mem_ready) state <= OBJECT_WAIT;
                OBJECT_WAIT: begin
                    object[object_word] <= mem_rdata;
                    if (object_word == 3) begin
                        row <= 0;
                        state <= OBJECT_CHECK;
                    end else begin
                        object_word <= object_word + 1'b1;
                        state <= OBJECT_REQ;
                    end
                end
                OBJECT_CHECK: begin
                    if (object_row_delta < 8) begin
                        object_char_address <= 18'h3C000 + {object[3][10:0], 3'b000} +
                            (object[3][12] ? 3'd7-object_row_delta[2:0] :
                                             object_row_delta[2:0]);
                        state <= OBJECT_CHAR_REQ;
                    end else state <= OBJECT_NEXT;
                end
                OBJECT_CHAR_REQ: if (mem_ready) state <= OBJECT_CHAR_WAIT;
                OBJECT_CHAR_WAIT: begin
                    char_pixels <= mem_rdata;
                    eye <= 0;
                    object_pixel <= 0;
                    state <= OBJECT_PIXEL_PREP;
                end
                OBJECT_PIXEL_PREP: begin
                    // JLON/JRON alone pick the eyes; the world's LON/RON only
                    // decide whether it was a dummy [scroll, Object Worlds;
                    // MiSTer obj row token — beetle-vb ANDs them instead].
                    if ((!eye && !object[1][15]) || (eye && !object[1][14])) begin
                        if (!eye) begin eye <= 1; object_pixel <= 0; end
                        else state <= OBJECT_NEXT;
                    end else begin
                        object_screen_x <= sx10(object[0][9:0]) +
                            (eye ? sx10(object[1][9:0]) : -sx10(object[1][9:0])) +
                            object_pixel;
                        state <= OBJECT_PIXEL_DRAW;
                    end
                end
                OBJECT_PIXEL_DRAW: begin
                    if (object_screen_x >= 0 && object_screen_x < 384 &&
                        object_raw_pixel != 0) begin
                        line_address <= object_screen_x[8:3];
                        line_row <= row;
                        line_mask <= 16'h0003 << {object_screen_x[2:0], 1'b0};
                        line_pattern <= {14'd0, object_color_pixel} <<
                                        {object_screen_x[2:0], 1'b0};
                        line_eye <= eye;
                        line_object <= 1'b1;
                        state <= LINE_READ;
                    end else if (object_pixel == 7) begin
                        if (!eye) begin eye <= 1; object_pixel <= 0; state <= OBJECT_PIXEL_PREP; end
                        else state <= OBJECT_NEXT;
                    end else begin object_pixel <= object_pixel + 1'b1; state <= OBJECT_PIXEL_PREP; end
                end
                LINE_READ: state <= LINE_WAIT;
                LINE_WAIT: state <= LINE_WRITE;
                LINE_WRITE: begin
                    if (!line_object) begin
                        pixel_x <= pixel_x + 1'b1;
                        state <= PIXEL_PREP;
                    end else if (object_pixel == 7) begin
                        if (!eye) begin eye <= 1; object_pixel <= 0; state <= OBJECT_PIXEL_PREP; end
                        else state <= OBJECT_NEXT;
                    end else begin object_pixel <= object_pixel + 1'b1; state <= OBJECT_PIXEL_PREP; end
                end
                OBJECT_NEXT: begin
                    if (row != 7) begin
                        row <= row + 1'b1;
                        state <= OBJECT_CHECK;
                    end else if (object_index == object_start) begin
                        object_group <= object_group - 1'b1;
                        state <= NEXT_WORLD;
                    end else begin
                        object_index <= object_index - 1'b1;
                        object_word <= 0;
                        state <= OBJECT_REQ;
                    end
                end
                NEXT_WORLD: begin
                    if (world_index == 0) begin write_x <= 0; state <= WRITE_PREP; end
                    else begin
                        world_index <= world_index - 1'b1;
                        world_elapsed <= 6'd0;
                        state <= HEAD_REQ;
                    end
                end
                WRITE_PREP: begin
                    line_address <= write_x[8:3];
                    state <= WRITE_PACK_WAIT;
                end
                WRITE_PACK_WAIT: state <= WRITE_LEFT;
                WRITE_LEFT: if (mem_ready) state <= WRITE_LEFT_WAIT;
                WRITE_LEFT_WAIT: state <= WRITE_RIGHT;
                WRITE_RIGHT: if (mem_ready) state <= WRITE_RIGHT_WAIT;
                WRITE_RIGHT_WAIT: begin
                    if (write_x == 383) state <= STRIP_PAD;
                    else begin write_x <= write_x + 1'b1; state <= WRITE_PREP; end
                end
                STRIP_PAD: begin
                    // Sit out the measured service budget before committing.
                    if (service_ce == 16'd0) begin
                        if (strip_number == 0) first_group_done <= 1'b1;
                        state <= NEXT_STRIP;
                    end
                end
                NEXT_STRIP: begin
                    if (strip_number == 27) state <= FINISH;
                    else begin
                        strip_number <= strip_number + 1'b1;
                        strip_begin <= 1'b1;
                        clear_chunk <= 0;
                        world_index <= 31;
                        object_group <= 3;
                        service_ce <= LATER_STRIP_CE;
                        state <= CLEAR;
                    end
                end
                FINISH: begin busy <= 0; done <= 1; state <= IDLE; end
                default: state <= IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
