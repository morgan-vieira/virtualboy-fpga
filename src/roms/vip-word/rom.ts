import { type Assembler, r6, r8, r9, r15, r16, r17, type Register } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// A word load whose two halfword answers arrive late. Work RAM and the
// cartridge answer the cycle after the access, so a word through them says
// nothing about this; the VIP's memory holds the bus off for several clocks
// per access, and that is the case the CPU got wrong. It launched the second
// halfword's request while the first answer was still on the bus and then
// took that answer when ready arrived -- by which time the bus was carrying
// the second. The high halfword came back twice.
//
// VUEngine is what found it: a pointer stored as 0x050054B0 read back as
// 0x05000500, so Game::start believed the game had already started, returned,
// and crt0 reset the machine into a boot loop -- a black screen.
//
// Both storages behind the VIP's port are checked, because they are different
// memories on the Pocket: BGMap lives in the SRAM chip, character memory in
// block RAM inside the FPGA.
//
// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r15-r17 addresses and data, r1 reserved for pseudo-instructions.

const STATUS = 0x05000000;
const PASS = 0x600d;

// Distinct halves, and the value the failure was found on: a low halfword
// that cannot be mistaken for the high one.
const PROBE = 0x050054b0;
const PROBE2 = 0x1234abcd;

const BGMAP = 0x00020000;
const CHR = 0x00006000;

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
  name: "vip-word",
  header: { gameTitle: "OPENFPGA VIPWORD", makerCode: "OF", gameCode: "VVWD", revision: 0 },
  sizeBytes: 1024,
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and the " +
    "status cells show the number of the failing check, counted in program order in " +
    "rom.ts; the bottom row shows the PC of the failure spin. Check 1 or 3 failing " +
    "means a word read back from the VIP's memory lost a halfword -- the symptom is " +
    "the high half appearing in both, 0x05000500 for check 1. In Mednafen: loads as " +
    "OPENFPGA VIPWORD, 1KiB, and the last halfword written to 0x05000000 is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // 1: a word through BGMap memory, which sits in the Pocket's SRAM.
    progress(a);
    a.loadImm(BGMAP, r15);
    a.loadImm(PROBE, r16);
    a.stW(r16, 0, r15);
    a.ldW(0, r15, r17);
    expectEq(a, r17, PROBE);

    // 2: the halves are independently addressable, so a wrong-half read
    // cannot pass by accident above.
    progress(a);
    a.ldH(0, r15, r17);
    expectEq(a, r17, PROBE & 0xffff);

    // 3: and a word through character memory, which is block RAM in the
    // FPGA rather than the SRAM chip.
    progress(a);
    a.loadImm(CHR, r15);
    a.loadImm(PROBE2, r16);
    a.stW(r16, 0, r15);
    a.ldW(0, r15, r17);
    expectEq(a, r17, PROBE2);

    // 4: a second word at an offset, so a stuck address cannot pass either.
    progress(a);
    a.loadImm(PROBE, r16);
    a.stW(r16, 0x10, r15);
    a.ldW(0x10, r15, r17);
    expectEq(a, r17, PROBE);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
