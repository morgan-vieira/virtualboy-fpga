`default_nettype none
//
// The NVC's game pad port: a 16-bit serial report clocked in from the
// controller, exposed as SDLR/SDHR and driven by SCR [Scroll, Game Pad].
// The pad is a shift register with a latch line and a clock line; the
// console can drive that clock itself (a software read) or hand the job to
// hardware, which clocks all sixteen bits at 31.25 kHz -- 640 architectural
// cycles a bit, 10,240 for the report, exactly the documented 512 us.
// Counting off ce means the read cannot drift against video or the timer.
//
// Bit numbering is the scroll's register numbering, bit 15 RD down to bit 0
// PWR [Scroll, Game Pad > Data Registers], which beetle-vb's input.c
// reproduces exactly: its pad bitmap lands at SDR bit 2 for A through bit
// 15 for right-D-pad-down, over SGN at bit 1 and the battery at bit 0. The
// wiki article in docs/technical-notes numbers the same sixteen bits the
// other way round; INDEX.md records why both are right -- it numbers by
// shift position, and the report goes out MSB first, so its bit N is the
// scroll's bit 15-N. That is the direction shifted here, though nothing
// can see it: the report commits whole on the sixteenth bit, so the
// direction leaves no software-visible trace and the choice is only about
// agreeing with both documents at once.
//
// The two references split three ways, all recorded where they happen:
// beetle-vb never implements the software clock at all (it hands live pad
// state back instead), so MiSTer's vue.v decides that path; MiSTer defers
// an abort to a clock phase where the scroll and beetle-vb both cancel at
// once, so they decide that one; and beetle-vb raises the key interrupt on
// every completed read, ignoring the condition the scroll states outright,
// so the document wins and MiSTer agrees with it.
//

module game_pad (
    input  wire logic        clk,
    input  wire logic        reset_n,
    input  wire logic        ce,       // architectural 20 MHz tick

    // mem_bus device shape: sel one clock, the answer registered the next.
    input  wire logic        sel,
    input  wire logic [26:1] addr,
    input  wire logic        we,
    input  wire logic [1:0]  be,
    input  wire logic [15:0] wdata,
    output logic      [15:0] rdata,

    // The pad's own report, already in this clock domain. Sampled when a
    // latch or a read start pulses the latch line, never continuously.
    input  wire logic [15:0] buttons,

    // Held until acknowledged; core_top presents it at level 0 (0xFE00).
    output wire logic        irq
);

    localparam int BIT_CYCLES = 640;   // 32 us a bit, 31.25 kHz

    // SCR's four writable fields [Scroll, Game Pad Control]. The rest of
    // the register is unused or read-only, so nothing stores them.
    logic        k_int_inh;    // bit 7, inhibits the key interrupt
    logic        para_si;      // bit 5, holds the pad's latch line
    logic        soft_ck;      // bit 4, the software clock, inverted out
    logic        abt_dis;      // bit 0, aborts and blocks a hardware read

    logic [15:0] shifter;      // the pad's report, rotating out MSB first
    logic [15:0] data;         // SDHR:SDLR, committed on the 16th bit
    logic [4:0]  count;        // bits clocked so far, 0..16
    logic        busy;         // SI-Stat: a hardware read is underway
    logic [9:0]  div;          // cycles left in the current bit
    logic        irq_q;

    // Registers sit four bytes apart so byte, halfword and word accesses
    // all land [Scroll, Miscellaneous Hardware]; only byte lane 0 carries a
    // register. Decoding addr & 0xFF mirrors the block every 0x100 through
    // the region, the same shape timer.v takes from beetle-vb's HWCTRL.
    wire logic wr_scr = sel && we && be[0] && addr[7:1] == 7'h14; // 0x02000028

    // Rotating left returns the whole report after sixteen clocks, so the
    // one register serves as both the pad's outgoing shift register and the
    // console's capture -- the assembled word is simply the rotation's
    // sixteenth value. MiSTer carries a separate capture register for the
    // same result.
    wire logic [15:0] shifted = {shifter[14:0], shifter[15]};
    wire logic        last_bit = count == 5'd15;

    // A standard controller can never satisfy this: it always sets SGN,
    // which sits inside the suppressing range [Scroll, Key Input
    // Interrupt]. Implemented as written even so -- a non-standard pad
    // could still raise it. beetle-vb omits the condition and raises on
    // every completed read; the scroll states it, and MiSTer agrees.
    wire logic key_match = (|shifted[15:4]) && (~|shifted[3:1]);

    // Writing Para/Si pulses the pad's latch line, which restarts the
    // report [Scroll, Software Read]. Clearing it is what arms the software
    // clock, which is why the scroll warns the bit must be cleared "or else
    // the operation will be repeatedly reset". A hardware read drives both
    // pad lines itself, so neither software handle reaches the pad while
    // one is underway -- MiSTer's output mux says the same (vue.v drives
    // pad_latch_o and pad_clock_o from the hardware sequencer while busy),
    // though its own state update forgets to, and a soft clock there would
    // corrupt the report in flight.
    wire logic latch_wr = wr_scr && wdata[5] && !busy;

    // The written clock bit reaches the pad inverted [Scroll, Software
    // Read], so a 1-to-0 write is a rising edge at the pad, and that is the
    // edge the report advances on. This is MiSTer's model (vue.v); it is
    // also what reconciles the scroll's two counts of the same procedure --
    // sixteen advancing edges need alternating writes, one write to set the
    // bit and sixteen pairs after it, which is the thirty-three the
    // document also gives.
    wire logic soft_edge = wr_scr && !wdata[5] && soft_ck && !wdata[4]
                           && count != 5'd16 && !busy;

    // HW-SI starts a read; setting it during one has no effect, and the
    // abort bit blocks a start whether it arrives in this write or was
    // already standing [Scroll, Hardware Read]. Both references gate on
    // both, beetle-vb by aborting the read it just started.
    wire logic hw_start = wr_scr && wdata[2] && !wdata[0] && !abt_dis && !busy;

    // The scroll cancels "immediately" and beetle-vb clears its counter on
    // the spot; MiSTer instead waits for a serial clock edge. The document
    // and the emulator agree, so the abort lands in the write.
    wire logic hw_abort = wr_scr && wdata[0] && busy;

    wire logic hw_tick = busy && ce && div == 10'd0;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Every SCR field zero, SDHR and SDLR 0x00 [Scroll, System
            // Reset > Game Pad]. Both references reset the same way.
            k_int_inh <= 1'b0;
            para_si   <= 1'b0;
            soft_ck   <= 1'b0;
            abt_dis   <= 1'b0;
            shifter   <= 16'd0;
            data      <= 16'd0;
            count     <= 5'd0;
            busy      <= 1'b0;
            div       <= 10'd0;
            irq_q     <= 1'b0;
        end else begin
            // A hardware read advances one bit per 640 cycles and commits
            // the report on the sixteenth, which is where the interrupt is
            // decided. Before then the data registers hold the previous
            // report -- the scroll calls their contents undefined until the
            // sixteenth bit, so holding is a choice, and it is the one that
            // makes a half-finished read visibly stale rather than random.
            if (busy && ce) div <= hw_tick ? BIT_CYCLES[9:0] - 10'd1
                                           : div - 10'd1;
            if (hw_tick) begin
                shifter <= shifted;
                count   <= count + 5'd1;
                if (last_bit) begin
                    busy <= 1'b0;
                    data <= shifted;
                    if (!k_int_inh && key_match) irq_q <= 1'b1;
                end
            end

            // A software clock edge advances the same shifter, so both
            // reads share one path through the pad -- which is what the
            // hardware has. The scroll leaves the data registers undefined
            // until the sixteenth bit here too. No interrupt: the scroll
            // conditions the key interrupt on a hardware read completing,
            // and both references raise it only there.
            if (soft_edge) begin
                shifter <= shifted;
                count   <= count + 5'd1;
                if (last_bit) data <= shifted;
            end

            if (wr_scr) begin
                k_int_inh <= wdata[7];
                para_si   <= wdata[5];
                soft_ck   <= wdata[4];
                abt_dis   <= wdata[0];
                // Writing the inhibit bit acknowledges a pending interrupt.
                // Both references clear on the write, and nothing else
                // clears: the scroll gives no other acknowledge path.
                if (wdata[7]) irq_q <= 1'b0;
            end

            // The latch line and a read start both resample the pad and
            // rewind the report, and both outrank a clock edge in the same
            // write. The abort is last so a write carrying both it and
            // HW-SI leaves no read running, which is where beetle-vb ends
            // up by starting the read and cancelling it.
            if (latch_wr || hw_start) begin
                shifter <= buttons;
                count   <= 5'd0;
            end
            if (hw_start) begin
                busy <= 1'b1;
                div  <= BIT_CYCLES[9:0] - 10'd1;
            end
            if (hw_abort) begin
                busy  <= 1'b0;
                div   <= 10'd0;
                count <= 5'd0;
            end
        end
    end

    // SDLR and SDHR are read-only halves of the committed report. SCR reads
    // back its four fields with SI-Stat live, HW-SI always set, and both
    // unused bits set [Scroll, Game Pad Control]; beetle-vb's
    // `SCR | 0x40 | 0x08 | HW_SI` and MiSTer's literal ones are the same
    // register. The high byte reads zero the way every byte-wide
    // miscellaneous register does.
    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) rdata <= 16'd0;
        else if (sel) begin
            case (addr[7:1])
                7'h08:   rdata <= {8'd0, data[7:0]};    // SDLR, 0x02000010
                7'h0A:   rdata <= {8'd0, data[15:8]};   // SDHR, 0x02000014
                7'h14:   rdata <= {8'd0, k_int_inh, 1'b1, para_si, soft_ck,
                                   1'b1, 1'b1, busy, abt_dis};
                default: rdata <= 16'd0;
            endcase
        end
    end

    assign irq = irq_q;

endmodule

`default_nettype wire
