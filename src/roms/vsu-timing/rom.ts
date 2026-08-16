import { r0, r6, r7, r8 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_ONE = 0x400;

export default defineRom({
  name: "vsu-timing",
  header: {
    gameTitle: "OPENFPGA VSU TIME",
    makerCode: "OF",
    gameCode: "VTIM",
    revision: 0,
  },
  expectation:
    "On the Pocket: a clearly sustained short tone burst repeats after a longer " +
    "silent gap. Click-like bursts mean the VSU is still running four times fast; " +
    "a continuous tone or silence means automatic duration failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);

    for (let sample = 0; sample < 32; sample += 1) {
      a.loadImm(sample < 16 ? 0 : 63, r7);
      a.stB(r7, sample * 4, r6);
    }

    a.movea(0xff, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x04, r6);
    a.movea(1693 & 0xff, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x08, r6);
    a.movea(1693 >> 8, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x0c, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x10, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_ONE + 0x18, r6);

    a.label("repeat");
    a.movea(0xbf, r0, r7);
    a.stB(r7, CHANNEL_ONE, r6);
    a.loadImm(2_000_000, r8);
    a.label("wait");
    a.addImm(-1, r8);
    a.bne("wait");
    a.br("repeat");
  },
});
