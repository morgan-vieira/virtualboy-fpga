import {
  type Assembler,
  CHCW,
  PSW,
  r6,
  r8,
  r9,
  r10,
  r11,
  r12,
  r15,
  r31,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r10-r12 working values, r31 the call linkage into T.
//
// The strongest proof here is check 3: a restored cache entry whose data
// deliberately differs from ROM executes from the cache, so a pass is
// impossible unless fetches really come out of the arrays. The dump layout
// (128 8-byte blocks then 128 4-byte tags, valid0 at bit 22) follows the
// scroll and beetle-vb's dump format.

const STATUS = 0x05000000;
const PASS = 0x600d;
const DUMP = 0x05003000;
const IMAGE = 0x05004000;

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

export default defineRom({
  name: "cpu-cache",
  header: { gameTitle: "OPENFPGA CPU CHE", makerCode: "OF", gameCode: "VCHE", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number, counted in program order in rom.ts. " +
    "In Mednafen: loads as OPENFPGA CPU CHE and the last halfword written to " +
    "0x05000000 is 0x600D.",
  program: (a) => {
    a.jr("start");
    a.align(8);

    // The probe routine, one cache subblock: reports 5 from ROM. The
    // fabricated cache image reports 9 from the same address.
    a.label("T");
    const tAddr = a.pc;
    a.movImm(5, r10);
    a.jmp(r31);
    a.align(8);

    const entry = (tAddr >> 3) & 0x7f;
    const tagWord = (0x400000 | (tAddr >>> 10)) >>> 0;

    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r10);
    a.ldsr(r10, PSW);
    a.di();

    // 1: with the cache disabled, the ROM's own code runs.
    progress(a);
    a.jal("T");
    expectEq(a, r10, 5);

    // 2: build the restore image: 1,536 zero bytes, then one fabricated
    // entry for T -- data says "movImm 9" where ROM says 5, tag valid.
    progress(a);
    a.loadImm(IMAGE, r11);
    a.movImm(0, r10);
    a.loadImm(384, r12);
    a.label("clr");
    a.stW(r10, 0, r11);
    a.addImm(4, r11);
    a.addImm(-1, r12);
    a.bne("clr");
    a.loadImm(IMAGE + entry * 8, r11);
    a.loadImm(0x181f4149, r10); // movImm 9, r10 / jmp [r31]
    a.stW(r10, 0, r11);
    a.loadImm(IMAGE + 1024 + entry * 4, r11);
    a.loadImm(tagWord, r10);
    a.stW(r10, 0, r11);

    // 3: restore it, enable the cache, and the fabricated entry executes
    // in place of ROM.
    progress(a);
    a.loadImm(IMAGE | 0x22, r11); // ICR | ICE
    a.ldsr(r11, CHCW);
    a.jal("T");
    expectEq(a, r10, 9);

    // 4: a clear starting at entry 128 clears nothing [Scroll, CHCW].
    progress(a);
    a.loadImm((128 << 20) | (4095 << 8) | 0x3, r11);
    a.ldsr(r11, CHCW);
    a.jal("T");
    expectEq(a, r10, 9);

    // 5: clearing exactly T's entry refills from ROM.
    progress(a);
    a.loadImm((entry << 20) | (1 << 8) | 0x3, r11);
    a.ldsr(r11, CHCW);
    a.jal("T");
    expectEq(a, r10, 5);

    // 6: a cached loop runs correctly.
    progress(a);
    a.movImm(0, r10);
    a.movImm(10, r12);
    a.label("loop");
    a.addImm(1, r10);
    a.addImm(-1, r12);
    a.bne("loop");
    expectEq(a, r10, 10);

    // 7: dump the cache and verify the spilled layout: T's entry holds the
    // ROM refill with its subblock valid bit at 22, and an entry no fetch
    // ever touched dumps as the zeros the restore loaded.
    progress(a);
    a.loadImm(DUMP | 0x12, r11); // ICD | ICE
    a.ldsr(r11, CHCW);
    a.loadImm(DUMP, r11);
    a.ldW(entry * 8, r11, r10);
    expectEq(a, r10, 0x181f4145); // movImm 5 / jmp [r31], from ROM
    a.ldW(1024 + entry * 4, r11, r10);
    expectEq(a, r10, tagWord);
    a.ldW(100 * 8, r11, r10); // entry 100: never fetched
    expectEq(a, r10, 0);
    a.ldW(1024 + 100 * 4, r11, r10);
    expectEq(a, r10, 0);

    // 8: with ICE off again, fetches bypass whatever the arrays hold.
    progress(a);
    a.movImm(0, r11);
    a.ldsr(r11, CHCW);
    a.jal("T");
    expectEq(a, r10, 5);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
