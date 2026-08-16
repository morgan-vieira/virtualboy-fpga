import { r0, r6, r7, r8 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "vip-bg",
  header: { gameTitle: "OPENFPGA VIP BG", makerCode: "OF", gameCode: "VVBG", revision: 0 },
  expectation:
    "The Pocket shows a full 384x224 field of repeating vertical red bars at " +
    "three clearly different brightness levels. Black, a flat single shade, " +
    "missing bars, or the old CPU diagnostic screen is failure.",
  program: (a) => {
    a.label("start");
    a.di();

    // Character 1: four non-zero palette indexes repeated across every row.
    a.loadImm(0x00006010, r6);
    a.loadImm(0xe4e4, r7);
    a.movImm(8, r8);
    a.label("charRows");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("charRows");

    // Fill map zero with character 1.
    a.loadImm(0x00020000, r6);
    a.movImm(1, r7);
    a.loadImm(4096, r8);
    a.label("mapCells");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("mapCells");

    // World 31 covers the display; world 30 terminates the list.
    a.loadImm(0x0003dbe0, r6);
    a.loadImm(0xc000, r7);
    a.stH(r7, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r0, 4, r6);
    a.stH(r0, 6, r6);
    a.stH(r0, 8, r6);
    a.stH(r0, 10, r6);
    a.stH(r0, 12, r6);
    a.loadImm(383, r7);
    a.stH(r7, 14, r6);
    a.loadImm(223, r7);
    a.stH(r7, 16, r6);
    a.loadImm(0x0003dbc0, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);

    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);
    a.movea(0x80, r0, r7);
    a.stH(r7, 2, r6);
    a.movea(0x3f, r0, r7);
    a.stH(r7, 4, r6);
    a.loadImm(0x0005f860, r6);
    a.movea(0xe4, r0, r7);
    a.stH(r7, 0, r6);
    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0602, r7);
    a.stH(r7, 0, r6);
    a.loadImm(0x0005f842, r6);
    a.movImm(2, r7);
    a.stH(r7, 0, r6);
    a.hang();
  },
});
