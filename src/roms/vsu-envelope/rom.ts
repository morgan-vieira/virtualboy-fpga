import { r0, r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_ONE = 0x400;

export default defineRom({
  name: "vsu-envelope",
  header: {
    gameTitle: "OPENFPGA VSU ENV",
    makerCode: "OF",
    gameCode: "VENV",
    revision: 0,
  },
  expectation:
    "On the Pocket: a tone repeatedly fades from full volume to silence over " +
    "about two seconds, then returns abruptly and repeats. Constant volume, " +
    "reversed fades, irregular stepping, or silence means envelope processing failed.",
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
    a.movea(0xf7, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x10, r6);
    a.movea(0x03, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x14, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_ONE + 0x18, r6);
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_ONE, r6);
    a.hang();
  },
});
