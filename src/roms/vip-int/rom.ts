import { PSW, r0, r6, r7, r8, r20 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

export default defineRom({
  name: "vip-int",
  header: { gameTitle: "OPENFPGA VIP INT", makerCode: "OF", gameCode: "VVIN", revision: 0 },
  expectation:
    "About every 320 ms the Pocket advances through black, dim, medium, and bright " +
    "red fields, then repeats. On each change only the top eight rows retain the " +
    "previous shade for that frame. A frozen field means XPEND or interrupt clear " +
    "failed; a single-shade or whole-frame change means BKCOL staging failed.",
  handlers: { vip: "onVip" },
  program: (a) => {
    a.label("onVip");
    a.addImm(1, r20);
    a.andi(3, r20, r20);
    a.stH(r20, 0, r6);
    a.stH(r8, 0, r7);
    a.reti();

    a.label("start");
    a.di();
    a.loadImm(0x0005f870, r6);
    a.loadImm(0x0005f804, r7);
    a.loadImm(0x4000, r8);
    a.movImm(1, r20);
    a.stH(r20, 0, r6);

    a.loadImm(0x0003dbe0, r6);
    a.movea(0x40, r0, r20);
    a.stH(r20, 0, r6);
    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r20);
    a.stH(r20, 0, r6);
    a.movea(0x80, r0, r20);
    a.stH(r20, 2, r6);
    a.movea(0x3f, r0, r20);
    a.stH(r20, 4, r6);
    a.movImm(15, r20);
    a.stH(r20, 10, r6);
    a.loadImm(0x0005f802, r6);
    a.stH(r8, 0, r6);
    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0602, r20);
    a.stH(r20, 0, r6);
    a.loadImm(0x0005f842, r6);
    a.movImm(2, r20);
    a.stH(r20, 0, r6);

    // Reset leaves NP set; clear PSW only after the handler's registers exist.
    a.loadImm(0x0005f870, r6);
    a.loadImm(0x0005f804, r7);
    a.movImm(0, r20);
    a.ldsr(r20, PSW);
    a.label("idle");
    a.br("idle");
  },
});
