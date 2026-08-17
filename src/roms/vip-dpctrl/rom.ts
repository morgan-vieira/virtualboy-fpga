import {
  type Assembler,
  r0,
  r6,
  r7,
  r8,
  r9,
  r15,
  r16,
  r17,
  r18,
  r20,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Display control conformance: DPCTRL programming and readback, SCANRDY,
// FCLK, the DPBSY windows, the CTA pointers, and LOCK, ending in a visible
// LOCK demonstration. Checks report through the status cells; a failing
// check spins with its number showing.
//
// Register budget: r6 status base, r7 VIP register base, r8 expected value,
// r9 check counter, r15-r18/r20 scratch, r1 reserved.

const STATUS = 0x05000000;
const REGS = 0x0005f800;
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

// Poll DPSTTS until (value & mask) equals want; the masked value is in r20.
const waitStatus = (a: Assembler, mask: number, want: number) => {
  const loop = uniq("dp");
  a.label(loop);
  a.ldH(0x20, r7, r20);
  a.andi(mask, r20, r20);
  a.cmpImm(0, r20);
  if (want === 0) a.bne(loop);
  else a.be(loop);
};

// A software delay long enough for several column-table groups.
const delay = (a: Assembler) => {
  const loop = uniq("dly");
  a.loadImm(1500, r17);
  a.label(loop);
  a.addImm(-1, r17);
  a.bne(loop);
};

export default defineRom({
  name: "vip-dpctrl",
  header: { gameTitle: "OPENFPGA VIPDPCT", makerCode: "OF", gameCode: "VVDP", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the top " +
    "status cells read 0x600D with the centre square hollow, over a full red field " +
    "that is brightest at the left edge and fades toward the right. Every two " +
    "seconds or so the field alternates between that gradient and a uniformly " +
    "bright field: that is LOCK freezing the column-table pointer on its 0xFA " +
    "field-start entry. A failing check leaves its number on the cells instead. " +
    "Checks 1-3 cover DPCTRL readback, SCANRDY, and the DPBSY windows; 4-7 cover " +
    "FCLK, CTA movement, LOCK, and RE. In Mednafen the image loads and freezes at " +
    "check 4 by design: beetle-vb never reports FCLK in DPSTTS and answers CTA " +
    "reads with a constant, which also covers checks 5 and 6.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(REGS, r7);
    a.movImm(0, r9);

    // DRAM powers up as pseudorandom contents; clear the worlds and tables.
    a.loadImm(0x00020000, r15);
    a.loadImm(0x10000, r16);
    a.label("clrDram");
    a.stH(r0, 0, r15);
    a.addImm(2, r15);
    a.addImm(-1, r16);
    a.bne("clrDram");

    // Column tables: repeat 0 everywhere, lengths that ramp with the entry
    // index so the used range 0x9B-0xFA reads dim to bright.
    a.loadImm(0x0003dc00, r15);
    a.movImm(0, r16);
    a.label("ctLoop");
    a.movea(-0x80, r16, r17);
    a.andi(0x00ff, r17, r17);
    a.stH(r17, 0, r15);
    a.stH(r17, 0x200, r15);
    a.addImm(2, r15);
    a.addImm(1, r16);
    a.cmpImm(0, r16);
    a.loadImm(256, r20);
    a.cmp(r20, r16);
    a.bne("ctLoop");

    // A BKCOL-3 field: world 31 terminates immediately, so every frame is
    // the erased background colour at full brightness.
    put(a, 0x0003dbe0, 0x0040);
    put(a, 0x0005f870, 0x0003);
    put(a, 0x0005f824, 0x0055);
    put(a, 0x0005f826, 0x0055);
    put(a, 0x0005f828, 0x0055);
    put(a, 0x0005f82a, 0x0000);
    put(a, 0x0005f842, 0x0002);

    // 1: RE stores immediately; SYNCE and DISP take effect at FCLK.
    progress(a);
    put(a, 0x0005f822, 0x0302);
    a.ldH(0x20, r7, r20);
    a.andi(0x0100, r20, r20);
    expectEq(a, r20, 0x0100);
    waitStatus(a, 0x0202, 1);
    a.andi(0x0202, r20, r20);
    expectEq(a, r20, 0x0202);

    // 2: the scanner always reports ready.
    progress(a);
    a.ldH(0x20, r7, r20);
    a.andi(0x0040, r20, r20);
    expectEq(a, r20, 0x0040);

    // 3: DPBSY names a buffer inside the eye windows and clears between.
    progress(a);
    waitStatus(a, 0x003c, 1);
    waitStatus(a, 0x003c, 0);

    // 4: FCLK is visible and toggles.
    progress(a);
    waitStatus(a, 0x0080, 1);
    waitStatus(a, 0x0080, 0);

    // 5: CTA walks downward while an eye displays.
    progress(a);
    waitStatus(a, 0x0014, 0);
    waitStatus(a, 0x0014, 1);
    a.ldH(0x30, r7, r16);
    a.andi(0x00ff, r16, r16);
    delay(a);
    a.ldH(0x30, r7, r20);
    a.andi(0x00ff, r20, r20);
    a.cmp(r16, r20);
    a.bl("c5moved");
    fail(a);
    a.label("c5moved");

    // 6: LOCK holds the pointer on the 0xFA field-start entry.
    progress(a);
    put(a, 0x0005f822, 0x0702);
    waitStatus(a, 0x0014, 0);
    waitStatus(a, 0x0014, 1);
    a.ldH(0x30, r7, r20);
    a.andi(0x00ff, r20, r20);
    expectEq(a, r20, 0x00fa);
    delay(a);
    a.ldH(0x30, r7, r20);
    a.andi(0x00ff, r20, r20);
    expectEq(a, r20, 0x00fa);
    put(a, 0x0005f822, 0x0302);

    // 7: clearing RE reads back clear.
    progress(a);
    put(a, 0x0005f822, 0x0202);
    a.ldH(0x20, r7, r20);
    a.andi(0x0100, r20, r20);
    expectEq(a, r20, 0x0000);
    put(a, 0x0005f822, 0x0302);

    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);

    // Visible LOCK demonstration: toggle every hundred display frames.
    a.movImm(0, r18);
    a.label("visLoop");
    a.loadImm(100, r17);
    a.label("visCount");
    a.label("visFs");
    a.ldH(0, r7, r20);
    a.andi(0x0010, r20, r20);
    a.be("visFs");
    a.loadImm(0x0010, r20);
    a.stH(r20, 4, r7);
    a.addImm(-1, r17);
    a.bne("visCount");
    a.xori(1, r18, r18);
    a.cmpImm(0, r18);
    a.be("visUnlock");
    put(a, 0x0005f822, 0x0702);
    a.br("visLoop");
    a.label("visUnlock");
    put(a, 0x0005f822, 0x0302);
    a.br("visLoop");
  },
});
