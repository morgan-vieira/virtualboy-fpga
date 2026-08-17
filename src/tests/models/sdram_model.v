`timescale 1ns/1ps
//
// The part. Commands are sampled on its own clock -- the inverted copy the
// controller forwards -- and every rule it enforces is one a real device
// enforces by returning garbage instead.
//
module sdram_model #(
    parameter integer WORDS = 65536     // the window the bench addresses
) (
    input  wire        clk,
    input  wire [12:0] a,
    input  wire [1:0]  ba,
    inout  wire [15:0] dq,
    input  wire [1:0]  dqm,
    input  wire        cke,
    input  wire        ras_n,
    input  wire        cas_n,
    input  wire        we_n
);

    localparam [2:0] CMD_NOP       = 3'b111;
    localparam [2:0] CMD_ACTIVATE  = 3'b011;
    localparam [2:0] CMD_READ      = 3'b101;
    localparam [2:0] CMD_WRITE     = 3'b100;
    localparam [2:0] CMD_PRECHARGE = 3'b010;
    localparam [2:0] CMD_REFRESH   = 3'b001;
    localparam [2:0] CMD_LOAD_MODE = 3'b000;

    // -6 part timings, in nanoseconds.
    localparam real T_RCD = 18.0;
    localparam real T_RP  = 18.0;
    localparam real T_RFC = 72.0;
    localparam real T_AC  = 6.0;    // clock to data out
    localparam real T_REFI_MAX = 7812.5;

    reg [15:0] mem [0:WORDS-1];

    reg [12:0] row [0:3];
    reg        active [0:3];
    real       activated_at [0:3];
    real       precharged_at;
    real       refreshed_at;

    integer refreshes;
    reg      precharge_all_seen;
    reg      initialized;         // the mode register has been programmed

    reg        rd_v1, rd_v2;
    reg [15:0] rd_d1, rd_d2;
    reg        dq_oe;
    reg [15:0] dq_out;

    // tAC: the beat arrives late enough that a controller capturing on the
    // wrong edge sees the previous value or z.
    assign #(T_AC) dq = dq_oe ? dq_out : 16'hzzzz;

    wire [2:0] cmd = {ras_n, cas_n, we_n};

    integer b;
    reg [24:0] linear;

    initial begin
        for (b = 0; b < 4; b = b + 1) begin
            active[b] = 1'b0;
            row[b] = 13'd0;
            activated_at[b] = 0.0;
        end
        precharged_at = 0.0;
        refreshed_at = 0.0;
        refreshes = 0;
        precharge_all_seen = 1'b0;
        initialized = 1'b0;
        rd_v1 = 1'b0; rd_v2 = 1'b0;
        dq_oe = 1'b0; dq_out = 16'd0;
    end

    always @(posedge clk) begin
        // CAS latency 2: the beat driven now was requested two clocks ago.
        dq_oe  <= rd_v2;
        dq_out <= rd_d2;
        rd_v2  <= rd_v1;
        rd_d2  <= rd_d1;
        rd_v1  <= 1'b0;

        if (cmd !== CMD_NOP && cke !== 1'b1)
            $fatal(1, "sdram_model: command %03b issued with CKE low", cmd);

        case (cmd)
            CMD_LOAD_MODE: begin
                if (ba === 2'b00) begin
                    if (!precharge_all_seen)
                        $fatal(1, "sdram_model: mode register loaded before a precharge all");
                    if (refreshes < 8)
                        $fatal(1, "sdram_model: mode register loaded after only %0d refreshes, 8 required",
                               refreshes);
                    if (a[2:0] !== 3'd0)
                        $fatal(1, "sdram_model: burst length %0d, this controller must use 1",
                               a[2:0]);
                    if (a[3] !== 1'b0)
                        $fatal(1, "sdram_model: interleaved burst type requested");
                    if (a[6:4] !== 3'd2)
                        $fatal(1, "sdram_model: CAS latency %0d programmed, the model drives 2",
                               a[6:4]);
                    if (a[9] !== 1'b1)
                        $fatal(1, "sdram_model: burst writes requested, single-location required");
                    initialized <= 1'b1;
                end
                // ba 2'b10 is the mobile part's extended register; its
                // defaults are what the controller programs, so the model
                // takes it without comment.
            end

            CMD_PRECHARGE: begin
                if (a[10]) begin
                    for (b = 0; b < 4; b = b + 1) active[b] = 1'b0;
                    precharge_all_seen = 1'b1;
                end else begin
                    active[ba] = 1'b0;
                end
                precharged_at = $realtime;
            end

            CMD_REFRESH: begin
                for (b = 0; b < 4; b = b + 1)
                    if (active[b])
                        $fatal(1, "sdram_model: refresh with bank %0d still open", b);
                if ($realtime - precharged_at < T_RP)
                    $fatal(1, "sdram_model: refresh %0.1f ns after a precharge, tRP is %0.1f",
                           $realtime - precharged_at, T_RP);
                if (initialized && refreshes > 0
                    && $realtime - refreshed_at > T_REFI_MAX)
                    $fatal(1, "sdram_model: %0.1f ns between refreshes, the row budget is %0.1f",
                           $realtime - refreshed_at, T_REFI_MAX);
                refreshed_at = $realtime;
                refreshes = refreshes + 1;
            end

            CMD_ACTIVATE: begin
                if (!initialized)
                    $fatal(1, "sdram_model: row activated before initialization");
                if (active[ba])
                    $fatal(1, "sdram_model: bank %0d activated while already open", ba);
                if ($realtime - precharged_at < T_RP)
                    $fatal(1, "sdram_model: activate %0.1f ns after a precharge, tRP is %0.1f",
                           $realtime - precharged_at, T_RP);
                active[ba] = 1'b1;
                row[ba] = a;
                activated_at[ba] = $realtime;
            end

            CMD_READ, CMD_WRITE: begin
                if (!initialized)
                    $fatal(1, "sdram_model: column access before initialization");
                if (!active[ba])
                    $fatal(1, "sdram_model: column access to bank %0d with no row open", ba);
                if ($realtime - activated_at[ba] < T_RCD)
                    $fatal(1, "sdram_model: column access %0.1f ns after activate, tRCD is %0.1f",
                           $realtime - activated_at[ba], T_RCD);
                if (a[10])
                    $fatal(1, "sdram_model: auto precharge requested, this controller keeps rows open");

                linear = {row[ba], ba, a[9:0]};
                if (linear >= WORDS)
                    $fatal(1, "sdram_model: word %07x is outside the %0d word window",
                           linear, WORDS);

                if (cmd === CMD_READ) begin
                    if (dqm !== 2'b00)
                        $fatal(1, "sdram_model: read with DQM %02b, the beat would be masked",
                               dqm);
                    rd_v1 <= 1'b1;
                    rd_d1 <= mem[linear];
                end else begin
                    if (!dqm[0]) mem[linear][7:0]  = dq[7:0];
                    if (!dqm[1]) mem[linear][15:8] = dq[15:8];
                end
            end

            default: ;      // NOP
        endcase
    end

endmodule
