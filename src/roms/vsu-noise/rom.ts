import { r0, r6, r7 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

const VSU = 0x01000000;
const CHANNEL_SIX = 0x540;
const NOISE_FREQUENCY = 1988;

export default defineRom({
  name: "vsu-noise",
  header: {
    gameTitle: "OPENFPGA VSU NOISE",
    makerCode: "OF",
    gameCode: "VNOI",
    revision: 0,
  },
  expectation:
    "On the Pocket: steady broadband static plays equally from both speakers. " +
    "A pitched tone, repeating click, silence, unstable volume, or one-sided " +
    "output means channel-six noise failed.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(VSU, r6);
    a.movea(0xff, r0, r7);
    a.stB(r7, CHANNEL_SIX + 0x04, r6);
    a.movea(NOISE_FREQUENCY & 0xff, r0, r7);
    a.stB(r7, CHANNEL_SIX + 0x08, r6);
    a.movea(NOISE_FREQUENCY >> 8, r0, r7);
    a.stB(r7, CHANNEL_SIX + 0x0c, r6);
    a.movea(0xf0, r0, r7);
    a.stB(r7, CHANNEL_SIX + 0x10, r6);
    a.movImm(0, r7);
    a.stB(r7, CHANNEL_SIX + 0x14, r6);
    a.movea(0x80, r0, r7);
    a.stB(r7, CHANNEL_SIX, r6);
    a.hang();
  },
});
