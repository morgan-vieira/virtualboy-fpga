# virtualboy-fpga

A Nintendo Virtual Boy core for the Analogue Pocket.

## A note from morgan-vieira

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## A small glossary

We need to be on the same page with terminology. When communicating, use this language:

- **you** means the agent reading this file and helping build the core.
- **we, us, and maintainers** mean morgan-vieira and the people building this Virtual Boy core. These are who you are talking to now.
- **user** means the person using this core to play Virtual Boy ROMs on an Analogue Pocket.
- **modules** mean the individual Verilog/SystemVerilog building blocks that make up the core (e.g. video timing module, CPU module, VIP module, VSU module). Each module has a clear interface (ports) and a single main responsibility.
- **features** mean the capabilities a module needs in order to work. e.g., the VIP module needs to draw a background; the VSU module needs to produce a tone.
- **sub-features** mean the capabilities a feature needs in order to work. Drawing a background needs character memory reads and world attribute decoding.

Anything below a sub-feature is small enough to explain in a sentence, so explain it instead of naming it.

## The slow route

Modules are where this core gets built, and modules are where we refuse to rush. A module that compiles is not a module that works, and a simulation that passes is not a Pocket that boots. Every module takes the slow route, in order, every time:

1. **Prove it in simulation first.** Write a testbench and run it under Icarus Verilog before the module goes anywhere near Quartus. Exercise the ports, the edge cases, and the timing you are least sure about. Synthesis checks that a module is legal, not that it is right.
2. **Build the ROM that proves it.** Every module gets its own test ROM, built for that module's specific requirement — the video timing module gets a ROM that stresses sync and refresh, the VSU gets a ROM that plays known tones. A commercial game exercises everything at once and proves nothing in particular.
3. **Name the ROM.** When you hand a module over for testing, say exactly which ROM to load and exactly what a pass looks like on the Pocket — what should show on screen, what should come out of the speaker, and what a failure looks like instead. "Load something and see" is not an instruction.
4. **Ask for the hardware test, always.** You cannot see the Pocket's screen. Only the real bitstream on real hardware counts, and only a maintainer can watch it run. Ask for the test, wait for the verdict, and treat a clean simulation as a status update, not a conclusion. No module is done until a maintainer has watched it behave on the Pocket.

The same road, walked backwards, is how we diagnose. When a user reports a game misbehaving, resist the urge to patch the core and re-test the whole game. Isolate the symptom to a module, build or pick the test ROM that reproduces just that behavior, prove the fix in simulation, and ask for hardware again. A bug you can only reproduce inside a commercial game is a bug you have not yet found.

## Where code lives

- `src/fpga` - the Quartus project (`ap_core.qpf`/`.qsf`). `core/` is the Virtual Boy logic — start at `core_top.v`. `apf/` is Analogue's framework scaffolding; rarely what you want to edit. `output_files/` is compile output, never hand-edited.
- `src/roms/` - the source to the test ROMs, one directory per ROM. Build them with `pnpm run build:roms`; images land in the gitignored `.roms/`. The V810 assembler and ROM packer behind it live in `scripts/lib/`. Start at `src/roms/README.md`.
- `core.json`, `video.json`, `audio.json`, `data.json`, `input.json`, `interact.json`, `variants.json`, `info.txt` - APF core definition files at the repo root. Schema lives in `docs/analogue-pocket/core-definition-files.md`.
- `dist/` - the SD-card staging tree (platform metadata, assets, icon) that gets zipped with the bitstream into a release.
- `output/` - `bitstream.rbf_r`, the bit-reversed bitstream the Pocket loads. Generated from `src/fpga/output_files/ap_core.rbf` — regenerate, don't edit.
- `.claude/skills/` - one directory per skill, each a `SKILL.md`. Start at `.claude/skills/README.md`; it covers when a skill is worth adding and the voice they are written in.
- `.repos/` - vendored read-only references. Prefer their patterns over invented ones. Never edit or import from them. Sync with `pnpm run sync:repos` when bumping the matching dependency.

## Additional Tips

- When writing comments, explain why we use this approach, not what the approach is. Keep every comment under ten words. Do not state the obvious.