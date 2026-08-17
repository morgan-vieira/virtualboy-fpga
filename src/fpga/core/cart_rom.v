`default_nettype none
//
// Cartridge ROM, loaded over the APF bridge and served out of the Pocket's
// SDRAM. data.json places slot 0 at bridge address 0x00000000 with "reset
// core while loading" set, so APF holds reset_n low around every load --
// initial boot and user reloads both -- and the CPU only ever boots into a
// fully loaded image.
//
// It lives in SDRAM rather than block RAM because a retail cartridge is
// 512 KB to 2 MB and the fabric has 384 KB of block RAM total, all of it
// already spoken for by work RAM and the VIP. The 64 KB block-RAM version
// this replaces was a test-ROM allowance, never a cartridge.
//
// Mirroring is the mechanism, not a convenience: the address masks with the
// loaded image's power-of-two size, which is how the header and vectors at
// the top of the file land at the top of the address space for any ROM
// size, and how the reset vector at 0xFFFFFFF0 finds them. The size is
// recovered from the load itself: images are powers of two and APF writes
// the file front to back, so the highest word address written is the mask.
//
// Byte order: with bridge_endian_little low, file byte 0 arrives in
// load_data[31:24]; the .vb is little-endian halfwords, so each halfword
// swaps its bytes here. This swap was confirmed on hardware 2026-08-14 and
// has not moved.
//
// The read path is a passthrough. pocket_sdram takes the same held request
// mem_bus gives a device -- req and payload steady until ready, answer the
// cycle after -- so the CPU's select becomes the memory's request and the
// memory's ready becomes the bus's, with only the mirror mask in between.
// A write into the ROM region reads instead of writing and is discarded,
// which is what a cartridge does with one.
//
// The loader crosses from clk_74a on a bundled-data toggle: one word in
// flight, its address and data held steady by the producer until the
// consumer acknowledges. One deep is enough by construction rather than by
// luck -- APF spends a whole eight-byte SPI transaction per 32-bit write
// (apf/io_bridge_peripheral.v walks four address then four data bytes
// before pulsing pmp_wr), which is at least 64 bridge clocks, while draining
// one word is two SDRAM halfword writes at roughly 250 ns. The CPU is held
// in reset for the whole load, so nothing competes for the memory either.
// The memory's own 200 us initialization is over long before any of this:
// it starts when the PLL locks and APF has a whole boot to get through --
// core definition files, the file browser, the SD read -- before the first
// bridge write lands.
//

module cart_rom (
    // load side, clk_74a domain. load_wr is the bridge's raw write strobe and
    // load_addr its raw address; the slot's window is decoded here rather than
    // in core_top so the size a cartridge may be is stated once, beside the
    // address width that defines it. Getting those two out of step is what
    // silently truncated the first image larger than 64KB.
    input  wire logic        load_clk,
    input  wire logic        load_begin,     // dataslot_requestwrite
    input  wire logic        load_wr,        // bridge_wr
    input  wire logic [31:0] load_addr,      // bridge_addr
    input  wire logic [31:0] load_data,

    // CPU side. The mask is only read while the load-time reset holds the
    // CPU, so it crosses domains as a quasi-static value.
    input  wire logic        clk,
    input  wire logic        sel,
    input  wire logic [26:1] addr,
    output logic     [15:0]  rdata,
    output logic             ready,

    // the SDRAM this cartridge lives in, at the bottom of the part
    output logic             mem_req,
    output logic     [24:0]  mem_addr,
    output logic             mem_we,
    output logic     [15:0]  mem_wdata,
    input  wire logic [15:0] mem_rdata,
    input  wire logic        mem_ready
);

    // A game pak holds at most 16 MB of ROM [Virtual Boy Development Manual
    // 3.9], which is 23 bits of halfword address.
    localparam int unsigned HWORD_BITS = 23;
    localparam int unsigned WORD_BITS  = HWORD_BITS - 1;

    // ------------------------------------------------------------------
    // Load side, clk_74a
    // ------------------------------------------------------------------

    logic [WORD_BITS-1:0] max_word = '0;
    logic [WORD_BITS-1:0] load_word_q = '0;
    logic [31:0]          load_data_q = '0;
    logic                 load_toggle = 1'b0;

    wire logic [WORD_BITS-1:0] load_word = load_addr[WORD_BITS+1:2];

    // data.json puts slot 0 at bridge address 0x00000000 and caps it at the
    // game pak's 16MB, so the slot owns exactly the bridge addresses whose top
    // eight bits are clear. Everything above that belongs to another slot or to
    // the framework's own 0xF8xxxxxx region.
    wire logic load_in_slot = load_addr[31:HWORD_BITS+1] == '0;

    always_ff @(posedge load_clk) begin
        if (load_begin) begin
            max_word <= '0;
        end else if (load_wr && load_in_slot) begin
            load_word_q <= load_word;
            load_data_q <= load_data;
            load_toggle <= ~load_toggle;
            if (load_word > max_word) max_word <= load_word;
        end
    end

    // ------------------------------------------------------------------
    // Load side, drained in the memory's domain
    // ------------------------------------------------------------------

    typedef enum logic [1:0] { LOAD_IDLE, LOAD_LOW, LOAD_HIGH } load_state_t;

    load_state_t load_state = LOAD_IDLE;

    logic [1:0]           toggle_sync = '0;
    logic                 toggle_seen = 1'b0;
    logic [WORD_BITS-1:0] word_held = '0;
    logic [31:0]          data_held = '0;

    wire logic load_pending = toggle_sync[1] != toggle_seen;
    wire logic load_active  = load_state != LOAD_IDLE;

    always_ff @(posedge clk) begin
        toggle_sync <= {toggle_sync[0], load_toggle};

        unique case (load_state)
            LOAD_IDLE:
                if (load_pending) begin
                    word_held   <= load_word_q;
                    data_held   <= load_data_q;
                    toggle_seen <= toggle_sync[1];
                    load_state  <= LOAD_LOW;
                end

            LOAD_LOW:  if (mem_ready) load_state <= LOAD_HIGH;
            LOAD_HIGH: if (mem_ready) load_state <= LOAD_IDLE;

            default: load_state <= LOAD_IDLE;
        endcase
    end

    // ------------------------------------------------------------------
    // The memory port, shared between the loader and the CPU
    // ------------------------------------------------------------------

    // Halfword index into the image, masked to the loaded size.
    wire logic [HWORD_BITS-1:0] hword =
        addr[HWORD_BITS:1] & {max_word, 1'b1};

    // The cartridge sits at the bottom of the 64 MB part; the two bits above
    // its 16 MB window stay clear.
    assign mem_req   = load_active || sel;
    assign mem_we    = load_active;
    assign mem_addr  = load_active
                     ? {2'b00, word_held, load_state == LOAD_HIGH}
                     : {2'b00, hword};
    assign mem_wdata = load_state == LOAD_HIGH
                     ? {data_held[7:0],   data_held[15:8]}
                     : {data_held[23:16], data_held[31:24]};

    assign rdata = mem_rdata;
    assign ready = mem_ready && !load_active;

endmodule

`default_nettype wire
