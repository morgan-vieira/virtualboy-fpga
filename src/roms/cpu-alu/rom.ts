import {
  type Assembler,
  r0,
  r6,
  r8,
  r9,
  r11,
  r12,
  r13,
  r14,
  r15,
  r16,
  r17,
  r30,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget, held for the whole program: r6 status base, r9 check
// counter, r8 expected-value scratch, r11-r14 flag captures (OV, CY, Z, S),
// r15-r17 operands under test, r30 multiply/divide side effects, r1 reserved
// for pseudo-instructions.

const STATUS = 0x05000000;
const PASS = 0x600d;

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

// Bumps the on-screen check number before the check runs, so a failure spin
// leaves the number of the check that failed on the status cells.
const progress = (a: Assembler) => {
  a.addImm(1, r9);
  a.stH(r9, 0, r6);
};

// Spins right here unless reg holds value. loadImm/cmp clobber flags, so
// capture flags before comparing anything.
const expectEq = (a: Assembler, reg: Register, value: number) => {
  const ok = uniq("ok");
  const spin = uniq("spin");
  a.loadImm(value, r8);
  a.cmp(r8, reg);
  a.be(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

// setf leaves flags alone, so all four survive into plain registers.
const captureFlags = (a: Assembler) => {
  a.setf(0x0, r11); // OV
  a.setf(0x1, r12); // CY
  a.setf(0x2, r13); // Z
  a.setf(0x4, r14); // S
};

const expectFlags = (a: Assembler, ov: number, cy: number, z: number, s: number) => {
  expectEq(a, r11, ov);
  expectEq(a, r12, cy);
  expectEq(a, r13, z);
  expectEq(a, r14, s);
};

export default defineRom({
  name: "cpu-alu",
  header: { gameTitle: "OPENFPGA CPU ALU", makerCode: "OF", gameCode: "VALU", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of " +
    "16 status cells reads 0x600D (0110 0000 0000 1101, lit = 1). Failure: the square " +
    "stays hollow and the status cells show the number of the failing check, counted " +
    "in program order in rom.ts; the bottom row shows the PC of the failure spin. In " +
    "Mednafen: loads as OPENFPGA CPU ALU and the last halfword written to 0x05000000 " +
    "is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // 1: add, no flags set. 5 + 7 = 12.
    progress(a);
    a.movImm(5, r15);
    a.movImm(7, r16);
    a.add(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 12);
    expectFlags(a, 0, 0, 0, 0);

    // 2: add overflow. 0x7FFFFFFF + 1 = 0x80000000, OV and S.
    progress(a);
    a.loadImm(0x7fffffff, r15);
    a.movImm(1, r16);
    a.add(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0x80000000);
    expectFlags(a, 1, 0, 0, 1);

    // 3: add carry. 0xFFFFFFFF + 1 = 0, CY and Z.
    progress(a);
    a.movImm(-1, r15);
    a.movImm(1, r16);
    a.add(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0);
    expectFlags(a, 0, 1, 1, 0);

    // 4: sub borrow. 3 - 5 = -2, CY (borrow) and S.
    progress(a);
    a.movImm(3, r15);
    a.movImm(5, r16);
    a.sub(r16, r15);
    captureFlags(a);
    expectEq(a, r15, -2 >>> 0);
    expectFlags(a, 0, 1, 0, 1);

    // 5: sub overflow. 0x80000000 - 1 = 0x7FFFFFFF, OV only.
    progress(a);
    a.loadImm(0x80000000, r15);
    a.movImm(1, r16);
    a.sub(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0x7fffffff);
    expectFlags(a, 1, 0, 0, 0);

    // 6: cmp leaves the register alone and sets flags. 9 - 9: Z only.
    progress(a);
    a.movImm(9, r15);
    a.movImm(9, r16);
    a.cmp(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 9);
    expectFlags(a, 0, 0, 1, 0);

    // 7: addi carries a 16-bit immediate. 5 + (-1) = 4 with carry-out.
    progress(a);
    a.movImm(5, r15);
    a.addi(-1, r15, r15);
    captureFlags(a);
    expectEq(a, r15, 4);
    expectFlags(a, 0, 1, 0, 0);

    // 8: mul splits the product. 0x10000 * 0x10000: high word 1 to r30, low
    // word 0 to the destination; Z considers only the low word, OV the pair.
    progress(a);
    a.loadImm(0x10000, r15);
    a.loadImm(0x10000, r16);
    a.mul(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0);
    expectEq(a, r30, 1);
    expectFlags(a, 1, 0, 1, 0);

    // 9: mul writes r30 before the destination, so r30 as destination keeps
    // the low word. 6 * 7 = 42, not the high word 0.
    progress(a);
    a.movImm(6, r30);
    a.movImm(7, r16);
    a.mul(r16, r30);
    expectEq(a, r30, 42);

    // 10: mulu. 0xFFFFFFFF * 2 = 0x1_FFFFFFFE: OV from the non-zero high
    // word, S from bit 31 of the low word.
    progress(a);
    a.movImm(-1, r15);
    a.movImm(2, r16);
    a.mulu(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0xfffffffe);
    expectEq(a, r30, 1);
    expectFlags(a, 1, 0, 0, 1);

    // 11: div rounds toward zero, remainder takes the dividend's sign.
    // -7 / 2 = -3 remainder -1.
    progress(a);
    a.movImm(-7, r15);
    a.movImm(2, r16);
    a.div(r16, r15);
    captureFlags(a);
    expectEq(a, r15, -3 >>> 0);
    expectEq(a, r30, -1 >>> 0);
    expectFlags(a, 0, 0, 0, 1);

    // 12: the one dividable overflow. 0x80000000 / -1 keeps the dividend,
    // zero remainder, OV set.
    progress(a);
    a.loadImm(0x80000000, r15);
    a.movImm(-1, r16);
    a.div(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0x80000000);
    expectEq(a, r30, 0);
    expectFlags(a, 1, 0, 0, 1);

    // 13: divu clears OV. 7 / 2 = 3 remainder 1.
    progress(a);
    a.movImm(7, r15);
    a.movImm(2, r16);
    a.divu(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 3);
    expectEq(a, r30, 1);
    expectFlags(a, 0, 0, 0, 0);

    // 14: div writes the remainder to r30 before the quotient, so r30 as
    // destination ends with the quotient. 42 / 5 = 8, not remainder 2.
    progress(a);
    a.movImm(-1, r15);
    a.loadImm(42, r30);
    a.movImm(5, r16);
    a.div(r16, r30);
    expectEq(a, r30, 8);

    // 15: bitwise ops clear OV. Set OV with an overflowing add, then check
    // an OR drops it.
    progress(a);
    a.loadImm(0x7fffffff, r15);
    a.movImm(1, r16);
    a.add(r16, r15); // OV=1 CY=0
    a.movImm(3, r15);
    a.movImm(5, r16);
    a.or(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 7);
    expectFlags(a, 0, 0, 0, 0);

    // 16: and, xor, not values and S from bit 31.
    progress(a);
    a.movImm(-1, r15);
    a.loadImm(0x0f0f0f0f, r16);
    a.and(r16, r15);
    expectEq(a, r15, 0x0f0f0f0f);
    a.loadImm(0xf0f0f0f0, r16);
    a.xor(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 0xffffffff);
    expectFlags(a, 0, 0, 0, 1);
    a.not(r15, r16);
    captureFlags(a);
    expectEq(a, r16, 0);
    expectFlags(a, 0, 0, 1, 0);

    // 17: andi zero-extends its immediate, so the result can never be
    // negative: S is clear even with bit 15 set in both operands.
    progress(a);
    a.movImm(-1, r15);
    a.andi(0x8000, r15, r15);
    captureFlags(a);
    expectEq(a, r15, 0x8000);
    expectFlags(a, 0, 0, 0, 0);

    // 18: shl. 3 << 31: last bit shifted out is bit 1, so CY=1.
    progress(a);
    a.movImm(3, r15);
    a.shlImm(31, r15);
    captureFlags(a);
    expectEq(a, r15, 0x80000000);
    expectFlags(a, 0, 1, 0, 1);

    // 19: shr. 0x80000001 >> 1: bit 0 out, zero into the top.
    progress(a);
    a.loadImm(0x80000001, r15);
    a.shrImm(1, r15);
    captureFlags(a);
    expectEq(a, r15, 0x40000000);
    expectFlags(a, 0, 1, 0, 0);

    // 20: sar replicates the sign. 0x80000000 >> 4, nothing but zeros out.
    progress(a);
    a.loadImm(0x80000000, r15);
    a.sarImm(4, r15);
    captureFlags(a);
    expectEq(a, r15, 0xf8000000);
    expectFlags(a, 0, 0, 0, 1);

    // 21: a zero shift amount leaves the value and clears CY, even when CY
    // was set going in.
    progress(a);
    a.movImm(-1, r15);
    a.movImm(1, r16);
    a.add(r16, r15); // CY=1
    a.movImm(5, r15);
    a.movImm(0, r16);
    a.shl(r16, r15);
    captureFlags(a);
    expectEq(a, r15, 5);
    expectFlags(a, 0, 0, 0, 0);

    // 22: a register shift amount is masked to five bits: 33 shifts by 1.
    progress(a);
    a.movImm(3, r15);
    a.loadImm(33, r16);
    a.shl(r16, r15);
    expectEq(a, r15, 6);

    // 23: movea sign-extends and, like every register transfer, leaves the
    // flags exactly as they were (here: CY and Z from 0xFFFFFFFF + 1).
    progress(a);
    a.movImm(-1, r15);
    a.movImm(1, r16);
    a.add(r16, r15); // CY=1 Z=1
    a.movea(-0x8000, r0, r15);
    a.movhi(0x1234, r0, r16);
    captureFlags(a);
    expectEq(a, r15, 0xffff8000);
    expectEq(a, r16, 0x12340000);
    expectFlags(a, 0, 1, 1, 0);

    // 24: r0 discards writes.
    progress(a);
    a.movImm(-5, r0);
    a.movImm(0, r15);
    a.cmp(r15, r0);
    captureFlags(a);
    expectFlags(a, 0, 0, 1, 0);

    // 25: stores write only the low bits; loads sign-extend where inputs
    // zero-extend. One word planted, picked apart every way.
    progress(a);
    a.loadImm(0xa55a8163, r15);
    a.stW(r15, 0x100, r6);
    a.ldB(0x100, r6, r16);
    expectEq(a, r16, 0x63);
    a.ldB(0x101, r6, r16);
    expectEq(a, r16, 0xffffff81);
    a.inB(0x101, r6, r16);
    expectEq(a, r16, 0x81);
    a.ldH(0x100, r6, r16);
    expectEq(a, r16, 0xffff8163);
    a.inH(0x100, r6, r16);
    expectEq(a, r16, 0x8163);
    a.ldH(0x102, r6, r16);
    expectEq(a, r16, 0xffffa55a);
    a.ldW(0x100, r6, r16);
    expectEq(a, r16, 0xa55a8163);

    // 26: st.b touches one byte, st.h one halfword.
    progress(a);
    a.loadImm(0x11, r16);
    a.stB(r16, 0x101, r6);
    a.ldW(0x100, r6, r16);
    expectEq(a, r16, 0xa55a1163);
    a.loadImm(0xbeef, r16);
    a.stH(r16, 0x102, r6);
    a.ldW(0x100, r6, r16);
    expectEq(a, r16, 0xbeef1163);

    // 27: unaligned accesses round down: bit 0 for halfwords, bits 1-0 for
    // words. Same data through misaligned addresses.
    progress(a);
    a.ldH(0x103, r6, r16); // rounds to 0x102
    expectEq(a, r16, 0xffffbeef);
    a.ldW(0x103, r6, r16); // rounds to 0x100
    expectEq(a, r16, 0xbeef1163);
    a.loadImm(0x55aa, r16);
    a.stH(r16, 0x105, r6); // rounds to 0x104
    a.ldH(0x104, r6, r17);
    expectEq(a, r17, 0x55aa);

    // 28: out and in mirror store and load onto the same bus.
    progress(a);
    a.loadImm(0xc0de, r16);
    a.outH(r16, 0x108, r6);
    a.inH(0x108, r6, r17);
    expectEq(a, r17, 0xc0de);
    a.outW(r15, 0x10c, r6);
    a.inW(0x10c, r6, r17);
    expectEq(a, r17, 0xa55a8163);

    // Success: leave 0x600D on the cells, fill the square.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
