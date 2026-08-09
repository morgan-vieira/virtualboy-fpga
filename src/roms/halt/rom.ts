import { r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "halt",
  header: { gameTitle: "OPENFPGA HALT", makerCode: "OF", gameCode: "VHLT", revision: 0 },
  expectation:
    "In Mednafen: the image loads without being rejected, the log reports the title " +
    "OPENFPGA HALT and a 1KiB ROM, and the emulator sits idle with a black screen. " +
    "Not yet judgeable on the Pocket — the core has no CPU, so a black screen there " +
    "proves nothing either way. Failure is Mednafen refusing the image, or reporting " +
    "a different title, code or size.",
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
