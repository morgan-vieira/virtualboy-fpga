# Notes: V810 Programming (V810 Seminar)

## Source

- File: `v810-seminar-slides-2-v810-programming.md`
- Type: slides. It is a presentation deck transcribed to Markdown. Several timing diagrams survive only as image references
- Extent: 25 slides
- Version or date stated in document: "February 21, 1995" on the title slide. Footer codes of the form `V-1123-0295-Ynn` appear on two slides. [slide 1, slides 4, 11]
- Author or publisher stated in document: "NEC", "Hitoshi Yamahata" and "NEC Corporation" on the title slide, "NEC Electronics Inc." on the closing slide. [slides 1, 25]
- Slide numbers used as anchors in these notes are 1-based positions in the deck. They agree with the deck's own footer codes where those survive: `V-1123-0295-Y04` on slide 4 and `V-1123-0295-Y11` on slide 11.
- The transcription's first slide also carries the text "PLANET VIRTUAL BOY" and the URL `HTTP://WWW.VR32.DE`, which is not part of the NEC titling. [slide 1]

## Scope

The deck is a programming and optimisation guide for the V810 processor, organised into four sections announced by divider slides: "Assembler Programming" [slide 2], "Pipelining" [slide 6], "System level Issue" [slide 12] and "Others" [slide 20]. It covers register conventions, assembler sections and small-data-area access, pipeline hazards with measured timings, enabling and disabling interrupts, handler coding, cache control, data alignment, the call and return convention, and branch-avoidance coding tricks.

The deck is written around short assembler listings and measured execution times. It does not give instruction encodings, does not enumerate the system register file (only registers #5 and #24 are named), and does not describe the hardware outside the programmer's view.

## Key concepts

- **hsp.** Handler Stack Pointer, register r2. [slide 3]
- **sp.** Stack Pointer, register r3. [slide 3]
- **gp.** Global Pointer, register r4. [slide 3]
- **tp.** Text Pointer, register r5. [slide 3]
- **lp.** Link Pointer, register r31. "'Jal' saves return address". [slide 3]
- **SDA (Small Data Area).** The `.sdata` and `.sbss` sections. [slide 4]
- **CHCW.** Cache Control Word, system register #24. Its `ICE` bit enables and disables cache. [slide 18]
- **PSW.** System register #5. Bit 12 is the `ID` flag that disables interrupts. [slide 13]
- **SETFcc.** "SETFcc reg". If conditions "cc" are satisfied then reg = 1 else reg = 0. [slide 24]
- **ca732.** The toolchain whose section convention the example on slide 4 follows ("Section convention of this example are cases of 'ca732'"). [slide 4]

## Content

### Assembler Programming section (slides 2–5)

#### Register Convention (slide 3)

Verbatim table. [slide 3]

| Register | Name                          | Note                                                                         |
| -------- | ----------------------------- | ---------------------------------------------------------------------------- |
| r0       | Zero Register                 | Hardware Zero.                                                               |
| r1       | Reserved for Assembler        | Assembler, linker and System reserved. (depend on individual software tools) |
| r2       | Handler Stack Pointer (hsp)   | Assembler, linker and System reserved. (depend on individual software tools) |
| r3       | Stack Pointer (sp)            | Assembler, linker and System reserved. (depend on individual software tools) |
| r4       | Global Pointer (gp)           | Assembler, linker and System reserved. (depend on individual software tools) |
| r5       | Text Pointer (tp)             | Assembler, linker and System reserved. (depend on individual software tools) |
| r6 ~ r25 | (no name given)               | (no note given)                                                              |
| r26      | String Destination Bit Offset | Parameters and work registers for Bit string Instructions.                   |
| r27      | String Source Bit Offset      | Parameters and work registers for Bit string Instructions.                   |
| r28      | String Length                 | Parameters and work registers for Bit string Instructions.                   |
| r29      | String Destination            | Parameters and work registers for Bit string Instructions.                   |
| r30      | String Source (\*)            | Parameters and work registers for Bit string Instructions.                   |
| r31      | Link Pointer (lp)             | "Jal" saves return address.                                                  |

- Footnote: "(\*) r30 also used by 'caxi', 'mul', 'mulu', 'div' and 'divu'." [slide 3]

#### Section (slide 4)

- The address space is drawn from 0x00000000 at the top to 0xFFFFFFFF at the bottom, with `r4(gp) ->` and `r5(tp) ->` marking pointer positions into it. [slide 4]
- Example source layout, verbatim: `.data` / `table:` / `.byte 0x11,0x12` / `.sdata` / `.sbss` / `.bss` / `.comm buf, 1024, 4` / `.lcomm tmp, 512, 4` / `.text` / `start:` / `mov 0,r10`. [slide 4]
- ".text" section. Program Body. [slide 4]
- ".data" section. Data with initial value. Directives are `.byte`, `.hword`, `.word`. [slide 4]
- ".bss" section. Data without initial value. Directives are `.lcomm`, `.comm`. [slide 4]
- SDA section (Small Data Area). `.sdata` and `.sbss`. [slide 4]
- "Section convention of this example are cases of 'ca732'." [slide 4]

#### Data access using "gp" (slide 5)

- "Assembler knows 'gp' indirect mode by using '$' instead of '#'." [slide 5]
- "'gp' indirect keeps displacement small enough to fit 16 bit length." [slide 5]
- Ordinal Data listing, verbatim. Direct access is `ld.w #LINE_DX, r10` and `ld.w #LINE_DY, r11`. Register indirect access is `mov #LINE_DX, r20` / `ld.w [r20], r10` / `mov #LINE_DY, r20` / `ld.w [r20], r11`. The data sits in `.data` with `.align 4`, `LINE_DX: .word 120`, `LINE_DY: .work 80`. Two lines of the register-indirect form are marked `<- (*)` in the source, with no footnote text for the marker. [slide 5]
- "gp" Register Indirect listing, verbatim. Direct access is `ld.w $LINE_DX, r10` and `ld.w $LINE_DY, r11`. Register indirect access is `movea $LINE_DX, gp, r20` / `ld.w [r20], r10` / `movea $LINE_DY, gp, r20` / `ld.w [r20], r11`. The data sits in `.sdata` with `.align 4`, `LINE_DX: .word 120`, `LINE_DY: .work 80`. [slide 5]

### Pipelining section (slides 6–11)

The divider lists three subtopics: Load / Store instruction, Flag Hazard, Register Hazard. [slide 6]

#### Load and Store (slide 7)

- The topic is the order of adjacent load / store. [slide 7]
- "Load invokes data read bus cycle before execution." [slide 7]
- "Store invokes data write bus cycle after execution." [slide 7]
- "-> Order; 'st -> ld' causes pipeline jam." [slide 7]
- Measurement condition: "[Condition: V810, 25MHz, 1wait, 16-bit bus width, Cache ON.] Total time of all iteration running 0x100000 loop counts." [slide 7]

#### Back-to-back Load (slide 8)

- "Load instructions are better to be gathered." [slide 8]
- "-> Load invokes data access bus cycle at the early stage of pipeline. So, in pipeline, load has different pipeline sequence from typical instruction." [slide 8]
- Same measurement condition line as slide 7, with 0x100000 loop counts. [slide 8]

#### Back-to-back Store (slide 9)

- "Pipeline flow of Store is isolated from it's data write bus cycle by two write buffer." [slide 9]
- "-> Better to insert other instructions between two Stores. (Best number of inserting instruction is different in the case of system configuration; i.e., bus width, bus wait, etc.)" [slide 9]

#### Flag Hazard (slide 10)

- "Flag hazard interlocks pipeline for 2 clocks." [slide 10]
- "-> Can avoid interlock by inserting other 'effective' instruction (if possible). (Nothing is better than inserting 'nop' instructions.)" [slide 10]
- Same measurement condition line, 0x100000 loop counts. [slide 10]

#### Register Hazard (slide 11)

- "Register hazard interlocks pipeline for 2 clocks." [slide 11]
- "-> Can avoid interlock by inserting other 'effective' instruction (if possible). (Nothing is better than inserting 'nop' instructions.)" [slide 11]
- Measurement condition: "[Condition: V810, 25MHz, 1wait, 16-bit bus width, Cache ON.] Total time of all iteration running 0x10000 loop counts." [slide 11]

### System level Issue section (slides 12–19)

The divider lists two subtopics: Interrupt, Cache. [slide 12]

#### Interrupt Enable/Disable (slide 13)

- "Interrupt Enable/Disable by PSW.bit12 (ID flag)." [slide 13]

#### Interrupt Handler (slide 14)

- "Control is transferred to one of sixteen interrupt handlers according to INT level." [slide 14]
- "-> ( INT level 'n' ; INTn -> 0xFFFFFFEn0)." (transcribed exactly, with nine hex digits) [slide 14]
- Handler table, verbatim [slide 14]:

  | Address      | Instruction        |
  | ------------ | ------------------ |
  | `0xFFFFFE00` | `jr int_handler_0` |
  | `0xFFFFFE10` | `jr int_handler_1` |
  | `0xFFFFFE20` | `jr int_handler_2` |
  | ellipsis     | ellipsis           |
  | `0xFFFFFEF0` | `jr int_handler_f` |

- Annotation: "Not a handler address here! Use V810 instructions. (example: 'jr')". [slide 14]

#### Saving Register in INT Handler (slide 15)

- "Registers, used in interrupt handler, must be saved explicitly." [slide 15]
- "Don't forget to save 'r1:assembler work' and 'r30:result of mul/div'." [slide 15]

#### Interrupt Tips (1) (slide 16)

- "INT handler may destroy contents of current stack." [slide 16]
- "-> Keeping interrupt in mind when changing 'sp'." [slide 16]
- The slide contrasts a "Recommended coding" column with a "Danger if interrupted during push/pop operation" column, for both a push routine and a pop routine. [slide 16]

#### Interrupt Tips (2) (slide 17)

- "Some type of I/O device must be accessed by 'in' instruction." [slide 17]
- "-> 'load' instruction causes side effect in such I/O device." [slide 17]
- "-> keeping in mind difference(\*) between 'load' and 'in'." [slide 17]
- "(\*): Read bus cycle of 'in' starts when execution of 'in' started." [slide 17]
- The example is the pipeline flow of `ld.b #io_addr, r10`, shown as two diagrams, with the conclusion "Read I/O port twice! -> cause side effect to some type of I/O device". [slide 17]

#### Cache Enable/Disable (slide 18)

- "Cache Enable/Disable by CHCW (Cache Control Word)." [slide 18]
- "Contents of cache are preserved during disabled period." [slide 18]

#### Cache Tips (slide 19)

- "Use in loop (with enough loop count)." [slide 19]
- "Control explicitly (enable/disable/clear)." [slide 19]
- "Know well about cache behavior." [slide 19]
- "-> At the first execution of loop, Cache replace tends to take much more time than Cache-off mode." [slide 19]
- The worked example is annotated "Cache hit during loop execution". [slide 19]

### Others section (slides 20–24)

The divider lists three subtopics: Data Alignment, Call / Return, Advanced Technique. [slide 20]

#### Data Alignment (slide 21)

- "Data must be aligned to each data size." [slide 21]
- "Word(32 bit) / Half word(16 bit) data -> 32 / 16 bit boundary." [slide 21]
- "Not aligned address truncated by H/W." [slide 21]

#### Call / Return (slide 22)

- "Call function by 'jal', and Return by 'jmp [lp]'." [slide 22]
- "Save/Restore return address in 'lp' by software explicitly." [slide 22]
- The slide contrasts an x86 listing (`call PRINT` … `PRINT:` … `ret`) with the V810 equivalent. [slide 22]

#### Pipeline Coding Tip (1) (slide 23)

- "Branch/Jump disturbs pipeline flow." [slide 23]
- "-> avoid branch/jump by optimizing code (if possible)." [slide 23]
- Worked example: calculate absolute value, `r10 = abs(r10)`. [slide 23]
- "In many cases, it's hard not to use a conditional branch like the above example. Conditional branch requires 3 clocks when taken, 1 clock when not taken. So, one strategy is selecting a branch condition rarely taken." [slide 23]

#### Pipeline Coding Tips (2) (slide 24)

- "Branch/Jump disturbs pipeline flow." [slide 24]
- "-> avoid branch/jump by optimizing code (if possible)." [slide 24]
- Worked example, get sign: "if ( r10 > 0 ) then r10 = 1 else if ( r10 == 0 ) then r10 = 0 else r10 = -1". [slide 24]
- "SETFcc reg": if conditions "cc" are satisfied then reg = 1 else reg = 0. [slide 24]

### Closing (slide 25)

- Closing slide: "NEC" / "NEC Electronics Inc." [slide 25]

## Specifications and procedures

### Disable Interrupt (DI) sequence (slide 13)

```
stsr  5, r1          -- get system register #5(PSW)
ori   0x1000, r1, r1 -- ID <- "1"
ldsr  r1, 5          -- set system register #5(PSW)
```

### Enable Interrupt (EI) sequence (slide 13)

```
stsr  5, r1          -- get system register #5(PSW)
andi  0xEFFF, r1, r1 -- ID <- "0"
ldsr  r1, 5          -- set system register #5(PSW)
```

### Interrupt handler register save/restore (slide 15)

Example given for r1, r6, r7 used in the interrupt handler, verbatim.

```
interrupt_handler:
    add   -4*3, sp      -- expand stack area
    st.w   r1, 4*0[sp]
    st.w   r6, 4*1[sp]
    st.w   r7, 4*2[sp]
    :
    :
    ld.w   4*0[sp], r1
    ld.w   4*1[sp], r6
    ld.w   4*2[sp], r7
    add   4*3, sp      -- restore stack area
    reti                     -- return from interrupt
```

### Push and pop routines (slide 16)

Recommended push routine:

```
add -4*3, sp
st.w r1, 4*0[sp]
st.w r6, 4*1[sp]
st.w r7, 4*2[sp]
```

Push routine labelled "Danger if interrupted during push/pop operation":

```
st.w r1, -4*3[sp]
st.w r6, -4*2[sp]
st.w r7, -4*1[sp]
add -4*3, sp
```

Recommended pop routine:

```
ld.w 4*0[sp], r1
ld.w 4*1[sp], r6
ld.w 4*2[sp], r7
add 4*3, sp
```

Pop routine labelled "Danger if interrupted during push/pop operation":

```
add 4*3, sp
ld.w -4*3[sp], r1
ld.w -4*2[sp], r6
ld.w -4*1[sp], r7
```

### Cache enable and disable (slide 18)

```
Enable Cache      -- CHCW.ICE <- "1"
mov            2, r1
ldsr           r1, 24      -- set system register #24(CHCW)
```

```
Disable Cache     -- CHCW.ICE <- "0"
ldsr           r0, 24      -- set system register #24(CHCW)
```

### Cache example: zero clear BUF(100 byte) (slide 19)

```
mov 100, r10
mov #BUF, r11
mov 2, r1
ldsr r1, 24 -- Cache=ON
LABEL:
st.b r0, [r11]
add 1, r11
add -1, r10
bnz LABEL
ldsr r0, 24 -- Cache=OFF
```

### Call / Return (slide 22)

x86 form shown for contrast:

```
  :
  call PRINT
  :
  :
  PRINT:
  :
  :
  ret
```

V810 form:

```
  :
  jal PRINT -- call function "PRINT"
  :
  :
  PRINT:
  add -4, sp --saving return address
  st.w lp, [sp]
  :
  :
  ld.w [sp], lp --restoring return address
  add 4, sp
  jmp [lp] --return to caller
```

### Data alignment example (slide 21)

Listing labelled "-- [Bad] Example":

```
mov   #not_aligned_d, r20
ld.h   [r20], r10
ld.w   [r20], r11
mov   #aligned_c, r20
add   #0x1, r20
jmp   [r20]
aligned_c:
    nop
    :
    .data
    .align 4
    .byte 0xab
not_aligned_d:
    .word 0x12345678
```

Stated results, verbatim:

- `<-- after "ld.h", r10=0x78ab`
- `<-- after "ld.w", r10=0x345678ab`
- `<-- jumped to "aligned_c"`

### Absolute value example (slide 23)

Normal version, "(6/6 clocks)":

```
cmp   r0, r10
bgt    LABEL
not    r10, r10
add    1, r10
LABEL:
```

Optimal version, "(4 clocks)":

```
mov   r10, r1
sar    0x1f, r1
xor    r1, r10
sub   r1, r10
```

### Get-sign example (slide 24)

Normal version, "(8/6/9 clocks)":

```
cmp   r0, r10
bz     L2
bgt    L1
mov   -1, r10
br     L2
L1:
mov   1, r10
L2:
```

Optimal version, "(4 clocks)":

```
cmp   r0, r10
setfgt  r10
setflt  r1
sub    r1, r10
```

### Measured timings

All timings below are quoted under the deck's stated condition "[Condition: V810, 25MHz, 1wait, 16-bit bus width, Cache ON.]".

#### Back-to-back Store (slide 9)

Consecutive stores, "(629msec)":

```
movhi 0010, r0, r20
movea 1000, r0, r10
LABEL:
st.b      r11, [r10]
st.b      r12, 1[r10]
st.b      r13, 2[r10]
mov       1, r14
mov       2, r15
add       -1, r20
bnz       LABEL
```

Stores separated by other instructions, "(545msec)":

```
movhi 0010, r0, r20
movea 1000, r0, r10
LABEL:
st.b      r11, [r10]
mov       1, r14
st.b      r12, 1[r10]
mov       2, r15
st.b      r13, 2[r10]
add       -1, r20
bnz       LABEL
```

#### Flag Hazard (slide 10)

"(377msec)":

```
movhi   0010, r0, r20
movea   1000, r0, r10
LABEL:
st.b      r0, [r10]
add       1, r10
add       -1, r20
bnz       LABEL
```

"(335msec)":

```
movhi   0010, r0, r20
movea   1000, r0, r10
LABEL:
st.b      r0, [r10]
add       -1, r20
movea   1, r10, r10
bnz       LABEL
```

#### Register Hazard (slide 11)

"(545msec)", with the `movea` and `st.b` lines marked by arrows in the source:

```
movhi   0010, r0, r20
LABEL:
movea   1000, r0, r10
st.b    r0, [r10]
mov     1, r11
add     r11, r12
add     -1, r20
bnz     LABEL
```

"(461msec)", with the `movea` and `st.b` lines marked by arrows in the source:

```
movhi   0010, r0, r20
LABEL:
movea   1000, r0, r10
mov     1, r11
add     r11, r12
st.b    r0, [r10]
add     -1, r20
bnz     LABEL
```

### Mnemonics and directives named anywhere in the deck

Instructions: `mov`, `movea`, `movhi`, `ld.b`, `ld.h`, `ld.w`, `st.b`, `st.w`, `in`, `add`, `sub`, `cmp`, `not`, `xor`, `ori`, `andi`, `sar`, `mul`, `mulu`, `div`, `divu`, `caxi`, `jal`, `jmp`, `jr`, `br`, `bz`, `bnz`, `bgt`, `setfgt`, `setflt`, `SETFcc`, `nop`, `stsr`, `ldsr`, `reti`. [slides 3, 5, 9, 10, 11, 13, 14, 15, 17, 18, 19, 21, 22, 23, 24]

Assembler directives: `.text`, `.data`, `.sdata`, `.sbss`, `.bss`, `.byte`, `.hword`, `.word`, `.comm`, `.lcomm`, `.align`. Also `.work`, which appears twice in slide 5's listings. [slides 4, 5]

## Constraints and requirements

- Registers used in an interrupt handler must be saved explicitly. The deck states the saving as a requirement, not a suggestion. [slide 15]
- The deck warns specifically not to forget saving r1 (assembler work) and r30 (result of mul/div) in an interrupt handler. [slide 15]
- Data must be aligned to each data size: word (32 bit) to a 32 bit boundary, half word (16 bit) to a 16 bit boundary. A misaligned address is truncated by hardware. [slide 21]
- Registers r0 through r5 and r26 through r31 carry conventional roles. Registers r1 through r5 are marked "Assembler, linker and System reserved. (depend on individual software tools)". [slide 3]
- r30 is used by `caxi`, `mul`, `mulu`, `div` and `divu` in addition to its bit-string role. [slide 3]
- Some I/O devices must be accessed with `in` rather than `load`, because `load` causes a side effect on such devices by reading the port twice. [slide 17]
- The interrupt vector locations hold instructions, not handler addresses: "Not a handler address here! Use V810 instructions. (example: 'jr')". [slide 14]
- The deck recommends adjusting `sp` before storing on push, and after loading on pop, so an interrupt taken mid-sequence cannot destroy the saved registers. [slide 16]
- The deck recommends gathering load instructions together. [slide 8]
- The deck recommends inserting other instructions between two stores, and notes the best number of inserted instructions depends on system configuration such as bus width and bus wait. [slide 9]
- The deck recommends avoiding branch and jump where code can be optimised instead, and where a conditional branch is unavoidable, selecting a branch condition that is rarely taken. [slides 23, 24]
- Conditional branch costs 3 clocks when taken and 1 clock when not taken. [slide 23]
- Flag hazard and register hazard each interlock the pipeline for 2 clocks. [slides 10, 11]
- The deck recommends using cache in loops with enough loop count, controlling it explicitly, and knowing its behaviour, warning that the first execution of a loop tends to take much more time under cache replacement than in Cache-off mode. [slide 19]
- Cache contents are preserved during a disabled period. [slide 18]

## Stated gaps and ambiguities

- Slide 14 writes the vector formula as "INTn -> 0xFFFFFFEn0", which is nine hex digits, while the table on the same slide lists eight-digit addresses 0xFFFFFE00 through 0xFFFFFEF0. The deck does not reconcile the two forms. [slide 14]
- Slide 21 states both results land in r10, "after 'ld.h', r10=0x78ab" and "after 'ld.w', r10=0x345678ab", but the listing loads the word into r11. The deck does not reconcile the two. [slide 21]
- Slides 7, 8, 9 and 10 quote loop counts of 0x100000 while slide 11 quotes 0x10000. The deck does not explain the difference. [slides 7, 8, 9, 10, 11]
- The sentences "Can avoid interlock by inserting other 'effective' instruction (if possible). (Nothing is better than inserting 'nop' instructions.)" appear on both hazard slides. As transcribed, the parenthetical reads as praise for `nop` while the surrounding advice is to insert useful instructions instead. The deck does not clarify. [slides 10, 11]
- The "Others" divider lists three subtopics including "Advanced Technique", but no later slide carries that title. Slides 23 and 24 are titled "Pipeline Coding Tip (1)" and "Pipeline Coding Tips (2)". [slides 20, 23, 24]
- `LINE_DY: .work 80` appears in both listings on slide 5. The deck's own directive list on slide 4 includes `.word` but not `.work`. [slides 4, 5]
- Slide 5's "Ordinal Data" listing marks two lines with `<- (*)` but the slide contains no footnote text for the marker. [slide 5]
- Slides 7, 8, 9, 10 and 11 each present measurement figures whose accompanying pipeline timing diagrams survive only as image references. For slides 7 and 8 no code listing survives at all, so the compared sequences behind those measurements are not recoverable from the text. [slides 7, 8]
- Slide 17's example, the pipeline flow of `ld.b #io_addr, r10`, is carried entirely by two diagrams. Only the conclusion "Read I/O port twice!" survives as text. [slide 17]
- Slide 4's address-space figure is transcribed as a table whose only populated cell holds the example source listing, with `0x00000000`, `r4(gp) ->`, `r5(tp) ->` and `0xFFFFFFFF` appearing outside it as loose lines. The positions of `gp` and `tp` relative to the sections are therefore not recoverable. [slide 4]
- The deck names only two system registers by number: #5 (PSW) and #24 (CHCW). No other system register, and no other PSW bit beyond bit 12 (ID), is described. [slides 13, 18]
- `CHCW.ICE` is set by writing the value 2 to CHCW, implying a bit position, but the deck never states which bit `ICE` is. [slide 18]
- Slide 3 gives no role or note for r6 ~ r25. [slide 3]
- Slide 3 lists `caxi` as a user of r30 but the deck never describes what `caxi` does. [slide 3]
- Standalone digits "2", "3" and "4" appear in the transcription immediately before the "Pipelining", "System level Issue" and "Others" divider slides. The deck does not label what they number. [slides 6, 12, 20]
- Footer codes survive on only two slides, 4 and 11. The transcription carries no slide numbers of its own.
- Immediate operands in the timing listings are written without a radix marker (`movhi 0010, r0, r20`, `movea 1000, r0, r10`), and the deck does not state whether they are decimal or hexadecimal. [slides 9, 10, 11]
