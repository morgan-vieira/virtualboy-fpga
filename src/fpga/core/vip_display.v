`default_nettype none

// Converts VIP pixel levels into apparent Pocket brightness.

module vip_display (
    input  logic [8:0]  x,
    input  logic [1:0]  pixel,
    input  logic [7:0]  brta,
    input  logic [7:0]  brtb,
    input  logic [7:0]  brtc,
    input  logic [7:0]  rest,
    input  logic [15:0] column,
    output logic [7:0]  column_index,
    output logic [7:0]  luma
);

    logic [9:0] base_level;
    logic [8:0] repeat_count;
    logic [10:0] column_budget;
    logic [17:0] idle_cost;
    logic [18:0] active_budget;
    logic [18:0] apparent_level;

    always_comb begin
        // MiSTer uses the measured 0xfa field-start value without a servo.
        column_index = 8'hFA - {1'b0, x[8:2]};

        unique case (pixel)
            2'd1: base_level = {2'd0, brta};
            2'd2: base_level = {2'd0, brtb};
            2'd3: base_level = {2'd0, brta} + {2'd0, brtb} +
                               {2'd0, brtc};
            default: base_level = 10'd0;
        endcase

        repeat_count = {1'b0, column[15:8]} + 9'd1;
        // Column length uses 200 ns; brightness controls use 50 ns.
        column_budget = ({3'd0, column[7:0]} + 11'd1) << 2;
        idle_cost = ({10'd0, rest} + 18'd1) * repeat_count;
        active_budget = idle_cost >= column_budget ? 19'd0 :
                        column_budget - idle_cost;
        apparent_level = base_level * repeat_count;
        if (apparent_level > active_budget)
            apparent_level = active_budget;
        if (apparent_level > 19'd255)
            luma = 8'hFF;
        else
            luma = apparent_level[7:0];
    end

endmodule

`default_nettype wire
