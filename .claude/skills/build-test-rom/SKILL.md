---
name: build-test-rom
description: Write, build and verify a Virtual Boy test ROM for this core, covering the .vb image layout (32-byte header and 512-byte vector table anchored to the end of a power-of-two image), the in-repo V810 assembler and its argument order, the memory map a ROM writes to, how to check a built image under Mednafen, and how to state a pass criterion a maintainer can check on hardware. Use when an agent needs to add a ROM under src/roms/, extend the assembler with a new opcode, confirm a built image loads in a reference emulator, diagnose a ROM that is rejected or that runs off into fill, or pick which ROM reproduces a reported bug.
---

# Build Test ROM

Build one ROM against one module's requirement. A commercial game exercises everything at once and proves nothing in particular; a ROM written for one module fails in one way, and that way points at the module.

Treat [src/roms/README.md](../../../src/roms/README.md) as the authoritative reference when this skill and it disagree.

## Write the smallest program that isolates one thing

Create `src/roms/<name>/rom.ts` with a default export:

```ts
import { defineRom } from "#scripts/lib/vb-rom";
import { r6, r7 } from "#scripts/lib/v810";

export default defineRom({
  name: "wram-signature",
  header: { gameTitle: "OPENFPGA WRAM", makerCode: "OF", gameCode: "VWRM", revision: 0 },
  expectation: "...",
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

`src/roms/halt/rom.ts` is the working version of that shape. Read it before writing a new ROM, and build it first whenever a new ROM misbehaves, to rule the packaging out.

`#scripts/*` and `#roms/*` are subpath imports declared in the root `package.json`. Use them rather than relative paths; the leading `#` is required and they only resolve from inside this package.

Execution starts at the label `start` unless `entry` names another. Name interrupt handlers with `handlers: { vip: "onVip" }`; any vector left out gets a stub that halts, so a stray interrupt freezes visibly instead of running into fill. `sizeBytes` forces an image size, and is only needed to test how the core handles a particular one.

## State the pass criterion before writing the code

`expectation` is required and is not documentation. Nobody building the ROM can see the Pocket, so the ROM states in advance what shows on screen, what comes out of the speaker, and what a failure looks like instead. `pnpm run build:roms` prints it beside the image, and that sentence is what gets handed to whoever runs the hardware test.

If that sentence cannot be written, the ROM is testing too much. Split it.

Where a module is not in the core yet, say so in the sentence and give the criterion for a reference emulator instead of implying a Pocket result. Do not write an expectation that a black screen would satisfy.

## Know the argument order

Arguments follow V810 assembly syntax, which puts the source first. Getting these backwards assembles cleanly and fails on hardware.

| Call | Meaning |
| --- | --- |
| `mov(src, dest)` | `dest = src`; same order for `add`, `sub`, `cmp`, `or`, `and`, `xor`, `not`, `mul`, `div` |
| `movImm(value, dest)` | 5-bit signed immediate, -16..15; same for `addImm`, `cmpImm` |
| `movea(value, src, dest)` | `dest = src + sign16(value)`; same for `movhi`, `addi`, `ori`, `andi`, `xori` |
| `loadImm(value, dest)` | Any 32-bit constant, as a `movhi`/`movea` pair |
| `ldW(disp, base, dest)` | `dest = mem[disp + base]`; same for `ldB`, `ldH`, `inB`, `inH`, `inW` |
| `stW(src, disp, base)` | `mem[disp + base] = src`; same for `stB`, `stH`, `outB`, `outH`, `outW` |
| `ldsr(src, sysReg)` / `stsr(sysReg, dest)` | System register moves; the register number is an immediate |
| `br(label)`, `be`, `bne`, `blt`, `bge`, … | Branch, reaching +254/-256 bytes |
| `jr(label)`, `jal(label)` | Jump, reaching +/-32MB |
| `jmp(reg)` | Jump to a register, the only way to reach an arbitrary address |
| `jumpFar(address)` | `loadImm` plus `jmp`, clobbering r1 |
| `hang()` | `halt` plus a branch onto it, the only permanent stop |
| `label(name)`, `byte`, `halfword`, `word`, `ascii`, `align` | Layout and raw data |

`halt()` alone is not a stop. An interrupt wakes the CPU and execution continues into whatever follows, which on a fresh image is `0xFF` fill.

## Write to the right addresses

Every region mirrors every `0x08000000`, because the CPU only decodes 27 address bits.

| Base | Region |
| --- | --- |
| `0x00000000` | VIP: frame buffers, character RAM, DRAM; registers at `0x0005F800`, 16-bit at even offsets |
| `0x01000000` | VSU registers, write-only |
| `0x02000000` | Hardware control: keypad `0x10`/`0x14`/`0x28`, timer `0x18`/`0x1C`/`0x20`, wait-state control `0x24` |
| `0x04000000` | Game Pak expansion |
| `0x05000000` | WRAM, 64KB, mirrored through the region |
| `0x06000000` | Game Pak RAM |
| `0x07000000` | Game Pak ROM, mirrored every image size |

Reads and writes are masked to their width: `stW` clears the low two address bits and `stH` the low one, so a misaligned store silently lands somewhere else.

## Build and check the image

```bash
pnpm run build:roms                       # every ROM, into .roms/
pnpm run build:roms -- --rom halt         # one
pnpm run test:roms                        # the assembler's own tests
```

Images land in `.roms/` and are gitignored. Never hand-edit one; change the source and rebuild.

Before handing a ROM over, confirm all of:

1. `pnpm run test:roms` passes. A change to the assembler that breaks an encoding breaks every ROM at once.
2. The build reports a power-of-two size and the code size you expect. Code far larger than the program suggests a loop emitting instructions.
3. The header reads back correctly from the end of the image, at `size - 0x220`.
4. `npx tsc -p src/roms/tsconfig.json --noEmit` is clean.

Then add the ROM to the table in `src/roms/README.md`.

## Check the image under Mednafen before handing it over

Mednafen is a local install, not a repository dependency. On morgan-vieira's machine it is at `C:\Users\morgan\Documents\Emulators\mednafen-1.32.1-win64\mednafen.exe`; confirm the path rather than assuming it on another machine.

The window it opens is not visible to the agent, so the check that matters is textual: Mednafen parses the ROM header with an implementation that is not ours and reports what it found. That catches a mispacked image before it wastes a maintainer's time.

On Windows, Mednafen writes its log to `stdout.txt` in its own base directory rather than to the console, and it runs until the window is closed. Start it, give it a few seconds, stop it, then read the log:

```powershell
$med  = 'C:\Users\morgan\Documents\Emulators\mednafen-1.32.1-win64\mednafen.exe'
$base = Split-Path $med
Remove-Item "$base\stdout.txt" -ErrorAction SilentlyContinue
$proc = Start-Process $med -ArgumentList '"<repo>\.roms\halt.vb"' -WorkingDirectory $base -PassThru
Start-Sleep -Seconds 5
Stop-Process -Id $proc.Id -Force
Get-Content "$base\stdout.txt" | Select-String 'Title|Game ID|Manufacturer|Version|ROM:|power of 2'
```

A well-formed image reports the header back:

```
   Title:     OPENFPGA HALT
   Game ID Code: 1414285398
   Manufacturer Code: 17999
   Version:   0
   ROM:       1KiB
```

Check the title, and that the size matches what the build reported. The two codes are the ASCII characters read as little-endian integers, so `1414285398` is `0x544C4856`, which is `VHLT`, and `17999` is `0x464F`, which is `OF`. Decode them rather than eyeballing them.

A rejected image prints `VB ROM image size is not a power of 2.` at the end of the log and no header block at all.

Ignore the `Failed:` and `Error:` lines about `.ips`, `vb.cfg`, `pgconfig`, `vb.pal` and `vb.cht`. Mednafen probes for those optional files on every launch and they are absent by design; they are not a problem with the ROM.

To give a maintainer something to watch, record the run with `-qtrecord <file.mov>` and report where the file is. `F9` saves a PNG into `snaps/`, but it needs a keypress, so it belongs to whoever is at the machine.

Mednafen agreeing proves the image is well-formed and that a reference emulator runs it. It says nothing about the core. Ask a maintainer to run the ROM on the Pocket; a clean build and a clean emulator run are status updates, not conclusions, and no ROM is done until someone has watched it behave on hardware.

## Add an opcode only against the decoder

The assembler covers what test ROMs have needed so far. When one needs more, read the encoding off the decoder in `.repos/beetle-vb-libretro/mednafen/hw_cpu/v810/`, using `v810_opt.h` for opcode numbers and `v810_oploop.inc` for the field layout and semantics. Never take an encoding from memory or from another assembler's syntax.

Add a test to `scripts/lib/v810.test.ts` in the same commit, with the expected halfwords worked out by hand from that field layout. Deriving them from the assembler makes the test agree with itself and prove nothing.

Do not propose adding a GNU v810 cross-toolchain. Building a test ROM deliberately requires nothing beyond Node.

## Troubleshoot predictable failures

When a user reports a game misbehaving, do not patch the core and re-test the game. Isolate the symptom to a module, build or pick the ROM that reproduces just that behavior, prove the fix in simulation, then ask for hardware again. A bug reproducible only inside a commercial game is a bug not yet found.

- **The emulator refuses to load the image:** the size is not a power of two, or is outside 256 bytes to 16MB. Check what the build reported.
- **Nothing runs, or execution starts mid-instruction:** the reset vector did not reach the code. Confirm the entry label exists and that the far jump at `size - 0x10` targets it.
- **The ROM runs briefly then behaves randomly:** execution reached `0xFF` fill. Find the path that leaves the program without a `hang()`.
- **`branch to <label> is N bytes away`:** a `br` exceeded +254/-256 bytes. Use `jr` for the longer hop.
- **A store appears to do nothing:** the address was misaligned for its width, or the region is write-only or unmapped. Check the table above.
- **A whole address is off by 64KB:** the code built it with `movhi`/`movea` by hand instead of `loadImm`, and did not compensate for `movea` sign-extending its immediate.
