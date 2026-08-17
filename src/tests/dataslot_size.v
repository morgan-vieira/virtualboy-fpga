`timescale 1ns/1ps
//
// The size table walk, against a model of the table APF and the core share.
//
// The model matches mf_datatable's port A where it matters: 256 words of 32
// bits, and a read that is two clocks behind its address because both the
// address and the output are registered. A walk that trusted the data one
// clock early would compare against the previous entry and write the size
// onto somebody else's file, which is the failure worth catching here --
// this module's whole job is to name a number that the Pocket then writes to
// the SD card.
//

module dataslot_size_tb;

    reg clk = 1'b0;
    always #6.7 clk = ~clk;

    reg         start = 1'b0;
    reg  [31:0] bytes = 32'd8192;
    wire [9:0]  table_addr;
    wire        table_wren;
    wire [31:0] table_data;
    reg  [31:0] table_q;

    dataslot_size #(.SLOT_ID(16'd1)) dut (
        .clk(clk),
        .start(start),
        .bytes(bytes),
        .table_addr(table_addr),
        .table_wren(table_wren),
        .table_data(table_data),
        .table_q(table_q)
    );

    // The table, and the two registers between its address and its answer.
    reg [31:0] dt [0:255];
    reg [31:0] q1;
    always @(posedge clk) begin
        if (table_wren) dt[table_addr[7:0]] <= table_data;
        q1      <= dt[table_addr[7:0]];
        table_q <= q1;
    end

    integer i;
    integer writes;

    // Every write the walk makes, so a stray one cannot hide behind a
    // correct one.
    always @(posedge clk) if (table_wren) writes = writes + 1;

    task automatic load_table;
        begin
            for (i = 0; i < 256; i = i + 1) dt[i] = 32'd0;
            // Entry 0 is the cartridge: 2MB, as APF loaded it.
            dt[0] = 32'h0000_0000;
            dt[1] = 32'd2097152;
            // Entry 1 is the save. Its file does not exist, so APF wrote zero.
            dt[2] = 32'h0000_0001;
            dt[3] = 32'd0;
        end
    endtask

    task automatic run_walk;
        begin
            writes = 0;
            @(negedge clk);
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;
            repeat (400) @(negedge clk);
        end
    endtask

    initial begin
        load_table();
        run_walk();

        if (dt[3] !== 32'd8192)
            $fatal(1, "save entry size is %0d, expected 8192", dt[3]);
        if (dt[1] !== 32'd2097152)
            $fatal(1, "cartridge entry size became %0d; wrong entry", dt[1]);
        if (dt[2] !== 32'h0000_0001)
            $fatal(1, "the save entry's id word was overwritten with %08x", dt[2]);
        if (writes !== 1)
            $fatal(1, "the walk made %0d writes, expected exactly 1", writes);

        // A later load with a smaller save narrows it again.
        bytes = 32'd4096;
        run_walk();
        if (dt[3] !== 32'd4096)
            $fatal(1, "a second walk left the size at %0d, expected 4096", dt[3]);
        if (writes !== 1)
            $fatal(1, "the second walk made %0d writes, expected exactly 1", writes);

        // The entry can sit anywhere in the table; the walk is a search.
        load_table();
        dt[2]  = 32'h0000_00AA;   // some other slot where the save used to be
        dt[3]  = 32'd64;
        dt[40] = 32'h0000_0001;   // the save, at entry 20
        dt[41] = 32'd0;
        bytes  = 32'd8192;
        run_walk();
        if (dt[41] !== 32'd8192)
            $fatal(1, "the save at entry 20 has size %0d, expected 8192", dt[41]);
        if (dt[3] !== 32'd64)
            $fatal(1, "entry 1 was resized to %0d; it is not ours", dt[3]);

        // No such slot: the walk runs off the end and writes nothing at all.
        load_table();
        dt[2] = 32'h0000_0002;
        run_walk();
        if (writes !== 0)
            $fatal(1, "the walk wrote %0d times with no matching slot", writes);

        $display("dataslot_size: PASS");
        $finish;
    end

    initial begin
        #2_000_000;
        $fatal(1, "timed out");
    end

endmodule
