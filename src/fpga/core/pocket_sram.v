`default_nettype none

// Controller for Pocket's AS6C2016-55BIN asynchronous SRAM.
//
// Address and control hold for three 39.936 MHz clocks before a read is
// sampled or a write completes: 75.12 ns against the part's 55 ns access
// time. A requester holds req and its payload until ready.

module pocket_sram (
    input  logic        clk,
    input  logic        reset_n,

    input  logic        req,
    input  logic [16:0] addr,
    input  logic        we,
    input  logic [1:0]  be,
    input  logic [15:0] wdata,
    output logic [15:0] rdata,
    output logic        ready,

    output logic [16:0] sram_a,
    inout  wire  [15:0] sram_dq,
    output logic        sram_oe_n,
    output logic        sram_we_n,
    output logic        sram_ub_n,
    output logic        sram_lb_n
);

    typedef enum logic [2:0] {
        IDLE,
        ACCESS_1,
        ACCESS_2,
        ACCESS_3,
        RESPONSE,
        RELEASE
    } state_t;

    state_t state;
    logic write_q;
    logic [15:0] wdata_q;
    logic access_active;

    always_comb begin
        access_active = state == ACCESS_1 || state == ACCESS_2 ||
                        state == ACCESS_3;
        ready = state == RESPONSE;
        sram_oe_n = 1'b1;
        sram_we_n = 1'b1;

        if (access_active) begin
            sram_oe_n = write_q;
            sram_we_n = !write_q;
        end
    end

    assign sram_dq = write_q && access_active
                   ? wdata_q : 16'hzzzz;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= IDLE;
            sram_a <= '0;
            sram_ub_n <= 1'b1;
            sram_lb_n <= 1'b1;
            write_q <= 1'b0;
            wdata_q <= '0;
            rdata <= '0;
        end else begin
            unique case (state)
                IDLE: if (req) begin
                    sram_a <= addr;
                    sram_ub_n <= !be[1];
                    sram_lb_n <= !be[0];
                    write_q <= we;
                    wdata_q <= wdata;
                    state <= ACCESS_1;
                end
                ACCESS_1: state <= ACCESS_2;
                ACCESS_2: state <= ACCESS_3;
                ACCESS_3: begin
                    if (!write_q) rdata <= sram_dq;
                    state <= RESPONSE;
                end
                RESPONSE: state <= RELEASE;
                RELEASE: if (!req) begin
                    sram_ub_n <= 1'b1;
                    sram_lb_n <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule

`default_nettype wire
