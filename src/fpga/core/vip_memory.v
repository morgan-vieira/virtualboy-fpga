`default_nettype none

// VIP RAM shared by the CPU, drawing engine, and host display.
//
// The CPU and drawing engine share one port because software must not touch
// drawing data while the VIP is drawing [Development Manual, Sec.5 §31.3].
// Drawing wins if both request together. The host owns the second port of the
// four frame buffers, matching the hardware's simultaneous draw/display use.

module vip_memory (
    input  logic        clk,
    input  logic        reset_n,

    input  logic        cpu_sel,
    input  logic [26:1] cpu_addr,
    input  logic        cpu_we,
    input  logic [1:0]  cpu_be,
    input  logic [15:0] cpu_wdata,
    output logic [15:0] cpu_rdata,
    output logic        ready,

    input  logic        draw_req,
    input  logic [18:1] draw_addr,
    input  logic        draw_we,
    input  logic [1:0]  draw_be,
    input  logic [15:0] draw_wdata,
    output logic [15:0] draw_rdata,
    output logic        draw_ready,

    output logic        dram_req,
    output logic [15:0] dram_addr,
    output logic        dram_we,
    output logic [1:0]  dram_be,
    output logic [15:0] dram_wdata,
    input  logic [15:0] dram_rdata,
    input  logic        dram_ready,

    input  logic        display_clk,
    input  logic        display_eye,
    input  logic        display_buffer,
    input  logic [8:0]  display_x,
    input  logic [7:0]  display_y,
    output logic [1:0]  display_pixel,
    input  logic [7:0]  display_column_index,
    output logic [15:0] display_column
);

    logic [7:0] fb_l0_lo [0:12287];
    logic [7:0] fb_l0_hi [0:12287];
    logic [7:0] fb_l1_lo [0:12287];
    logic [7:0] fb_l1_hi [0:12287];
    logic [7:0] fb_r0_lo [0:12287];
    logic [7:0] fb_r0_hi [0:12287];
    logic [7:0] fb_r1_lo [0:12287];
    logic [7:0] fb_r1_hi [0:12287];

    logic [7:0] chr_lo [0:16383];
    logic [7:0] chr_hi [0:16383];
    (* ramstyle = "MLAB, no_rw_check" *) logic [7:0] column_lo [0:511];
    (* ramstyle = "MLAB, no_rw_check" *) logic [7:0] column_hi [0:511];
    logic column_written;
    logic [18:1] access_addr;
    logic        access_we;
    logic [1:0]  access_be;
    logic [15:0] access_wdata;

    always_comb begin
        access_addr  = draw_req ? draw_addr : cpu_addr[18:1];
        access_we    = draw_req ? draw_we : cpu_we;
        access_be    = draw_req ? draw_be : cpu_be;
        access_wdata = draw_req ? draw_wdata : cpu_wdata;
    end

    typedef enum logic [2:0] {
        NONE,
        FB_L0,
        FB_L1,
        FB_R0,
        FB_R1,
        CHR,
        DRAM
    } target_t;

    target_t target;
    logic [13:0] fb_index;
    logic [13:0] chr_index;
    logic [15:0] dram_index;

    always_comb begin
        target = NONE;
        fb_index = '0;
        chr_index = '0;
        dram_index = '0;

        if (access_addr < (19'h06000 >> 1)) begin
            target = FB_L0;
            fb_index = access_addr[14:1];
        end else if (access_addr < (19'h08000 >> 1)) begin
            target = CHR;
            chr_index = access_addr[12:1];
        end else if (access_addr < (19'h0E000 >> 1)) begin
            target = FB_L1;
            fb_index = access_addr[14:1];
        end else if (access_addr < (19'h10000 >> 1)) begin
            target = CHR;
            chr_index = 14'h1000 + access_addr[12:1];
        end else if (access_addr < (19'h16000 >> 1)) begin
            target = FB_R0;
            fb_index = access_addr[14:1];
        end else if (access_addr < (19'h18000 >> 1)) begin
            target = CHR;
            chr_index = 14'h2000 + access_addr[12:1];
        end else if (access_addr < (19'h1E000 >> 1)) begin
            target = FB_R1;
            fb_index = access_addr[14:1];
        end else if (access_addr < (19'h20000 >> 1)) begin
            target = CHR;
            chr_index = 14'h3000 + access_addr[12:1];
        end else if (access_addr < (19'h40000 >> 1)) begin
            target = DRAM;
            dram_index = access_addr[16:1];
        end else if (access_addr >= (19'h78000 >> 1)) begin
            target = CHR;
            chr_index = access_addr[14:1];
        end
    end

    always_comb begin
        dram_req = (draw_req || cpu_sel) && target == DRAM;
        dram_addr = dram_index;
        dram_we = access_we;
        dram_be = access_be;
        dram_wdata = access_wdata;
        ready = !dram_req || dram_ready;
        draw_ready = !draw_req || target != DRAM || dram_ready;
    end

    logic [7:0] fb_l0_lo_q, fb_l0_hi_q;
    logic [7:0] fb_l1_lo_q, fb_l1_hi_q;
    logic [7:0] fb_r0_lo_q, fb_r0_hi_q;
    logic [7:0] fb_r1_lo_q, fb_r1_hi_q;
    logic [7:0] chr_lo_q, chr_hi_q;
    target_t target_q;

    always_ff @(posedge clk) begin
        if (!reset_n) begin
            column_written <= 1'b0;
        end else if (draw_req || cpu_sel) begin
            fb_l0_lo_q <= fb_l0_lo[fb_index];
            fb_l0_hi_q <= fb_l0_hi[fb_index];
            fb_l1_lo_q <= fb_l1_lo[fb_index];
            fb_l1_hi_q <= fb_l1_hi[fb_index];
            fb_r0_lo_q <= fb_r0_lo[fb_index];
            fb_r0_hi_q <= fb_r0_hi[fb_index];
            fb_r1_lo_q <= fb_r1_lo[fb_index];
            fb_r1_hi_q <= fb_r1_hi[fb_index];
            chr_lo_q <= chr_lo[chr_index];
            chr_hi_q <= chr_hi[chr_index];
            target_q <= target;

            unique case (target)
                FB_L0: begin
                    if (access_we && access_be[0]) fb_l0_lo[fb_index] <= access_wdata[7:0];
                    if (access_we && access_be[1]) fb_l0_hi[fb_index] <= access_wdata[15:8];
                end
                FB_L1: begin
                    if (access_we && access_be[0]) fb_l1_lo[fb_index] <= access_wdata[7:0];
                    if (access_we && access_be[1]) fb_l1_hi[fb_index] <= access_wdata[15:8];
                end
                FB_R0: begin
                    if (access_we && access_be[0]) fb_r0_lo[fb_index] <= access_wdata[7:0];
                    if (access_we && access_be[1]) fb_r0_hi[fb_index] <= access_wdata[15:8];
                end
                FB_R1: begin
                    if (access_we && access_be[0]) fb_r1_lo[fb_index] <= access_wdata[7:0];
                    if (access_we && access_be[1]) fb_r1_hi[fb_index] <= access_wdata[15:8];
                end
                CHR: begin
                    if (access_we && access_be[0]) chr_lo[chr_index] <= access_wdata[7:0];
                    if (access_we && access_be[1]) chr_hi[chr_index] <= access_wdata[15:8];
                end
                DRAM: begin end
                default: begin end
            endcase

            if (target == DRAM && access_we &&
                access_addr >= (19'h3DC00 >> 1) &&
                access_addr < (19'h3E000 >> 1)) begin
                if (access_be[0])
                    column_lo[access_addr[9:1]] <= access_wdata[7:0];
                if (access_be[1])
                    column_hi[access_addr[9:1]] <= access_wdata[15:8];
                column_written <= 1'b1;
            end
        end
    end

    always_comb begin
        unique case (target_q)
            FB_L0: cpu_rdata = {fb_l0_hi_q, fb_l0_lo_q};
            FB_L1: cpu_rdata = {fb_l1_hi_q, fb_l1_lo_q};
            FB_R0: cpu_rdata = {fb_r0_hi_q, fb_r0_lo_q};
            FB_R1: cpu_rdata = {fb_r1_hi_q, fb_r1_lo_q};
            CHR:   cpu_rdata = {chr_hi_q, chr_lo_q};
            DRAM:  cpu_rdata = dram_rdata;
            default: cpu_rdata = '0;
        endcase
        draw_rdata = cpu_rdata;
    end

    logic [14:0] display_index;
    logic [2:0]  display_row;
    logic [15:0] display_word;
    logic [15:0] display_column_q;
    logic column_written_q1, column_written_q2;

    always_comb begin
        display_index = {display_x, 5'b00000} + display_y[7:3];
    end

    always_ff @(posedge display_clk) begin
        display_row <= display_y[2:0];
        column_written_q1 <= column_written;
        column_written_q2 <= column_written_q1;
        display_column_q <= {column_hi[{display_eye, display_column_index}],
                             column_lo[{display_eye, display_column_index}]};
        unique case ({display_eye, display_buffer})
            2'b00: display_word <= {fb_l0_hi[display_index], fb_l0_lo[display_index]};
            2'b01: display_word <= {fb_l1_hi[display_index], fb_l1_lo[display_index]};
            2'b10: display_word <= {fb_r0_hi[display_index], fb_r0_lo[display_index]};
            2'b11: display_word <= {fb_r1_hi[display_index], fb_r1_lo[display_index]};
        endcase
    end

    always_comb begin
        display_pixel = 2'(display_word >> {display_row, 1'b0});
        display_column = column_written_q2 ? display_column_q : 16'h00FF;
    end

endmodule
