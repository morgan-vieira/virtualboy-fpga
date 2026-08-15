import { type Assembler, r6, r8, r9, r15, r16, r17, type Register } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r15-r17 addresses and data, r1 reserved for pseudo-instructions.

const STATUS = 0x05000000;
const PASS = 0x600d;

// Forced so the in-ROM mirror addresses below are correct: with a 2KB image
// the trailer's last sixteen bytes sit at 0x070007F0 and mirror at
// 0x07FFFFF0, the copy the reset vector actually reaches.
const SIZE = 2048;

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

export default defineRom({
  name: "busmap",
  header: { gameTitle: "OPENFPGA BUSMAP", makerCode: "OF", gameCode: "VBUS", revision: 0 },
  sizeBytes: SIZE,
  expectation:
    "On the Pocket: the centre square fills solid red (CPU halted) and the top row of " +
    "16 status cells reads 0x600D (0110 0000 0000 1101, lit = 1). Failure: the square " +
    "stays hollow and the status cells show the number of the failing check, counted " +
    "in program order in rom.ts; the bottom row shows the PC of the failure spin. In " +
    "Mednafen: loads as OPENFPGA BUSMAP, 2KiB, and the last halfword written to " +
    "0x05000000 is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // 1: work RAM holds a word.
    progress(a);
    a.loadImm(0x12345678, r15);
    a.stW(r15, 0x10, r6);
    a.ldW(0x10, r6, r16);
    expectEq(a, r16, 0x12345678);

    // 2: work RAM mirrors through its region: bits 23-16 of the address are
    // ignored, so 0x05AB0010 lands on the word just written.
    progress(a);
    a.loadImm(0x05ab0010, r15);
    a.ldW(0, r15, r16);
    expectEq(a, r16, 0x12345678);

    // 3: and a write through a mirror lands in the same storage.
    progress(a);
    a.loadImm(0x057f0000, r15);
    a.loadImm(0xcafe0000, r16);
    a.stW(r16, 0x20, r15);
    a.ldW(0x20, r6, r17);
    expectEq(a, r17, 0xcafe0000);

    // 4: everything above 0x07FFFFFF mirrors the whole map: the top five
    // address bits never leave the CPU. 0x85AB0010 is work RAM too.
    progress(a);
    a.loadImm(0x85ab0010, r15);
    a.ldW(0, r15, r16);
    expectEq(a, r16, 0x12345678);

    // 5: the unmapped region reads zero and swallows writes; not a fault.
    progress(a);
    a.loadImm(0x03000000, r15);
    a.loadImm(0xdeadbeef, r16);
    a.stW(r16, 0, r15);
    a.ldW(0, r15, r16);
    expectEq(a, r16, 0);

    // 6: VSU reads are undefined on hardware; this core answers zero,
    // following beetle-vb. An implementation choice, pinned so it cannot
    // drift by accident.
    progress(a);
    a.loadImm(0x01000000, r15);
    a.ldW(0x40, r15, r16);
    expectEq(a, r16, 0);

    // 7: no commercial cart populates the expansion region; it reads zero.
    progress(a);
    a.loadImm(0x04000000, r15);
    a.ldW(0, r15, r16);
    expectEq(a, r16, 0);

    // 8: cartridge ROM mirrors by its size mask. The same trailer halfword
    // through the in-ROM address and through the top-of-space copy the reset
    // vector uses. Equal and non-zero, so a stuck-at-zero ROM fails too.
    progress(a);
    a.loadImm(0x07000000 + SIZE - 0x10, r15);
    a.ldH(0, r15, r16);
    a.loadImm(0x07fffff0, r15);
    a.ldH(0, r15, r17);
    const spinZero = uniq("spin");
    const okNonZero = uniq("ok");
    a.cmp(r16, r17);
    const spinDiffer = uniq("spin");
    const okEqual = uniq("ok");
    a.be(okEqual);
    a.label(spinDiffer);
    a.br(spinDiffer);
    a.label(okEqual);
    a.cmpImm(0, r16);
    a.bne(okNonZero);
    a.label(spinZero);
    a.br(spinZero);
    a.label(okNonZero);

    // 9: byte lanes: four byte stores assemble a word, each untouched by
    // its neighbors.
    progress(a);
    a.movImm(0x01, r15);
    a.stB(r15, 0x30, r6);
    a.movImm(0x02, r15);
    a.stB(r15, 0x31, r6);
    a.movImm(0x03, r15);
    a.stB(r15, 0x32, r6);
    a.movImm(0x04, r15);
    a.stB(r15, 0x33, r6);
    a.ldW(0x30, r6, r16);
    expectEq(a, r16, 0x04030201);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
