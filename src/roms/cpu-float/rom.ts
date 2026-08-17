import {
  type Assembler,
  PSW,
  r6,
  r8,
  r9,
  r10,
  r11,
  r15,
  r16,
  r17,
  r18,
  r19,
  r20,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r10/r11 operands, r15 flag captures, r16 PSW snapshots. The FPU
// handler records into r17 (ECR), r18 (EIPC) and r19 (PSW), and r20 counts
// its invocations.
//
// Every PSW assertion snapshots the word into r16 straight after the
// operation under test, because the check helpers' own compares rewrite
// the condition flags.
//
// Expected words follow beetle-vb's fpu path (softfloat with the Mednafen
// overflow hack): round to nearest even, overflow wraps the exponent by
// -192 and still writes, results below the normal range flush to a signed
// zero with FUD and FPR unless they round up to the minimum normal.

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

// Wipe the FP status and condition flags, keeping interrupts disabled.
const clearFlags = (a: Assembler) => {
  a.loadImm(0x00001000, r8);
  a.ldsr(r8, PSW);
};

export default defineRom({
  name: "cpu-float",
  header: { gameTitle: "OPENFPGA CPU FLT", makerCode: "OF", gameCode: "VFLT", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number, counted in program order in rom.ts. " +
    "In Mednafen: loads as OPENFPGA CPU FLT and the last halfword written to " +
    "0x05000000 is 0x600D.",
  handlers: { fpu: "onFpu" },
  program: (a) => {
    // The one FPU handler: record ECR, EIPC and PSW, count the visit, step
    // EIPC past the 4-byte instruction, return.
    a.label("onFpu");
    a.stsr(4, r17); // ECR
    a.stsr(0, r18); // EIPC
    a.stsr(PSW, r19);
    a.addImm(1, r20);
    a.stsr(0, r8);
    a.addImm(4, r8);
    a.ldsr(r8, 0);
    a.reti();

    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r20);
    a.movImm(0, r10);
    a.ldsr(r10, PSW);
    a.di();

    // 1: CVT.WS: exact, negative, INT_MIN, and a rounded conversion.
    progress(a);
    a.movImm(5, r10);
    a.cvtWs(r10, r11);
    expectEq(a, r11, 0x40a00000);
    a.movImm(-7, r10);
    a.cvtWs(r10, r11);
    expectEq(a, r11, 0xc0e00000);
    a.loadImm(0x80000000, r10);
    a.cvtWs(r10, r11);
    expectEq(a, r11, 0xcf000000);
    clearFlags(a);
    a.loadImm(0x7fffffff, r10);
    a.cvtWs(r10, r11);
    a.stsr(PSW, r16);
    expectEq(a, r11, 0x4f000000);
    expectEq(a, r16, 0x00001010); // that one rounded: FPR

    // 2: CVT.SW rounds to nearest even, TRNC.SW toward zero.
    progress(a);
    a.loadImm(0x3fc00000, r10); // 1.5
    a.cvtSw(r10, r11);
    expectEq(a, r11, 2);
    a.loadImm(0x40200000, r10); // 2.5
    a.cvtSw(r10, r11);
    expectEq(a, r11, 2);
    a.trncSw(r10, r11);
    expectEq(a, r11, 2);
    a.loadImm(0xbff33333, r10); // -1.9
    a.trncSw(r10, r11);
    expectEq(a, r11, 0xffffffff);
    a.loadImm(0xcf000000, r10); // exactly INT_MIN converts
    a.cvtSw(r10, r11);
    expectEq(a, r11, 0x80000000);

    // 3: ADDF/SUBF: an exact sum, the tie to even, and the signed zero.
    progress(a);
    a.loadImm(0x3f800000, r10); // 1.0
    a.loadImm(0x40000000, r11); // 2.0
    a.addfS(r11, r10);
    expectEq(a, r10, 0x40400000);
    clearFlags(a);
    a.loadImm(0x3f800000, r10);
    a.loadImm(0x33800000, r11); // 2^-24: the tie, to even
    a.addfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x3f800000);
    expectEq(a, r16, 0x00001010); // FPR from the tie, flags clear
    a.loadImm(0x40a00000, r10);
    a.loadImm(0x40a00000, r11);
    a.subfS(r11, r10);
    a.setf(0x2, r15); // Z sets on the +0 result
    a.setf(0x1, r16); // with CY clear
    expectEq(a, r10, 0x00000000);
    expectEq(a, r15, 1);
    expectEq(a, r16, 0);

    // 4: MULF/DIVF: an exact product, a rounded quotient, the zero's sign.
    progress(a);
    a.loadImm(0x40400000, r10); // 3.0
    a.loadImm(0x40a00000, r11); // 5.0
    a.mulfS(r11, r10);
    expectEq(a, r10, 0x41700000); // 15.0
    clearFlags(a);
    a.loadImm(0x3f800000, r10);
    a.loadImm(0x40400000, r11);
    a.divfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x3eaaaaab); // 1/3 rounds up
    expectEq(a, r16, 0x00001010); // FPR
    a.loadImm(0x80000000, r10); // -0
    a.loadImm(0x40400000, r11);
    a.mulfS(r11, r10);
    expectEq(a, r10, 0x80000000); // the xor keeps the sign

    // 5: CMPF.S drives Z/S/CY like CMP and writes nothing.
    progress(a);
    a.loadImm(0x3f800000, r10);
    a.loadImm(0x40000000, r11);
    a.cmpfS(r11, r10); // 1.0 - 2.0: negative
    a.setf(0x1, r15); // CY
    a.setf(0x2, r16); // Z
    expectEq(a, r15, 1);
    expectEq(a, r16, 0);
    a.loadImm(0x80000000, r10);
    a.movImm(0, r11);
    a.cmpfS(r11, r10); // -0 vs +0: equal
    a.setf(0x2, r15);
    expectEq(a, r15, 1);
    expectEq(a, r10, 0x80000000); // untouched

    // 6: overflow wraps the exponent by -192, writes the result, sets FOV,
    // and raises 0xFF64 at the multiply itself.
    progress(a);
    clearFlags(a);
    a.movImm(0, r20);
    a.loadImm(0x5f800000, r10); // 2^64
    a.loadImm(0x5f800000, r11);
    const bigmul = a.pc;
    a.mulfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x1f800000); // 2^128 wrapped to 2^-64
    expectEq(a, r16, 0x00001040); // FOV; the product was exact, no FPR
    expectEq(a, r17, 0xff64);
    expectEq(a, r18, bigmul);
    expectEq(a, r20, 1);

    // 7: underflow flushes to a signed zero with FUD and FPR, no exception.
    progress(a);
    clearFlags(a);
    a.loadImm(0x0d800000, r10); // 2^-100
    a.loadImm(0x0d800000, r11);
    a.mulfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x00000000);
    expectEq(a, r16, 0x00001031); // FUD | FPR | Z from the zero
    expectEq(a, r20, 1); // still just the one exception

    // 8: DIVF by zero: FZD, code 0xFF68, result killed, flags untouched.
    progress(a);
    clearFlags(a);
    a.loadImm(0x40a00000, r10);
    a.movImm(0, r11);
    a.divfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x40a00000);
    expectEq(a, r16, 0x00001080); // FZD alone
    expectEq(a, r17, 0xff68);
    expectEq(a, r20, 2);

    // 9: 0/0 is FIV, 0xFF70.
    progress(a);
    clearFlags(a);
    a.movImm(0, r10);
    a.movImm(0, r11);
    a.divfS(r11, r10);
    expectEq(a, r17, 0xff70);
    expectEq(a, r20, 3);

    // 10: a reserved operand is FRO, 0xFF60, and outranks the zero divide;
    // a non-zero denormal is reserved too.
    progress(a);
    clearFlags(a);
    a.loadImm(0x7fc00000, r10); // NaN
    a.movImm(0, r11);
    a.divfS(r11, r10);
    expectEq(a, r17, 0xff60);
    expectEq(a, r20, 4);
    a.loadImm(0x00000001, r10);
    a.loadImm(0x3f800000, r11);
    a.addfS(r11, r10);
    expectEq(a, r17, 0xff60);
    expectEq(a, r20, 5);

    // 11: CVT.SW out of range is FIV and keeps the destination.
    progress(a);
    clearFlags(a);
    a.loadImm(0x4f000000, r10); // 2^31
    a.loadImm(0x12341234, r11);
    a.cvtSw(r10, r11);
    expectEq(a, r11, 0x12341234);
    expectEq(a, r17, 0xff70);
    expectEq(a, r20, 6);

    // 12: the boundary that rounds back up to the minimum normal keeps a
    // normal result with FPR alone -- no FUD, no flush.
    progress(a);
    clearFlags(a);
    a.loadImm(0x00ffffff, r10);
    a.loadImm(0x40000000, r11);
    a.divfS(r11, r10);
    a.stsr(PSW, r16);
    expectEq(a, r10, 0x00800000);
    expectEq(a, r16, 0x00001010);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
