# Test ROMs

Every module in `src/fpga/core/` gets a ROM built for its specific requirement. A commercial game exercises everything at once and proves nothing in particular; a ROM written for one module fails in one way, and that way points at the module. This folder holds the source to those ROMs, next to the Verilog they exist to test.

## Building

```powershell
pnpm run build:roms                # every ROM, into .roms/
pnpm run build:roms -- --rom halt  # just one
pnpm run test:roms                 # the assembler's own tests
```

Built images land in `.roms/` at the repository root and are gitignored — they are rebuilt from source, never edited. There is no toolchain to install. The V810 assembler and the ROM packer live in `scripts/lib/`, so building a ROM means importing its source and writing out the bytes.

## What a ROM source looks like

One directory per ROM, holding a `rom.ts` that default-exports a spec:

```ts
import { defineRom } from "#scripts/lib/vb-rom";
import { r6, r7 } from "#scripts/lib/v810";

export default defineRom({
  name: "wram-signature",
  header: { gameTitle: "OPENFPGA WRAM", makerCode: "OF", gameCode: "VWRM", revision: 0 },
  expectation: "what a maintainer should see on the Pocket, and what failure looks like",
  program: (asm) => {
    asm.label("start");
    asm.di();
    asm.loadImm(0x05000000, r6);
    asm.loadImm(0xdeadbeef, r7);
    asm.stW(r7, 0, r6);
    asm.hang();
  },
});
```

`expectation` is not documentation. You cannot see the Pocket's screen and neither can the build script, so the ROM has to say in advance what a pass looks like — what shows on screen, what comes out of the speaker, and what a failure looks like instead. `pnpm run build:roms` prints it next to the image it just built, and that sentence is what gets handed to whoever runs the hardware test. "Load it and see" is not an instruction.

The entry point is the label `start` unless `entry` says otherwise. Interrupt handlers are named the same way, through `handlers: { vip: "onVip" }`.

`#scripts/*` and `#roms/*` are subpath imports declared in the root `package.json`. Node resolves them natively, so there is no loader or bundler in the way — but they only work from inside this package, and the leading `#` is required. A scoped `@scripts` name is not an option: npm scopes have to be `@scope/name`.

## What the packer does

A `.vb` file is a flat binary. No container, no checksum, no signature — everything that makes it a ROM is where the bytes sit:

| Offset         | Size    | Contents                                           |
| -------------- | ------- | -------------------------------------------------- |
| `0`            | code    | Whatever `program` emitted, linked at `0x07000000` |
| `size - 0x220` | `0x20`  | ROM header: title, maker code, game code, revision |
| `size - 0x200` | `0x200` | Interrupt and reset vector table                   |
| `size`         | —       | End of file, always a power of two                 |

Gaps fill with `0xFF` to match erased flash. The size is the smallest power of two the code and trailer fit inside, floored at 1KB, and `sizeBytes` can force it larger.

The trailer is anchored to the end of the file rather than to a fixed address because the cart is mirrored: the address bus masks with `size - 1`, so a 1KB ROM and a 2MB ROM both boot from their own last sixteen bytes. That mirroring is not a convenience, it is the mechanism — the core has to reproduce it, or a small test ROM will not reach its own reset vector.

Vectors the ROM does not name get a stub that halts and branches onto itself. A stray interrupt then freezes visibly instead of running off into the `0xFF` fill and doing something that looks like a core bug.

## Adding one

1. Create `src/roms/<name>/rom.ts` and write the smallest program that exercises the one thing you are testing.
2. Write the `expectation` before the code, not after. If you cannot say what a pass looks like, the ROM is testing too much.
3. `pnpm run build:roms` and `pnpm run test:roms`.
4. Add it to the table below, then ask a maintainer to run it. A clean build is a status update, not a conclusion.

## The ROMs

| ROM               | Module under test           | Pass looks like                                                                                                                                                                                                                                                                                        |
| ----------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `halt`            | none — the packaging itself | Loads in a reference emulator without being rejected, writes `0xDEADBEEF` to WRAM `0x05000000`, and sits in `HALT`. On the Pocket: the halt square fills and the status cells read `0xBEEF`.                                                                                                           |
| `cpu-alu`         | `cpu`                       | Status cells read `0x600D` with the halt square filled. A failure spins with the failing check's number on the cells: arithmetic, flags, multiply/divide r30 ordering, shifts, load/store widths.                                                                                                      |
| `cpu-branch`      | `cpu`                       | Status cells read `0x600D` with the halt square filled. All sixteen conditions both ways, `JMP`/`JR`/`JAL`, the `r31` link, and target bit-0 masking.                                                                                                                                                  |
| `cpu-except`      | `cpu`                       | Status cells read `0x600D` with the halt square filled. Trap through both vectors, RETI restoring flags, illegal opcode and zero divide resumed by handler, the duplexed escalation, sysreg fixed values, WCR readback.                                                                                |
| `busmap`          | `mem_bus`                   | Status cells read `0x600D` with the halt square filled. A value per region, mirrors both by region masking and by the 27-bit space, zero from unmapped/VSU/expansion, byte lanes.                                                                                                                      |
| `timer`           | `timer`                     | Status cells count up by one each second — `0x003C` after a timed minute — and the halt square never fills. A frozen small number is that check failing. Mednafen freezes at `0x0003` by design: beetle-vb defers the reload write the scroll documents as immediate, and the core follows the scroll. |
| `vip-bg`          | `vip` background drawing    | A full 384×224 field of vertical red bars at three distinct brightness levels. Black, flat colour, missing bars, or the CPU diagnostic screen fails.                                                                                                                                                   |
| `vip-obj`         | `vip` object drawing        | Fourteen rows of spaced bright 8×8 red squares on black; the first square is clipped four pixels by left-eye parallax. Missing, smeared, joined, or unshifted squares fail.                                                                                                                            |
| `vip-affine`      | `vip` affine drawing        | Three-level bands slope smoothly down and right by half a pixel per scanline. Horizontal bands, eight-line stepping, flat colour, or black fails.                                                                                                                                                      |
| `vip-affine-diag` | `vip` affine diagnosis      | A dim full-screen red field with a brighter patterned 384x64 rectangle across the top. Black means drawing did not complete; a flat dim field means affine coordinates or parameters failed.                                                                                                           |
| `vip-display`     | `vip_display`               | Alternating four-pixel-wide dim and medium red vertical stripes fill the 384x224 field. Black, flat brightness, incorrectly sized stripes, or horizontal breaks fail.                                                                                                                                  |
| `vip-int`         | `vip` interrupts and BKCOL  | The field advances through four shades about every 320 ms; on each change the top eight rows retain the previous shade for one frame. Frozen or whole-frame changes fail.                                                                                                                              |
| `vsu-tone`        | `vsu` wavetable channel one | A steady square-wave tone near A4 (440 Hz) plays in both channels, clearly louder on the right than the left. Silence, unstable pitch, or equal/reversed loudness fails.                                                                                                                               |
| `vsu-chord`       | `vsu` wavetable channels    | A steady five-note C-major chord plays without popping; lower voices favor the left channel and higher voices favor the right. A single/thin tone, silence, or centred stereo fails.                                                                                                                   |
| `vsu-envelope`    | `vsu` envelope progression  | A tone repeatedly fades from full volume to silence over about two seconds, then returns abruptly and repeats. Constant volume, reversed fades, irregular stepping, or silence fails.                                                                                                                   |
| `vsu-timing`      | `vsu` 5 MHz base clock      | A clearly sustained short tone burst repeats after a longer silent gap. Click-like bursts mean the VSU is still running four times fast; a continuous tone or silence means automatic duration failed.                                                                                                  |
| `vsu-sweep`       | `vsu` channel-five sweep    | A tone repeatedly slides from high to low over roughly two seconds, then snaps back high. A fixed pitch, upward slide, silence, or irregular resets fail.                                                                                                                                                 |

The CPU-era ROMs share a status convention: the ROM writes a running check
number to WRAM `0x05000000` before each check, `core_top` latches writes to that
address onto a row of on-screen cells, success writes `0x600D` and halts, and
each failure spins with its own number showing. The failing check is then read
straight off the screen.

On the Pocket, built `.vb` images go in `Assets/virtualboy/common/` on the SD
card; the core prompts for one at launch and can reload from the Interact menu.
The cartridge slot tops out at 64KB until cartridge memory moves off-chip.

## Where the format came from

The layout was read off VUEngine Studio's linker script, `.repos/vuengine-studio/applications/electron/templates/vb.ld.njk`, which is what actually places the header and vectors in a real VUEngine build. The size and mirroring rules were confirmed against beetle-vb's loader in `.repos/beetle-vb-libretro/libretro.cpp`, which refuses any image that is not a power of two between 256 bytes and 16MB.

Every instruction encoding in `scripts/lib/v810.ts` was taken from the decoder in `.repos/beetle-vb-libretro/mednafen/hw_cpu/v810/`, not from memory, and `scripts/lib/v810.test.ts` checks the bytes against that field layout. An assembler bug and a core bug look identical from the outside — both are a test ROM misbehaving on hardware — so the assembler is tested before it is trusted.
