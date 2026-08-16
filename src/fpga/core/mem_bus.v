//
// The NVC's external bus: one 27-bit space, eight regions selected by the top
// three address lines, one halfword per access [Sacred Tech Scroll > Memory
// Map]. Address bit 0 never leaves the CPU, which is what rounds a halfword
// access down; a word access is two bus cycles there too, so both unaligned
// rules are structure here rather than logic.
//
// The bus owns what no device does: the region selects, work RAM, and the
// answer for regions nothing drives. Unmapped reads return zero and unmapped
// writes vanish -- defined behavior, not a fault. VSU reads are undefined on
// its 8-bit bus and no commercial cart populates the expansion region; zero
// for both follows beetle-vb (libretro.cpp, MemRead16), an implementation
// choice rather than documented hardware.
//
// Timing contract: an access is one cycle of req, and rdata holds the answer
// the following cycle -- the same shape block RAM gives, so external devices
// answer exactly like the on-chip work RAM does. Between accesses rdata holds.
//
// Wait states are deliberately absent. The WCR lives with the CPU's bus
// timing, where its only consumer is (see TODO section 2).
//

module mem_bus (
    input  wire         clk,
    input  wire         reset_n,

    // CPU side. One access per req cycle; we qualifies it as a write, be
    // picks byte lanes within the halfword (be[0] low byte, little-endian).
    input  wire         req,
    input  wire [26:1]  addr,
    input  wire         we,
    input  wire [1:0]   be,
    input  wire [15:0]  wdata,
    output wire [15:0]  rdata,
    output wire         ready,

    // One select per region a future module owns. addr, we, be and wdata
    // fan out to the devices unchanged; only the selects are decoded here.
    output wire         vip_sel,
    output wire         vsu_sel,
    output wire         misc_sel,
    output wire         exp_sel,
    output wire         cart_ram_sel,
    output wire         cart_rom_sel,

    input  wire [15:0]  vip_rdata,
    input  wire         vip_ready,
    input  wire [15:0]  misc_rdata,
    input  wire [15:0]  cart_ram_rdata,
    input  wire [15:0]  cart_rom_rdata
);

    wire [2:0] region = addr[26:24];

    assign vip_sel      = req && region == 3'd0;
    assign vsu_sel      = req && region == 3'd1;
    assign misc_sel     = req && region == 3'd2;
    assign exp_sel      = req && region == 3'd4;
    wire   wram_sel     = req && region == 3'd5;
    assign cart_ram_sel = req && region == 3'd6;
    assign cart_rom_sel = req && region == 3'd7;

    // 64 KiB, mirrored through its region by ignoring bits 16-23
    // [Sacred Tech Scroll > Memory Map]. Two byte arrays so byte-lane writes
    // infer as block RAM byte enables. No initialization on purpose: real
    // hardware powers up with garbage, and zeroes would hide a ROM that
    // forgets to initialize.
    reg [7:0] wram_lo [0:32767];
    reg [7:0] wram_hi [0:32767];

    reg [7:0] wram_lo_q;
    reg [7:0] wram_hi_q;

always @(posedge clk) begin
    if (wram_sel) begin
        if (we && be[0]) wram_lo[addr[15:1]] <= wdata[7:0];
        if (we && be[1]) wram_hi[addr[15:1]] <= wdata[15:8];
        wram_lo_q <= wram_lo[addr[15:1]];
        wram_hi_q <= wram_hi[addr[15:1]];
    end
end

    // The answer follows the access by a cycle, so the mux runs on the
    // region held from the last req. Reset parks it on the unmapped region,
    // making rdata zero out of reset instead of x.
    reg [2:0] region_q;

always @(posedge clk or negedge reset_n) begin
    if (~reset_n) region_q <= 3'd3;
    else if (req) region_q <= region;
end

    assign rdata = region_q == 3'd0 ? vip_rdata :
                   region_q == 3'd2 ? misc_rdata :
                   region_q == 3'd5 ? {wram_hi_q, wram_lo_q} :
                   region_q == 3'd6 ? cart_ram_rdata :
                   region_q == 3'd7 ? cart_rom_rdata :
                   16'd0;

    assign ready = !req || region != 3'd0 || vip_ready;

endmodule
