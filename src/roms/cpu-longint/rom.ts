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
  r21,
  r22,
  r24,
  r26,
  r27,
  r28,
  r29,
  r30,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Interrupts against long-running instructions, timed by the real timer at
// its fastest rate (reload 1 at 20 us = one interrupt per 400 cycles).
//
// Register budget -- the handler can fire between any two instructions, so
// its registers never overlap the main flow's: main uses r6 status, r9
// check counter, r8 expect scratch, r10-r15 work, r26-r30 descriptors; the
// handler owns r7 (hardware base), r16 (the acknowledge byte), r17/r18
// (the divide's and the string's addresses), r19 (interrupt count), r21
// (saw the divide aborted), r22 (saw the string interrupted), r24 scratch.

const STATUS = 0x05000000;
const PASS = 0x600d;
const HW = 0x02000000;
const TLR = 0x18;
const THR = 0x1c;
const TCR = 0x20;

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
  name: "cpu-longint",
  header: { gameTitle: "OPENFPGA CPU LNG", makerCode: "OF", gameCode: "VLNG", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number. Mednafen freezes at check 5 by " +
    "design: beetle-vb never aborts a divide mid-flight. If the Pocket freezes at " +
    "check 5, real silicon does not abort DIV either -- record that finding and " +
    "the core follows the scroll's between-instructions rule instead of the V810 " +
    "manual's Table 6-2.",
  handlers: { timer: "onTimer" },
  program: (a) => {
    let bstrAddr = 0;
    let divAddr = 0;

    a.jr("start");

    // Acknowledge, count, and note whether the saved PC is one of the two
    // long instructions -- the abort evidence the checks assert on.
    a.label("onTimer");
    a.stB(r16, TCR, r7);
    a.addImm(1, r19);
    a.stsr(0, r24); // EIPC
    a.cmp(r17, r24);
    a.bne("notDiv");
    a.movImm(1, r21);
    a.label("notDiv");
    a.cmp(r18, r24);
    a.bne("notBstr");
    a.movImm(1, r22);
    a.label("notBstr");
    a.reti();

    // ---- phase 1: a 8,192-bit MOVBSU under fire ----
    a.label("phase1");
    progress(a); // 1
    a.movImm(0, r26);
    a.movImm(0, r27);
    a.loadImm(8192, r28);
    a.loadImm(0x05002000, r29);
    a.loadImm(0x05001000, r30);
    a.label("bstr");
    bstrAddr = a.pc;
    a.movbsu();

    // 2: the string completed across every interruption: length drained
    // and the destination checksum matches the source's.
    progress(a);
    expectEq(a, r28, 0);
    a.loadImm(0x05001000, r11);
    a.movImm(0, r13);
    a.loadImm(256, r12);
    a.label("suma");
    a.ldW(0, r11, r10);
    a.add(r10, r13);
    a.addImm(4, r11);
    a.addImm(-1, r12);
    a.bne("suma");
    a.loadImm(0x05002000, r11);
    a.movImm(0, r14);
    a.loadImm(256, r12);
    a.label("sumb");
    a.ldW(0, r11, r10);
    a.add(r10, r14);
    a.addImm(4, r11);
    a.addImm(-1, r12);
    a.bne("sumb");
    a.cmp(r13, r14);
    a.be("sumok");
    a.label("sumspin");
    a.br("sumspin");
    a.label("sumok");
    a.loadImm(0x05001000, r11);
    a.ldW(0, r11, r13);
    a.loadImm(0x05002000, r11);
    a.ldW(0, r11, r14);
    a.cmp(r13, r14);
    a.be("w0ok");
    a.label("w0spin");
    a.br("w0spin");
    a.label("w0ok");

    // 3: at ~9 interrupts inside a ~3,600-cycle string, at least one saved
    // the string's own address.
    progress(a);
    expectEq(a, r22, 1);

    // ---- phase 2: 1,024 divides under fire, each one re-verified ----
    // 4: a spin here means an interrupted divide produced a wrong result.
    progress(a);
    a.loadImm(0x30000000, r13); // dividend, changing each pass
    a.loadImm(1024, r12);
    a.label("dloop");
    a.addImm(1, r13);
    a.mov(r13, r10);
    a.movImm(7, r11);
    a.label("divi");
    divAddr = a.pc;
    a.div(r11, r10);
    // quotient * 7 + remainder must rebuild the dividend
    a.mov(r30, r14);
    a.movImm(7, r15);
    a.mul(r15, r10);
    a.add(r14, r10);
    a.cmp(r13, r10);
    a.be("divok");
    a.label("divspin");
    a.br("divspin");
    a.label("divok");
    a.addImm(-1, r12);
    a.bne("dloop");

    // 5: at least one of those thousand interrupts landed mid-divide and
    // saved the divide's own address -- the abort the manual documents.
    progress(a);
    expectEq(a, r21, 1);

    // Quiet the timer and report.
    a.movImm(0, r10);
    a.stB(r10, TCR, r7);
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();

    // ---- entry: constants, source pattern, timer, then the phases ----
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r10);
    a.ldsr(r10, PSW);
    a.di();
    a.loadImm(HW, r7);
    a.movea(0x1d, r0, r16); // acknowledge: enabled, 20 us, int, clear
    a.loadImm(divAddr, r17);
    a.loadImm(bstrAddr, r18);
    a.movImm(0, r19);
    a.movImm(0, r21);
    a.movImm(0, r22);

    // The source pattern, summed the same way check 2 sums it back.
    a.loadImm(0x05001000, r11);
    a.loadImm(0x13579bdf, r10);
    a.loadImm(256, r12);
    a.label("fill");
    a.stW(r10, 0, r11);
    a.loadImm(0x01030507, r8);
    a.add(r8, r10);
    a.addImm(4, r11);
    a.addImm(-1, r12);
    a.bne("fill");

    // Arm the timer: reload 1 at 20 us, interrupt on zero, and open the
    // mask.
    a.movImm(1, r10);
    a.stB(r10, TLR, r7);
    a.movImm(0, r10);
    a.stB(r10, THR, r7);
    a.movea(0x19, r0, r10);
    a.stB(r10, TCR, r7);
    a.ei();
    a.jr("phase1");
  },
});
