import { type Assembler, r6, r8, r9, r15, r16, r17, type Register } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r15-r17 addresses and data, r1 reserved for pseudo-instructions.

const STATUS = 0x05000000;
const ROM = 0x07000000;
const PASS = 0x600d;

// A retail cartridge, and thirty-two times the 64KB of block RAM the core used
// to serve one out of. The size is the point: the image cannot fit on-chip, so
// every read below has to come back from the SDRAM.
const SIZE = 2 * 1024 * 1024;

// The trailer sits in the last 0x220 bytes, and the header's game title is the
// first twenty of them, space-padded. "OPEN" read as a little-endian word.
const TRAILER_OFFSET = SIZE - 0x220;
const TITLE_WORD = 0x4e45504f;

// Offsets chosen for where they land in the memory, not for where they land in
// the file. The controller maps halfword address bits 9:0 to the column, 11:10
// to the bank and 24:12 to the row (pocket_sdram.v), so in bytes 0x800 steps
// the bank and 0x2000 steps the row. These walk all four banks, the first row
// boundary, and rows far enough apart that only a correct row address reaches
// them.
const MARKERS = [
  { offset: 0x000800, value: 0xba0110ad },
  { offset: 0x001000, value: 0xba021eaf },
  { offset: 0x001800, value: 0xba03c0de },
  { offset: 0x002000, value: 0x0001a0ff },
  { offset: 0x040000, value: 0x0020b0ff },
  { offset: 0x100000, value: 0x0080c0ff },
  { offset: 0x1ff000, value: 0x00ffd0ff },
] as const;

const NEAR = ROM + 0x000800;
const FAR = ROM + 0x100000;

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

const expectWordAt = (a: Assembler, address: number, value: number) => {
  a.loadImm(address, r15);
  a.ldW(0, r15, r16);
  expectEq(a, r16, value);
};

// 0xFF fill up to an absolute offset, in chunks so a megabyte of it does not
// become a megabyte of calls.
const padTo = (a: Assembler, offset: number) => {
  const gap = offset - a.offset;
  if (gap < 0) throw new Error(`cart-size: code already passed offset 0x${offset.toString(16)}`);
  for (let done = 0; done < gap; done += 4096) {
    a.byte(...new Array<number>(Math.min(4096, gap - done)).fill(0xff));
  }
};

export default defineRom({
  name: "cart-size",
  header: { gameTitle: "OPENFPGA CARTSZ", makerCode: "OF", gameCode: "VCSZ", revision: 0 },
  sizeBytes: SIZE,
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). This is the first image larger than " +
    "64KB the core has been given, so a core still serving the cartridge out of " +
    "block RAM could not reach the first check. Failure: the square stays hollow " +
    "and the status cells show the number of the failing check, counted in " +
    "program order in rom.ts; the bottom row shows the PC of the failure spin. A " +
    "blank screen instead means the reset vector never landed, which for an image " +
    "this size points at the size mask rather than at the program. In Mednafen: " +
    "loads as OPENFPGA CARTSZ, 2048KiB, and the last halfword written to " +
    "0x05000000 is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // 1-7: every marker in ascending order. Each is a different bank or row
    // from the last, so all seven cost a precharge and an activate rather
    // than a page hit.
    for (const marker of MARKERS) {
      progress(a);
      expectWordAt(a, ROM + marker.offset, marker.value);
    }

    // 8: the same markers descending. A controller that opened rows but never
    // compared them would have passed everything above and fails here.
    progress(a);
    for (let i = MARKERS.length - 1; i >= 0; i -= 1) {
      const marker = MARKERS[i];
      if (marker === undefined) continue;
      expectWordAt(a, ROM + marker.offset, marker.value);
    }

    // 9: two rows alternating, so a row miss follows a row miss with nothing
    // idle in between.
    progress(a);
    expectWordAt(a, NEAR, 0xba0110ad);
    expectWordAt(a, FAR, 0x0080c0ff);
    expectWordAt(a, NEAR, 0xba0110ad);
    expectWordAt(a, FAR, 0x0080c0ff);

    // 10: the same word after long enough that refreshes have run underneath
    // it. The controller refreshes every 7.5 us; this spin is hundreds of
    // microseconds, so the row has been closed and reopened many times.
    progress(a);
    a.loadImm(2000, r17);
    a.label("refresh_wait");
    a.addImm(-1, r17);
    a.bne("refresh_wait");
    expectWordAt(a, FAR, 0x0080c0ff);

    // 11: the top of the address space still reaches the top of the image.
    // 0xFFFFFDE0 masked to 27 bits and then to a 2MB image is the trailer, so
    // this reads back the game title the packer wrote there -- the same path
    // the reset vector took to start this program, now with a mask thirty-two
    // times wider than any image the core has served before.
    progress(a);
    expectWordAt(a, 0xfffffde0, TITLE_WORD);

    progress(a);
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();

    // The markers themselves, each alone at its offset in the 0xFF fill.
    for (const marker of MARKERS) {
      padTo(a, marker.offset);
      a.word(marker.value);
    }
    padTo(a, TRAILER_OFFSET - 4);
  },
});
