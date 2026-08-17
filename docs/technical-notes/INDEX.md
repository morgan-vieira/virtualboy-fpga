# Index of document notes

One notes file per source document. Each was written and audited independently
against its own document only; no fact in a notes file was imported from another
document in this set.

This index adds the one thing a single notes file cannot carry: how the documents
relate to each other, and where they disagree. Relationships below are recorded
only where the documents themselves evidence them, with anchors on both sides.
Contradictions are recorded, not resolved — resolving would require knowing which
source is authoritative, which none of these documents states.

## Documents

| Notes file                                                                                                                                                                | Document title as stated                                                | Type                                                          | Extent                                                    | Stated date / number                                                             | Scope in one line                                                                                                                                                                                                                                                                                |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- | ------------------------------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| [intel/cyclone-v-device-handbook-vol-1](intel/cyclone-v-device-handbook-vol-1.notes.md)                                                                                   | Cyclone V Device Handbook, Volume 1: Device Interfaces and Integration  | reference handbook                                            | 327 pages; ~74,000 words; 10 chapters                     | every chapter dated `2023.10.18`; CV-52001–CV-52010                              | Device-level interfaces of the Cyclone V FPGA family: logic fabric, embedded memory, DSP blocks, clocks and PLLs, I/O, external memory interfaces, configuration, SEU mitigation, JTAG, power management.                                                                                        |
| [virtual-boy/u10082ej1v0um00-v810-family-users-manual](virtual-boy/u10082ej1v0um00-v810-family-users-manual.notes.md)                                                     | V810 Family 32-Bit Microprocessor User's Manual (architecture volume)   | architecture user's manual                                    | ~31,000 words; body pp.1–143; 9 chapters + appendices A–C | none stated in body; `U10082EJ1V0UM00` in filename                               | Architecture of the NEC V810 family (V805, V810, V820, V821): register set, data types, address space, instruction formats and full instruction set, interrupts and exceptions, cache dump/restore, debug support, reset.                                                                        |
| [virtual-boy/u10661ej5v0um00-v805-v810-users-manual](virtual-boy/u10661ej5v0um00-v805-v810-users-manual.notes.md)                                                         | V805, V810 32/16-, 32-Bit Microprocessor — Hardware                     | hardware user's manual                                        | 90 transcribed pages; body pp.1–75; ~17,900 words         | no date stated; document number `U10661EJ5V0UM00`                                | Hardware functions of the V805 (µPD70731, 16-bit data bus) and V810 (µPD70732, 32-bit data bus): overview and register set, pin functions, bus interface, interrupt and exception, reset.                                                                                                        |
| [virtual-boy/u10691ej3v0ds00-v810-data-sheet](virtual-boy/u10691ej3v0ds00-v810-data-sheet.notes.md)                                                                       | V810 32-bit Microprocessor Data Sheet (µPD70732)                        | data sheet                                                    | contents to p.62; ~18,000 words; 12 sections              | no date stated in body                                                           | Pin functions, registers, data types, address space, bus interface, interrupts, cache, reset, instruction-mnemonic summary, electrical specifications for three supply-voltage ranges, packages, soldering conditions.                                                                           |
| [virtual-boy/v810-architecture-summary](virtual-boy/v810-architecture-summary.notes.md)                                                                                   | V810 Architecture: Summary (title recorded only in extraction metadata) | reference summary                                             | 2 pages; 16 headed sections; ~450 words                   | not stated                                                                       | Single-sheet condensed overview of the V810: registers, data types, alignment, instruction categories, clock cycles, addressing modes, flags, function call, bit strings, floating point, interrupts, interlock, cache.                                                                          |
| [virtual-boy/v810-seminar-slides-1-introduction-architecture-tips](virtual-boy/v810-seminar-slides-1-introduction-architecture-tips.notes.md)                             | V810 Introduction / V810 Architecture / Programming Tips & Optimization | slides                                                        | 38 slides                                                 | February 21, 1995; footer codes `V-1123-0295-WWnn`                               | Seminar deck introducing the V810: CISC vs RISC, pipelining and cache, the architecture proper, execution clocks, addressing modes, floating point, interrupt/exception model, hardware interlock.                                                                                               |
| [virtual-boy/v810-seminar-slides-2-v810-programming](virtual-boy/v810-seminar-slides-2-v810-programming.notes.md)                                                         | V810 Programming (Hitoshi Yamahata)                                     | slides                                                        | 25 slides                                                 | February 21, 1995; footer codes `V-1123-0295-Ynn`                                | Seminar deck on V810 assembler programming: register and section conventions, `gp` indirect addressing, pipeline hazards with measured timings, interrupt enable/disable and handlers, cache control, alignment, call/return, branch elimination.                                                |
| [virtual-boy/vb-sacred-tech-scroll](virtual-boy/vb-sacred-tech-scroll.notes.md)                                                                                           | Virtual Boy — Sacred Tech Scroll                                        | hardware reference (single-page HTML)                         | ~34,000 words; 11 top-level parts plus About/References   | May 21, 2026; Guy Perfect, produced for Planet Virtual Boy                       | End-to-end Virtual Boy hardware reference: memory map, ROM format, NVC/V810 CPU with full instruction set and opcode map, communication port, game pad, game pak, timer, wait controller, VIP, VSU, power-on reset state.                                                                        |
| [virtual-boy/virtual-boy-controller](virtual-boy/virtual-boy-controller.notes.md)                                                                                         | none in body; article title carried only by the filename                | MediaWiki markup (wikitext)                                   | 34 lines; ~200 words including markup                     | not stated                                                                       | The controller's 16-bit serial report after strobing, bit 0 through bit 15, compared to the SNES controller report, plus a four-item References section.                                                                                                                                         |
| [virtual-boy/licensed/virtual-boy-development-manual](virtual-boy/licensed/virtual-boy-development-manual.notes.md)                                                       | Virtual Boy Development Manual                                          | hardware programming manual plus licensing and content policy | ~37,000 words; paginated SECTION-CHAPTER-PAGE             | `D.C.N. NOA-06-8085-001 REV C`, February 17, 1995; Nintendo; marked Confidential | Virtual Boy hardware for licensed developers: scanner display unit, NVC central processor, VIP image processor, VSU sound processor, their memory maps, registers, data structures and timing, plus the NOA approval process, stereoscopic-viewing guidelines, and content policy.               |
| [virtual-boy/licensed/vue-development-system-preliminary-operation-manual](virtual-boy/licensed/vue-development-system-preliminary-operation-manual.notes.md)             | VUE Development System Preliminary Operation Manual                     | operation manual / tool reference                             | 5,785 lines; ~38,800 words; PDF pages 0–242               | `D.C.N. NOA-06-8086-001 REV A`, March 1, 1995; Nintendo; marked Confidential     | Operation of the VUE Development System: cabinet and interface-board installation, DOS setup, the NDEBUG windowing environment menu by menu, program and sound development workflows, the ISAS assembler, the ISLK linker and ISX format, NDEBUG line commands, warning messages, function keys. |
| [virtual-boy/licensed/virtual-boy-technical-symposium-95-vue-development-system](virtual-boy/licensed/virtual-boy-technical-symposium-95-vue-development-system.notes.md) | VUE DEVELOPMENT SYSTEM                                                  | product overview                                              | 157 lines; 7 pages in the original                        | no date stated; only "around mid-May, 1995" as availability                      | Product overview of the VUE Development System: bundled hardware, disk contents by executable name, host-PC requirements, debugger windows and features, assembler and linker, purchasable options, price list, evaluation PCB configurations.                                                   |
| [virtual-boy/licensed/vucc-compiler](virtual-boy/licensed/vucc-compiler.notes.md)                                                                                         | none stated; first headings are "Contents:" and "vucc version"          | command and option reference                                  | 156 lines; 6 pages in the original                        | not stated; refers to "the current version" without a number                     | The `vucc` C toolchain: the four commands (`vucc`, `cpp`, `cparse`, `cgrind`), the compiler-driver option set grouped by phase, ANSI C conformance, three structure restrictions, and the register calling convention.                                                                           |

## Relationships evidenced in the documents

### The three NEC processor documents declare each other as a set

- The data sheet names both manuals on its front page — "V805(TM), V810 User's Manual Hardware : U10661E" and "V810 Family User's Manual Architecture : U10082E" — and states they "should be read before starting design work" [u10691, front page].
- The hardware manual states it is the HARDWARE volume of a two-volume set and defers instruction functions to the "V810 FAMILY™ USER'S MANUAL ARCHITECTURE" [u10661, INTRODUCTION "Organization"], and electrical specifications to "each DATA SHEET" [u10661, INTRODUCTION "How to read this manual"].
- The architecture manual states the family User's Manuals consist of hardware and architecture versions per device and that it is the architecture version [u10082, INTRODUCTION "Organization"], deferring hardware functions to "USER'S MANUAL–HARDWARE" and electrical specifications to the data sheet [u10082, INTRODUCTION "How to read this manual"].
- The division holds in the content: the hardware manual contains no instruction encodings, no cycle counts, and no AC/DC characteristics [u10661, Scope].

### The Sacred Tech Scroll cites the architecture manual, with a different attribution

- The Sacred Tech Scroll's reference list names "V810 Family™ 32-bit Microprocessor User's Manual", October 1995, Document No. U10082EJ1V0UM00 (1st edition), and attributes it to **Renesas Technology Corporation** [vb-sacred-tech-scroll, About > References].
- The manual so identified states its publisher as **NEC Corporation** and states no publication date anywhere in its body [u10082, front matter; u10082, Source].
- The attribution difference and the date are not reconciled by either document. The architecture manual does not cite the Sacred Tech Scroll.
- The Sacred Tech Scroll also cites two documents not present in this set: "V830 Family™ 32-bit Microprocessor User's Manual", U12496EJ2V0UM00, and "IAR Assembler Reference Guide for V850", AV850-4 [vb-sacred-tech-scroll, About > References].

### The Development Manual defers V810 detail to an NEC manual it names ambiguously

- The Development Manual states it describes only those NVC functions unique to the NVC, and refers the reader to "V810™ 32-bit Microprocessor µPD70732 User's Manual" for general V810 operation [virtual-boy-development-manual, Sec.4 Ch.1]. Its cover states "V810™ is a trademark of Nippon Electric Co., Ltd." [virtual-boy-development-manual, cover page].
- No document in this set carries that exact title. The data sheet is the µPD70732 document [u10691, front page]; the hardware manual covers µPD70732 under the name V810 [u10661, Scope]. Which is intended is not stated in any of the three.

### The Operation Manual defers submission rules to a chapter that carries no content

- The Operation Manual defers game-submission rules to the "Submission Requirements" chapter of the "Virtual Boy Development Manual" [vue-development-system-preliminary-operation-manual, Sec.2 ch.1 §1.6].
- That chapter in the Development Manual states it is "currently under development" and carries no content in the revision transcribed [virtual-boy-development-manual, Sec.1 Ch.2].
- The Operation Manual separately defers register detail to the "V810 User's Manual" [vue-development-system-preliminary-operation-manual, Sec.1 ch.4 §4.2.5], without a document number.

### The Operation Manual and the Symposium overview describe the same system

- The Symposium overview states the system comprises a VUE Debugger, Display Unit, Virtual Boy Controller, Assembler (ISAS/ISAS4G), Linker (ISLK/ISLK4G), and control software ISW [virtual-boy-technical-symposium-95, L5], with disk contents `ISAS.EXE`/`ISAS4G.EXE`, `ISLK.EXE`/`ISLK4G.EXE`, `ISW.EXE`, `ISSPCDRV`, `DOS4GW.EXE` [virtual-boy-technical-symposium-95, L25–29].
- The Operation Manual's "Materials Supplied" lists eight files: `ISSPCDRV.COM`, `ISW.EXE`, `ISW.PAL`, `ISW.HLP`, `ISDW.HLP`, `ISWASM.BAT`, `ISWEDIT.BAT`, `DOS4GW.EXE` [vue-development-system-preliminary-operation-manual, Preface, Materials Supplied]. `ISAS.EXE` and `ISLK.EXE` are absent from that list even though the manual documents ISAS and ISLK in full [same, Sec.4; Sec.5]. The two lists are not reconciled by either document.
- Both name **V810SF** as the processor the assembler targets [virtual-boy-technical-symposium-95, L87; vue-development-system-preliminary-operation-manual, Sec.4 ch.4 §4.5.1].
- Both use `ISW` for the control program and treat the debugger as distinct from it: the Symposium calls ISW the "control software for VUE Debugger" [virtual-boy-technical-symposium-95, L5]; the Operation Manual defines NDEBUG as the window server started by the `isw` command and ISDW as the debugger incorporated into it [vue-development-system-preliminary-operation-manual, Preface, Terminology; Sec.1 ch.1 §1.3.1].

### The C compiler is priced in one document and disclaimed in another

- The Symposium overview lists `"C" COMPILER VUE (VUCC)` as a purchasable option [virtual-boy-technical-symposium-95, L126–128] at $2,000 [same, price list L144], and describes producing ISX files with source-level debug information by passing the compiler's assembler output through ISAS and ISLK [same, L128].
- The Operation Manual states a "C" Compiler is purchasable separately and is *not* available through Nintendo [vue-development-system-preliminary-operation-manual, Sec.2 ch.1 §1.2]. The Symposium overview states no publisher [virtual-boy-technical-symposium-95, Source]. The two statements are not reconciled.
- The `vucc` document itself names no publisher, no price, and no target processor, and does not mention VUE or Virtual Boy [vucc-compiler, Source; vucc-compiler, Scope]. Its membership in this set rests on the Symposium overview's naming, not on anything the `vucc` document states.

### The Symposium overview lists the controller as a bundled component

- The Symposium overview lists the Virtual Boy Controller among the system's hardware components [virtual-boy-technical-symposium-95, §HARDWARE L19; L5].
- The controller wikitext describes the controller's serial report format and makes no mention of the VUE Development System or any development hardware [virtual-boy-controller, L1–34].

### A "PLANET VIRTUAL BOY" marking appears on five documents

- Present on the Development Manual cover above the D.C.N. line [virtual-boy-development-manual, cover page], on the Operation Manual title page [vue-development-system-preliminary-operation-manual, Source], on the first slide of both seminar decks together with the URL `HTTP://WWW.VR32.DE` [v810-seminar-slides-1, slide 1; v810-seminar-slides-2, slide 1], and as the producing organisation of the Sacred Tech Scroll, "Produced for Planet Virtual Boy", `https://www.virtual-boy.com/` [vb-sacred-tech-scroll, About].
- On the four 1995 documents the marking is recorded in the notes as an artefact overlaid on the original, not as part of the original titling. On the Sacred Tech Scroll it is the document's own stated producer.

### The Cyclone V handbook stands apart

- No document in this set cites the Cyclone V handbook, and the Cyclone V handbook cites none of them. The documents it defers to — *Cyclone V Device Handbook Volume 2: Transceivers*, the *Cyclone V Device Datasheet*, the *Cyclone V Device Pin-Out Files*, the *Cyclone V Device Overview*, and the *External Memory Interface Handbook* — are all absent from this set [cyclone-v-device-handbook-vol-1, Scope].

## Contradictions between documents, not reconciled

### Reset program-counter value

- `FFFFFFF0H` is stated by the architecture manual [u10082, §2.1.2 p.7; Table 9-1 p.131], the data sheet [u10691, §2.1(2); Table 8-1], and the hardware manual in three places [u10661, §1.5.1(2) p.5; §2.3(22); Table 4-1 p.65]. The Sacred Tech Scroll gives `PC` = `0xFFFFFFF0` on reset [vb-sacred-tech-scroll, System Reset > CPU].
- `FFFFFFFFH` is given by one table in the hardware manual [u10661, Table 5-2 p.74]. That manual does not reconcile its own two values.

### Number of maskable interrupt levels

- 16 levels: the architecture manual [u10082, §1.1 p.2; Table 6-1 p.117 lists INT level n for n = 0–15], the data sheet [u10691, Features], the hardware manual [u10661, §2.3(19), "INTV3 to INTV0 supply 16 interrupt levels, 0 to 15"], and seminar deck 1 [v810-seminar-slides-1, slides 10, 27]. Seminar deck 2 shows sixteen handler entries from `0xFFFFFE00` to `0xFFFFFEF0` [v810-seminar-slides-2, slide 14].
- 5 levels: the architecture summary, stated verbatim as "Virtual Game Boy has 5 levels of hardware maskable interrupts" [v810-architecture-summary, Interrupts and Exceptions]. That document attributes the count to "Virtual Game Boy" rather than to the processor and does not say whether the count is a processor property or a system property — an ambiguity the summary's own notes record [v810-architecture-summary, Stated gaps and ambiguities].

### Whether `jal` is a machine instruction

- The architecture manual documents `JAL disp26` as a Format IV instruction with op code `101011`, operation `GR[31] <- PC + 4`, and a cycle count of 3 [u10082, §5.3 p.64; Table B-2 p.142; Table 5-11 (2/3) p.108]. Seminar deck 1 lists `jal` at 3 clocks in its execution-clock table [v810-seminar-slides-1, slide 16].
- The architecture summary annotates its function-call section heading "(synthesized through discrete instructions in V810)" [v810-architecture-summary, Function Call (jal)]. No document reconciles this with the encoded instruction above.

### Game pad report bit numbering, a difference rather than a contradiction

- The Sacred Tech Scroll numbers the sixteen report bits by their position in the data registers: bit 15 right-D-pad-down down to bit 1 signature and bit 0 low battery [vb-sacred-tech-scroll, Game Pad > Data Registers]. Its key-interrupt rule is stated in the same numbering: bits 15 through 4 arm it, bits 3 through 1 suppress it, and the signature bit at bit 1 is why a standard controller never raises one [vb-sacred-tech-scroll, Key Input Interrupt].
- The controller wiki article numbers them the other way: bit 0 right-D-pad-down through bit 14 "Always 1" and bit 15 battery [virtual-boy-controller, Report format].
- The two are the same sixteen bits read in opposite directions, and one fact reconciles them: the article introduces its list as what "can be read from the data line" after strobing [virtual-boy-controller, L8], so it numbers shift positions rather than register positions, and the report goes out most-significant bit first. Its bit N is the scroll's bit 15 − N. Neither document says this; it is an inference, and the evidence that the scroll's numbering is the register one is beetle-vb's `mednafen/vb/input.c`, which places all sixteen exactly where the scroll does. `src/fpga/core/game_pad.v` follows the scroll and shifts MSB first, which satisfies both readings at once. The choice is not software-visible either way: the data registers are committed whole on the sixteenth bit, so nothing can observe the shift direction.

### Floating-point execution clock counts

- The architecture summary gives add 24, sub 26, mul 27, div 44 [v810-architecture-summary, Floating Point Operations]. Seminar deck 1's execution-clock table matches those figures exactly, listing `addf.s` 24, `subf.s` 26, `mulf.s` 27, `divf.s` 44 [v810-seminar-slides-1, slide 16].
- Seminar deck 1 elsewhere states a "26-44" range covering Add, Sub, Mul, Div and Compare [v810-seminar-slides-1, slide 25]. Neither document gives a figure for a floating compare, and deck 1 does not reconcile its slide 16 and slide 25 presentations [v810-seminar-slides-1, Stated gaps and ambiguities].
- The scroll gives per-instruction ranges that overlap none of this cleanly: `ADDF.S` 9–28, `SUBF.S` 12–28, `MULF.S` 8–30, `CMPF.S` 7–10, `DIVF.S` 44 [vb-sacred-tech-scroll, CPU > Floating-Point]. The scroll additionally gives `TRNC.SW` as 9–14 where the architecture manual's Table 5-11 prints 8–14 [u10082, Table 5-11 (3/3) p.109]. `src/fpga/core/cpu.v` charges beetle-vb's point values, which sit at the bottom of each scroll range, and says so.

### Whether an interrupt can abort a long-running instruction

- The architecture manual is explicit that it can: Table 6-2 names DIV/DIVU, the floating-point operations and the bit string instructions as "Instructions Aborted by Interrupt" [u10082, Table 6-2 p.117], and Table 6-1's Note 3 gives the aborted case a restore PC of the current instruction [u10082, Table 6-1 Notes p.117].
- The scroll states the opposite for everything but bit strings: "A requested interrupt is not accepted until the current CPU instruction, or a cache dump or restore operation, has finished" [vb-sacred-tech-scroll, CPU > Exceptions > Interrupt], with bit strings interruptible only because they re-execute per destination word without advancing PC [same, CPU > Bit Strings > Bitwise].
- beetle-vb sides with the scroll: only bit strings are interrupted mid-instruction (`v810_oploop.inc`'s `in_bstr` path); DIV and the FPU run atomically.
- `src/fpga/core/cpu.v` implements the manual — DIV/DIVU and the floating-point operations abort with restore at the instruction itself, nothing having committed — per issue #3's scope. The `cpu-longint` ROM's check 5 is written so Pocket hardware can settle it: a freeze there means real silicon never aborts a divide, and the core should revert to the scroll's reading.

### Where a bit string search leaves its pointer after a find

- The architecture manual stores "the bit address 1 bit before the 1 found first" into r30/r27, subtracting only the skipped bits from r28 [u10082, §5.3 SCH1BS p.88].
- The scroll says r30/r27 "point to the next bit following the matched bit" [vb-sacred-tech-scroll, CPU > Bit Strings > Search].
- beetle-vb implements the manual (`Do_BSTR_Search`'s fix-up steps one bit back against the search direction), and `src/fpga/core/cpu.v` follows both.

### What DIVF.S stores on underflow

- The architecture manual states a denormal number is stored to reg2 when DIVF.S underflows [u10082, §5.3 DIVF.S pp.59–60].
- The scroll's FUD row states "zero is used as the result" for underflow generally [vb-sacred-tech-scroll, CPU > Floating-Point].
- beetle-vb flushes every underflowed result to a signed zero (`FPU_Math_Template`), crediting hardware observation; `src/fpga/core/cpu_fpu.v` follows the scroll and beetle-vb.

## Within-document contradictions

Each notes file records its own document's internal inconsistencies under
`Stated gaps and ambiguities`, unresolved. The documents carrying the most are
the Sacred Tech Scroll (six, plus 31 author-marked "Editor's Note" blocks
flagging timings and behaviours as unverified), the Operation Manual (five,
including an Appendix A entry describing a different system entirely), the
architecture manual (six), and the hardware manual (seven, including the reset
PC value above and the IC3 pin stated as both VDD and VSS).

## A limitation of this index

The relationships and contradictions above were found by comparing the documents
on the points where they visibly overlap. No systematic value-by-value
reconciliation was performed across the four documents that describe the same
processor, nor between the two that describe the same console hardware. Absence
from this list is not evidence of agreement.

## Transcription artefacts affecting every document

All thirteen sources are transcriptions in which figures survive as image
references rather than text. Where this removes recoverable content — register
bit-layout diagrams, memory maps, timing charts, DIP-switch settings, package
drawings, wide tables that lost their column headers — the affected notes file
records the loss explicitly in `Stated gaps and ambiguities`, so that a gap in
the transcription is not mistaken for a gap in the notes.
