# TODO

Every module the core needs, the features each one needs in order to work, and
the sub-features each feature needs in order to work. Ordered by the sequence I
intend to build them in.

## How to read this

- `[ ]` not started, `[~]` in progress, `[x]` watched on hardware and passed.
- A module is done when a test ROM written for it has been run on the Pocket by a
  maintainer and passed. Each module names its ROM and its pass criterion.
- **?** marks behavior the source documents do not establish, quoting where they
  say so. These are gaps in the references, not gaps in this list. Resolve them
  from the working implementations below rather than by guessing or by asking.
- **DECIDE** marks a call that belongs to a maintainer. I won't make these quietly.

Documentation traces to `docs/technical-notes/virtual-boy/vb-sacred-tech-scroll.notes.md`
unless noted; cross-document disagreements live in `docs/technical-notes/INDEX.md`.

Where the documents run out, two implementations already had to answer the question:

- `.repos/beetle-vb-libretro` — the RetroArch emulator, and the one to prefer. It
  has been corrected against a large game library over many years.
- `.repos/mister-virtualboy` — the MiSTer FPGA port. Closer to our problem shape,
  being RTL rather than C, but younger.

Take the behavior, comment which file it came from and that it's an implementation
choice rather than documented hardware, and never copy code across — `.repos/` is
read-only, and an imported bug looks exactly like a core bug from the outside.
Where the two disagree, follow beetle-vb and say so in the comment.

---

## Before the first module

Not Virtual Boy hardware, and not a module. Needed before anything can be proven.

- [x] **A way to simulate.** `pnpm run test:sim` (`scripts/run-testbenches.ts`)
      compiles every `src/tests/<module>.v` against the modules in
      `src/fpga/core/` and runs it,
      with `.vvp` programs and waveform dumps landing in the gitignored `.sim/`. It
      fails the process on `$fatal`, on a compile error, on a bench that outlives its
      timeout, and on `$error` — which Icarus reports but exits zero for, so the
      output marker is the only signal. Proven against a throwaway tree covering all
      five outcomes; no module has a testbench yet.
- [ ] **A current Quartus source list.** `ap_core.qsf` names only `core_top.v`,
      `core_bridge_cmd.v`, the PLL and the constraints today. Every new module gets
      added as it lands, and timing closure gets read rather than assumed.
      `core/host_video_timing.v` is listed. Its compile closed with every slack
      positive and TNS 0.000, at 433 ALMs and 2 RAM blocks. Stays open as a standing
      obligation, not as a task with an end.
- [ ] **DECIDE: SignalTap is on in the template.** `ap_core.qsf` carries
      `ENABLE_SIGNALTAP ON` with `core/stp1.stp` (lines 326, 327, 744), inherited from
      Analogue rather than chosen. It costs nothing today — `stp1.stp` instruments no
      signals, and the 21.1 fit report never mentions it — so this is not urgent. It
      becomes a decision the first time someone assigns a signal to it, because the
      logic analyzer's capture buffer comes out of the same block RAM that section 4
      needs. Leave it on as a debugging aid, or turn it off so the cost can never
      appear by accident.

---

## 1. Video timing

Drives pixels at the Virtual Boy's rate and hands them to the Pocket. First module
because it needs no CPU, so it can be watched failing.

### Feature: produce a 384×224 image per eye at 50 Hz

- [x] **Free-running pixel and line counters.** Nothing about this timing depends on
      the VIP or the CPU, so the counters run on their own and everything else
      eventually synchronizes to them. Now `core/host_video_timing.v`, out of
      `core_top`. Named for the host raster on purpose: the real machine scans a
      mirror on the 20 ms schedule in section 5 and produces no raster at all, so
      conflating the two would be a mistake the first time section 5 lands.
      `src/tests/host_video_timing.v` checks the raster cycle by cycle: a 384×224 data
      enable with x and y correct on every active clock, hs pulses exactly 480
      clocks apart and never on vs's clock, one vs per frame with neither sync
      inside the active window, and a measured vs-to-vs of exactly 245,760 clocks.
      Nine mutations of the module were each caught before the bench was trusted,
      three of them invisible to every per-frame count.
- [x] **Hand off to APF's scaler.** Analogue's contract is a pixel clock plus RGB,
      data-enable, hsync and vsync. Getting the polarity or the enable window wrong
      shows as a rolling or torn image rather than as a build failure.
- [x] **Settle the frame rate at exactly 50 Hz.** 12.288 MHz over 480×512 is 245,760
      clocks, which is 20 ms to the clock, so the existing PLL needs no retuning. The
      sources disagree and the disagreement is recorded rather than resolved: the
      Sacred Tech Scroll gives a fixed 20 ms / 50 Hz [VIP > Drawing and Display
      Procedures > Frame Types], beetle-vb ships `MEDNAFEN_CORE_TIMING_FPS 50.27`
      (`libretro.cpp`). We follow the document, because it is exact at this pixel
      clock and 50.27 is not. Revisit if section 8 finds audio sync cares.
- [x] **Declare the native size.** `video.json` held Analogue's sample values (320×240
      at 4:3) rather than a considered choice. It now declares 384×224 at 12:7, matching
      beetle-vb's geometry in `libretro.cpp`. APF takes width and height as plain
      integers with the aspect ratio given separately, so no letterboxing is needed.

### Feature: show one image on one screen

- [x] **Show the left eye only.** Settled by following beetle-vb, which ships 3D mode
      set to anaglyph but its anaglyph preset set to disabled — so it falls through to a
      left color of `0xFF0000` and a right color of `0x000000` (`mednafen/settings.c`).
      A black right eye contributes nothing, making the shipped default a single red
      image. Anaglyph and side-by-side stay possible later through `interact.json`, the
      way both references expose them, but nothing depends on them now.
- [ ] **Turn emission duration into intensity.** The Virtual Boy's LEDs cannot vary
      brightness; a pixel looks brighter because it emits for longer. Four shades exist
      — black plus levels A, B and C — and level C's duration is the sum of all three
      brightness registers rather than an independent value, so the mapping to LCD
      intensity is not linear in the register values.

**ROM:** none. The pattern drives itself.
**Pass criterion:** flat colour could not fail this test, so `core_top` draws a pattern
built to fail visibly. A maintainer sees a one-pixel white border on all four edges,
unbroken and never clipped; a red square outline in the middle that reads as square
rather than as a rectangle; and grey bars scrolling steadily left to right with no
break across them, no vertical roll, and no jitter. A missing or doubled border edge is
a wrong data-enable window; a rectangular square is a wrong aspect; a break across the
bars is a tear.
**Watched and passed 2026-08-14** by morgan-vieira, on the bitstream built 2026-08-11.
The Memories screenshot (`20260814_124048.png`) measured pixel-exact: 384×224 native,
the full 1,212-pixel border white with zero defects, the red outline exactly 112×112
at (136,56) with all four edges complete, and exactly four colors in the frame. The
maintainer confirmed the bars scrolled steadily with no tear, roll or jitter, and the
square read as a true square on the physical screen.

---

## 2. Memory bus

One 27-bit address space, seven devices, and the mirroring rules that games rely on.

### Feature: route an access to the right device

- [ ] **Decode the seven regions.** VIP at `0x00xxxxxx`, VSU at `0x01xxxxxx`,
      miscellaneous hardware at `0x02xxxxxx`, unmapped at `0x03xxxxxx`, cartridge
      expansion at `0x04xxxxxx`, work RAM at `0x05xxxxxx`, cartridge RAM at
      `0x06xxxxxx`, cartridge ROM at `0x07xxxxxx`.
- [ ] **Mask the address down to 27 bits.** Everything from `0x08000000` up is a
      mirror of the whole map, achieved by dropping the top five bits, which makes
      `0x07FFFFFF` the highest address that can be expressed.
- [ ] **Answer the unmapped region.** Writes into `0x03xxxxxx` do nothing and reads
      return zero — a defined behavior, not a bus fault.

### Feature: hold work RAM

- [ ] **64 KiB of storage.** It occupies the first 64 KiB of its region and mirrors
      through the rest by masking address bits 16 through 23.
- [ ] **Leave it undefined at reset.** Real hardware powers up with garbage; filling
      it with zeroes would hide bugs in any ROM that forgets to initialize.
- [ ] ? Real WRAM is pseudostatic and needs a 200 µs wait plus eight dummy reads before
      first use, with undefined behavior otherwise. Emulating the misbehavior is
      almost certainly not worth it, but the requirement is recorded here so the
      decision is deliberate.

### Feature: honor each device's access-width rules

These differ per peripheral and are an easy source of bugs that only show up in one game.

- [ ] **Miscellaneous hardware takes any width.** Its registers sit four bytes apart
      specifically so byte, halfword and word accesses all land correctly, even though
      they're documented as byte-oriented.
- [ ] **VIP registers mangle byte writes.** They expect halfwords. A byte write to an
      even address performs a halfword write using the low 16 bits of the source
      register; a byte write to an odd address performs one using the low 8 bits
      shifted left by 8. Both are well-defined and both are wrong-looking.
- [ ] **VSU accepts byte writes only.** Wider writes are undefined and every read is
      undefined, because its bus is 8 bits.
- [ ] **Round unaligned accesses down.** A halfword access ignores address bit 0 and a
      word access ignores bits 1 and 0. Nothing faults; the address just moves.

### Feature: insert cartridge wait states

- [ ] **Two waits or one, per region.** A single control register carries one bit for
      the ROM region and one for the expansion region; a clear bit means two waits and
      a set bit means one. Both start clear at reset, so the slow case is the default.
- [ ] **Feed the CPU's timing.** This is the only knob software has over memory speed,
      so it belongs in whatever the CPU uses to count bus cycles rather than sitting
      off to one side as a register that nothing reads.

**ROM:** `busmap` — writes a distinct value per region, reads it back through both the
direct address and a mirror, and checks the unmapped region reads zero.
**Pass criterion:** halts on success, spins at a distinct address per failing region.

---

## 3. NVC

The CPU: a 20 MHz V810 with Nintendo's additions, a 16-bit external bus and a
32-bit word.

### Feature: execute the integer instruction set

- [ ] **Decode all seven instruction formats.** Instructions arrive as halfwords and
      are 16 or 32 bits long, with the opcode in the top bits of the first halfword
      deciding both the format and whether a second halfword follows. In a 32-bit
      instruction the first halfword supplies the *upper* half of the word, which is
      the opposite of what reading the bytes in order suggests.
- [ ] **Provide the register file.** Thirty-two general registers with `r0` hardwired
      to zero, plus a program counter whose lowest bit is always clear. Several
      registers carry meaning to specific instructions rather than by convention:
      multiply's high word and divide's remainder land in `r30`, `JAL`'s return address
      in `r31`, and the bit string instructions take five of their operands from
      `r26` through `r30`.
- [ ] **Compute arithmetic and set flags correctly.** Multiply writes its high 32 bits
      to `r30` before writing the low half to the destination, and divide writes its
      remainder first — order matters when the destination *is* `r30`. Divide rounds
      toward zero, the remainder takes the dividend's sign, dividing by zero raises an
      exception, and dividing `0x80000000` by −1 sets overflow. Carry is left alone by
      both multiply and divide.
- [ ] **Compute bitwise and shift operations.** All of them clear overflow. Carry
      after a shift is the last bit shifted out, or cleared when the shift amount was
      zero. `ANDI` is the odd one: it sets zero but *clears* sign rather than computing
      it.
- [ ] **Load and store.** Loads sign-extend and inputs zero-extend, which is the only
      difference between them since the I/O bus is mapped onto the memory bus. Stores
      and outputs are identical in function; the byte and halfword forms write only the
      low bits of the source register.
- [ ] **Branch and jump.** Sixteen condition codes are shared with `SETF`, one of which
      always branches and one of which never does. Every target masks its lowest bit,
      because the program counter can't hold an odd address.

### Feature: execute the floating-point instructions

- [ ] **Eight operations sharing one opcode.** Add, subtract, multiply, divide,
      compare, both conversions and truncate, distinguished by sub-opcode. Conversion
      rounds to nearest while truncation rounds toward zero.
- [ ] **Reject what the hardware rejects.** Only normal reals and zero are accepted.
      NaNs, indefinites and non-zero denormals are invalid operands and raise an
      exception rather than propagating, which is the opposite of IEEE behavior a
      modern reader expects.
- [ ] **Raise one condition, not several.** Six status conditions exist in priority
      order, four of which have exception codes. When an operation satisfies more than
      one — dividing a NaN by zero, say — only the highest-priority one is processed,
      and flags land in the status word before the exception is raised.

### Feature: execute bit string instructions

- [ ] **Eight bitwise operations and four searches.** They share one opcode and are
      told apart by sub-opcode, operating on runs of bits defined by a word address, a
      bit offset and a length, with length zero valid.
- [ ] **Process one word per invocation.** This is the important part: the instruction
      updates its five operand registers and then *does not* advance the program
      counter until the whole string is done. That's what makes a multi-thousand-bit
      operation interruptible, and modelling it as one atomic step would break
      interrupt latency in a way no test ROM would catch directly.
- [ ] **Wrap at both ends of the address space.** A string running off the top of
      memory continues at the bottom and vice versa.
- [ ] **Reproduce the read-buffering artifact.** Overlapping source and destination
      only corrupts the source when the destination starts 64 or more bits after it.
      That's a consequence of buffering inside the CPU, and it's the spec.

### Feature: execute Nintendo's added instructions

- [ ] **Two standalone instructions.** Clear and set the interrupt-disable flag, each
      taking 12 cycles. They occupy the same opcodes NEC later gave to `EI` and `DI` on
      the V830, where the same operations take only 2 cycles.
- [ ] **Four extended instructions.** Multiply-halfword, bit reverse, byte exchange and
      halfword exchange. Multiply-halfword sign-extends the low *17* bits of its
      operand, not 16.
- [ ] ? One source claims byte and halfword exchange require `r0` in the unused
      register field or behavior is undefined, but no misbehavior has been observed
      either way.

### Feature: handle exceptions and interrupts

- [ ] **Three tiers that escalate.** A normal exception saves state to one register
      pair and sets a pending flag; an exception raised while that flag is set becomes
      a duplexed exception using a second register pair; an exception during *that*
      is fatal — the CPU writes the cause, status word and program counter to the
      first three words of memory and halts until reset.
- [ ] **Choose the right return address.** Some exceptions resume at the instruction
      that faulted and some at the one after it. `TRAP` and ordinary interrupts use the
      next instruction; faults, address traps, and any interrupt taken during a bit
      string instruction use the current one.
- [ ] **Accept interrupts under four conditions at once.** Interrupts are disabled by
      one flag, blocked by either pending-exception flag, and masked by level. Five
      hardware sources exist, ranked with the VIP highest and the game pad lowest, and
      accepting one raises the mask to that level plus one.
- [ ] **Check between instructions, not during.** This is why an interrupt can never
      coincide with an instruction exception, and why a pending interrupt waits for the
      current instruction — or a cache dump or restore — to finish.
- [ ] **Halt until something happens.** `HALT` stops the CPU until an interrupt is
      accepted. With everything masked it never resumes, and that's correct behavior
      rather than a hang to guard against.
- [ ] **Trap on an address.** With a breakpoint register loaded and a flag set, the CPU
      raises an exception when the program counter matches, checked before the fetch.

### Feature: cache instructions

- [ ] **Look up and fill.** One kilobyte holds 128 entries of 8 bytes each, indexed by
      seven address bits, tagged with the upper 22 and a valid bit. A miss reads memory
      and fills the entry.
- [ ] **Clear a range of entries.** Software gives a first entry and a count. Counts
      above 128 clamp, a starting entry of 128 or more does nothing at all, and
      clearing always stops at the last entry rather than wrapping.
- [ ] **Dump and restore.** The whole cache spills to a software-chosen address as 128
      eight-byte blocks followed by 128 four-byte tags, 1,536 bytes in total. Interrupts
      are postponed until it finishes. Asking for more than one of clear, dump and
      restore at once is undefined, so pick one and say which in a comment.
- [ ] ? Whether the cache is initialized by reset is not established.

### Feature: expose the system registers

- [ ] **Thirteen registers reachable only through two instructions.** They configure
      the CPU rather than holding program data. Several are read-only with fixed values
      — the processor ID, the task control word, and one whose purpose nobody knows —
      and writes to them are silently ignored rather than faulting.
- [ ] **Three registers the V810 manual doesn't document.** Nintendo appears to have
      added them. Two have unknown significance; the third returns the absolute value of
      whatever was last written to it, which is strange enough that it's worth
      implementing exactly rather than rationalizing.

### Feature: spend the right number of cycles

This is where cycle accuracy is won or lost, and where the documents run out.

- [ ] **The documented per-instruction counts.** Most instructions have a fixed figure,
      and a conditional branch costs 1 cycle untaken against 3 taken.
- [ ] **Load and store are context-dependent.** A load costs 5 cycles in isolation, 4
      immediately after another load, and 1 when it follows a long instruction it
      doesn't conflict with. A store costs 1 for the first two consecutive stores and 4
      for every consecutive store after that.
- [ ] ? **Memory latency per device is not documented.** The reference says plainly
      that "the exact latencies for reads needs to be researched," and the same for
      writes. Instruction costs are known; what a load against VIP memory versus work
      RAM versus ROM actually costs is not. This is the single largest obstacle to
      calling the core cycle-accurate.
- [ ] ? Input and output instruction costs "may be identical to" load and store costs,
      unconfirmed.
- [ ] ? The cost of entering an exception — "research is needed."
- [ ] ? Floating-point instructions have documented *ranges* with no rule for which
      case costs what. A separate document gives point values that fall inside those
      ranges but contradicts itself elsewhere; see `INDEX.md`.
- [ ] ? Bit string timing exists as a table in the V810 manual that was never carried
      into the reference.
- [ ] ? Whether a conditional branch whose displacement points at the next instruction
      still costs the full 3 cycles.

### Feature: come up in the documented reset state

- [ ] **Three registers defined, everything else undefined.** The cause register, the
      program counter and the status word have known values; every other system
      register and every program register except `r0` does not. Initializing them
      anyway would mask ROMs that depend on setting them.
- [ ] ? One table in the hardware manual gives a different reset program counter than
      the other three documents and than its own text. `INDEX.md` records it; use the
      value the majority give.

**ROMs:** `cpu-alu` (arithmetic and bitwise against known results, flags included),
`cpu-branch` (all sixteen conditions both ways), `cpu-except` (trap, illegal opcode,
zero divide, duplexed, return), `cpu-cache` (enable, clear, dump, verify the spilled
layout), `cpu-bitstring` (bitwise and search, including wrap and overlap).
**Pass criterion:** each halts on success and spins at a distinct address per failure,
readable off the screen by a maintainer.
**Blocked on:** the assembler doesn't yet encode bit strings, floating point or
compare-and-exchange. See the assembler section below.

---

## 4. VIP drawing

Builds one frame buffer. Separate module from display, because the two run
concurrently against the same memory and have separate control registers.

### Feature: draw a background world

- [ ] **Decode a world's attributes.** Thirty-two worlds of 32 bytes each, processed
      from 31 down to 0 so that lower indexes draw in front. Each carries per-eye
      enables, a type, a destination rectangle, a source position and a parallax offset
      that is subtracted for the left eye and added for the right.
- [ ] **Assemble a background from maps.** A background is 1 to 8 maps of 64×64
      characters, arranged left to right then top to bottom, with width and height
      given as powers of two. The base map index rounds *down* to a multiple of the
      total map count. Asking for more than 8 maps is documented as unintended but
      well-defined, and games can rely on it, so it gets implemented rather than
      rejected.
- [ ] **Read characters.** Each is 8×8 pixels at 2 bits per pixel packed into 16 bytes,
      spread across four tables that sit in the gaps between frame buffers. A
      contiguous mirror exists specifically so software can address all 2,048 as one
      run, and the address arithmetic goes through that mirror.
- [ ] **Apply palettes and transparency.** Pixel value 0 in a character is transparent
      and leaves the frame buffer untouched, which is why the palettes only have three
      entries. Background and object uses draw from separate palette sets even for the
      same character.
- [ ] **Handle running off the edge.** A background either repeats indefinitely or
      substitutes a designated character outside its bounds, selected by one bit.
- [ ] ? That designated character may have restrictions on which characters it can
      reach; the reference says some experimentation is in order.

### Feature: draw an h-bias world

- [ ] **Shift each row independently.** One 4-byte parameter per pixel row supplies a
      separate horizontal offset for each eye, added to that eye's source position.
- [ ] ? The right eye's offset appears to be addressed by OR-ing 2 into the left one's
      address rather than adding. If the parameter base isn't divisible by 4, the left
      offset silently serves both eyes.

### Feature: draw an affine world

- [ ] **Walk a source vector per row.** One 16-byte parameter per row gives a starting
      source coordinate in 13.3 fixed point and a per-column delta in 7.9, which is
      what makes rotation, scaling and cheap perspective possible.
- [ ] **Apply parallax to one eye only.** The sign decides which: negative applies to
      the left eye, non-negative to the right. It shifts which column's output is
      produced rather than shifting the result.
- [ ] **Require 16-byte alignment.** The VIP appears to compute some field addresses by
      OR-ing and others by adding, so a misaligned parameter base corrupts the
      following parameters. The reference marks this IMPORTANT.
- [ ] ? Which bits of parameter memory the VIP uses as scratch, and how.

### Feature: draw objects

- [ ] **Place a character anywhere.** Each of 1,024 objects is 8 bytes: a signed
      horizontal position, a parallax offset applied per eye, a vertical position,
      per-eye enables, both flips, a palette selector and a character number.
- [ ] **Serve objects in groups.** Four registers give each group's *end* index; a
      group's start is one past the previous group's end, and group 0 starts at zero.
      Objects draw in reverse from end to start, and if end is below start the walk
      wraps through object 1,023 rather than drawing nothing.
- [ ] **Cycle groups within a frame.** An internal counter starts at 3, decrements
      after each object world drawn, and wraps back to 3, so the same group can be
      drawn more than once per frame. A world with both eye enables clear is skipped
      *without* consuming a group.
- [ ] ? The vertical position field's exact range is unknown, because part of it lands
      off-screen and can't be observed.

### Feature: compose the frame buffer

- [ ] **Fill one 1×8 strip at a time.** Frame buffer memory is column-major at 2 bits
      per pixel, so one halfword is eight vertically-stacked pixels. Each strip is
      initialized to the background color, then every world from 31 down to 0 draws
      into it, then it's stored — and each location is written exactly once per frame.
- [ ] **Stop early on a control world.** A world with its end flag set terminates the
      walk, and every lower-indexed world is skipped.
- [ ] **Delay background-color changes.** A write doesn't take effect until after the
      first eight rows of the *next* frame are drawn.
- [ ] **Alternate frame buffers.** Drawing swaps between buffer 0 and 1 each pass so
      one can be displayed while the other is filled. Only the top 224 of the 256 stored
      rows are ever drawn or shown; the rest is functional memory the VIP never touches.
- [ ] ? Exactly when the active buffer toggles is unknown — "it may occur when the frame
      clock goes high."
- [ ] ? Whether buffer 0 is necessarily the default after reset.

### Feature: report drawing status and raise interrupts

- [ ] **Expose progress in eight-row groups.** Software can read which group is being
      drawn and ask for an interrupt when a chosen group starts.
- [ ] **Report overrun.** If the previous pass is still running when the next should
      start, an overtime flag sets and a separate interrupt condition fires.
- [ ] ? The flag marking the start of a row group is documented as clearing after 56 µs
      but measured persisting up to 120 µs, overrunning into the next group. The
      reference calls it unreliable for detecting progress and doesn't reconcile the
      two figures.
- [ ] ? **How long drawing actually takes is not established.** The only datum is
      roughly 2.8 ms for a frame that merely erases. Affine worlds are called out as
      unable to fill the screen without dropping frames. Everything about overrun
      behavior depends on a number nobody has measured.

**ROMs:** `vip-bg` (one normal world, known character and palette), `vip-obj` (objects
across a group boundary, both flips, parallax), `vip-affine` (rotation and scale against
a reference frame), `vip-int` (each interrupt condition raised and acknowledged alone).
**Pass criterion:** written into each ROM's `expectation` before its code is.
**Blocked on:** the on-chip versus SDRAM decision below.

---

## 5. VIP display

Ships finished frame buffers to the screen. Fixed timing, unlike drawing.

### Feature: display a frame on the 20 ms timeline

- [ ] **Follow the fixed schedule.** Every frame is 20 ms: the frame clock rises at 0,
      the left buffer displays from 3 to 8 ms, the clock falls at 10, and the right
      buffer displays from 13 to 18. This is the timing games actually synchronize
      against, and unlike drawing it's specified exactly.
- [ ] **Require both enables.** Two separate bits must be set before anything appears,
      and one of them also gates sync signals to the display servo.
- [ ] **Report which buffer is busy.** Four status bits, one per buffer, that software
      polls to work out what double-buffering is doing.
- [ ] ? There's no software-visible way to choose which buffer displays; the only
      documented handle on double buffering is to use the drawing engine.

### Feature: shape emission per column

- [ ] **Walk the column table.** Each eye has 256 entries, one consumed per four
      columns of pixels, walking from higher addresses to lower — lower addresses are
      further *right*. A lock bit freezes the pointer, which is the only way software
      can hold a column configuration still.
- [ ] **Give each column a duration and a repeat count.** Emission time is in 200 ns
      units and the repeat count multiplies it, so apparent brightness is the product of
      the two. Past roughly 128 the user can't see any further increase.
- [ ] **Cut a column short when it overruns.** If the configured brightness plus idle
      time exceeds the column's allotted window, emission stops and moves on rather
      than stretching the frame.
- [ ] ? Which entries the servo actually uses shifts frame to frame; the VIP prefers the
      middle 96 and keeps the rest as slack for the physical mirror.

### Feature: set brightness

- [ ] **Three registers for four shades.** Levels A and B are durations in 5 ns units
      set directly; level C's real duration is A plus B plus C, so writing C alone does
      not do what it looks like. A fourth register sets the idle time between pixels.

### Feature: raise display interrupts

- [ ] **Six display-side conditions.** Frame start, game start, left and right buffer
      finished, mirrors-unstable, and the drawing-overran condition shared with the
      drawing engine. All of them, and the drawing-side ones, deliver the same interrupt
      code, so the handler always has to read the pending register to find out why.
- [ ] **Latch pending regardless of enable.** A condition sets its pending bit whether
      or not it's enabled; the interrupt only fires when both the enable and the pending
      bit are set. Software acknowledges through a separate write-only register.

**Pass criterion:** with the CPU halted and a hand-filled frame buffer, a maintainer
sees a stable image at the right brightness on the Pocket.

---

## 6. Timer

### Feature: count down at a selectable rate

- [ ] **Tick every 20 µs, always.** An internal counter advances modulo 5 whether or not
      the timer is enabled. One control bit decides whether the user-visible counter
      decrements on every tick or only when that internal counter wraps, giving 20 µs
      or 100 µs.
- [ ] **Reload on write, not just on zero.** Writing either half of the counter sets
      the reload value, loads the whole 16-bit value into the counter *and* restarts the
      current tick interval. Reads return the live counter, which is why software is
      told to stop the timer before reading it.
- [ ] **Decrement on a rate change.** Switching from the slow rate to the fast one while
      the internal counter is non-zero decrements immediately, which can itself fire the
      interrupt.
- [ ] ? The hardware may actually initialize its internal counter to 4 and count down
      rather than up.

### Feature: raise the zero interrupt

- [ ] **Fire on the transition, not the state.** Any change from non-zero to zero
      qualifies, including one caused by a write to the reload registers — but the timer
      loading a reload value of zero does not.
- [ ] **Acknowledge through two paths that interact.** A status bit stays set while the
      counter is zero and the timer is enabled. Clearing it acknowledges the interrupt,
      except that disabling the timer and clearing in the same write disables it without
      clearing the status.
- [ ] **Start with the counter and reload disagreeing.** Reset leaves the counter at
      `0xFFFF` and the reload at zero — the only moment the two can differ, since any
      write to either makes them equal.

**ROM:** `timer` — a known interval counted against the VIP's 50 Hz frame.
**Pass criterion:** an on-screen counter advances at the expected rate relative to
display frames.

---

## 7. Game pad

### Feature: report button state

- [ ] **Sixteen bits in a documented order.** Two four-way pads, six buttons, select and
      start, plus a signature bit that a standard controller always sets and a
      low-battery bit. The bit order is not the order anyone would guess, so it comes
      from the table rather than from intuition.
- [ ] **DECIDE: controller mapping.** The Virtual Boy has two D-pads; the Pocket has one
      plus a face-button cluster. `input.json` needs a mapping and it changes how games
      play. Maintainer's call.

### Feature: clock the state out

- [ ] **A hardware read that takes 512 µs.** Started by one bit, it clocks buttons at
      31.25 kHz, reports busy while running, and can be aborted mid-flight by another
      bit.
- [ ] **A software read that's faster.** Software latches, then toggles a clock bit
      itself — and the bit it writes is inverted on the way to the pad.
- [ ] ? The reference describes the software read as both "16 times" and "33 writes" and
      doesn't reconcile them.
- [ ] ? Real hardware returns unstable data if software clocks too fast in humid
      conditions, which games worked around with a dummy multiply between bits.

### Feature: raise the key interrupt

- [ ] **A condition a standard controller can never satisfy.** It fires if any of the
      top twelve bits is set, but is suppressed if any of three low bits is set — and
      the signature bit sits in that suppressing range and is always set. Implement the
      rule as written; a non-standard controller could still trigger it.

**ROM:** `pad` — display the raw 16-bit word.
**Pass criterion:** each physical button toggles exactly its documented bit and no others.

---

## 8. VSU

Six channels mixed to 10-bit stereo at 41,700 Hz.

### Feature: produce a tone from wavetable memory

- [ ] **Five 32-sample tables.** Samples are 6-bit unsigned, stored four bytes apart,
      and writable only with byte stores. The upper two bits of each written byte are
      discarded.
- [ ] **Write them only when everything is silent.** Wave memory can be written only
      while *all* channels including noise are inactive; writes during playback are
      dropped. Selecting a table index above the fifth makes the channel play silently
      while still blocking writes, which is a trap worth reproducing.
- [ ] **Turn a frequency value into a delay.** The channel waits 2,048 minus the
      frequency value in base clocks, at 5 MHz for the wavetable channels. Higher values
      mean higher pitch, which is backwards from how it reads.
- [ ] **Keep two frequency values.** One is what software last wrote, the other is what
      playback is using. Register writes update both; sweep and modulation update only
      the second. Software that writes only one of the two frequency registers can
      therefore end up with a value it didn't intend.
- [ ] **Play for a fixed time and stop.** A channel can be told to disable itself after
      an interval measured in units of about 3.84 ms.
- [ ] **Reset six things on a channel write.** Writing the channel's control register
      restarts the frequency delay, the wave position, the envelope step timer, the
      frequency-modification timer, the modulation position and the noise shift
      register, all at once.

### Feature: shape amplitude with the envelope

- [ ] **Step up or down once per interval.** One direction bit and an interval in units
      of about 15.36 ms; the level clamps at 15 and at 0 rather than wrapping.
- [ ] **Optionally reload and continue.** With repeat set, the envelope holds at its
      limit for one interval, reloads the initial value for one interval, and resumes.
- [ ] **Require a non-zero level for any sound at all.** Even with automatic
      modification disabled, a zero envelope is silence.
- [ ] ? A channel enabled with the envelope active emits zero samples for the first 5 to
      10 ms; the reference doesn't know why or whether it's consistent.

### Feature: sweep and modulate channel 5

- [ ] **Slide the pitch, or drive it from a table.** One bit chooses between sweep,
      which shifts the current frequency right and adds or subtracts the result to slide
      along octaves, and modulation, which adds a signed value from a 32-entry table to
      the last-written frequency and keeps 11 bits.
- [ ] **Compute ahead, apply behind.** The new value is calculated at the start of a
      modification frame and applied only after that frame's audio is generated.
- [ ] **Stop the channel on overflow — even when disabled.** A calculated value above
      2,047 kills channel 5 immediately, and a hardware bug means this happens whether
      or not the sweep function is enabled. Because the check runs at the frame start, it
      also makes the highest valid frequency unusable. This is the spec, not a defect to
      smooth over.
- [ ] **Honor a mid-frame interval change conditionally.** A newly written interval
      takes effect immediately only if that much time hasn't already elapsed in the
      current frame; otherwise the frame finishes on the old interval.

### Feature: produce noise

- [ ] **A 15-bit shift register with a selectable tap.** Each sample XORs a fixed bit
      with the tapped bit, inverts, shifts left and inserts the result. Eight tap
      choices give sequence lengths from 28 to 32,767, so the tap is a timbre control
      rather than a frequency control.
- [ ] **Emit only two values.** A generated 0 becomes sample 0 and a 1 becomes 63, so
      the channel matches the others' 6-bit width. Its base clock is 500 kHz, a tenth of
      the other channels'.
- [ ] **Clear on either of two writes.** Both the channel control register and the
      envelope register reset the shift register to all zeroes.

### Feature: mix to stereo output

- [ ] **Scale each channel in a specific order.** Multiply the 4-bit stereo level by the
      4-bit envelope level, keep the top five bits of the result, add one if neither
      input was zero, then multiply by the 6-bit sample. The add-one step is what keeps
      quiet channels audible and it only applies conditionally.
- [ ] **Sum and truncate.** Add all six 11-bit channel outputs and keep the top 10 bits
      of the 14-bit sum. Inactive channels contribute zero and the maximum output is 685.
- [ ] **Stop everything on request.** One register disables all active channels; clearing
      it does nothing and channels can restart without clearing it.

### Feature: deliver audio to the Pocket

- [ ] **Apply the output filter.** Real hardware blocks DC through an RC circuit that
      works out to a first-order high-pass at about 7.234 Hz, and the reference gives the
      discrete form directly.
- [ ] **Resample 41,700 Hz to what APF expects.** The Virtual Boy's rate isn't one the
      Pocket's audio path takes natively.
- [ ] ? The VSU's reset state isn't verified. The reference only suggests using the stop
      register on boot.

**ROMs:** `vsu-tone` (a known frequency on one channel), `vsu-noise` (each of the eight
taps in turn).
**Pass criterion:** a maintainer hears the stated pitch, for the stated duration, in the
stated ear. Silence and wrong-pitch are distinguishable failures.

---

## 9. Game pak

### Feature: serve cartridge ROM

- [ ] **Take the image from the APF dataslot.** The Pocket hands the core a `.vb` file;
      the core has to present it as a memory region.
- [ ] **Mirror by masking.** Every commercial cart is a power of two in size, and
      addresses past the end have their upper bits masked, which is exactly why the
      header and vectors sit at the very top of the address space and land correctly for
      any ROM size.

### Feature: serve save RAM

- [ ] **Mirror the same way.** Cartridge RAM is also a power of two and also masks.
- [ ] **Persist through a nonvolatile data slot.** Settled from
      `docs/analogue/core-definition-files/data-json.md`. A second slot in `data.json`
      marked `nonvolatile` is read back onto the file it came from when the core shuts
      down — on Quit, on power off, and on sleep. Its size comes from the dataslot
      size table in the core rather than from the JSON.
- [ ] **Name the save after the ROM.** Parameters bit 2 clones the filename from slot 0
      and appends this slot's extension, which is what turns `Game.vb` into `Game.sav`
      without the core knowing anything about filenames.
- [ ] **Fill a fresh save with `0xFF`.** Parameters bit 5 overwrites the slot with
      `0xFF` up to its maximum size when no save file exists yet, which matches an
      erased SRAM chip. Leaving it clear writes nothing at all, so a first boot would
      read whatever the FPGA powered up with.
- [ ] **Leave the read-only bit clear** (bit 3), or the file never gets written.
- [ ] Note that `core.json` sets `sleep_supported: false` today, so the sleep flush
      doesn't apply to us yet — quit and power-off do.

### Feature: accept a cartridge interrupt

- [ ] **Wire the path and generate nothing.** Carts can request an interrupt; no
      commercial cart does. The expansion region is likewise unused by every commercial
      cart and decodes to nothing.

**ROM:** the existing `halt` already exercises header parsing end to end.

---

## 10. Link port

Last, and possibly never — no commercial game used it, and the cable was never sold to
consumers. `core.json` declares no link port today; leave it that way.

### Feature: exchange a byte with another unit

- [ ] Eight bits at 50 kHz each, 160 µs total, uncancellable once started, with a
      selectable internal or external clock. Starting with the internal clock and no peer
      completes immediately and leaves the received data undefined.

### Feature: negotiate status out of band

- [ ] An auxiliary signal whose value each unit sees as the AND of both units' outputs.
      With no peer attached, the hardware behaves as though a peer existed with identical
      settings, so this can't be used to detect a connection.

### Feature: raise the communication interrupt

- [ ] Two independent sources — transfer complete and auxiliary-signal match — share one
      interrupt code and must be acknowledged separately.

---

## Assembler work these ROMs imply

`scripts/lib/v810.ts` covers the base integer set, which is enough for `halt` and would
be enough for the bus and video ROMs. The CPU ROMs need more. Encodings come from the
decoder in `.repos/beetle-vb-libretro/mednafen/hw_cpu/v810/` — opcode numbers in
`v810_opt.h`, field layout and semantics in `v810_oploop.inc` — never from memory, with
expected halfwords worked out by hand in the same commit rather than derived from the
assembler.

- [ ] The bit string group, twelve sub-opcodes under one opcode
- [ ] The floating-point group, eight sub-opcodes
- [ ] Nintendo's four extended instructions
- [ ] Compare-and-exchange

---

## Open decisions

Collected from above, split by whether a reference can answer them.

### Answerable from the implementations — I'll decide, not ask

1. **On-chip versus SDRAM** for the 320 KiB of VIP and work RAM state — **decided:
   on-chip, with cartridge ROM in SDRAM.** MiSTer keeps VIP working memory on-chip in
   M10K (`rtl/VIP/vip_render_storage.sv` forwards same-address writes rather than
   relying on M10K collision mode, which only makes sense for block RAM) and pushes
   cartridge ROM out to SDRAM and DDR (`rtl/Mem/vb_cart_sdram.sv`, `rtl/Mem/ddram.sv`).
   The Pocket's budget allows the same split, but not with much room — see below.
2. **Controller mapping** for two D-pads. MiSTer already maps a Virtual Boy pad onto
   a conventional controller; take its layout as the default and let `input.json`
   remap. Blocks section 7.

### Settled

3. **Stereo presentation** — left eye only, red on black, matching beetle-vb's shipped
   default. Recorded in section 1.
4. **`video.json` scaler mode** — 384×224 at 12:7, matching beetle-vb's geometry.
   Already changed.

5. **Save RAM persistence** — a nonvolatile data slot in `data.json`, flushed on core
   shutdown. Recorded in section 9.

6. **The Pocket's block RAM budget** — measured, and it is the tightest constraint on
   this project.

   The device is `5CEBA4F23C8`, named in `src/fpga/ap_core.qsf`. Per
   `src/fpga/output_files/ap_core.fit.summary`, it carries 3,153,920 block memory bits
   in 308 M10K blocks, 18,480 ALMs, 66 DSP blocks and 4 PLLs. The template as it stands
   uses 2 memory blocks, 412 ALMs and 1 PLL — and all 224 pins, though nothing we build
   needs I/O.

   The Virtual Boy needs 256 KiB of VIP memory plus 64 KiB of work RAM. That is
   2,621,440 bits, or **exactly 256 of the 308 blocks — 83%**, leaving 52 blocks for
   the CPU's instruction cache, the APF framework and every buffer we haven't thought
   of yet.

   Two cautions on that number. It assumes perfect packing, and real designs never
   achieve it: port widths and dual-port requirements push actual block counts above
   the theoretical minimum, so 256 is a floor rather than an estimate. And the four
   frame buffers alone are 77 blocks of the 256, which makes them the obvious thing to
   move to SDRAM if the fit gets tight — at the cost of a much harder VIP.

   **Verdict:** proceed on-chip as decided in 1, but treat block RAM as the scarce
   resource throughout section 4, and check the Fitter summary after every VIP module
   rather than at the end.
