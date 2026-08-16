import { r0, r6, r7, r8 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_FIVE = 0x500;
const START_FREQUENCY = 1693;

export default defineRom({
  name: "vsu-sweep",
  header: {
    gameTitle: "OPENFPGA VSU SWEEP",
    makerCode: "OF",
    gameCode: "VSWP",
    revision: 0,
  },
  expectation:
    "On the Pocket: a tone repeatedly slides from high to low over roughly two " +
    "seconds, then snaps back high. A fixed pitch, upward slide, silence, or " +
    "irregular resets means channel-five sweep failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);

    for (let sample = 0; sample < 32; sample += 1) {
      a.loadImm(sample < 16 ? 0 : 63, r7);
      a.stB(r7, sample * 4, r6);
    }

    a.movea(0xff, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x04, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x10, r6);
    a.movea(0x40, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x14, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x18, r6);
    a.movea(0xf4, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x1c, r6);

    a.label("repeat");
    a.movea(START_FREQUENCY & 0xff, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x08, r6);
    a.movea(START_FREQUENCY >> 8, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x0c, r6);
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_FIVE, r6);
    a.loadImm(8_000_000, r8);
    a.label("wait");
    a.addImm(-1, r8);
    a.bne("wait");
    a.br("repeat");
  },
});
