`timescale 1ns/1ps
`default_nettype none

module pocket_sram_tb;
    logic clk = 1'b0;
    logic reset_n = 1'b0;
    logic req = 1'b0;
    logic [16:0] addr = '0;
    logic we = 1'b0;
    logic [1:0] be = '0;
    logic [15:0] wdata = '0;
    logic [15:0] rdata;
    logic ready;
    logic [16:0] sram_a;
    tri [15:0] sram_dq;
    logic sram_oe_n, sram_we_n, sram_ub_n, sram_lb_n;

    logic [7:0] memory_lo [0:131071];
    logic [7:0] memory_hi [0:131071];
    logic [15:0] memory_read;

    pocket_sram dut (.*);

    always #12.52 clk = ~clk;

    assign memory_read = {memory_hi[sram_a], memory_lo[sram_a]};
    assign #55 sram_dq = !sram_oe_n && sram_we_n ? memory_read : 16'hzzzz;

    always @(posedge sram_we_n) begin
        if (!sram_lb_n) memory_lo[sram_a] <= sram_dq[7:0];
        if (!sram_ub_n) memory_hi[sram_a] <= sram_dq[15:8];
    end

    task automatic transact(input logic write, input logic [16:0] address,
                             input logic [1:0] lanes, input logic [15:0] data);
        integer clocks;
        begin
            @(negedge clk);
            req = 1'b1;
            addr = address;
            we = write;
            be = lanes;
            wdata = data;
            clocks = 0;
            while (!ready) begin
                @(negedge clk);
                clocks = clocks + 1;
                if (clocks > 8) $fatal(1, "SRAM transaction timed out");
                if (clocks < 4 && ready)
                    $fatal(1, "SRAM completed before its access window");
            end
            if (clocks != 4)
                $fatal(1, "SRAM took %0d clocks, expected 4", clocks);
            req = 1'b0;
            we = 1'b0;
            @(negedge clk);
            @(negedge clk);
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        reset_n = 1'b1;

        transact(1'b1, 17'h01234, 2'b11, 16'hA55A);
        transact(1'b0, 17'h01234, 2'b11, 16'h0000);
        if (rdata !== 16'hA55A) $fatal(1, "full read returned %04x", rdata);

        transact(1'b1, 17'h01234, 2'b01, 16'h00CC);
        transact(1'b0, 17'h01234, 2'b11, 16'h0000);
        if (rdata !== 16'hA5CC) $fatal(1, "low lane returned %04x", rdata);

        transact(1'b1, 17'h01234, 2'b10, 16'h7700);
        transact(1'b0, 17'h01234, 2'b11, 16'h0000);
        if (rdata !== 16'h77CC) $fatal(1, "high lane returned %04x", rdata);

        if (!sram_oe_n || !sram_we_n || !sram_ub_n || !sram_lb_n)
            $fatal(1, "SRAM controls did not return idle");
        $finish;
    end

    initial begin
        #100_000;
        $fatal(1, "timed out");
    end
endmodule

`default_nettype wire
