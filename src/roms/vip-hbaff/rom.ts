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

// H-bias and affine conformance: per-row and per-eye offsets, the OR-one
// right-eye rule, 16-bit parameter wrap, affine parallax eye selection,
// signed sources, affine overplane, and unaligned-base rejection. Every
// check draws one frame and reads the finished frame buffer back; the drawn
// buffer is discovered from XPSTTS while the draw runs.
//
// Register budget: r6 status base, r7 VIP register base, r8 expected value,
// r9 check counter, r10 left base of the drawn buffer, r15/r16/r20 scratch,
// r31 drawFrame link, r1 reserved.

const STATUS = 0x05000000;
const REGS = 0x0005f800;
const W31 = 0x0003dbe0;
const W30 = 0x0003dbc0;
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

const world = (a: Assembler, base: number, words: ReadonlyArray<number>) => {
  a.loadImm(base, r15);
  for (let i = 0; i < 11; i += 1) {
    a.loadImm(words[i] ?? 0, r16);
    a.stH(r16, i * 2, r15);
  }
};

// Eight affine parameter elements at byte 0x24000, one per output row.
const affineParams = (a: Assembler, mx: number, mp: number) => {
  for (let row = 0; row < 8; row += 1) {
    const base = 0x00024000 + row * 16;
    put(a, base + 0, mx);
    put(a, base + 2, mp);
    put(a, base + 4, row * 8);
    put(a, base + 6, 512);
    put(a, base + 8, 0);
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
  name: "vip-hbaff",
  header: { gameTitle: "OPENFPGA VIPHBAF", makerCode: "OF", gameCode: "VVHA", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red and the top status cells read 0x600D. Failure: the " +
    "square stays hollow and the cells show the failing check's number, counted in " +
    "program order in rom.ts. Checks 1-7 cover independent per-eye h-bias offsets, " +
    "the odd-parameter-base alias, affine identity, both parallax signs, signed " +
    "source wrap, and affine overplane. In Mednafen the image loads and freezes at " +
    "check 8 by design: beetle-vb masks the h-bias parameter base to 16-byte " +
    "alignment, so the documented 16-bit index wrap never happens there, and it " +
    "also draws unaligned affine tables that this core rejects (check 9).",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(REGS, r7);
    a.movImm(0, r9);

    // Background maps, parameters, and the column tables power up as
    // pseudorandom DRAM; clear everything the checks could sample.
    a.loadImm(0x00020000, r15);
    a.loadImm(0x10000, r16);
    a.label("clrDram");
    a.stH(r0, 0, r15);
    a.addImm(2, r15);
    a.addImm(-1, r16);
    a.bne("clrDram");

    // Characters: 0 transparent, 1-3 solid, 4 a half-opaque edge probe.
    for (let row = 0; row < 8; row += 1) {
      put(a, 0x00006000 + row * 2, 0x0000);
      put(a, 0x00006010 + row * 2, 0x5555);
      put(a, 0x00006020 + row * 2, 0xaaaa);
      put(a, 0x00006030 + row * 2, 0xffff);
      put(a, 0x00006040 + row * 2, 0x0055);
    }
    put(a, 0x0005f860, 0x00e4);
    world(a, W30, [0x0040]);
    put(a, 0x00020000, 0x0004);

    // 1: each eye reads its own signed row offset.
    progress(a);
    put(a, 0x00020800, 1);
    put(a, 0x00020802, 0);
    world(a, W31, [0xd000, 0, 0, 0, 0, 0, 0, 15, 7, 0x0400, 0]);
    draw(a);
    readLeft(a, 3 * 64, r20);
    expectEq(a, r20, 0x5554);
    readRight(a, 3 * 64, r20);
    expectEq(a, r20, 0x5555);

    // 2: an odd Param Base serves HOFSTL to both eyes through the OR-one
    // address rule.
    progress(a);
    put(a, 0x00020802, 2);
    put(a, 0x00020804, 0);
    world(a, W31, [0xd000, 0, 0, 0, 0, 0, 0, 15, 7, 0x0401, 0]);
    draw(a);
    readRight(a, 2 * 64, r20);
    expectEq(a, r20, 0x5554);

    // 3: affine identity over a sixteen-pixel window.
    progress(a);
    put(a, 0x00020000, 0x0001);
    affineParams(a, 0, 0);
    world(a, W31, [0xe000, 0, 0, 0, 0, 0, 0, 15, 7, 0x2000, 0]);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);
    readLeft(a, 16 * 64, r20);
    expectEq(a, r20, 0x0000);

    // 4: a negative MP shifts only the left eye's sampling.
    progress(a);
    put(a, 0x00020002, 0x0002);
    affineParams(a, 0, 0xfff8);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xaaaa);
    readRight(a, 0, r20);
    expectEq(a, r20, 0x5555);

    // 5: a non-negative MP shifts only the right eye.
    progress(a);
    affineParams(a, 0, 8);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x5555);
    readRight(a, 0, r20);
    expectEq(a, r20, 0xaaaa);

    // 6: a negative source coordinate wraps to the far edge of the map.
    progress(a);
    put(a, 0x00020070, 0x0003);
    affineParams(a, 0xfe00, 0);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xffff);

    // 7: with OVER set the same coordinates use the overplane cell instead.
    progress(a);
    put(a, 0x00020300, 0x0002);
    world(a, W31, [0xe080, 0, 0, 0, 0, 0, 0, 15, 7, 0x2000, 0x0180]);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0xaaaa);

    // 8: the h-bias parameter index wraps at sixteen bits, landing on DRAM
    // halfword zero, which doubles as map cell (0,0). Character 4 becomes a
    // right-half bar so the wrapped shift of four lights screen x0.
    progress(a);
    for (let row = 0; row < 8; row += 1) put(a, 0x00006040 + row * 2, 0xff00);
    put(a, 0x00020000, 4);
    put(a, 0x00020002, 0);
    world(a, W31, [0xd000, 0, 0, 0xffff, 0, 0, 0x1fff, 15, 7, 0xfffe, 0]);
    draw(a);
    readLeft(a, 0, r20);
    expectEq(a, r20, 0x0003);

    // 9: an unaligned affine Param Base draws nothing rather than guessing
    // at the documented corruption.
    progress(a);
    world(a, W31, [0xe000, 0, 0, 0, 0, 0, 0, 15, 7, 0x2001, 0]);
    draw(a);
    readLeft(a, 0, r20);
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
