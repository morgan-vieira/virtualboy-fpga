import { r0, r6, r7, r8, r9 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_ONE = 0x400;

export default defineRom({
  name: "vsu-restart",
  header: {
    gameTitle: "OPENFPGA VSU RESTART",
    makerCode: "OF",
    gameCode: "VRST",
    revision: 0,
  },
  expectation:
    "On the Pocket: a tone fades once to silence despite frequent phase " +
    "restarts, pauses, then returns at full volume and repeats. Constant " +
    "loudness means INT writes incorrectly reload the envelope; clicks, " +
    "unstable pitch, or no repeating fade means restart behavior failed.",
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
    a.movea(0x01, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x14, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_ONE + 0x18, r6);

    a.label("repeat");
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x10, r6);
    a.movea(16, r0, r8);

    a.label("retrigger");
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_ONE, r6);
    a.loadImm(200_000, r9);
    a.label("shortWait");
    a.addImm(-1, r9);
    a.bne("shortWait");
    a.addImm(-1, r8);
    a.bne("retrigger");

    a.loadImm(2_000_000, r9);
    a.label("silentWait");
    a.addImm(-1, r9);
    a.bne("silentWait");
    a.br("repeat");
  },
});
