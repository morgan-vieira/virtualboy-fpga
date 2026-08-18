import { type Assembler, r0, r6, r7, r8, r9, r10 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// The four frame buffers. Nothing here enables drawing, so the VIP never
// swaps and which buffer it shows out of reset is its call; both of each
// eye's are filled so no reset choice can invalidate the picture.
const LEFT = [0x00000000, 0x00008000];
const RIGHT = [0x00010000, 0x00018000];

// Frame buffers are column-major: 64 bytes per column, one halfword per
// eight rows, two bits per pixel.
const COLUMN_BYTES = 64;

// A flat field, one shade everywhere.
const fillField = (a: Assembler, base: number, word: number, tag: string) => {
  a.loadImm(word, r7);
  a.loadImm(base, r6);
  a.loadImm(12288, r8);
  a.label(tag);
  a.stH(r7, 0, r6);
  a.addImm(2, r6);
  a.addImm(-1, r8);
  a.bne(tag);
};

// Shade 3 over `cols` columns from `x`, `words` halfwords down each.
const rect = (
  a: Assembler,
  base: number,
  x: number,
  cols: number,
  words: number,
  tag: string,
) => {
  a.loadImm(base + x * COLUMN_BYTES, r10);
  a.loadImm(0xffff, r7);
  a.loadImm(cols, r8);
  a.label(`${tag}_col`);
  a.mov(r10, r6);
  a.loadImm(words, r9);
  a.label(`${tag}_row`);
  a.stH(r7, 0, r6);
  a.addImm(2, r6);
  a.addImm(-1, r9);
  a.bne(`${tag}_row`);
  a.addi(COLUMN_BYTES, r10, r10);
  a.addImm(-1, r8);
  a.bne(`${tag}_col`);
};

export default defineRom({
  name: "vip-stereo",
  header: { gameTitle: "OPENFPGA VIP 3D", makerCode: "OF", gameCode: "VVST", revision: 0 },
  expectation:
    "Each eye gets a different picture. The left eye is a dim field with a " +
    "bright 32x32 block in its top-left corner; the right eye is a clearly " +
    "brighter field with a bright block in its top-right corner. Both carry a " +
    "bright 8-pixel vertical bar, at x=176 on the left and x=208 on the right, " +
    "so the bar sits 32 pixels apart between the eyes. Check every Core " +
    "Settings > Stereo Mode. 2D (left eye): dim field, block top-left, bar left " +
    "of centre. 2D (right eye): brighter field, block top-right, bar right of " +
    "centre. Side-by-Side: those two pictures next to each other, left one on " +
    "the left. Vertical Line Interleave: one field of fine vertical dither with " +
    "both corner blocks and both bars. Horizontal Line Interleave: the same as " +
    "horizontal dither. Cyberscope: two quarter-turned pictures, left one on " +
    "the left half. Anaglyph: one field with the two bars 32 pixels apart in " +
    "the preset's two colours. Identical pictures under the two 2D settings is " +
    "one eye read twice; the dim field where the bright one belongs is the two " +
    "eyes crossed; a missing corner block or a bar separation that is not 32 " +
    "pixels is the mode's pixel mapping.",
  program: (a) => {
    a.label("start");
    a.di();

    // Both eyes' column tables, flat: a repeat count of one everywhere, so
    // shade comes from BRTA/BRTB/BRTC alone and the field does not fade
    // across x. 0x3DC00 is the left table, 0x3DE00 the right, 256 entries
    // each and contiguous.
    a.loadImm(0x0003dc00, r6);
    a.loadImm(0x00ff, r7);
    a.loadImm(512, r8);
    a.label("columns");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("columns");

    // Shades 1/2/3 as exposures 40, 100 and 255 -- three levels far enough
    // apart that a maintainer can name which one is on screen.
    a.loadImm(0x0005f824, r6);
    a.loadImm(40, r7);
    a.stH(r7, 0, r6);
    a.loadImm(100, r7);
    a.stH(r7, 2, r6);
    a.loadImm(115, r7);
    a.stH(r7, 4, r6);
    a.stH(r0, 6, r6);

    fillField(a, LEFT[0], 0x5555, "fill_l0");
    fillField(a, LEFT[1], 0x5555, "fill_l1");
    fillField(a, RIGHT[0], 0xaaaa, "fill_r0");
    fillField(a, RIGHT[1], 0xaaaa, "fill_r1");

    // Opposite corners: a duplicated eye shows one block, not two.
    rect(a, LEFT[0], 0, 32, 4, "blk_l0");
    rect(a, LEFT[1], 0, 32, 4, "blk_l1");
    rect(a, RIGHT[0], 352, 32, 4, "blk_r0");
    rect(a, RIGHT[1], 352, 32, 4, "blk_r1");

    // The parallax bar, 32 pixels of separation between the eyes.
    rect(a, LEFT[0], 176, 8, 28, "bar_l0");
    rect(a, LEFT[1], 176, 8, 28, "bar_l1");
    rect(a, RIGHT[0], 208, 8, 28, "bar_r0");
    rect(a, RIGHT[1], 208, 8, 28, "bar_r1");

    // DPCTRL: SYNCE, RE, DISP.
    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0302, r7);
    a.stH(r7, 0, r6);
    a.hang();
  },
});
