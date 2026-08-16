import { r0, r6, r7, r8, r9, r10, r11, r12 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "vip-obj",
  header: { gameTitle: "OPENFPGA VIP OBJ", makerCode: "OF", gameCode: "VVOB", revision: 0 },
  expectation:
    "The Pocket shows fourteen rows of evenly spaced bright red 8x8 squares on " +
    "black, with the first square in each row clipped four pixels off the left " +
    "edge by object parallax. Missing, smeared, joined, or unshifted squares fail.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(0x00006010, r6);
    a.loadImm(0x5555, r7);
    a.movImm(8, r8);
    a.label("charRows");
    a.stH(r7, 0, r6);
    a.addImm(2, r6);
    a.addImm(-1, r8);
    a.bne("charRows");

    a.loadImm(0x0003e000, r6);
    a.movImm(0, r9);
    a.movea(14, r0, r12);
    a.label("objectRow");
    a.movImm(0, r10);
    a.loadImm(32, r8);
    a.label("objectColumn");
    a.stH(r10, 0, r6);
    a.loadImm(0xc004, r7);
    a.stH(r7, 2, r6);
    a.stH(r9, 4, r6);
    a.movImm(1, r11);
    a.stH(r11, 6, r6);
    a.addImm(8, r6);
    a.addImm(12, r10);
    a.addImm(-1, r8);
    a.bne("objectColumn");
    a.addImm(8, r9);
    a.addImm(8, r9);
    a.addImm(-1, r12);
    a.bne("objectRow");

    a.loadImm(0x0003dbe0, r6);
    a.loadImm(0xf000, r7);
    a.stH(r7, 0, r6);
    a.loadImm(0x0003dbc0, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);

    a.loadImm(0x0005f848, r6);
    a.loadImm(1023, r7);
    a.stH(r7, 4, r6);
    a.loadImm(447, r7);
    a.stH(r7, 6, r6);
    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);
    a.movea(0x80, r0, r7);
    a.stH(r7, 2, r6);
    a.movea(0x3f, r0, r7);
    a.stH(r7, 4, r6);
    a.loadImm(0x0005f868, r6);
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
