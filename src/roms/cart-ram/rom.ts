import { type Assembler, type Register, r6, r7, r8, r9, r10, r15, r16, r17 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r7 save RAM base, r8 expected-value
// scratch, r9 check counter, r10 the boot count, r15-r17 addresses and data,
// r1 reserved for pseudo-instructions.

const STATUS = 0x05000000;
const RAM = 0x06000000;
const PASS = 0x5a00;

// Cell k lives at RAM + 2k. A game pak wires only D0-D7 to its RAM module, so
// one address holds one byte and the upper half of every halfword is nothing.
const cell = (k: number) => 2 * k;

// The record that has to survive a power cycle: a magic saying the save is
// ours, a boot count, and the count's complement so a half-written record
// cannot pass for a whole one.
const MAGIC_HI = 0x56; // 'V'
const MAGIC_LO = 0x42; // 'B'
const COUNT_CELL = 2;
const CHECK_CELL = 3;

// Scratch cells, chosen at both ends of the array so a mask that came back
// too small cannot alias them onto each other.
const SCRATCH = [
  { index: 0x100, value: 0xa5 },
  { index: 0x101, value: 0x5a },
  { index: 0x1fff, value: 0x3c },
] as const;

const MIRROR_BYTES = 0x4000; // 8192 cells, two bytes of address each

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

const setCheck = (a: Assembler, n: number) => {
  a.movImm(n, r9);
  a.stH(r9, 0, r6);
};

const spin = (a: Assembler) => {
  const label = uniq("spin");
  a.label(label);
  a.br(label);
};

// Every check ends the same way: match and fall through, or spin forever with
// its number on the status cells.
const expectEq = (a: Assembler, reg: Register, value: number) => {
  const ok = uniq("ok");
  a.loadImm(value, r8);
  a.cmp(r8, reg);
  a.be(ok);
  spin(a);
  a.label(ok);
};

const expectSame = (a: Assembler, left: Register, right: Register) => {
  const ok = uniq("ok");
  a.cmp(left, right);
  a.be(ok);
  spin(a);
  a.label(ok);
};

// ld.b sign-extends, so every read is masked back to the byte the cell holds.
const readCell = (a: Assembler, index: number, dest: Register) => {
  a.ldB(cell(index), r7, dest);
  a.andi(0xff, dest, dest);
};

const writeCell = (a: Assembler, index: number, value: number) => {
  a.loadImm(value, r15);
  a.stH(r15, cell(index), r7);
};

export default defineRom({
  name: "cart-ram",
  header: { gameTitle: "OPENFPGA CARTRAM", makerCode: "OF", gameCode: "VCRM", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x5A01 (0101 1010 0000 0001, lit = 1) the first time this ROM is ever run. " +
    "Then Quit to the Pocket menu and launch it again: the cells must read 0x5A02, " +
    "and 0x5A03 the time after that. That low byte is a boot count kept in save " +
    "RAM, so it only advances if the save was written to the SD card on quit and " +
    "read back on launch. A number that never leaves 0x5A01 means the save is not " +
    "persisting, which is the whole feature. Powering the Pocket off instead of " +
    "quitting must advance it too. Failure before that: the square stays hollow and " +
    "the cells show the failing check's number -- 1 a fresh save that did not come " +
    "up as 0xFF, 2 a save whose record came back corrupt, 3 cells that do not hold " +
    "distinct bytes, 4 a byte store that did not land, 5 a halfword read whose upper " +
    "byte was not 0xFF, 6 the region failing to mirror, 7 the record not reading " +
    "back after it was written. In Mednafen: loads as OPENFPGA CARTRAM and freezes at " +
    "check 1 by design -- beetle-vb zeroes cartridge RAM at power-on (libretro.cpp, " +
    "memset after SetFastMap) where APF fills a fresh save with 0xFF, and its flat " +
    "16-bit array with a fixed 64KB mask would fail checks 5 and 6 as well.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.loadImm(RAM, r7);

    // Is this save ours already, or is it the 0xFF fill APF writes for a
    // cartridge that has never been saved?
    readCell(a, 0, r16);
    a.loadImm(MAGIC_HI, r8);
    a.cmp(r8, r16);
    a.bne("fresh_save");
    readCell(a, 1, r16);
    a.loadImm(MAGIC_LO, r8);
    a.cmp(r8, r16);
    a.bne("fresh_save");
    a.jr("returning");

    // 1: a fresh save reads as erased silicon everywhere. This is data.json's
    // parameter bit 5 doing its job; with the bit clear the cells would come
    // up as whatever the FPGA powered on with, which is what this catches.
    a.label("fresh_save");
    setCheck(a, 1);
    for (const index of [4, SCRATCH[0].index, SCRATCH[2].index]) {
      readCell(a, index, r16);
      expectEq(a, r16, 0xff);
    }
    a.movImm(1, r10);
    a.jr("checks");

    // 2: the record the last run left behind is intact, and the count moves
    // on by one.
    a.label("returning");
    setCheck(a, 2);
    readCell(a, COUNT_CELL, r10);
    readCell(a, CHECK_CELL, r16);
    a.not(r10, r17);
    a.andi(0xff, r17, r17);
    expectSame(a, r17, r16);
    a.addImm(1, r10);
    a.andi(0xff, r10, r10);

    // 3: distinct cells hold distinct bytes, written as halfwords and read
    // back as bytes.
    a.label("checks");
    setCheck(a, 3);
    for (const scratch of SCRATCH) writeCell(a, scratch.index, scratch.value);
    for (const scratch of SCRATCH) {
      readCell(a, scratch.index, r16);
      expectEq(a, r16, scratch.value);
    }

    // 4: a byte store lands in the cell a halfword store would have used.
    setCheck(a, 4);
    a.loadImm(0xc3, r15);
    a.stB(r15, cell(0x102), r7);
    readCell(a, 0x102, r16);
    expectEq(a, r16, 0xc3);

    // 5: the upper byte of a halfword read is the pak's unwired D8-D15. Only
    // the low eight data lines reach the RAM module, so the byte above the
    // cell reads 0xFF and no game can store anything there.
    setCheck(a, 5);
    a.ldH(cell(SCRATCH[0].index), r7, r16);
    a.andi(0xffff, r16, r16);
    expectEq(a, r16, 0xff00 | SCRATCH[0].value);

    // 6: the region mirrors, both one array past the end and at the top of
    // the 16MB the game pak RAM area owns.
    setCheck(a, 6);
    a.ldH(cell(SCRATCH[0].index) + MIRROR_BYTES, r7, r16);
    a.andi(0xffff, r16, r16);
    expectEq(a, r16, 0xff00 | SCRATCH[0].value);
    a.loadImm(RAM + 0xfffffe, r15);
    a.ldH(0, r15, r16);
    a.andi(0xffff, r16, r16);
    expectEq(a, r16, 0xff00 | SCRATCH[2].value);

    // The record for the next boot. This is what APF has to carry to the SD
    // card when the core shuts down.
    writeCell(a, 0, MAGIC_HI);
    writeCell(a, 1, MAGIC_LO);
    a.stH(r10, cell(COUNT_CELL), r7);
    a.not(r10, r17);
    a.andi(0xff, r17, r17);
    a.stH(r17, cell(CHECK_CELL), r7);

    // 7: it reads back before we claim it was written.
    setCheck(a, 7);
    readCell(a, COUNT_CELL, r16);
    expectSame(a, r10, r16);

    // The count itself is the verdict, so it goes on the cells rather than
    // the usual 0x600D.
    a.loadImm(PASS, r15);
    a.or(r10, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
