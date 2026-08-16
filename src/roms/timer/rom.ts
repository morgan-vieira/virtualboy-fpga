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
  r16,
  r17,
  r20,
  r21,
  r22,
  r23,
  r25,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r7 hardware base, r8 expected-value
// scratch, r9 check counter, r10 poll bound, r11 read scratch, r1 reserved
// (the vector stubs clobber it). The handler owns r20 (interrupt count) and
// reads r16/r17 (its TCR disable and clear bytes) and r21/r22/r23 (the
// reload pair and the TCR value it re-arms with) -- all set before any
// write turns Tim-Z-Int on, because the handler has no scratch of its own.

const STATUS = 0x05000000;
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

// Spins until the interrupt count reaches `value`, giving up -- and
// freezing on the current check number -- after a generous bound.
const waitIrqCount = (a: Assembler, value: number) => {
  const poll = uniq("poll");
  const spin = uniq("spin");
  a.loadImm(500_000, r10);
  a.label(poll);
  a.addImm(-1, r10);
  a.be(spin);
  a.cmpImm(value, r20);
  a.bne(poll);
  const done = uniq("done");
  a.br(done);
  a.label(spin);
  a.br(spin);
  a.label(done);
};

export default defineRom({
  name: "timer",
  header: { gameTitle: "OPENFPGA TIMER", makerCode: "OF", gameCode: "VTMR", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the top row " +
    "of 16 status cells counts up by one each second -- " +
    "0x0001, 0x0002, ... -- and after a timed minute reads 0x003C; the centre square " +
    "never fills. Counting at the wrong rate is a prescaler bug. Cells frozen show " +
    "the failure: a small number N is check N (counted in program order in rom.ts), " +
    "0x0000 means the display phase armed but the timer never interrupted again. In " +
    "Mednafen: loads as OPENFPGA TIMER and freezes with 0x0003 at 0x05000000 -- " +
    "expected there and only there: beetle-vb defers a reload write's counter load " +
    "and resets the reload to 0xFFFF, where the scroll documents an immediate load " +
    "and a reload of zero, and this core follows the scroll. The behavioral run for " +
    "this ROM is src/tests/cpu.v, which drives the real timer RTL.",
  handlers: { timer: "onTimer" },
  program: (a) => {
    // The one handler both phases share: count, stop the timer, clear zero
    // status while disabled (clearing while enabled at zero is the faulty
    // clear and does nothing), restart the interval, re-arm with whatever
    // TCR value the current phase chose.
    a.label("onTimer");
    a.addImm(1, r20);
    a.stB(r16, TCR, r7); // T-Enb off, Tim-Z-Int still set
    a.stB(r17, TCR, r7); // Z-Stat-Clr, acting because disabled
    a.stB(r21, TLR, r7);
    a.stB(r22, THR, r7);
    a.stB(r23, TCR, r7);
    a.reti();

    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(HW, r7);
    a.movImm(0, r9);

    // Reset leaves NP set and interrupts need PSW clear; same idiom as
    // cpu-except. No interrupt can fire before Tim-Z-Int goes on.
    a.movImm(0, r10);
    a.ldsr(r10, PSW);

    // 1: TCR at reset -- unused bits and Z-Stat-Clr read set, all
    // functions off.
    progress(a);
    a.inB(TCR, r7, r11);
    expectEq(a, r11, 0xe4);

    // 2: the counter resets to 0xFFFF.
    progress(a);
    a.inB(TLR, r7, r11);
    expectEq(a, r11, 0xff);
    a.inB(THR, r7, r11);
    expectEq(a, r11, 0xff);

    // 3: the reload resets to 0x0000, the one moment it can disagree with
    // the counter: a TLR write pairs the new low byte with the reload's
    // high byte, so the counter must read 0x0034, not 0xFF34.
    progress(a);
    a.movea(0x34, r0, r11);
    a.stB(r11, TLR, r7);
    a.inB(TLR, r7, r11);
    expectEq(a, r11, 0x34);
    a.inB(THR, r7, r11);
    expectEq(a, r11, 0x00);

    // 4: the registers take any access width -- halfword and word reads
    // see the byte zero-extended, a word write lands its low byte.
    progress(a);
    a.inH(TLR, r7, r11);
    expectEq(a, r11, 0x0034);
    a.inW(TLR, r7, r11);
    expectEq(a, r11, 0x00000034);
    a.movea(0xab, r0, r11);
    a.outW(r11, TLR, r7);
    a.inB(TLR, r7, r11);
    expectEq(a, r11, 0xab);

    // 5: enabled at 20 us the counter counts down to zero, and zero with
    // the timer enabled shows as Z-Stat.
    progress(a);
    a.movImm(0, r11);
    a.stB(r11, THR, r7);
    a.movea(0x10, r0, r11);
    a.stB(r11, TLR, r7);
    a.movea(0x11, r0, r11);
    a.stB(r11, TCR, r7);
    {
      const poll = uniq("poll");
      const spin = uniq("spin");
      const done = uniq("done");
      a.loadImm(200_000, r10);
      a.label(poll);
      a.addImm(-1, r10);
      a.be(spin);
      a.inB(TLR, r7, r11);
      a.cmpImm(0, r11);
      a.bne(poll);
      a.br(done);
      a.label(spin);
      a.br(spin);
      a.label(done);
    }
    a.inB(TCR, r7, r11);
    expectEq(a, r11, 0xf7);

    // 6: the faulty clear -- Z-Stat-Clr while enabled at zero does
    // nothing. Park the counter at zero first: with a non-zero reload it
    // cycles, and a clear caught mid-cycle would act legitimately.
    progress(a);
    a.movImm(0, r11);
    a.stB(r11, TLR, r7); // counter and reload both zero, Tim-Z-Int off
    a.movea(0x15, r0, r11);
    a.stB(r11, TCR, r7);
    a.inB(TCR, r7, r11);
    expectEq(a, r11, 0xf7);

    // 7: disabling holds Z-Stat; clearing once disabled works.
    progress(a);
    a.movea(0x10, r0, r11);
    a.stB(r11, TCR, r7);
    a.inB(TCR, r7, r11);
    expectEq(a, r11, 0xf6);
    a.movea(0x14, r0, r11);
    a.stB(r11, TCR, r7);
    a.inB(TCR, r7, r11);
    expectEq(a, r11, 0xf4);

    // Arm the handler's registers before Tim-Z-Int ever goes on.
    a.movImm(0, r20);
    a.movea(0x18, r0, r16);
    a.movea(0x1c, r0, r17);
    a.movImm(5, r21);
    a.movImm(0, r22);
    a.movImm(0, r23); // phase 1: the handler leaves everything off

    // 8: counting to zero with Tim-Z-Int on takes the interrupt through
    // the 0xFE10 vector; the handler counts once and quiesces.
    progress(a);
    a.stB(r21, TLR, r7);
    a.stB(r22, THR, r7);
    a.movea(0x19, r0, r11);
    a.stB(r11, TCR, r7);
    waitIrqCount(a, 1);

    // 9: a reload write that lands the counter on zero interrupts at
    // once -- the handler left the counter at 5, one zero write drops it.
    progress(a);
    a.movea(0x19, r0, r11);
    a.stB(r11, TCR, r7);
    a.movImm(0, r11);
    a.stB(r11, TLR, r7);
    waitIrqCount(a, 2);

    // 10: the same write-induced zero fires with the timer disabled --
    // MiSTer's reading of the scroll, and the least-documented corner
    // here, so it runs last: a freeze on 10 is this alone misread.
    progress(a);
    a.movea(0x08, r0, r23); // handler re-arms disabled, Tim-Z-Int on
    a.movea(0x08, r0, r11);
    a.stB(r11, TCR, r7);
    a.movImm(7, r11);
    a.stB(r11, TLR, r7);
    a.movImm(0, r11);
    a.stB(r11, TLR, r7);
    waitIrqCount(a, 3);
    a.movImm(0, r11);
    a.stB(r11, TCR, r7); // all off, slate clean

    // Display phase: one interrupt per second -- reload 10000 at 100 us --
    // and the cells show the running count. Writing 0x0000 first marks
    // every check passed; the simulation watches for exactly that.
    a.movImm(0, r20);
    a.movImm(0, r25);
    a.stH(r25, 0, r6);
    a.movea(0x10, r0, r21);
    a.movea(0x27, r0, r22); // reload 0x2710 = 10000
    a.movea(0x09, r0, r23); // 100 us, Tim-Z-Int, enabled
    a.stB(r21, TLR, r7);
    a.stB(r22, THR, r7);
    a.stB(r23, TCR, r7);

    a.label("display");
    a.cmp(r20, r25);
    a.be("display");
    a.mov(r20, r25);
    a.stH(r25, 0, r6);
    a.br("display");
  },
});
