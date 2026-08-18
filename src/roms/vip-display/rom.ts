import { type Assembler, r0, r6, r7, r8, r9, r10, r11 } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Fill one left frame buffer with shade 1, r7 carrying the pattern.
const fillBuffer = (a: Assembler, base: number, tag: string) => {
  a.loadImm(base, r6);
  a.loadImm(12288, r8);
  a.label(tag);
  a.stH(r7, 0, r6);
  a.addImm(2, r6);
  a.addImm(-1, r8);
  a.bne(tag);
};

// Read one halfword back and set a bit if it is what was written. The
// picture is the verdict; this only tells a maintainer which half failed.
let seq = 0;
const probe = (
  a: Assembler,
  address: number,
  mask: number,
  want: number,
  bit: number,
) => {
  const done = `probe_${(seq += 1)}`;
  a.loadImm(address, r6);
  a.ldH(0, r6, r7);
  a.andi(mask, r7, r7); // ldH sign-extends; the mask is what makes it a halfword
  a.loadImm(want, r8);
  a.cmp(r8, r7);
  a.bne(done);
  a.ori(bit, r9, r9);
  a.label(done);
};

export default defineRom({
  name: "vip-display",
  header: { gameTitle: "OPENFPGA VIP DSP", makerCode: "OF", gameCode: "VVDP", revision: 0 },
  expectation:
    "The Pocket shows alternating four-pixel-wide dim and medium red vertical " +
    "stripes across the full 384x224 field. Black, flat brightness, stripes wider " +
    "or narrower than four pixels, or any horizontal break fails. With " +
    "Diagnostic Overlay: On the status row reads 0x00FF, the ROM's own " +
    "read-back of both buffers, the brightness, the column table and the " +
    "display control; any clear bit names the half that did not stick.",
  program: (a) => {
    a.label("start");
    a.di();

    // Nothing here enables the drawing engine, so the VIP never swaps and
    // which buffer it shows out of reset is its call. Fill both.
    a.loadImm(0x5555, r7);
    fillBuffer(a, 0x00000000, "buffer0");
    fillBuffer(a, 0x00008000, "buffer1");

    // CTA starts at FA and walks downward once per four columns.
    a.loadImm(0x0003ddf4, r6);
    a.loadImm(0x00ff, r7);
    a.loadImm(96, r8);
    a.label("columns");
    a.stH(r7, 0, r6);
    a.xori(0x0100, r7, r7);
    a.addImm(-2, r6);
    a.addImm(-1, r8);
    a.bne("columns");

    a.loadImm(0x0005f824, r6);
    a.movea(0x40, r0, r7);
    a.stH(r7, 0, r6);
    a.stH(r0, 2, r6);
    a.stH(r0, 4, r6);
    a.stH(r0, 6, r6);

    a.loadImm(0x0005f822, r6);
    a.loadImm(0x0302, r7);
    a.stH(r7, 0, r6);

    // Both buffers, both ends, the brightness, both column entries, and the
    // display control that survived. All eight is 0x00FF.
    a.mov(r0, r9);
    probe(a, 0x00000000, 0xffff, 0x5555, 0x0001);
    probe(a, 0x00005ffe, 0xffff, 0x5555, 0x0002);
    probe(a, 0x00008000, 0xffff, 0x5555, 0x0004);
    probe(a, 0x0000dffe, 0xffff, 0x5555, 0x0008);
    probe(a, 0x0005f824, 0x00ff, 0x0040, 0x0010);
    probe(a, 0x0003ddf4, 0xffff, 0x00ff, 0x0020);
    probe(a, 0x0003ddf2, 0xffff, 0x01ff, 0x0040);
    // FCLK latches SYNCE and DISP once a frame, so wait for the latch
    // instead of racing it. Bounded, so a core that never latches still
    // reports the other seven.
    a.loadImm(0x0005f820, r6);
    a.loadImm(0x0302, r11);
    a.loadImm(200000, r8);
    a.label("dpwait");
    a.ldH(0, r6, r7);
    a.andi(0x0702, r7, r7);
    a.cmp(r11, r7);
    a.be("dpready");
    a.addImm(-1, r8);
    a.bne("dpwait");
    a.label("dpready");

    // DPSTTS, masked to LOCK, SYNCE, RE and DISP.
    probe(a, 0x0005f820, 0x0702, 0x0302, 0x0080);
    a.loadImm(0x05000000, r10);
    a.stH(r9, 0, r10);

    a.hang();
  },
});
