`default_nettype none
//
// Cartridge ROM, loaded over the APF bridge. data.json places slot 0 at
// bridge address 0x00000000 with "reset core while loading" set, so APF
// holds reset_n low around every load -- initial boot and user reloads both
// -- and the CPU only ever boots into a fully loaded image.
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
// swaps its bytes here. If a first hardware run shows instant garbage --
// no status writes, a wild PC row -- suspect this swap first; the baked-ROM
// bitstreams kept in output/ isolate it.
//
// Two banks, one per halfword of a bridge word, so a load is a single-cycle
// write to each and neither RAM needs two write ports. The CPU side answers
// the cycle after the access and holds, the mem_bus device shape.
//

module cart_rom #(
    parameter               HWORDS = 32768   // 64KB, matching size_maximum
) (
    // load side, clk_74a domain
    input  wire logic        load_clk,
    input  wire logic        load_begin,     // dataslot_requestwrite
    input  wire logic        load_wr,
    input  wire logic [31:0] load_addr,      // byte offset into the slot
    input  wire logic [31:0] load_data,

    // CPU side. The mask is only read while the load-time reset holds the
    // CPU, so it crosses domains as a quasi-static value.
    input  wire logic        clk,
    input  wire logic        sel,
    input  wire logic [26:1] addr,
    output logic     [15:0]  rdata
);

    localparam WORDS = HWORDS / 2;

    logic [15:0] bank_lo [0:WORDS-1];   // halfword 0 of each bridge word
    logic [15:0] bank_hi [0:WORDS-1];   // halfword 1

    logic [$clog2(WORDS)-1:0] max_word = '0;

    wire logic [$clog2(WORDS)-1:0] load_word = load_addr[$clog2(WORDS)+1:2];

    always_ff @(posedge load_clk) begin
        if (load_begin) begin
            max_word <= '0;
        end else if (load_wr) begin
            bank_lo[load_word] <= {load_data[23:16], load_data[31:24]};
            bank_hi[load_word] <= {load_data[7:0],  load_data[15:8]};
            if (load_word > max_word) max_word <= load_word;
        end
    end

    // Halfword index into the image, masked to the loaded size.
    wire logic [$clog2(HWORDS)-1:0] hword =
        addr[$clog2(HWORDS):1] & {max_word, 1'b1};

    // Both banks read into registers and the mux sits after them, the same
    // shape as mem_bus's work RAM: a mux before the register would ask the
    // block RAM for an asynchronous read, and Quartus falls back to half a
    // million plain registers instead.
    logic [15:0] read_lo, read_hi;
    logic        read_odd;

    always_ff @(posedge clk) begin
        if (sel) begin
            read_lo  <= bank_lo[hword[$clog2(HWORDS)-1:1]];
            read_hi  <= bank_hi[hword[$clog2(HWORDS)-1:1]];
            read_odd <= hword[0];
        end
    end

    assign rdata = read_odd ? read_hi : read_lo;

endmodule

`default_nettype wire
