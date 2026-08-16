import { r0, r6, r7, r8, r9 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "vip-affine-diag",
  header: { gameTitle: "OPENFPGA VIP ADG", makerCode: "OF", gameCode: "VVAD", revision: 0 },
  expectation:
    "The Pocket shows a dim full-screen red field with a brighter patterned " +
    "384x64 rectangle across the top. An entirely black screen means drawing did " +
    "not complete; a flat dim field means affine coordinates or parameters failed.",
  program: (a) => {
    a.label("start");
    a.di();

    // Every source pixel is nontransparent, so valid affine output cannot be black.
    a.loadImm(0x00006010, r6);
    a.loadImm(0xe9e9, r7);
    a.movImm(8, r8);
    a.label("charRows");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("charRows");

    // Map segment 1, leaving DRAM offset zero for affine parameters.
    a.loadImm(0x00022000, r6);
    a.movImm(1, r7);
    a.loadImm(4096, r8);
    a.label("mapCells");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("mapCells");

    a.loadImm(0x00020000, r6);
    a.movImm(0, r9);
    a.loadImm(64, r8);
    a.label("affineRows");
    a.stH(r0, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r9, 4, r6);
    a.loadImm(512, r7);
    a.stH(r7, 6, r6);
    a.stH(r0, 8, r6);
    a.addImm(8, r6);
    a.addImm(8, r6);
    a.addImm(8, r9);
    a.addImm(-1, r8);
    a.bne("affineRows");

    a.loadImm(0x0003dbe0, r6);
    a.loadImm(0xe001, r7);
    a.stH(r7, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r0, 4, r6);
    a.stH(r0, 6, r6);
    a.loadImm(383, r7);
    a.stH(r7, 14, r6);
    a.loadImm(63, r7);
    a.stH(r7, 16, r6);
    a.stH(r0, 18, r6);
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
    a.loadImm(0x0005f870, r6);
    a.movImm(1, r7);
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
