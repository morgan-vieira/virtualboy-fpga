import { r0, r6, r7, r8 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "vip-display",
  header: { gameTitle: "OPENFPGA VIP DSP", makerCode: "OF", gameCode: "VVDP", revision: 0 },
  expectation:
    "The Pocket shows alternating four-pixel-wide dim and medium red vertical " +
    "stripes across the full 384x224 field. Black, flat brightness, stripes wider " +
    "or narrower than four pixels, or any horizontal break fails.",
  program: (a) => {
    a.label("start");
    a.di();

    // Display buffer 1 directly, without involving the drawing engine.
    a.loadImm(0x00008000, r6);
    a.loadImm(0x5555, r7);
    a.loadImm(12288, r8);
    a.label("framebuffer");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("framebuffer");

    // CTA starts at FA and walks downward once per four columns.
    a.loadImm(0x0003ddf4, r6);
    a.loadImm(0x00ff, r7);
    a.loadImm(96, r8);
    a.label("columns");
    a.stH(r7, 0, r6);
    a.xori(0x0100, r7, r7);
    a.addImm(-2, r6);
    a.addImm(-1, r8);
    a.bne("columns");

    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r0, 4, r6);
    a.stH(r0, 6, r6);

    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0302, r7);
    a.stH(r7, 0, r6);
    a.hang();
  },
});
