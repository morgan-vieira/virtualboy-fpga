import { r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "halt",
  header: { gameTitle: "OPENFPGA HALT", makerCode: "OF", gameCode: "VHLT", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row " +
    "of 16 status cells reads 0xBEEF (1011 1110 1110 1111) — the low halfword of " +
    "the 0xDEADBEEF the ROM stores to 0x05000000. In Mednafen: the image loads " +
    "without being rejected, the log reports the title OPENFPGA HALT and a 1KiB " +
    "ROM. Failure is a hollow square, different cells, or Mednafen refusing the " +
    "image.",
  program: (asm) => {
    asm.label("start");
    // Masks interrupts, which would otherwise wake the CPU out of the halt
    // below and run it into the 0xFF fill.
    asm.di();
    // Stores 0xDEADBEEF to the base of WRAM, 0x05000000.
    asm.loadImm(0x05000000, r6);
    asm.loadImm(0xdeadbeef, r7);
    asm.stW(r7, 0, r6);
    // halt, then a branch onto it.
    asm.hang();
  },
});
