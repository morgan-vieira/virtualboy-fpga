import {
  type Assembler,
  PSW,
  r0,
  r6,
  r7,
  r8,
  r9,
  r10,
  r11,
  r12,
  r13,
  r14,
  r15,
  r16,
  r17,
  r18,
  r19,
  r20,
  r21,
  type Register,
  r31,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// The Pocket's controls drawn where they sit on the device, each lighting
// bright while its button is held, plus the raw sixteen-bit report twice in
// small cells along the bottom: hardware read above, software read below,
// bit 15 leftmost, a two-cell gap between SDHR's half and SDLR's.
//
// The picture decodes the hardware read through the default mapping, which
// the V810 cannot see changed: the Core Settings register is bridge-side.
// Flip a mapping switch and the picture lights the control the report says,
// not the one under your thumb. The rows are the ground truth either way,
// and the only view of the software-read path.
//
// The two rows cannot prove each other on their own. Both reads land in the
// same pair of data registers, so a software read that never clocks anything
// leaves the hardware read's value standing and the rows agree anyway. What
// separates them is the reset state: the registers come up zero and only a
// completed read can fill them, so a software read performed before any
// hardware read has a known-wrong starting value to overwrite. That is the
// self-test below, and it is what actually proves the software path; the
// rows then show the live report.
//
// Register budget: r6-r13 are scratch, r14 holds the hardware word and r15
// the software word, r16-r19 belong to the keypad handler (SCR address, its
// acknowledge byte, the flag address, and a one), r20 is the status address
// and r21 the data registers'. Everything the handler reads is set before
// interrupts are enabled, because it has no scratch of its own.

const SCR = 0x02000028;
const SDLR = 0x02000010;
const STATUS = 0x05000000;
const FLAG = 0x05000004;

const SGN = 0x0002; // the signature bit, set by any standard controller
const PASS = 0x600d;

const CHR = 0x00006000; // character table 0, 16 bytes a character
const MAP = 0x00020000; // BG map 0, 64x64 cells of one halfword

const chr = (index: number) => CHR + index * 16;
const mapCell = (row: number, col: number) => MAP + (row * 64 + col) * 2;

// Character allocation: 0 stays blank, the rows own 1-32 so drawWord walks
// them by index, and each control is one character painted over its whole
// map region, so lighting a control is one character fill.
const HW_CHAR = 1; // 1..16, top row cells
const SW_CHAR = 17; // 17..32, bottom row cells
const BAR_CHAR = 33;
const DPAD_HUB = 34; // the cross's centre, dim always
const CTL_CHAR = 35; // 35..46, the twelve controls
const CHAR_COUNT = 47;

const ROWS_COL = 15; // both rows: cols 15-22 and 25-32, centred
const HW_ROW = 24;
const SW_ROW = 26;
const BAR_ROW = 27;

// Pixel values: two-bit colour indices through GPLT0, LSB pixel leftmost.
const BRIGHT = 0xffff; // every pixel colour 3
const DIM = 0x5555; // every pixel colour 1
const CELL_ON = 0x0fff; // a six-pixel glyph, two pixels of gap
const CELL_OFF = 0x0555;

// Each control is its report bit under the default mapping and the map
// region it fills, in 8px cells: shoulders top, cross left, diamond right,
// Select and Start centre. host_pad_map.v is where these bits come from.
const CONTROLS: [mask: number, row: number, col: number, w: number, h: number][] = [
  [0x0004, 1, 1, 11, 2], // L shoulder    -> A,  bit 2
  [0x0008, 1, 36, 11, 2], // R shoulder   -> B,  bit 3
  [0x0800, 8, 9, 3, 3], // D-pad up       -> LU, bit 11
  [0x0400, 14, 9, 3, 3], // D-pad down    -> LD, bit 10
  [0x0200, 11, 6, 3, 3], // D-pad left    -> LL, bit 9
  [0x0100, 11, 12, 3, 3], // D-pad right  -> LR, bit 8
  [0x0040, 8, 37, 2, 2], // X             -> RU, bit 6
  [0x0080, 11, 40, 2, 2], // A            -> RR, bit 7
  [0x8000, 14, 37, 2, 2], // B            -> RD, bit 15
  [0x4000, 11, 34, 2, 2], // Y            -> RL, bit 14
  [0x0020, 19, 19, 3, 1], // Select       -> LT, bit 5
  [0x0010, 19, 26, 3, 1], // Start        -> RT, bit 4
];

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

// The whole report, both halves, into `dest`. Clobbers r11.
const readReport = (a: Assembler, dest: Register) => {
  a.inB(0, r21, dest);
  a.inB(4, r21, r11);
  a.shlImm(8, r11);
  a.or(r11, dest);
};

// Falls through when the flags say the check passed, and otherwise freezes
// on `sentinel` with the bar lit and the code in the top row.
const failUnless = (a: Assembler, taken: "be" | "bne", sentinel: number) => {
  const ok = uniq("ok");
  if (taken === "be") a.be(ok);
  else a.bne(ok);
  a.loadImm(sentinel, r13);
  a.jr("fail"); // out of a conditional branch's 9-bit reach from here
  a.label(ok);
};

export default defineRom({
  name: "pad",
  header: { gameTitle: "OPENFPGA PAD", makerCode: "OF", gameCode: "VPAD", revision: 0 },
  expectation:
    "On the Pocket: the Pocket's own controls drawn in red where they sit on " +
    "the device -- two shoulder slabs across the top, the D-pad cross on the " +
    "left, the four face buttons as a diamond on the right, Select and Start " +
    "as two small slabs in the centre -- plus two small rows of sixteen cells " +
    "near the bottom edge, the raw report bit 15 leftmost with a gap between " +
    "halves, hardware read above and software read below. With nothing " +
    "pressed every control sits dim and exactly the fifteenth cell from the " +
    "left is lit in both rows: the signature bit. Holding a button fills its " +
    "control bright and lights exactly one further cell in both rows -- B " +
    "cell 1, Y cell 2, Up cell 5, Down cell 6, Left cell 7, Right cell 8, A " +
    "cell 9, X cell 10, Select cell 11, Start cell 12, R cell 13, L cell 14 " +
    "-- and releasing it puts both out again. Cells 3, 4 and 16 stay dark " +
    "with everything held: nothing reaches 3 and 4 in the default mapping, " +
    "and 16 is the low-battery bit APF gives the core no signal for. The " +
    "picture assumes the default mapping, because the V810 cannot read Core " +
    "Settings: flip 'D-Pad > Right Pad' and pressing the D-pad lights the " +
    "face diamond (Up becomes cell 10, X cell 5); flip 'Select and Start' " +
    "and the Select/Start slabs go dark while cells 3 and 4 light instead. " +
    "Under any setting the rows are the truth. The thin bar along the bottom " +
    "edge must stay black: it lights for a failed startup self-test, with " +
    "the failing code drawn in the top row -- 0xE001 data registers not zero " +
    "at reset, 0xE002 a software read alone never filled them, 0xE003 HW-SI " +
    "did not report busy, 0xE004 the hardware read returned no signature " +
    "bit, 0xE005 the two reads disagreed -- and for a keypad interrupt, " +
    "which a controller that sets the signature bit can never cause. A black " +
    "screen means the VIP never drew; a picture that ignores buttons means " +
    "the reads stopped completing. In Mednafen: loads as OPENFPGA PAD and " +
    "freezes on 0xE001 -- expected there and only there, because beetle-vb's " +
    "instant-read hack answers the data registers with live pad state " +
    "instead of the reset zero the scroll documents. The behavioural run for " +
    "this ROM is src/tests/cpu.v, which drives the real game pad RTL.",
  handlers: { keypad: "onKeypad" },
  program: (a) => {
    // Acknowledge through K-Int-Inh -- the only path that clears the line --
    // then record that it happened at all.
    a.label("onKeypad");
    a.stB(r17, 0, r16);
    a.stH(r19, 0, r18);
    a.reti();

    // ----------------------------------------------------------------
    // Subroutines
    // ----------------------------------------------------------------

    // Fill one character solid: r6 its data address, r13 the row value.
    // Leaves r6 on the next character, which initCtls counts on.
    a.label("fillChar");
    a.movImm(8, r8);
    a.label("fillRow");
    a.stH(r13, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("fillRow");
    a.jmp(r31);

    // Paint one rectangle of map cells with one character: r10 the top-left
    // cell's address, r7 the character, r8 width, r9 height.
    a.label("paintRect");
    a.mov(r10, r12);
    a.label("rectRow");
    a.mov(r12, r6);
    a.mov(r8, r11);
    a.label("rectCol");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r11);
    a.bne("rectCol");
    a.addi(128, r12, r12);
    a.addImm(-1, r9);
    a.bne("rectRow");
    a.jmp(r31);

    // Point one row's sixteen cells at consecutive characters: r10 the first
    // cell's address, r11 the first character. Two columns of gap after the
    // eighth so the report's halves read apart.
    a.label("mapCells");
    a.movea(16, r0, r9);
    a.label("cellNext");
    a.stH(r11, 0, r10);
    a.addImm(2, r10);
    a.addImm(1, r11);
    a.addImm(-1, r9);
    a.cmpImm(8, r9);
    a.bne("cellNoGap");
    a.addImm(4, r10);
    a.label("cellNoGap");
    a.cmpImm(0, r9);
    a.bne("cellNext");
    a.jmp(r31);

    // Paint one word into sixteen row cells: r10 the first character's data
    // address, r7 the word, consumed from bit 15 down so the leftmost cell
    // is the report's top bit. Off cells stay dim so the row reads as
    // sixteen positions rather than a count of lit ones.
    a.label("drawWord");
    a.movea(16, r0, r9);
    a.mov(r10, r6);
    a.label("wordCell");
    a.andi(0x8000, r7, r12);
    a.be("wordBlank");
    a.movea(CELL_ON, r0, r13);
    a.br("wordFill");
    a.label("wordBlank");
    a.movea(CELL_OFF, r0, r13);
    a.label("wordFill");
    a.movImm(6, r8);
    a.label("wordRow");
    a.stH(r13, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("wordRow");
    a.stH(r0, 0, r6);
    a.stH(r0, 2, r6);
    a.addImm(4, r6);
    a.shlImm(1, r7);
    a.addImm(-1, r9);
    a.bne("wordCell");
    a.jmp(r31);

    // Para/Si latches, then sixteen falls of the clock bit walk the report
    // out. The written bit is inverted on the way to the pad, so the pad
    // advances on the write that clears it -- the second of each pair.
    a.label("softRead");
    a.movea(0x20, r0, r7);
    a.stB(r7, 0, r16);
    a.stB(r0, 0, r16);
    a.movea(0x10, r0, r7);
    a.movea(16, r0, r8);
    a.label("softClock");
    a.stB(r7, 0, r16);
    a.stB(r0, 0, r16);
    a.addImm(-1, r8);
    a.bne("softClock");
    a.jmp(r31);

    // HW-SI starts a read; SI-Stat says when the sixteenth bit landed.
    a.label("hwRead");
    a.movImm(4, r7);
    a.stB(r7, 0, r16);
    a.label("hwWait");
    a.inB(0, r16, r7);
    a.andi(2, r7, r7);
    a.bne("hwWait");
    a.jmp(r31);

    // Freeze on r13 with the bar lit and the code in the top row, so a
    // failure names itself on screen and in the status word at once.
    a.label("fail");
    a.stH(r13, 0, r20);
    a.mov(r13, r7);
    a.loadImm(chr(HW_CHAR), r10);
    a.jal("drawWord");
    a.loadImm(BRIGHT, r13);
    a.loadImm(chr(BAR_CHAR), r6);
    a.jal("fillChar");
    a.label("failSpin");
    a.br("failSpin");

    // ----------------------------------------------------------------
    // Setup
    // ----------------------------------------------------------------

    a.label("start");
    a.di();

    a.loadImm(SCR, r16);
    a.movea(0x80, r0, r17);
    a.loadImm(FLAG, r18);
    a.movImm(1, r19);
    a.stH(r0, 0, r18);
    a.loadImm(STATUS, r20);
    a.loadImm(SDLR, r21);

    // Blank every character the display uses, then point the whole map at
    // character 0, so nothing shows power-on junk.
    a.loadImm(chr(0), r6);
    a.movea(CHAR_COUNT * 8, r0, r8);
    a.label("blankChars");
    a.stH(r0, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("blankChars");

    a.loadImm(MAP, r6);
    a.loadImm(4096, r8);
    a.label("clearMap");
    a.stH(r0, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("clearMap");

    // The controls' map regions, plus the cross's centre block.
    CONTROLS.forEach(([, row, col, w, h], index) => {
      a.loadImm(mapCell(row, col), r10);
      a.movea(CTL_CHAR + index, r0, r7);
      a.movImm(w, r8);
      a.movImm(h, r9);
      a.jal("paintRect");
    });
    a.loadImm(mapCell(11, 9), r10);
    a.movea(DPAD_HUB, r0, r7);
    a.movImm(3, r8);
    a.movImm(3, r9);
    a.jal("paintRect");

    a.loadImm(mapCell(HW_ROW, ROWS_COL), r10);
    a.movImm(HW_CHAR, r11);
    a.jal("mapCells");
    a.loadImm(mapCell(SW_ROW, ROWS_COL), r10);
    a.movea(SW_CHAR, r0, r11);
    a.jal("mapCells");

    // The bar: one whole map row of one character, including the sixteen
    // columns past the right edge, which costs nothing.
    a.loadImm(mapCell(BAR_ROW, 0), r10);
    a.movea(BAR_CHAR, r0, r7);
    a.movea(64, r0, r8);
    a.movImm(1, r9);
    a.jal("paintRect");

    // Every control dim, the hub dim, both rows at their off state, so a
    // self-test freeze still shows the whole layout. fillChar leaves r6 on
    // the next character, so the thirteen fills walk 34..46 in one loop.
    a.loadImm(chr(DPAD_HUB), r6);
    a.movImm(13, r9);
    a.label("initCtls");
    a.movea(DIM, r0, r13);
    a.jal("fillChar");
    a.addImm(-1, r9);
    a.bne("initCtls");
    a.mov(r0, r7);
    a.loadImm(chr(HW_CHAR), r10);
    a.jal("drawWord");
    a.mov(r0, r7);
    a.loadImm(chr(SW_CHAR), r10);
    a.jal("drawWord");

    // Brightness, palette, one world over the whole display, and the next
    // world down ending the list -- the same shape vip-bg uses. On before
    // the self-test, so a self-test failure has a screen to show itself on.
    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);
    a.movea(0x80, r0, r7);
    a.stH(r7, 2, r6);
    a.movea(0x3f, r0, r7);
    a.stH(r7, 4, r6);
    a.loadImm(0x0005f860, r6);
    a.movea(0xe4, r0, r7);
    a.stH(r7, 0, r6);

    a.loadImm(0x0003dbe0, r6);
    a.loadImm(0xc000, r7);
    a.stH(r7, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r0, 4, r6);
    a.stH(r0, 6, r6);
    a.stH(r0, 8, r6);
    a.stH(r0, 10, r6);
    a.stH(r0, 12, r6);
    a.loadImm(383, r7);
    a.stH(r7, 14, r6);
    a.loadImm(223, r7);
    a.stH(r7, 16, r6);
    a.loadImm(0x0003dbc0, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);

    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0602, r7);
    a.stH(r7, 0, r6);
    a.loadImm(0x0005f842, r6);
    a.movImm(2, r7);
    a.stH(r7, 0, r6);

    // ----------------------------------------------------------------
    // The self-test, in the one order that can tell the paths apart
    // ----------------------------------------------------------------

    // 1: the data registers come up zero, which is what makes the next
    //    check mean anything.
    readReport(a, r12);
    a.cmpImm(0, r12);
    failUnless(a, "be", 0xe001);

    // 2: a software read alone fills them, before any hardware read has
    //    run. The signature bit is the proof it came from the pad rather
    //    than from noise -- a standard controller always sets it.
    a.jal("softRead");
    readReport(a, r15);
    a.andi(SGN, r15, r12);
    failUnless(a, "bne", 0xe002);

    // 3: HW-SI reports busy while the read is in flight. A hardware read
    //    that never starts would look like an instant one, and its value
    //    would be the software read's still standing.
    a.movImm(4, r7);
    a.stB(r7, 0, r16);
    a.inB(0, r16, r12);
    a.andi(2, r12, r12);
    failUnless(a, "bne", 0xe003);
    a.label("selfWait");
    a.inB(0, r16, r12);
    a.andi(2, r12, r12);
    a.bne("selfWait");

    // 4 and 5: it finished with a real report, and the two paths agree.
    readReport(a, r14);
    a.andi(SGN, r14, r12);
    failUnless(a, "bne", 0xe004);
    a.cmp(r15, r14);
    failUnless(a, "be", 0xe005);

    a.loadImm(PASS, r12);
    a.stH(r12, 0, r20);

    // Reset leaves NP set and interrupts need PSW clear; same idiom as the
    // timer ROM. The keypad sits at level 0, so the mask has to be zero for
    // it to be accepted at all -- which is what makes the bar a real test
    // of the suppression rule rather than of a masked interrupt.
    a.movImm(0, r6);
    a.ldsr(r6, PSW);

    // ----------------------------------------------------------------
    // The display loop: both reads, the picture, both rows, every pass
    // ----------------------------------------------------------------

    a.label("loop");
    a.jal("hwRead");
    readReport(a, r14);
    a.jal("softRead");
    readReport(a, r15);

    // Each control bright while its report bit is up, dim otherwise,
    // decoded from the hardware word.
    CONTROLS.forEach(([mask], index) => {
      const dim = uniq("dim");
      const fill = uniq("ctl");
      a.andi(mask, r14, r12);
      a.be(dim);
      a.loadImm(BRIGHT, r13);
      a.br(fill);
      a.label(dim);
      a.movea(DIM, r0, r13);
      a.label(fill);
      a.loadImm(chr(CTL_CHAR + index), r6);
      a.jal("fillChar");
    });

    a.loadImm(chr(HW_CHAR), r10);
    a.mov(r14, r7);
    a.jal("drawWord");
    a.loadImm(chr(SW_CHAR), r10);
    a.mov(r15, r7);
    a.jal("drawWord");

    // The status word carries what the top row shows, so a run with no
    // screen still has something to judge.
    a.stH(r14, 0, r20);

    // The bar lights if the keypad interrupt ever fired.
    a.ldH(0, r18, r12);
    a.cmpImm(0, r12);
    a.be("barBlank");
    a.loadImm(BRIGHT, r13);
    a.br("barFill");
    a.label("barBlank");
    a.mov(r0, r13);
    a.label("barFill");
    a.loadImm(chr(BAR_CHAR), r6);
    a.jal("fillChar");

    a.jr("loop"); // the unrolled controls put it past a short branch's reach
  },
});
