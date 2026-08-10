# Notes: V810 Architecture: Summary

## Source

- File: `v810-architecture-summary.md`
- Type: reference summary (single-sheet architecture overview, presented as headed lists and small tables)
- Extent: 2 pages; 16 headed sections; roughly 450 words
- Version or date stated in document: not stated
- Author or publisher stated in document: not stated
- Title: the Markdown body carries no title line. The accompanying extraction metadata records a page-1 title of "V810 Architecture: Summary".

## Scope

The document is a condensed architecture overview of a processor it calls the V810. It covers, in order: the register set, data types, alignment, the instruction-set categories, instruction execution clock cycles, instruction format, addressing modes, flag behaviour, load-versus-in extension, function call (`jal`), bit string operations, floating point operations, interrupts and exceptions, hardware interlock issues, and the cache.

The document does not describe pin-out, bus timing, package, electrical characteristics, instruction encodings, or the system register file. It gives no register-by-register or instruction-by-instruction reference; every statement is a one-line summary.

## Key concepts

- **Bit String** — a data type the document defines as "any length bit string from or to anywhere in memory". [Data types:]
- **Interlock** — hardware hazard detection that prevents instruction faults; the document contrasts it with "some pipeline architectures" that "allow successive instruction faults to exist". [Important Hardware Issues]
- **CHCW** — "the cache control word (CHCW) register", described as controlling the use of cache. [Cache:]
- **jal** — the function-call operation; the document annotates the section heading "(synthesized through discrete instructions in V810)". [Function Call (jal):]

## Content

### Register set

- General purpose program registers are 32 bit. [Register set:]
- R0 and R26-31 are reserved for explicit hardware operations. [Register set:]
- R1-R5 are used by assembler and compiler. [Register set:]
- R6-25 (20 registers) are available for general program use. [Register set:]
- The document states that multiple registers permit much improved program execution speed. [Register set:]

### Data types

- Integer/Unsigned types are Byte (8 bits), Halfword (16 bits) and Word (32 bits). [Data types:]
- Floating Point format is a 23 bit mantissa with a signed 9 bit exponent. [Data types:]
- Bit String may be any length bit string from or to anywhere in memory. [Data types:]

### Alignment

- Byte order is Little Endian, stated as "All bytes, half words and words must line up to bit 0". [Alignment:]
- Data aligns to byte, half word and word boundaries. [Alignment:]
- Instructions align to halfword and word boundaries. [Alignment:]
- "Truncation is performed if boundaries are mislighted" (transcribed spelling; the document does not define "mislighted" or describe what is truncated). [Alignment:]

### Instruction set categories

The document gives a two-column table of category and function. [Instruction Set:]

| Category | Function (verbatim) |
| --- | --- |
| Data transfer | Register to register and register to or from memory |
| I/O | Input and Output |
| Arithmetic | Signed / unsigned add subtract, multiply and divide |
| Logical | Compare, and, or, not, exclusive or |
| Shift | Logical shift and arithmetic shift |
| System | System register load and store |
| Bit string | Move, and, or, exclusive or, search |
| Floating Point | Add, subtract, multiply, divide, compare, convert |
| Branch | Jump, conditional branch and jump and link |
| Miscellaneous | Trap, RETI, Nop, Halt, and Compare and exchange |

### Instruction format

- The instruction word's internal format is aligned on halfword boundaries. [Instruction Format:]
- "Instructions are may be half word (16 bits) or word (32 bits)" (transcribed wording). [Instruction Format:]

### Addressing modes

- Load / Store instructions affect a + or - 32kb offset from a base register. [Addressing modes:]
- Immediate Load moves a 16 bit value to the upper or lower halfword of a register. [Addressing modes:]
- Function Call changes program execution to a + or - 32mb offset from PC. [Addressing modes:]

### Flags

The three flag statements appear as an unheaded paragraph following the addressing-mode list.

- "Move, load, store in, out, jump and branch instructions do not affect flags" (verbatim, including the missing comma after "store"). [Addressing modes:, following paragraph]
- All other operations affect flags appropriately to their operation. [Addressing modes:, following paragraph]
- Floating point flags are set to signal an invalid result or error condition. [Addressing modes:, following paragraph]

### Load/In

- Load instructions are sign extended into the upper bits. [Load/In:]
- In instructions are zero extended into the upper bits. [Load/In:]

### Function call (jal)

The document gives an ordered sequence. [Function Call (jal):]

1. When a `jal` op is executed the return address is saved to register r31.
2. The return address may then be pushed onto a software stack.
3. The function is then executed.
4. The return address is then popped from the stack back to r31.
5. A jump to the return address stored in r31 is then performed.

### Bit string operations

- Bit strings may be any length and may affect any area of memory. [Bitstring Operation:]
- Search: find first 1 or zero bit up or down from a specified bit. [Bitstring Operation:]
- Move: moves specified bits from a source address to a destination address. [Bitstring Operation:]
- Logical (BitBlt): ands, ors or xors a specified range of bits. [Bitstring Operation:]

### Floating point operations

- The heading names the operations covered: add, subtract, multiply and divide. [Floating point operations:]
- Throughput is stated as ".9 million floating point operations per second at 25 MHz". [Floating point operations:]
- Conversion instructions exist from 32 bit float to/from 32 bit integer. [Floating point operations:]
- Floating point data is handled in normal 32 bit general registers. [Floating point operations:]

### Interrupts and exceptions

- "Virtual Game Boy has 5 levels of hardware maskable interrupts" (verbatim; this is the only place the document names a system rather than the processor). [Interrupts and Exceptions:]
- Software exceptions are produced by TRAP codes and illegal operations. [Interrupts and Exceptions:]
- Interrupts and exceptions branch to fixed addresses to specified routines. [Interrupts and Exceptions:]
- Return from Interrupt or exception (RETI) restores PC and branches to it. [Interrupts and Exceptions:]
- Lower level interrupts may be interrupted by higher level interrupts. [Interrupts and Exceptions:]
- Higher level interrupts complete before responding to lower ones. [Interrupts and Exceptions:]
- Interrupts will "(nest) properly" (the document's own parenthesis). [Interrupts and Exceptions:]

### Important hardware issues

- Some pipeline architectures allow successive instruction faults to exist. [Important Hardware Issues]
- "In the V81 Hardware interlock prevents faults and reduces instructions" (transcribed as "V81"). [Important Hardware Issues]
- Load/Store interlock stops base register change before a load/store hazard. [Important Hardware Issues]
- Flag interlock prevents a conditional branch after a flag modification hazard. [Important Hardware Issues]
- Extra clock cycles are automatically inserted to "flush the pipe" if needed. [Important Hardware Issues]

### Cache

- Access costs: ROM = 3 clock cycles, RAM = 2 clock cycles, Cache = 1 clock cycle. [Cache:]
- Cache size is 1 k bytes, direct mapping, with an 8 byte block and 4 byte sub-block. [Cache:]
- Cache can be enabled/disabled, cleared, and saved to or from memory. [Cache:]
- The cache control word (CHCW) register controls the use of cache. [Cache:]

## Specifications and procedures

### Instruction execution clock cycles

Verbatim table. [Instruction Execution Clock Cycles:]

| Class | Clock cycles |
| --- | --- |
| Most instructions | 1 |
| Load / store | 1 to 3 |
| Integer / logical | 1 except multiply = 13 and divide = 38 |
| Shift | 1 |
| Floating point | 24 to 44 |
| Branch / jump | 1 if branch not taken, 3 if branch taken |
| Bit string | 3 to 12 |

### Floating point clock cycles

- Add = 24, subtract = 26, multiply = 27 and divide = 44 clock cycles. [Floating point operations:]

### Numeric values stated

- Floating point format: 23 bit mantissa, signed 9 bit exponent. [Data types:]
- Load/Store offset range: + or - 32kb from base register. [Addressing modes:]
- Immediate Load width: 16 bit value into upper or lower halfword. [Addressing modes:]
- Function Call range: + or - 32mb from PC. [Addressing modes:]
- Cache: 1 k bytes, 8 byte block, 4 byte sub-block, direct mapping. [Cache:]
- Maskable interrupt levels: 5. [Interrupts and Exceptions:]
- Floating point throughput: .9 million operations per second at 25 MHz. [Floating point operations:]

## Constraints and requirements

- All bytes, half words and words must line up to bit 0 (stated as a requirement of Little Endian alignment). [Alignment:]
- Data must align to byte, half word and word boundaries; instructions must align to halfword and word boundaries. If boundaries are not aligned, truncation is performed. [Alignment:]
- Efficient use of Cache is mandatory for fast applications (the document's own word, "mandatory"). [Cache:]
- The document states cache is best used for often executed loops and routines. [Cache:]
- Registers R0 and R26-31 are reserved for explicit hardware operations; R1-R5 are used by assembler and compiler; only R6-25 are available for general program use. [Register set:]
- Higher level interrupts complete before lower level interrupts are responded to; lower level interrupts may be interrupted by higher level ones. [Interrupts and Exceptions:]

## Stated gaps and ambiguities

- The document names the processor exactly twice, as "V810" in the function-call heading ("synthesized through discrete instructions in V810") and as "V81" in the interlock section ("In the V81 Hardware interlock prevents faults"). The document does not reconcile the two spellings. [Function Call (jal):, Important Hardware Issues]
- The flags paragraph has no heading of its own in the Markdown body, although the extraction metadata records a "Flags:" heading at that position. The three flag statements are therefore anchored only by their position after the addressing-mode list.
- On page 2 the section headings are run together with the first line of their body text in the transcription, for example `**Load/In:**Load instructions are sign extended…` and `**Important Hardware Issues**Some pipeline architectures…`. No separating punctuation survives.
- "Truncation is performed if boundaries are mislighted" — the document neither defines "mislighted" nor states what value is truncated or how. [Alignment:]
- "Instructions are may be half word (16 bits) or word (32 bits)" is ungrammatical as transcribed. [Instruction Format:]
- The document states 5 levels of hardware maskable interrupts but attributes them to "Virtual Game Boy" rather than to the processor, and does not say whether the count is a processor property or a system property. [Interrupts and Exceptions:]
- The document lists cache access as 1 clock cycle and "Most instructions" as 1 clock cycle, but does not state how the ROM/RAM/Cache access costs combine with the per-instruction clock counts. [Cache:, Instruction Execution Clock Cycles:]
- Floating point clock cycles are given twice with different framing: the table says "24 to 44" and the floating point section says "Add = 24, subtract = 26, multiply = 27 and divide = 44". Compare is listed as a floating point instruction in the instruction-set table but has no clock figure anywhere. [Instruction Execution Clock Cycles:, Floating point operations:, Instruction Set:]
- The document mentions a "software stack" for return addresses but never says where the stack pointer lives or which register holds it. [Function Call (jal):]
- No instruction mnemonics are given beyond `jal`, `RETI`, `Nop`, `Halt`, `Trap` and "Compare and exchange"; no encodings, operand orders, or system register numbers appear anywhere in the document.
- Bit string clock cycles are given as "3 to 12" without saying which operations sit at each end of the range. [Instruction Execution Clock Cycles:]
