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

// Object conformance: group boundaries and cycling, per-eye enables, flips,
// vertical wrap, clipping, parallax, and ordering. Every check draws one
// frame and reads the finished frame buffer back; the drawn buffer is
// discovered from XPSTTS while the draw runs.
//
// Register budget: r6 status base, r7 VIP register base, r8 expected value,
// r9 check counter, r10 left base of the drawn buffer, r15/r16/r20 scratch,
// r31 drawFrame link, r1 reserved.

const STATUS = 0x05000000;
const REGS = 0x0005f800;
const OAM = 0x0003e000;
const W31 = 0x0003dbe0;
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

const put = (a: Assembler, address: number, value: number) => {
  a.loadImm(address, r15);
  a.loadImm(value, r16);
  a.stH(r16, 0, r15);
};

// Write one object's four halfwords.
const obj = (a: Assembler, index: number, words: ReadonlyArray<number>) => {
  a.loadImm(OAM + index * 8, r15);
  for (let i = 0; i < 4; i += 1) {
    a.loadImm(words[i] ?? 0, r16);
    a.stH(r16, i * 2, r15);
  }
};

const spt = (a: Assembler, values: ReadonlyArray<number>) => {
  a.loadImm(REGS + 0x48, r15);
  for (let i = 0; i < 4; i += 1) {
    a.loadImm(values[i] ?? 0, r16);
    a.stH(r16, i * 2, r15);
  }
};

const draw = (a: Assembler) => a.jal("drawFrame");

const readLeft = (a: Assembler, offset: number, dest: Register) => {
  a.ldH(offset, r10, dest);
  a.andi(0xffff, dest, dest);
};

const readRight = (a: Assembler, offset: number, dest: Register) => {
  a.movhi(1, r10, r15);
  a.ldH(offset, r15, dest);
  a.andi(0xffff, dest, dest);
};

export default defineRom({
  name: "vip-objx",
  header: { gameTitle: "OPENFPGA VIPOBJX", makerCode: "OF", gameCode: "VVOX", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red and the top status cells read 0x600D. Failure: the " +
    "square stays hollow and the cells show the failing check's number, counted in " +
    "program order in rom.ts. Checks 1-9 cover placement, palettes, in-group " +
    "ordering, JLON/JRON, parallax, both flips, negative JY, edge clipping, and a " +
    "group whose end index sits below its start. Check 9 walks 1,022 objects and " +
    "legitimately overruns the frame; the pass is unaffected. In Mednafen the image " +
    "loads and freezes at check 10 by design: beetle-vb saturates the object group " +
    "counter at zero where the scroll wraps it back to three, and it also gates " +
    "object eyes with the world's LON/RON (check 11), which the scroll rules out.",
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

    // Characters: 1 and 2 solid, 5 a lone bright top-left pixel, 6 a bar
    // on its bottom row only.
    for (let row = 0; row < 8; row += 1) {
      put(a, 0x00006000 + row * 2, 0x0000);
      put(a, 0x00006010 + row * 2, 0x5555);
      put(a, 0x00006020 + row * 2, 0xaaaa);
      put(a, 0x00006050 + row * 2, row === 0 ? 0x0003 : 0x0000);
      put(a, 0x00006060 + row * 2, row === 7 ? 0x5555 : 0x0000);
    }
    put(a, 0x0005f868, 0x00e4);
    // World 31 serves objects; world 30 terminates the list.
    put(a, W31, 0xf000);
    put(a, W31 - 0x20, 0x0040);

    // 1: one object, both eyes, palette 0.
    progress(a);
    spt(a, [1023, 1023, 1023, 0]);
    obj(a, 0, [16, 0xc000, 8, 0x0001]);
    draw(a);
    readLeft(a, 0x402, r20);
    expectEq(a, r20, 0x5555);
    readRight(a, 0x402, r20);
    expectEq(a, r20, 0x5555);

    // 2: objects draw from the end index down, so object 0 lands in front.
    progress(a);
    spt(a, [1023, 1023, 1023, 1]);
    obj(a, 1, [16, 0xc000, 8, 0x0002]);
    draw(a);
    readLeft(a, 0x402, r20);
    expectEq(a, r20, 0x5555);

    // 3: JLON alone draws only the left image.
    progress(a);
    spt(a, [1023, 1023, 1023, 0]);
    obj(a, 0, [16, 0x8000, 8, 0x0001]);
    draw(a);
    readLeft(a, 0x402, r20);
    expectEq(a, r20, 0x5555);
    readRight(a, 0x402, r20);
    expectEq(a, r20, 0x0000);

    // 4: parallax subtracts left and adds right.
    progress(a);
    obj(a, 0, [100, 0xc003, 0, 0x0001]);
    draw(a);
    readLeft(a, 97 * 64, r20);
    expectEq(a, r20, 0x5555);
    readRight(a, 103 * 64, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 96 * 64, r20);
    expectEq(a, r20, 0x0000);

    // 5: JHFLP moves the lone pixel to the character's other edge.
    progress(a);
    obj(a, 0, [32, 0xc000, 0, 0x2005]);
    draw(a);
    readLeft(a, 39 * 64, r20);
    expectEq(a, r20, 0x0003);
    readLeft(a, 32 * 64, r20);
    expectEq(a, r20, 0x0000);

    // 6: JVFLP moves it to the bottom row instead.
    progress(a);
    obj(a, 0, [32, 0xc000, 0, 0x1005]);
    draw(a);
    readLeft(a, 32 * 64, r20);
    expectEq(a, r20, 0xc000);

    // 7: JY of 0xF9 is -7, leaving only the character's last row on screen.
    progress(a);
    obj(a, 0, [48, 0xc000, 0xf9, 0x0006]);
    draw(a);
    readLeft(a, 48 * 64, r20);
    expectEq(a, r20, 0x0001);

    // 8: objects clip at both screen edges.
    progress(a);
    spt(a, [1023, 1023, 1023, 1]);
    obj(a, 0, [0x3fc, 0xc000, 0, 0x0001]);
    obj(a, 1, [380, 0xc000, 0, 0x0001]);
    draw(a);
    readLeft(a, 3 * 64, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 4 * 64, r20);
    expectEq(a, r20, 0x0000);
    readLeft(a, 383 * 64, r20);
    expectEq(a, r20, 0x5555);

    // 9: an end index below the start walks down through object 1,023 and
    // excludes only the gap.
    progress(a);
    spt(a, [1023, 1023, 5, 3]);
    obj(a, 0, [0, 0, 0, 0]);
    obj(a, 1, [0, 0, 0, 0]);
    obj(a, 2, [0, 0, 0, 0]);
    obj(a, 3, [0, 0, 0, 0]);
    obj(a, 4, [70, 0xc000, 0, 0x0001]);
    obj(a, 1023, [60, 0xc000, 0, 0x0001]);
    draw(a);
    readLeft(a, 60 * 64, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 70 * 64, r20);
    expectEq(a, r20, 0x0000);

    // 10: the group counter wraps from zero back to three, so a fifth
    // object world redraws group 3 in front of group 0.
    progress(a);
    put(a, W31 - 0x20, 0xf000);
    put(a, W31 - 0x40, 0xf000);
    put(a, W31 - 0x60, 0xf000);
    put(a, W31 - 0x80, 0xf000);
    put(a, W31 - 0xa0, 0x0040);
    spt(a, [0, 1, 2, 3]);
    obj(a, 0, [20, 0xc000, 0, 0x0002]);
    obj(a, 3, [20, 0xc000, 0, 0x0001]);
    draw(a);
    readLeft(a, 20 * 64, r20);
    expectEq(a, r20, 0x5555);

    // 11: object eyes come from JLON/JRON alone; a world with only RON
    // still draws a JLON-only object to the left image.
    progress(a);
    put(a, W31, 0x7000);
    put(a, W31 - 0x20, 0x0040);
    spt(a, [1023, 1023, 1023, 0]);
    obj(a, 0, [90, 0x8000, 0, 0x0001]);
    draw(a);
    readLeft(a, 90 * 64, r20);
    expectEq(a, r20, 0x5555);
    readRight(a, 90 * 64, r20);
    expectEq(a, r20, 0x0000);

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
