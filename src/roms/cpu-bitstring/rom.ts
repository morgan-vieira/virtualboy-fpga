import {
  type Assembler,
  PSW,
  r6,
  r8,
  r9,
  r10,
  r11,
  r15,
  r26,
  r27,
  r28,
  r29,
  r30,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r10/r11 data scratch, r26-r30 the bit string descriptors.
//
// Checks 1-7 agree with beetle-vb bit for bit. Checks 8 and 9 are where
// the documents and beetle part ways, and the core follows the documents:
// beetle crosses words one bit early on downward searches (Do_BSTR_Search's
// !srcoff test is the upward condition), and its single-word read cache
// corrupts an overlapping copy already at +32 bits where the documented
// 64-bit buffer keeps it clean [Scroll, CPU > Bit Strings > Bitwise].
// Mednafen therefore freezes at check 8 by design.

const STATUS = 0x05000000;
const PASS = 0x600d;

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

const progress = (a: Assembler) => {
  a.addImm(1, r9);
  a.stH(r9, 0, r6);
};

const expectEq = (a: Assembler, reg: Register, value: number) => {
  const ok = uniq("ok");
  const spin = uniq("spin");
  a.loadImm(value >>> 0, r8);
  a.cmp(r8, reg);
  a.be(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

const expectZ = (a: Assembler, value: number) => {
  a.setf(0x2, r15);
  expectEq(a, r15, value);
};

const descriptors = (
  a: Assembler,
  dstOff: number,
  srcOff: number,
  len: number,
  dst: number,
  src: number,
) => {
  a.loadImm(dstOff, r26);
  a.loadImm(srcOff, r27);
  a.loadImm(len, r28);
  a.loadImm(dst >>> 0, r29);
  a.loadImm(src >>> 0, r30);
};

export default defineRom({
  name: "cpu-bitstring",
  header: { gameTitle: "OPENFPGA CPU BST", makerCode: "OF", gameCode: "VBST", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number, counted in program order in rom.ts. " +
    "Mednafen freezes at check 8 by design: beetle-vb crosses words one bit early " +
    "on downward searches and corrupts an overlapping copy at +32 bits, where the " +
    "documented 64-bit read buffer keeps it clean; the core follows the documents.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r10);
    a.ldsr(r10, PSW);
    a.di();

    // Source and destination patterns in WRAM.
    a.loadImm(0xf0f0f0f0, r10);
    a.stW(r10, 0x200, r6);
    a.loadImm(0x0000aaaa, r10);
    a.stW(r10, 0x204, r6);
    a.loadImm(0x11111111, r10);
    a.stW(r10, 0x300, r6);
    a.loadImm(0x22222222, r10);
    a.stW(r10, 0x304, r6);
    a.loadImm(0x33333333, r10);
    a.stW(r10, 0x308, r6);

    // 1: an aligned 48-bit MOVBSU moves a word and merges the tail, and
    // the five descriptors end where the documents say.
    progress(a);
    descriptors(a, 0, 0, 48, 0x05000300, 0x05000200);
    a.movbsu();
    a.ldW(0x300, r6, r10);
    expectEq(a, r10, 0xf0f0f0f0);
    a.ldW(0x304, r6, r10);
    expectEq(a, r10, 0x2222aaaa);
    expectEq(a, r26, 16);
    expectEq(a, r27, 16);
    expectEq(a, r28, 0);
    expectEq(a, r29, 0x05000304);
    expectEq(a, r30, 0x05000204);

    // 2: offsets and a second operation: XORBSU with source offset 4 into
    // destination offset 8, then NOTBSU over the same span undoes half.
    progress(a);
    descriptors(a, 8, 4, 12, 0x05000308, 0x05000200);
    a.xorbsu();
    a.ldW(0x308, r6, r10);
    expectEq(a, r10, 0x333c3c33);
    descriptors(a, 8, 4, 12, 0x05000308, 0x05000200);
    a.notbsu();
    // NOT writes ~source over the field: ~0xF0F is 0x0F0 in the 12 bits.
    a.ldW(0x308, r6, r10);
    expectEq(a, r10, 0x3330f033);

    // 3: length zero is valid and only masks the descriptors.
    progress(a);
    descriptors(a, 0xffffffff, 0xeeeeeeee, 0, 0x05000303, 0x05000202);
    a.movbsu();
    expectEq(a, r26, 31);
    expectEq(a, r27, 14);
    expectEq(a, r28, 0);
    expectEq(a, r29, 0x05000300);
    expectEq(a, r30, 0x05000200);

    // Search patterns: bit 16 set in one word, a zero word, bit 31 set.
    a.loadImm(0x00010000, r10);
    a.stW(r10, 0x600, r6);
    a.movImm(0, r10);
    a.stW(r10, 0x604, r6);
    a.loadImm(0x80000000, r10);
    a.stW(r10, 0x608, r6);

    // 4: upward search finds bit 16: Z clears, the pointer lands one bit
    // before, r28 keeps the found bit, r29 counts the skips.
    progress(a);
    descriptors(a, 0, 0, 64, 0, 0x05000600);
    a.loadImm(100, r29);
    a.sch1bsu();
    expectZ(a, 0);
    expectEq(a, r27, 15);
    expectEq(a, r28, 48);
    expectEq(a, r29, 116);
    expectEq(a, r30, 0x05000600);

    // 5: an exhausted upward search sets Z and walks past the string.
    progress(a);
    descriptors(a, 0, 0, 32, 0, 0x05000604);
    a.movImm(0, r29);
    a.sch1bsu();
    expectZ(a, 1);
    expectEq(a, r29, 32);
    expectEq(a, r30, 0x05000608);

    // 6: a downward search that finds its first bit still fixes the
    // pointer up one bit -- into the word above.
    progress(a);
    descriptors(a, 0, 31, 40, 0, 0x05000608);
    a.movImm(0, r29);
    a.sch1bsd();
    expectZ(a, 0);
    expectEq(a, r27, 0);
    expectEq(a, r28, 40);
    expectEq(a, r29, 0);
    expectEq(a, r30, 0x0500060c);

    // 7: an overlapping copy 64 bits ahead outruns the read buffer and
    // corrupts the third word -- the documented artifact, and beetle-vb
    // agrees at this distance.
    progress(a);
    a.loadImm(0xdeadbeef, r10);
    a.stW(r10, 0x500, r6);
    a.loadImm(0xcafef00d, r10);
    a.stW(r10, 0x504, r6);
    a.loadImm(0x99999999, r10);
    a.stW(r10, 0x508, r6);
    a.loadImm(0x55555555, r10);
    a.stW(r10, 0x50c, r6);
    a.stW(r10, 0x510, r6);
    descriptors(a, 0, 0, 96, 0x05000508, 0x05000500);
    a.movbsu();
    a.ldW(0x508, r6, r10);
    expectEq(a, r10, 0xdeadbeef);
    a.ldW(0x50c, r6, r10);
    expectEq(a, r10, 0xcafef00d);
    a.ldW(0x510, r6, r10);
    expectEq(a, r10, 0xdeadbeef); // was 0x99999999 before the write landed on it

    // ---- Mednafen diverges from here on, by design ----

    // 8: a downward search crosses the word boundary in whole words, and
    // the address space wraps at the bottom: bit 0 of word 0 is clear (the
    // VIP frame buffer word this ROM zeroes), so the search crosses to
    // 0xFFFFFFFC -- the top of ROM's 0xFF fill -- and finds a set bit.
    progress(a);
    a.movImm(0, r10);
    a.movImm(0, r11);
    a.stW(r10, 0, r11); // VIP word 0 = 0
    descriptors(a, 0, 0, 33, 0, 0x00000000);
    a.movImm(0, r29);
    a.sch1bsd();
    expectZ(a, 0);
    expectEq(a, r27, 0);
    expectEq(a, r28, 32);
    expectEq(a, r29, 1);
    expectEq(a, r30, 0x00000000); // one past the find wraps back up

    // 9: an overlapping copy only 32 bits ahead stays clean -- the 64-bit
    // buffer read both source words before the first write.
    progress(a);
    a.loadImm(0xdeadbeef, r10);
    a.stW(r10, 0x400, r6);
    a.loadImm(0xcafef00d, r10);
    a.stW(r10, 0x404, r6);
    a.loadImm(0x99999999, r10);
    a.stW(r10, 0x408, r6);
    descriptors(a, 0, 0, 64, 0x05000404, 0x05000400);
    a.movbsu();
    a.ldW(0x404, r6, r10);
    expectEq(a, r10, 0xdeadbeef);
    a.ldW(0x408, r6, r10);
    expectEq(a, r10, 0xcafef00d);

    // 10: the upward wrap: all ones from the fill at the top of the space,
    // then the zeroed VIP word answers a zero search.
    progress(a);
    descriptors(a, 0, 16, 64, 0, 0xfffffff8);
    a.movImm(0, r29);
    a.sch0bsu();
    expectZ(a, 0);
    expectEq(a, r27, 31);
    expectEq(a, r28, 16);
    expectEq(a, r29, 48);
    expectEq(a, r30, 0xfffffffc);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
