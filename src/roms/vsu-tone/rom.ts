import { r0, r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_ONE = 0x400;

export default defineRom({
  name: "vsu-tone",
  header: {
    gameTitle: "OPENFPGA VSU TONE",
    makerCode: "OF",
    gameCode: "VVSU",
    revision: 0,
  },
  expectation:
    "On the Pocket: a steady square-wave tone near A4 (440 Hz) plays in both channels, clearly louder on the right than the left. Silence means the VSU or APF audio path failed; unstable pitch means frequency timing failed; equal or reversed loudness means stereo routing failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);

    for (let sample = 0; sample < 32; sample += 1) {
      a.loadImm(sample < 16 ? 0 : 63, r7);
      a.stB(r7, sample * 4, r6);
    }

    a.movea(0x4f, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x04, r6);
    a.movea(0x74, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x08, r6);
    a.movea(0x02, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x0c, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_ONE + 0x10, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_ONE + 0x18, r6);
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_ONE, r6);
    a.hang();
  },
});
