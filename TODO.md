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
Where the two disagree, follow beetle-vb and say so in the comment — except for
cycle counts, where MiSTer carries hardware-measured Cycle Test figures that
beetle-vb lacks, and is checked first (Morgan, 2026-08-17). Deviations that no
source resolves at all are collected in `CAVEATS.md`.

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
      five outcomes; the suite now runs 14 module benches.
- [ ] **A current Quartus source list.** Every new module gets added as it lands,
      and timing closure gets read rather than assumed.
      `core/host_video_timing.v` is listed. Its compile closed with every slack
      positive and TNS 0.000, at 433 ALMs and 2 RAM blocks. Stays open as a standing
      obligation, not as a task with an end.
      `core/mem_bus.v`, `core/cpu.v`, `core/cart_rom.v`,
      `core/cpu_clock_enable.v` and `core/timer.v` are listed too — the
      SystemVerilog ones as `SYSTEMVERILOG_FILE`, new RTL being SystemVerilog
      by Morgan's call (2026-08-14). The full-core compile closes with every slack positive and
      TNS 0.000 in all corners: 3,006 ALMs (16%), 130 RAM blocks (42%), 3 DSPs,
      with the CPU domain at 133.12 MHz. The 0.4.0 compile (timer landed,
      `SEED 2` after 3/4/5 each failed setup by 0.3–0.6 ns) closes at 3,207
      ALMs (17%), 130 RAM blocks, worst-case setup slack +0.020 ns with TNS
      0.000 in all corners — the seed lottery that motivated the per-CE
      rebuild decided in section 3. The 0.5.0 compile (the rebuild: CPU
      domain at 39.936 MHz, qsf back to `OPTIMIZATION_MODE BALANCED` and
      `SEED 1`) closes at 3,121 ALMs (17%), 130 RAM blocks, 3 DSPs, with
      every category's worst-case slack positive in all corners — setup
      +2.280 ns, hold +0.161, recovery +17.045, removal +1.304 — on the
      first and only seed. The lesson still baked into the code: a compile
      once hit 16.6k ALMs and a silent miscompile from per-call-site
      register-file access and Quartus 21.1 dropping module-scope reads
      inside automatic functions; `cpu.v` keeps every function pure and the
      register file at one read site and one write port, and the map report
      gets grepped for "assigned a value but never read" after every
      compile (0.5.0: only Analogue's template scratch registers). The
      other 133 MHz-era lesson — that closing that domain took predecode
      stages, a two-stage shifter, and registered bus command and answer —
      is history the rebuild deleted; cpu.v's header says why those stages
      must not come back.
      The completed VSU build on 2026-08-16 also closes every timing category:
      6,659 ALMs (36%), 2,498,560 RAM bits (79%), 306 of 308 RAM blocks
      (99%), 14 DSPs (21%), and worst setup slack +0.150 ns. The source list
      now includes the implemented CPU, VIP, timer, VSU, audio and memory path;
      this item remains open only as the standing obligation described above.
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
- [~] **Turn emission duration into intensity.** The Virtual Boy's LEDs cannot vary
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

- [x] **Decode the seven regions.** VIP at `0x00xxxxxx`, VSU at `0x01xxxxxx`,
      miscellaneous hardware at `0x02xxxxxx`, unmapped at `0x03xxxxxx`, cartridge
      expansion at `0x04xxxxxx`, work RAM at `0x05xxxxxx`, cartridge RAM at
      `0x06xxxxxx`, cartridge ROM at `0x07xxxxxx`. Now `core/mem_bus.v`: a
      halfword bus, one-hot selects off `addr[26:24]`, matching both MiSTer's
      `vb_vue_addr_decode` and beetle-vb's `switch(A >> 24)` (`libretro.cpp`).
      Devices answer the cycle after their select, the shape block RAM gives.
- [x] **Mask the address down to 27 bits.** Everything from `0x08000000` up is a
      mirror of the whole map, achieved by dropping the top five bits, which makes
      `0x07FFFFFF` the highest address that can be expressed. Structural in
      `mem_bus`: the port is `addr[26:1]`, so the mask is the wire count, the same
      way MiSTer's `vue.v` takes `a_i[26:1]`. Proven for real when the CPU's
      address port connects.
- [x] **Answer the unmapped region.** Writes into `0x03xxxxxx` do nothing and reads
      return zero — a defined behavior, not a bus fault. `mem_bus` parks its answer
      mux on this region at reset, so rdata is zero out of reset too.

### Feature: hold work RAM

- [x] **64 KiB of storage.** It occupies the first 64 KiB of its region and mirrors
      through the rest by masking address bits 16 through 23. In `mem_bus`, as two
      byte arrays so byte-lane writes infer block RAM byte enables.
- [~] **Leave it undefined at reset.** Real hardware powers up with garbage; filling
      it with zeroes would hide bugs in any ROM that forgets to initialize. The
      bench asserts an unwritten read is x, so initialization can't creep in.
- [ ] ? Real WRAM is pseudostatic and needs a 200 µs wait plus eight dummy reads before
      first use, with undefined behavior otherwise. Emulating the misbehavior is
      almost certainly not worth it, but the requirement is recorded here so the
      decision is deliberate.

### Feature: honor each device's access-width rules

These differ per peripheral and are an easy source of bugs that only show up in one game.

- [~] **Miscellaneous hardware takes any width.** Its registers sit four bytes apart
      specifically so byte, halfword and word accesses all land correctly, even though
      they're documented as byte-oriented. Lands with the misc register block, not
      the bus — the bus only routes the region. In `core/timer.v` for its three
      registers (byte lane 0 carries the register, the block mirroring every 0x100
      the way beetle-vb decodes `A & 0xFF`), watched per width by the `timer` ROM's
      check 4; the keypad registers extend the same shape when they land.
- [~] **VIP registers mangle byte writes.** They expect halfwords. A byte write to an
      even address performs a halfword write using the low 16 bits of the source
      register; a byte write to an odd address performs one using the low 8 bits
      shifted left by 8. Both are well-defined and both are wrong-looking. Lands in
      the VIP: on this bus a byte write is a halfword access with one byte lane, so
      the mangling is the VIP's reaction to lanes, not the bus's.
- [x] **VSU accepts byte writes only.** Wider writes are undefined and every read is
      undefined, because its bus is 8 bits. `mem_bus` already answers VSU reads
      with zero, following beetle-vb (`MemRead16` falls through); `vsu.v` accepts
      either byte lane, ignores address bit 1, and accepts only the first half of
      a word write, matching the observed hardware/MiSTer quirk.
- [x] **Round unaligned accesses down.** A halfword access ignores address bit 0 and a
      word access ignores bits 1 and 0. Nothing faults; the address just moves.
      Structural: bit 0 never leaves the CPU (`addr[26:1]`), and a word access is
      two halfword bus cycles, so the CPU's bus unit owns bit 1.

### Feature: insert cartridge wait states

- [~] **Two waits or one, per region.** A single control register carries one bit for
      the ROM region and one for the expansion region; a clear bit means two waits and
      a set bit means one. Both start clear at reset, so the slow case is the default.
      Note beetle-vb reads WCR back as `WCR | 0xFC` — the unused bits read as ones.
      Now in `cpu.v` (writes to `0x02000024` snooped, reads intercepted with the
      `| 0xFC` readback), proven in simulation by the bench's WCR timing span;
      the readback watched both ways via `cpu-except` (2026-08-14). The wait
      counts themselves stay sim-proven until a timebase exists.
- [~] **Feed the CPU's timing.** This is the only knob software has over memory speed,
      so it belongs in whatever the CPU uses to count bus cycles rather than sitting
      off to one side as a register that nothing reads. Deliberately absent from
      `mem_bus` for that reason; MiSTer does the same, keeping waits in
      `vb_vue_wait_control` beside the CPU's READY pin rather than in the decode.
      `region_wait` in `cpu.v` is exactly that: waits charged into the cycle
      budget, per fetch halfword and per data access.

**ROM:** `busmap` — writes a distinct value per region, reads it back through both the
region mirror and the 27-bit-space mirror, checks unmapped/VSU/expansion read zero,
and walks the byte lanes. Built, checked under Mednafen, and passing in simulation
against the CPU (`src/tests/cpu.v` runs the image to its success halt). Reports
through the status convention in `src/roms/README.md`.
**Pass criterion:** the on-screen status cells read `0x600D` with the halt square
filled; a failure shows the failing check's number instead.
**Watched and passed 2026-08-14** by morgan-vieira on the 0.2.1 bitstream
(screenshot `20260814_153229.png`): status `0x600D`, square filled, and the PC
row reading exactly `busmap`'s computed halt address `0x07000144`. The
access-width and wait-state features stay open — they belong to devices and
CPU timing that don't exist yet. Simulation-side proof is
`src/tests/mem_bus.v`: selects one-hot per region at both region ends, every device
answer routed back the cycle after its access, zero from VSU/unmapped/expansion
reads, work RAM written and read back through mirrors and byte lanes, untouched by
foreign-region traffic and by reads, and x before the first write. Reads drive live
byte lanes and junk wdata so only `we` may gate a write, and a back-to-back run
holds req across five consecutive accesses — a store loaded back the very next
cycle, answers crossing three region switches — because a CPU fetching sequentially
never idles the bus. Seven mutations were each caught before the bench was trusted,
one of them (a write committing a cycle late) invisible to every check that idles
between accesses.
A standalone Quartus 21.1 synthesis of the module confirmed the intent rather than
assuming it: both byte arrays inferred as `altsyncram` block RAM, 524,288 bits
total, old-data collision mode, 70 logic cells for the decode and mux — and
`addr[23:16]` reported as driving nothing, which is the work RAM mirror mask
visible in synthesis. Fit and timing still belong to the first full compile that
instantiates the module.

---

## 3. NVC

The CPU: a 20 MHz V810 with Nintendo's additions, a 16-bit external bus and a
32-bit word.

**Slice 1 landed as `core/cpu.v`**: a multicycle machine over `mem_bus` — no
pipeline, no cache, no prefetch, no cycle accuracy (its `ce` port is where the
20 MHz-average enable lands when that feature does; tied high until then).
Proven by `src/tests/cpu.v` — nine directed scenarios on hand-encoded programs
generated by the repo's assembler, plus the `cpu-alu`, `cpu-branch` and
`busmap` images run to their success halts — and by eight deliberate mutations
of the module (flag polarity, r30 write order, branch base PC, load sign
extension, interrupt level compare, ANDI extension, RETI pair choice, shift-
by-zero carry), each caught by a distinct check before the bench was trusted.
**Watched and passed 2026-08-14** by morgan-vieira on the 0.2.1 bitstream:
`cpu-alu`, `cpu-branch` and `busmap` each showed the filled halt square with
status `0x600D` (screenshots `20260814_153152/153206/153229.png`), and each
PC row matched its ROM's computed halt address exactly — `0x07000806`,
`0x070002F0`, `0x07000144` — so the screens are authenticated, not just
plausible. **Re-watched and passed 2026-08-14** on the 0.3.0 bitstream — the
cycle-accurate rework in the 133 MHz domain — alongside `cpu-except`
(screenshots `20260814_201316/201329/201350/201414.png`), every PC row again
matching its computed halt address, `cpu-except`'s being `0x070001E0`.
Interrupts wait on the first source, the timer; the cycle counts wait on a
timebase.

**DECIDED (morgan-vieira, 2026-08-14): slice 3 is a per-CE rebuild.** The
133 MHz multicycle domain closes timing by seed lottery — landing the timer's
irq materialized the CPU's interrupt-accept cone, previously constant-folded
away behind the tied-low port, and three seeds left the exception-restore
paths 0.3–0.6 ns short. MiSTer proves the whole machine in one ~40 MHz domain
with a 20 MHz clock enable and a per-CE pin-level V810
(`rtl/NECv810/NECv810.sv`), trading CPU complexity for triple the timing
budget — and its microstructure is *more* faithful than our budget-charging
approximation, not less. The rebuild reimplements that shape (pattern, never
code) after the timer ships on the current domain: core domain moves to a
same-VCO ~40 MHz output (the drift-free video lock holds at any same-VCO
ratio; 39.936 MHz gives a 625/1248 enable), `timer.v` carries over untouched
since it counts ce ticks, and the existing bench suite plus all five ROMs are
the acceptance bar. This lands before the VIP, so the VIP is designed for the
domain it will live in.

**Slice 3 landed 2026-08-15 as the 0.5.0 rebuild of `cpu.v`.** The domain is
the PLL's C2 output re-solved to 39.936 MHz (the fit chose VCO 638.976 with
C0=52, C2=16 — a 13:4 ratio against video, so the 625/1248 enable is exact),
and the machine the same architecture minus every 133 MHz retiming
stage: no predecode pipeline, no two-stage shifter, no registered bus answer
or command — decode, register read, execute and writeback close
combinationally in the 25 ns cycle, and the walk between executes shrank to
at most five clocks. The budget ledger carried over unchanged (`owed`,
charged at execute, drained per tick, execute barred until empty) because
the bench's eleven measured spans are the spec; one deviation from the
decision as written, recorded in `cpu.v`'s header: bus requests ride the
fast clock rather than the ticks, because a strictly tick-gated two-request
fetch cannot fit a charge-2 instruction followed by a 32-bit one — the
accumulator is what keeps the spans exact, and the walk-inside-drain margins
that make it sound are derived there, including the two adjacent-clock
enables per 1248 the new ratio brings. `timer.v`, `mem_bus.v` and
`cart_rom.v` carried over untouched as decided; `ap_core.qsf` dropped
HIGH PERFORMANCE EFFORT and the seed back to defaults, since closing without
them is the point. Proven by the full bench suite at the new ratio, with the
`cpu` bench additionally swept across six enable phases (both adjacency
positions included) and every timing span exact at each.

**Watched and passed 2026-08-15** by morgan-vieira on the 0.5.0 bitstream,
all six ROMs (screenshots `20260815_094942`–`095104.png`), every frame
measured pixel-exact at 384×224 native with four colours and an intact
border. The five halting ROMs each showed the filled square with the PC
row matching its image's computed halt address: `halt` status `0xBEEF` at
`0x07000014` (derived from its 22-byte layout, now on record), `busmap`
`0x600D` at `0x07000144`, `cpu-alu` `0x600D` at `0x07000806`, `cpu-except`
`0x600D` at `0x070001E0`, and `cpu-branch` `0x600D` at `0x070002DC` — a
different address than the `0x070002F0` in the earlier record because the
ROM's bytes have shifted since that build: in today's hex the `0x600D`
immediate sits at `0x2D4` and the success halt at `0x2DA`, so the screen
matches today's image exactly. The `timer` frame showed the hollow square,
the PC row inside the display loop at `0x07000210`, and status `0x000B` —
eleven seconds after its boot, consistent with the session's screenshot
timeline. The once-per-second cadence — the one claim a still image
cannot carry — was watched and confirmed by morgan-vieira (2026-08-15),
which closes the whole 0.5.0 acceptance bar: the engine swap is done, and
the VIP gets built directly in this domain.

### Feature: execute the integer instruction set

- [~] **Decode all seven instruction formats.** Instructions arrive as halfwords and
      are 16 or 32 bits long, with the opcode in the top bits of the first halfword
      deciding both the format and whether a second halfword follows. In a 32-bit
      instruction the first halfword supplies the *upper* half of the word, which is
      the opposite of what reading the bytes in order suggests. Format VII decodes
      only as far as the illegal-opcode stand-in below.
- [~] **Provide the register file.** Thirty-two general registers with `r0` hardwired
      to zero, plus a program counter whose lowest bit is always clear. Several
      registers carry meaning to specific instructions rather than by convention:
      multiply's high word and divide's remainder land in `r30`, `JAL`'s return address
      in `r31`, and the bit string instructions take five of their operands from
      `r26` through `r30`. Flops, undefined at reset like the real part; the
      bit-string roles of `r26`–`r29` wait for that feature.
- [x] **Compute arithmetic and set flags correctly.** Multiply writes its high 32 bits
      to `r30` before writing the low half to the destination, and divide writes its
      remainder first — order matters when the destination *is* `r30`. Divide rounds
      toward zero, the remainder takes the dividend's sign, dividing by zero raises an
      exception, and dividing `0x80000000` by −1 sets overflow. Carry is left alone by
      both multiply and divide. Multiply is the `*` operator (the Pocket's DSP
      blocks sit unused; no reason to dodge them), divide a 32-step restoring loop.
- [x] **Compute bitwise and shift operations.** All of them clear overflow. Carry
      after a shift is the last bit shifted out, or cleared when the shift amount was
      zero. `ANDI` is the odd one: it sets zero but *clears* sign rather than computing
      it — which falls out of the zero-extended operand, and `cpu.v` says so.
- [x] **Load and store.** Loads sign-extend and inputs zero-extend, which is the only
      difference between them since the I/O bus is mapped onto the memory bus. Stores
      and outputs are identical in function; the byte and halfword forms write only the
      low bits of the source register.
- [x] **Branch and jump.** Sixteen condition codes are shared with `SETF`, one of which
      always branches and one of which never does. Every target masks its lowest bit,
      because the program counter can't hold an odd address. The branch base is the
      branch's own address, which one bench mutation specifically pinned.

### Feature: execute the floating-point instructions

- [x] **Eight operations sharing one opcode.** Add, subtract, multiply, divide,
      compare, both conversions and truncate, distinguished by sub-opcode. Conversion
      rounds to nearest while truncation rounds toward zero. Landed as
      `core/cpu_fpu.v` (2026-08-17): round-to-nearest-even throughout, semantics
      matched to beetle-vb's softfloat including the hardware-observed overflow
      that wraps the exponent by -192 and still writes the result. Proven by
      `src/tests/cpu_fpu.v`'s vector suite and the `cpu-float` ROM in simulation.
- [x] **Reject what the hardware rejects.** Only normal reals and zero are accepted.
      NaNs, indefinites and non-zero denormals are invalid operands and raise an
      exception rather than propagating, which is the opposite of IEEE behavior a
      modern reader expects. In: the reserved-operand check runs before any
      arithmetic, and a result below the normal range flushes to a signed zero
      with FUD and FPR (the scroll and beetle-vb, against the manual's denormal
      claim — INDEX.md records it).
- [x] **Raise one condition, not several.** Six status conditions exist in priority
      order, four of which have exception codes. When an operation satisfies more than
      one — dividing a NaN by zero, say — only the highest-priority one is processed,
      and flags land in the status word before the exception is raised. In, and
      benched: FRO outranks FIV outranks FZD, flags committed the clock before
      EXC_ENTER reads the PSW.

### Feature: execute bit string instructions

- [x] **Eight bitwise operations and four searches.** They share one opcode and are
      told apart by sub-opcode, operating on runs of bits defined by a word address, a
      bit offset and a length, with length zero valid. Landed in `cpu.v`
      (2026-08-17), proven by the bench's string scenarios and the
      `cpu-bitstring` ROM in simulation. Two places beetle-vb and the documents
      part ways, and the documents win with a comment saying so: downward
      searches cross words whole (beetle crosses one bit early), and the search
      pointer lands one bit before a find (the scroll's "next bit following"
      disagrees; INDEX.md records both).
- [x] **Process one word per invocation.** This is the important part: the instruction
      updates its five operand registers and then *does not* advance the program
      counter until the whole string is done. That's what makes a multi-thousand-bit
      operation interruptible, and modelling it as one atomic step would break
      interrupt latency in a way no test ROM would catch directly. Implemented
      exactly that way: each invocation computes one destination word (or scans
      one source word), writes r26-r30 back, and leaves PC on itself, so FETCH1's
      ordinary interrupt check services the string with restore at current PC.
- [x] **Wrap at both ends of the address space.** A string running off the top of
      memory continues at the bottom and vice versa. Structural — the descriptor
      registers are full 32-bit values — and pinned both directions by
      `cpu-bitstring`'s wrap checks through the top of ROM and VIP word zero.
- [x] **Reproduce the read-buffering artifact.** Overlapping source and destination
      only corrupts the source when the destination starts 64 or more bits after it.
      That's a consequence of buffering inside the CPU, and it's the spec. The
      buffer is two source words topped up before each destination write, which
      lands the artifact exactly at the documented distance — beetle-vb's
      single-word cache corrupts already at +32, so its Mednafen run freezes at
      `cpu-bitstring` check 8 by design.

### Feature: execute Nintendo's added instructions

- [~] **Two standalone instructions.** Clear and set the interrupt-disable flag, each
      taking 12 cycles. They occupy the same opcodes NEC later gave to `EI` and `DI` on
      the V830, where the same operations take only 2 cycles. The flag behavior is in;
      the 12 cycles belong to the timing feature below.
- [x] **Four extended instructions.** Multiply-halfword, bit reverse, byte exchange and
      halfword exchange. Multiply-halfword sign-extends the low *17* bits of its
      operand, not 16. In `cpu.v` (2026-08-17): MPYHW rides the existing
      multiplier and writes reg2 alone, no flags from any of the four; the
      17-bit boundary is pinned by the bench and the `cpu-ext` ROM.
- [~] ? One source claims byte and halfword exchange require `r0` in the unused
      register field or behavior is undefined, but no misbehavior has been observed
      either way. Resolved per beetle-vb: the field is ignored (the assembler
      emits `r0` there regardless).

### Feature: handle exceptions and interrupts

- [x] **Three tiers that escalate.** A normal exception saves state to one register
      pair and sets a pending flag; an exception raised while that flag is set becomes
      a duplexed exception using a second register pair; an exception during *that*
      is fatal — the CPU writes the cause, status word and program counter to the
      first three words of memory and halts until reset. Regular and duplexed
      watched via `cpu-except` (2026-08-14); the fatal tier stays bench-proven
      only — its screen state is indistinguishable from a pass-halt, so no ROM
      can show it.
- [x] **Choose the right return address.** Some exceptions resume at the instruction
      that faulted and some at the one after it. `TRAP` and ordinary interrupts use the
      next instruction; faults, address traps, and any interrupt taken during a bit
      string instruction use the current one. Watched via `cpu-except`: traps
      resume after, faults at the faulting instruction. The bit-string case
      waits for bit strings.
- [~] **Accept interrupts under four conditions at once.** Interrupts are disabled by
      one flag, blocked by either pending-exception flag, and masked by level. Five
      hardware sources exist, ranked with the VIP highest and the game pad lowest, and
      accepting one raises the mask to that level plus one. The timer now drives the
      port at level 1 from `core_top`, exercised end to end by the `timer` ROM in
      `src/tests/cpu.v` and **watched on hardware 2026-08-15** — interrupts
      accepted, acknowledged and RETI'd through 0xFE10 on the Pocket; the
      priority encoder proper waits for a second source.
- [x] **Check between instructions, not during — except where the manual says
      otherwise.** An interrupt can never coincide with an instruction exception,
      and a pending interrupt waits for a cache dump or restore to finish. For
      DIV/DIVU and the floating-point operations the manual's Table 6-2 makes
      them abortable mid-flight with restore at current PC, the scroll says
      between-instructions only, and beetle-vb sides with the scroll; issue #3
      scoped the abort in, so `cpu.v` implements the manual (2026-08-17) —
      nothing commits before the abort, so the rerun is clean and the remaining
      cycle budget is forgiven. Watched via `cpu-longint` on 2026-08-17, which
      proves the core's abort end to end. It cannot settle what NEC's silicon
      does — the Pocket runs this core — so INDEX.md's contradiction stays
      open until someone runs that ROM on a real Virtual Boy, where a check-5
      freeze would mean the NVC never aborts and the scroll's reading should
      come back.
- [~] **Halt until something happens.** `HALT` stops the CPU until an interrupt is
      accepted. With everything masked it never resumes, and that's correct behavior
      rather than a hang to guard against. Benched both ways.
- [x] **Trap on an address.** With a breakpoint register loaded and a flag set, the CPU
      raises an exception when the program counter matches, checked before the fetch.
      Wired 2026-08-17, the last CPU-local feature: 0xFFC0 with restore at
      current PC and AE cleared on entry, checked in FETCH1 after the
      interrupt (the scroll's priority list ranks interrupts above the trap;
      MiSTer orders them the other way, and the scroll wins with a comment).
      MiSTer proves the shape — beetle-vb stores ADTRE and never checks it, so
      Mednafen freezes `cpu-adtre` at check 1 by design. Sim-proven by the
      bench's E8 scenario, and **watched and passed 2026-08-17** by
      morgan-vieira on the 0.8.1 bitstream: `cpu-adtre` showed the filled
      square with status 0x600D and its PC row decoding to the image's
      computed halt address 0x070000AC exactly (screenshot
      `20260817_125504.png`).

### Feature: cache instructions

- [x] **Look up and fill.** One kilobyte holds 128 entries of 8 bytes each, indexed by
      seven address bits, tagged with the upper 22 and a valid bit. A miss reads memory
      and fills the entry. Landed in `cpu.v` (2026-08-17) with beetle-vb's
      per-4-byte-subblock valid refinement, in MLABs because the M10K budget is
      spent; fetches consult it only when `CHCW.ICE` is set and data accesses
      always bypass. The cached fetch walk paces exactly like the bus walk, so
      the ICE-off machine is untouched; `cpu.v`'s header derives the one timing
      wrinkle (a cached one-cycle instruction is walk-limited at two clocks).
- [x] **Clear a range of entries.** Software gives a first entry and a count. Counts
      above 128 clamp, a starting entry of 128 or more does nothing at all, and
      clearing always stops at the last entry rather than wrapping. In: a walker
      clears tag and data per entry, so cleared entries dump as zeros the way
      beetle-vb's memset leaves them.
- [x] **Dump and restore.** The whole cache spills to a software-chosen address as 128
      eight-byte blocks followed by 128 four-byte tags, 1,536 bytes in total. Interrupts
      are postponed until it finishes. Asking for more than one of clear, dump and
      restore at once is undefined, so pick one and say which in a comment. In:
      the walkers never pass the FETCH1 interrupt check, which is the
      postponement; several command bits at once do nothing, beetle-vb's
      exact-match dispatch; the spilled tag word carries valid0 at bit 22 and
      valid1 at bit 23, beetle-vb's format inside the documented NECRV field.
      `cpu-cache`'s restore check executes a fabricated entry in place of ROM,
      which no cache-less shortcut can pass.
- [~] ? Whether the cache is initialized by reset is not established. Resolved
      per beetle-vb: the reset walker clears every entry (and ICE) before the
      first fetch.

### Feature: expose the system registers

- [x] **Thirteen registers reachable only through two instructions.** They configure
      the CPU rather than holding program data. Several are read-only with fixed values
      — the processor ID, the task control word, and one whose purpose nobody knows —
      and writes to them are silently ignored rather than faulting. `CHCW` stores only
      its enable bit; the clear/dump/restore commands wait for the cache feature.
- [x] **Three registers the V810 manual doesn't document.** Nintendo appears to have
      added them. Two have unknown significance; the third returns the absolute value of
      whatever was last written to it, which is strange enough that it's worth
      implementing exactly rather than rationalizing. All three benched, and the
      fixed values plus the absolute-value read watched via `cpu-except`.

### Feature: spend the right number of cycles

This is where cycle accuracy is won or lost, and where the documents run out.

**The model, landed 2026-08-14, rehosted 2026-08-15:** the CPU's state
machine runs on a 39.936 MHz clock from the video PLL's own VCO (133.12 MHz
until the slice-3 rebuild), and `cpu_clock_enable` ticks architectural time
at 625 enables per 1248 clocks — exactly 20 MHz average and exactly 400,000
CPU cycles per 20 ms frame, drift-free against video by construction. Each
instruction charges max(documented base, fetch halfwords × (1 + region wait))
plus a region wait per data access; the next instruction fetches during the
drain and executes when it ends, which is the pipeline-overlap approximation.
Proven by `src/tests/cpu.v`'s marker scenario — eleven measured spans, each
matching a hand-derived cost, with two timing mutations caught — and by
`src/tests/cpu_clock_enable.v` pinning the enable ratio. **First hardware
confirmation 2026-08-15:** the timer ROM's seconds display — 10,000 × 100 µs
per interrupt, counted off this enable — advanced at one per second on the
Pocket by a maintainer's watch, which checks the whole 20 MHz-average chain
at eyeball precision; the exact ratio stays pinned by the benches. Note the
fetch model also means peripherals see bus writes a few fast clocks before
their architectural instant — the timer landed as the first timed peripheral
and nothing software-visible can resolve the skew (its module header says
why); revisit if a later peripheral can.

- [~] **The documented per-instruction counts.** Most instructions have a fixed figure,
      and a conditional branch costs 1 cycle untaken against 3 taken. All of the
      scroll's integer figures are charged, MUL through a pipelined multiplier
      whose 13-cycle budget hides its three fast-clock latency.
- [~] **Load and store are context-dependent.** A load costs 5 cycles in isolation, 4
      immediately after another load, and 1 when it follows a long instruction it
      doesn't conflict with. A store costs 1 for the first two consecutive stores and 4
      for every consecutive store after that. Implemented; "long instruction" means
      the multiply/divide family, beetle-vb's `lastop` choice. The third-store
      base of 4 is currently masked by the 4-cycle fetch floor of a 32-bit
      instruction — it becomes observable, and testable, once the icache lands.
- [~] ? **Memory latency per device.** The scroll says it needs research, but the
      Development Manual's Table 4-4-3 documents wait states per region, and that is
      what `region_wait` in `cpu.v` charges — ROM and expansion 2 (1 with the WCR
      bit), everything else 1, VIP pinned at its documented minimum of 2 until the
      VIP's variable handshake exists. What stays unresearched is the exact
      fetch/execute interleave; our max() model is the approximation.
- [~] ? Input and output instruction costs "may be identical to" load and store costs,
      unconfirmed. Resolved per MiSTer (2026-08-17), which follows Table
      5-11's flat figures: IN charges 5 with no context discount and never
      arms the following load's discount; only true loads do. OUT still
      shares the store shape; MiSTer's finer same-size streak rule is
      unmeasured and lives in `CAVEATS.md`.
- [~] ? The cost of entering an exception — "research is needed." Charged as zero,
      following beetle-vb's explicit "exception overhead is unknown"; MiSTer
      agrees ("unpublished") and charges only its normal fetch timing.
      `CAVEATS.md` carries it — a hardware measurement is the only way out.
- [~] ? Floating-point instructions have documented *ranges* with no rule for which
      case costs what. A separate document gives point values that fall inside those
      ranges but contradicts itself elsewhere; see `INDEX.md`. Charged as the
      Cycle Test totals measured on real hardware, taken from MiSTer's
      fp_issue_cycles_fn (2026-08-17): CMPF 7, CVT.WS 8, CVT.SW 14, TRNC 13,
      ADDF 22, SUBF 26, MULF 26, DIVF 44 — every one inside its scroll range,
      where beetle-vb instead guesses each range's bottom. The T2 bench spans
      pin them.
- [~] ? Bit string timing exists as a table in the V810 manual that was never carried
      into the reference. Now charged from it: word accesses at their region
      waits land the manual's 12-per-word bitwise and 5-per-word search slopes
      on one-wait memory, and the first-invocation intercepts (22 bitwise, 26
      search, 20/13 for length zero) reproduce Table 5-13/5-12's one-word
      columns. Each re-invocation refetches the instruction, which adds its
      fetch cost over the manual's figures uncached; the model and the deltas
      are pinned by the T2 spans.
- [~] ? Whether a conditional branch whose displacement points at the next instruction
      still costs the full 3 cycles. Charged the full 3, the documented figure; the
      bench's branch span pins it.

### Feature: come up in the documented reset state

- [~] **Three registers defined, everything else undefined.** The cause register, the
      program counter and the status word have known values; every other system
      register and every program register except `r0` does not. Initializing them
      anyway would mask ROMs that depend on setting them. The bench pins all three
      values and that the first fetch is 0xFFFFFFF0 through the 27-bit mask.
      (Deviates from beetle-vb, which zeroes r1–r31 at reset; the documents and
      MiSTer both leave them undefined, and we follow them.)
- [ ] ? One table in the hardware manual gives a different reset program counter than
      the other three documents and than its own text. `INDEX.md` records it; use the
      value the majority give.

**ROMs:** `cpu-alu` (arithmetic and bitwise against known results, flags included)
and `cpu-branch` (all sixteen conditions both ways, the jumps, the `r31` link and
bit-0 masking) are built, Mednafen-checked, and passing in simulation. `cpu-except`
(trap through both vectors, RETI flag restore, illegal opcode and zero divide
resumed from their handlers, the duplexed escalation, the fixed system
registers and the WCR readback) **watched and passed 2026-08-14** on 0.3.0.
The completion five (2026-08-17) are built, Mednafen-checked, and run to their
success halts through the real CPU in `src/tests/cpu.v`: `cpu-float` (every
operation, rounding ties, the exponent-wrapping overflow, the flush-to-zero
underflow, all four exception codes with saved PCs), `cpu-bitstring` (bitwise
ops across words and offsets, searches both directions, both address-space
wraps, the 64-bit overlap artifact — Mednafen freezes at check 8 by design,
where beetle-vb's single-word buffer corrupts early), `cpu-cache` (a restored
fabricated entry executing in place of ROM, clear clamps, the dumped layout),
`cpu-ext` (CAXI both ways, XB/XH/REV/MPYHW with the 17-bit boundary), and
`cpu-longint` (timer interrupts landing inside a bit string and aborting a
divide, both resuming to correct results — Mednafen freezes at check 5 by
design, and a Pocket freeze there would be the finding that real silicon does
not abort DIV). A sixth followed on 2026-08-17: `cpu-adtre` (the address
trap fires before the armed instruction with 0xFFC0 and AE stripped, and
stays quiet with AE clear — Mednafen freezes at check 1 by design, since
beetle-vb never checks ADTRE), built, sim-proven, and **watched and passed
2026-08-17** on the 0.8.1 bitstream with its PC row authenticated at
0x070000AC. Every CPU-local feature is now hardware-watched; what remains
of section 3 is the VIP-dependent wait handshake and the residue in
`CAVEATS.md`.
**Pass criterion:** the on-screen status cells read `0x600D` with the halt square
filled; a failure shows the failing check's number instead (the status convention
in `src/roms/README.md`).
**Watched and passed:** `cpu-alu`, `cpu-branch`, `cpu-except`, `busmap`, `halt`
and `timer` on the Pocket across the 0.2.1 through 0.5.0 builds as recorded
above. Issue #3's floating-point, bit-string, `CAXI`, extended-instruction,
cache and long-instruction interruption work is implemented, benched (ten
deliberate mutations each caught before the benches were trusted), sim-proven,
and **watched and passed 2026-08-17** by morgan-vieira on the 0.8.0 bitstream:
all five completion ROMs showed the filled square with status `0x600D`
(screenshots `20260817_120807`/`120821`/`120836`/`120852`/`120911.png`), and
every PC row decoded to its image's computed halt address exactly —
`cpu-float` `0x070003C8`, `cpu-ext` `0x070001BA`, `cpu-bitstring`
`0x07000456`, `cpu-cache` `0x07000166`, `cpu-longint` `0x070000FA` — so each
screen is authenticated rather than plausible. The same session re-ran the
regression sweep (`cpu-alu` `0x07000806`, `cpu-branch` `0x070002DC`,
`cpu-except` `0x070001E0`, `busmap` `0x07000144`, `halt` `0x07000014` at
status `0xBEEF`, `timer` counting with the hollow square and its loop PC, and
`vip-bg`'s full field of bars; screenshots `120928` through `121131.png`),
every PC row again matching today's images.
**Delivery:** through the APF dataslot loader (section 9's first feature, landed
same day at Morgan's request): `.vb` files in `Assets/virtualboy/common/`, picked
at core launch, reloadable from the Interact menu. One bitstream serves every ROM.
The baked-BRAM variants from the first packaging survive in `output/` as a
bisection tool if the loader itself is ever the suspect.

---

## 4. VIP drawing

Builds one frame buffer. Separate module from display, because the two run
concurrently against the same memory and have separate control registers.

### Feature: draw a background world

- [~] **Decode a world's attributes.** Thirty-two worlds of 32 bytes each, processed
      from 31 down to 0 so that lower indexes draw in front. Each carries per-eye
      enables, a type, a destination rectangle, a source position and a parallax offset
      that is subtracted for the left eye and added for the right.
- [~] **Assemble a background from maps.** A background is 1 to 8 maps of 64×64
      characters, arranged left to right then top to bottom, with width and height
      given as powers of two. The base map index rounds *down* to a multiple of the
      total map count. Asking for more than 8 maps is documented as unintended but
      well-defined, and games can rely on it, so it gets implemented rather than
      rejected.
- [~] **Read characters.** Each is 8×8 pixels at 2 bits per pixel packed into 16 bytes,
      spread across four tables that sit in the gaps between frame buffers. A
      contiguous mirror exists specifically so software can address all 2,048 as one
      run, and the address arithmetic goes through that mirror.
- [~] **Apply palettes and transparency.** Pixel value 0 in a character is transparent
      and leaves the frame buffer untouched, which is why the palettes only have three
      entries. Background and object uses draw from separate palette sets even for the
      same character.
- [~] **Handle running off the edge.** A background either repeats indefinitely or
      substitutes a designated character outside its bounds, selected by one bit.
- [ ] ? That designated character may have restrictions on which characters it can
      reach; the reference says some experimentation is in order.

### Feature: draw an h-bias world

- [~] **Shift each row independently.** One 4-byte parameter per pixel row supplies a
      separate horizontal offset for each eye, added to that eye's source position.
- [ ] ? The right eye's offset appears to be addressed by OR-ing 2 into the left one's
      address rather than adding. If the parameter base isn't divisible by 4, the left
      offset silently serves both eyes.

### Feature: draw an affine world

- [~] **Walk a source vector per row.** One 16-byte parameter per row gives a starting
      source coordinate in 13.3 fixed point and a per-column delta in 7.9, which is
      what makes rotation, scaling and cheap perspective possible.
- [~] **Apply parallax to one eye only.** The sign decides which: negative applies to
      the left eye, non-negative to the right. It shifts which column's output is
      produced rather than shifting the result.
- [~] **Require 16-byte alignment.** The VIP appears to compute some field addresses by
      OR-ing and others by adding, so a misaligned parameter base corrupts the
      following parameters. The reference marks this IMPORTANT.
- [ ] ? Which bits of parameter memory the VIP uses as scratch, and how.

### Feature: draw objects

- [~] **Place a character anywhere.** Each of 1,024 objects is 8 bytes: a signed
      horizontal position, a parallax offset applied per eye, a vertical position,
      per-eye enables, both flips, a palette selector and a character number.
- [~] **Serve objects in groups.** Four registers give each group's *end* index; a
      group's start is one past the previous group's end, and group 0 starts at zero.
      Objects draw in reverse from end to start, and if end is below start the walk
      wraps through object 1,023 rather than drawing nothing.
- [~] **Cycle groups within a frame.** An internal counter starts at 3, decrements
      after each object world drawn, and wraps back to 3, so the same group can be
      drawn more than once per frame. A world with both eye enables clear is skipped
      *without* consuming a group.
- [ ] ? The vertical position field's exact range is unknown, because part of it lands
      off-screen and can't be observed.

### Feature: compose the frame buffer

- [~] **Fill one 1×8 strip at a time.** Frame buffer memory is column-major at 2 bits
      per pixel, so one halfword is eight vertically-stacked pixels. Each strip is
      initialized to the background color, then every world from 31 down to 0 draws
      into it, then it's stored — and each location is written exactly once per frame.
- [~] **Stop early on a control world.** A world with its end flag set terminates the
      walk, and every lower-indexed world is skipped.
- [~] **Delay background-color changes.** A write doesn't take effect until after the
      first eight rows of the *next* frame are drawn.
- [~] **Alternate frame buffers.** Drawing swaps between buffer 0 and 1 each pass so
      one can be displayed while the other is filled. Only the top 224 of the 256 stored
      rows are ever drawn or shown; the rest is functional memory the VIP never touches.
- [ ] ? Exactly when the active buffer toggles is unknown — "it may occur when the frame
      clock goes high."
- [ ] ? Whether buffer 0 is necessarily the default after reset.

### Feature: report drawing status and raise interrupts

- [~] **Expose progress in eight-row groups.** Software can read which group is being
      drawn and ask for an interrupt when a chosen group starts.
- [~] **Report overrun.** If the previous pass is still running when the next should
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
All four are built, and their paths pass `vip_draw` or `vip_registers` simulation.
`vip-affine-diag` isolates affine completion from coordinate errors.
**Pass criterion:** recorded per ROM in `src/roms/README.md`.
**Watched and passed 2026-08-15:** `vip-bg`, `vip-obj`, `vip-affine`,
`vip-affine-diag` and `vip-int` on Pocket hardware. These prove the current
renderer paths, not every edge case marked `[~]`. Completing all documented and
reference-defined VIP behavior is tracked by GitHub issue #4. Undocumented
refresh, event-overlap and display-servo behavior remains isolated in issue #2.

---

## 5. VIP display

Ships finished frame buffers to the screen. Fixed timing, unlike drawing.

### Feature: display a frame on the 20 ms timeline

- [~] **Follow the fixed schedule.** Every frame is 20 ms: the frame clock rises at 0,
      the left buffer displays from 3 to 8 ms, the clock falls at 10, and the right
      buffer displays from 13 to 18. This is the timing games actually synchronize
      against, and unlike drawing it's specified exactly.
- [~] **Require both enables.** Two separate bits must be set before anything appears,
      and one of them also gates sync signals to the display servo.
- [~] **Report which buffer is busy.** Four status bits, one per buffer, that software
      polls to work out what double-buffering is doing.
- [ ] ? There's no software-visible way to choose which buffer displays; the only
      documented handle on double buffering is to use the drawing engine.

### Feature: shape emission per column

- [~] **Walk the column table.** Each eye has 256 entries, one consumed per four
      columns of pixels, walking from higher addresses to lower — lower addresses are
      further *right*. A lock bit freezes the pointer, which is the only way software
      can hold a column configuration still.
- [~] **Give each column a duration and a repeat count.** Emission time is in 200 ns
      units and the repeat count multiplies it, so apparent brightness is the product of
      the two. Past roughly 128 the user can't see any further increase.
- [~] **Cut a column short when it overruns.** If the configured brightness plus idle
      time exceeds the column's allotted window, emission stops and moves on rather
      than stretching the frame.
- [ ] ? Which entries the servo actually uses shifts frame to frame; the VIP prefers the
      middle 96 and keeps the rest as slack for the physical mirror.

### Feature: set brightness

- [~] **Three registers for four shades.** Levels A and B are durations in 5 ns units
      set directly; level C's real duration is A plus B plus C, so writing C alone does
      not do what it looks like. A fourth register sets the idle time between pixels.

### Feature: raise display interrupts

- [~] **Six display-side conditions.** Frame start, game start, left and right buffer
      finished, mirrors-unstable, and the drawing-overran condition shared with the
      drawing engine. All of them, and the drawing-side ones, deliver the same interrupt
      code, so the handler always has to read the pending register to find out why.
- [~] **Latch pending regardless of enable.** A condition sets its pending bit whether
      or not it's enabled; the interrupt only fires when both the enable and the pending
      bit are set. Software acknowledges through a separate write-only register.

**ROM:** `vip-display` — built; its brightness path passes `vip_display` simulation.
**Pass criterion:** alternating four-pixel-wide dim and medium red vertical stripes
fill the 384×224 field. Black, flat brightness, incorrectly sized stripes, or
horizontal breaks fail.
**Watched and passed 2026-08-15:** `vip-display` on Pocket hardware, alongside
the drawing ROMs above. Documented display completion remains in issue #4;
the silicon behavior that the available sources do not establish remains in #2.

---

## 6. Timer

**Landed as `core/timer.v` (2026-08-14)**: the misc region's first device, on
`mem_bus`'s misc select with its answer for 0x18/0x1C/0x20 and its irq into the
CPU at level 1 (0xFE10). 20 µs is 400 ticks of `cpu_clock_enable`'s architectural
time, so the timer cannot drift against video. Where the scroll runs out MiSTer's
`vue.v` decides (the free-running base, the reload-pending restart, the
rate-change decrement while disabled), each choice commented in the module;
where beetle-vb contradicts the scroll (deferred reload loads, reload resetting
to 0xFFFF, status dying with Tim-Z-Int) the scroll wins, and the `timer` ROM's
expectation says so — Mednafen freezes that ROM at check 3 by design.
Proven by `src/tests/timer.v` — the 400/2000-ce grids held across disables,
every Z-Stat-Clr rule, both acknowledge paths, the interval restart, both
rate-change cases, the reset disagreement — with ten deliberate mutations each
caught, one bench gap (disable-and-clear masked by the faulty clear at counter
zero) found and closed by the sweep. `src/tests/cpu.v` runs the built ROM's
whole check phase through the real CPU, timer and 0xFE10 vector to its pass
sentinel, three interrupts serviced.

**Watched and passed 2026-08-15** by morgan-vieira on the 0.4.0 bitstream.
The ROM first ran on the still-installed 0.3.0 core and froze exactly as a
timer-less core must — status `0x0001`, PC row reading `0x0700003A`, which is
check 1's computed fail-spin — authenticating the failure reporting on
hardware before the real run. On 0.4.0 (screenshot `20260815_020122.png`) the
cells read `0x0040` with the PC row inside the display loop at
`0x0700021x`, the back-computed boot time matching the install timeline, and
the maintainer watched the cells advance once per second. All ten checks
passed on hardware, including check 10's write-induced zero while disabled.
The rate-change decrement stays bench-proven only; the ROM doesn't exercise
that corner.

### Feature: count down at a selectable rate

- [x] **Tick every 20 µs, always.** An internal counter advances modulo 5 whether or not
      the timer is enabled. One control bit decides whether the user-visible counter
      decrements on every tick or only when that internal counter wraps, giving 20 µs
      or 100 µs. The bench pins both grids and that they free-run through disables.
- [x] **Reload on write, not just on zero.** Writing either half of the counter sets
      the reload value, loads the whole 16-bit value into the counter *and* restarts the
      current tick interval. Reads return the live counter, which is why software is
      told to stop the timer before reading it. The restart rides `reload_pending` on
      the free-running base (MiSTer's shape): the next count tick reloads instead of
      decrementing, so the first decrement lands one to two tick intervals after the
      write, never sooner.
- [~] **Decrement on a rate change.** Switching from the slow rate to the fast one while
      the internal counter is non-zero decrements immediately, which can itself fire the
      interrupt. Benched both ways; follows MiSTer in decrementing whether or not the
      timer is enabled, which only MiSTer models.
- [~] ? The hardware may actually initialize its internal counter to 4 and count down
      rather than up. Resolved per MiSTer: up from zero. The wrap lands on the same
      tick either way, so nothing software-visible separates the two.

### Feature: raise the zero interrupt

- [x] **Fire on the transition, not the state.** Any change from non-zero to zero
      qualifies, including one caused by a write to the reload registers — but the timer
      loading a reload value of zero does not. The irq is a latch set at transitions
      (so a write-induced zero fires even disabled, MiSTer's reading), while Z-Stat is
      a sticky level on enabled-at-zero (so enabling at zero shows status without
      replaying an acknowledged interrupt — beetle-vb's tick behavior, the scroll's
      wording). The bench separates the two.
- [x] **Acknowledge through two paths that interact.** A status bit stays set while the
      counter is zero and the timer is enabled. Clearing it acknowledges the interrupt,
      except that disabling the timer and clearing in the same write disables it without
      clearing the status — nor acknowledging the interrupt, which is where we part
      from beetle-vb's status shadow and follow the scroll's parenthetical.
- [x] **Start with the counter and reload disagreeing.** Reset leaves the counter at
      `0xFFFF` and the reload at zero — the only moment the two can differ, since any
      write to either makes them equal. Both references reset the reload to `0xFFFF`
      instead; we follow the document, and the ROM's check 3 puts the difference on
      screen.

**ROM:** `timer` — built, Mednafen header-checked, check phase passing in
`src/tests/cpu.v`. Ten checks (reset state, the reload disagreement, any-width
access, counting to zero, the faulty clear, disable-then-clear, three interrupt
paths), then a display phase: one interrupt per second from reload 10000 at
100 µs, the count on the status cells. The hardware run used a stopwatch as the
human reference; the 50 Hz raster and timer share the PLL, so the check also
covered their common timebase.
**Pass criterion:** the status cells count up by one each second and read
`0x003C` after a timed minute; the halt square never fills. A frozen small
number is that check failing; check 10 alone failing means real hardware does
not raise a write-induced zero while disabled, which would itself be a finding.
**Watched and passed 2026-08-15:** all ten checks completed on the Pocket and
the status count advanced once per second. The earlier 0.3.0 run also failed at
the expected timer-less sentinel, authenticating the ROM's failure path.

---

## 7. Game pad

**Landed as `core/game_pad.v` (2026-08-16)**: the misc region's second device,
answering `SDLR`/`SDHR`/`SCR` at 0x10/0x14/0x28 beside the timer and
interrupting the CPU at level 0 (0xFE00). That turns `core_top`'s two-source
special case into the priority encoder section 3 was waiting on. One shift
register serves both read paths, because the hardware has one serial port:
a hardware read clocks it 640 architectural cycles a bit, and a software
read clocks it by hand. `core/host_pad_map.v` is the host side, keeping
APF's controller out of the machine's module.
Proven by `src/tests/game_pad.v` and by twenty-one deliberate mutations of
the two modules, each caught by a distinct check before the bench was
trusted. One of them, the software clock's polarity, stayed invisible until the
bench stopped clocking in balanced pairs and counted the scroll's thirty-three
writes instead. `src/tests/cpu.v` runs the built `pad` image through the real
CPU, bus and pad to its self-test pass sentinel and then follows a changing
report, with three further mutations each caught by their own sentinel.

**DECIDED (morgan-vieira, 2026-08-16): the controller mapping**, which
settles open decision 2. The Pocket's D-pad is the left pad, its face
buttons are the right pad in the diamond arrangement the hardware already
draws (X up, A right, B down, Y left), and L and R are the machine's A and
B. Twelve Pocket inputs cannot reach fourteen machine buttons, so the
default leaves the machine's own Select and Start unreachable, standing L
and R in their place. The note asked for the swap to be available, so
`interact.json` carries two switches: which pad the D-pad drives, and
whether Select and Start report as themselves or as L and R. Every
documented bit is reachable in some setting, which is what lets the ROM's
pass criterion cover all sixteen.

### Feature: report button state

- [x] **Sixteen bits in a documented order.** Two four-way pads, six buttons, select and
      start, plus a signature bit that a standard controller always sets and a
      low-battery bit. The bit order is not the order anyone would guess, so it comes
      from the table rather than from intuition. The scroll's register numbering is the
      one implemented, and beetle-vb's `input.c` reproduces it bit for bit; the wiki
      article numbers the same sixteen the other way round, which `INDEX.md` now records
      as a numbering difference rather than a disagreement: it counts shift positions,
      and the report goes out MSB first. Fifteen of the sixteen carry live state; the
      sixteenth is below.
- [~] **The low-battery bit.** `PWR`, bit 0, reports 1 when the pad's batteries are
      low. It is hardwired to 0 in `host_pad_map.v`, which is not the behavior but
      the absence of it. **Blocked on the host, not on difficulty:** APF hands the core
      no battery signal at all. `core_top`'s port list carries no such input, and
      nothing in `docs/analogue/` exposes charge state to a core. The only mention of
      a battery in the whole of APF's documentation is a warning not to remove the
      Pocket's own. The `pad` ROM covers this as far as it can: cell 16 is bit 0, and
      the criterion is that it stays dark with every button held, which is what a
      wired-through bit reading "not low" would also do. Return to it if a future APF
      revision exposes charge state; there is nothing to implement until then.
- [x] **DECIDE: controller mapping.** Decided above; `host_pad_map.v` implements it and
      `input.json` labels the default in the Controls menu. APF's `input.json` is
      read-only, so it describes the default rather than following the switches.

### Feature: clock the state out

- [x] **A hardware read that takes 512 µs.** Started by one bit, it clocks buttons at
      31.25 kHz, reports busy while running, and can be aborted mid-flight by another
      bit. 640 ce a bit, 10,240 for the report, pinned exactly by the bench. The abort
      lands in the write, following the scroll's "immediately" and beetle-vb; MiSTer
      defers it to a serial clock phase, and the module says so.
- [x] **A software read that's faster.** Software latches, then toggles a clock bit
      itself, and the bit it writes is inverted on the way to the pad. beetle-vb never
      implements this path at all (its instant-read hack answers with live pad state),
      so MiSTer's `vue.v` decides it: the report advances on the written bit's falling
      edge, which is the pad's own rising edge once the inversion is applied.
- [x] ? The reference describes the software read as both "16 times" and "33 writes" and
      doesn't reconcile them. **Resolved: they describe the same procedure.** One write
      raises the bit, then sixteen fall-and-raise pairs follow, the last raise clocking
      nothing: 33 writes carrying 16 advancing edges. The bench asserts both readings
      at once by stopping on a raised bit and requiring the report to still be short.
- [x] ? Real hardware returns unstable data if software clocks too fast in humid
      conditions, which games worked around with a dummy multiply between bits.
      **Resolved by construction, not by emulation:** the instability is the physical
      cable and the pad's own logic, and this core has neither. The report is already
      inside the FPGA and is sampled at the latch. A game's dummy multiply costs it
      nothing here.

### Feature: raise the key interrupt

- [x] **A condition a standard controller can never satisfy.** It fires if any of the
      top twelve bits is set, but is suppressed if any of three low bits is set — and
      the signature bit sits in that suppressing range and is always set. Implemented as
      written; a non-standard controller could still trigger it. This is the one place
      the references split and the document wins: beetle-vb raises on every completed
      hardware read and never checks the condition, while the scroll states it outright
      and MiSTer agrees with the scroll. Writing the inhibit bit is the acknowledge
      path, which both references do agree on, and a software read raises nothing,
      because the scroll conditions the interrupt on a hardware read.

**ROM:** `pad`, the Pocket's controls drawn where they sit on the device and
lighting while held, plus the raw sixteen-bit word twice in small rows along
the bottom, one row per read path, plus a startup self-test. The picture
decodes the hardware read through the default mapping, because the V810
cannot see Core Settings; the rows are the ground truth under any setting.
The two rows cannot prove each other on their own, because both reads land in
the same registers and a dead software read leaves the hardware read's value
standing; the reset state is what separates them, so the self-test reads the
registers zero, then does a software read alone before any hardware read has
run. Built, Mednafen header-checked, and passing in `src/tests/cpu.v` against
the real pad.
**Pass criterion:** each physical button lights exactly its control and its
documented bit and no others, in both rows, with the failure bar black
throughout. The full wording, including the per-button cell numbers and each
self-test sentinel, is the ROM's `expectation`.
**Watched and passed 2026-08-16** by morgan-vieira on the 0.7.0 bitstream, as
the original two-row display: every button toggled exactly its cell in both
rows and the bar stayed black. **Re-watched and passed 2026-08-17** as the
controls-picture display above, same bitstream, ROM change only. The two
Core Settings switches are proven by `src/tests/game_pad.v` and have not been
separately watched on hardware.

---

## 8. VSU

Six channels mixed to 10-bit stereo at the exact 480-cycle publication cadence,
41.666 kHz from the 20 MHz architectural clock. **Complete 2026-08-16.**

### Feature: produce wavetable channels

- [x] **Store five 32-sample tables.** Samples are 6-bit unsigned, stored four
      bytes apart, and the upper two written bits are discarded.
- [x] **Lock waveform memory during playback.** Any active source, including noise
      and a channel selecting invalid bank 5–7, blocks writes. Invalid banks stay
      active but contribute silence.
- [x] **Run five independent oscillators from the 5 MHz VSU clock.** Frequency
      timing, 32-sample phase progression, stereo levels, fixed duration and partial
      frequency-register writes match the documented register behavior.
- [x] **Restart channel state on every `SxINT` write.** Phase and timing restart,
      but the live envelope level does not reload. The `vsu-restart` ROM isolates
      this distinction on hardware.

### Feature: shape amplitude with the envelope

- [x] **Grow, decay, clamp and repeat.** The live level advances on the documented
      frame grid, holds at a terminal value for one-shot envelopes, and reloads at
      the documented point when repeat is enabled.
- [x] **Keep restart and envelope reload separate.** Frequent `INT` writes cannot
      turn a completed one-shot envelope back on; rewriting the envelope register
      provides the reload behavior.

### Feature: sweep and modulate channel 5

- [x] **Sweep the current frequency.** Direction, shift, frame interval and the
      immediate overflow-shutdown quirk are implemented.
- [x] **Apply signed 32-entry modulation.** One-shot and repeating table walks use
      the programmed base frequency without destroying it, and table writes lock
      while channel 5 is active.
- [x] **Honor control writes during a frame.** Current, next and elapsed frame state
      preserve the hardware's conditional interval-change behavior; sweep and
      modulation share the same progression model.

### Feature: produce noise

- [x] **Generate all eight documented sequences.** Channel 6 uses the 15-bit XNOR
      shift register, selectable taps, 500 kHz base clock, two-level output, and the
      reset behavior of both control writes. Simulation pins every sequence period.

### Feature: mix and deliver stereo output

- [x] **Use the documented unsigned digital mix.** Each channel applies stereo level
      and envelope gain in the hardware order; all six snapshots are summed and
      truncated to the 10-bit result.
- [x] **Remove DC without introducing clicks.** A stereo Q16 first-order high-pass
      implements the approximately 7.234 Hz analog cutoff before scaling to APF's
      signed audio path.
- [x] **Publish at a stable cadence.** The serial snapshot mixer emits one sample
      every 480 enabled CPU cycles and `audio_i2s` carries it to the Pocket without
      popping or crackling.
- [x] **Stop and reset deterministically.** `SSTOP` disables every source and the
      reset state is silent. Exact uninitialized silicon contents are undocumented
      and unobservable through the write-only VSU bus, so they do not leave a
      software-visible feature incomplete.

**ROMs:** `vsu-tone`, `vsu-chord`, `vsu-envelope`, `vsu-timing`, `vsu-sweep`,
`vsu-modulation`, `vsu-noise`, `vsu-wave-lock` and `vsu-restart`.
**Verification:** all 14 simulation benches, all 39 assembler tests, ROM
typechecking, Mednafen parsing and numerical WAV analysis passed. Quartus closed
with positive timing slack. Morgan watched the complete Pocket suite and confirmed
stable tone and timing, stereo mixing, fade/restart, sweep, repeating modulation,
noise and waveform locking with no popping or crackling.

---

## 9. Game pak

### Feature: serve cartridge ROM

- [x] **Take the image from the APF dataslot.** The Pocket hands the core a `.vb` file;
      the core has to present it as a memory region. Now `core/cart_rom.v`: slot 0
      in `data.json` at bridge `0x00000000`, required so the Pocket spawns the file
      browser, user-reloadable, read-only, and with "reset core while loading" set
      so APF holds `reset_n` through every load; the CPU is additionally gated on
      `dataslot_allcomplete`. Capped at 64KB of block RAM — plenty for test ROMs,
      revisited when cartridge memory moves off-chip for commercial sizes (open
      decision 1). Bridge byte order (file byte 0 in bits 31:24) is pinned by
      `src/tests/cart_rom.v` and was confirmed on hardware 2026-08-14: three
      images of two sizes picked from the Pocket's browser each booted through
      the reset vector and ran to its success halt.
- [x] **Mirror by masking.** Every commercial cart is a power of two in size, and
      addresses past the end have their upper bits masked, which is exactly why the
      header and vectors sit at the very top of the address space and land correctly for
      any ROM size. The mask is recovered from the load itself — highest word
      address written — and the bench proves the reset vector's top-of-space view
      lands on the image's own trailer, and that a reload shrinks the mask.

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

### Settled


2. **Controller mapping** for two D-pads. Decided by morgan-vieira on 2026-08-16 and
   recorded in section 7. Not answered from the implementations in the end: APF's
   `input.json` is read-only and cannot remap, so the mapping lives in
   `host_pad_map.v` with two `interact.json` switches over it. Twelve Pocket inputs
   cannot cover fourteen machine buttons, and choosing which two go missing is a
   player's call per game rather than a constant.

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
