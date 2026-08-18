# Caveats

Deliberate, known deviations between this core and real hardware that no
reference resolves — checked against MiSTer's port first, then beetle-vb,
before landing here. Each entry says what every implementation does and what
would close it. Gaps in the *documents* live in
`docs/technical-notes/INDEX.md`; open work lives in `TODO.md` with its `?`
marks. This file is for the residue: behavior nobody has measured, or
approximations structural to this core's design.

## CPU timing

### Exception entry charges zero cycles

Nobody knows the real figure. beetle-vb comments "exception overhead is
unknown" and adds nothing; MiSTer comments "exception entry cycle count is
unpublished" and charges only its normal fetch timing; we charge zero on top
of the handler's own fetch. Closing it needs a hardware measurement — a
timer-bracketed TRAP loop on a real Virtual Boy would do.

### Bit string charges match the manual's slopes, not its per-type intercepts

The V810 manual's Tables 5-12/5-13/5-14 give per-word slopes plus start-up
intercepts that vary by seven boundary-condition "types". Our per-invocation
machine charges word accesses at their region waits — which lands the
documented 12-per-word bitwise and 5-per-word search slopes on one-wait
memory — with flat intercepts taken from the tables' one-word columns (22
bitwise, 26 search, 20/13 for length zero). Each re-invocation also refetches
the instruction, since PC really is held on it: one cycle cached, the fetch
cost uncached. MiSTer reproduces the full type tables (`bs_arith_start/
resume_cycles_fn`), but that model is welded to an engine that keeps the
instruction resident; porting it here means carrying a type classification
and word index across invocations. Adopt it if a game is ever shown to care.

### A cached 1-cycle instruction paces at 1.0016 cycles

The fetch walk is two clocks (lookup, decide/execute) and the 39.936 MHz
domain averages two clocks per architectural cycle, so back-to-back cached
1-cycle instructions run at 20 MHz ÷ 1.0016 — the walk, not the ledger, is
the limit, and `cpu.v`'s header derives it. Everything charging 2 or more
cycles stays exact. MiSTer's pin-level pipeline reaches a true 1; getting
there here means re-adding the pipelining the 0.5.0 rebuild deliberately
deleted, for a 0.16 % ceiling on straight-line cached code.

### A taken branch to the next instruction charges the full 3 cycles

Unmeasured everywhere. MiSTer's comment says the same ("a taken Bcond to
fall-through is unmeasured") and charges the taken cost, as we and the
documents' plain reading do.

### The store streak counts any consecutive stores

The scroll says the third *consecutive store* onward costs 4 cycles. MiSTer
refines the streak to stores of the same size and the same load/IO family
(`next_write_streak_fn`); no document says which is right and nothing
measured it. We follow the scroll's plain sentence.

## CPU behavior

### The fatal exception tier is proven in simulation only

The third escalation writes its cause word, PSW and PC to `0x0`–`0x8` and
stops until reset — a screen state indistinguishable from an ordinary
pass-halt, so no ROM can show it. The bench pins the writes and the
permanent stop; a hardware proof would need bus observation.

### Whether NEC's silicon aborts DIV and floating point mid-flight is open

We follow the V810 manual's Table 6-2 (abortable, restore at current PC);
the scroll and beetle-vb say between-instructions only, and MiSTer models
long operations as interrupt-deferring. `INDEX.md` records the
contradiction. The Pocket runs this core, so `cpu-longint`'s pass proves the
implementation, not the silicon — running that ROM on a real Virtual Boy is
the experiment: a check-5 freeze there means the NVC never aborts, and the
core should revert to the scroll's reading.

## VIP

### Active worlds render at engine speed, not the measured per-tile figures

The strip scheduling reproduces MiSTer's measured coordinator exactly � 32
ce of setup, 2,033/1,949 ce strip service budgets that pause while a world
is processed, 11 ce END and 21/20 ce dummy intervals, totalling the scroll's
~2.8 ms erase-only frame � but the time an *active* world adds is our
engine's own. Normal and h-bias worlds blend a character row per line-bank
write at roughly twice MiSTer's measured per-tile cost, and affine worlds
walk per pixel at slightly under MiSTer's measured four ce per output pixel,
so a frame full of background worlds reaches OVERTIME at roughly half the
world count real silicon tolerates. Closing it means porting MiSTer's
per-engine tick model (91 ce per tile-row load, 2 ce per tile and per
character row, the per-object probe and setup charges). Adopt it if a game
is ever shown to care.

### VIP register accesses cost one cycle more than measured

MiSTer measures a register access at 2 total 20 MHz cycles
(`LOCAL_TOTAL_CE`); the Development Manual's Table 4-4-3 documents a two-wait
minimum for the VIP region, which `cpu.v` charges as its budget, making our
register access 3. Memory accesses use the measured figures (3 ce writes,
7 ce reads). The document wins over the measurement until hardware says
otherwise.

### The column table walks the documented window, not the measured cadence

The scroll's display procedure consumes one column-table entry per four
columns across the 5 ms eye window � exactly 2,080 clocks per group in the
39.936 MHz domain, which is what CTA reads reflect here. MiSTer measures a
1,392-ce group cadence, under which the ninety-six groups outrun the
documented window and the eye actually ends when group 95 completes rather
than at the documented 8 ms / 18 ms marks (its `CTA_TIMED_EYE_END`).
Following the measurement would move LFBEND and RFBEND off their documented
times, so the document wins; the measured servo behavior belongs to the
issue #2 investigation.

### SBOUT holds the formal 56 us, not the measured worst case

The scroll's formal figure is 56 us; its own testing saw up to 120 us,
unreconciled. beetle-vb and MiSTer both implement 1,120 cycles = 56 us, and
so do we. The scroll itself calls SBOUT unreliable for detecting progress.

### Display-side memory contention is not modeled

On real hardware the display serving steals VIP memory slots from the CPU.
MiSTer's only display-side port-A client is the CTA fetch � one 16-bit read
per four columns � and this core serves those from a shadow copy, so CPU
accesses never stall against display activity. The undocumented refresh
arbitration is issue #2's.

### Emission time reaches the panel through a gamma curve

A pixel's LED is lit for `exposure` ticks of its column's window and dark
for the rest, and what that pulse train should look like on an LCD is
nobody's measurement. MiSTer runs exposure through a lookup table its own
header calls presentation logic rather than Virtual Boy behavior
(`rtl/VIP/vip_host_display.sv`); `vip_luma_curve` does the same with
round(255 × (exposure/255) ^ (1/2.2)), which is beetle-vb's encode
(`mednafen/vb/vip.c` MakeColorLUT). An LED's output is linear in duty cycle,
so exposure is linear light and that is the plain inverse of a 2.2 display:
the physically neutral choice, and the one we take.

We followed MiSTer's curve until 2026-08-18, as round(255 × (exposure/255) ^
(1.4/2.2)) — the same encode against the 1.4 rendering gamma a dark surround
wants, and a power law through MiSTer's SDR table to within 2/255. On the
Pocket it was too dark to play, so we now depart from MiSTer deliberately
[morgan-vieira, 2026-08-18]. That is a readability decision about a panel we
can see, not a claim about the hardware. Neither curve is measured.

Both are absolute — full red needs an exposure of 255, so a game that dims
itself gets a dimmer picture. Emulators normalize instead:
virtual-boy.com rendered a frame whose exposures were 33/66/132 as
135/185/254, which is that frame's own top level scaled to full red and
gamma-encoded. That photographs better and cannot represent a fade to dark.
Closing this needs a photometer on real hardware.

### Two eyes reach one screen however the user asks, and none of it is hardware

The machine shows each eye its own image through its own mirror; a Pocket
has one screen and no mirrors. Every answer to that is presentation, not
Virtual Boy behavior, so `vip_stereo` takes beetle-vb's five — anaglyph,
Cyberscope, side by side, and the two line interleaves — rather than
inventing any, and adds the pair beetle-vb has no reason to offer: 2D
(left eye), which is what this core showed before there were modes, and 2D
(right eye). The geometry and the compositing follow `mednafen/vb/vip.c`.

Two places where following it exactly was not possible or not useful:

- **Side-by-side separation is four values, not a slider.** beetle-vb's
  frame is 768 + separation wide and the separation is free; `video.json`
  declares its widths ahead of time in at most eight slots. 0, 16, 32 and
  64 pixels get a slot each and the rest of the range is not offered.
- **Cyberscope's raster is three clocks long.** Every other mode's totals
  multiply to the 245,760 clocks that make 20 ms at 12.288 MHz, so the
  display buffer's swap point stays put. 245,760 has no factor pair that
  leaves room for a 512x384 active area with porches, so that mode runs
  581 x 423 = 245,763 and its swap point drifts a frame roughly every 27
  minutes.

beetle-vb also has a slow anaglyph path, for a channel that carries both
eyes: sum the eyes' linear light and re-encode rather than OR their encoded
colours. None of the six presets needs it — each splits the three channels
between the eyes — and we do not offer the custom colours that would, so
only the fast path exists here. `src/tests/vip_stereo.v` checks that
invariant over every preset value rather than trusting it.

Which eye is which, and whether the parallax reads as depth rather than
inside out, is something only a maintainer with the ROM on hardware can
say; `vip-stereo` exists to be that check.


## Adjacent, tracked elsewhere

- VIP data accesses charge the documented minimum wait of 2 until the real
  variable handshake exists — part of the VIP work (`TODO.md` section 3's
  memory-latency note, issue #4).
- WRAM's pseudostatic init requirement (200 µs plus eight dummy reads before
  first use) is deliberately not emulated (`TODO.md` section 2).
