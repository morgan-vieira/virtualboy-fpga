`default_nettype none
//
// Controller for the Pocket's AS4C32M16MSA-6BIN mobile SDRAM: 64 MB as four
// banks of 8192 rows of 1024 halfwords, 1.8 V, good for 166 MHz
// [docs/analogue/external-hardware.md > 32Mx16 SDRAM].
//
// It runs in the CPU's own 39.936 MHz domain instead of on the PLL's spare
// 133 MHz outputs. The machine asks for one halfword at a time and charges
// the cartridge two wait states for it -- 150 ns -- so the bandwidth a fast
// clock buys has nowhere to go on this bus, while the clock crossing it
// costs would spend most of the latency it saved. At 25.04 ns every device
// timing collapses to one to four clocks and the pin margins stop being
// interesting, which is the only failure mode here that hardware sees first.
//
// The board ties CS low, so DESELECT does not exist: every clock the part
// samples is a command, and idle means NOP.
//
// One row stays open until another row, a refresh or reset closes it. That
// is what makes sequential fetch cheap -- a hit is READ plus CAS, a miss
// adds PRECHARGE and ACTIVATE ahead of it.
//
// Timing contract, matching what block RAM gives the rest of the bus: the
// requester holds req and its payload until ready, and changes or drops
// them the cycle after. ready is high for one cycle and rdata carries the
// answer the cycle after that, then holds. There is deliberately no release
// phase waiting for req to fall the way pocket_sram has one: the CPU issues
// a word access's two halves back to back, and a release phase turns that
// into the deadlock recorded against vip_draw.
//
// The clock the part sees is not driven here. core_top forwards an inverted
// copy of clk to the dram_clk pin through an output DDIO cell, so the SDRAM
// samples our commands half a period after we launch them and drives read
// data half a period before we capture it. Modeling that inverted pin clock
// is also what src/tests/pocket_sdram.v clocks its device model on.
//
// That capture is the tightest path in the whole core, and it is worth
// knowing why before touching it. The beat is valid from tAC after the pin
// clock's edge until tOH after the next one, and the rising edge that ends
// the second CAS cycle is the only one of ours inside that window -- half a
// period early is before the data arrives, half a period late is past the
// hold. So the budget is exactly the half period, 12.52 ns, and the fit
// spends it as 6.0 ns of assumed tAC, 3.34 ns of clock skew and 2.84 ns of
// pin-to-register routing, leaving 0.169 ns at the slow 85 C corner
// (measured 2026-08-17, TNS zero). It passes, but it is thin, and the tAC is
// borrowed from MiSTer's numbers rather than read off this part's datasheet.
//
// If hardware ever reads garbage from the cartridge while everything else
// works, this is the first suspect, and the fix is to capture into an
// unconditional register that Quartus can pack into the I/O cell and move
// rdata a clock later. That buys about 2.8 ns and costs one clock on every
// read, which puts a page hit at five and breaks the one-wait budget below.
// Asking the fitter for the packing without the restructure does nothing:
// the capture has a clock enable, and Quartus declines it silently.
//

module pocket_sdram (
    input  wire logic        clk,

    // Released once the PLL locks, and never by the core reset: APF holds
    // the core in reset for the whole of every cartridge load, and the
    // loader writes through here while it does.
    input  wire logic        reset_n,

    input  wire logic        req,
    input  wire logic [24:0] addr,      // halfword address into the part
    input  wire logic        we,
    input  wire logic [1:0]  be,        // be[0] low byte, little-endian
    input  wire logic [15:0] wdata,
    output logic     [15:0]  rdata,
    output logic             ready,

    output logic     [12:0]  dram_a,
    output logic     [1:0]   dram_ba,
    inout  wire      [15:0]  dram_dq,
    output logic     [1:0]   dram_dqm,   // [1] upper byte, [0] lower
    output logic             dram_cke,
    output logic             dram_ras_n,
    output logic             dram_cas_n,
    output logic             dram_we_n
);

    // Device timings in clocks at 25.04 ns, each rounded up from the -6
    // part's nanoseconds. A count of zero means the next command may issue
    // on the very next clock, which is where tRP and tRCD land: both are
    // 18 ns, and one clock already covers them.
    localparam int unsigned T_INIT  = 8000; // 200 us of stable clock and CKE
    localparam int unsigned T_RP    = 0;    // precharge to activate, 18 ns
    localparam int unsigned T_RCD   = 0;    // activate to read/write, 18 ns
    localparam int unsigned T_RFC   = 3;    // refresh to command, 72 ns
    localparam int unsigned T_MRD   = 1;    // mode register to command
    localparam int unsigned T_WR    = 1;    // write recovery, 12 ns
    localparam int unsigned INIT_REFRESHES = 8;

    // 8192 rows every 64 ms is one every 7.8125 us; 7.5 us of clocks leaves
    // the slack for an access already in flight when the timer expires.
    localparam int unsigned T_REFI = 300;

    // Mode register: burst length 1 (A2:0), sequential (A3), CAS latency 2
    // (A6:4 -- legal at or below 100 MHz), standard operation (A8:7), and
    // single-location writes (A9) so a write is one halfword rather than a
    // burst.
    localparam logic [12:0] MODE_REG = 13'b0_00_1_00_010_0_000;

    // Mobile parts carry a second register that a plain SDR part does not,
    // and docs/analogue/external-hardware.md warns to program it. Zeros are
    // full-array refresh, 70 C temperature compensation and full drive
    // strength -- the power-up defaults, so if this part disagreed about
    // BA=10 selecting it, the command lands on values it already holds.
    localparam logic [12:0] EXT_MODE_REG = 13'd0;

    // {ras_n, cas_n, we_n}, with CS tied low on the board.
    localparam logic [2:0] CMD_NOP       = 3'b111;
    localparam logic [2:0] CMD_ACTIVATE  = 3'b011;
    localparam logic [2:0] CMD_READ      = 3'b101;
    localparam logic [2:0] CMD_WRITE     = 3'b100;
    localparam logic [2:0] CMD_PRECHARGE = 3'b010;
    localparam logic [2:0] CMD_REFRESH   = 3'b001;
    localparam logic [2:0] CMD_LOAD_MODE = 3'b000;

    typedef enum logic [3:0] {
        INIT_WAIT,
        INIT_PRECHARGE,
        INIT_REFRESH,
        INIT_MODE,
        INIT_EXT_MODE,
        IDLE,
        ACTIVATE,
        ACCESS,
        WRITE_RECOVER,
        REFRESH_PRECHARGE,
        REFRESH
    } state_t;

    state_t state;

    // Every state that issues a command sets delay to the clocks of NOP that
    // must follow it; the machine only advances once it drains.
    logic [12:0] delay;

    logic [15:0] refresh_timer;
    logic        refresh_due;
    logic [3:0]  init_refreshes;

    // The open row, and the request the machine latched.
    logic        row_open;
    logic [1:0]  open_bank;
    logic [12:0] open_row;

    logic [24:0] addr_q;
    logic        we_q;
    logic [1:0]  be_q;
    logic [15:0] wdata_q;
    logic        dq_drive;

    // CAS latency 2, walked one-hot from the clock that puts READ on the
    // pins. The part samples that command half a period later and drives the
    // beat two of its own clocks after that, so the pin is captured at the
    // edge ending the second cycle -- and ready leads the capture by one,
    // because the requester reads rdata the cycle after it sees ready.
    logic [2:0] cas_pipe;

    wire logic [9:0]  req_col  = addr_q[9:0];
    wire logic [1:0]  req_bank = addr_q[11:10];
    wire logic [12:0] req_row  = addr_q[24:12];

    // A request that lands on the open row is issued from IDLE, in the same
    // clock it is latched, so a page hit costs four clocks end to end -- the
    // machine's one-wait cartridge budget. That is why the hit is decided
    // against the incoming address rather than the latched one, and why a
    // column command takes its address from whichever of the two is current.
    wire logic row_hit = row_open && open_bank == addr[11:10]
                      && open_row == addr[24:12];

    wire logic [1:0]  cmd_bank = state == IDLE ? addr[11:10] : req_bank;
    wire logic [9:0]  cmd_col  = state == IDLE ? addr[9:0]   : req_col;
    wire logic        cmd_we   = state == IDLE ? we          : we_q;
    wire logic [1:0]  cmd_be   = state == IDLE ? be          : be_q;

    assign dram_dq = dq_drive ? wdata_q : 16'hzzzz;

    // Set by whichever state decides this clock issues a column command.
    logic column;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state          <= INIT_WAIT;
            delay          <= T_INIT[12:0];
            refresh_timer  <= '0;
            refresh_due    <= 1'b0;
            init_refreshes <= '0;
            row_open       <= 1'b0;
            open_bank      <= '0;
            open_row       <= '0;
            addr_q         <= '0;
            we_q           <= 1'b0;
            be_q           <= '0;
            wdata_q        <= '0;
            dq_drive       <= 1'b0;
            cas_pipe       <= '0;
            rdata          <= '0;
            ready          <= 1'b0;
            dram_a         <= '0;
            dram_ba        <= '0;
            dram_dqm       <= 2'b00;
            dram_cke       <= 1'b0;
            {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_NOP;
        end else begin
            column = 1'b0;
            {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_NOP;
            dram_cke <= 1'b1;
            dq_drive <= 1'b0;
            ready    <= 1'b0;

            // The refresh timer runs against the row budget regardless of
            // what the machine is doing; the flag is cleared when one issues.
            if (refresh_timer == T_REFI[15:0]) begin
                refresh_timer <= '0;
                refresh_due   <= 1'b1;
            end else begin
                refresh_timer <= refresh_timer + 16'd1;
            end

            // A read in flight owns its CAS cycles, and nothing else may
            // issue during them -- a refresh's precharge would close the row
            // out from under the beat.
            if (cas_pipe[2]) begin
                cas_pipe <= 3'b010;
            end else if (cas_pipe[1]) begin
                cas_pipe <= 3'b001;
                ready    <= 1'b1;
            end else if (cas_pipe[0]) begin
                cas_pipe <= 3'b000;
                rdata    <= dram_dq;
            end

            if (delay != 13'd0) begin
                delay <= delay - 13'd1;
            end else if (cas_pipe == 3'b000) begin
                unique case (state)
                    INIT_WAIT: begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_PRECHARGE;
                        dram_a <= 13'h0400;     // A10 high: every bank
                        delay  <= T_RP[12:0];
                        state  <= INIT_PRECHARGE;
                    end

                    INIT_PRECHARGE, INIT_REFRESH: begin
                        if (init_refreshes == INIT_REFRESHES[3:0]) begin
                            {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_LOAD_MODE;
                            dram_ba <= 2'b00;
                            dram_a  <= MODE_REG;
                            delay   <= T_MRD[12:0];
                            state   <= INIT_MODE;
                        end else begin
                            {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_REFRESH;
                            init_refreshes <= init_refreshes + 4'd1;
                            delay          <= T_RFC[12:0];
                            state          <= INIT_REFRESH;
                        end
                    end

                    INIT_MODE: begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_LOAD_MODE;
                        dram_ba <= 2'b10;       // the extended register
                        dram_a  <= EXT_MODE_REG;
                        delay   <= T_MRD[12:0];
                        state   <= INIT_EXT_MODE;
                    end

                    INIT_EXT_MODE: begin
                        refresh_due <= 1'b0;
                        state       <= IDLE;
                    end

                    // Refresh outranks a waiting request, so a stream of
                    // accesses can never starve the array.
                    IDLE: begin
                        if (refresh_due) begin
                            {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_PRECHARGE;
                            dram_a   <= 13'h0400;
                            row_open <= 1'b0;
                            delay    <= T_RP[12:0];
                            state    <= REFRESH_PRECHARGE;
                        end else if (req) begin
                            addr_q  <= addr;
                            we_q    <= we;
                            be_q    <= be;
                            wdata_q <= wdata;
                            if (row_hit) begin
                                column = 1'b1;
                            end else if (row_open) begin
                                {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_PRECHARGE;
                                dram_a   <= 13'h0400;
                                row_open <= 1'b0;
                                delay    <= T_RP[12:0];
                                state    <= ACTIVATE;
                            end else begin
                                {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_ACTIVATE;
                                dram_ba   <= addr[11:10];
                                dram_a    <= addr[24:12];
                                row_open  <= 1'b1;
                                open_bank <= addr[11:10];
                                open_row  <= addr[24:12];
                                delay     <= T_RCD[12:0];
                                state     <= ACCESS;
                            end
                        end
                    end

                    // Reached only after a precharge closed a foreign row, so
                    // the request is already latched.
                    ACTIVATE: begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_ACTIVATE;
                        dram_ba   <= req_bank;
                        dram_a    <= req_row;
                        row_open  <= 1'b1;
                        open_bank <= req_bank;
                        open_row  <= req_row;
                        delay     <= T_RCD[12:0];
                        state     <= ACCESS;
                    end

                    ACCESS: column = 1'b1;

                    WRITE_RECOVER: state <= IDLE;

                    REFRESH_PRECHARGE: begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_REFRESH;
                        refresh_due <= 1'b0;
                        delay       <= T_RFC[12:0];
                        state       <= REFRESH;
                    end

                    REFRESH: state <= IDLE;

                    default: state <= IDLE;
                endcase

                // The one place a column command is issued, entered either
                // straight from IDLE on a page hit or from ACCESS once a row
                // was opened for it. A10 stays low so the row survives for
                // whatever comes next.
                if (column) begin
                    dram_ba <= cmd_bank;
                    dram_a  <= {3'b000, cmd_col};
                    if (cmd_we) begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_WRITE;
                        dram_dqm <= ~cmd_be;
                        dq_drive <= 1'b1;
                        ready    <= 1'b1;
                        delay    <= T_WR[12:0];
                        state    <= WRITE_RECOVER;
                    end else begin
                        {dram_ras_n, dram_cas_n, dram_we_n} <= CMD_READ;
                        dram_dqm <= 2'b00;
                        cas_pipe <= 3'b100;
                        state    <= IDLE;
                    end
                end
            end
        end
    end

endmodule

`default_nettype wire
