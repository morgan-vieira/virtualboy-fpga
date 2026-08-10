# Notes: V810 Seminar (Introduction, Architecture, Programming Tips & Optimization)

## Source

- File: `v810-seminar-slides-1-introduction-architecture-tips.md`
- Type: slides (presentation deck, transcribed to Markdown; figures and diagrams are referenced as image files and their content is not in the text)
- Extent: 38 slides
- Version or date stated in document: "February 21, 1995" on the title slide. Footer codes of the form `V-1123-0295-WWnn` appear on several slides. [slide 1, slides 2, 3, 9, 21, 26, 32]
- Author or publisher stated in document: NEC; "NEC Electronics Inc."; "NEC Corporation". [slide 1, slide 38]
- Slide numbers used as anchors in these notes are 1-based positions in the deck. They agree with the deck's own footer codes wherever a footer survives: `WW02` on slide 2, `WW03` on slide 3, `WW09` on slide 9, `WW21` on slide 21, `WW26` on slide 26, `WW32` on slide 32.
- The transcription's first slide also carries the text "PLANET VIRTUAL BOY" and the URL `HTTP://WWW.VR32.DE`, which is not part of the NEC titling. [slide 1]

## Scope

The deck introduces the V810 processor, its architecture, and programming tips. The stated agenda is three parts: "V810 Introduction", "V810 Architecture", "Programming Tips & Optimization". [slide 2] Divider slides mark the sections in practice as "V810 Architecture" [slide 9], "Interrupt/Exception Flow" [slide 26] and "Important H/W Issues" [slide 32].

Content covered: CISC versus RISC, load/store architecture, code size, pipelining, cache, interrupt response time, the architectural outline, registers, data types, alignment, the instruction set, execution clock counts, addressing modes, flag effects, sign/zero extension, function calls, bit string operations, floating point, the interrupt and exception model, hardware interlock, and cache implementation and usage.

The deck does not give instruction encodings, does not enumerate the individual program or system registers in text (those slides are diagrams only), does not give bus timing or electrical characteristics, and does not contain code listings beyond a handful of two-to-four line examples.

## Key concepts

- **CISC** — "Complex Instruction Set Computer". [slide 3]
- **RISC** — "Reduced Instruction Set Computer". The deck labels the V810 a RISC machine ("RISC (V810 etc.)"). [slides 3, 4]
- **Load/Store Architecture** — the property that arithmetic operates on registers, with separate load and store instructions for memory. [slide 4]
- **Pipeline stages** — IF : Instruction Fetch; ID : Instruction Decode; EX : Execution; MA : Memory Access; WB : Write Back. [slide 6]
- **Interlock** — "Hazard detection & interlock by H/W", described as covering load/store and flag hazards. [slide 33]
- **CHCW** — the "cache control word" register. [slide 37]
- **V800** — the name the interlock slide uses for the hardware being contrasted against "General RISC". [slide 33]

## Content

### Introduction (slides 1–8)

- Title slide: "V810 Seminar", February 21, 1995, NEC, NEC Electronics Inc., NEC Corporation. [slide 1]
- Agenda: V810 Introduction; V810 Architecture; Programming Tips & Optimization. [slide 2]
- "CISC vs. RISC" gives only the two expansions and a figure; no comparison text survives in the transcription. [slide 3]
- Load/Store Architecture contrasts a CISC memory-to-memory add with the equivalent RISC sequence. [slide 4]
  - CISC: `add _mem1, _mem2`
  - RISC (V810 etc.): `load _mem1_disp[rBase], rX` / `load _mem2_disp[rBase], rY` / `add rX, rY` / `store rY, _mem2_disp[rBase]`
- "Code Size Efficiency" is a figure only; the transcription carries no text for it. [slide 5]
- Pipeline slide contrasts "Non-pipeline" and "Pipeline" timing diagrams across instruction1 through instruction5, labelled "parallel operation of 5-instruction". [slide 6]
- Cache Memory is characterised as "High-performance ; 1 clock access" and "Parallel Operation ; instruction/data flow". [slide 7]
- Fast Interrupt Response states "14Clocks (when INT handler is in cache)". [slide 8]

### Outline of Architecture (slide 10)

Nine bullets, verbatim. [slide 10]

- 1K-byte instruction cache memory
- 1 clock pitch pipeline
- 16-bit/32-bit instruction length
- 32 general-purpose registers (32-bit)
- 4G-byte linear address space
- Register/flag hazard interlocked by hardware
- Floating-point operation instructions (IEEE-754)
- Bit string instructions
- 16-levels of high-speed interrupt responses

### Register Set (slide 11)

- The slide is split into "Program Registers" and "System Registers", each a diagram. Neither register list appears as text in the transcription. [slide 11]

### Data Type (slide 12)

- Integer/Unsigned Integer sizes with bit ranges: Byte (B) 7..0; "Halfword (H" 15..0; "Word (W" 31..0; each labelled MSB and LSB. [slide 12]
- Floating Point number: bit range shown as "31 22" with fields S, exponent, mantissa. [slide 12]
- Bit String: fields "Bit Length" and "Bit Offset". [slide 12]

### Data Alignment (slide 13)

- Little Endian. [slide 13]
- "Data must align to their length". [slide 13]

### Instruction Alignment (slide 14)

- Little Endian. [slide 14]
- "Half-word(16-bit) alignment". [slide 14]

### Instruction Set (slide 15)

Verbatim category/function table. [slide 15]

| Category | Function |
| --- | --- |
| Data transfer | General reg ↔ General reg; General reg ↔ Memory |
| I/O | Input, Output |
| Arithmetic / Logical | Signed/ Unsigned add, sub, mul,, div; Compare; And, Or, Not, Exclusive-Or |
| Shift | Logical shift, Arithmetic shift |
| System | System Register load / store |
| Bitstring | Move, And, Not, Or, Exclusive-Or, Search |
| Floating | Add, Sub, Mul, Div, Compare, Convert |
| Branch | Jump, Conditional branch, Jump and link |
| Others | Trap; Return from interrupt; Nop; Halt; Compare and exchange |

### Instruction Format (slide 17)

- The slide is a figure only; no format text survives in the transcription. [slide 17]

### Offset Addressing Mode (slide 18)

- Load / Store form given as `Id 16bit[base],reg` (transcribed with a capital "I"; the deck elsewhere writes the load mnemonic as `ld`). [slide 18]

### 32-bit Immediate Load (slide 19)

- Immediate load uses two instructions: `movhi imm,reg` and `movea imm,reg`. [slide 19]

### Function Call Range (slide 20)

- Function call form given as `jal _func`, with the range shown in a figure only. [slide 20]

### Load / In (slide 22)

- Load performs sign extension; the example mnemonic is transcribed as `id.b` (capital "I"; the load byte mnemonic). [slide 22]
- In performs zero extension; the example mnemonic is `in.b`. [slide 22]

### Function Call (slide 23)

- "jal op. : return address is saved into r31 register". [slide 23]

### Bitstring Operation (slide 24)

- Search: "Search for the first 0 or 1 from the specified bit". [slide 24]
- Move: figure only. [slide 24]
- "Logical operation (BitBLT operation)": figure only. [slide 24]

### Floating Point Operation (slide 25)

- Single precision floating point operation, IEEE-754 standard. [slide 25]
- Performance = 0.9 M FLOPS (25MHz). [slide 25]
- Add, Sub, Mul, Div, Compare (26-44 execution clocks). [slide 25]
- Conversion (32 bit float → 32 bit integer). [slide 25]
- Floating data are handled in General Registers. [slide 25]

### Interrupt and Exception (slide 27)

- Interrupt: "Maskable interrupt (16 levels)". [slide 27]
- Interrupt: "Non-maskable interrupt" appears struck through and annotated "NOT IMPROVED". [slide 27]
- Exception list, verbatim: Double exception; Trap instruction; Address trap; Reserved op code; Zero division; Floating operation exception (6 types); Reset. [slide 27]

### Interrupt and exception flow slides (slides 28–31)

- "Maskable Interrupt": text is only "Maskable interrupt (INT) occurs"; the flow itself is a diagram. [slide 28]
- "Non-Maskable Interrupt": text is only "Non-maskable interrupt (NMI) occurs"; the flow itself is a diagram. [slide 29]
- "Exception Processing": diagram only, no text. [slide 30]
- "Return from Exception/Interrupt": diagram only, no text. [slide 31]

### Interlock (slides 33–35)

The interlock material occupies three slides; the transcription groups all of it under the single heading "Interlock" on slide 33.

- Interlock support covers load/store/flag interlock. [slide 33]
- "Hazard detection & interlock by H/W." [slide 33]
- "Transparent to assembler programming & debugging." [slide 33]
- "Small code size by reducing excessive instruction." [slide 33]
- "Better performance by inserting effective instruction." [slide 33]
- Case 1, "Changing base register just before load/store": General RISC has the assembler insert a software wait — `add r3,r6` / `nop` / `Id.w disp[r6],r10`. V800 has hardware detect the hazard and stall the pipeline — `add r3,r6` / `Id.w disp[r6],r10`. [slides 33–35]
- Case 2, "Conditional branch just after flag modification": General RISC — `cmp r6,r10` / `nop` / `bz`. V800 — `cmp r6,r10` / `bz`. [slides 33–35]

### Cache Implementation (slide 36)

| Property | Value |
| --- | --- |
| Capacity | 1K bytes |
| Mapping method | Direct mapping |
| Block size | 8 bytes |
| Subblock size | 4 bytes |

[slide 36]

### Cache Tips (slide 37)

- "Locality of program execution is very important." [slide 37]
- Loop (with many loop count) -> very good. [slide 37]
- Key for performance (ex. INT handler) -> good. [slide 37]
- Rarely executing -> poor. [slide 37]
- Executing only once (ex. boot routine) -> very poor. [slide 37]
- Cache "Can control by CHCW(cache control word) register", with three listed controls: Enable/Disable; Clear all/part; Dump/Restore to/from memory. [slide 37]

### Closing (slide 38)

- Closing slide: "NEC" / "NEC Electronics Inc." [slide 38]

## Specifications and procedures

### Execution Clock table (slide 16)

Verbatim, including the deck's footnote markers. [slide 16]

| Group | Instruction | Clocks |
| --- | --- | --- |
| move | `mov`, `movea` | 1 |
| load / store | `ld` \*\*\* | 2-5 |
| load / store | `st` \*\*\* | 1-4 |
| Integer/logical operation | `op reg, reg` | 1 |
| Integer/logical operation | `op imm, reg` | 1 |
| Integer/logical operation | `mul` | 13 |
| Integer/logical operation | `div` | 38 |
| Shift | `sha` | 1 |
| Shift | `shl`, `shr` | 1 |
| Floating operation | `addf.s` | 24 |
| Floating operation | `subf.s` | 26 |
| Floating operation | `mulf.s` | 27 |
| Floating operation | `divf.s` | 44 |
| branch \* | `jmp`, `jr` | 3 |
| branch \* | `jal` | 3 |
| branch \* | `Bcc` (taken) | 3 |
| branch \* | `Bcc` (not taken) | 1 |
| bitstring \*\* | `search` \*\*\* | 4 |
| bitstring \*\* | `move`, \*\*\* `logical` | 12 |

Footnotes, verbatim. [slide 16]

- "This value shows the case that the same instructions are executed"
- \* No hazard and cache hit
- \*\* Clock for word data
- \*\*\* 16-bit external data bus

### Flag Operation table (slide 21)

Columns are CY, OV, S, Z. Legend: "— : Not affected", "★: Affected", "0 : Cleared to 0". [slide 21]

| Instructions | CY | OV | S | Z |
| --- | --- | --- | --- | --- |
| `mov`, `movea`, `movhi`, `ld`, `st`, `in`, `out` | — | — | — | — |
| `add`, `addi`, `sub`, `cmp` | ★ | ★ | ★ | ★ |
| `mul`, `div`, `mulu`, `divu` | — | ★ | ★ | ★ |
| `and`, `or`, `xor`, `not`, `andi`, `ori`, `xori` | — | 0 | ★ | ★ |
| `shl`, `shr`, `sar` | ★ | 0 | ★ | ★ |
| `jmp`, `jr`, `jal`, `Bcond` | — | — | — | — |

### Mnemonics named anywhere in the deck

`mov`, `movea`, `movhi`, `ld`, `ld.w`, `ld.b` (transcribed `id.b`), `st`, `in`, `in.b`, `out`, `add`, `addi`, `sub`, `cmp`, `mul`, `mulu`, `div`, `divu`, `and`, `or`, `xor`, `not`, `andi`, `ori`, `xori`, `shl`, `shr`, `sar`, `sha`, `jmp`, `jr`, `jal`, `Bcc`/`Bcond`, `bz`, `nop`, `search`, `addf.s`, `subf.s`, `mulf.s`, `divf.s`. [slides 4, 16, 18, 19, 20, 21, 22, 23, 33]

## Constraints and requirements

- Data must align to their length. [slide 13]
- Instructions require half-word (16-bit) alignment. [slide 14]
- Byte order is Little Endian for both data and instructions. [slides 13, 14]
- The clock figures on the Execution Clock slide hold only under the stated conditions: same instructions executed repeatedly; branch figures assume no hazard and a cache hit; bitstring figures are for word data; the marked load/store and bitstring figures assume a 16-bit external data bus. [slide 16]
- The 14-clock interrupt response figure holds only "when INT handler is in cache". [slide 8]
- The 0.9 M FLOPS figure is quoted at 25MHz. [slide 25]
- The deck states that hardware interlock makes hazard handling "Transparent to assembler programming & debugging", in contrast to a "General RISC" where the assembler inserts a software wait. [slide 33]
- The deck ranks cache suitability by locality: loops with many iterations "very good"; performance-critical code such as an INT handler "good"; rarely executing code "poor"; code executing only once such as a boot routine "very poor". [slide 37]

## Stated gaps and ambiguities

- A large share of the deck's substance is in figures that the transcription preserves only as image references, so their content is absent from the text. Slides that are figure-only or nearly so: slide 3 (CISC vs. RISC comparison), slide 5 (Code Size Efficiency), slide 6 (pipeline timing), slide 7 (cache block diagram), slide 8 (interrupt response timing), slide 11 (both the Program Registers and System Registers lists), slide 12 (data type layouts), slides 13 and 14 (alignment diagrams), slide 17 (Instruction Format), slide 18 (offset addressing diagram), slide 19 (immediate load diagram), slide 20 (function call range diagram), slide 22 (extension diagrams), slide 23 (function call diagram), slide 24 (bitstring Move and Logical diagrams), slides 28–31 (all four interrupt/exception flow diagrams), slide 36 (cache diagrams).
- The Register Set slide names "Program Registers" and "System Registers" but the transcription contains no register names, numbers, or bit assignments for either. [slide 11]
- Slide 27 shows "Non-maskable interrupt" struck through and annotated "NOT IMPROVED". The deck does not explain the annotation, and slide 29 nonetheless presents a "Non-maskable interrupt (NMI) occurs" flow. [slides 27, 29]
- Slide 25 gives floating point execution clocks as "26-44" for Add, Sub, Mul, Div, Compare, while slide 16 lists `addf.s` at 24. The deck does not reconcile the two ranges, and gives no clock figure for a floating compare. [slides 16, 25]
- The interlock slides name the hardware "V800" while the rest of the deck says "V810". The deck does not state the relationship between the two names. [slide 33]
- Load mnemonics are transcribed inconsistently, appearing as `Id`/`id` (capital "I") on slides 18, 22 and 33 and as `ld` in the tables on slides 16 and 21. [slides 16, 18, 21, 22, 33]
- Slide 12 truncates the parenthesised type abbreviations: "Halfword (H" and "Word (W" have no closing parenthesis, and the floating point bit range reads "31 22" without the intermediate field boundaries.
- The Arithmetic / Logical row on slide 15 contains a doubled comma, "add, sub, mul,, div". [slide 15]
- Slide 16's bitstring rows place "move," and "logical" against a single clock figure of 12, so it is unclear whether 12 applies to both or only to move. [slide 16]
- Slide 24 lists three bitstring operations but only the Search line has explanatory text. [slide 24]
- The deck states "16-levels of high-speed interrupt responses" and "Maskable interrupt (16 levels)" but never lists the levels, their priorities, or their vector addresses. [slides 10, 27]
- The exception list includes "Floating operation exception (6 types)" without naming the six types. [slide 27]
- No slide states the address of any interrupt or exception vector. [whole deck]
- The transcription carries no slide numbers of its own; footer codes survive on only six slides (2, 3, 9, 21, 26, 32).
