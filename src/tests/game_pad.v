`timescale 1ns/1ps
//
// Exercises the game pad through its bus registers, and the Pocket mapping
// that feeds it, against absolute architectural time. ce fires every second
// clock and ce_count counts the same pulses the bit divider sees, so the
// 512 us read is knowable in advance rather than merely plausible: the
// sixteenth bit may only land 10,240 ce after the start, never one sooner.
//
// The checks follow TODO section 7 line by line: the sixteen documented bit
// positions arriving in the documented registers, SCR's readback with its
// always-set bits and live SI-Stat, the hardware read's duration and busy
// window, an abort taken immediately and one that blocks a start, the
// software read's inverted clock and its sixteen advancing edges, the latch
// that rewinds a report in flight, the data registers holding rather than
// tearing until the sixteenth bit, the key interrupt raised only by a
// report a standard controller cannot produce and acknowledged only by the
// inhibit bit, the byte-lane and mirroring rules, and both settings of the
// Pocket mapping.
//

module game_pad_tb;

    reg clk = 1'b0;
    always #5 clk = ~clk;

    // ce as a tick, not a clock: every second cycle, nothing like the
    // hardware's 625/1248 -- the pad may only count pulses.
    reg ce = 1'b0;
    always @(posedge clk) ce <= ~ce;

    integer ce_count = 0;

    reg         reset_n = 1'b0;
    reg         sel = 1'b0;
    reg  [26:1] a = 26'd0;
    reg         we = 1'b0;
    reg  [1:0]  be = 2'b00;
    reg  [15:0] wd = 16'd0;
    reg  [15:0] buttons = 16'h0002;
    wire [15:0] rdata;
    wire        irq;

    game_pad dut (
        .clk(clk),
        .reset_n(reset_n),
        .ce(ce),
        .sel(sel),
        .addr(a),
        .we(we),
        .be(be),
        .wdata(wd),
        .rdata(rdata),
        .buttons(buttons),
        .irq(irq)
    );

    always @(posedge clk) if (reset_n && ce) ce_count = ce_count + 1;

    localparam [26:1] SDLR = {3'd2, 16'h0000, 7'h08};   // 0x02000010
    localparam [26:1] SDHR = {3'd2, 16'h0000, 7'h0A};   // 0x02000014
    localparam [26:1] SCR  = {3'd2, 16'h0000, 7'h14};   // 0x02000028

    // SCR's fields, as the scroll names them.
    localparam [7:0] K_INT_INH = 8'h80;
    localparam [7:0] PARA_SI   = 8'h20;
    localparam [7:0] SOFT_CK   = 8'h10;
    localparam [7:0] HW_SI     = 8'h04;
    localparam [7:0] S_ABT_DIS = 8'h01;

    // SCR's read-only furniture: HW-SI and both unused bits always set.
    localparam [15:0] SCR_FIXED = 16'h004c;

    // A standard controller always sets SGN, and never the battery bit
    // here -- the Pocket's battery does not reach the core.
    localparam [15:0] SGN = 16'h0002;

    localparam integer READ_CE = 10240;   // 512 us of architectural time

    // ------------------------------------------------------------------
    // Bus plumbing, mem_bus device shape: sel one clock, answer the next.
    // ------------------------------------------------------------------

    task automatic bus_write(input [26:1] address, input [1:0] lanes,
                             input [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b1; a = address; be = lanes; wd = value;
            @(negedge clk);
            sel = 1'b0; we = 1'b0; wd = 16'hxxxx;
        end
    endtask

    // A register write the way software does it: byte store, low lane.
    // The high lane carries x so a lane leak lands as x, never as luck.
    task automatic write8(input [26:1] address, input [7:0] value);
        bus_write(address, 2'b01, {8'hxx, value});
    endtask

    task automatic read16(input [26:1] address, output [15:0] value);
        begin
            @(negedge clk);
            sel = 1'b1; we = 1'b0; a = address; wd = 16'hxxxx;
            @(negedge clk);
            sel = 1'b0;
            #1;
            value = rdata;
        end
    endtask

    task automatic expect16(input [26:1] address, input [15:0] expected,
                            input string what);
        reg [15:0] value;
        begin
            read16(address, value);
            if (value !== expected)
                $fatal(1, "%0s: addr %07x read %04x, expected %04x",
                       what, address, value, expected);
        end
    endtask

    // The whole report as software sees it, through both halves.
    task automatic expect_report(input [15:0] expected, input string what);
        reg [15:0] lo, hi;
        begin
            read16(SDLR, lo);
            read16(SDHR, hi);
            if ({hi[7:0], lo[7:0]} !== expected)
                $fatal(1, "%0s: report %04x, expected %04x",
                       what, {hi[7:0], lo[7:0]}, expected);
            if (hi[15:8] !== 8'h00 || lo[15:8] !== 8'h00)
                $fatal(1, "%0s: high byte not zero (%04x %04x)",
                       what, hi, lo);
        end
    endtask

    task automatic expect_irq(input v, input string what);
        if (irq !== v)
            $fatal(1, "%0s: irq is %b, expected %b", what, irq, v);
    endtask

    task automatic expect_busy(input v, input string what);
        if (dut.busy !== v)
            $fatal(1, "%0s: busy is %b, expected %b", what, dut.busy, v);
    endtask

    // ------------------------------------------------------------------
    // Read sequencing
    // ------------------------------------------------------------------

    integer mark    = 0;
    integer elapsed = 0;

    // Start a hardware read and note the architectural instant it began.
    task automatic hw_read_start;
        begin
            write8(SCR, HW_SI);
            mark = ce_count;
        end
    endtask

    // Run one out to completion and pin its length. Anything that finishes
    // early or late is a broken divider, not a rounding difference.
    task automatic hw_read_finish(input string what);
        begin
            while (dut.busy) @(negedge clk);
            elapsed = ce_count - mark;
            if (elapsed !== READ_CE)
                $fatal(1, "%0s: read took %0d ce, expected %0d",
                       what, elapsed, READ_CE);
        end
    endtask

    task automatic hw_read(input [15:0] pad, input string what);
        begin
            buttons = pad;
            hw_read_start();
            hw_read_finish(what);
        end
    endtask

    // Sixteen advancing edges of the software clock. The written bit is
    // inverted on the way to the pad, so the report advances when the
    // written bit falls -- which is why the high write comes first.
    task automatic soft_clock(input integer edges);
        integer n;
        begin
            for (n = 0; n < edges; n = n + 1) begin
                write8(SCR, SOFT_CK);
                write8(SCR, 8'h00);
            end
        end
    endtask

    // Latch, then clock the whole report out by hand. The pad is set
    // before the latch, because the latch is when it gets sampled.
    task automatic soft_read(input [15:0] pad);
        begin
            buttons = pad;
            write8(SCR, PARA_SI);
            write8(SCR, 8'h00);
            soft_clock(16);
        end
    endtask

    // ------------------------------------------------------------------
    // The Pocket mapping, under its own instance.
    // ------------------------------------------------------------------

    reg  [15:0] map_key = 16'h0000;
    reg  [1:0]  map_cfg = 2'b00;
    wire [15:0] map_buttons;

    host_pad_map map_dut (
        .key(map_key),
        .cfg(map_cfg),
        .buttons(map_buttons)
    );

    task automatic expect_map(input [15:0] key_in, input [1:0] cfg_in,
                              input [15:0] expected, input string what);
        begin
            map_key = key_in;
            map_cfg = cfg_in;
            #1;
            if (map_buttons !== expected)
                $fatal(1, "%0s: key %04x cfg %b mapped to %04x, expected %04x",
                       what, key_in, cfg_in, map_buttons, expected);
        end
    endtask

    // The report bits, by the scroll's numbering.
    localparam [15:0] RD  = 16'h8000, RL  = 16'h4000;
    localparam [15:0] SEL = 16'h2000, STA = 16'h1000;
    localparam [15:0] LU  = 16'h0800, LD  = 16'h0400;
    localparam [15:0] LL  = 16'h0200, LR  = 16'h0100;
    localparam [15:0] RR  = 16'h0080, RU  = 16'h0040;
    localparam [15:0] LT  = 16'h0020, RT  = 16'h0010;
    localparam [15:0] BTN_B = 16'h0008, BTN_A = 16'h0004;

    // The Pocket's key bitmap, in the APF layout core_top documents.
    localparam [15:0] K_UP = 16'h0001, K_DOWN = 16'h0002;
    localparam [15:0] K_LEFT = 16'h0004, K_RIGHT = 16'h0008;
    localparam [15:0] K_A = 16'h0010, K_B = 16'h0020;
    localparam [15:0] K_X = 16'h0040, K_Y = 16'h0080;
    localparam [15:0] K_L = 16'h0100, K_R = 16'h0200;
    localparam [15:0] K_SELECT = 16'h4000, K_START = 16'h8000;

    integer i = 0;
    reg [15:0] scr;

    initial begin
        $dumpfile("game_pad.vcd");
        $dumpvars(0, game_pad_tb);

        repeat (4) @(negedge clk);
        reset_n = 1'b1;
        repeat (4) @(negedge clk);

        // --------------------------------------------------------------
        // 1. Reset: every SCR field zero, both data registers zero, and
        //    the read-only furniture already standing.
        // --------------------------------------------------------------
        expect_report(16'h0000, "reset report");
        expect16(SCR, SCR_FIXED, "reset SCR");
        expect_irq(1'b0, "reset irq");
        expect_busy(1'b0, "reset busy");

        // --------------------------------------------------------------
        // 2. A hardware read takes exactly 512 us. SI-Stat is set for the
        //    whole window, and the report lands on the last cycle of it --
        //    before that the data registers hold the previous report
        //    rather than a torn one.
        // --------------------------------------------------------------
        buttons = 16'ha5a5 | SGN;
        hw_read_start();
        expect_busy(1'b1, "busy after start");
        read16(SCR, scr);
        if (scr !== (SCR_FIXED | 16'h0002))
            $fatal(1, "SI-Stat during a read: SCR %04x", scr);

        while (ce_count < mark + READ_CE / 2) @(negedge clk);
        expect_busy(1'b1, "busy halfway");
        expect_report(16'h0000, "report held halfway");

        while (ce_count < mark + READ_CE - 1) @(negedge clk);
        expect_busy(1'b1, "busy on the last bit");
        if (dut.data !== 16'h0000)
            $fatal(1, "report committed a cycle early: %04x", dut.data);

        hw_read_finish("first hardware read");
        expect_report(16'ha5a5 | SGN, "report after a hardware read");
        expect16(SCR, SCR_FIXED, "SI-Stat clear once the read is done");

        // --------------------------------------------------------------
        // 3. Each of the sixteen documented bits arrives on its own, in
        //    the half the scroll puts it in, and disturbs no other bit.
        // --------------------------------------------------------------
        for (i = 0; i < 16; i = i + 1) begin
            hw_read(16'h0001 << i, "single-bit report");
            expect16(SDLR, (16'h0001 << i) & 16'h00ff, "SDLR holds bits 7:0");
            expect16(SDHR, (16'h0001 << i) >> 8, "SDHR holds bits 15:8");
        end

        // Most of those reports satisfy the key interrupt, which check 8
        // owns. Housekeeping, not a check: put the line back down.
        write8(SCR, K_INT_INH);
        write8(SCR, 8'h00);
        expect_irq(1'b0, "the line is clear before the interrupt checks");

        // --------------------------------------------------------------
        // 4. HW-SI during a read has no effect: the read still ends
        //    10,240 ce after the first write, carrying the pad as it stood
        //    at that write rather than at the second.
        // --------------------------------------------------------------
        buttons = 16'h1234 | SGN;
        hw_read_start();
        while (ce_count < mark + 3000) @(negedge clk);
        buttons = 16'h4321 | SGN;
        write8(SCR, HW_SI);
        hw_read_finish("a second HW-SI must not restart the read");
        expect_report(16'h1234 | SGN, "the pad is sampled at the start");

        // --------------------------------------------------------------
        // 5. S-Abt/Dis cancels at once, commits nothing, and blocks a
        //    start for as long as it stays set.
        // --------------------------------------------------------------
        buttons = 16'h0f0f | SGN;
        hw_read_start();
        while (ce_count < mark + 4000) @(negedge clk);
        write8(SCR, S_ABT_DIS);
        expect_busy(1'b0, "an abort cancels immediately");
        expect_report(16'h1234 | SGN, "an aborted read commits nothing");

        write8(SCR, S_ABT_DIS | HW_SI);
        expect_busy(1'b0, "a standing abort bit blocks a start");
        write8(SCR, 8'h00);
        write8(SCR, HW_SI | S_ABT_DIS);
        expect_busy(1'b0, "start and abort in one write run nothing");

        // That write left the abort bit standing, so the start still has
        // to wait for a write that clears it.
        write8(SCR, HW_SI);
        expect_busy(1'b0, "the abort bit outlives the write that set it");
        write8(SCR, 8'h00);
        write8(SCR, HW_SI);
        expect_busy(1'b1, "a start lands once the abort bit is clear");
        write8(SCR, S_ABT_DIS);
        write8(SCR, 8'h00);
        expect_busy(1'b0, "aborted again");

        // --------------------------------------------------------------
        // 6. The software read: a latch, then sixteen falling edges of the
        //    written clock bit. Nothing lands before the sixteenth.
        // --------------------------------------------------------------
        buttons = 16'hc3c3 | SGN;
        write8(SCR, PARA_SI);
        write8(SCR, 8'h00);
        soft_clock(15);
        expect_report(16'h1234 | SGN, "nothing lands before the 16th bit");
        soft_clock(1);
        expect_report(16'hc3c3 | SGN, "report after a software read");

        // Past sixteen, edges do nothing until the next latch.
        buttons = 16'h5555 | SGN;
        soft_clock(16);
        expect_report(16'hc3c3 | SGN, "edges past the 16th are ignored");

        // The latch is when the pad is sampled: a press landing after it
        // belongs to the next report, not this one.
        buttons = 16'h00ff | SGN;
        write8(SCR, PARA_SI);
        buttons = 16'hffff;
        write8(SCR, 8'h00);
        soft_clock(16);
        expect_report(16'h00ff | SGN, "the latch samples the pad");

        // Holding the bit set is not an edge, however many writes land;
        // sixteen falls complete the report whichever way they are paired.
        buttons = 16'h0ff0 | SGN;
        write8(SCR, PARA_SI);
        write8(SCR, 8'h00);
        repeat (8) write8(SCR, SOFT_CK);
        expect_report(16'h00ff | SGN, "a held clock bit never advances");
        for (i = 0; i < 16; i = i + 1) begin
            write8(SCR, 8'h00);
            write8(SCR, SOFT_CK);
        end
        expect_report(16'h0ff0 | SGN, "sixteen falls complete the report");

        // The scroll counts this one procedure twice -- "alternating
        // states for Soft-Ck 16 times" and "a total of 33 writes" -- and
        // both describe the same thing: one write to raise the bit, then
        // sixteen fall-and-raise pairs, with the last raise clocking
        // nothing. The report advances on the falls, because the written
        // bit is inverted and the pad advances on its own rising edge.
        // Stopping on a raised bit is what tells the two polarities apart:
        // fifteen falls have to leave the report short even though sixteen
        // raises have gone by.
        buttons = 16'h6a6a | SGN;
        write8(SCR, PARA_SI);
        write8(SCR, 8'h00);
        write8(SCR, SOFT_CK);                       // write 1 of 33
        for (i = 0; i < 15; i = i + 1) begin
            write8(SCR, 8'h00);                     // a fall: one bit
            write8(SCR, SOFT_CK);
        end
        expect_report(16'h0ff0 | SGN, "fifteen falls leave the report short");
        write8(SCR, 8'h00);                         // the sixteenth fall
        expect_report(16'h6a6a | SGN, "the sixteenth fall completes it");
        write8(SCR, SOFT_CK);                       // write 33 of 33
        expect_report(16'h6a6a | SGN, "the last raise clocks nothing");
        write8(SCR, 8'h00);

        // A latch left standing resets the read over and over, which is
        // exactly what the scroll warns about.
        buttons = 16'h1111 | SGN;
        write8(SCR, PARA_SI);
        for (i = 0; i < 16; i = i + 1) begin
            write8(SCR, PARA_SI | SOFT_CK);
            write8(SCR, PARA_SI);
        end
        expect_report(16'h6a6a | SGN, "a standing latch blocks the read");
        write8(SCR, 8'h00);

        // Neither software handle reaches the pad while hardware owns it.
        buttons = 16'h7777 | SGN;
        hw_read_start();
        while (ce_count < mark + 2000) @(negedge clk);
        write8(SCR, PARA_SI);
        write8(SCR, 8'h00);
        soft_clock(16);
        hw_read_finish("software writes must not disturb a hardware read");
        expect_report(16'h7777 | SGN, "hardware owns the pad while busy");

        // --------------------------------------------------------------
        // 7. SCR's four writable fields read back; its fixed bits stay
        //    fixed whatever is written over them.
        // --------------------------------------------------------------
        write8(SCR, K_INT_INH | PARA_SI | SOFT_CK | S_ABT_DIS);
        expect16(SCR, SCR_FIXED | 16'h00b1, "SCR readback");
        write8(SCR, 8'h00);
        expect16(SCR, SCR_FIXED, "SCR readback cleared");

        // --------------------------------------------------------------
        // 8. The key interrupt. Its condition is bits 15:4 with any set
        //    and bits 3:1 with none, and a standard controller always sets
        //    SGN -- so no report it can produce raises one, single button
        //    or every button.
        // --------------------------------------------------------------
        for (i = 0; i < 16; i = i + 1) begin
            hw_read((16'h0001 << i) | SGN, "standard single button");
            expect_irq(1'b0, "SGN suppresses the key interrupt");
        end
        hw_read(16'hffff, "every bit set");
        expect_irq(1'b0, "bits 3:1 suppress even with everything pressed");

        // Drop the low bits and the same rule fires.
        hw_read(16'h0010, "a report no standard controller can produce");
        expect_irq(1'b1, "the key interrupt fires");

        // Only the inhibit bit acknowledges: not a read, not another read.
        read16(SCR, scr);
        expect_irq(1'b1, "reading SCR acknowledges nothing");
        hw_read(16'h0000, "a quiet report");
        expect_irq(1'b1, "a later read acknowledges nothing");
        write8(SCR, K_INT_INH);
        expect_irq(1'b0, "the inhibit bit acknowledges");

        // Inhibited, the same report raises nothing.
        buttons = 16'h0010;
        write8(SCR, K_INT_INH | HW_SI);
        mark = ce_count;
        hw_read_finish("inhibited read");
        expect_irq(1'b0, "an inhibited read raises nothing");
        write8(SCR, 8'h00);

        // Bit 0 is outside the suppressing range; bits 3 through 1 are in
        // it, one at a time; and with nothing in 15:4 there is nothing to
        // raise in the first place.
        hw_read(16'h0011, "bit 0 set alongside");
        expect_irq(1'b1, "bit 0 does not suppress");
        write8(SCR, K_INT_INH);
        write8(SCR, 8'h00);
        for (i = 1; i <= 3; i = i + 1) begin
            hw_read(16'h0010 | (16'h0001 << i), "a suppressing bit");
            expect_irq(1'b0, "bits 3:1 suppress");
        end
        hw_read(16'h0008, "nothing in 15:4");
        expect_irq(1'b0, "an empty upper range raises nothing");

        // A completed software read raises nothing at all: the scroll
        // conditions the interrupt on a hardware read.
        soft_read(16'h8000);
        expect_report(16'h8000, "a software read still lands");
        expect_irq(1'b0, "a software read raises no interrupt");

        // --------------------------------------------------------------
        // 9. Register access rules: the data registers are read-only, a
        //    write without byte lane 0 is not a write, and the block
        //    mirrors every 0x100 through the region.
        // --------------------------------------------------------------
        write8(SDLR, 8'hff);
        write8(SDHR, 8'hff);
        expect_report(16'h8000, "the data registers are read-only");

        bus_write(SCR, 2'b10, {HW_SI, 8'hxx});
        expect_busy(1'b0, "byte lane 1 alone is not a write");

        buttons = 16'h2222 | SGN;
        write8({3'd2, 16'h0003, 7'h14}, HW_SI);     // 0x02000328
        expect_busy(1'b1, "the block mirrors every 0x100");
        while (dut.busy) @(negedge clk);
        expect16({3'd2, 16'h0007, 7'h08}, 16'h0022, "a mirrored SDLR");

        // --------------------------------------------------------------
        // 10. The Pocket mapping. Every Pocket key reaches exactly one
        //     documented bit, and the two settings move only the four keys
        //     they exist to move.
        // --------------------------------------------------------------
        expect_map(16'h0000, 2'b00, SGN,       "nothing pressed");
        expect_map(K_UP,     2'b00, SGN | LU,  "up is the left pad");
        expect_map(K_DOWN,   2'b00, SGN | LD,  "down is the left pad");
        expect_map(K_LEFT,   2'b00, SGN | LL,  "left is the left pad");
        expect_map(K_RIGHT,  2'b00, SGN | LR,  "right is the left pad");
        expect_map(K_X,      2'b00, SGN | RU,  "X is the right pad's up");
        expect_map(K_B,      2'b00, SGN | RD,  "B is the right pad's down");
        expect_map(K_Y,      2'b00, SGN | RL,  "Y is the right pad's left");
        expect_map(K_A,      2'b00, SGN | RR,  "A is the right pad's right");
        expect_map(K_L,      2'b00, SGN | BTN_A, "L is the machine's A");
        expect_map(K_R,      2'b00, SGN | BTN_B, "R is the machine's B");
        expect_map(K_SELECT, 2'b00, SGN | LT,  "Select is the machine's L");
        expect_map(K_START,  2'b00, SGN | RT,  "Start is the machine's R");

        // Swapping the pads moves the eight directions and nothing else.
        expect_map(K_UP,     2'b01, SGN | RU,  "up swapped");
        expect_map(K_DOWN,   2'b01, SGN | RD,  "down swapped");
        expect_map(K_LEFT,   2'b01, SGN | RL,  "left swapped");
        expect_map(K_RIGHT,  2'b01, SGN | RR,  "right swapped");
        expect_map(K_X,      2'b01, SGN | LU,  "X swapped");
        expect_map(K_B,      2'b01, SGN | LD,  "B swapped");
        expect_map(K_Y,      2'b01, SGN | LL,  "Y swapped");
        expect_map(K_A,      2'b01, SGN | LR,  "A swapped");
        expect_map(K_L,      2'b01, SGN | BTN_A, "L is unmoved by the swap");
        expect_map(K_SELECT, 2'b01, SGN | LT,  "Select is unmoved by the swap");

        // The second setting hands Select and Start to the machine's own,
        // which is what leaves its L and R unreachable -- the trade the
        // note names, and the reason this is a setting.
        expect_map(K_SELECT, 2'b10, SGN | SEL, "Select is the machine's");
        expect_map(K_START,  2'b10, SGN | STA, "Start is the machine's");
        expect_map(K_L,      2'b10, SGN | BTN_A, "L is unmoved by the trade");
        expect_map(K_R,      2'b10, SGN | BTN_B, "R is unmoved by the trade");
        expect_map(K_UP,     2'b10, SGN | LU,  "up is unmoved by the trade");
        expect_map(K_SELECT | K_START, 2'b11, SGN | SEL | STA,
                   "both settings at once");

        // Every Pocket key at once reaches twelve distinct report bits,
        // and the battery bit stays clear whatever is pressed.
        expect_map(16'hc3ff, 2'b00,
                   SGN | RD | RL | LU | LD | LL | LR | RR | RU | LT | RT
                       | BTN_A | BTN_B,
                   "every key at once");

        $display("game_pad: all checks passed");
        $finish;
    end

    // A stuck read or a missing completion must fail rather than hang.
    initial begin
        #60_000_000;
        $fatal(1, "game_pad: timed out");
    end

endmodule
