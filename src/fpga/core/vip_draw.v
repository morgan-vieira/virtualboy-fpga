`default_nettype none

// VIP world renderer. Eight horizontal rows are composed in parallel banks,
// then transposed into the hardware's column-major framebuffer layout.

module vip_draw (
    input  logic        clk,
    input  logic        reset_n,
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
        IDLE, CLEAR, WORLD_REQ, WORLD_WAIT, WORLD_CHECK,
        ROW_PREP, HBIAS_REQ, HBIAS_WAIT, AFFINE_PARAM_REQ,
        AFFINE_PARAM_WAIT, AFFINE_EYE_PREP, PIXEL_PREP,
        MAP_REQ, MAP_WAIT, CHAR_REQ, CHAR_WAIT, PIXEL_DRAW,
        OBJECT_PREP, OBJECT_REQ, OBJECT_WAIT, OBJECT_CHECK,
        OBJECT_PIXEL_PREP, OBJECT_CHAR_REQ, OBJECT_CHAR_WAIT,
        OBJECT_PIXEL_DRAW, OBJECT_NEXT, LINE_READ, LINE_WAIT, LINE_WRITE,
        NEXT_WORLD, WRITE_PREP, WRITE_PACK_WAIT, WRITE_LEFT,
        WRITE_LEFT_WAIT, WRITE_RIGHT, WRITE_RIGHT_WAIT, NEXT_STRIP,
        FINISH
    } state_t;
    state_t state;

    logic [5:0] clear_chunk;
    logic [5:0] world_index;
    logic [3:0] world_word;
    logic [2:0] row;
    logic eye;
    logic signed [15:0] pixel_x;
    logic signed [15:0] x_start, x_end;
    logic signed [15:0] source_x, source_y;
    logic signed [15:0] bias;
    logic [18:1] map_address;
    logic [18:1] hbias_address;
    logic [18:1] cached_map_address;
    logic [15:0] map_cell, cached_map_cell;
    logic map_cache_valid;
    logic [18:1] char_address;
    logic [18:1] object_char_address;
    logic [18:1] cached_char_address;
    logic [15:0] char_pixels, cached_char_pixels;
    logic char_cache_valid;
    logic [8:0] write_x;
    logic [9:0] object_index, object_start;
    logic [1:0] object_group;
    logic [1:0] object_word;
    logic [15:0] object [0:3];
    logic [15:0] affine [0:4];
    logic [2:0] affine_word;
    logic [18:1] affine_address;
    logic [3:0] object_pixel;
    logic signed [15:0] object_screen_x;
    logic [7:0] object_row_delta;
    logic [1:0] object_raw_pixel, object_color_pixel;
    logic [2:0] object_char_column;
    logic [5:0] line_address;
    logic [2:0] line_row;
    logic [2:0] line_position;
    logic [1:0] line_color;
    logic line_eye;
    logic line_object;

    logic [15:0] packed_left, packed_right;
    logic signed [15:0] screen_y;
    integer i;

    function automatic signed [15:0] sx10(input logic [9:0] value);
        sx10 = {{6{value[9]}}, value};
    endfunction

    function automatic signed [15:0] sx13(input logic [12:0] value);
        sx13 = {{3{value[12]}}, value};
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

    function automatic [15:0] replace_pixel(
        input logic [15:0] original,
        input logic [2:0] position,
        input logic [1:0] value
    );
        logic [15:0] mask;
        begin
            mask = 16'h0003 << {position, 1'b0};
            replace_pixel = (original & ~mask) |
                            ({14'd0, value} << {position, 1'b0});
        end
    endfunction

    always_comb begin
        screen_y = $signed({8'd0, strip_number, 3'b000}) + $signed({13'd0, row});
        packed_left = 16'd0;
        packed_right = 16'd0;
        for (i = 0; i < 8; i = i + 1) begin
            packed_left[i*2 +: 2] = 2'(line_l_q[i] >> {write_x[2:0], 1'b0});
            packed_right[i*2 +: 2] = 2'(line_r_q[i] >> {write_x[2:0], 1'b0});
        end
    end

    genvar bank;
    generate
        for (bank = 0; bank < 8; bank = bank + 1) begin : line_banks
            wire selected = state == LINE_WRITE && line_row == bank;
            wire [5:0] write_address = state == CLEAR ? clear_chunk : line_address;
            wire [15:0] left_data = state == CLEAR ? {8{bkcol}} :
                replace_pixel(line_l_q[bank], line_position, line_color);
            wire [15:0] right_data = state == CLEAR ? {8{bkcol}} :
                replace_pixel(line_r_q[bank], line_position, line_color);

            vip_line_bank left (
                .clk(clk), .read_addr(line_address), .read_data(line_l_q[bank]),
                .write_enable(state == CLEAR || (selected && !line_eye)),
                .write_addr(write_address), .write_data(left_data)
            );
            vip_line_bank right (
                .clk(clk), .read_addr(line_address), .read_data(line_r_q[bank]),
                .write_enable(state == CLEAR || (selected && line_eye)),
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
            WORLD_REQ: begin
                mem_req = 1'b1;
                mem_addr = 18'h1EC00 + {world_index[4:0], 4'b0000} + world_word;
            end
            MAP_REQ: begin
                // A request nobody consumes parks pocket_sram in RELEASE.
                mem_req = !map_skip;
                mem_addr = map_address;
            end
            HBIAS_REQ, AFFINE_PARAM_REQ, OBJECT_REQ,
            OBJECT_CHAR_REQ, CHAR_REQ: begin
                mem_req = 1'b1;
                mem_addr = state == CHAR_REQ ? char_address :
                           state == OBJECT_CHAR_REQ ? object_char_address :
                           state == HBIAS_REQ ? hbias_address :
                           state == AFFINE_PARAM_REQ ? affine_address :
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

    integer bg_width, bg_height, effective_w, effective_logw;
    integer wrapped_x, wrapped_y, map_x, map_y, map_count, map_base, map_number;
    logic outside;
    logic map_skip;
    logic signed [16:0] affine_column;
    logic signed [31:0] affine_x_calc, affine_y_calc;
    always_comb begin
        bg_width = 512 << world[0][9:8];
        bg_height = 512 << world[0][7:6];
        map_count = 1 << (world[0][9:8] + world[0][7:6]);
        effective_logw = world[0][9:8];
        if (map_count > 8) effective_logw = 3 - world[0][7:6];
        case (effective_logw)
            0: effective_w = 1;
            1: effective_w = 2;
            2: effective_w = 4;
            default: effective_w = 8;
        endcase
        map_base = world[0][3:0] & ~((map_count > 8 ? 8 : map_count) - 1);
        outside = source_x < 0 || source_y < 0 ||
                  source_x >= bg_width || source_y >= bg_height;
        wrapped_x = source_x & (bg_width - 1);
        wrapped_y = source_y & (bg_height - 1);
        map_x = wrapped_x >> 9;
        map_y = wrapped_y >> 9;
        map_number = map_base + (map_y * effective_w) +
                     (map_x & (effective_w - 1));
        map_address = 18'(18'h10000 + (map_number << 12) +
                      (((wrapped_y & 511) >> 3) << 6) + ((wrapped_x & 511) >> 3));
        char_address = 18'h3C000 + {map_cell[10:0], 3'b000} +
                       (map_cell[12] ? 3'd7 - source_y[2:0] : source_y[2:0]);
        map_skip = (outside && world[0][7]) ||
                   (map_cache_valid && map_address == cached_map_address);
        affine_column = pixel_x - x_start;
        if ($signed(affine[1]) < 0 && !eye)
            affine_column = affine_column - $signed(affine[1]);
        if ($signed(affine[1]) >= 0 && eye)
            affine_column = affine_column + $signed(affine[1]);
        affine_x_calc = ($signed(affine[0]) <<< 6) +
                        $signed(affine[3]) * affine_column;
        affine_y_calc = ($signed(affine[2]) <<< 6) +
                        $signed(affine[4]) * affine_column;
    end

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
            strip_begin <= 1'b0;
            first_group_done <= 1'b0;
            strip_number <= 5'd0;
            object_group <= 2'd3;
        end else begin
            done <= 1'b0;
            strip_begin <= 1'b0;
            first_group_done <= 1'b0;
            if (reset_draw) begin
                state <= IDLE;
                busy <= 1'b0;
            end else unique case (state)
                IDLE: if (start) begin
                    busy <= 1'b1;
                    strip_number <= 5'd0;
                    clear_chunk <= 6'd0;
                    world_index <= 6'd31;
                    object_group <= 2'd3;
                    strip_begin <= 1'b1;
                    state <= CLEAR;
                end
                CLEAR: begin
                    if (clear_chunk == 47) begin
                        world_word <= 0;
                        state <= WORLD_REQ;
                    end else clear_chunk <= clear_chunk + 1'b1;
                end
                WORLD_REQ: if (mem_ready) state <= WORLD_WAIT;
                WORLD_WAIT: begin
                    world[world_word] <= mem_rdata;
                    if (world_word == 10) state <= WORLD_CHECK;
                    else begin world_word <= world_word + 1'b1; state <= WORLD_REQ; end
                end
                WORLD_CHECK: begin
                    if (world[0][6]) begin
                        write_x <= 0;
                        state <= WRITE_PREP;
                    end else if (world[0][13:12] == 2'b11 && |world[0][15:14]) begin
                        state <= OBJECT_PREP;
                    end else if (|world[0][15:14]) begin
                        row <= 0;
                        eye <= 0;
                        state <= ROW_PREP;
                    end else state <= NEXT_WORLD;
                end
                ROW_PREP: begin
                    if (screen_y < $signed(world[3]) ||
                        screen_y > ($signed(world[3]) +
                        $signed(world[0][13:12] == 2'b10 ? world[8] :
                                (world[8][9:0] < 10'd7 ? 16'd7 : world[8])))) begin
                        if (row == 7) state <= NEXT_WORLD;
                        else row <= row + 1'b1;
                    end else begin
                        if (world[0][13:12] == 2'b10) begin
                            affine_word <= 0;
                            affine_address <= 18'h10000 + world[9] +
                                ((screen_y - $signed(world[3])) <<< 3);
                            state <= AFFINE_PARAM_REQ;
                        end else begin
                        x_start <= sx10(world[1][9:0]) +
                                   (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                        x_end <= sx10(world[1][9:0]) +
                                 (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0])) +
                                 sx13(world[7][12:0]);
                        pixel_x <= sx10(world[1][9:0]) +
                                   (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                        bias <= 0;
                        map_cache_valid <= 0;
                        char_cache_valid <= 0;
                        if (world[0][13:12] == 2'b01) begin
                            hbias_address <= 18'h10000 + world[9] +
                                           (({strip_number,3'b000}+row-$signed(world[3])) << 1) + eye;
                            state <= HBIAS_REQ;
                        end else state <= PIXEL_PREP;
                        end
                    end
                end
                HBIAS_REQ: if (mem_ready) state <= HBIAS_WAIT;
                HBIAS_WAIT: begin bias <= sx13(mem_rdata[12:0]); state <= PIXEL_PREP; end
                AFFINE_PARAM_REQ: if (mem_ready) state <= AFFINE_PARAM_WAIT;
                AFFINE_PARAM_WAIT: begin
                    affine[affine_word] <= mem_rdata;
                    if (affine_word == 4) begin
                        eye <= 0;
                        state <= AFFINE_EYE_PREP;
                    end else begin
                        affine_word <= affine_word + 1'b1;
                        affine_address <= affine_address + 1'b1;
                        state <= AFFINE_PARAM_REQ;
                    end
                end
                AFFINE_EYE_PREP: begin
                    x_start <= sx10(world[1][9:0]) +
                               (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                    x_end <= sx10(world[1][9:0]) +
                             (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0])) +
                             {6'd0, world[7][9:0]};
                    pixel_x <= sx10(world[1][9:0]) +
                               (eye ? sx10(world[2][9:0]) : -sx10(world[2][9:0]));
                    map_cache_valid <= 0;
                    char_cache_valid <= 0;
                    state <= PIXEL_PREP;
                end
                PIXEL_PREP: begin
                    if (pixel_x < 0) pixel_x <= 0;
                    else if (pixel_x > x_end || pixel_x > 383) begin
                        if (!eye && world[0][14]) begin
                            eye <= 1;
                            state <= world[0][13:12] == 2'b10 ? AFFINE_EYE_PREP : ROW_PREP;
                        end
                        else if (row == 7) state <= NEXT_WORLD;
                        else begin row <= row + 1'b1; eye <= 0; state <= ROW_PREP; end
                    end else if ((!eye && !world[0][15]) || (eye && !world[0][14])) begin
                        pixel_x <= x_end + 16'd1;
                    end else begin
                        if (world[0][13:12] == 2'b10) begin
                            source_x <= 16'(affine_x_calc >>> 9);
                            source_y <= 16'(affine_y_calc >>> 9);
                        end else begin
                            source_x <= sx13(world[4][12:0]) +
                                (eye ? $signed({world[5][14],world[5][14:0]}) :
                                       -$signed({world[5][14],world[5][14:0]})) +
                                bias + pixel_x - x_start;
                            source_y <= sx13(world[6][12:0]) + screen_y - $signed(world[3]);
                        end
                        state <= MAP_REQ;
                    end
                end
                MAP_REQ: begin
                    if (outside && world[0][7]) begin
                        map_cell <= world[10];
                        state <= CHAR_REQ;
                    end else if (map_cache_valid && map_address == cached_map_address) begin
                        map_cell <= cached_map_cell;
                        state <= CHAR_REQ;
                    end else if (mem_ready) state <= MAP_WAIT;
                end
                MAP_WAIT: begin
                    map_cell <= mem_rdata;
                    cached_map_cell <= mem_rdata;
                    cached_map_address <= map_address;
                    map_cache_valid <= 1;
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
                    char_cache_valid <= 1;
                    state <= PIXEL_DRAW;
                end
                PIXEL_DRAW: begin
                    if (raw_pixel != 0) begin
                        line_address <= pixel_x[8:3];
                        line_row <= row;
                        line_position <= pixel_x[2:0];
                        line_color <= color_pixel;
                        line_eye <= eye;
                        line_object <= 1'b0;
                        state <= LINE_READ;
                    end else begin
                        pixel_x <= pixel_x + 1'b1;
                        state <= PIXEL_PREP;
                    end
                end
                OBJECT_PREP: begin
                    unique case (object_group)
                        2'd0: begin object_index <= spt[9:0]; object_start <= 0; end
                        2'd1: begin object_index <= spt[19:10]; object_start <= spt[9:0] + 1'b1; end
                        2'd2: begin object_index <= spt[29:20]; object_start <= spt[19:10] + 1'b1; end
                        default: begin object_index <= spt[39:30]; object_start <= spt[29:20] + 1'b1; end
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
                        line_position <= object_screen_x[2:0];
                        line_color <= object_color_pixel;
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
                    else begin world_index <= world_index - 1'b1; world_word <= 0; state <= WORLD_REQ; end
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
                    if (write_x == 383) begin
                        if (strip_number == 0) first_group_done <= 1'b1;
                        state <= NEXT_STRIP;
                    end
                    else begin write_x <= write_x + 1'b1; state <= WRITE_PREP; end
                end
                NEXT_STRIP: begin
                    if (strip_number == 27) state <= FINISH;
                    else begin
                        strip_number <= strip_number + 1'b1;
                        strip_begin <= 1'b1;
                        clear_chunk <= 0;
                        world_index <= 31;
                        object_group <= 3;
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
