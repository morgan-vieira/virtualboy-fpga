`default_nettype none
//
// Cartridge save RAM: the battery-backed SRAM a game pak carries [Sacred Tech
// Scroll > Game Pak > Memory], held in block RAM and persisted through a
// nonvolatile APF data slot. Like the ROM, its size is a power of two whose
// upper address bits mask, so the region mirrors.
//
// The cells are eight bits wide, not sixteen. A pak wires only D0-D7 to its
// RAM module, so a halfword read answers 0xFF in the upper byte and a
// halfword write drops it. No document we have says so: MiSTer models it in
// rtl/Mem/vb_cart_sdram.sv ({8'hff, byte}) and beetle-vb does not (a flat
// 16-bit array), so MiSTer decides, per CLAUDE.md's reference priority. What
// it costs a game is that save data steps two bytes per cell, which is how a
// pak addresses it anyway; what it costs the save file is one byte per cell,
// the packed layout MiSTer writes for an exact-size save and not the same
// bytes beetle-vb's would hold.
//
// A byte store to an odd address selects the upper lane alone. The pak has
// one write-enable pin and no lane strobe, so what real silicon does there
// depends on what the NVC drives on D0-D7, which nothing documents; MiSTer
// drops the write (VirtualBoy.sv gates its request on the low lane) and so do
// we. It is an implementation choice, not observed hardware.
//
// Persistence is APF's, not ours. data.json's slot 1 is nonvolatile with
// parameter bits 2 and 5 set and bit 3 clear, so the Pocket names the file
// after the cartridge (Game.vb -> Game.sav), fills a fresh one with 0xFF the
// way erased silicon reads, and reads the slot back onto that file on Quit
// and on power off [core-boot-process.md > Shutdown]. Sleep would flush too;
// core.json leaves sleep_supported false. The readback happens after Reset
// Enter, so the CPU is already stopped and nothing races it.
//
// The size mask is recovered from the load the way the cartridge's is: the
// highest word address APF wrote. It starts full and narrows, so a slot that
// never loads is 8KB of uninitialized cells rather than a four-cell mirror.
//
// 8192 cells is seven M10K blocks of the sixty-four the cartridge freed when
// it moved to SDRAM. CELL_BITS and data.json's size_maximum are the same
// number stated twice and have to move together.
//
// The bridge is 32 bits wide and a cell is 8, so a bridge word is four cells
// walked one per clock: writes at boot, reads at shutdown. One request in
// flight is enough by construction, for the reason cart_rom.v records -- APF
// spends a whole eight-byte SPI transaction per bridge access, at least 64
// bridge clocks, where a walk is five.
//

module cart_ram (
    // bridge side, clk_74a. load_begin is dataslot_requestwrite for this
    // slot; everything else is the raw bridge, whose window is decoded here
    // beside the size that defines it.
    input  wire logic        bridge_clk,
    input  wire logic        load_begin,
    input  wire logic        bridge_wr,
    input  wire logic        bridge_rd,
    input  wire logic [31:0] bridge_addr,
    input  wire logic [31:0] bridge_wr_data,
    output logic     [31:0]  bridge_rd_data,

    // How many bytes APF handed us, which is how many it has to take back.
    // The size table it flushes from says zero for a save with no file yet,
    // so somebody has to name this; dataslot_size.v carries it there.
    output logic     [31:0]  save_bytes,

    // CPU side. The mask crosses domains as a quasi-static value: it is
    // settled before dataslot_allcomplete lets the CPU out of reset.
    input  wire logic        clk,
    input  wire logic        sel,
    input  wire logic [26:1] addr,
    input  wire logic        we,
    input  wire logic [1:0]  be,
    input  wire logic [15:0] wdata,
    output logic     [15:0]  rdata
);

    localparam int unsigned CELL_BITS = 13;             // 8192 cells
    localparam int unsigned WORD_BITS = CELL_BITS - 2;  // four cells a word

    // The save's own window on the bridge, above the 16MB the cartridge owns.
    // One comparison covers both the base and the cap, so a stray write
    // neither lands in the cells nor drags the mask up with it.
    localparam logic [31:0] BRIDGE_BASE = 32'h0100_0000;

    logic [7:0] cells [0:(1 << CELL_BITS) - 1];

    // ------------------------------------------------------------------
    // Bridge side, clk_74a
    // ------------------------------------------------------------------

    wire logic in_slot =
        bridge_addr[31:CELL_BITS] == BRIDGE_BASE[31:CELL_BITS];

    wire logic [WORD_BITS-1:0] bridge_word = bridge_addr[CELL_BITS-1:2];

    logic [WORD_BITS-1:0] max_word = '1;
    logic [WORD_BITS-1:0] word_q   = '0;
    logic [31:0]          data_q   = '0;

    logic        walk_write = 1'b0;
    logic [1:0]  step       = '0;
    logic        walking    = 1'b0;
    logic        walking_q  = 1'b0;     // the cycle a walked read answers in
    logic [7:0]  cell_q;
    logic [31:0] rd_shift   = '0;
    logic [31:0] rd_word    = '0;

    wire logic start_write = bridge_wr && in_slot && !walking;
    wire logic start_read  = bridge_rd && in_slot && !walking;

    // Address the walk is presenting, and the write it is making.
    wire logic [CELL_BITS-1:0] bridge_cell = {word_q, step};
    wire logic bridge_we = walking && walk_write;

    // Neither port reads the cell it is writing, on either clock. A real SRAM
    // does not drive its bus during a write either, and a dual-clock block RAM
    // leaves read-during-write undefined -- Quartus refuses to infer the array
    // at all if it is asked to.
    always_ff @(posedge bridge_clk) begin
        if (bridge_we) cells[bridge_cell] <= data_q[31:24];
        else           cell_q <= cells[bridge_cell];

        walking_q <= walking;
        if (walking_q && !walk_write) rd_shift <= {rd_shift[23:0], cell_q};
        // The last byte lands the cycle after the walk ends; hold the whole
        // word so a read never samples the shift mid-flight.
        if (!walking && walking_q && !walk_write)
            rd_word <= {rd_shift[23:0], cell_q};

        if (walking) begin
            data_q <= {data_q[23:0], 8'h00};
            step   <= step + 2'd1;
            if (step == 2'd3) walking <= 1'b0;
        end

        if (load_begin) max_word <= '0;

        if (start_write || start_read) begin
            word_q     <= bridge_word;
            data_q     <= bridge_wr_data;
            walk_write <= start_write;
            step       <= '0;
            walking    <= 1'b1;
        end

        if (start_write && bridge_word > max_word) max_word <= bridge_word;
    end

    assign bridge_rd_data = rd_word;

    // One word past the highest one written, in bytes.
    assign save_bytes = (32'(max_word) + 32'd1) << 2;

    // ------------------------------------------------------------------
    // CPU side, clk
    // ------------------------------------------------------------------

    // Cell index, mirrored by ignoring the address above the array and masked
    // to the size that loaded.
    wire logic [CELL_BITS-1:0] cpu_cell = addr[CELL_BITS:1] & {max_word, 2'b11};

    logic [7:0] cpu_q;

    always_ff @(posedge clk) begin
        if (sel) begin
            if (we && be[0]) cells[cpu_cell] <= wdata[7:0];
            else             cpu_q <= cells[cpu_cell];
        end
    end

    assign rdata = {8'hFF, cpu_q};

endmodule

`default_nettype wire
