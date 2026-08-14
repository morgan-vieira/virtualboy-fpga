# Virtual Boy

A Nintendo Virtual Boy core for the Analogue Pocket, built on openFPGA. Verilog under `src/fpga` becomes a bitstream the Pocket loads; a small TypeScript toolchain in `scripts/` assembles the V810 test ROMs that core gets judged against.

It's early. `src/fpga/core/` is still Analogue's template plus a PLL — there's no CPU, no VIP, no VSU yet. Most of this document is about how the first real module gets built and proven, because that's the work.

## A note from morgan-vieira

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

Of note: you can't see the Pocket's screen, and neither can anything in this repo. Every claim about how the core behaves on hardware comes from a maintainer who watched it happen. Write as though someone will check.

## A small glossary

We need to be on the same page with terminology. When communicating, use this language:

- **you** means the agent reading this file and building the core.
- **we, us, and maintainers** mean morgan-vieira and the people building this core. These are who you are talking to now.
- **user** means the person using this core to play Virtual Boy ROMs on an Analogue Pocket.
- **module** means one Verilog block in `src/fpga/core/` with a clear port list and one job — video timing, CPU, VIP, VSU.
- **APF** means the Analogue Pocket Framework, Analogue's scaffolding in `src/fpga/apf/`. Our core is what sits inside it.
- **NVC** means the Virtual Boy's processor: a NEC V810 plus the on-chip peripherals around it.
- **VIP** means the video image processor — worlds, backgrounds, characters, and one image per eye.
- **VSU** means the sound unit — six channels off wavetable RAM.
- **test ROM** means a `.vb` image built from `src/roms/`, written to exercise one module and fail in one way.
- **the bitstream** means `output/bitstream.rbf_r`. Quartus emits a plain `.rbf`; APF only loads the bit-reversed one.
- **features** mean the capabilities a module needs in order to work. e.g., the VIP needs to draw a background; the VSU needs to produce a tone.
- **sub-features** mean the capabilities a feature needs in order to work. Drawing a background needs character memory reads and world attribute decoding.

Anything below a sub-feature is small enough to explain in a sentence, so explain it instead of naming it.

## The three ways to hurt yourself

1. **Reporting what you didn't watch.** A clean simulation, a clean build, and a clean Mednafen run are status updates. None of them is a working core. Say what you ran and what it proved, then ask a maintainer to run the ROM on the Pocket — and name the ROM and the pass criterion when you do.
2. **Editing generated files.** `src/fpga/output_files/` is Quartus output, `output/bitstream.rbf_r` is derived from it, and `.roms/` is built from `src/roms/`. Regenerate them, never hand-edit them. A hand-patched artifact passes review and fails on hardware.
3. **Trusting your memory over `.repos/`.** Instruction encodings, ROM layout, and timing come from the vendored references — the V810 decoder in `.repos/beetle-vb-libretro/mednafen/hw_cpu/v810/`, the linker script in `.repos/vuengine-studio/`. Read them. Never edit them, never import from them. An assembler bug and a core bug look identical from the outside.

## Prove it before it ships

A module that compiles isn't a module that works. Every module takes the same route:

- **Simulate first.** Exercise the ports, the edge cases, and the timing you're least sure about before the module goes near Quartus. Synthesis checks that a module is legal, not that it's right. A module's testbench is `src/tests/<module>.v`, it reports failure with `$fatal` or `$error`, and `pnpm run test:sim` runs it.
- **Build the ROM that proves it.** One ROM per module, written for that module's requirement. Video timing gets a ROM that stresses sync and refresh; the VSU gets one that plays known tones. A commercial game exercises everything at once and proves nothing in particular.
- **Say what a pass looks like.** What shows on screen, what comes out of the speaker, what failure looks like instead. That's the `expectation` field in the ROM spec, and it gets written before the code. "Load it and see" is not an instruction.
- **Ask for the hardware test.** Only a maintainer can watch the Pocket. Ask, wait for the verdict, and don't call the module done before it comes back.

Diagnosis is the same road backwards. When a game misbehaves, don't patch the core and replay the game. Isolate the symptom to a module, pick or build the ROM that reproduces just it, fix it in simulation, ask for hardware again. A bug you can only reproduce inside a commercial game is a bug you haven't found yet.

## Building

Node 24 and pnpm 11, then `pnpm install`. There's no toolchain to install for ROMs — the V810 assembler and packer are in `scripts/lib/`.

- `pnpm run build:roms` builds every ROM into `.roms/` and prints each one's pass criterion. `-- --rom halt` builds one.
- `pnpm run test:roms` runs the assembler's own tests against the encodings.
- `pnpm run test:sim` compiles and runs every `src/tests/*.v` testbench into `.sim/`. `--bench host_video_timing` runs one; `--timeout 5` shortens the per-bench kill. No `--` separator — pnpm forwards it literally and the flags stop parsing.
- `pnpm run format:md` and `pnpm run format:ts` format through VS Code, so they match what the editor does on save.
- `pnpm run sync:repos` refreshes `.repos/`. Only when bumping a reference.
- `quartus_sh --flow compile src/fpga/ap_core.qpf` compiles the bitstream, from the repo root. Don't chain a `cd` into that command — Quartus resolves against the changed directory and writes output somewhere else.

Quartus is Prime Lite 21.1 on morgan-vieira's machine, and Icarus Verilog 12.0 is at `C:\iverilog`. The `package-core` skill covers the compile, the bit reversal, and the SD-card tree; `build-test-rom` covers ROM layout and the Mednafen check. Read the skill before doing either by hand.

## Verifying

- Smallest proof that the change works. Touch the assembler, run `pnpm run test:roms`. Touch a ROM, build that one ROM. Touch a module, run its testbench.
- A new ROM gets checked under Mednafen before it's handed over. Mednafen parses the header with an implementation that isn't ours, which catches a mispacked image before it wastes a maintainer's afternoon.
- Don't recompile the bitstream just to package one. Reuse it when the FPGA sources haven't moved.
- There's no CI. The hardware test is the suite.

## Where code lives

- `src/fpga` - the Quartus project (`ap_core.qpf`/`.qsf`). `core/` is the Virtual Boy logic — start at `core_top.v`. `apf/` is Analogue's scaffolding, rarely what you want to edit. `output_files/` is compile output.
- `src/tests/` - one testbench per module, named for the module it exercises. Benches compile against the modules in `src/fpga/core/`.
- `src/roms/` - one directory per test ROM, each a `rom.ts`. Start at `src/roms/README.md`; it covers the image layout and why the trailer sits at the end of the file.
- `scripts/lib/` - the V810 assembler (`v810.ts`), its tests, and the ROM packer (`vb-rom.ts`).
- `core.json`, `video.json`, `audio.json`, `data.json`, `input.json`, `interact.json`, `variants.json`, `info.txt` - APF core definition files. Schema in `docs/analogue/core-definition-files.md`.
- `docs/analogue/` - Analogue's own APF documentation. `docs/technical-notes/` - notes on the V810 and Virtual Boy source documents, indexed in `INDEX.md`.
- `dist/` - the SD-card staging tree. `output/` - the packaged release and `bitstream.rbf_r`.
- `.claude/skills/` - one directory per skill, each a `SKILL.md`. `.agent/skills` and `AGENTS.md` are symlinks, so other agents read the same files.
- `.repos/` - vendored read-only references. Prefer their patterns over invented ones.

## Taste

- Comments say why, not what. Under ten words. Don't annotate the obvious.
- Name the module for what it does, not for the chip it emulates, and give the file that same name. The simulator resolves an instantiated module by looking for a file named after it.
- Hardware quirks are the spec, not a bug to smooth over. If the real hardware mirrors, wraps, or glitches, we do too — and the comment says which document says so.
- One module per change. If a fix touches the CPU and the VIP, it's two changes or it's not understood yet.
- If a rule here fights the task in front of you, say so loudly and get a maintainer's sign-off before breaking it.

## Additional tips

- Don't commit, push, or open a PR unless a maintainer asks.
- Don't verify with browsers or computer use unless asked.
- When a document and the code disagree, say so rather than picking one quietly. `docs/technical-notes/INDEX.md` already records where the sources contradict each other.
