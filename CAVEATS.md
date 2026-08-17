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

## Adjacent, tracked elsewhere

- VIP data accesses charge the documented minimum wait of 2 until the real
  variable handshake exists — part of the VIP work (`TODO.md` section 3's
  memory-latency note, issue #4).
- WRAM's pseudostatic init requirement (200 µs plus eight dummy reads before
  first use) is deliberately not emulated (`TODO.md` section 2).
