# Notes: V805™, V810™ 32/16, 32-BIT MICROPROCESSOR — HARDWARE (µPD70731, µPD70732)

## Source

- File: `U10661EJ5V0UM00.md` (Markdown transcription of the printed manual, with extracted figure images alongside it).
- Type: Hardware reference / user's manual for a microprocessor family.
- Extent: 90 transcribed PDF pages; the numbered body runs p.1 to p.75 (CHAPTER 1 through CHAPTER 5), preceded by unnumbered front matter and followed by a reader-response facsimile form. Approximately 17,900 words in the transcription.
- Version or date stated in document: no publication date is stated. The document number is U10661EJ5V0UM00, and the document contains a "Major Revisions in This Edition" table; no edition number is spelled out in words.
- Author or publisher stated in document: NEC Corporation (regional contacts listed for NEC Electronics Inc. (U.S.), NEC Electronics (Germany) GmbH, NEC Electronics (UK) Ltd., NEC Electronics Italiana s.r.1., NEC Electronics Hong Kong Ltd., NEC Electronics Singapore Pte. Ltd., NEC Electronics Taiwan Ltd., NEC Electronics (France) S.A., and NEC do Brasil S.A.).

## Scope

The manual documents the hardware functions of two parts: the V805 (µPD70731) and the V810 (µPD70732). It covers overview and register set, pin functions, bus interface function, interrupt and exception, and reset, in five chapters.

The manual states explicitly that it is the HARDWARE volume of a two-volume set, and that instruction functions (register set, data type, address space, instruction format and instruction set, interrupt and exception) are documented in the separate **V810 FAMILY™ USER'S MANUAL ARCHITECTURE** [INTRODUCTION, "Organization"]. It also states that electrical specifications are not in this manual and are found in "each DATA SHEET" [INTRODUCTION, "How to read this manual"]. Consequently the manual contains no instruction encodings, no instruction cycle counts, and no AC/DC electrical characteristics.

## Key concepts

- **V805** — the µPD70731 part; described as "a product in which the external data bus length is expanded to 16 bits", with a 32-bit address bus and 16-bit data bus. [CHAPTER 1 preamble, p.1; §1.1, p.1]
- **V810** — the µPD70732 part; described as "NEC's first microprocessor of the V810 family for embedded control applications", with a 32-bit address bus and 32-bit data bus. [CHAPTER 1 preamble, p.1; §1.1, p.1]
- **halfword** — data consisting of 2 bytes, as the manual defines the word. [INTRODUCTION; §1.3, p.3]
- **word** — data consisting of 4 bytes, as the manual defines the word. [INTRODUCTION; §1.3, p.3]
- **Dynamic bus sizing** — a V810-only 32-bit-bus-mode function that uses the lower 16 bits of the data bus to access 16-bit peripherals, enabled by making the SZRQ signal active; a word access is performed as two 16-bit accesses. [CHAPTER 3 preamble, p.23; §3.1, p.24]
- **16-bit bus fixed mode** — a mode in which the external data bus is fixed to 16 bits. On the V810 it is entered by fixing SZRQ and SIZ16B active at reset; the V805 has no SZRQ or SIZ16B signals because its data bus is 16 bits. [§3.2, p.44]
- **Machine fault status** — a bus status, signalled by MRQ, ST1 and ST0, entered on a fatal exception; the CPU writes the fatal-exception cause code, PSW and PC to the bus and halts. [§3.1.6, p.41; §4.1(8), p.66]
- **Restore PC** — the PC value saved to EIPC or FEPC when an exception or interrupt is taken; per exception source it is either "next PC" or "current PC". [Table 4-1 Note 1, p.65]
- **Duplexed exception** — the exception raised when an exception occurs while the EP bit of the PSW is already set. [§4.1(2) and §4.1(9), p.66; Table 4-1, p.65]
- **Fatal exception** — the condition entered when an exception occurs while the NP bit of the PSW is already set. [§4.1(1) and §4.1(8), p.66]
- **Clock stop exception period** — "the reset period immediately after power on (the period when the low level of the RESET pin: 20 clocks or more)", during which the clock may not be stopped. [§5.2, p.75]

## Content

### Front matter (unnumbered pages)

- The manual opens with three CMOS device notes: precaution against ESD for semiconductors, handling of unused input pins for CMOS, and status before initialization of MOS devices. [NOTES FOR CMOS DEVICES]
- The CMOS note on unused pins states that input levels of CMOS devices must be fixed high or low by pull-up or pull-down circuitry, and that each unused pin should be connected to VDD or GND with a resistor if it may be an output pin. [NOTES FOR CMOS DEVICES, item 2]
- The CMOS note on initialization states that power-on does not guarantee out-pin levels, I/O settings or register contents, and that reset must be executed immediately after power-on for devices having a reset function. [NOTES FOR CMOS DEVICES, item 3]
- NEC classifies its devices into three quality grades — "Standard", "Special", and "Specific" — and states the grade is "Standard" unless otherwise specified in NEC's Data Sheets or Data Books. [legal notice page]
- The legal notice states "Anti-radioactive design is not implemented in this product." [legal notice page]
- The "Major Revisions in This Edition" table lists five changes: p.1 §1.1 Features, addition of description of low voltage; p.2 §1.2 Ordering Information, addition of µPD70732GC-25-9EV; p.9 §2.1 (2) V810, addition of 120-pin plastic TQFP; p.20–21, addition of §2.5 Pin I/O Circuits and Recommended Connection of Unused Pins; p.73 to 75, addition of CHAPTER 5 RESET. [Major Revisions in This Edition]
- The manual marks major revised points with the symbol ★. [Major Revisions in This Edition]
- The stated readership is "users who understand the functions of the V805 (µPD70731) and V810 (µPD70732) and wish to design application systems using this microprocessor"; the manual assumes general knowledge of electric engineering, logic circuits, and microprocessors. [INTRODUCTION]
- Numeric representation convention: binary is written `xxxx` or `xxxxB`, decimal `xxxx`, hexadecimal `xxxxH`. Active-low signals are written with a top bar over the pin or signal name. Memory maps are drawn with high addresses at the top. [INTRODUCTION, "Legend"]
- Data significance convention: higher on left, lower on right. [INTRODUCTION, "Legend"]
- Exponent suffixes are defined as K (Kilo) = 2^10 = 1024, M (Mega) = 2^20 = 1024^2, G (Giga) = 2^30 = 1024^3. [INTRODUCTION, "Legend"]
- The manual notes that related documents it cites "may include preliminary versions" and that "preliminary versions are not marked as such". [Related documents]
- Related product documents listed: V805 Data Sheet U10917E; V810 Data Sheet U10691E; V805, V810 User's Manual Hardware ("This manual"); V810 family User's Manual Architecture U10082E. [Related documents]
- Related development-tool documents listed cover the in-circuit emulators IE-70732-BX-A (U10667E) and IE-70732-MC (EEU-5016), the C compiler CA732, the debugger ID732, the real-time OS RX732, and the system performance tool AZ732; two ID732 Windows manuals are marked "Planned". [Related documents]

### CHAPTER 1 OVERVIEW (p.1–p.6)

- The V805 and V810 employ a RISC architecture for embedded control applications; the manual names facsimile, digital PPC, word processor, image processor, and real time control device as applications. [CHAPTER 1 preamble, p.1]
- The manual states that because the V805 expands the external data bus to 16 bits, "modification from the existing 16-bit system is easy", and that its small package "realizes a compact system". [CHAPTER 1 preamble, p.1]
- Features listed for both parts: high-performance 32-bit architecture for embedded control application; 1-Kbyte cache memory; pipeline structure of 1 clock pitch; 16-bit fixed instructions (with some exceptions); 32 general-purpose registers of 32 bits; 4-Gbyte linear address space; register/flag hazard interlocked by hardware; floating-point operation instructions based upon IEEE754 data format; bit string instructions; 16 levels of high-speed interrupt responses; CMOS technology; low voltage operation possible. [§1.1, p.1]
- Separate address/data buses are listed per part: V810 address bus 32 bits and data bus 32 bits; V805 address bus 32 bits and data bus 16 bits. [§1.1, p.1]
- The dynamic bus sizing function and the 16-bit bus fixing function are both listed as V810 features. [§1.1, p.1]
- Both the V805 and V810 support 4 Gbytes of linear memory space and I/O space, and output 32-bit addresses to memory and I/Os, so addresses run from 0 to 2^32 – 1. [§1.3, p.3]
- Bit number 0 of each byte is the LSB and bit number 7 is the MSB; unless otherwise specified, the byte at the lower address of a multi-byte datum is the LSB and the byte at the higher address is the MSB. [§1.3, p.3]
- Data types supported by both parts: integer (8, 16, 32 bits); unsigned integer (8, 16, 32 bits); bit string; single-precision floating-point data (32 bits). [§1.4, p.4]
- The register set of both parts divides into a program register set "generally used by the programmer" and a system register set "usually used by the OS (operating system)"; all registers are 32 bits wide. [§1.5, p.4]
- Thirty-two general-purpose registers r0 to r31 are available on both parts, all usable as data registers or address registers. [§1.5.1(1), p.5]
- r0 and r26 to r31 are implicitly used by instructions; r1 to r5 are used by the C compiler and assembler. [§1.5.1(1), p.5]
- The program counter (PC) indicates the address of the instruction currently executed; bit 0 of the PC is fixed to 0, so execution cannot branch to an odd address. [§1.5.1(2), p.5]
- §1.5.1(2) states the PC contents are initialized to FFFFFFF0H at reset. [§1.5.1(2), p.5]
- System registers are accessed by number using the system register load/store instructions LDSR and STSR. [§1.5.2, p.6]
- The system register table marks ECR, PIR and TKCW as write disabled, and marks numbers 8 to 23 and 26 to 31 as Reserved with the note "Operation is not guaranteed if this is accessed." [§1.5.2, p.6]

### CHAPTER 2 PIN FUNCTIONS (p.7–p.22)

§2.3 Pin Function Details numbers its individual pin descriptions (1) to (27) and runs from p.14 to p.17; bullets below are anchored by that item number, which the document states, rather than by page.

- §2.1 gives pin configuration drawings (top views) for the V805 in 100-pin plastic QFP (Fine pitch) (14 x 14 mm), for the V810 in 120-pin plastic QFP (28 x 28 mm) and 120-pin plastic TQFP (Fine pitch) (14 x 14 mm), and a pin-assignment grid table for the V810 in 176-pin ceramic PGA (Seam weld). [§2.1, p.7–p.10]
- Every package drawing carries the same two cautions: "Leave the IC1 pin open." and "Connect the IC2 pin to GND."; the 176-pin PGA adds "Connect the IC3 pin to VDD." [§2.1, p.7–p.10]
- For the 176-pin ceramic PGA (µPD70732R-25) the manual remarks that "The insertion guide pin is not included in the number of pins." [§2.1, p.10]
- The 176-pin PGA pin list is given as grid positions A1 through Q15 mapped to signal names (for example A1 = IC2, A12 = RESET, B15 = ICHEEN, C15 = NMI, H13 = CLK, K13 = BLOCK, L12 = HLDAK, M13 = BCYST, M14 = DA, M15 = SIZ16B, P10 = SZRQ, P12 = MRQ, P14 = ADRSERR, Q11 = READY, Q14 = R/W). [§2.1, p.10]
- The address bus A31 to A1 is a 3-state output on both parts; the data bus is D31 to D0 on the V810 and D15 to D0 on the V805, both 3-state I/O. [§2.2, p.11–p.12; §2.3(1)–(2)]
- The byte enable signals are BE1, BE0 on the V805 and BE3 to BE0 on the V810. [§2.2, p.11; §2.3(3)–(4)]
- The V805 does not have the D31 to D16 pins. [§2.3(2)]
- SZRQ, SIZ16B, ICHEEN and IC3 are marked "V810 only"; BE1/BE0 and D15 to D0 are marked "V805 only". [§2.2 Notes 2 and 3, p.12; §2.4 Notes 2 and 3, p.19]
- A31 to A1 changes state in synchronization with the rising edge of the clock of the T1 state of the bus cycle; in an additional bus cycle, A1 changes state in synchronization with the rising edge of the clock of the T1S state. [§2.3(1)]
- In the write cycle, new data is output at the falling edge of the clock of the T1 and T1S states and held until the first TH state or the falling edge of the clock of the next T1/T1S state; in the read cycle, data is sampled at the rising edge of the clock next to the last T2 or T2S state. [§2.3(2)]
- DA is a strobe signal for data access, changes state at the rising edge of the clock, and becomes active in the T2 and T2S states. [§2.3(6)]
- MRQ goes "L" when memory is accessed and is "H" otherwise, and is valid for the period of the bus cycle. [§2.3(7)]
- R/W goes "H" for a read cycle and "L" for a write cycle, and is valid for the period of the bus cycle. [§2.3(8)]
- BCYST indicates the start of the bus cycle, changes at the rising edge of the clock, and is active during the T1 and T1S states. [§2.3(9)]
- READY extends the bus cycle and is sampled at the falling edge of the clock in the T2 and T2S states. [§2.3(10)]
- HLDRQ is sampled at the falling edge of the clock in the T2, T2S, TI, TIS, TH and THS states; when the handshake completes, the address bus, data bus and control bus go to high impedance, HLDAK becomes active, and bus mastership is relinquished. [§2.3(11)]
- If the BLOCK signal is active, the TH and THS states do not start. [§2.3(11)]
- SZRQ (V810) requests a change of external data bus width to 16 bits for the bus cycle under execution; the V810 then treats the lower 16 bits of the data bus as the valid data bus, and the bus cycle is automatically added as necessary. SZRQ is sampled at the falling edge of the T2 state at the end of the bus cycle. [§2.3(13)]
- SIZ16B (V810) fixes the external data bus width to 16 bits; the CPU then outputs BE1, BE0 and A1 for a 16-bit data bus system, and BE3, BE2 and D31 to D16 go to high impedance. SZRQ must also be made active. D31 to D16 need not be connected. [§2.3(14)]
- BLOCK becomes active at the rising edge of the clock of the T1 state of the first bus cycle and inactive at the rising edge of the clock next to the last bus cycle (last T2 state, or last T2S state when there is an additional bus cycle). [§2.3(15)]
- ICHEEN (V810) enables operation of the instruction cache; to energize the instruction cache the ICE bit of the cache control word must also be set. [§2.3(16)]
- ADRSERR indicates that the address calculated by a load/store or I/O instruction was not aligned and has been aligned automatically by the V805 and V810; it becomes active in association with the bus cycle for one operand access. [§2.3(17)]
- ADRSERR does not detect the branch address of a branch instruction, nor illegal alignment of the address of the lock word of the CAXI instruction. [§2.3(17)]
- INT is sampled at the rising edge of the clock; the detected interrupt request and interrupt level are internally held while condition (a) is satisfied. [§2.3(18)]
- INTV3 to INTV0 supply 16 interrupt levels, 0 to 15, and are sampled at the rising edge of the clock. [§2.3(19)]
- NMI is sampled at the falling edge of the clock; the request is detected when the sampled value changes from "H" to "L", and is internally held until the CPU starts interrupt servicing. [§2.3(20)]
- CLK inputs the system clock. [§2.3(21)]
- RESET is sampled at the falling edge of the clock; its active level must be held for 20 clocks or longer. On acceptance the CPU initializes pins and internal registers and executes instructions starting from address FFFFFFF0H. [§2.3(22)]
- §2.3(23) describes VDD as a "+5-V power supply pin" and §2.3(24) describes GND as a ground pin (0 V). [§2.3(23)–(24)]
- IC1 is to be left open, IC2 connected to the GND line, and IC3 (V810) connected to the VDD line. [§2.3(25)–(27)]
- §2.3 states its state-timing convention: "For each state of a bus cycle, the period from the rising edge of the clock to the time just before the next rising edge is taken as a unit." [§2.3, p.14]
- §2.5 (marked ★ as an addition in this edition) gives pin I/O circuit types and recommended connections for unused pins, with Figure 2-1 showing the I/O circuit of each type. [§2.5, p.20–p.21]

### CHAPTER 3 BUS INTERFACE FUNCTION (p.23–p.64)

- The V805 is equipped with a 16-bit data bus and the V810 with a 32-bit data bus. [CHAPTER 3 preamble, p.23]
- The V810 bus interface has two modes: 32-bit bus mode, which uses the data bus in 32 bits, and 16-bit bus fixed mode, which fixes the bus in 16 bits. Modes can be switched only at reset, using the SIZ16B signal. [CHAPTER 3 preamble, p.23]
- In the V810's 32-bit bus mode, dynamic bus sizing accesses word data by loading/storing 16-bit data twice; in 16-bit bus fixed mode, word access is executed by activating a bus cycle twice. [CHAPTER 3 preamble, p.23]
- The manual directs readers to §3.2 for the V805 bus interface. [CHAPTER 3 preamble, p.23]

#### 32-bit bus mode (V810) — §3.1, p.24–p.43

- The bus interface is in 32-bit bus mode when the SIZ16B signal is fixed to inactive at reset; word data is then processed in one bus cycle for 32-bit-wide peripherals. [§3.1, p.24]
- In dynamic bus sizing, two bus cycles are started during a word access: the lower halfword in the first bus cycle and the higher halfword in the second. Halfword and byte data are accessed in one bus cycle. [§3.1, p.24]
- Figures 3-1 and 3-2 illustrate word and halfword/byte access during dynamic bus sizing, with "A" denoting the lower 16 bits of data and "B" the higher 16 bits. [§3.1, p.24–p.25]
- §3.1 lists the seven items it covers for 32-bit bus mode: relationship between external access and byte enable signals; operand read; operand write; bus state; memory and I/O access; machine fault acknowledge; halt acknowledge. [§3.1, p.26]
- In operand-read figures, the notation "n ; Bm" for the internal register means the byte numbered m on the external data bus is sampled in the bus cycle numbered n. [§3.1.2, p.28]
- The Bm byte numbering runs B4, B3, B2, B1 across the external data bus from bit 31 down to bit 0. [Figure 3-3, p.28]
- With a 32-bit data bus, a byte read at operand address bits (1,0) = (0,0), (0,1), (1,0), (1,1) places B1, B2, B3, B4 respectively into the internal register, all in bus cycle 1; a halfword read at (0,0) takes B2:B1 and at (1,0) takes B4:B3; a word read at (0,0) takes B4:B3:B2:B1. [Figure 3-3(a)–(c), p.28]
- Under dynamic bus sizing, a byte read at operand address bits (1,0) = (0,0) or (1,0) takes B1, and at (0,1) or (1,1) takes B2; a halfword read at either (0,0) or (1,0) takes B2:B1 — in all cases from the lower 16 bits of the data bus in bus cycle 1. [Figure 3-4(a)–(b), p.29]
- Under dynamic bus sizing, a word read fills the internal register from two bus cycles: bytes "1; B1" and "1; B2" from the first cycle and "2; B1" and "2; B2" from the second (the second cycle being the one added by dynamic bus sizing). [Figure 3-4(c), p.29]
- In operand-write figures, OPm (m = 4 to 1) denotes the byte position of an internal register; OP4, OP3, OP2, OP1 run across the internal register from bit 31 down to bit 0. [§3.1.3, p.30; Figure 3-5, p.30]
- In a 32-bit bus mode halfword write, the operand is duplicated across the bus for the odd case: at operand address bits (1,0) = (0,0) the bus carries OP2:OP1 on D15 to D0, and at (1,0) it carries OP2:OP1 on both D31 to D16 and D15 to D0, in one bus cycle. [Figure 3-5(b), p.30]
- During dynamic bus sizing a word write adds one bus cycle, shown as bus cycle sequence 2 in Figure 3-5(c). [§3.1.3, p.30]
- A bit string processes data by word (4 bytes) to increase processing speed; if the end of the written data is not at a word boundary — that is, if bits 1 and 0 of the last byte address in the destination bit string are not "11" — up to 3 bytes are excessively written, but data is not destroyed because the original value is written back unchanged. [Caution "Notes on bit string", §3.1.3, p.31]
- For bit string reads, up to 3 words may be excessively read from the last word at the source side and at the destination side; the excessively read data is discarded. [Caution "Notes on bit string", §3.1.3, p.31]
- During a bit string operand write, BE3 to BE0 are always "0000". [Figure 3-6 note, p.31]
- The bus cycle of the V810 consists of eight states: TI, TIS, T1, T1S, T2, T2S, TH, THS. [§3.1.4, p.32]
- TI and TIS start when no access request is issued, or when the TH or THS (hold) state is over; BCYST and DA outputs are inactive and HLDRQ is sampled at the falling edge of the clock. [§3.1.4(a), p.32]
- T1 and T1S start a bus cycle: BCYST becomes active, the address is output at the rising edge of the clock, valid data is output to the data bus at the falling edge of the clock, and T2/T2S always follows. [§3.1.4(b), p.32]
- In the T1 state the A1 signal becomes 0 and in the T1S state A1 becomes 1; likewise A1 is 0 in T2 and 1 in T2S. [§3.1.4(b)–(c), p.32]
- T2 and T2S occur at the end of a bus cycle or in wait status: DA becomes active, HLDRQ is sampled at the falling edge of the clock, and read data is sampled at the rising edge of the clock next to the last T2 or T2S state. [§3.1.4(c), p.32]
- TH and THS start when hold status is set by the HLDRQ input; when HLDRQ is detected inactive, TI and TIS start. [§3.1.4(d), p.32]
- The TIS, T1S, T2S and THS states are bus cycles added only when a word is accessed with the bus sizing function enabled, corresponding respectively to TI, T1, T2 and TH in the normal bus cycle. [§3.1.4 Remark, p.32]
- When the RESET input becomes active, the TI or TH state starts depending on the status of the HLDRQ signal. [Figure 3-7 Remark, p.33]
- Figure 3-7 lists 17 numbered bus cycle state transition conditions expressed over READY, SZRQ, HLDRQ, hold enable/disable status, access cause, and whether the access is a word access. [§3.1.4, p.33]
- After BLOCK becomes active and immediately before the last bus cycle of the bus lock status (last T2 state, or last T2S state when bus sizing is enabled), the hold disable status is entered; the hold enable status is entered in the last bus cycle. [§3.1.4 Remark, p.33]
- The A1 signal in 32-bit bus mode is fixed to 0, except that in dynamic bus sizing A1 becomes 0 in the first access and 1 in the second access for word data access. [§3.1.5, p.34]
- Memory read cycle: address output starts in T1 and BCYST becomes active; in T2 the address continues, BCYST goes inactive and DA goes active; READY is sampled at the falling edge of the clock in T2 and T2 repeats as wait status while READY is inactive; when READY becomes active the T2 state ends and data is sampled as DA is made inactive at the rising edge of the next clock. [§3.1.5(1), p.34]
- Memory write cycle: write data output starts at the falling edge of the clock in T1 and is held until the TH state starts or the clock in the T1 state of the next bus cycle falls; all pins except D31 to D0 and R/W behave as in the read cycle. [§3.1.5(2), p.36]
- The I/O read cycle and I/O write cycle are described with the same sequences as the memory read and write cycles. [§3.1.5(3)–(4), p.37–p.38]
- Read during dynamic bus sizing: read data comes from D15 to D0 in the first bus cycle (T1, T2); for word access a second bus cycle (T1S, T2S) starts, in which BE1 and BE0 are made inactive at the rising edge of the T1S state clock and the higher 16 bits are read from D15 to D0. [§3.1.5(5), p.39]
- Write during dynamic bus sizing: write data is output to D31 to D0 at the falling edge of the T1 state clock in the first bus cycle; in the added second bus cycle BE1 and BE0 are made inactive at the rising edge of the T1S state clock, and at the falling edge of the T1S state clock the data previously output on D31 to D16 is output on D15 to D0, held until the falling edge of the T1 state clock of the next bus cycle. [§3.1.5(5), p.39]
- Machine fault cycle: MRQ, ST1 and ST0 indicate machine fault status, and the cause code of the fatal exception (logical sum of FFFF0000H and an exception code), the current PSW and the current PC are output sequentially in the write cycle to the data bus. [§3.1.6, p.41]
- Wait, bus sizing and bus hold requests are valid in the machine fault write cycle (32-bit bus mode). [§3.1.6, p.41]
- After the machine fault cycle ends, MRQ, ST1 and ST0 retain the machine fault bus status; the machine fault status can be released only by reset input. HLDRQ and READY requests remain valid in the machine fault cycle and in the subsequent TI state. [§3.1.6, p.41]
- Halt acknowledge cycle: MRQ, ST1 and ST0 indicate the halt acknowledge cycle; the PC contents at the time the HALT instruction is executed are output in the write cycle to the address bus, and the lower 16 bits of the PSW are output to the data bus by halfword. Wait, bus sizing and bus hold requests are valid. [§3.1.7, p.43]

#### 16-bit bus fixed mode (V805 and V810) — §3.2, p.44–p.60

- For the V810, the bus interface is in 16-bit bus fixed mode when SZRQ and SIZ16B are fixed active at reset; BE3, BE2 and D31 to D16 are then in the high impedance state, and BE1, BE0 and A1 output values appropriate to a 16-bit data bus system. SZRQ and SIZ16B can be changed only at reset. [§3.2, p.44]
- For the V805, because the data bus is 16-bit, the SZRQ and SIZ16B signals are not present. [§3.2, p.44]
- In 16-bit bus fixed mode two bus cycles are started during word data access: the lower halfword in the first bus cycle and the higher halfword in the second. [§3.2, p.44]
- Figures 3-15 and 3-16 show 16-bit bus fixed mode operation for the V810; the manual states the V805 operation is the same except that the data bus consists of 16 bits (0 to 15). [§3.2, p.44]
- §3.2 lists the same seven items as §3.1 for 16-bit bus fixed mode. [§3.2, p.46]
- Figure 3-16 breaks halfword/byte access in 16-bit bus fixed mode into four cases: (a) higher halfword/byte data read cycle, (b) higher halfword/byte data write cycle, (c) lower halfword/byte data read cycle, (d) lower halfword/byte data write cycle. [Figure 3-16, p.45]
- Operand read in 16-bit bus fixed mode uses the same "n ; Bm" notation as 32-bit bus mode, with the word case (c) marked "Added bus cycle" for the second cycle. [§3.2.2, p.48]
- In a 16-bit bus fixed mode word write, bus cycle 1 carries OP2:OP1 and bus cycle 2 (the added cycle) carries OP4:OP3, both on D15 to D0; a byte write carries OP1 on D7 to D0 for even operand addresses and on D15 to D8 for odd operand addresses, in one bus cycle. [Figure 3-18, p.49]
- Figure 3-18 shows the V810 operation; the manual states V805 operation is the same except that the external data bus consists of 16 bits (0 to 15). [§3.2.3, p.49]
- The bus cycles of the V805 and V810 in this mode consist of the same eight states TI, TIS, T1, T1S, T2, T2S, TH, THS, with the same per-state behaviour described for 32-bit bus mode. [§3.2.4, p.50]
- In 16-bit bus fixed mode the TIS, T1S, T2S and THS states are the bus cycles added only when word data is accessed. [§3.2.4 Remark, p.50]
- Figure 3-19 lists 17 numbered state transition conditions for 16-bit bus fixed mode; unlike the 32-bit bus mode list they contain no SZRQ term, using "word access" / "not word access" instead. [§3.2.4, p.51]
- In 16-bit bus fixed mode the A1 signal is valid for addresses. [§3.2.5, p.52]
- Memory read cycle (16-bit bus fixed mode): address output starts in T1 with BCYST active; "When the space outputting the chip select signal is accessed, the chip select signal is output at the falling edge of the T1 state clock"; in T2 the address continues, BCYST goes inactive and DA goes active. [§3.2.5(1), p.52]
- In T2 both READY and HLDRQ are sampled at the falling edge of the clock, and the next state depends on both: READY inactive repeats T2; READY active with HLDRQ inactive reads the data at the rising edge of the clock and ends T2 for halfword/byte access, or starts T1S and adds a bus cycle for word access; both READY and HLDRQ active moves from T2 to TI. [§3.2.5(1), p.52]
- In the T1S and T2S states the timing is the same as T1 and T2 except that the A1 signal becomes high level. [§3.2.5(1), p.52]
- Memory write cycle (16-bit bus fixed mode): write data output starts at the falling edge of the clock in T1 and is held until the TH state starts or the clock in the T1 state (the T1S state during word data access) of the next bus cycle falls; pins other than D15 to D0 and R/W behave as in the read cycle. [§3.2.5(2), p.54]
- The I/O read and I/O write cycles in 16-bit bus fixed mode follow the same descriptions as the memory read and write cycles, including the chip select statement for the read cycle. [§3.2.5(3), p.55; §3.2.5(4), p.57]
- Machine fault cycle (16-bit bus fixed mode): the cause code of the fatal exception, the current PSW and the current PC are output sequentially in the write cycle over six halfword transfers. Only wait and bus hold requests are stated as valid in this write cycle. [§3.2.6, p.58]
- Halt acknowledge cycle (16-bit bus fixed mode): the PC contents when the HALT instruction is executed are output to the address bus and the lower 16 bits of the PSW to the data bus by halfword; wait and bus hold requests are valid. [§3.2.7, p.60]

#### Timing of control signals — §3.3, p.61–p.64

- Bus lock is set by making the BLOCK signal active, to disable use of bus mastership by bus masters other than the V805 and V810; bus lock takes place when the CAXI instruction is executed. [§3.3.1, p.61]
- When the lock word is accessed with the CAXI instruction, BLOCK turns active in synchronization with the start of the read cycle (BCYST active) and turns inactive in synchronization with the end of the last write cycle (DA inactive). [§3.3.1, p.61]
- Figure 3-26 gives bus lock timing separately for (1) 32-bit bus mode (V810) and (2) 16-bit bus fixed mode (V805, V810); during the locked access ST1, ST0 = "data access" with BE3 to BE0 = "0000" on the V810 and BE1, BE0 = "00" on the V805. [§3.3.1, p.61–p.62]
- Bus hold: when an external bus master requests bus mastership, the V805 and V810 float the bus to transfer it and enter bus hold state. Bus hold starts at the same time as HLDAK becomes active, and ends half a clock after the high level of HLDRQ is sampled. [§3.3.2, p.63]
- Bus hold requests are not accepted from when BLOCK becomes active until immediately before the last bus cycle of the bus lock cycle (last T2, or last T2S for the bus sizing); in the last bus cycle bus hold requests are accepted. [§3.3.2, p.63]
- Figure 3-27 identifies the signals floated during bus hold as A31 to A1, BE3 to BE0, ST1, ST0, R/W, MRQ and D31 to D0 for the V810, and A31 to A1, BE1, BE0, ST1, ST0, R/W, MRQ and D15 to D0 for the V805. [Figure 3-27 Notes, p.63]

### CHAPTER 4 INTERRUPT AND EXCEPTION (p.65–p.72)

- Interrupts are events that take place independently of program execution and are classified into maskable interrupts and a non-maskable interrupt; an exception is an event that takes place depending upon program execution. [CHAPTER 4 preamble, p.65]
- The manual states there is little difference between interrupt and exception in terms of flow, but "the interrupt takes precedence over the exception". [CHAPTER 4 preamble, p.65]
- If an exception, a maskable interrupt or NMI occurs, control transfers to a handler whose address is determined by the source; the source can be checked by examining the exception code stored in the ECR (Exception Code Register). [CHAPTER 4 preamble, p.65]
- The floating-point underflow exception (FUD) and floating-point precision degradation exception (FPR) do not occur in the V805 and V810, although both appear in the exception code table. [Table 4-1 Note 5, p.65]
- For a duplexed exception, the exception code of the exception that occurs first is stored in the lower 16 bits of the ECR and that of the second exception in the higher 16 bits. [Table 4-1 Note 4, p.65]
- At reset, EIPC and FEPC are undefined. [Table 4-1 Note 2, p.65]
- While an instruction whose execution is aborted by an interrupt is executed, restore PC = current PC. [Table 4-1 Note 3, p.65]
- Table 4-2 lists the instructions aborted by interrupt as: DIV/DIVU instruction, floating-point operation instructions, bit string instructions. [Table 4-2, p.65]
- Exception processing sequence: if NP of the PSW is already set, proceed to fatal exception processing; if EP of the PSW is already set, proceed to duplexed exception processing; otherwise save the restore PC to EIPC, save the current PSW to EIPSW, write the exception code to the lower 16 bits of the ECR (EICC), set the EP and ID bits of the PSW and clear the AE bit, then jump to the handler address. [§4.1(1)–(7), p.66]
- Fatal exception processing indicates machine fault status using ST1, ST0 and MRQ, starts the write cycle, outputs the source code of the fatal exception (OR of FFFF0000H and exception code) at address 00000000H, the current PSW at 00000004H and the current PC at 00000008H, then halts until reset. [§4.1(8), p.66]
- Duplexed exception processing saves the restore PC to FEPC, saves the current PSW to FEPSW, writes the exception code of the causing source to the higher 16 bits of the ECR (FECC), sets the NP and ID bits of the PSW, clears the AE bit, and jumps to address FFFFFFD0H (NMI handler address). [§4.1(9), p.66]
- A maskable interrupt occurs when a high level signal is input to the INT pin; the INT input is sampled at the rising edge of the clock and a request is detected when three conditions hold: NP, EP and ID flags in the PSW are all "0"; the level on INTV3 to INTV0 is higher than the interrupt enable level in the PSW; and the INT pin is active. [§4.2.1, p.67]
- The V805 and V810 check for an interrupt request at three points: when an instruction ends, during execution of an instruction that is interrupted, and when no internal servicing is executed at all. [§4.2.1, p.67]
- The maskable interrupt is masked by the logical sum of NP, EP and ID of the PSW; the interrupt is not accepted if the interrupt level n of INTV3 to INTV0 is lower than the interrupt enable level (I3 to I0) of the PSW. [§4.2.1, p.68]
- The interrupt of the highest level (n = 15) cannot be disabled by the interrupt enable level. [§4.2.1, p.68]
- Maskable interrupt servicing: save the restore PC to EIPC; save the current PSW to EIPSW; write the exception code to the lower 16 bits of the ECR (EICC); set the EP and ID bits of the PSW and clear the AE bit; set n + 1 into the I (I3 to I0) field of the PSW, or 15 if the accepted level is n = 15; jump to the handler address. [§4.2.1(1)–(6), p.68]
- Non-maskable interrupt servicing uses FEPC and FEPSW to save the PC and PSW: save the restore PC to FEPC; save the current PSW to FEPSW; write the exception code to the higher 16 bits of the ECR (FECC); set the NP and ID bits of the PSW and clear the AE bit; jump to address FFFFFFD0H (NMI handler address). [§4.2.2(1)–(5), p.69]
- If another non-maskable interrupt request occurs while a non-maskable interrupt is being serviced (NP bit of the PSW is 1), the request is internally held by the processor; clearing the NP bit to 0 with the RETI and LDSR instructions then starts new non-maskable interrupt servicing. [§4.2.2, p.69]
- A non-maskable interrupt request that occurs during the period in which the latch is cleared by internal servicing, immediately after the start of servicing the first non-maskable interrupt, is not held in the internal latch of the processor. [§4.2.2, p.69]
- Return from an exception event other than the fatal exception uses the RETI instruction: if NP of the PSW = 1, the restore PC and PSW are restored from FEPC and FEPSW; if NP = 0, from EIPC and EIPSW; then the restore PC and PSW are restored and execution jumps to the PC. [§4.3, p.70]
- Table 4-3 gives the priority relationships among RESET, NMI, INT, AD-TR (address trap), TRAP (trap instruction), I-OPC (illegal op code), DIV0 (zero division) and FLOAT (floating-point exceptions: invalid operation, zero division, overflow, and reserved operand exceptions), using the symbols `*` (item on the left ignores the item above), `x` (item on the left is ignored by the item above), `–` (do not occur simultaneously), `←` (item on the left has higher priority) and `↑` (item above has higher priority). [§4.4.1, p.71]
- Table 4-4 gives priorities among the floating-point operation exceptions FRO, FIV, FZD, FOV, FUD and FPR using the symbols `*`, `x` and `–`. [§4.4.2, p.72]
- An interrupt is accepted when an instruction is executed; if the instruction takes two or more clocks, the interrupt is accepted during the period of the last one clock of the instruction. [§4.4.3, p.72]
- If an interrupt request is issued while no instruction is executed (in wait or bus hold status), the interrupt is accepted when the next instruction is executed. [§4.4.3, p.72]

### CHAPTER 5 RESET (p.73–p.75)

- The V805 and V810 can be reset by inputting low level to the RESET pin regardless of the state of the device. [§5.1, p.73]
- Each output pin enters the state shown in Table 5-1 at the rising edge of the clock 0.5 to 2.5 clocks after low level of the RESET pin is detected. [§5.1, p.73]
- Internal hardware is initialized if the RESET pin is returned to high level after being held low for 20 clocks or more; if the HLDRQ pin is not active, a memory read cycle is started for instruction fetch. [§5.1, p.74]
- The V805 and V810 can be placed in bus hold status even during the reset period (while RESET is held low) by setting the HLDRQ pin to the active level. [§5.1, p.74]
- Figure 5-1 identifies the rising-clock-synchronous signals as A31 to A1, BE3 to BE0 (V810) / BE1, BE0 (V805), ST1, ST0, MRQ, R/W, BCYST, DA, ADRSERR, HLDAK and BLOCK, and marks the pre-reset state as undefined during power on. [Figure 5-1 Notes, p.74]
- The V805 and V810 can stop the clock at any timing except during the clock stop exception period, and the clock can be stopped either in "H" or "L" level. [§5.2, p.75]

## Specifications and procedures

### Part numbers and operating voltage/frequency (§1.1, p.1)

| Part number      | VDD = +5 V ± 10% | VDD = 3.0 to 3.6 V | VDD = 2.7 to 3.6 V | VDD = 2.2 to 3.6 V |
| ---------------- | ---------------- | ------------------ | ------------------ | ------------------ |
| V805 µPD70731-16 | Max. 16 MHz      | —                  | —                  | —                  |
| V805 µPD70731-20 | Max. 20 MHz      | Max. 16 MHz        | Max. 12.5 MHz      | Max. 10 MHz        |
| V810 µPD70732-16 | Max. 16 MHz      | —                  | —                  | —                  |
| V810 µPD70732-20 | Max. 20 MHz      | —                  | —                  | —                  |
| V810 µPD70732-25 | Max. 25 MHz      | —                  | Max. 16 MHz        | Max. 10 MHz        |

### Ordering information (§1.2, p.2)

V805:

| Part Number       | Package                                       | Max. operating freq. (MHz) |
| ----------------- | --------------------------------------------- | -------------------------- |
| µPD70731GC-16-7EA | 100-pin plastic QFP (Fine pitch) (14 x 14 mm) | 16                         |
| µPD70731GC-20-7EA | 100-pin plastic QFP (Fine pitch) (14 x 14 mm) | 20                         |

V810:

| Part Number       | Package                                        | Max. operating freq. (MHz) |
| ----------------- | ---------------------------------------------- | -------------------------- |
| µPD70732GD-16-LBB | 120-pin plastic QFP (28 x 28 mm)               | 16                         |
| µPD70732GD-20-LBB | 120-pin plastic QFP (28 x 28 mm)               | 20                         |
| µPD70732GD-25-LBB | 120-pin plastic QFP (28 x 28 mm)               | 25                         |
| µPD70732GC-25-9EV | 120-pin plastic TQFP (Fine pitch) (14 x 14 mm) | 25                         |
| µPD70732R-25      | 176-pin ceramic PGA (Seam weld)                | 25                         |

### System register numbers (§1.5.2, p.6)

| No       | System register                             | Access                               |
| -------- | ------------------------------------------- | ------------------------------------ |
| 0        | EIPC : Exception/Interrupt PC               | read/write enabled                   |
| 1        | EIPSW : Exception/Interrupt PSW             | read/write enabled                   |
| 2        | FEPC : Fatal Error PC                       | read/write enabled                   |
| 3        | FEPSW : Fatal Error PSW                     | read/write enabled                   |
| 4        | ECR : Exception Cause Register              | write disabled                       |
| 5        | PSW : Program Status Word                   | read/write enabled                   |
| 6        | PIR : Processor ID Register                 | write disabled                       |
| 7        | TKCW : TasK Control Word                    | write disabled                       |
| 8 to 23  | Reserved                                    | operation not guaranteed if accessed |
| 24       | CHCW : CacHe Control Word                   | read/write enabled                   |
| 25       | ADTRE : ADdress Trap Register for Execution | read/write enabled                   |
| 26 to 31 | Reserved                                    | operation not guaranteed if accessed |

The table's legend reads "— : Write disabled" and notes that read/write-enabled registers "cannot be set in some cases".

### Bus cycle status encoding (Table 2-1, p.15)

| MRQ | ST1 | ST0 | Type of bus cycle         |
| --- | --- | --- | ------------------------- |
| L   | L   | L   | RFU (reserved area)       |
| L   | L   | H   | Fetch after branch (Note) |
| L   | H   | L   | Data access               |
| L   | H   | H   | Instruction fetch         |
| H   | L   | L   | RFU (reserved area)       |
| H   | L   | H   | Machine fault acknowledge |
| H   | H   | L   | I/O access                |
| H   | H   | H   | Halt acknowledge          |

Note on "Fetch after branch": "Does not output if cache is ON."

### Byte enable to data bus correspondence (§2.3(3)–(4))

- V805: BE1 → D15 to D8; BE0 → D7 to D0.
- V810: BE3 → D31 to D24; BE2 → D23 to D16; BE1 → D15 to D8; BE0 → D7 to D0.

### Pin status (Table 2-2, p.19)

| Pin                    | I/O                  | Bus hold status during operation | Bus hold status at reset | Bus idle status at reset |
| ---------------------- | -------------------- | -------------------------------- | ------------------------ | ------------------------ |
| A31 to A1              | 3-state output       | Hi-Z                             | Hi-Z                     | H (Note 1)               |
| D15 to D0 (V805 only)  | 3-state input/output | Hi-Z                             | Hi-Z                     | Hi-Z                     |
| D31 to D0 (V810 only)  | 3-state input/output | Hi-Z                             | Hi-Z                     | Hi-Z                     |
| BE1, BE0 (V805 only)   | 3-state input/output | Hi-Z                             | Hi-Z                     | H                        |
| BE3 to BE0 (V810 only) | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| ST1, ST0               | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| DA                     | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| MRQ                    | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| R/W                    | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| BCYST                  | 3-state output       | Hi-Z                             | Hi-Z                     | H                        |
| READY                  | Input                | —                                | —                        | —                        |
| HLDRQ                  | Input                | —                                | —                        | —                        |
| HLDAK                  | Output               | L                                | L                        | H                        |
| SZRQ (V810 only)       | Input                | —                                | —                        | —                        |
| SIZ16B (V810 only)     | Input                | —                                | —                        | —                        |
| BLOCK                  | Output               | L                                | L                        | L                        |
| ICHEEN (V810 only)     | Input                | —                                | —                        | —                        |
| ADRSERR                | Output               | Not affected                     | H                        | H                        |
| INT                    | Input                | —                                | —                        | —                        |
| INTV3 to INTV0         | Input                | —                                | —                        | —                        |
| NMI                    | Input                | —                                | —                        | —                        |
| CLK                    | Input                | —                                | —                        | —                        |

Note 1: "A1 is 'H' in the 16-bit bus mode; otherwise, it is 'L' (V810 only)."

The equivalent table in §2.2 (p.11–p.12) adds the function descriptions and the pins omitted from Table 2-2: VDD (Power Supply, "+5-V power source"), GND (Ground, "Ground potential (0 V)"), RESET ("Resets internal status"), IC1 ("Internally connected (Leave this pin open.)"), IC2 ("Internally connected (Ground this pin.)") and IC3, V810 only ("Internally connected (Connect this pin to power supply.)").

### Recommended connection of unused pins (Table 2-3, p.20)

The table pairs each pin with an I/O circuit type number and a recommended connection. As transcribed, the type numbers and connections are partially collapsed into single cells; the values that are legible are: D15 to D0 (V805 only) and D31 to D0 (V810 only) — circuit type 5, "Open"; A31 to A1 — type 4; READY — type 1, "Connect to GND via a resistor"; HLDRQ — "Connect to VDD via a resistor"; IC1 — "Open"; IC2 — "Connect to GND"; IC3 (V810 only) — "Connect to VSS". BE1/BE0 (V805 only), BE3 to BE0 (V810 only), SIZ16B, SZRQ and ICHEEN are listed without a legible individual value, and CLK is listed with "—". Figure 2-1 (p.21) shows the I/O circuit of each type.

### Address, data length, byte enable and A1 — 32-bit bus mode (Table 3-1, p.27)

| Data length | Addr bit 1 | Addr bit 0 | BE3 | BE2 | BE1 | BE0 | A1  | Bus cycle sequence |
| ----------- | ---------- | ---------- | --- | --- | --- | --- | --- | ------------------ |
| Byte        | 0          | 0          | 1   | 1   | 1   | 0   | 0   | 1                  |
| Byte        | 0          | 1          | 1   | 1   | 0   | 1   | 0   | 1                  |
| Byte        | 1          | 0          | 1   | 0   | 1   | 1   | 0   | 1                  |
| Byte        | 1          | 1          | 0   | 1   | 1   | 1   | 0   | 1                  |
| Halfword    | 0          | 0          | 1   | 1   | 0   | 0   | 0   | 1                  |
| Halfword    | 1          | 0          | 0   | 0   | 1   | 1   | 0   | 1                  |
| Word        | 0          | 0          | 0   | 0   | 0   | 0   | 0   | 1                  |
| Word        | 0          | 0          | 0   | 0   | 1   | 1   | 1   | 2 (Note)           |

Note: "Bus cycle added by dynamic bus sizing".

### Address, data length, byte enable and A1 — 16-bit bus fixed mode (Table 3-3, p.47)

| Data length | Addr bit 1 | Addr bit 0 | BE3 (Note 1) | BE2 (Note 1) | BE1 | BE0 | A1  | Bus cycle sequence |
| ----------- | ---------- | ---------- | ------------ | ------------ | --- | --- | --- | ------------------ |
| Byte        | 0          | 0          | Hi-Z         | Hi-Z         | 1   | 0   | 0   | 1                  |
| Byte        | 0          | 1          | Hi-Z         | Hi-Z         | 0   | 1   | 0   | 1                  |
| Byte        | 1          | 0          | Hi-Z         | Hi-Z         | 1   | 0   | 1   | 1                  |
| Byte        | 1          | 1          | Hi-Z         | Hi-Z         | 0   | 1   | 1   | 1                  |
| Halfword    | 0          | 0          | Hi-Z         | Hi-Z         | 0   | 0   | 0   | 1                  |
| Halfword    | 1          | 0          | Hi-Z         | Hi-Z         | 0   | 0   | 1   | 1                  |
| Word        | 0          | 0          | Hi-Z         | Hi-Z         | 0   | 0   | 0   | 1                  |
| Word        | 0          | 0          | Hi-Z         | Hi-Z         | 0   | 0   | 1   | 2 (Note 2)         |

Note 1: "The V805 does not have these signals." Note 2: "Added bus cycle".

### Machine fault cycle bus contents — 32-bit bus mode (Table 3-2, p.41)

| Sequence | Address bus (A31 to A1) | Data bus (D31 to D0)                                                           |
| -------- | ----------------------- | ------------------------------------------------------------------------------ |
| 1        | 00000000H               | Cause code of fatal exception (logical sum of FFFF0000H and an exception code) |
| 2        | 00000004H               | Current PSW value                                                              |
| 3        | 00000008H               | Current PC value                                                               |

### Machine fault cycle bus contents — 16-bit bus fixed mode (Table 3-4, p.58)

| Sequence | Address bus (A31 to A1) | Data bus (D15 to D0)                                  |
| -------- | ----------------------- | ----------------------------------------------------- |
| 1        | 00000000H               | Cause code of fatal exception (lower)                 |
| 2        | 00000002H               | Cause code of fatal exception (higher) (always FFFFH) |
| 3        | 00000004H               | Current PSW value (lower)                             |
| 4        | 00000006H               | Current PSW value (higher)                            |
| 5        | 00000008H               | Current PC value (lower)                              |
| 6        | 0000000AH               | Current PC value (higher)                             |

### Exception codes, handler addresses and restore PC (Table 4-1, p.65)

| Exception and interrupt                    | Classification     | Exception code | Handler address | Restore PC (Note 1) |
| ------------------------------------------ | ------------------ | -------------- | --------------- | ------------------- |
| Reset                                      | Interrupt          | FFF0           | FFFFFFF0        | Note 2              |
| NMI                                        | Interrupt          | FFD0           | FFFFFFD0        | next PC (Note 3)    |
| Duplexed exception                         | Exception          | Note 4         | FFFFFFD0        | current PC          |
| Address trap                               | Exception          | FFC0           | FFFFFFC0        | current PC          |
| Trap instruction (parameter is 0x1n)       | Exception          | FFBn           | FFFFFFB0        | next PC             |
| Trap instruction (parameter is 0x0n)       | Exception          | FFAn           | FFFFFFA0        | next PC             |
| Invalid instruction code                   | Exception          | FF90           | FFFFFF90        | current PC          |
| Zero division                              | Exception          | FF80           | FFFFFF80        | current PC          |
| FIV (floating-point invalid operation)     | Exception          | FF70           | FFFFFF60        | current PC          |
| FZD (floating-point zero division)         | Exception          | FF68           | FFFFFF60        | current PC          |
| FOV (floating-point overflow)              | Exception          | FF64           | FFFFFF60        | current PC          |
| FUD (floating-point underflow)             | Exception (Note 5) | FF62           | FFFFFF60        | current PC          |
| FPR (floating-point precision degradation) | Exception (Note 5) | FF61           | FFFFFF60        | current PC          |
| FRO (floating-point reserved operand)      | Exception          | FF60           | FFFFFF60        | current PC          |
| INT level n (n = 0 to 15)                  | Interrupt          | FEn0           | FFFFFEn0        | next PC (Note 3)    |

The exception-code and handler-address columns are printed without a trailing "H"; elsewhere the manual writes the same values as FFFFFFF0H and FFFFFFD0H. Note 1: "PC to be saved to EIPC or FEPC." Note 2: "EIPC and FEPC are undefined." Note 3: "While an instruction whose execution is aborted by an interrupt (refer to Table 4-2) is executed, restore PC = current PC." Note 4: "The exception code of the exception that occurs for the first time is stored to the lower 16 bits of the ECR, and that of the second exception is stored in the higher 16 bits." Note 5: "In the V805 and V810, the floating-point underflow exception and floating-point precision degradation exception do not occur."

### State of each output pin after reset (Table 5-1, p.73)

| Part       | Output pins                                                                 | Pin state      |
| ---------- | --------------------------------------------------------------------------- | -------------- |
| V805       | A31 to A1, BE1, BE0, ST1, ST0, DA, MRQ, R/W, BCYST, ADRSERR, HLDAK (Note)   | High-level     |
| V810       | A31 to A2, BE3 to BE0, ST1, ST0, DA, MRQ, R/W, BCYST, ADRSERR, HLDAK (Note) | High-level     |
| V810       | A1 in 16-bit bus mode                                                       | High-level     |
| V810       | A1 except 16-bit bus mode                                                   | Low-level      |
| V805, V810 | BLOCK                                                                       | Low-level      |
| V805       | D15 to D0                                                                   | High-impedance |
| V810       | D31 to D0                                                                   | High-impedance |

Note: "High-level in the states other than bus hold status".

### Initial value of each register (Table 5-2, p.74)

| Register  | Initial Value |
| --------- | ------------- |
| r0        | 00000000H     |
| r1 to r31 | Undefined     |
| PC        | FFFFFFFFH     |
| EIPC      | Undefined     |
| EIPSW     | Undefined     |
| FEPC      | Undefined     |
| FEPSW     | Undefined     |
| ECR       | 0000FFF0H     |
| PSW       | 00008000H     |
| TKCW      | 000000E0H     |
| CHCW      | 00000000H     |
| ADTRE     | Undefined     |

## Constraints and requirements

- The RESET active (low) level must be held for the duration of 20 clocks or longer. [§2.3(22); §5.1, p.74]
- SIZ16B can be changed only at reset; if it is changed at other times, "the operation of the CPU is not guaranteed". [§2.3(14)]
- ICHEEN (V810) can be changed only at reset; if it is changed at other times, "the operation of the CPU is not guaranteed". [§2.3(16)]
- On the V810, SZRQ and SIZ16B can be changed only at reset. [§3.2, p.44]
- To make SIZ16B active, SZRQ must also be made active. [§2.3(14)]
- To energize the instruction cache, the ICE bit of the cache control word must be set in addition to the ICHEEN input. [§2.3(16)]
- Caution: "The SIZ16B signal should be fixed to 'L' during dynamic bus sizing." [Figure 3-12 Caution, p.40]
- The INT signal and the INTV3 to INTV0 signals must be kept active from the time the CPU has started interrupt servicing until acceptance of the interrupt is notified to external devices through software; the interrupt level may be changed to a higher priority level in the meantime. [§2.3(18)–(19); §4.2.1, p.67]
- The machine fault status can be released only by reset input. [§3.1.6, p.41; §3.2.6, p.58]
- IC1 must be left open; IC2 must be connected to GND; IC3 (V810) must be connected to VDD. [§2.1 Cautions, p.7–p.10; §2.3(25)–(27)]
- Accessing the reserved system register numbers 8 to 23 and 26 to 31 is stated as "Operation is not guaranteed if this is accessed." [§1.5.2, p.6]
- Execution cannot branch to an odd address because bit 0 of the PC is fixed to 0. [§1.5.1(2), p.5]
- The clock may be stopped at any timing except during the clock stop exception period (the reset period immediately after power on, when the RESET pin is low for 20 clocks or more). [§5.2, p.75]
- If BLOCK is active, the TH and THS (bus hold) states do not start. [§2.3(11)]
- On the V810 in 16-bit bus fixed mode, D31 to D16 need not be connected. [§2.3(14)]

## Stated gaps and ambiguities

- Initial PC value is stated inconsistently: §1.5.1(2) (p.5) and §2.3(22) state the PC is initialized to FFFFFFF0H at reset and that execution begins at address FFFFFFF0H, and Table 4-1 (p.65) gives the reset handler address as FFFFFFF0; Table 5-2 (p.74) lists the PC initial value as FFFFFFFFH. The manual does not reconcile these.
- IC3 connection is stated inconsistently: the §2.1 caution (p.10) and §2.3(27) say to connect IC3 to VDD / the VDD line, and §2.2 (p.12) says "Connect this pin to power supply"; Table 2-3 (p.20) says "Connect to VSS". The manual does not reconcile these, and "VSS" appears nowhere else in the document — the ground pin is named GND throughout.
- Pin direction for the V805 byte enables is stated inconsistently: §2.2 (p.11) and §2.3(3) call BE1, BE0 a 3-state output, while Table 2-2 (p.19) lists them as "3-state input/output".
- The HLDAK description in §2.3(12) says both that "The CPU makes this signal active after it has relinquished the bus mastership" and that "When the HLDRQ input becomes inactive, the CPU makes the HLDAK signal active, and acquires the bus mastership"; the manual does not state when HLDAK is made inactive.
- Supply voltage is stated inconsistently in scope: §2.2 (p.12) and §2.3(23) describe VDD as a "+5-V power supply pin", while the §1.1 (p.1) part-number table lists operating supply voltage ranges down to VDD = 2.2 to 3.6 V for µPD70731-20 and µPD70732-25.
- §3.2.5 (p.52, p.55) refers to "the space outputting the chip select signal" and to a chip select signal output at the falling edge of the T1 state clock, but no chip select pin appears in the pin configuration, pin function list or pin status tables of CHAPTER 2.
- §5.1 (p.73) cross-references "2.4 Pin State" while the section is titled "2.4 Pin Status".
- §5.1 (p.74) refers to "The 805 and V810", omitting the V from V805.
- The wait/bus-sizing/bus-hold requests stated as valid during the machine fault and halt acknowledge write cycles differ by mode: §3.1.6 and §3.1.7 (p.41, p.43) list wait, bus sizing and bus hold; §3.2.6 and §3.2.7 (p.58, p.60) list only wait and bus hold. The manual does not comment on the difference.
- The exception code for a duplexed exception is given only as "Note 4" in Table 4-1 (p.65); no single code value is stated for it.
- Table 4-1 (p.65) lists FUD and FPR exception codes and handler addresses while Note 5 states those two exceptions do not occur in the V805 and V810; Table 4-4 (p.72) likewise ranks FUD and FPR against the other floating-point exceptions using only the "does not occur simultaneously" symbol.
- The manual does not state what the "1-Kbyte cache memory" listed in §1.1 (p.1) caches, beyond references elsewhere to an "instruction cache" enabled via ICHEEN and the ICE bit of the cache control word.
- Register-set details beyond the register list, PSW flag layouts (NP, EP, ID, AE, I3 to I0 are used by name but never defined field-by-field), and the ECR field split into EICC and FECC are referenced but not specified here; the manual defers instruction and architecture detail to the separately available V810 FAMILY USER'S MANUAL ARCHITECTURE. [INTRODUCTION; §4.1, p.66]
- Several figures are image-only in the transcription and their content is not available as text: Figure 1-1 (Program Registers, p.5), Figure 2-1 (Pin I/O Circuit, p.21), the package pin-configuration drawings of §2.1 (p.7–p.9), all bus timing charts (Figures 3-3 to 3-14, 3-17 to 3-27), the interrupt timing charts (Figures 4-1, 4-2), and the reset timing chart (Figure 5-1). Some of the accompanying data tables (notably the operand read/write mapping tables in §3.1.2, §3.1.3, §3.2.2 and §3.2.3) are transcribed with garbled column alignment.
