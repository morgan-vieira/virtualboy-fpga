# virtualboy-fpga

A Nintendo Virtual Boy core for the Analogue Pocket.

## A note from morgan-vieira

I like ambitious ideas, simple systems, and software that feels obvious. Do not preserve complexity just because it already exists. Do not introduce machinery because it looks architecturally impressive. Understand the real constraint, then fight for the smallest model that makes the correct behavior unsurprising.

Channel both "measure twice, cut once" and "yagni". Fight scope creep. Try to honor the dev's intent in both a minimal and realistic fashion.

The rest of this document is meant to help you navigate the codebase and make changes effectively. Think of these instructions less as "hard rules", more as "good defaults". The developer's preferences should be able to override anything here.

## A small glossary

We need to be on the same page with terminology. When communicating, use this language:

- **you** means the agent reading this file and helping build the core.
- **we, us, and maintainers** mean morgan-vieira and the people building this core. These are who you are talking to now.
- **user** means the person using this core to play Rally-X on an Analogue Pocket.
- **modules** mean the individual Verilog/SystemVerilog building blocks that make up the core.

## The slow route

Modules are where this core gets built, and modules are where we refuse to rush. A module that compiles is not a module that works, and a simulation that passes is not a Pocket that boots.

Three tools, three jobs. **Icarus Verilog** simulates the Verilog modules. **GHDL** simulates the VHDL ones, which in practice means the T80 CPU - Icarus cannot read VHDL, so the Z80's cycle timing would otherwise be untestable. **Quartus Prime Lite 21.1** synthesises the bitstream, and is the only one of the three that produces something you can put on a Pocket. `python tools/sim.py` drives both simulators and skips the VHDL half with a note if GHDL is missing; `python tools/build.py` drives Quartus.

Every module takes the slow route, in order, every time:

1. **Prove it in simulation first.** Write a testbench and run it under Icarus Verilog - or GHDL, if the module is VHDL - before the module goes anywhere near Quartus. Exercise the ports, the edge cases, and the timing you are least sure about. Synthesis checks that a module is legal, not that it is right.
2. **Build the ROM that proves it.** Every module gets its own test ROM, built for that module's specific requirement — the video timing module gets a ROM that stresses sync and refresh, the VSU gets a ROM that plays known tones. A commercial game exercises everything at once and proves nothing in particular.
3. **Name the ROM.** When you hand a module over for testing, say exactly which ROM to load and exactly what a pass looks like on the Pocket — what should show on screen, what should come out of the speaker, and what a failure looks like instead. "Load something and see" is not an instruction.
4. **Ask for the hardware test, always.** You cannot see the Pocket's screen. Only the real bitstream on real hardware counts, and only a maintainer can watch it run. Ask for the test, wait for the verdict, and treat a clean simulation as a status update, not a conclusion. No module is done until a maintainer has watched it behave on the Pocket.

The same road, walked backwards, is how we diagnose. When a user reports a game misbehaving, resist the urge to patch the core and re-test the whole game. Isolate the symptom to a module, build or pick the test ROM that reproduces just that behavior, prove the fix in simulation, and ask for hardware again. A bug you can only reproduce inside a commercial game is a bug you have not yet found.

## Where code lives

TBD