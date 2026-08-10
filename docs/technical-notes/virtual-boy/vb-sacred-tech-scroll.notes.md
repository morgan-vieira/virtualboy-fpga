# Notes: Virtual Boy - Sacred Tech Scroll

## Source

- File: `vb-sacred-tech-scroll.htm`
- Type: hardware reference / specification (single-page HTML document)
- Extent: ~34,000 words of body text; 11 top-level parts (Memory Map, ROM Format, CPU, Communication Port, Game Pad, Game Pak, Timer, Wait Controller, VIP, VSU, System Reset) plus an About/References section
- Version or date stated in document: "May 21, 2026" (printed in the About section and again as the closing line)
- Author or publisher stated in document: "Written by Guy Perfect", "Produced for Planet Virtual Boy", `https://www.virtual-boy.com/` [About]

## Scope

The document is a complete hardware reference for the Nintendo Virtual Boy: the system memory map, the ROM image layout, the NVC/V810 CPU (registers, cache, instruction formats, exceptions, full instruction set and opcode map), and every peripheral — communication port, game pad, game pak, timer, wait controller, VIP (Virtual Image Processor) and VSU (Virtual Sound Unit) — closing with power-on reset state for each component. [document as a whole]

The document explicitly places some material out of scope: "Nintendo maintains a list of maker codes that is beyond the scope of this document." [ROM Format > ROM Header] It also states repeatedly, in bracketed "Editor's Note" blocks, that certain timings and behaviors are not yet established; those are recorded under [Stated gaps and ambiguities](#stated-gaps-and-ambiguities) rather than resolved.

The document is written as a descriptive reference, not a tutorial: it contains no worked example programs and no build or toolchain procedures, though it does record the operand-order conventions of two assembly notations.

## Key concepts

- **NVC** — Nintendo's modified NEC V810 CPU used in the Virtual Boy. "A handful of instructions were added by Nintendo, but otherwise the processor is the same as the stock V810." [CPU > Specifications]
- **Program registers** — the 32 general-purpose CPU registers `r0`–`r31`. [CPU > Register Set > Program Registers]
- **System registers** — 13 registers that are not directly usable by the program and that configure CPU operating behavior; accessed only via `LDSR`/`STSR`. [CPU > Register Set > System Registers]
- **Exception** — the document's general term for any event that breaks execution; it comes in three forms, called Exception, Interrupt and Address Trap. [CPU > Exceptions]
- **Duplexed exception** — an exception raised during the processing of another exception. [CPU > Exceptions > Duplexed Exception]
- **Fatal exception** — an exception raised during the processing of a duplexed exception; debugging information is written to the memory bus and the CPU halts permanently until reset. [CPU > Exceptions > Duplexed Exception]
- **Restore PC** — the value stored into a status-saving register when exception handling begins; either "current PC" (address of the current instruction) or "next PC" (address of the following instruction). [CPU > Exception Processing > Restore PC]
- **Bit string** — a contiguous sequence of bits defined by word address, bit offset (0–31) and length; length zero is valid. [CPU > Data Types; CPU > Bit Strings > Overview]
- **Character** — an 8×8-pixel, 2-bits-per-pixel graphic; "also known as a 'tile'". The atomic unit of graphics. [VIP > Overview; VIP > Characters]
- **Object** — a character placed anywhere on screen; "often called a 'sprite'". [VIP > Overview; VIP > Objects]
- **Background map** — a 64×64-character mosaic. [VIP > Overview; VIP > Background Maps]
- **Background** — a larger mosaic assembled from 1 to 8 background maps. [VIP > Worlds > Backgrounds]
- **World** — "the top-level unit of graphics", also known as a "window"; specifies a rectangular region where a background can be drawn. [VIP > Overview; VIP > Worlds > Overview]
- **Display frame** — the fixed 20 ms / 50 Hz interval that drives the physical display unit. [VIP > Drawing and Display Procedures > Frame Types]
- **Game frame** — the interval at which the VIP drawing procedure produces a new image; configured as a number of display frames via `FRMCYC`. [VIP > Drawing and Display Procedures > Frame Types]
- **Frequency value** — the document's term for a VSU channel's delay setting: "the delay setting as the 'frequency value'". [VSU > Frequency > Frequency Values]

## Content

### Memory Map

- The Virtual Boy memory bus is 27 bits wide and is organized by hardware component. [Memory Map]
- Component ranges: `0x00000000`–`0x00FFFFFF` VIP; `0x01000000`–`0x01FFFFFF` VSU; `0x02000000`–`0x02FFFFFF` Miscellaneous Hardware; `0x03000000`–`0x03FFFFFF` Unmapped; `0x04000000`–`0x04FFFFFF` Game Pak Expansion; `0x05000000`–`0x05FFFFFF` WRAM; `0x06000000`–`0x06FFFFFF` Game Pak RAM; `0x07000000`–`0x07FFFFFF` Game Pak ROM; `0x08000000`–`0xFFFFFFFF` mirroring of the memory map. [Memory Map]
- The upper 5 bits of any address in `0x08000000`–`0xFFFFFFFF` are masked, making the maximum effective address `0x07FFFFFF`. [Memory Map]
- Writes to `0x03000000`–`0x03FFFFFF` have no effect; reads in that range return zero. [Memory Map]
- WRAM is 64 KiB; its effective range is `0x05000000`–`0x0500FFFF`, and addresses in `0x05010000`–`0x05FFFFFF` have bits 16–23 masked. [Memory Map]
- WRAM is pseudostatic RAM with two initialization requirements: wait 200 µs before accessing, and perform 8 dummy read accesses before any other accesses. Software must account for this "or else its behavior is undefined." [Memory Map > WRAM]
- Miscellaneous hardware registers: `0x02000000` `CCR` (Link, Communication Control Register); `0x02000004` `CCSR` (Link, COMCNT Control Register); `0x02000008` `CDTR` (Link, Transmitted Data Register); `0x0200000C` `CDRR` (Link, Received Data Register); `0x02000010` `SDLR` (Game Pad, Serial Data Low Register); `0x02000014` `SDHR` (Game Pad, Serial Data High Register); `0x02000018` `TLR` (Timer, Timer Counter Low Register); `0x0200001C` `THR` (Timer, Timer Counter High Register); `0x02000020` `TCR` (Timer, Timer Control Register); `0x02000024` `WCR` (Game Pak, Wait Control Register); `0x02000028` `SCR` (Game Pad, Serial Control Register); `0x02000040`–`0x02FFFFFF` mirroring of the hardware component memory map. [Memory Map > Miscellaneous Hardware]
- Hardware I/O registers are intended to be accessed as bytes, but because they are spaced 4 bytes apart "any type of access can be used with them." [Memory Map > Miscellaneous Hardware]
- Writing to unmapped addresses in the miscellaneous hardware range "has no apparent effect", and all bits in any unlisted byte are undefined when read. [Memory Map > Miscellaneous Hardware]

### ROM Format

- The document states that memory addresses `0xFFFFFDE0` - `0xFFFFFFF` must contain specific kinds of data (the upper bound is printed with seven hexadecimal digits in the source). These correspond to `0x07FFFDE0`–`0x07FFFFFF` in the game pak ROM range. [ROM Format]
- Because of game pak ROM address mirroring, addresses starting at `0x07FFFDE0` are "traditionally located at the end of the ROM data, regardless of the size of the ROM module." [ROM Format]
- ROM header occupies `0xFFFFFDE0`–`0xFFFFFDFF`: `0xFFFFFDE0`–`0xFFFFFDF3` Title; `0xFFFFFDF4`–`0xFFFFFDF8` Reserved; `0xFFFFFDF9`–`0xFFFFFDFA` Maker code; `0xFFFFFDFB`–`0xFFFFFDFE` Game code; `0xFFFFFDFF` Version. [ROM Format > ROM Header]
- Title is the game's title in Shift JIS character encoding. [ROM Format > ROM Header]
- Reserved bytes "should be zeroes". [ROM Format > ROM Header]
- Maker code is a 2-character ASCII identifier for the game's developer; game code is a 4-character ASCII identifier for the game. [ROM Format > ROM Header]
- Version is an unsigned byte holding the minor version number; "the major version number is always 1." [ROM Format > ROM Header]
- Game codes for commercial software are printed on the packaging and game pak labels. [ROM Format > ROM Header]
- Exception handlers occupy `0xFFFFFE00`–`0xFFFFFFFF`, 16 bytes each: `0xFFFFFE00` game pad interrupt; `0xFFFFFE10` timer zero interrupt; `0xFFFFFE20` game pak interrupt; `0xFFFFFE30` communication interrupt; `0xFFFFFE40` VIP interrupt; `0xFFFFFE50`–`0xFFFFFEFF` unused; `0xFFFFFF00`–`0xFFFFFF5F` unused; `0xFFFFFF60` floating-point exception; `0xFFFFFF70`–`0xFFFFFF7F` unused; `0xFFFFFF80` zero division exception; `0xFFFFFF90` illegal opcode exception; `0xFFFFFFA0` `TRAP` (vector < 16); `0xFFFFFFB0` `TRAP` (vector ≥ 16); `0xFFFFFFC0` address trap; `0xFFFFFFD0` duplexed exception; `0xFFFFFFE0`–`0xFFFFFFEF` unused; `0xFFFFFFF0` reset. [ROM Format > Exception Handlers]
- The data at these addresses is CPU instructions; "At 16 bytes each, there is enough room to construct an address and jump to it." [ROM Format > Exception Handlers]

### CPU — Specifications and data types

- Specifications table: Name NVC; Bus width 16 bits; Clock speed 20.0 MHz; General registers 32; Instruction cache 1 KiB; Instruction set RISC; Manufacturer Nintendo; Word size 32 bits; Year 1995. [CPU > Specifications]
- The I/O bus is mapped to the memory bus: "all read and write instructions access the same data." [CPU > Specifications]
- Five data types: Byte (8-bit two's complement integer), Halfword (16-bit), Word (32-bit), Floating Short (32-bit IEEE 754-1985), Bit String. [CPU > Data Types]
- Floating Short: "Only normal real numbers and zero are accepted by the CPU: indefinites, NaNs and non-zero denormal values are regarded as invalid operands and cannot be processed." [CPU > Data Types]
- All multi-byte data types are little-endian. [CPU > Data Types]
- Memory accesses are aligned; an unaligned access has its lowest-order address bits ignored and is rounded down to the next lower multiple of the data type size. [CPU > Data Types]
- "Dedicated instructions exist for converting between word and floating short data types." [CPU > Data Types]

### CPU — Register set

- All CPU registers are 32 bits wide. [CPU > Register Set]
- `PC` holds the address of the current instruction; its lowest-order bit is always clear, so instructions always begin on a 16-bit boundary. [CPU > Register Set > Program Counter]
- When an instruction raises an exception, `PC` "will generally not be changed"; the handler is responsible for modifying the corresponding "PC" status-saving register before returning to prevent the exception from immediately recurring. [CPU > Register Set > Program Counter]
- Program registers with instruction-level significance: `r0` fixed zero; `r26` bit string destination bit offset; `r27` bit string source bit offset; `r28` bit string length; `r29` bit string destination word address / bits skipped in a search; `r30` upper 32 bits of integer multiplication, remainder of integer division, exchange value for `CAXI`, bit string source word address; `r31` return address of `JAL`. [CPU > Register Set > Program Registers]
- Compiler/assembler names: `r0` Zero Register; `r1` Assembler Reserved (for constructing 32-bit immediate data); `r2` `hp` Handler Stack Pointer; `r3` `sp` Stack Pointer (full-stack convention, points at the most recently added value); `r4` `gp` Global Pointer; `r5` `tp` Text Pointer; `r31` `lp` Link Pointer. [CPU > Register Set > Program Registers]
- `r2` (`hp`) and `r5` (`tp`) "have no designated purpose on Virtual Boy." [CPU > Register Set > Program Registers]
- Calling convention: `r6`–`r9` carry the first through fourth arguments; `r31` the return address; the return value is stored in `r10`. [CPU > Register Set > Calling Convention]
- The fifth argument is pointed to by `r3 + 16`, with subsequent arguments at consecutively higher addresses. The callee does not clean these up; `r3` is unchanged on return. [CPU > Register Set > Calling Convention]
- The 16 bytes preceding the fifth argument on the stack are "spill space in the caller's stack frame and may be written by the callee." [CPU > Register Set > Calling Convention]
- Registers `r1` and `r6` through `r31` are not guaranteed to be preserved across a function call. [CPU > Register Set > Calling Convention]
- Thirteen system registers, by index: 0 `EIPC`; 1 `EIPSW`; 2 `FEPC`; 3 `FEPSW`; 4 `ECR`; 5 `PSW`; 6 `PIR`; 7 `TKCW`; 24 `CHCW`; 25 `ADTRE`; 29, 30, 31 (unnamed). [CPU > Register Set > System Registers; CPU > CPU Control (system register numbers list)]
- The official names of system registers 29, 30 and 31 "are unknown"; 29 and 30 have "unknown significance", and 31 "calculates the absolute value of the number written into it." [CPU > Register Set > System Registers]
- `LDSR` to `ECR`, `PIR`, `TKCW` and register 30 "will have no effect". Reserved system register indexes also ignore `LDSR` and read as zero. [CPU > CPU Control]
- `ADTRE`: single 32-bit field `TA` (Trap Address), R/W; the memory address monitored for address traps; lowest-order bit always clear. [CPU > `ADTRE`]
- `CHCW` has two formats depending on context. Format 1: `CEN` bits 31–20 (12), `CEC` bits 19–8 (12). Format 2: `SA` bits 31–8 (24). Both share `RFU` bits 7–6 (2), `ICR` bit 5, `ICD` bit 4, `RFU` bits 3–2 (2), `ICE` bit 1, `ICC` bit 0. [CPU > `CHCW`]
- `CHCW` fields: `CEN` Clear Entry Number (W, index of first cache entry to clear, read as zeroes); `CEC` Clear Entry Count (W, read as zeroes); `SA` Spill-Out Base Address (W, higher 24 bits of the dump/restore address, lower 8 bits zero, read as zeroes); `ICR` Instruction Cache Restore (W); `ICD` Instruction Cache Dump (W); `ICE` Instruction Cache Enable (R/W); `ICC` Instruction Cache Clear (W). [CPU > `CHCW`]
- `CHCW` rules: if `CEN` ≥ 128, no dump or restore is performed; if `CEC` > 128, the number of entries cleared becomes 128; a clear operation stops after clearing entry 127; specifying more than one of `ICR`, `ICD`, `ICC` simultaneously is undefined. [CPU > `CHCW`]
- `ECR`: `FECC` (Fatal Error Cause Code) bits 31–16, `EICC` (Exception/Interrupt Cause Code) bits 15–0, both read-only. `ECR` cannot be modified by `LDSR`. [CPU > `ECR`]
- Status-saving registers: `EIPC`/`EIPSW` are used for a regular exception or interrupt; `FEPC`/`FEPSW` for a duplexed exception. `EIPC` and `FEPC` share `PC`'s format (lowest bit always clear); `EIPSW` and `FEPSW` share `PSW`'s format, and `PSW` reserved bits likewise cannot be written in them. [CPU > `EIPC`, `EIPSW`, `FEPC`, `FEPSW` - Status-saving registers]
- `PIR`: `RFU` bits 31–16 (read as zeroes), `PT` (Processor Type) bits 15–0 = `0x5346`. Read-only, fixed value `0x00005346`. [CPU > `PIR`]
- `PSW` layout: `RFU` 31–20 (12), `I` 19–16 (4), `NP` 15, `EP` 14, `AE` 13, `ID` 12, `RFU` 11–10 (2), `FRO` 9, `FIV` 8, `FZD` 7, `FOV` 6, `FUD` 5, `FPR` 4, `CY` 3, `OV` 2, `S` 1, `Z` 0. [CPU > `PSW`]
- `PSW` field meanings: `I` Interrupt Level — an interrupt whose level is less than `I` is masked; `NP` NMI Pending — set during processing of a duplexed exception or reset; `EP` Exception Pending — set during processing of an exception or interrupt; `AE` Address Trap Enable; `ID` Interrupt Disable — if set, all interrupts are masked; `FRO` floating reserved operand; `FIV` floating invalid; `FZD` floating zero divide (set when `DIVF.S` is executed with a divisor of zero); `FOV` floating overflow; `FUD` floating underflow; `FPR` floating precision; `CY` carry; `OV` overflow; `S` sign; `Z` zero. All are R/W. [CPU > `PSW`]
- `TKCW` layout: `RFU` 31–9 (23), `OTM` 8, `FIT` 7, `FZT` 6, `FVT` 5, `FUT` 4, `FPT` 3, `RDI` 2, `RD` 1–0. All fields read-only. [CPU > `TKCW`]
- `TKCW` is read-only with fixed value `0x000000E0`, corresponding to: `OTM` = 0 (invalid operand exceptions raised), `FIT` = 1, `FZT` = 1, `FVT` = 1, `FUT` = 0 (underflow exceptions not raised), `FPT` = 0 (precision degradation exceptions not raised), `RDI` = 0, `RD` = 0 (rounding to nearest in both cases). [CPU > `TKCW`]
- `TKCW` `RDI` values: 0 = "Same as RD", 1 = "Undocumented". `RD` values: 0 = "Toward nearest"; 1, 2 and 3 = "Undocumented". [CPU > `TKCW`]
- System register 29: 32-bit field marked `???`, R/W — "Unknown. All 32 bits of this field can be read and written." [CPU > `29` - System register 29]
- System register 30: 32-bit field marked `???`, read-only, fixed value `0x00000004`. [CPU > `30` - System register 30]
- System register 31: 32-bit field marked `???`, R/W, accepts any signed word; "Reading from this register will give the absolute value of the most recent value written to it." [CPU > `31` - System register 31]

### CPU — Instruction cache

- 1 KiB of instruction cache: 128 entries, block size 8 bytes each, 1,024 bytes total. [CPU > Instruction Cache]
- Each entry carries a tag holding the upper 22 bits of the memory address plus a validity bit. [CPU > Instruction Cache]
- Instruction fetch address is parsed as: Tag bits 31–10 (22), Index bits 9–3 (7), Offset bits 2–0 (3). [CPU > Instruction Cache]
- A cache entry is selected by Index; if it holds no valid data or its tag does not match Tag, the data is read from memory and stored into the entry. [CPU > Instruction Cache]
- During dump and restore, at the address given by `SA` in `CHCW`, all 128 8-byte blocks are stored in order, followed by all 128 4-byte tags — 1,536 bytes total. [CPU > Instruction Cache]
- Dumped/restored tag format: bits 31–28 unused (4) — "Tag memory in the cache is only 27 bits wide"; `NECRV` (NEC Reserved) bits 27–23 (5) — "The significance of this field is not documented"; `Valid` bit 22; `TAG` bits 21–0 (22). [CPU > Instruction Cache]
- Interrupts are postponed until dump and restore operations complete. [CPU > Instruction Cache]

### CPU — Instruction formats

- Instructions are fetched as halfword units and may be 16 or 32 bits; a common opcode field in the highest-order bits of the first halfword determines format and whether a second halfword is needed. [CPU > Instruction Formats]
- For a 32-bit instruction, the first halfword forms bits 0–15 (the upper 16 bits of the word) and the second halfword forms bits 16–31 (the lower 16 bits). [CPU > Instruction Formats]
- Format I (Register-Register, 16 bits): `opcode` 15–10 (6), `reg2` 9–5 (5), `reg1` 4–0 (5). `reg2` is destination and left-hand operand; `reg1` is source and right-hand operand. [CPU > Format I]
- Format II (Immediate-Register, 16 bits): `opcode` 15–10 (6), `reg2` 9–5 (5), then a 5-bit field that is variously `imm`, `cond` (4 bits with 1 unused bit at 4), `regID`, `vector`, or `sub-opcode`. [CPU > Format II]
- Format II field meanings: `imm` source value and right-hand operand; `cond` condition for `SETF`; `regID` zero-extended system register index for `LDSR`/`STSR`; `vector` zero-extended vector for `TRAP`; `sub-opcode` additional opcode bits for bit string instructions. Whether `imm` is sign-extended depends on the instruction. [CPU > Format II]
- Format III (Conditional Branch, 16 bits): `opcode` 15–13 (3), `cond` 12–9 (4), `disp` 8–0 (9, sign-extended). Displacement is measured in bytes relative to the address of the first byte of the instruction. [CPU > Format III]
- Format III is the only format without a 6-bit opcode field; the 3 bits of the `Bcond` opcode (`100`) "are not shared as the upper 3 bits of any other instruction's opcode." [CPU > Format III]
- Format IV (Middle-Distance Jump, 32 bits): `opcode` 6 bits, `disp` 26 bits, sign-extended, measured in bytes relative to the first byte of the instruction. [CPU > Format IV]
- Format V (3-Operand, 32 bits): `opcode` 6, `reg2` 5 (destination), `reg1` 5 (source and left-hand operand), `imm` 16 (source and right-hand operand). [CPU > Format V]
- Format VI (Load/Store, 32 bits): `opcode` 6, `reg2` 5 (data register), `reg1` 5 (base address register), `disp` 16 (sign-extended). Effective address = `reg1` + `disp`. [CPU > Format VI]
- Format VII (Extended, 32 bits): `opcode` 6, `reg2` 5, `reg1` 5, `sub-opcode` 6 (bits 31–26), `RFU` 10 (bits 25–16, ignored). [CPU > Format VII]

### CPU — Exceptions

- Three forms: Exception (instruction processing produced an error condition), Interrupt (a hardware component requested a program break), Address Trap (a hardware execute breakpoint triggered). [CPU > Exceptions]
- Every exception has a 16-bit code and a 32-bit handler address; the code is stored into `ECR` and the handler address into `PC`. [CPU > Exceptions]
- An instruction-raised exception occurs when the opcode or sub-opcode does not correspond with a valid instruction, when the operation cannot be performed with the given operands, or when `TRAP` is executed. [CPU > Exceptions > Exception]
- Interrupts are disabled by setting `ID` in `PSW`; `CLI` and `SEI` manipulate this flag directly, and `LDSR` can also configure it. [CPU > Exceptions > Interrupt]
- Each interrupting hardware component has a numeric level; greater levels take priority. An interrupt whose level is less than `I` in `PSW` is ignored. [CPU > Exceptions > Interrupt]
- A requested interrupt is not accepted until the current CPU instruction, or a cache dump or restore operation, has finished. [CPU > Exceptions > Interrupt]
- Interrupts are ignored during exception processing — when either `EP` or `NP` is set in `PSW`. [CPU > Exceptions > Interrupt]
- `HALT` stops all CPU activity until an interrupt request is accepted, then resumes with exception processing. [CPU > Exceptions > Interrupt]
- Address trap: with `ADTRE` set to the breakpoint address and `AE` set in `PSW`, if `PC` matches `ADTRE` prior to fetching the instruction at that address, an address trap exception is raised. [CPU > Exceptions > Address Trap]
- Restore PC is "current PC" for: any regular exception not raised by `TRAP`; any interrupt accepted during processing of a bit string instruction; an address trap. It is "next PC" for: the `TRAP` instruction; any interrupt not occurring during a bit string instruction. [CPU > Exception Processing > Restore PC]
- An interrupt is accepted only if all of: `ID` = 0, `EP` = 0, `NP` = 0 in `PSW`, and `I` in `PSW` is less than or equal to the interrupt's level. [CPU > Exception Processing > Interrupt Handling]
- Return from an exception is via `RETI`, which restores `PC` and `PSW` from the appropriate status-saving registers according to the `NP` flag of `PSW`. [CPU > Exception Processing > Returning from Exceptions]
- Exception list (Name / Type / Code / Level / Handler Address / Restore PC / Note): Reset, Interrupt, `0xFFF0`, –, `0xFFFFFFF0`, –, occurs at system power-on. Duplexed exception, Exception, –, –, `0xFFFFFFD0`, Current PC. VIP, Interrupt, `0xFE40`, 4, `0xFFFFFE40`, various video conditions. Communication, Interrupt, `0xFE30`, 3, `0xFFFFFE30`, completion of communication port transfer. Game Pak, Interrupt, `0xFE20`, 2, `0xFFFFFE20`, initiated by the game pak. Timer Zero, Interrupt, `0xFE10`, 1, `0xFFFFFE10`, the timer counter reached zero. Game Pad, Interrupt, `0xFE00`, 0, `0xFFFFFE00`, controller button press. Address trap, Address trap, `0xFFC0`, –, `0xFFFFFFC0`, Current PC. `TRAP` (vector < 16), Exception, `0xFFA0 + vector`, –, `0xFFFFFFA0`, Next PC. `TRAP` (vector ≥ 16), Exception, `0xFFA0 + vector`, –, `0xFFFFFFB0`, Next PC. Illegal opcode, Exception, `0xFF90`, –, `0xFFFFFF90`, Current PC. Zero division, Exception, `0xFF80`, –, `0xFFFFFF80`, Current PC. Floating-point reserved operand, Exception, `0xFF60`, –, `0xFFFFFF60`, Current PC. Floating-point invalid operation, Exception, `0xFF70`, –, `0xFFFFFF60`, Current PC. Floating-point zero division, Exception, `0xFF68`, –, `0xFFFFFF60`, Current PC. Floating-point overflow, Exception, `0xFF64`, –, `0xFFFFFF60`, Current PC. [CPU > List of Exceptions]
- For the five hardware interrupts the Restore PC entry is a note: "If an interrupt occurs during the processing of a bit string instruction, current PC is used. Otherwise, next PC is used." [CPU > List of Exceptions]
- The exception list is ordered by priority, earlier entries having higher priority; when two exceptions coincide the highest-priority one is processed. [CPU > List of Exceptions]
- Interrupts "cannot occur simultaneously with instruction exceptions because the CPU checks for interrupt requests in between executing instructions." Bit string instructions are not interrupted mid-processing; they are executed repeatedly and only update `PC` once they fully complete. [CPU > List of Exceptions]
- The reset interrupt is automatically acknowledged when the CPU is initialized; because `PSW` is initialized with `I` zero, "reset has no meaningful interrupt level." [CPU > List of Exceptions]
- If a floating-point instruction satisfies multiple error conditions (such as dividing NaN by zero), only the highest-priority one is processed and has its status flag set in `PSW`. [CPU > List of Exceptions]

### CPU — Instruction set

Columns in the document's instruction tables are Mnemonic, Opcode, Format, `Z`, `S`, `OV`, `CY`, Cycles, Name, Operation. A `✓` marks a flag the instruction affects, `0` a flag it clears, `-` a flag it leaves alone, and `*` a value the document describes in prose beneath the table rather than as a single figure.

- Register transfer: `MOV` (imm) `010000` II 1 cycle, `reg2 = (sign extend) imm`; `MOV` (reg) `000000` I 1 cycle, `reg2 = reg1`; `MOVEA` `101000` V 1 cycle, `reg2 = reg1 + (sign extend) imm`; `MOVHI` `101111` V 1 cycle, `reg2 = reg1 + (imm << 16)`. None affect status flags. [CPU > Memory and Register > Register Transfer]
- `MOVEA` and `MOVHI` exist to populate a register with 32 bits of immediate data without modifying `PSW` status flags; because `MOVEA` sign-extends, care is needed to store the appropriate upper halfword via `MOVHI`. [CPU > Memory and Register > Register Transfer]
- Load and input: `IN.B` `111000`, `IN.H` `111001`, `IN.W` `111011`, `LD.B` `110000`, `LD.H` `110001`, `LD.W` `110011`, all Format VI, no flags affected. `IN.*` zero-extend; `LD.B`/`LD.H` sign-extend. [CPU > Memory and Register > Load and Input]
- Halfword operations mask the lowest bit of the effective address to 0; word operations mask the two lowest bits. [CPU > Memory and Register > Load and Input; > Store and Output]
- Because the I/O bus is mapped to the memory bus, input instructions access the same data as load instructions and are "nearly identical in function, except the input instructions zero-extend the data being read whereas the load instructions sign-extend it." [CPU > Memory and Register > Load and Input]
- Load cycle counts: 1 cycle when used immediately after an instruction that takes many cycles and does not conflict with the load; 4 cycles when immediately following another load instruction; 5 cycles in an isolated context. [CPU > Memory and Register > Load and Input]
- Store and output: `OUT.B` `111100`, `OUT.H` `111101`, `OUT.W` `111111`, `ST.B` `110100`, `ST.H` `110101`, `ST.W` `110111`, all Format VI, no flags affected. Byte forms write `reg2 AND 0xFF`; halfword forms write `reg2 AND 0xFFFF`. Output and store instructions are "identical in function." [CPU > Memory and Register > Store and Output]
- Store cycle counts: 1 cycle for the first two consecutive executions of store instructions; 4 cycles for subsequent consecutive executions. [CPU > Memory and Register > Store and Output]
- Arithmetic: `ADD` (imm) `010001` II 1; `ADD` (reg) `000001` I 1; `ADDI` `101001` V 1; `CMP` (imm) `010011` II 1; `CMP` (reg) `000011` I 1; `DIV` `001001` I 38; `DIVU` `001011` I 36; `MUL` `001000` I 13; `MULU` `001010` I 13; `SUB` `000010` I 1. [CPU > Arithmetic]
- `ADD`, `ADDI`, `CMP`, `SUB` affect `Z`, `S`, `OV`, `CY`. `DIV` affects `Z`, `S`, `OV`; `DIVU` affects `Z`, `S` and clears `OV` to 0; `MUL`/`MULU` affect `Z`, `S`, `OV`. `CY` is unaffected by the multiply and divide instructions. [CPU > Arithmetic]
- Compare operations perform subtraction, update flags and discard the result. [CPU > Arithmetic]
- Division produces a quotient rounded toward zero and a remainder sharing the dividend's sign; the remainder is stored into `r30` first, then the result into `reg2`. Division by zero raises a Zero Division exception with code `0xFF80` and restore PC of current PC. [CPU > Arithmetic]
- Multiplication produces a 64-bit result: the upper 32 bits go to `r30` first, then the lower 32 bits to `reg2`. [CPU > Arithmetic]
- `OV` is set when: addition operands share a sign and the result has the opposite sign; subtraction operands have opposite signs and the left operand and result have opposite signs; `DIV` divides `0x80000000` by −1 (result `0x80000000`, remainder zero); or the full 64-bit multiplication result differs from sign-extending (signed) or zero-filling (unsigned) the lower 32 bits of the product. [CPU > Arithmetic]
- `CY` is set when addition or subtraction results in unsigned wrap-around; the document's example is that "carry will be set when subtracting an unsigned value from a lesser value." [CPU > Arithmetic]
- `Z` is set when the result of any operation is zero and cleared otherwise; `S` is a copy of the highest-order bit of the result. "For multiply operations, only the lower 32 bits of the result are considered" for both flags. [CPU > Arithmetic]
- Bitwise: `AND` `001101` I; `ANDI` `101101` V; `NOT` `001111` I; `OR` `001100` I; `ORI` `101100` V; `SAR` (imm) `010111` II; `SAR` (reg) `000111` I; `SHL` (imm) `010100` II; `SHL` (reg) `000100` I; `SHR` (imm) `010101` II; `SHR` (reg) `000101` I; `XOR` `001110` I; `XORI` `101110` V. All take 1 cycle and clear `OV` to 0. [CPU > Bitwise]
- `ANDI` sets `Z`, clears `S` to 0 and clears `OV` to 0; the other logical instructions affect `Z` and `S`. Shift instructions additionally affect `CY`. [CPU > Bitwise]
- Register-operand shifts use `reg1 AND 0x1F` as the shift amount; immediate shifts zero-extend `imm`. [CPU > Bitwise]
- `CY` after a shift is "a copy of the last bit shifted out of the register during a shift operation, or cleared if the shift amount was zero." [CPU > Bitwise]
- CPU control: `Bcond` opcode `100` Format III; `HALT` `011010` II (cycles listed as "–"); `JAL` `101011` IV 3; `JMP` `000110` I 3; `JR` `101010` IV 3; `LDSR` `011100` II 8; `RETI` `011001` II 10; `STSR` `011101` II 8; `TRAP` `011000` II 15. [CPU > CPU Control]
- `LDSR` and `RETI` are marked `*` in all four flag columns; the other CPU control instructions do not modify flags. [CPU > CPU Control]
- `Bcond` takes 1 cycle when the branch is not taken and 3 cycles when taken. [CPU > CPU Control]
- Status flags in `PSW` are only modified by `LDSR` when `PSW` itself is the target system register, and are then determined directly by the value loaded. [CPU > CPU Control]
- `TRAP` raises an exception with code `0xFFA0 + vector` and a restore PC of next PC. [CPU > CPU Control]
- Branch and jump effective addresses have their lowest bit masked to a 16-bit boundary because the lowest bit of `PC` is always clear. [CPU > CPU Control]
- Condition codes shared by `Bcond` and `SETF` (value / `Bcond` mnemonic / condition / test): 0 `BV` Overflow `OV = 1`; 1 `BC`,`BL` Carry/Lower `CY = 1` (unsigned); 2 `BE`,`BZ` Equal/Zero `Z = 1`; 3 `BNH` Not higher `(CY OR Z) = 1` (unsigned); 4 `BN` Negative `S = 1`; 5 `BR` Always; 6 `BLT` Less than `(OV XOR S) = 1` (signed); 7 `BLE` Less than or equal `((OV XOR S) OR Z) = 1` (signed); 8 `BNV` Not overflow `OV = 0`; 9 `BNC`,`BNL` Not carry/Not lower `CY = 0` (unsigned); 10 `BNE`,`BNZ` Not equal/Not zero `Z = 0`; 11 `BH` Higher `(CY OR Z) = 0` (unsigned); 12 `BP` Positive `S = 0`; 13 `NOP` Not always, never branches; 14 `BGE` Greater than or equal `(OV XOR S) = 0` (signed); 15 `BGT` Greater than `((OV XOR S) OR Z) = 0` (signed). [CPU > CPU Control (Condition Numbers)]
- `SETF` mnemonics for the same 16 condition values are `V`, `C`/`L`, `E`/`Z`, `NH`, `N`, `T` (always 1), `LT`, `LE`, `NV`, `NC`/`NL`, `NE`/`NZ`, `H`, `P`, `F` (always 0), `GE`, `GT`. [CPU > Miscellaneous > `SETF`]
- Floating-point instructions are Format VII sharing opcode `111110`, identified by sub-opcode: `ADDF.S` `000100` 9–28 cycles; `CMPF.S` `000000` 7–10; `CVT.SW` `000011` 9–14; `CVT.WS` `000010` 5–16; `DIVF.S` `000111` 44; `MULF.S` `000110` 8–30; `SUBF.S` `000101` 12–28; `TRNC.SW` `001011` 9–14. [CPU > Floating-Point]
- All floating-point instructions affect `Z` and `S`, clear `OV` to 0, and set `FRO` except `CVT.WS`; `CY` is affected by all except `CVT.SW` and `TRNC.SW`. `FIV` is set by `CVT.SW`, `TRNC.SW` and `DIVF.S`; `FZD` only by `DIVF.S`; `FOV` and `FUD` by `ADDF.S`, `SUBF.S`, `MULF.S` and `DIVF.S`; `FPR` by all except `CMPF.S`. [CPU > Floating-Point]
- `CVT.SW` rounds to the nearest integer; `TRNC.SW` rounds toward zero. [CPU > Floating-Point]
- For floating-point results, `CY` and `S` are both copies of the highest-order bit of the result. [CPU > Floating-Point]
- Floating-point status conditions (flag / code / name / condition): `FRO` `0xFF60` Reserved operand — either operand is a NaN, an indefinite, or a non-zero denormal; `FIV` `0xFF70` Invalid operation — a conversion or truncation on a value beyond word range, or `DIVF.S` dividing zero by zero; `FZD` `0xFF68` Zero division — `DIVF.S` dividing non-zero by zero; `FOV` `0xFF64` Overflow; `FUD` (no code) Underflow — zero is used as the result; `FPR` (no code) Precision degradation — underflow did not occur and the result was rounded with loss of precision. [CPU > Floating-Point]
- Conditions with a code raise an exception with that code; the list is priority-ordered and only the highest-priority satisfied condition is processed. Flags are set in `PSW` prior to raising an exception. [CPU > Floating-Point]
- Bit strings are stored in memory least-significant to most-significant within words and by address across words; a bit string extending above bit 31 of word address `0xFFFFFFFC` or below bit 0 of word address `0x00000000` wraps to the other end of the address space. [CPU > Bit Strings > Overview]
- Bit string registers: `r30` source word address (lowest 2 bits cleared prior to operation); `r29` destination word address (lowest 2 bits cleared) or search skip counter (not modified prior to operation); `r28` string length (all 32 bits unsigned); `r27` source bit offset (highest 27 bits cleared); `r26` destination bit offset (highest 27 bits cleared). [CPU > Bit Strings > Overview]
- Search operations use the registers designated for the "source" bit string. [CPU > Bit Strings > Overview]
- "Bit string operations are carried out in either an 'upward' or 'downward' direction. In an upwards operation, the offset of bits within a word increases and the words in memory increase in address. Conversely, a downward operation observes decreased bit offsets and word addresses." [CPU > Bit Strings > Overview]
- Bit string instructions are Format II sharing opcode `011111`, identified by sub-opcode. [CPU > Bit Strings > Overview]
- Bitwise bit string sub-opcodes: `ORBSU` `01000`; `ANDBSU` `01001`; `XORBSU` `01010`; `MOVBSU` `01011`; `ORNBSU` `01100`; `ANDNBSU` `01101`; `XORNBSU` `01110`; `NOTBSU` `01111`. None affect status flags. [CPU > Bit Strings > Bitwise]
- Search sub-opcodes: `SCH0BSU` `00000`; `SCH0BSD` `00001`; `SCH1BSU` `00010`; `SCH1BSD` `00011`. All affect `Z` only. [CPU > Bit Strings > Search]
- Bit string instructions process one word of output per invocation and only advance `PC` after the entire string is processed; registers `r26`–`r30` are updated each invocation. The document states this "facilitates the handling of interrupts even in the midst of time-consuming bit string operations." [CPU > Bit Strings > Bitwise]
- After a bitwise bit string instruction completes, the source and destination bit strings point at the next higher bit in memory and `r28` is zero. [CPU > Bit Strings > Bitwise]
- Each invocation processes all bits for the current destination word, leaving the next destination word to begin at bit offset zero. [CPU > Bit Strings > Bitwise]
- If source and destination bit strings overlap and the destination begins later, the source may be corrupted; "Due to read buffering in the CPU, this will only occur during an invocation of a bit string instruction when the destination bit string begins 64 or more bits after the source bit string." [CPU > Bit Strings > Bitwise]
- Search: `Z` is set at the start of processing and only cleared if the specified bit was found. Each invocation processes one word of input, leaving the next source word to begin at bit offset zero (upward) or 31 (downward). `r29` is incremented for each non-matching bit processed. [CPU > Bit Strings > Search]
- After a search completes, `r30`/`r27` point to the next bit following the matched bit (if found) or following the entire string (if not), and `r28` holds the number of remaining bits including the one pointed to. [CPU > Bit Strings > Search]
- `CAXI` (Compare and Exchange Interlocked): opcode `111010`, Format VI, 26 cycles, affects `Z`, `S`, `OV`, `CY`. Operands: `reg1` base address of lock word, `disp` displacement, `reg2` compare value, `r30` exchange value. [CPU > Miscellaneous > `CAXI`]
- "Virtual Boy only has one processor, so the `CAXI` instruction has limited utility." [CPU > Miscellaneous > `CAXI`]
- `SETF`: opcode `010010`, Format II, 1 cycle, no flags modified; stores `0x00000001` into `reg2` if the condition is true, otherwise `0x00000000`. The `cond` field is 4 bits. [CPU > Miscellaneous > `SETF`]
- The document states `SETF` exists to evaluate simple conditional operations without branching, since "Branching disrupts the pipeline flow and takes more cycles than the corresponding `SETF` implementations", giving absolute value and sign as examples. [CPU > Miscellaneous > `SETF`]
- Nintendo standalone instructions: `CLI` `010110` Format II 12 cycles (`ID = 0`); `SEI` `011110` Format II 12 cycles (`ID = 1`). Neither affects status flags. [CPU > Nintendo > Standalone]
- Nintendo extended instructions (Format VII, opcode `111110`, identified by sub-opcode): `MPYHW` `001100` 9 cycles, `reg2 = reg2 * (reg1 << 15 >> 15 (sign-propagating))`; `REV` `001010` 22 cycles, `reg2 = ReverseBits(reg1)`; `XB` `001000` 6 cycles, `reg2 = (reg2 AND 0xFFFF0000) OR ((reg2 << 8) AND 0xFF00) OR ((reg2 >> 8) AND 0x00FF)`; `XH` `001001` 1 cycle, `reg2 = (reg2 >> 16 (zero-filling)) OR (reg2 << 16)`. None affect status flags. [CPU > Nintendo > Extended]
- `MPYHW` performs a 32-bit signed multiplication whose right-hand operand is produced by sign-extending the lower 17 bits of `reg1`. [CPU > Nintendo > Extended]

### CPU — Assembly notation

- General conventions in official V810 assembly notation: with multiple operands the destination is on the right; with three operands the immediate value is on the left; read/write target addresses are written as displacement followed by base register in square brackets (displacement may be omitted if zero); jump and branch targets are written as absolute addresses, not relative displacements. [CPU > Assembly Notation]
- `Bcond` is written as a one-operand instruction using the condition's mnemonic, except `NOP`, which is written with zero operands. [CPU > Assembly Notation]
- `JMP` encloses its operand in square brackets "although the operation does not perform an indirection". [CPU > Assembly Notation]
- `LDSR` and `STSR` may use either the symbolic name of the system register or its numeric index. [CPU > Assembly Notation]
- `SETF` has two notations. "V810": a two-operand instruction whose first operand is the condition's mnemonic or numeric code. "IAR": a one-operand instruction where the mnemonic concatenates "SETF" with the condition's mnemonic (for example `SETFNZ reg2`). [CPU > Assembly Notation]
- The document states the "V810" notation is used by official NEC V810 documents, the GNU assembler, Nintendo's own Virtual Boy development tools, and NEC/Renesas-produced development tools, and that "In the final draft of the V810 specification, this was the notation that was intended to be used." [CPU > Assembly Notation]
- The document states the "IAR" notation "has been known to be used by NEC in V810 presentations during development, the IAR Systems V850 assembler, and Hudson Soft's development tools for PC-FX." [CPU > Assembly Notation]
- A per-instruction notation table lists operand order for every mnemonic in the instruction set. The forms it gives are: `MNEM reg1, reg2` for all Format I register-register operations and all floating-point operations (`ADD`, `AND`, `CMP`, `DIV`, `DIVU`, `MOV`, `MPYHW`, `MUL`, `MULU`, `NOT`, `OR`, `REV`, `SAR`, `SHL`, `SHR`, `SUB`, `XOR`, `ADDF.S`, `CMPF.S`, `CVT.SW`, `CVT.WS`, `DIVF.S`, `MULF.S`, `SUBF.S`, `TRNC.SW`); `MNEM imm, reg2` for the Format II immediate forms (`ADD`, `CMP`, `MOV`, `SAR`, `SHL`, `SHR`); `MNEM imm, reg1, reg2` for the Format V three-operand instructions (`ADDI`, `ANDI`, `MOVEA`, `MOVHI`, `ORI`, `XORI`); `MNEM disp[reg1], reg2` for loads and inputs (`LD.B`, `LD.H`, `LD.W`, `IN.B`, `IN.H`, `IN.W`) and for `CAXI`; `MNEM reg2, disp[reg1]` for stores and outputs (`ST.B`, `ST.H`, `ST.W`, `OUT.B`, `OUT.H`, `OUT.W`); `JAL address`, `JR address`, `JMP [reg1]`; `LDSR reg2, regID` and `STSR regID, reg2`; `TRAP vector`; `XB reg2` and `XH reg2`; `SETF cond, reg2` (V810 notation) or `SETFNZ reg2` (IAR notation); `BNZ address` and the other `Bcond` mnemonics as one-operand instructions; and no operands at all for `CLI`, `SEI`, `HALT`, `RETI`, `NOP` and every bit string mnemonic. [CPU > Assembly Notation]

### CPU — Opcode map

- Executing any invalid opcode or sub-opcode raises an exception with code `0xFF90` and a restore PC of current PC. [CPU > Opcode Map]
- Primary opcode map: `000000` I `MOV`; `000001` I `ADD`; `000010` I `SUB`; `000011` I `CMP`; `000100` I `SHL`; `000101` I `SHR`; `000110` I `JMP`; `000111` I `SAR`; `001000` I `MUL`; `001001` I `DIV`; `001010` I `MULU`; `001011` I `DIVU`; `001100` I `OR`; `001101` I `AND`; `001110` I `XOR`; `001111` I `NOT`; `010000` II `MOV`; `010001` II `ADD`; `010010` II `SETF`; `010011` II `CMP`; `010100` II `SHL`; `010101` II `SHR`; `010110` II `CLI`; `010111` II `SAR`; `011000` II `TRAP`; `011001` II `RETI`; `011010` II `HALT`; `011011` Invalid; `011100` II `LDSR`; `011101` II `STSR`; `011110` II `SEI`; `011111` II bit string group; `100` III `Bcond`; `101000` V `MOVEA`; `101001` V `ADDI`; `101010` IV `JR`; `101011` IV `JAL`; `101100` V `ORI`; `101101` V `ANDI`; `101110` V `XORI`; `101111` V `MOVHI`; `110000` VI `LD.B`; `110001` VI `LD.H`; `110010` Invalid; `110011` VI `LD.W`; `110100` VI `ST.B`; `110101` VI `ST.H`; `110110` Invalid; `110111` VI `ST.W`; `111000` VI `IN.B`; `111001` VI `IN.H`; `111010` VI `CAXI`; `111011` VI `IN.W`; `111100` VI `OUT.B`; `111101` VI `OUT.H`; `111110` VII floating-point and Nintendo group; `111111` VI `OUT.W`. [CPU > Opcode Map]
- Bit string sub-opcode map (opcode `011111`): `00000` `SCH0BSU`; `00001` `SCH0BSD`; `00010` `SCH1BSU`; `00011` `SCH1BSD`; sub-opcodes between `00011` and `01000` are Invalid; `01000` `ORBSU`; `01001` `ANDBSU`; `01010` `XORBSU`; `01011` `MOVBSU`; `01100` `ORNBSU`; `01101` `ANDNBSU`; `01110` `XORNBSU`; `01111` `NOTBSU`; all higher sub-opcodes Invalid. [CPU > Opcode Map]
- Format VII sub-opcode map (opcode `111110`): `000000` `CMPF.S`; `000001` Invalid; `000010` `CVT.WS`; `000011` `CVT.SW`; `000100` `ADDF.S`; `000101` `SUBF.S`; `000110` `MULF.S`; `000111` `DIVF.S`; `001000` `XB`; `001001` `XH`; `001010` `REV`; `001011` `TRNC.SW`; `001100` `MPYHW`; all higher sub-opcodes Invalid. [CPU > Opcode Map]

### Communication Port

- The port is labeled "EXT." on the underside of the unit next to the controller port. "Although a link cable was developed for use with the system, no commercial games made use of it and the cable itself was never made available to consumers." [Communication Port > Overview]
- Communication exchanges 8 bits at a time; "The hardware controls the entire communication operation, exchanging bits at a rate of 50 KHz per bit for a total of 160 µs." [Communication Port > Overview]
- An auxiliary signal can negotiate communication status independently of the data bits. [Communication Port > Overview]
- Pinout (looking into the port from the bottom of the unit): 1 COMCNT; 2 +5V DC; 3 Communication clock; 4 Data receive; 5 Sync in; 6 Sync out; 7 Ground; 8 Data transmit. [Communication Port > Pinout]
- Link cable wiring: 1↔1 COMCNT; 2 and 2 not connected; 3↔3 communication clock; 4←8 (data receive from data transmit); 5←6 (sync in from sync out); 6 and 5 not connected; 7↔7 ground; 8→4. [Communication Port > Pinout]
- "+5V DC is not connected because it is not used in link communications. It can be used to power some external device." [Communication Port > Pinout]
- "Sync in and Sync out do not form a round-trip connection in a link cable because doing so would result in clock feedback." [Communication Port > Pinout]
- `CCR` at `0x02000000`: `C-Int-Inh` bit 7 (R/W), unused bits 6–5, `C-Clk-Sel` bit 4 (R/W), unused bit 3, `C-Start` bit 2 (W), `C-Stat` bit 1 (R), unused bit 0. Unused bits "have no function and are set when read." [Communication Port > Communication Control]
- `C-Int-Inh`: when clear the communication interrupt is enabled; when set it is acknowledged and disabled. `C-Clk-Sel`: 0 = internal clock, 1 = external (another unit's) clock. `C-Start`: setting begins a communication operation; always set when read. `C-Stat`: set while communication is underway. [Communication Port > Communication Control]
- Data in `CDTR` is sent and received data is loaded into `CDRR`. [Communication Port > Communication Control]
- With the external clock selected the unit waits for a signal from a linked unit; with the internal clock the operation begins immediately. [Communication Port > Communication Control]
- "If the internal clock is selected and `C-Start` is set without another unit waiting for an external clock, a peerless communication will be performed immediately and the bits in `CDRR` will be undefined." [Communication Port > Communication Control]
- Setting `C-Start` while `C-Stat` is already set does nothing. Changing the clock selection while `C-Stat` is set changes only the clock source and does not abort the operation. If both units await an external clock and one switches to internal (with or without writing `C-Start`), the communication is carried out normally. [Communication Port > Communication Control]
- "A communication operation cannot be canceled once initiated. The only way `C-Stat` will be cleared is when the operation completes." [Communication Port > Communication Control]
- `CCSR` at `0x02000004`: `CC-Int-Inh` bit 7 (R/W), unused bits 6–5, `CC-Int-Lev` bit 4 (R/W), `CC-Sig` bit 3 (R/W), `CC-Smp` bit 2 (R), `CC-Wr` bit 1 (R/W), `CC-Rd` bit 0 (R). [Communication Port > Signal Control]
- `CC-Rd` on both connected units is the bitwise AND of the `CC-Wr` bits on both units. `CC-Smp` on both units is the bitwise AND of the `CC-Sig` bits on both units, further ANDed with the value of `CC-Rd`. [Communication Port > Signal Control]
- With no second unit connected, `CC-Rd` and `CC-Smp` are processed "as though a connected unit had the same `CCSR` configuration." [Communication Port > Signal Control]
- When a communication operation completes and `CC-Smp` updates, its value is compared with `CC-Int-Lev`; if they match the interrupt condition is satisfied and raised if `CC-Int-Inh` is clear. [Communication Port > Signal Control]
- `CDTR` at `0x02000008` (read/write) and `CDRR` at `0x0200000C` (read-only) are both 8 bits of software-assigned data. [Communication Port > Data Registers]
- Two interrupt sources exist: "Communication" (configured in `CCR`, on any completed operation) and "COMCNT Input" (configured in `CCSR`, when `CC-Int-Lev` and `CC-Smp` match). Both request an interrupt with code `0xFE30` and must be acknowledged individually — by setting `C-Int-Inh` in `CCR` and `CC-Int-Inh` in `CCSR` respectively. [Communication Port > Communication Interrupt]

### Game Pad

- The game pad is an 8-direction, 6-button controller that also supplies power to the system; it was manufactured with a battery pack accepting 6 AA batteries, and an A/C adapter was sold separately. [Game Pad]
- Layout diagram labels: Front — Left D-pad, Select, Start, Power, B, A, Right D-pad; Back — R, L. [Game Pad > Layout]
- Game pad port pinout (looking into it from the bottom of the unit): 1 Data; 2 +5V DC; 3 Reset; 4 Clock; 5 Ground; 6 Power (VCC). [Game Pad > Pinout]
- Button state is read one bit at a time over a serial port using two signals: one to reset the process and one to clock bits back to the console. [Game Pad > Game Pad Control]
- `SCR` at `0x02000028`: `K-Int-Inh` bit 7 (R/W), unused bit 6, `Para/Si` bit 5 (R/W), `Soft-Ck` bit 4 (R/W), unused bit 3, `HW-SI` bit 2 (W), `SI-Stat` bit 1 (R), `S-Abt/Dis` bit 0 (R/W). Unused bits "have no function and are set when read." [Game Pad > Game Pad Control]
- `Para/Si` when set sends a latch signal resetting the game pad's read operation; it should be cleared before using `Soft-Ck` "or else the operation will be repeatedly reset." [Game Pad > Game Pad Control > Software Read]
- Writing to `Soft-Ck` sends the inverse bit to the game pad (0 becomes 1 and vice versa). [Game Pad > Game Pad Control > Software Read]
- `HW-SI` initiates a hardware read and is always set when read; setting it while a hardware read is already underway has no effect. `SI-Stat` is set while a hardware read is underway. `S-Abt/Dis` cancels an active hardware read immediately. [Game Pad > Game Pad Control > Hardware Read]
- "The hardware read operation clocks buttons at a rate of 31.25 KHz per button for a total of 512 µs. This is significantly slower than the speeds that can be achieved through a software read." [Game Pad > Game Pad Control > Hardware Read]
- Key input interrupt: when a hardware read completes and `K-Int-Inh` is clear, an interrupt is raised if any data register bit from 15 through 4 is set, but is not raised if any bit from 3 through 1 is set. Its code is `0xFE00`. [Game Pad > Game Pad Control > Key Input Interrupt]
- "Since the standard Virtual Boy controller always sets bit 1, it is impossible for it to raise a key input interrupt." [Game Pad > Game Pad Control > Key Input Interrupt]
- `SDLR` at `0x02000010` and `SDHR` at `0x02000014` are read-only and together hold a 16-bit value: bit 15 `RD` right D-pad down; 14 `RL` right D-pad left; 13 `SEL` Select; 12 `STA` Start; 11 `LU` left D-pad up; 10 `LD` left D-pad down; 9 `LL` left D-pad left; 8 `LR` left D-pad right; 7 `RR` right D-pad right; 6 `RU` right D-pad up; 5 `LT` L button; 4 `RT` R button; 3 `B`; 2 `A`; 1 `SGN` signature; 0 `PWR` low battery. [Game Pad > Data Registers]
- "When using the standard Virtual Boy controller, `SGN` is always set." [Game Pad > Data Registers]

### Game Pak

- A game pak is a cartridge containing a ROM module and optionally a RAM module, battery and/or other circuitry. [Game Pak]
- "The game pak is able to request an interrupt with a code of `0xFE20`. No commercial game paks make use of this." [Game Pak]
- Allocated ranges: `0x04000000`–`0x04FFFFFF` Game Pak Expansion; `0x06000000`–`0x06FFFFFF` Game Pak RAM; `0x07000000`–`0x07FFFFFF` Game Pak ROM. [Game Pak > Memory]
- The game pak expansion range "was not used in any commercial game pak." [Game Pak > Memory]
- Commercial game paks containing RAM modules were battery-backed SRAM. Every game pak must supply program data, typically from a ROM module. [Game Pak > Memory]
- "In all commercial game paks, the sizes in bytes of the ROM and RAM (if present) data are powers of 2." Addresses exceeding the data size have their upper bits masked, producing mirrors. [Game Pak > Memory]
- 60-pin pinout (odd pins on one row, even on the other, seen looking at the bottom of the cartridge): 1 Ground; 2 Ground; 3 RAM write enable; 4 Expansion select; 5 Expansion write enable; 6 RAM select; 7 Reset; 8 +5V DC; 9 Interrupt request; 10 Address 23; 11 Address 19; 12 Address 22; 13 Address 18; 14 Address 21; 15 Address 8; 16 Address 20; 17 Address 7; 18 Address 9; 19 Address 6; 20 Address 10; 21 Address 5; 22 Address 11; 23 Address 4; 24 Address 12; 25 Address 3; 26 Address 13; 27 Address 2; 28 Address 14; 29 Address 1; 30 Address 15; 31 ROM select; 32 Address 16; 33 Ground; 34 Address 17; 35 Output enable; 36 +5V DC; 37 Data 0; 38 Data 15; 39 Data 8; 40 Data 7; 41 Data 1; 42 Data 14; 43 Data 9; 44 Data 6; 45 Data 2; 46 Data 13; 47 Data 10; 48 Data 5; 49 Data 3; 50 Data 12; 51 Data 11; 52 Data 4; 53 +5V DC; 54 +5V DC; 55 Right audio in; 56 Left audio in; 57 Right audio out; 58 Left audio out; 59 Ground; 60 Ground. [Game Pak > Pinout]
- The expansion, ROM and RAM address ranges activate the corresponding "select" pins; "Only one such pin should be active at a time." [Game Pak > Pinout]
- "There is no Address 0 pin because there are 16 data lines: all accesses are 16-bit aligned." [Game Pak > Pinout]
- Audio line direction in the pinout table is relative to the game pak: "in" lines enter the game pak, "out" lines exit it. [Game Pak > Pinout]

### Timer

- The timer contains a 16-bit counter decremented at a specified interval; when it reaches zero a reload value is loaded and counting continues. [Timer; Timer > Counter and Reload]
- On reset an internal tick counter is initialized to zero. "Every 20 µs, the tick counter is incremented modulo 5 (the next value after 4 is 0). This process always occurs, even if the timer is disabled." [Timer]
- When `T-Clk-Sel` in `TCR` is set, the timer counter is decremented every time the tick counter increments; when clear, it is decremented only when the tick counter becomes zero. [Timer]
- `TLR` at `0x02000018` and `THR` at `0x0200001C` represent both the counter and the reload value, "High" holding the upper 8 bits and "Low" the lower 8 bits of the 16-bit value. [Timer > Counter and Reload]
- Reads return the current counter value; because the timer counts independently of program activity, "it should be stopped before accessing the counter value." [Timer > Counter and Reload]
- Writes specify a new reload value for the corresponding 8 bits; writing either register loads the entire 16-bit value into the counter and resets the current timer tick to the beginning of its wait interval. [Timer > Counter and Reload]
- `TCR` at `0x02000020`: unused bits 7–5, `T-Clk-Sel` bit 4 (R/W), `Tim-Z-Int` bit 3 (R/W), `Z-Stat-Clr` bit 2 (W), `Z-Stat` bit 1 (R), `T-Enb` bit 0 (R/W). Unused bits "have no function and are set when read." [Timer > Timer Control]
- `T-Clk-Sel` selects the count frequency: 0 = 100 µs, 1 = 20 µs. [Timer > Timer Control]
- "If `T-Clk-Sel` transitions from 0 to 1 and the internal tick counter is not zero, the timer counter value is decremented. This can trigger a timer zero interrupt." [Timer > Timer Control]
- `Z-Stat-Clr` clears `Z-Stat` and acknowledges a timer zero interrupt if the counter is non-zero, or if the counter is zero and the timer is disabled. It is always set when read. [Timer > Timer Control]
- `Z-Stat` becomes set whenever the counter is zero while the timer is enabled, and remains set until `Z-Stat-Clr` performs an action. [Timer > Timer Control]
- "If both `T-Enb` is cleared and `Z-Stat-Clr` is set while the timer is enabled, then the timer is disabled, but zero status is not cleared (nor is an interrupt acknowledged)." [Timer > Timer Control]
- A timer zero interrupt (code `0xFE10`) is raised whenever the counter value changes from non-zero to zero, either by timer activity or by writing to the reload registers. "The timer loading a reload value of zero into the counter does not satisfy the interrupt condition." [Timer > Timer Zero Interrupt]
- The interrupt is acknowledged by clearing `Tim-Z-Int` or by setting `Z-Stat-Clr` under the conditions given in Timer Control. [Timer > Timer Zero Interrupt]

### Wait Controller

- The wait controller generates wait signals for the game pak expansion and ROM address ranges. [Wait Controller]
- `WCR` at `0x02000024`: unused bits 7–2, `EXP1W` bit 1 (R/W), `ROM1W` bit 0 (R/W). Unused bits "have no function and are set when read." [Wait Controller]
- For both `EXP1W` and `ROM1W`, 2 waits are generated in the respective address range if the bit is clear and 1 wait if set. [Wait Controller]

### VIP — Overview and memory map

- The displays "were invented by Reflection Technology, Inc. and pitched to Nintendo, who accepted the proposal and initiated the Virtual Boy project." Each display is a single column of red LEDs projecting onto an oscillating mirror; the two mirrors oscillate opposite one another "to maintain balance and optimize power consumption." [VIP > Overview]
- "Images on Virtual Boy are 384×224 pixels per eye and are transmitted at a rate of 50.0 Hz." [VIP > Overview]
- Capacities: 2,048 characters; 1,024 objects; 14 full background maps; 32 worlds. Background maps are 64×64-character mosaics. [VIP > Overview]
- Drawing can be disabled so the frame buffer is accessed directly by the CPU, "facilitating software rendering." [VIP > Overview]
- Three brightness levels can be configured before a frame is displayed; used with a black value "there can be four base shades of red in a given image." [VIP > Overview]
- The column table is used by the physical display unit to maintain pixel proportions as the mirror oscillates, and "can also be used to indirectly influence the absolute brightness of columns of pixels in the output independently from the brightness settings." [VIP > Overview]
- VIP memory map: `0x00000000`–`0x00005FFF` Left frame buffer 0; `0x00006000`–`0x00007FFF` Character table 0; `0x00008000`–`0x0000DFFF` Left frame buffer 1; `0x0000E000`–`0x0000FFFF` Character table 1; `0x00010000`–`0x00015FFF` Right frame buffer 0; `0x00016000`–`0x00017FFF` Character table 2; `0x00018000`–`0x0001DFFF` Right frame buffer 1; `0x0001E000`–`0x0001FFFF` Character table 3; `0x00020000`–`0x0003D7FF` Background maps and world parameters; `0x0003D800`–`0x0003DBFF` World attributes; `0x0003DC00`–`0x0003DDFF` Left column table; `0x0003DE00`–`0x0003DFFF` Right column table; `0x0003E000`–`0x0003FFFF` Object attributes; `0x00040000`–`0x0005DFFF` Unmapped; `0x0005E000`–`0x0005FFFF` I/O registers; `0x00060000`–`0x00077FFF` Unmapped; `0x00078000`–`0x00079FFF` mirror of character table 0; `0x0007A000`–`0x0007BFFF` mirror of character table 1; `0x0007C000`–`0x0007DFFF` mirror of character table 2; `0x0007E000`–`0x0007FFFF` mirror of character table 3; `0x00080000`–`0x00FFFFFF` mirroring of the VIP memory map. [VIP > Memory Map]
- VIP I/O registers: `0x0005F800` `INTPND`; `0x0005F802` `INTENB`; `0x0005F804` `INTCLR`; `0x0005F820` `DPSTTS`; `0x0005F822` `DPCTRL`; `0x0005F824` `BRTA`; `0x0005F826` `BRTB`; `0x0005F828` `BRTC`; `0x0005F82A` `REST`; `0x0005F82E` `FRMCYC`; `0x0005F830` `CTA`; `0x0005F840` `XPSTTS`; `0x0005F842` `XPCTRL`; `0x0005F844` `VER`; `0x0005F848`–`0x0005F84E` `SPT0`–`SPT3`; `0x0005F860`–`0x0005F866` `GPLT0`–`GPLT3`; `0x0005F868`–`0x0005F86E` `JPLT0`–`JPLT3`; `0x0005F870` `BKCOL`. [VIP > Memory Map > I/O Registers]
- VIP I/O registers are intended to be accessed as halfwords; all reads, halfword writes and word writes function normally, but byte writes behave anomalously: a byte write to an even address performs a halfword write using the lowest 16 bits of the source register; a byte write to an odd address performs a halfword write using the lowest 8 bits of the source register shifted left 8 bits. [VIP > Memory Map > I/O Registers]
- Addresses in `0x0005E000`–`0x0005FFFF` that do not correspond to a listed register are unused; writing has no apparent effect and values are undefined when read. [VIP > Memory Map > I/O Registers]

### VIP — Drawing and display procedures

- "Display frames occur at a fixed interval of 20 ms, or 50 Hz." During each display frame the frame buffer contents are transmitted to the LEDs. [VIP > Drawing and Display Procedures > Frame Types]
- The drawing procedure begins when the `FCLK` flag gets set in `DPSTTS`; the value in `FRMCYC` is loaded into a counter decremented each display frame to determine when to begin the next drawing task. If the previous drawing task is still ongoing when that occurs, the `OVERTIME` flag in `DPSTTS` is set. [VIP > Drawing and Display Procedures > Drawing Procedure]
- Because the VIP memory bus is 16 bits wide and frame buffer memory is 2 bits per pixel in column-major order, "a halfword access into frame buffer memory corresponds to a 1×8 pixel unit of data. The VIP only writes each location in frame buffer memory once per frame." [VIP > Drawing and Display Procedures > Drawing Procedure]
- Halfwords are processed left-to-right, 8 rows of pixels at a time; groups of 8 rows are processed top-to-bottom; the procedure completes after all 28 groups. [VIP > Drawing and Display Procedures > Drawing Procedure]
- Drawing alternates between frame buffer 0 and 1 each time the drawing procedure is carried out, "enabl[ing] drawing to one frame buffer while the other is being displayed." [VIP > Drawing and Display Procedures > Drawing Procedure]
- Display frame timeline: 0 ms `FCLK` in `DPSTTS` goes high; 3 ms the appropriate left frame buffer begins to display; 8 ms the left frame buffer finishes displaying; 10 ms `FCLK` goes low; 13 ms the appropriate right frame buffer begins to display; 18 ms the right frame buffer finishes displaying; 20 ms start of next display frame. [VIP > Drawing and Display Procedures > Display Procedure]

### VIP — Characters, objects, background maps

- A character is an 8×8-pixel image at 2 bits per pixel, represented by 16 bytes, stored consecutively by address. [VIP > Characters; VIP > Characters > Format]
- The 2,048 characters are held in four blocks of 512 in four non-contiguous tables between frame buffer regions; virtual mirror addresses `0x00078000`–`0x0007FFFF` map them so all addresses are consecutive. [VIP > Characters]
- Character halfword format: 8 pixels at 2 bits each, `p7` in bits 15–14 down to `p0` in bits 1–0. Pixels at lower-order positions are displayed to the left of pixels at higher-order positions; rows are ordered top-to-bottom for a total of 8 halfwords. [VIP > Characters > Format]
- Object attribute memory (OAM) occupies `0x0003E000`–`0x0003FFFF`, holding 1,024 objects of 8 bytes each (4 halfwords). [VIP > Objects]
- Object halfword 0: unused bits 15–10 (6), `JX` bits 9–0 (10). Halfword 1: `JLON` bit 15, `JRON` bit 14, unused bits 13–10 (4), `JP` bits 9–0 (10). Halfword 2: unused bits 15–8 (8), `JY` bits 7–0 (8). Halfword 3: `JPLTS` bits 15–14 (2), `JHFLP` bit 13, `JVFLP` bit 12, unused bit 11, `JCA` bits 10–0 (11). [VIP > Objects]
- Object field meanings: `JX` Display Pointer X (signed horizontal coordinate of the object's left edge from the image's left edge); `JLON`/`JRON` draw to left/right image; `JP` Parallax (signed offset applied to the horizontal coordinate); `JY` Display Pointer Y; `JPLTS` Palette Selector; `JHFLP`/`JVFLP` horizontal/vertical flip; `JCA` Character Number. Unused bits "are not used by the VIP, but are functional memory." [VIP > Objects]
- Object horizontal position per eye: Left = `JX - JP`; Right = `JX + JP`. [VIP > Objects]
- "`JY` is not formally two's complement, but is effectively the lower 8 bits of a signed halfword value. It can express values in the range of -8 to +224." [VIP > Objects]
- `JCA` indexes characters consecutively across all four character tables; "The virtual mirroring address of the character in question can be calculated as `0x00078000 + JCA * 16`." [VIP > Objects]
- Background maps live in `0x00020000`–`0x0003D7FF`, shared with world parameters; "There is enough memory in this address range for 14 full background maps, plus a few more bytes. When accessing background maps, a full 16 indexes are allowed, but indexes 14 and 15 will access memory not intended for background maps." [VIP > Background Maps]
- Each background map is 8,192 bytes, appearing consecutively by address, containing 64×64 = 4,096 halfword cells. [VIP > Background Maps]
- Background map cell format: `GPLTS` bits 15–14 (2), `BHFLP` bit 13, `BVFLP` bit 12, unused bit 11, `Character` bits 10–0 (11). [VIP > Background Maps]
- The document gives the cell's character address formula as "`0x00078000` + `Character`". [VIP > Background Maps]
- Cell order within a background map is left-to-right for each row, then top-to-bottom by row. [VIP > Background Maps]

### VIP — Worlds

- Worlds are processed in reverse order from world 31 down to world 0; "Worlds with higher indexes will appear behind, and be obscured by, worlds of lesser indexes." [VIP > Worlds > Overview]
- Six world varieties: Normal; H-Bias (adds per-row independent horizontal shifting); Affine (per-row source coordinate and vector, allowing rotation, scaling "and can even be used to achieve perspective"); Object; Dummy (both `LON` and `RON` clear, produces no output); Control (`END` set, signals early termination of the drawing procedure). [VIP > Worlds > Overview]
- A background is composed of 1 to 8 background maps arranged in rows and columns; the base map is given by `BG Map Base` and additional maps are selected sequentially from memory. [VIP > Worlds > Backgrounds]
- Background dimensions are in units of background map, each 512×512 pixels; width and height may each be any power of 2 from 1 to 8 BG maps, but "no more than 8 BG maps total are intended to be used in a single background, restricting which combinations of width and height are intended to be used." [VIP > Worlds > Backgrounds]
- For 8 or fewer maps the arrangement is left-to-right for each row, then top-to-bottom (example given: 4 wide × 2 tall with base 0 → rows `0 1 2 3` and `4 5 6 7`). [VIP > Worlds > Backgrounds]
- For more than 8 maps "the behavior of the VIP is unintended but nonetheless well-defined": the background is treated as the largest 8-map background expressible with the specified height, and that vertical arrangement repeats horizontally (example: 4×4 with base 0 → rows `0 1 0 1`, `2 3 2 3`, `4 5 4 5`, `6 7 6 7`). [VIP > Worlds > Backgrounds]
- The value written to `BG Map Base` "will automatically be rounded down to the next multiple of the total number of background maps" (example: 4-map background with base index 11 rounds down to 8). Backgrounds of more than 8 maps are treated as containing only 8 for this purpose, "making their effective base map indexes either 0 or 8." [VIP > Worlds > Backgrounds]
- World attributes occupy `0x0003D800`–`0x0003DBFF`; each world element is 32 bytes / 16 halfwords. [VIP > Worlds > World Attributes]
- World halfword 0 field widths, most significant first: `LON` 1, `RON` 1, `BGM` 2, `SCX` 2, `SCY` 2, `OVER` 1, `END` 1, unused 2, `BG Map Base` 4. [VIP > Worlds > World Attributes]
- World halfword 1: unused 6, `GX` 10. Halfword 2: unused 6, `GP` 10. Halfword 3: `GY` 16. Halfword 4: unused 3, `MX` 13. Halfword 5: unused 1, `MP` 15. Halfword 6: unused 3, `MY` 13. Halfword 7: unused 3, `W` 13. Halfword 8: `H` 16. Halfword 9: `Param Base` 16. Halfword 10: `Overplane Character` 16. Halfwords 11–15: unused 16. [VIP > Worlds > World Attributes]
- World field meanings: `LON`/`RON` draw to left/right image; `BGM` BG Modification; `SCX`/`SCY` Screen X/Y Size — "Raise 2 to this power for the width [height] of the world's background in background maps"; `OVER` Overplane — if clear the background repeats indefinitely, if set characters beyond the bounds use `Overplane Character`; `END` — if set, this world and all worlds of lesser index are not drawn; `BG Map Base` index of the first background map. [VIP > Worlds > World Attributes]
- More world fields: `GX` BG X Destination (signed); `GP` BG Parallax Destination (signed); `GY` BG Y Destination (signed); `MX` BG X Source (signed, relative to the background's top-left corner, displayed in the world's top-left corner); `MP` BG Parallax Source (signed); `MY` BG Y Source (signed); `W` Window Width — add 1 for width in pixels; `H` Window Height — add 1 for height in pixels, value is signed; `Param Base`; `Overplane Character`. Unused bits are "used by the VIP as work memory." [VIP > Worlds > World Attributes]
- `BGM` values: 0 Normal BG; 1 H-Bias BG; 2 Affine BG; 3 OBJ. [VIP > Worlds > World Attributes]
- World destination position per eye: Left = `GX - GP`; Right = `GX + GP`. Background source position per eye: Left = `MX - MP`; Right = `MX + MP`. [VIP > Worlds > World Attributes]
- "For normal and H-bias worlds, `W` is a 13-bit signed value. For affine worlds, it is a 10-bit unsigned value." [VIP > Worlds > World Attributes]
- "The minimum height of normal and H-bias worlds is 8 pixels, even if `H` is in the range of 0 to 6. Affine worlds can be any height." [VIP > Worlds > World Attributes]
- `Param Base` maps to CPU address `0x00020000 + Param_Base × 2`. `Overplane Character` maps to `0x00020000 + Overplane_Character × 2`. [VIP > Worlds > World Attributes]
- Parameter elements are stored sequentially, one per row of pixels, starting with the top row. [VIP > Worlds > World Attributes]
- World parameter elements are always located in `0x00020000`–`0x0003FFFF`, which also contains background maps, worlds, the column table and objects; "Care must be taken to prevent accessing data used for other purposes." An address exceeding `0x0003FFFF` wraps back to `0x00020000`. [VIP > Worlds > World Attributes]
- Normal worlds are defined entirely in world attribute memory; all attributes except `Param Base` apply, and `BGM` must be 0. [VIP > Worlds > Normal Worlds]
- H-bias worlds: all world attribute fields apply and `BGM` must be 1. The number of H-bias elements required equals the world's height in pixels. [VIP > H-Bias Worlds]
- H-bias elements are 4 bytes / 2 halfwords: halfword 0 unused bits 15–13, `HOFSTL` bits 12–0; halfword 1 unused bits 15–13, `HOFSTR` bits 12–0. Both are signed horizontal offsets for the left and right eye respectively. [VIP > H-Bias Worlds]
- H-bias source position per eye: Left = `MX - MP + HOFSTL`; Right = `MX + MP + HOFSTR`. [VIP > H-Bias Worlds]
- "The VIP appears to determine the address of `HOFSTR` by OR'ing the address of `HOFSTL` with 2. If the `Param Base` attribute in the world is not divisibe by 4, this will result in `HOFSTL` being used for both the left and right images, and `HOFSTR` will not be accessed." [VIP > H-Bias Worlds]
- Affine worlds: all world attribute fields except `MX`, `MP` and `MY` apply, and `BGM` must be 2. The number of affine elements required equals the world's height in pixels. [VIP > Affine Worlds]
- Affine elements are 16 bytes / 8 halfwords: 0 `MX` (16), 1 `MP` (16), 2 `MY` (16), 3 `DX` (16), 4 `DY` (16), 5–7 unused (work memory). [VIP > Affine Worlds]
- Affine `MX` and `MY` are 13.3 fixed-point signed source coordinates for the left-most column of the current row; `DX` and `DY` are 7.9 fixed-point signed offsets added per column; `MP` is a 16-bit signed parallax offset. [VIP > Affine Worlds]
- Affine `MP` "is processed as though producing output for pixels in the world that are shifted horizontally. For instance, a value of 1 in `MP` will produce output pixels as though they were 1 world column to the right of their actual position." [VIP > Affine Worlds]
- "If `MP` is negative, it only applies to the left-eye image. Otherwise, it only applies to the right-eye image." [VIP > Affine Worlds]
- Affine source positions for column `i` (where `i = 0` is the left-most column): if `MP < 0`, Left X = `MX + DX × (i - MP)`, Left Y = `MY + DY × (i - MP)`, Right X = `MX + DX × i`, Right Y = `MY + DY × i`. If `MP ≥ 0`, Left X = `MX + DX × i`, Left Y = `MY + DY × i`, Right X = `MX + DX × (i + MP)`, Right Y = `MY + DY × (i + MP)`. [VIP > Affine Worlds]
- Object worlds ignore all world attributes except `BGM`, which must be 3. `LON`/`RON` do not influence which eyes objects are drawn to — that is determined entirely by object attributes — but if both are clear the world is interpreted as a dummy world and skipped, and "the world does not count as an object world." [VIP > Object Worlds]
- Object group registers `SPT0`–`SPT3` at `0x0005F848`, `0x0005F84A`, `0x0005F84C`, `0x0005F84E` share the format: unused bits 15–10 (undefined when read), `OBJ End Number` bits 9–0 (R/W). [VIP > Object Worlds]
- "An object group defines a range of objects with a start index and an end index. The end index is given by the corresponding object group register. The start index is 1 greater than the register of the next lower group. The start index of group 0 is always 0." [VIP > Object Worlds]
- An internal object world counter is initialized to 3 at the start of image processing, decrements after each object world is drawn, and resets to 3 when decremented from 0, "allowing each object group to be processed multiple times in one frame." [VIP > Object Worlds]
- Objects within a group are drawn in reverse order from the end index down to the start index; "If the end index is less than the start index, the process is still carried out as usual, continuing with processing of object index 1,023 after object index 0." [VIP > Object Worlds]

### VIP — Column table

- The column table corrects for the changing mirror angle: "If LED emissions were of constant duration for each column of pixels, then pixels on one side of the image would appear wider than pixels on the other side of the image." [VIP > Column Table]
- Left column table at `0x0003DC00`–`0x0003DDFF`, right column table at `0x0003DE00`–`0x0003DFFF`; 512 entries total, 256 per eye. [VIP > Column Table]
- "An entry in the column table is loaded during the display of every 4 columns of pixels. Column table entries are stored in column table memory consecutively by address, with lower addresses representing columns that are more to the right." [VIP > Column Table]
- Column table entry format: `Repeat` bits 15–8 (R/W) — add 1 for the number of times to produce LED pulses for each column of pixels; `Column Length` bits 7–0 (R/W) — add 1 for the emission time per column, in units of 200 nanoseconds. [VIP > Column Table]
- "The exact column table entries used during LED operation are determined by the servo and may change from one frame to the next. The VIP prefers to use the middle 96 entries, with the others providing room for adjustments to compensate for the physical behavior of the mirrors." [VIP > Column Table]
- `CTA` at `0x0005F830` is read-only: `CTA_R` bits 15–8 (index into the right column table, address `0x0003DE00 + (CTA_R × 2)`); `CTA_L` bits 7–0 (index into the left column table, address `0x0003DC00 + (CTA_L × 2)`). [VIP > Column Table > `CTA`]
- The VIP's internal column-table pointer is initialized from `CTA` when displaying a frame buffer and is decremented after each 4 columns, pointing to the next 4 columns to the right. The decrement can be prevented by setting `LOCK` in `DPCTRL`. [VIP > Column Table > `CTA`]
- "The LEDs in the display unit cannot actually emit light of varying intensity, so brightness is instead achieved by adjusting how long each pixel emits light." [VIP > Column Table > LED Emission; VIP > Brightness]
- `REST` at `0x0005F82A`: unused bits 15–8 (undefined when read), `Duration` bits 7–0 (R/W) in units of 5 nanoseconds. [VIP > Column Table > LED Emission]
- Per pixel: the value is loaded from the frame buffer, the LED pulses for the appropriate brightness duration, then idles for the `REST` duration; the number of repetitions per column is given by `Repeat`, so "`Repeat` serves as a sort of brightness multiplier for the column." [VIP > Column Table > LED Emission]
- "If the total configured brightness + idle duration exceeds the time allotted for the corresponding column of pixels, the display will stop emitting and move onto the next column." [VIP > Column Table > LED Emission]
- Apparent brightness: "The measurable brightness of a pixel is given by the duration of its brightness level multiplied by the `Repeat` field in the column table. If this measurement reaches about 128, then any longer durations will not appear brighter to the user." [VIP > Column Table > Apparent Brightness]
- The document reproduces a "recommended column table" from Nintendo, "used by all commercial software", stating "The following data is to be loaded to addresses `0x0003DC00` and `0x0003DE00`". The block is 512 bytes = 256 halfword entries, every entry having a `Repeat` byte of `00`. As a run-length listing of the 256 halfwords in address order (`value` ×count): `FE 00` ×62; `E0 00`, `BC 00`, `A6 00`, `96 00`, `8A 00`, `82 00`, `7A 00`, `74 00`, `6E 00`, `6A 00`, `66 00`, `62 00`, `60 00`, `5C 00`, `5A 00`, `58 00`, `56 00`, `54 00`, `52 00` each ×1; `50 00` ×2; `4E 00` ×1; `4C 00` ×2; `4A 00` ×2; `48 00` ×2; `46 00` ×3; `44 00` ×3; `42 00` ×3; `40 00` ×5; `3E 00` ×7; `3C 00` ×34; `3E 00` ×7; `40 00` ×5; `42 00` ×3; `44 00` ×3; `46 00` ×3; `48 00` ×2; `4A 00` ×2; `4C 00` ×2; `4E 00` ×1; `50 00` ×2; `52 00`, `54 00`, `56 00`, `58 00`, `5A 00`, `5C 00`, `60 00`, `62 00`, `66 00`, `6A 00`, `6E 00`, `74 00`, `7A 00`, `82 00`, `8A 00`, `96 00`, `A6 00`, `BC 00`, `E0 00` each ×1; `FE 00` ×62. [VIP > Column Table > Recommended Column Table]
- "The exact association between entries in the column table and physical columns of pixels is dynamic and can change without notice during system operation." [VIP > Column Table > Recommended Column Table]

### VIP — Frame buffer, display and drawing registers

- Frame buffers: Left 0 `0x00000000`–`0x00005FFF`; Left 1 `0x00008000`–`0x0000DFFF`; Right 0 `0x00010000`–`0x00015FFF`; Right 1 `0x00018000`–`0x0001DFFF`. [VIP > Frame Buffer]
- "A frame buffer is a 384×256 pixel image represented by 24,576 bytes." [VIP > Frame Buffer]
- Frame buffer halfword format is 8 pixels at 2 bits each, `p7` in bits 15–14 down to `p0` in bits 1–0; "Pixels at lower-order positions are displayed above pixels at higher-order positions." [VIP > Frame Buffer]
- Pixels are stored column-major: "first top-to-bottom for each column, then left-to-right column order", chosen "in order to transfer them more efficiently when displayed by the scanner." [VIP > Frame Buffer]
- "The VIP will only draw and display the top 224 rows of pixels in the frame buffer." Additional memory for 32 rows below the image exists in each frame buffer, "never modified by the VIP but is fully functional." [VIP > Frame Buffer]
- `DPSTTS` (`0x0005F820`, read-only) and `DPCTRL` (`0x0005F822`, write-only, undefined when read) share the format: unused bits 15–11 (5), `LOCK` 10, `SYNCE` 9, `RE` 8, `FCLK` 7, `SCANRDY` 6, `R1BSY` 5, `L1BSY` 4, `R0BSY` 3, `L0BSY` 2, `DISP` 1, `DPRST` 0. [VIP > Display]
- Display field meanings: `LOCK` (R/W) prevents `CTA` from updating; `SYNCE` (R/W) when clear, display sync signals are not sent to the display servo; `RE` (R/W) when clear, memory refresh signals are not issued on VIP memory; `FCLK` (R) the display frame clock signal is high; `SCANRDY` (R) the mirrors are stable; `R1BSY`/`L1BSY`/`R0BSY`/`L0BSY` (R) the corresponding frame buffer is being displayed; `DISP` (R/W) display enabled; `DPRST` (W) resets display functions when set. [VIP > Display]
- The four `*BSY` fields "are formally sub-fields of a 4-bit field called `DPBSY`." [VIP > Display]
- "`SYNCE` and `DISP` must both be set in order for images to be displayed. With precise timing, `SYNCE` might be used to enable only one image at a time, but its function is effectively the same as `DISP`." [VIP > Display]
- "While `RE` is clear, any VIP memory not used by the drawing procedure will degrade after several seconds." [VIP > Display]
- Setting `DPRST` makes `LOCK`, `FCLK`, `SCANRDY` and all four `DPBSY` flags in `DPSTTS` undefined, and clears `TIMEERR`, `FRAMESTART`, `GAMESTART`, `RFBEND`, `LFBEND` and `SCANERR` in both `INTENB` and `INTPND`. [VIP > Display]
- `XPSTTS` (`0x0005F840`, read-only) and `XPCTRL` (`0x0005F842`, write-only, undefined when read) share the format: `SBOUT` bit 15, unused bits 14–13 (2), `SBCOUNT`/`SBCMP` bits 12–8 (5), unused bits 7–5 (3), `OVERTIME` bit 4, `F1BSY` bit 3, `F0BSY` bit 2, `XPEN` bit 1, `XPRST` bit 0. [VIP > Drawing]
- Drawing field meanings: `SBOUT` (R) set when a group of 8 rows begins to draw; `SBCOUNT` (R) the group of 8 rows currently being drawn; `SBCMP` (W) the group of 8 rows to compare with while drawing; `OVERTIME` (R) the drawing procedure has taken longer than the allotted time; `F1BSY`/`F0BSY` (R) which frame buffer is being drawn to; `XPEN` (R/W) drawing enabled; `XPRST` (W) resets drawing functions when set. `F1BSY`/`F0BSY` "are formally sub-fields of a 2-bit field called `XPBSY`." [VIP > Drawing]
- The document notes about `SBOUT`: "The formal specification states that `SBOUT` will be cleared after 56 µs, but testing has shown it to persist for as long as 120 µs and overrun into the following group of 8 rows of pixels. `SBOUT` is not a reliable way to detect changes to `SBCOUNT`." [VIP > Drawing]
- Setting `XPRST` clears `XPEN` in `XPSTTS`, and clears `TIMEERR`, `XPEND` and `SBHIT` in both `INTENB` and `INTPND`. [VIP > Drawing]

### VIP — Brightness, palettes, interrupts, miscellaneous registers

- `BRTA` `0x0005F824`, `BRTB` `0x0005F826`, `BRTC` `0x0005F828` share the format: unused bits 15–8 (undefined when read), `Duration` bits 7–0 (R/W) in units of 5 nanoseconds. [VIP > Brightness]
- Frame buffer pixel values map to brightness: 0 Black; 1 Brightness level A; 2 Brightness level B; 3 Brightness level C. [VIP > Brightness]
- "Brightness levels A and B are configured directly, with zero representing no intensity and larger durations appearing brighter. The actual duration of brightness level C is the sum of the durations in all three brightness registers: A + B + C." [VIP > Brightness]
- Palette registers `GPLT0`–`GPLT3` (`0x0005F860`, `0x0005F862`, `0x0005F864`, `0x0005F866`) and `JPLT0`–`JPLT3` (`0x0005F868`, `0x0005F86A`, `0x0005F86C`, `0x0005F86E`) share the format: unused bits 15–8, `c3` bits 7–6 (R/W), `c2` bits 5–4 (R/W), `c1` bits 3–2 (R/W), unused bits 1–0. [VIP > Palettes]
- "A pixel value of 0 in a character is interpreted as a transparent pixel and will not modify the contents of the frame buffer when drawn. Accordingly, there is no palette entry for character pixel value 0." [VIP > Palettes]
- "BG" palettes are selected when the character is used in a background map; "OBJ" palettes when used in an object. [VIP > Palettes]
- `BKCOL` at `0x0005F870` (R/W): unused bits 15–2, `value` bits 1–0 — the initial frame buffer pixel value. [VIP > Palettes > Background Color]
- "After `BKCOL` is written, the new background color will not be applied until after the first 8 rows of pixels are drawn to the frame buffer the next time a frame is drawn." [VIP > Palettes > Background Color]
- "Regardless of the cause, all VIP interrupts have a code of `0xFE40`." [VIP > Interrupts]
- `INTPND` `0x0005F800` (read-only), `INTENB` `0x0005F802`, `INTCLR` `0x0005F804` (write-only, undefined when read) share the format: `TIMEERR` bit 15, `XPEND` bit 14, `SBHIT` bit 13, unused bits 12–5 (8), `FRAMESTART` bit 4, `GAMESTART` bit 3, `RFBEND` bit 2, `LFBEND` bit 1, `SCANERR` bit 0. [VIP > Interrupts]
- Interrupt condition meanings: `TIMEERR` drawing still in progress when the drawing procedure should begin (detects `OVERTIME` in `XPSTTS`); `XPEND` the drawing procedure has finished; `SBHIT` drawing has begun on the group of 8 rows specified in `SBCMP` of `XPCTRL`; `FRAMESTART` the display procedure has begun; `GAMESTART` the drawing procedure has begun; `RFBEND` the display procedure has completed for the right eye; `LFBEND` completed for the left eye; `SCANERR` the mirrors are not stable. [VIP > Interrupts]
- "When an interrupt condition is satisfied, regardless of whether or not the condition is enabled, the corresponding flag in `INTPND` will be set. If any flag is set in both `INTENB` and `INTPND`, the VIP will issue an interrupt request signal to the CPU." Conditions are acknowledged by writing to `INTCLR`. [VIP > Interrupts]
- `FRMCYC` at `0x0005F82E`: unused bits 15–4, `FRMCYC` bits 3–0 (R/W) — "Add 1 to this figure for the number of display frames for each game frame." [VIP > Miscellaneous Registers > `FRMCYC`]
- `VER` at `0x0005F844`: unused bits 15–5, `VER` bits 4–0 (R). "Only one model of Virtual Boy was ever produced. Its VIP version is 2." [VIP > Miscellaneous Registers > `VER`]

### VSU — Overview and memory map

- The VSU has 6 channels, "five of which produce tones by sampling from PCM memory and one of which produces binary noise." Channels are named 1 through 6. [VSU > Overview]
- All channels have duration control, stereo output levels/balance, sampling frequency, and a master envelope level with shrink/grow and repeat. Channels 1–4 sample from PCM wave memory; channel 5 additionally has frequency sweep and modulation; channel 6 samples from a pseudorandom noise generator. [VSU > Overview]
- "Audio output from the mixer is 10-bit digital stereo at 41,700 Hz. Peripherals include two built-in stereo speakers, a volume wheel and a 3.5 mm headphone jack." [VSU > Overview]
- "All VSU addresses must be accessed with 8-bit writes. 16- and 32-bit writes have undefined behavior. All reads are undefined." [VSU > Memory Map]
- VSU memory map: `0x01000000`–`0x0100007F` Waveform 1 RAM; `0x01000080`–`0x010000FF` Waveform 2 RAM; `0x01000100`–`0x0100017F` Waveform 3 RAM; `0x01000180`–`0x010001FF` Waveform 4 RAM; `0x01000200`–`0x0100027F` Waveform 5 RAM; `0x01000280`–`0x010002FF` Modulation RAM; `0x01000300`–`0x010003FF` Unmapped; `0x01000400`–`0x010007FF` I/O registers; `0x01000800`–`0x01FFFFFF` mirroring of the VSU memory map. [VSU > Memory Map]
- Per-channel register blocks are 0x40 apart, starting at `0x01000400` (channel 1), `0x01000440` (2), `0x01000480` (3), `0x010004C0` (4), `0x01000500` (5), `0x01000540` (6). Within each block the offsets are +0x00 `SxINT`, +0x04 `SxLRV`, +0x08 `SxFQL`, +0x0C `SxFQH`, +0x10 `SxEV0`, +0x14 `SxEV1`, +0x18 `SxRAM` (channels 1–5 only). Channel 5 additionally has `S5SWP` at `0x0100051C`. `SSTOP` is at `0x01000580`. [VSU > Memory Map > I/O Registers]

### VSU — Output procedure

- "An unsigned, 6-bit input sample is produced for each of the 6 audio channels." If a channel is not active, 0 is used for its input sample. [VSU > Output Procedure > Digital Output]
- "Output is sampled at 41,700 Hz. The maximum output value is 685." [VSU > Output Procedure > Digital Output]
- On conversion to analog the VSU implements an RC circuit blocking the DC bias, "effectively producing a first-order high-pass filter with a very low cutoff frequency." [VSU > Output Procedure > Analog Output]
- "The RC circuit is implemented with a 100 Ω resistor and a 220 µF capacitor, resulting in a cutoff frequency of 1 / (2π × 100 × 0.000220) ≈ 7.234 Hz." [VSU > Output Procedure > Analog Output]
- Discretization: `RC = 100 × 0.000220 = 0.022`; `α = RC / (RC + 1 / SamplingRateHz)`; `Output[n] = α × ( Output[n - 1] + Input[n] - Input[n - 1] )`. [VSU > Output Procedure > Analog Output]
- "If no output line is plugged into the 3.5 mm headphone jack, the output will be sent to the internal stereo speakers. Otherwise, the output will be sent through the connected line and not to the speakers." [VSU > Output Procedure > Analog Output]

### VSU — PCM waveforms and channel control

- Five wave tables of 32 samples each occupy `0x01000000`–`0x0100027F`. [VSU > PCM Waveforms]
- "Samples are 6-bit, unsigned integers. They are accessed on word boundaries (4 bytes apart, lowest address), but must be written using 8-bit store or output instructions. The upper 2 bits of the 8-bit value are ignored." [VSU > PCM Waveforms]
- "PCM wave memory can only be written while all sound channels are inactive, including the noise channel. Attempts to write to it during sound generation will have no effect." [VSU > PCM Waveforms]
- `S1RAM`–`S5RAM` (`0x01000418`, `0x01000458`, `0x01000498`, `0x010004D8`, `0x01000518`): unused bits 7–3 (undefined when read), `Wave` bits 2–0 (W). A value of zero corresponds with waveform 1. [VSU > PCM Waveforms]
- "If a value greater than 4 (PCM wave 5) is specified for `Wave`, the channel will still play, but will not produce any sound. PCM wave memory still cannot be written while any channel is active in this manner." [VSU > PCM Waveforms]
- `SxINT` registers: `Enb` bit 7 (W), unused bit 6, `Auto` bit 5 (W), `Interval` bits 4–0 (W). [VSU > Channel Control]
- "When `Auto` is set, the channel will play for the amount of time specified by `Interval` and then automatically disable itself." `Interval` value plus 1 "represents time in units of ≈ 3.84 ms (= 260.4 Hz)." [VSU > Channel Control]
- Writing `SxINT` resets: the frequency delay counter to the beginning of its current sample; the current position in PCM wave memory to the first sample; the envelope step timer to the start of its step interval; the frequency modification timer to the start of its modification interval; the current position in modulation memory to the first value; the noise generator's shift register to all zeroes. [VSU > Channel Control]
- `SxLRV` registers: `Left` bits 7–4 (W), `Right` bits 3–0 (W). "The level scales linearly with 0 being silence and 15 being maximum amplitude." [VSU > Stereo Levels]

### VSU — Frequency

- Base clock frequencies: 5,000,000 Hz for channels 1–5; 500,000 Hz for channel 6. [VSU > Frequency > Frequency Values]
- "The number of base clocks to wait is calculated by subtracting the frequency value from 2,048 (1 greater than the 11-bit maximum value). In this way, higher frequency values correspond with higher frequencies." [VSU > Frequency > Frequency Values]
- Channels maintain two frequency values internally: the most recent value written to the frequency registers, and the current value used as the delay counter during sound generation. Both are unsigned 11-bit. [VSU > Frequency > Frequency Values]
- "Writing an 8-bit value to one of the frequency registers will update the corresponding bits of both the most recent value and the current value. Frequency modifications that occur during sound generation will only update the current value." Because modifications can alter all 11 bits of the current value, "programs should use both frequency registers to ensure the entire value is updated." [VSU > Frequency > Frequency Values]
- "Since the VSU samples output from channels at 41,700 Hz, any frequency value that specifies a higher sampling rate will be subject to aliasing." [VSU > Frequency > Frequency Values]
- `SxFQL` registers hold `Low` bits 7–0 (W), the lower 8 bits of the frequency value. `SxFQH` registers hold unused bits 7–3 and `High` bits 2–0 (W), the upper 3 bits. [VSU > Frequency > Frequency Registers]
- "Frequency values are 11-bit, but must be written as two individual bytes because the VSU bus is only 8 bits wide." [VSU > Frequency > Frequency Registers]

### VSU — Envelope

- "Even if automatic modifications are disabled, the envelope level must be initialized to some non-zero value in order for audible sound to be produced on the channel." [VSU > Envelope]
- `SxEV0` field widths, most significant first: `Value` 4 bits, `Dir` 1 bit, `Interval` 3 bits, all write-only. `Value` is the initial and reload value of the envelope. [VSU > Envelope]
- `SxEV1`: unused bit 7, `(Ext)` bits 6–4 ("These bits have significance with regards to the frequency modification and noise features"), unused bits 3–2, `Rep` bit 1 (W), `Enb` bit 0 (W). [VSU > Envelope]
- "When `Dir` is set, automatic envelope modifications will add 1 to the current envelope level (grow). When clear, modifications will subtract 1 from the current level (decay)." [VSU > Envelope]
- `Interval` value plus 1 "represents time in units of ≈ 15.36 ms (65.1 Hz)." [VSU > Envelope]
- "The envelope level can grow until it reaches 15 or decay until it reaches 0." [VSU > Envelope]
- "If `Rep` is set while `Enb` is set, then after the envelope is processed at its maximum (if `Dir` is set) or minimum (if `Dir` is clear) level for one interval, the most recent value written to `Value` is reloaded as the envelope level for one interval and automatic modifications will resume." [VSU > Envelope]
- "Writing to `S6EV1` will reset the noise generator's shift register to all zeroes." [VSU > Envelope]
- "When the channel's `SxINT` register is written, the current envelope frame is reset (needs to wait for the entire `Interval` again)." [VSU > Envelope > Envelope Procedure]

### VSU — Sweep and modulation

- Channel 5 has, in addition to the features of channels 1–4, frequency sweep and modulation; "These functions will modify the current frequency value, but not the frequency value most recently written to the frequency registers." [VSU > Sweep & Modulation]
- "Regardless of the frequency modification function used, a new frequency value is calculated at the beginning of the current frequency modification frame. After audio is generated for the current frame, the current frequency value is replaced by the calculated new value." [VSU > Sweep & Modulation]
- Sweep shifts the current frequency value right by a specified number of bits, then adds or subtracts the result to or from the current frequency value, producing "a sliding pitch on the logarithmic scale, as though along octaves." [VSU > Sweep & Modulation > Sweep]
- "If the calculated new frequency value is greater than 2,047, channel 5 will immediately be stopped without generating any further sound. A bug in the hardware implementation of the sweep function allows this to occur even if the sweep function is disabled (if either modifications are disabled or the modification interval is zero)." [VSU > Sweep & Modulation > Sweep]
- Because automatic shutoff inspects the calculated new value at the beginning of the frame, "it will prevent the highest valid frequency value from being used in audio generation." [VSU > Sweep & Modulation > Sweep]
- Modulation reads a modulation value each frequency modification frame and adds it to the most recent frequency value written to the frequency registers, "retaining only the lowest 11 bits of the result." [VSU > Sweep & Modulation > Modulation]
- After processing all 32 modulation values, processing "can either stop or continue from the first modulation value." Writing to `S5INT` resets the current modulation position to the first value. [VSU > Sweep & Modulation > Modulation]
- Modulation RAM at `0x01000280`–`0x010002FF` holds 32 values; "Modulation values are 8-bit, two's complement signed integers. They are accessed on word boundaries (4 bytes apart, lowest address), but must be written using 8-bit store or output instructions." [VSU > Sweep & Modulation > Modulation]
- "Modulation memory can only be written while sound channel 5 is inactive." [VSU > Sweep & Modulation > Modulation]
- `S5EV1` (`0x01000514`) frequency-modification view: unused bit 7, `Enb` bit 6 (W), `Rep` bit 5 (W), `Func` bit 4 (W), unused bits 3–2, `(Env)` bits 1–0 (envelope-related). [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- `S5SWP` at `0x0100051C`: `Clk` bit 7 (W), `Interval` bits 6–4 (W), `Dir` bit 3 (W), `Shift` bits 2–0 (W). [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- "If `Enb` is set and `Interval` is not zero, frequency modifications will be performed. Otherwise, the frequency will not be modified." [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- `Func` values: 0 Sweep; 1 Modulation. [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- "If `Rep` is clear while the modulation function is selected, then the 32 values in modulation memory will only be processed once, leaving the frequency at the final value." Otherwise modulation memory wraps back to the first value. [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- `Clk` values: 0 ≈ 0.96 ms (1041.6 Hz); 1 ≈ 7.68 ms (130.2 Hz). `Interval` "exactly represents time in the unit specified by `Clk`"; if `Interval` is zero, the frequency modification feature is disabled. [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- "If `Dir` is set while the sweep function is selected, the shifted result is added to the current frequency value. Otherwise, if `Dir` is clear, the shifted result is subtracted." [VSU > Sweep & Modulation > Sweep/Modulation Control Registers]
- Writing `S5INT` resets the current frequency modification frame to the beginning of its interval but does not change the current frequency value, "meaning the most recent current frequency value will be used for one frequency modification frame after re-enabling the channel." [VSU > Sweep & Modulation > Frequency Modification Procedure]
- "If `S5SWP` is written specifying a new frequency modification interval, and the amount of time since the start of the current frequency modification frame is already greater than the new interval being set, the current frame will continue to be processed using the previous interval. However, if the new interval specifies a time that hasn't been fully processed yet during the current frame, the new interval will take effect immediately." [VSU > Sweep & Modulation > Frequency Modification Procedure]

### VSU — Noise and master control

- "Channel 6 produces sound by generating pseudorandom noise. The noise generator is a 15-bit linear feedback shift register with a configurable tap location. Output is binary: noise is only either high or low." [VSU > Noise]
- `S6EV1` (`0x01000554`) noise view: unused bit 7, `Tap` bits 6–4 (W), unused bits 3–2, `(Env)` bits 1–0. [VSU > Noise]
- `Tap` values, bit used, and resulting sequence length: 0 → bit 14, 32,767; 1 → bit 10, 1,953; 2 → bit 13, 254; 3 → bit 4, 217; 4 → bit 8, 73; 5 → bit 6, 63; 6 → bit 9, 42; 7 → bit 11, 28. [VSU > Noise]
- "Bit positions listed above are zero-based. That is, bit 0 is the bit at position `0x0001` and bit 14 is the bit at position `0x4000`." [VSU > Noise]
- The generated bit "is then scaled to 6 bits to be the same size as the samples of the other sound channels. That is to say, if a 0 is generated, the sample is 0; and if a 1 is generated, the sample is 63." [VSU > Noise]
- The 15-bit shift register is initialized to all zeroes when either `S6INT` or `S6EV1` is written. [VSU > Noise > Noise Procedure]
- `SSTOP` at `0x01000580`: unused bits 7–1, `Stop` bit 0 (W). "If `Stop` is set, all active channels will be disabled. Clearing `Stop` has no effect." [VSU > Master Control]
- "This register will not prevent sounds from being generated: it only stops active channels. Channels can be restarted without writing a 0 to `Stop`." [VSU > Master Control]

### System Reset

- CPU registers initialized on reset: `ECR` = `0x0000FFF0`; `PC` = `0xFFFFFFF0`; `PSW` = `0x00008000` ("The only bit set in `PSW` on reset is the `NP` flag"). All other system registers and all program registers except `r0` are undefined on reset. [System Reset > CPU]
- Communication port on reset: `CCR` all fields zero; `CCSR` all fields set; `CDRR` `0x00`; `CDTR` `0x00`. [System Reset > Communication Port]
- Game pad on reset: `SCR` all fields zero; `SDHR` `0x00`; `SDLR` `0x00`. [System Reset > Game Pad]
- Timer on reset: Counter `0xFFFF`; Reload `0x0000`; `TCR` all fields zero. "Because the reload value is loaded into the counter when either of the reload registers is written, reset is the only time when the two figures can have different values." [System Reset > Timer]
- Wait controller on reset: `WCR` all fields zero. [System Reset > Wait Controller]
- VIP on reset: the contents of VIP memory are undefined; `DPSTTS` `SYNCE` = 0, `RE` = 0, `DISP` = 0; `INTENB` all fields zero; `XPSTTS` `XPEN` = 0. "All other registers (including `INTPND`) and other fields within the above registers are undefined on reset." [System Reset > VIP]
- WRAM contents are undefined on reset. [System Reset > WRAM]

### About and References

- The document credits "Written by Guy Perfect", "Produced for Planet Virtual Boy", website `https://www.virtual-boy.com/`, and thanks 20 named individuals (Benjamin Stevens, bigmak, blitter, dasi, DogP, enthusi, Floogle, Gookanheimer, HorvatM, jwestfall, Kevin Mellott, KR155E, Matt Mozingo, MineStorm, optiroc, overlord, SonicSwordcane, The Beesh-Spweesh!, Triverske, Yeti_dude). [About]
- References listed: "V810 Family™ 32-bit Microprocessor User's Manual", October 1995, Document No. U10082EJ1V0UM00 (1st edition), written by Renesas Technology Corporation. [About > References]
- Reference: "Project: Virtual Boy", website by DogP. [About > References]
- Reference: "The Unofficial Virtual Boy Home Page", website by David Tucker. [About > References]
- Reference: "IAR Assembler Reference Guide for V850", October 2010, Document No. AV850-4 (fourth edition), written by IAR Systems. [About > References]
- Reference: "V830 Family™ 32-bit Microprocessor User's Manual", December 1997, Document No. U12496EJ2V0UM00 (2nd edition), written by Renesas Technology Corporation. [About > References]
- Reference: "Unraveling The Enigma Of Nintendo's Virtual Boy, 20 Years Later", August 21, 2015, an article on the history of the Virtual Boy's development, written by Benj Edwards. [About > References]
- The reference list closes with "And countless hours of original research." [About > References]

## Specifications and procedures

### WRAM initialization sequence

1. Wait 200 µs before accessing.
2. Perform 8 dummy read accesses before any other accesses.
   Software that does not account for this before accessing WRAM has undefined behavior. [Memory Map > WRAM]

### Exception handling algorithm

- If the `NP` flag in `PSW` is set, a fatal exception occurs: the exception's code is OR'd with `0xFFFF0000` and the result written to memory address `0x00000000`; the value in `PSW` is written to `0x00000004`; the value in `PC` is written to `0x00000008`; the CPU halts until system reset. [CPU > Exception Processing > Exception Handling]
- Else if the `EP` flag in `PSW` is set, a duplexed exception occurs: the exception's code is stored into `FECC` of `ECR`; `PSW` into `FEPSW`; the restore PC into `FEPC`; the `NP` flag in `PSW` is set; `0xFFFFFFD0` is stored into `PC`. [CPU > Exception Processing > Exception Handling]
- Else a regular exception occurs: the exception's code is stored into `EICC` of `ECR`; `PSW` into `EIPSW`; the restore PC into `EIPC`; the `EP` flag in `PSW` is set; the exception's handler address is stored into `PC`. [CPU > Exception Processing > Exception Handling]
- If the exception was an interrupt: 1 is added to the interrupt's level and the result stored into the `I` field of `PSW`; any pending `HALT` instruction completes. [CPU > Exception Processing > Exception Handling]
- Finally, the `ID` flag in `PSW` is set and the `AE` flag in `PSW` is cleared. [CPU > Exception Processing > Exception Handling]
- Note attached to the interrupt-level step: "If an interrupt's level is 15, 15 will be stored into the `I` field of `PSW`. This will never occur on an unmodified Virtual Boy because no interrupt is assigned level 15." [CPU > Exception Processing > Exception Handling]

### `CAXI` algorithm

1. The bus is locked, causing other CPUs to block when accessing it.
2. A value is loaded, as though with `LD.W`, from `reg1 + disp`.
3. A comparison is performed, as though with `CMP`, using `reg2 - value`.
4. If the result is equal (`Z = 1`): a store is performed, as though with `ST.W`, storing `r30` into `reg1 + disp`. Otherwise: a store is performed storing `value` back into `reg1 + disp`.
5. `value` is stored into `reg2`.
6. The lock on the bus is released.
   The program can check `Z` to determine what action was taken. [CPU > Miscellaneous > `CAXI`]

### Game pad software read

- Set `Para/Si` once to reset the operation, then write alternating states for `Soft-Ck` 16 times. "After the 16th bit has been clocked, the data registers will contain the button state bits. Before the 16th bit has been clocked, the contents of the data registers will be undefined." [Game Pad > Game Pad Control > Software Read]
- The same subsection also states: "In order to properly read the button state, the game pad must receive a 0 followed by a 1 for each button for a total of 33 writes to `Soft-Ck`." The document does not reconcile the "16 times" and "33 writes" figures. [Game Pad > Game Pad Control > Software Read]

### VIP drawing algorithm, per 1×8 halfword unit

1. All pixels in the halfword are initialized to the value specified by `BKCOL`.
2. A temporary object group counter is initialized to 3.
3. For each world from 31 to 0: if the `END` flag is set (control world), stop processing worlds; if `LON` and `RON` are both clear (dummy world), skip to the next world; if `BGM` = 3 (object world), draw the object group specified by the temporary counter and decrement the counter (wrapping back to 3 after 0); otherwise (background world) draw the world's background.
4. Store the halfword into the frame buffer. [VIP > Drawing and Display Procedures > Drawing Procedure]

### VIP display algorithm, per eye

1. An internal column table pointer is initialized using the corresponding value from `CTA`.
2. The corresponding `DPBSY` flag is set in `DPSTTS`.
3. For every group of 4 columns of pixels from left to right: the pixels are emitted using the current frame buffer, brightness and column table values; if the `LOCK` flag in `DPSTTS` is clear, the internal column table pointer is decremented to the next entry's address; advance to the next group of 4 columns.
4. The corresponding `DPBSY` flag is cleared in `DPSTTS`. [VIP > Drawing and Display Procedures > Display Procedure]

### VSU digital output algorithm

- For each channel: the 4-bit stereo level is multiplied with the 4-bit envelope level; of the resulting 8 bits, only the highest 5 are used as the amplitude value; if neither level was zero, 1 is added to the amplitude value; the 6-bit input sample is multiplied with the 5-bit amplitude value to produce the 11-bit channel output value. [VSU > Output Procedure > Digital Output]
- Once all channels are processed: the 11-bit channel output values for all channels are added together; of the resulting 14 bits, only the highest 10 are used as the final output. [VSU > Output Procedure > Digital Output]

### VSU envelope procedure, per envelope frame

1. Sound is generated for `Interval` time.
2. If `Enb` is clear, the current envelope level remains the same.
3. Otherwise, if `Dir` is clear and the current envelope level is not 0, decrease the level by 1.
4. Otherwise, if `Dir` is set and the current envelope level is not 15, increase the level by 1.
5. Otherwise, if `Rep` is set, the current envelope level is replaced by `Value`. [VSU > Envelope > Envelope Procedure]

### VSU frequency modification procedure, per modification frame

1. A new frequency value is calculated, but is not yet applied.
2. If the new frequency value is greater than 2,047, the channel is immediately stopped.
3. Sound is generated for the modification interval.
4. If `Enb` is set and `Interval` is not zero, the current frequency value is replaced with the previously calculated new value. [VSU > Sweep & Modulation > Frequency Modification Procedure]

### VSU noise procedure, per pseudorandom sample

1. From the shift register, bit 7 (`0x0080`) is XORed with the bit at `Tap` and the result inverted to produce a pseudorandom bit.
2. The value in the register is shifted left one bit.
3. The pseudorandom bit is used as the new bit 0 of the shift register.
4. The pseudorandom bit is scaled to 63 to produce the output sample. [VSU > Noise > Noise Procedure]

## Constraints and requirements

- Virtual Boy software "must account for" the WRAM initialization (200 µs wait, 8 dummy reads) "or else its behavior is undefined." [Memory Map > WRAM]
- Memory addresses `0xFFFFFDE0` upward "must contain specific kinds of data" (ROM header and exception handlers). [ROM Format]
- ROM header Reserved bytes "should be zeroes" (the document's word is "should", not "must"). [ROM Format > ROM Header]
- Only normal real numbers and zero are accepted by the floating-point unit; indefinites, NaNs and non-zero denormals "cannot be processed". [CPU > Data Types]
- Specifying more than one of `ICR`, `ICD` or `ICC` in `CHCW` simultaneously makes the operation undefined. [CPU > `CHCW`]
- `ECR` cannot be modified by `LDSR`; `LDSR` to `ECR`, `PIR`, `TKCW`, register 30 and reserved indexes has no effect. [CPU > `ECR`; CPU > CPU Control]
- `TKCW` and `PIR` are read-only with fixed values (`0x000000E0` and `0x00005346`); system register 30 is read-only with fixed value `0x00000004`. [CPU > `TKCW`; CPU > `PIR`; CPU > `30` - System register 30]
- If all interrupts are masked or disabled, "`HALT` cannot finish and the CPU will be stopped until reset." [CPU > CPU Control]
- Executing an invalid opcode or sub-opcode raises the illegal opcode exception (code `0xFF90`). [CPU > Opcode Map]
- Hardware I/O registers in `0x02000000`–`0x0200003F` are "intended to be accessed as bytes", though any access type works because they are 4 bytes apart. [Memory Map > Miscellaneous Hardware]
- VIP I/O registers are "intended to be accessed as halfwords"; byte writes behave anomalously as described above. [VIP > Memory Map > I/O Registers]
- "All VSU addresses must be accessed with 8-bit writes. 16- and 32-bit writes have undefined behavior. All reads are undefined." [VSU > Memory Map]
- PCM wave memory can only be written while all sound channels are inactive, including the noise channel; modulation memory can only be written while channel 5 is inactive. [VSU > PCM Waveforms; VSU > Sweep & Modulation > Modulation]
- `SYNCE` and `DISP` "must both be set in order for images to be displayed." [VIP > Display]
- The timer should be stopped before reading the counter value, since it counts independently of program activity. [Timer > Counter and Reload]
- Only one game pak "select" pin (expansion, ROM, RAM) should be active at a time. [Game Pak > Pinout]
- `BGM` must be 0 for normal worlds, 1 for H-bias worlds, 2 for affine worlds, 3 for object worlds. [VIP > Worlds > Normal Worlds; > H-Bias Worlds; > Affine Worlds; > Object Worlds]
- "No more than 8 BG maps total are intended to be used in a single background." Behavior above 8 maps is described as "unintended but nonetheless well-defined." [VIP > Worlds > Backgrounds]
- Affine parameters "should always be configured to begin on a 16-byte boundary (lowest 4 bits of `Param Base` are clear)"; unaligned parameter elements "will result in corruption of subsequent elements." [VIP > Affine Worlds, Editor's Note marked IMPORTANT]
- The envelope level "must be initialized to some non-zero value in order for audible sound to be produced on the channel." [VSU > Envelope]

## Stated gaps and ambiguities

The document marks unresolved points in italicized "Editor's Note" blocks. All are recorded here as the document states them; none are resolved in the source.

- "Three system registers are functional on NVC that are not mentioned in the V810 manual. It's possible Nintendo may have introduced them, but so far no record of where they came from can be found." [CPU > Specifications]
- "Is it correct that the spill area is in the caller's stack frame? Is it absent when fewer than five arguments are present?" [CPU > Register Set > Calling Convention]
- "The NVC format of `PIR` differs slightly from the V810 format." [CPU > `PIR`]
- "Since this register was never intended to be modifiable, the effects of other values for `RDI` and `RD` were not provided in the documentation for the V810 or V830 processors." [CPU > `TKCW`]
- System registers 29 and 30 have "unknown significance"; the official names of system registers 29, 30 and 31 "are unknown". [CPU > Register Set > System Registers]
- The `NECRV` field in dumped cache tag data: "The significance of this field is not documented." [CPU > Instruction Cache]
- "Research is needed to determine the number of cycles taken by this process" (exception handling). [CPU > Exception Processing > Exception Handling]
- "The V810 documentation uses the phrase 'many cycles' with regards to a one-cycle load operation, but it doesn't explicitly define exactly how many is 'many'. Logic suggests that the instruction needs only take long enough for the pipeline to ready the load operation with its effective address, then can immediately execute it when the long instruction finishes. Either way, this needs some research." [CPU > Memory and Register > Load and Input]
- "The cycle counts for input instructions needs to be researched, as they may be identical to the load instructions' counts." [CPU > Memory and Register > Load and Input]
- "While the number of CPU cycles taken for an input or load instruction may be small, the actual amount of time taken depends on the speed of whatever is being accessed on the bus (video memory, WRAM, etc.). The exact latencies for reads needs to be researched." [CPU > Memory and Register > Load and Input]
- "The cycle counts for output instructions needs to be researched, as they may be identical to the store instructions' counts." [CPU > Memory and Register > Store and Output]
- "The exact latencies for writes needs to be researched." [CPU > Memory and Register > Store and Output]
- "Research is needed to determine whether a conditional branch with a displacement to the following instruction still take 3 cycles, even though it's equivalent to a non-branch." [CPU > CPU Control]
- "The overflow condition appears to process the result as usual, updating `FPR` and `reg2` as appropriate, then raises the overflow exception when writing the exponent field. Research is needed to determine exactly which values are produced in this situation." [CPU > Floating-Point]
- "While the V810 documentation gives ranges for the number of cycles taken for each floating-point instruction, it does not give specifics about which situations result in which cycle counts. Research is needed to determine how long any given operation will take." [CPU > Floating-Point]
- "The V810 manual provides a table of cycle timings for various configurations of these operations that needs to be incorporated into this document." — stated twice, once for bitwise bit string instructions and once for search instructions. [CPU > Bit Strings > Bitwise; CPU > Bit Strings > Search]
- "These instructions were borrowed from the 6502/65816 instruction set used by the NES and SNES. When NEC developed the V830 in 1997, they introduced the `EI` and `DI` instructions … which use the same opcodes and perform the same operations as NVC's `CLI` and `SEI` instructions. However, `EI` and `DI` only take 2 cycles to complete." [CPU > Nintendo > Standalone]
- "One source suggests that `XB` and `XH` must supply `r0` in the binary encoding of the `reg1` field, or else the behavior is undefined. This could use further testing, as no misbehavior has been observed regardless of the value of `reg1`." [CPU > Nintendo > Extended]
- "If the ambient humidity is high enough, an assembly-optimized software read routine will attempt to process game pad bits so fast that the game pad will respond with unstable data. A dummy `MUL` instruction between bits seems to add enough latency to address this problem, but may or may not be sufficient in all cases." [Game Pad > Game Pad Control > Software Read]
- "The hardware's implementation might initialize the tick counter to 4 and decrement it each tick." [Timer]
- "The amount of time taken by the drawing procedure depends on the complexity of the image being drawn. Affine worlds in particular are computationally expensive and cannot fill the screen without reducing the frame rate. Research is needed to determine exactly how long each type of graphic takes to draw. When no image is being drawn whatsoever (such that the frame buffer's contents are merely erased), the drawing procedure takes approximately 2.8 ms." [VIP > Drawing and Display Procedures > Drawing Procedure]
- "Research is needed to determine exactly when the active frame buffer is toggled. It may occur when `FCLK` goes high." [VIP > Drawing and Display Procedures > Drawing Procedure]
- "There doesn't appear to be any way to select in software the frame buffer to be displayed. The only known way to leverage double buffering is to use the hardware drawing feature." [VIP > Drawing and Display Procedures > Display Procedure]
- "Research is needed to determine whether frame buffer 0 is necessarily used as the default after reset. The drawing function can be used for one frame and `DPSTTS` monitored to determine which frame buffer it used." [VIP > Drawing and Display Procedures > Display Procedure]
- Object `JY`: "Values `0xE0` through `0xF8` are beyond the bounds of the image, so the exact range of the field is unknown." [VIP > Objects]
- "One case suggests that `Overplane Character` may have restrictions regarding the range of characters it is able to access. Some experimentation is in order." [VIP > Worlds > World Attributes]
- "Extensive research is required in order to determine the exact behavior of the VIP when drawing worlds with unintended attributes, such as negative or large dimensions, excessive parallax, etc. Research is also needed to determine which bits of world attribute memory are used by the VIP as work memory and in what ways." [VIP > Worlds > World Attributes]
- "Research is needed to determine which bits of affine parameter memory are used by the VIP as work memory and in what ways." [VIP > Affine Worlds]
- "IMPORTANT - Affine parameters should always be configured to begin on a 16-byte boundary (lowest 4 bits of `Param Base` are clear). The VIP appears to determine field addresses with a bitwise OR rather than addition, but writes to halfwords 5, 6 and 7 with addition. Unaligned parameter elements will result in corruption of subsequent elements." [VIP > Affine Worlds]
- H-bias address behavior is hedged: "The VIP *appears* to determine the address of `HOFSTR` by OR'ing the address of `HOFSTL` with 2." [VIP > H-Bias Worlds]
- "If `FRMCYC` is set to a value lower than the internal frame counter in between game frames, what happens? Will the next frame be a game frame? Will it wrap around at 15 and keep counting?" [VIP > Miscellaneous Registers > `FRMCYC`]
- `SBOUT` timing conflict: "The formal specification states that `SBOUT` will be cleared after 56 µs, but testing has shown it to persist for as long as 120 µs". The document does not reconcile the two figures. [VIP > Drawing]
- "When the channel is enabled while the envelope's `Enb` is set, it will generate samples of value 0 for the first 5-10 milliseconds but otherwise function normally. It is not clear exactly why this happens or whether it's consistent, so it could bear some further investigation." [VSU > Envelope > Envelope Procedure]
- "Research is needed to determine whether the cache is initialized during reset." [System Reset > CPU]
- "The VSU appears to be initialized to all zeroes/disabled on reset, but this hasn't been definitively verified. If nothing else, `SSTOP` should probably be used on boot." The System Reset section therefore lists no concrete VSU reset values. [System Reset > VSU]

### Internal inconsistencies in the source text

These are printing or wording inconsistencies observed in the document itself; the document does not comment on any of them.

- The ROM Format introduction gives the upper bound of the reserved region as `0xFFFFFFF` (seven hexadecimal digits) while the surrounding text and the header/handler tables use `0xFFFFFFFF`. [ROM Format]
- The exception handler table lists `0xFFFFFF70`–`0xFFFFFF7F` as "Unused", while the List of Exceptions gives handler address `0xFFFFFF60` for the floating-point invalid operation exception whose code is `0xFF70`. [ROM Format > Exception Handlers; CPU > List of Exceptions]
- The object character address formula is `0x00078000 + JCA * 16`, while the background map cell formula is written as `0x00078000 + Character` with no multiplier. [VIP > Objects; VIP > Background Maps]
- The bit-position header row of world attribute halfword 0 prints "19" in the column where 9 would be expected; the field widths listed beneath (1, 1, 2, 2, 2, 1, 1, 2, 4) are self-consistent and total 16 bits. [VIP > Worlds > World Attributes]
- The bit-position header row of `SxEV0` prints "1" in the column where 2 would be expected; the field widths listed beneath (`Value` 4, `Dir` 1, `Interval` 3) are self-consistent and total 8 bits. [VSU > Envelope]
- The software game pad read is described both as "write alternating states for `Soft-Ck` 16 times" and as "a total of 33 writes to `Soft-Ck`". [Game Pad > Game Pad Control > Software Read]
- `SxINT` describes the enable bit as `Enb` in its field table but refers to it as "Enable" in the following prose. [VSU > Channel Control]
