import {
  type Assembler,
  r0,
  r6,
  r7,
  r8,
  r9,
  r10,
  r12,
  r13,
  r15,
  r16,
  r17,
  r20,
  r31,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Draw and display scheduling: XPEN and XPBSY visibility, XPEND, FRMCYC
// cadence, framebuffer ownership across game-frame boundaries, SBOUT and
// SBHIT, XPRST recovery, genuine overtime, and DPRST. Checks report through
// the status cells; a failing check spins with its number showing.
//
// Register budget: r6 status base, r7 VIP register base, r8 expected value,
// r9 check counter, r10 left base of the drawn buffer, r12/r13 saved bases,
// r15-r17/r20 scratch, r31 drawFrame link, r1 reserved.

const STATUS = 0x05000000;
const REGS = 0x0005f800;
const W31 = 0x0003dbe0;
const PASS = 0x600d;

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

const progress = (a: Assembler) => {
  a.addImm(1, r9);
  a.stH(r9, 0, r6);
};

const fail = (a: Assembler) => {
  const spin = uniq("spin");
  a.label(spin);
  a.br(spin);
};

const expectEq = (a: Assembler, reg: Register, value: number) => {
  const ok = uniq("ok");
  a.loadImm(value, r8);
  a.cmp(r8, reg);
  a.be(ok);
  fail(a);
  a.label(ok);
};

const put = (a: Assembler, address: number, value: number) => {
  a.loadImm(address, r15);
  a.loadImm(value, r16);
  a.stH(r16, 0, r15);
};

const world = (a: Assembler, base: number, words: ReadonlyArray<number>) => {
  a.loadImm(base, r15);
  for (let i = 0; i < 11; i += 1) {
    a.loadImm(words[i] ?? 0, r16);
    a.stH(r16, i * 2, r15);
  }
};

// Poll INTPND until a bit in `mask` is set, leaving INTPND in r20.
const waitPending = (a: Assembler, mask: number) => {
  const loop = uniq("wait");
  a.label(loop);
  a.ldH(0, r7, r20);
  a.andi(mask, r20, r20);
  a.be(loop);
};

const intclr = (a: Assembler, mask: number) => {
  a.loadImm(mask, r20);
  a.stH(r20, 4, r7);
};

const draw = (a: Assembler) => a.jal("drawFrame");

export default defineRom({
  name: "vip-sched",
  header: { gameTitle: "OPENFPGA VIPSCHD", makerCode: "OF", gameCode: "VVSC", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red and the top status cells read 0x600D. Checks 8 and 9 " +
    "each wait through a deliberately heavy scene, so allow a few seconds. " +
    "Failure: the square stays hollow and the cells show the failing check's " +
    "number, counted in program order in rom.ts. Checks 1-6 cover XPEN and XPBSY " +
    "readback, XPEND, the FRMCYC cadence, and double-buffer ownership; 7-10 cover " +
    "SBOUT/SBHIT, XPRST, overtime, and DPRST. In Mednafen the image loads and " +
    "freezes at check 7 by design: beetle-vb never raises SBHIT, never reports " +
    "SBOUT, swaps buffers on XPRST, and never sets OVERTIME, all of which the " +
    "scroll or MiSTer's measured behavior establishes differently.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(REGS, r7);
    a.movImm(0, r9);

    // DRAM powers up as pseudorandom contents; clear what the checks use.
    a.loadImm(0x00020000, r15);
    a.loadImm(0x10000, r16);
    a.label("clrDram");
    a.stH(r0, 0, r15);
    a.addImm(2, r15);
    a.addImm(-1, r16);
    a.bne("clrDram");

    for (let row = 0; row < 8; row += 1) {
      put(a, 0x00006000 + row * 2, 0x0000);
      put(a, 0x00006010 + row * 2, 0x5555);
      put(a, 0x00006020 + row * 2, 0xaaaa);
      put(a, 0x00006030 + row * 2, 0xffff);
    }
    put(a, 0x0005f860, 0x00e4);
    world(a, W31 - 0x20, [0x0040]);
    world(a, W31, [0xc000, 0, 0, 0, 0, 0, 0, 383, 223, 0, 0]);
    put(a, 0x00020000, 0x0001);
    // Display on so the display-side conditions run.
    put(a, 0x0005f822, 0x0302);

    // 1: XPEN reads back through XPSTTS.
    progress(a);
    a.movImm(2, r20);
    a.stH(r20, 0x42, r7);
    a.ldH(0x40, r7, r20);
    a.andi(0x0002, r20, r20);
    expectEq(a, r20, 0x0002);

    // 2: a draw begins at the next game frame and XPBSY names a buffer.
    progress(a);
    a.label("c2busy");
    a.ldH(0x40, r7, r20);
    a.andi(0x000c, r20, r20);
    a.be("c2busy");

    // 3: the draw ends with XPEND pending.
    progress(a);
    waitPending(a, 0x4000);
    intclr(a, 0x4000);
    a.stH(r0, 0x42, r7);

    // 4: with FRMCYC=1 exactly two display frames separate game frames.
    progress(a);
    put(a, 0x0005f82e, 0x0001);
    intclr(a, 0x0018);
    waitPending(a, 0x0008);
    intclr(a, 0x0018);
    a.movImm(0, r17);
    a.label("c4count");
    waitPending(a, 0x0018);
    a.mov(r20, r16);
    a.andi(0x0008, r16, r16);
    a.bne("c4game");
    a.addImm(1, r17);
    intclr(a, 0x0010);
    a.br("c4count");
    a.label("c4game");
    a.ldH(0, r7, r20);
    a.andi(0x0010, r20, r20);
    a.be("c4nofs");
    a.addImm(1, r17);
    a.label("c4nofs");
    expectEq(a, r17, 2);
    put(a, 0x0005f82e, 0x0000);
    intclr(a, 0x0018);

    // 5: consecutive draws land in opposite buffers and the earlier image
    // survives in its own.
    progress(a);
    draw(a);
    a.mov(r10, r12);
    put(a, 0x00020000, 0x0002);
    draw(a);
    a.mov(r10, r13);
    a.cmp(r12, r13);
    a.bne("c5distinct");
    fail(a);
    a.label("c5distinct");
    a.ldH(0, r13, r20);
    a.andi(0xffff, r20, r20);
    expectEq(a, r20, 0xaaaa);
    a.ldH(0, r12, r20);
    a.andi(0xffff, r20, r20);
    expectEq(a, r20, 0x5555);

    // 6: the pending buffer is consumed at the game-frame boundary that
    // starts the next draw, which therefore reuses the first buffer.
    progress(a);
    put(a, 0x00020000, 0x0003);
    draw(a);
    a.cmp(r10, r12);
    a.be("c6same");
    fail(a);
    a.label("c6same");
    a.ldH(0, r10, r20);
    a.andi(0xffff, r20, r20);
    expectEq(a, r20, 0xffff);

    // 7: SBHIT fires when the compared group starts, while SBOUT holds and
    // well before XPEND. SBCMP sat at zero through every earlier draw, so
    // each of them fired SBHIT at strip 0; clear the stale pending when
    // arming or this check sees it instantly with no draw running — the
    // hardware failure the 2026-08-17 run caught.
    progress(a);
    a.loadImm(0x0502, r20);
    a.stH(r20, 0x42, r7);
    intclr(a, 0x6000);
    waitPending(a, 0x2000);
    a.ldH(0, r7, r20);
    a.andi(0x4000, r20, r20);
    expectEq(a, r20, 0x0000);
    a.ldH(0x40, r7, r20);
    a.loadImm(0x8000, r16);
    a.and(r16, r20);
    expectEq(a, r20, 0x8000);
    a.label("c7sbout");
    a.ldH(0x40, r7, r20);
    a.and(r16, r20);
    a.cmpImm(0, r20);
    a.bne("c7sbout");
    waitPending(a, 0x4000);
    intclr(a, 0x6000);
    a.stH(r0, 0x42, r7);

    // 8: XPRST aborts the draw, clears XPEN and the drawing interrupts,
    // and leaves buffer ownership alone.
    progress(a);
    a.movImm(2, r20);
    a.stH(r20, 0x42, r7);
    a.label("c8busy");
    a.ldH(0x40, r7, r20);
    a.andi(0x000c, r20, r20);
    a.be("c8busy");
    a.cmpImm(8, r20);
    a.movImm(0, r12);
    a.bne("c8fb0");
    a.loadImm(0x8000, r12);
    a.label("c8fb0");
    a.movImm(1, r20);
    a.stH(r20, 0x42, r7);
    a.label("c8idle");
    a.ldH(0x40, r7, r20);
    a.andi(0x000e, r20, r20);
    a.bne("c8idle");
    a.ldH(0, r7, r20);
    a.loadImm(0xe000, r16);
    a.and(r16, r20);
    expectEq(a, r20, 0x0000);
    draw(a);
    a.cmp(r10, r12);
    a.be("c8same");
    fail(a);
    a.label("c8same");

    // 9: eight full-screen affine worlds overrun the frame: TIMEERR is
    // raised, OVERTIME reads set, and both resolve when the draw completes.
    progress(a);
    a.loadImm(0x00024000, r15);
    a.movImm(0, r16);
    a.loadImm(224, r17);
    a.loadImm(512, r13);
    a.label("c9params");
    a.stH(r0, 0, r15);
    a.stH(r0, 2, r15);
    a.stH(r16, 4, r15);
    a.stH(r13, 6, r15);
    a.stH(r0, 8, r15);
    a.movea(16, r15, r15);
    a.addImm(8, r16);
    a.addImm(-1, r17);
    a.bne("c9params");
    for (let w = 31; w >= 24; w -= 1) {
      world(a, 0x0003d800 + w * 0x20, [0xe000, 0, 0, 0, 0, 0, 0, 383, 223, 0x2000, 0]);
    }
    world(a, 0x0003d800 + 23 * 0x20, [0x0040]);
    intclr(a, 0xe000);
    a.movImm(2, r20);
    a.stH(r20, 0x42, r7);
    waitPending(a, 0x8000);
    a.ldH(0x40, r7, r20);
    a.andi(0x0010, r20, r20);
    expectEq(a, r20, 0x0010);
    waitPending(a, 0x4000);
    a.ldH(0x40, r7, r20);
    a.andi(0x0010, r20, r20);
    expectEq(a, r20, 0x0000);
    intclr(a, 0xe01f);
    a.stH(r0, 0x42, r7);

    // 10: DPRST clears the display-side pendings and enables.
    progress(a);
    put(a, 0x0005f802, 0x0018);
    a.ldH(2, r7, r20);
    expectEq(a, r20, 0x0018);
    waitPending(a, 0x0010);
    put(a, 0x0005f822, 0x0303);
    a.ldH(0, r7, r20);
    a.loadImm(0x801f, r16);
    a.and(r16, r20);
    expectEq(a, r20, 0x0000);
    a.ldH(2, r7, r20);
    expectEq(a, r20, 0x0000);
    put(a, 0x0005f822, 0x0302);

    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();

    // Start a draw, learn its target buffer from XPSTTS, and wait it out.
    a.label("drawFrame");
    a.movImm(2, r20);
    a.stH(r20, 0x42, r7);
    a.label("dfBusy");
    a.ldH(0x40, r7, r20);
    a.andi(0x000c, r20, r20);
    a.be("dfBusy");
    a.cmpImm(8, r20);
    a.movImm(0, r10);
    a.bne("dfEnd0");
    a.loadImm(0x8000, r10);
    a.label("dfEnd0");
    a.label("dfEnd");
    a.ldH(0, r7, r20);
    a.andi(0x4000, r20, r20);
    a.be("dfEnd");
    a.loadImm(0x4000, r20);
    a.stH(r20, 4, r7);
    a.stH(r0, 0x42, r7);
    a.jmp(r31);
  },
});
