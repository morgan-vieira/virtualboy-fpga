import { r0, r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const MODULATION_RAM = 0x280;
const CHANNEL_FIVE = 0x500;
const BASE_FREQUENCY = 1693;
const modulation = [
  -120, -105, -90, -75, -60, -45, -30, -15,
  0, 15, 30, 45, 60, 75, 90, 105,
  120, 105, 90, 75, 60, 45, 30, 15,
  0, -15, -30, -45, -60, -75, -90, -105,
] as const;

export default defineRom({
  name: "vsu-modulation",
  header: {
    gameTitle: "OPENFPGA VSU MOD",
    makerCode: "OF",
    gameCode: "VMOD",
    revision: 0,
  },
  expectation:
    "On the Pocket: a continuous tone repeatedly bends upward and downward like " +
    "a smooth siren. A fixed pitch, one-way slide, silence, or a bend that stops " +
    "after one cycle means channel-five modulation failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);

    for (let sample = 0; sample < 32; sample += 1) {
      a.loadImm(sample < 16 ? 0 : 63, r7);
      a.stB(r7, sample * 4, r6);
    }
    for (const [index, value] of modulation.entries()) {
      a.loadImm(value & 0xff, r7);
      a.stB(r7, MODULATION_RAM + index * 4, r6);
    }

    a.movea(0xff, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x04, r6);
    a.movea(BASE_FREQUENCY & 0xff, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x08, r6);
    a.movea(BASE_FREQUENCY >> 8, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x0c, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x10, r6);
    a.movea(0x70, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x14, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x18, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_FIVE + 0x1c, r6);
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_FIVE, r6);
    a.hang();
  },
});
