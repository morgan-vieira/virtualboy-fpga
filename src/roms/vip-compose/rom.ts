import {
  type Assembler,
  r0,
  r6,
  r7,
  r8,
  r9,
  r10,
  r15,
  r16,
  r20,
  r31,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// World and background composition conformance: every check draws one frame,
// reads the finished frame buffer back through the CPU, and spins with the
// check number on the status cells if a pixel is wrong. The drawn buffer is
// discovered from XPSTTS while the draw runs, so the checks never depend on
// buffer parity.
//
// Register budget: r6 status base, r7 VIP register base, r8 expected value,
// r9 check counter, r10 left base of the drawn buffer,
// r15/r16/r20 scratch, r31 drawFrame link, r1 reserved.

const STATUS = 0x05000000;
const REGS = 0x0005f800;
const W31 = 0x0003dbe0;
const W30 = 0x0003dbc0;
const W29 = 0x0003dba0;
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
  a.loadImm(value, r8);
  a.cmp(r8, reg);
  a.be(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

// Store one halfword to an absolute address, clobbering r15/r16.
const put = (a: Assembler, address: number, value: number) => {
  a.loadImm(address, r15);
  a.loadImm(value, r16);
  a.stH(r16, 0, r15);
};

// Rewrite every world attribute halfword so no field goes stale.
const world = (a: Assembler, base: number, words: ReadonlyArray<number>) => {
  a.loadImm(base, r15);
  for (let i = 0; i < 11; i += 1) {
    a.loadImm(words[i] ?? 0, r16);
    a.stH(r16, i * 2, r15);
  }
};

const w31 = (a: Assembler, words: ReadonlyArray<number>) => world(a, W31, words);

// [w0, gx, gp, gy, mx, mp, my, w, h, pb, over]
const NORM = (w0: number, mx: number, w: number, h: number, over = 0) => [
  w0,
  0,
  0,
  0,
  mx,
  0,
  0,
  w,
  h,
  0,
  over,
];

const draw = (a: Assembler) => a.jal("drawFrame");

// Read the drawn left frame buffer at a byte offset into `dest`.
const readLeft = (a: Assembler, offset: number, dest: Register) => {
  a.ldH(offset, r10, dest);
  a.andi(0xffff, dest, dest);
};

export default defineRom({
  name: "vip-compose",
  header: { gameTitle: "OPENFPGA VIPCOMP", makerCode: "OF", gameCode: "VVCP", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red and the top status cells read 0x600D. Failure: the " +
    "square stays hollow and the cells show the failing check's number, counted in " +
    "program order in rom.ts. Checks 1-11 cover the basic world, SCX/SCY sizes, " +
    "overplane fetch and wrap, minimum height, negative width, END termination, " +
    "overlap with transparency, palettes, and dummy worlds. In Mednafen the image " +
    "loads and freezes at check 12 by design: beetle-vb treats VIP register byte " +
    "writes as plain byte writes where the scroll documents a mangled halfword " +
    "write, and it also composes the base map with OR instead of the documented " +
    "rounding (checks 14-15).",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(REGS, r7);
    a.movImm(0, r9);

    // Background maps, parameters, worlds, and OAM power up as pseudorandom
    // DRAM; clear everything the checks could sample.
    a.loadImm(0x00020000, r15);
    a.loadImm(0x10000, r16);
    a.label("clrDram");
    a.stH(r0, 0, r15);
    a.addImm(2, r15);
    a.addImm(-1, r16);
    a.bne("clrDram");

    // Characters 1-4: solid shades and a half-opaque edge probe.
    for (let row = 0; row < 8; row += 1) {
      put(a, 0x00006000 + row * 2, 0x0000);
      put(a, 0x00006010 + row * 2, 0x5555);
      put(a, 0x00006020 + row * 2, 0xaaaa);
      put(a, 0x00006030 + row * 2, 0xffff);
      put(a, 0x00006040 + row * 2, 0x0055);
    }
    // Identity background palette; nothing else configured yet.
    put(a, 0x0005f860, 0x00e4);
    // World 30 terminates the list.
    world(a, W30, [0x0040]);

    // 1: a one-cell normal world lands character 1 at the origin.
    progress(a);
    put(a, 0x00020000, 0x0001);
    w31(a, NORM(0xc000, 0, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);

    // 2: SCX lives in bits 11:10; two maps wide puts MX=512 in map 1.
    progress(a);
    put(a, 0x00022000, 0x0002);
    w31(a, NORM(0xc400, 512, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xaaaa);

    // 3: SCY lives in bits 9:8; two maps tall puts MY=512 in map 1.
    progress(a);
    w31(a, [0xc100, 0, 0, 0, 0, 0, 512, 383, 223, 0, 0]);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xaaaa);

    // 4: the overplane character names a DRAM cell; out-of-bounds pixels
    // draw that cell, not the register value.
    progress(a);
    put(a, 0x00020200, 0x0002);
    w31(a, NORM(0xc080, 0x1ff8, 7, 223, 0x0100));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xaaaa);

    // 5: with OVER clear the same coordinates wrap to the far edge.
    progress(a);
    put(a, 0x0002007e, 0x0003);
    w31(a, NORM(0xc000, 0x1ff8, 7, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

    // 6: H of 2 still draws eight rows and not a ninth.
    progress(a);
    w31(a, NORM(0xc000, 0, 383, 2));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 2, r20);
    expectEq(a, r20, 0x0000);

    // 7: a negative W draws nothing at all.
    progress(a);
    w31(a, NORM(0xc000, 0, 0x1fff, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x0000);

    // 8: an END world hides every lower-indexed world.
    progress(a);
    world(a, W29, NORM(0xc000, 504, 383, 223));
    w31(a, NORM(0xc000, 0, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);

    // 9: lower indexes draw in front, and transparent pixels leave the
    // world behind visible.
    progress(a);
    put(a, 0x00020002, 0x0004);
    world(a, W29, [0x0040]);
    world(a, W30, NORM(0xc000, 8, 383, 223));
    w31(a, NORM(0xc000, 504, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 256, r20);
    expectEq(a, r20, 0xffff);

    // 10: the cell's palette selector picks GPLT1, remapping raw 1 to 3.
    progress(a);
    put(a, 0x0005f862, 0x001c);
    put(a, 0x00020000, 0x4001);
    world(a, W30, [0x0040]);
    w31(a, NORM(0xc000, 0, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

    // 11: a dummy world is skipped without ending the walk.
    progress(a);
    world(a, W30, NORM(0xc000, 0, 383, 223));
    w31(a, [0x0000]);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

    // 12: a byte write to an even register address carries the register's
    // full low sixteen bits.
    progress(a);
    a.loadImm(0x0123, r15);
    a.stB(r15, 0x48, r7);
    a.ldH(0x48, r7, r20);
    expectEq(a, r20, 0x0123);

    // 13: a byte write to an odd address shifts the low byte into the
    // high lane over zeroes.
    progress(a);
    a.loadImm(0x0056, r15);
    a.stB(r15, 0x49, r7);
    a.ldH(0x48, r7, r20);
    expectEq(a, r20, 0x0200);

    // 14: base map 11 of a four-map background rounds down to 8.
    progress(a);
    put(a, 0x00030000, 0x0003);
    world(a, W30, [0x0040]);
    w31(a, NORM(0xc50b, 0, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

    // 15: sixteen maps repeat two wide, so map column two reads map 0.
    progress(a);
    w31(a, NORM(0xca00, 1024, 383, 223));
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

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
    a.bne("dfFb0");
    a.loadImm(0x8000, r10);
    a.label("dfFb0");
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
