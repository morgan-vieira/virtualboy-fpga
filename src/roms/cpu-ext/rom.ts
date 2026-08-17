import {
  type Assembler,
  PSW,
  r0,
  r6,
  r8,
  r9,
  r10,
  r11,
  r12,
  r13,
  r14,
  r15,
  r30,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r10-r15 operands, r30 CAXI's exchange value.

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

export default defineRom({
  name: "cpu-ext",
  header: { gameTitle: "OPENFPGA CPU EXT", makerCode: "OF", gameCode: "VEXT", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number, counted in program order in rom.ts. " +
    "In Mednafen: loads as OPENFPGA CPU EXT and the last halfword written to " +
    "0x05000000 is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r10);
    a.ldsr(r10, PSW);
    a.di();

    // 1: XB swaps the low bytes and keeps the high halfword.
    progress(a);
    a.loadImm(0x12345678, r10);
    a.xb(r10);
    expectEq(a, r10, 0x12347856);

    // 2: XH swaps the halfwords.
    progress(a);
    a.loadImm(0x12345678, r10);
    a.xh(r10);
    expectEq(a, r10, 0x56781234);

    // 3: REV mirrors reg1's bits into reg2.
    progress(a);
    a.loadImm(0x12345678, r10);
    a.rev(r10, r11);
    expectEq(a, r11, 0x1e6a2c48);
    expectEq(a, r10, 0x12345678);

    // 4: MPYHW sign-extends the low 17 bits -- 0x1FFFF is -1, not 131071.
    progress(a);
    a.movea(1000, r0, r10);
    a.loadImm(0x1ffff, r11);
    a.mpyhw(r11, r10);
    expectEq(a, r10, 0xfffffc18);
    a.movImm(3, r10);
    a.loadImm(0xffff, r11);
    a.mpyhw(r11, r10);
    expectEq(a, r10, 3 * 0xffff);

    // 5: none of the four touch the flags. Set CY and Z, run them, read PSW.
    progress(a);
    a.movImm(-1, r12);
    a.movImm(1, r13);
    a.add(r13, r12); // CY=1 Z=1
    a.loadImm(0x12345678, r14);
    a.xb(r14);
    a.xh(r14);
    a.rev(r14, r14);
    a.mpyhw(r13, r14);
    a.stsr(PSW, r15);
    expectEq(a, r15, 0x00001009); // ID | CY | Z

    // 6: CAXI on a match: memory takes r30, reg2 takes the old word, Z sets.
    progress(a);
    a.loadImm(0x11112222, r10);
    a.stW(r10, 0x40, r6);
    a.loadImm(0x33334444, r30);
    a.caxi(0x40, r6, r10);
    a.setf(0x2, r11); // Z
    expectEq(a, r11, 1);
    expectEq(a, r10, 0x11112222);
    a.ldW(0x40, r6, r12);
    expectEq(a, r12, 0x33334444);

    // 7: CAXI on a mismatch: memory keeps its word (rewritten with itself),
    // reg2 takes it, and the compare drives the flags like CMP. The
    // exchange value is changed first, so a mismatch that wrongly stored
    // it would show.
    progress(a);
    a.loadImm(0x77778888, r30);
    a.loadImm(0x55555555, r13);
    a.caxi(0x40, r6, r13);
    a.setf(0x2, r11); // Z
    expectEq(a, r11, 0);
    a.setf(0x1, r11); // CY: greater compare leaves it clear
    expectEq(a, r11, 0);
    expectEq(a, r13, 0x33334444);
    a.ldW(0x40, r6, r12);
    expectEq(a, r12, 0x33334444);

    // 8: a lower compare value borrows and sets CY.
    progress(a);
    a.loadImm(0x11111111, r13);
    a.caxi(0x40, r6, r13);
    a.setf(0x1, r11); // CY
    expectEq(a, r11, 1);
    expectEq(a, r13, 0x33334444);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
