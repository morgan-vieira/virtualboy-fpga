`default_nettype none

// One compositor row. MLABs preserve scarce framebuffer blocks.

module vip_line_bank (
    input  logic        clk,
    input  logic [5:0]  read_addr,
    output logic [15:0] read_data,
    input  logic        write_enable,
    input  logic [5:0]  write_addr,
    input  logic [15:0] write_data
);
    (* ramstyle = "MLAB, no_rw_check" *) logic [15:0] memory [0:63];

    always_ff @(posedge clk) begin
        read_data <= memory[read_addr];
    end

    always_ff @(posedge clk) begin
        if (write_enable) memory[write_addr] <= write_data;
    end
endmodule

`default_nettype wire
