import { r0, r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const channels = [
  { frequency: 854, volume: 0xc4 },
  { frequency: 1100, volume: 0x88 },
  { frequency: 1251, volume: 0x88 },
  { frequency: 1451, volume: 0x4c },
  { frequency: 1574, volume: 0x4c },
] as const;

export default defineRom({
  name: "vsu-chord",
  header: {
    gameTitle: "OPENFPGA VSU CHORD",
    makerCode: "OF",
    gameCode: "VCHD",
    revision: 0,
  },
  expectation:
    "On the Pocket: a steady five-note C-major chord plays without popping; its lower voices favor the left channel and higher voices favor the right. A single or thin tone means a wavetable channel is missing, silence means mixing failed, and a centred chord means stereo routing failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);

    for (let sample = 0; sample < 32; sample += 1) {
      a.loadImm(sample < 16 ? 0 : 63, r7);
      a.stB(r7, sample * 4, r6);
    }

    for (const [channel, config] of channels.entries()) {
      const base = 0x400 + channel * 0x40;
      a.movea(config.volume, r0, r7);
      a.stB(r7, base + 0x04, r6);
      a.movea(config.frequency & 0xff, r0, r7);
      a.stB(r7, base + 0x08, r6);
      a.movea(config.frequency >> 8, r0, r7);
      a.stB(r7, base + 0x0c, r6);
      a.movea(0xf0, r0, r7);
      a.stB(r7, base + 0x10, r6);
      a.movImm(0, r7);
      a.stB(r7, base + 0x18, r6);
    }

    for (const channel of channels.keys()) {
      a.movea(0x80, r0, r7);
      a.stB(r7, 0x400 + channel * 0x40, r6);
    }
    a.hang();
  },
});
