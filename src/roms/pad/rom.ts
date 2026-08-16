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

// The raw report, one cell per bit, twice: the top row is what a hardware
// read returned and the bottom row what a software read returned. Bit 15 is
// leftmost, and the wider gap in the middle separates SDHR's eight bits
// from SDLR's.
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
const mapRow = (row: number) => MAP + row * 64 * 2;

// Six character rows of cells, two bands, and a three-row bar underneath
// that lights only if something went wrong.
const TOP_ROW = 6;
const BOTTOM_ROW = 16;
const BAR_ROW = 24;
const BAR_CHAR = 33;

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
// on `sentinel` with the bar lit.
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
    "On the Pocket: two rows of sixteen red cells, each cell one bit of the game " +
    "pad's report, bit 15 leftmost and bit 0 rightmost, with a wider gap in the " +
    "middle separating the left eight (SDHR) from the right eight (SDLR). The top " +
    "row is a hardware read and the bottom row a software read. Counting cells from " +
    "the left, with nothing pressed exactly cell 15 is lit in both rows and nothing " +
    "else: that is the signature bit a standard controller always sets. Each button " +
    "then lights exactly one further cell in both rows and no other -- B cell 1, Y " +
    "cell 2, Up cell 5, Down cell 6, Left cell 7, Right cell 8, A cell 9, X cell 10, " +
    "Select cell 11, Start cell 12, R cell 13, L cell 14 -- and releasing it puts " +
    "that cell out again. Cells 3, 4 and 16 stay dark with every button held at " +
    "once, because nothing reaches them in the default mapping. In Core Settings, " +
    "switching 'Select and Start' to 'Select and Start' moves Select to cell 3 and " +
    "Start to cell 4 and leaves 11 and 12 dark; switching 'D-Pad' to 'Right Pad' " +
    "swaps the D-pad and the face buttons, so Up becomes cell 10 and X becomes cell " +
    "5. The three-row bar across the bottom must stay black throughout: it lights " +
    "for a failed startup self-test, and for a keypad interrupt, which a controller " +
    "that sets the signature bit can never cause. A lit bar at boot is the " +
    "self-test: the cells then hold 0xE001 (the data registers were not zero out of " +
    "reset), 0xE002 (a software read alone never filled them, so the software clock " +
    "or the latch is broken), 0xE003 (HW-SI did not report busy), 0xE004 (the " +
    "hardware read finished but returned no signature bit) or 0xE005 (the two reads " +
    "disagreed). A black screen means the VIP never drew; a pattern that ignores " +
    "buttons means the reads stopped completing. In Mednafen: loads as OPENFPGA PAD " +
    "and freezes on 0xE001 -- expected there and only there, because beetle-vb's " +
    "instant-read hack answers the data registers with live pad state instead of " +
    "the reset zero the scroll documents. The behavioural run for this ROM is " +
    "src/tests/cpu.v, which drives the real game pad RTL.",
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

    // Paint one band of sixteen cells: r10 the map address of its first
    // row, r11 the character its leftmost cell uses. Each cell is two
    // characters wide over six rows with one column of gap, and the gap
    // after the eighth is two columns so the report's halves read apart.
    a.label("writeBand");
    a.movea(16, r0, r9);
    a.mov(r10, r12);
    a.label("bandCell");
    a.movImm(6, r8);
    a.mov(r12, r6);
    a.label("bandRow");
    a.stH(r11, 0, r6);
    a.stH(r11, 2, r6);
    a.addi(128, r6, r6);
    a.addImm(-1, r8);
    a.bne("bandRow");
    a.addImm(6, r12);
    a.addImm(1, r11);
    a.addImm(-1, r9);
    a.cmpImm(8, r9);
    a.bne("bandNoGap");
    a.addImm(2, r12);
    a.label("bandNoGap");
    a.cmpImm(0, r9);
    a.bne("bandCell");
    a.jmp(r31);

    // Paint one word into sixteen characters: r10 the first character's
    // data address, r7 the word, consumed from bit 15 down so the leftmost
    // cell is the report's top bit.
    a.label("drawWord");
    a.movea(16, r0, r9);
    a.mov(r10, r6);
    a.label("wordCell");
    a.andi(0x8000, r7, r12);
    a.be("wordBlank");
    a.loadImm(0xffff, r13);
    a.br("wordFill");
    a.label("wordBlank");
    a.mov(r0, r13);
    a.label("wordFill");
    a.movImm(8, r8);
    a.label("wordRow");
    a.stH(r13, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("wordRow");
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

    // Freeze on r13 with the bar lit, so a failure names itself on screen
    // and in the status word at once.
    a.label("fail");
    a.stH(r13, 0, r20);
    a.loadImm(0xffff, r12);
    a.loadImm(chr(BAR_CHAR), r6);
    a.movImm(8, r8);
    a.label("failRow");
    a.stH(r12, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("failRow");
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
    a.movea((BAR_CHAR + 1) * 8, r0, r8);
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

    a.loadImm(mapRow(TOP_ROW), r10);
    a.movImm(1, r11);
    a.jal("writeBand");
    a.loadImm(mapRow(BOTTOM_ROW), r10);
    a.movea(17, r0, r11);
    a.jal("writeBand");

    // The bar: three whole map rows of one character, including the sixteen
    // columns past the right edge, which costs nothing.
    a.loadImm(mapRow(BAR_ROW), r6);
    a.movea(BAR_CHAR, r0, r7);
    a.movea(192, r0, r8);
    a.label("barMap");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("barMap");

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
    // The display loop: both reads, both rows, every pass
    // ----------------------------------------------------------------

    a.label("loop");
    a.jal("hwRead");
    readReport(a, r14);
    a.jal("softRead");
    readReport(a, r15);

    a.loadImm(chr(1), r10);
    a.mov(r14, r7);
    a.jal("drawWord");
    a.loadImm(chr(17), r10);
    a.mov(r15, r7);
    a.jal("drawWord");

    // The status word carries what the top row shows, so a run with no
    // screen still has something to judge.
    a.stH(r14, 0, r20);

    // The bar lights if the keypad interrupt ever fired.
    a.ldH(0, r18, r12);
    a.cmpImm(0, r12);
    a.be("barBlank");
    a.loadImm(0xffff, r13);
    a.br("barFill");
    a.label("barBlank");
    a.mov(r0, r13);
    a.label("barFill");
    a.loadImm(chr(BAR_CHAR), r6);
    a.movImm(8, r8);
    a.label("barRow");
    a.stH(r13, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("barRow");

    a.br("loop");
  },
});
