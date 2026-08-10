# Notes: V810(TM) 32-BIT MICROPROCESSOR (µPD70732)

## Source

- File: U10691EJ3V0DS00.md
- Type: data sheet (device data sheet with pin, register, instruction, and electrical/package specifications)
- Extent: contents list runs to page 62 (section 12), followed by CMOS handling notes, regional contact information, and legal notices; approximately 18,000 words
- Version or date stated in document: not stated in the body text
- Author or publisher stated in document: NEC Corporation; legal notice and trademark statement at the end attribute the document to NEC Corporation [end matter]
- Related documents the document names: "V805(TM), V810 User's Manual Hardware : U10661E" and "V810 Family User's Manual Architecture : U10082E" [front page]; "Semiconductor Device Mounting Technology Manual" (C10535E) [§12]; "Electrical Characteristics for Microcomputer (IEI-601)" [end matter, "Reference"]

## Scope

The document is the data sheet for the µPD70732 (also called V810), described as NEC's first microprocessor of the V810 family(TM) for embedded control applications [front page]. It covers pin functions, register set, data types, address space, bus interface, interrupts and exceptions, cache, reset, instruction set summary, electrical specifications for three supply-voltage ranges, package drawings, and recommended soldering conditions [CONTENTS].

The document explicitly defers detailed functional description elsewhere: it states that the functions are described in detail in the V805/V810 User's Manual Hardware (U10661E) and the V810 Family User's Manual Architecture (U10082E), "which should be read before starting design work" [front page]. Section 9.2 gives instruction mnemonics as a quick reference or dictionary rather than a full instruction description [§9.2].

## Key concepts

- **µPD70732** — the part number of the microprocessor the data sheet describes; the document states it is also known as V810 [front page].
- **V810 family(TM)** — the NEC microprocessor family of which the µPD70732 is described as the first member [front page].
- **Dynamic bus sizing** — a function of 32-bit bus mode that uses the data bus in 16-bit bus width to access 16-bit peripherals, enabled by setting the SZRQ signal active [§5].
- **16-bit bus fixed mode** — a bus interface mode fixing the bus at 16 bits, switchable only at reset using the SIZ16B signal [§5].
- **Bit string** — a data type whose bit length is variable from 0 to 2^32 – 1, specified by three attributes: first-word address A, in-word bit offset B, and bit length M [§3.1.4].
- **Halfword** — 2-byte (16-bit) data [§3.1.1(2), §4]. **Word / short real** — 4-byte (32-bit) data [§3.1.1(3), §4].
- **Duplexed exception** — an exception condition for which the exception code of the first exception is stored in the lower 16 bits of ECR and the second in the higher 16 bits [Table 6-1 Note 4].
- **IC1 / IC2 / IC3** — internally connected pins; IC means "Internally Connected" [Pin Configuration remarks; §1.1].

## Content

### Front page: description and features

- The document states the V810 employs a RISC architecture for embedded control applications [front page].
- The document lists intended applications as facsimile, digital PPC, word processor, image processor, and real time control device [front page].
- Stated features: high-performance 32-bit architecture for embedded control application; 32-bit separate address/data bus; 1-Kbyte cache memory; pipeline structure of 1 clock pitch; 16-bit fixed instructions (with some exceptions); 32 32-bit general-purpose registers; 4-Gbyte linear address space [Features].
- Stated features continued: register/flag hazard interlocked by hardware; dynamic bus sizing function (16 bits); 16-bit bus fixing function; 16-bit bus system can be configured; floating-point operation instructions based upon IEEE754 data format; bit string instructions; 16 levels of high-speed interrupt responses; clock can be stopped by internal static operation [Features].
- Stated maximum operating frequency: 16/20/25 MHz [Features].
- Stated low-voltage operation: VDD = 2.7 to 3.6 V (Max. 16 MHz); VDD = 2.2 to 3.6 V (Max. 10 MHz) [Features].
- Stated small package availability: 14 x 14 mm fine-pitch TQFP [Features].

### 1. PIN FUNCTIONS (page 8)

- §1.1 gives the pin function list; §1.2 gives pin I/O circuit types and recommended connection of unused pins [CONTENTS, pages 8 and 10].
- The pin function table gives, per signal, the I/O direction, function, status during operation, bus hold status, and bus idle status at reset [§1.1].
- A31 to A1 (Address Bus) are 3-state outputs; status during operation Hi-Z, bus hold at reset Hi-Z, bus idle at reset H (marked "Note") [§1.1].
- D31 to D0 (Data Bus) are 3-state I/O, bidirectional data bus; Hi-Z / Hi-Z / Hi-Z [§1.1].
- BE3 to BE0 (Byte Enable) are 3-state outputs indicating valid data bus when data is accessed; Hi-Z / Hi-Z / H [§1.1].
- ST1, ST0 (Status) are 3-state outputs indicating type of bus cycle; Hi-Z / Hi-Z / H [§1.1].
- DA (Data Access) is a 3-state output, strobe signal for bus cycle; Hi-Z / Hi-Z / H [§1.1].
- MRQ (Memory Request) is a 3-state output indicating memory access; Hi-Z / Hi-Z / H [§1.1].
- R/W (Read/Write) is a 3-state output distinguishing read access from write access; Hi-Z / Hi-Z / H [§1.1].
- BCYST (Bus Cycle Start) is a 3-state output indicating start of bus cycle; Hi-Z / Hi-Z / H [§1.1].
- READY (Ready) is an input that extends the bus cycle [§1.1].
- HLDRQ (Hold Request) is an input that requests bus mastership [§1.1].
- HLDAK (Hold Acknowledge) is an output that acknowledges HLDRQ; L / L / H [§1.1].
- SZRQ (Bus Sizing Request) is an input that requests bus sizing [§1.1].
- SIZ16B (Bus Size 16 Bit) is an input that fixes external data bus width to 16 bits [§1.1].
- BLOCK (Bus Lock) is an output that requests to inhibit use of bus; L / L / L [§1.1].
- ICHEEN (Instruction Cache Enable) is an input that operates the instruction cache [§1.1].
- INT (Maskable Interrupt) is an input for interrupt request [§1.1].
- INTV3 to INTV0 (Interrupt Level) are inputs conveying interrupt level [§1.1].
- NMI (Non-Maskable Interrupt) is an input for non-maskable interrupt request [§1.1].
- CLK is the CPU clock input [§1.1].
- RESET is an input that resets internal status [§1.1].
- ADRSERR (Address Error) is an output indicating that data alignment is illegal; not affected during operation, H at bus hold, H at bus idle [§1.1].
- VDD is positive power supply; GND is ground potential (0 V) [§1.1].
- IC1 is internally connected and the document instructs to leave the pin open; IC2 is internally connected and the document instructs to ground the pin; IC3 is internally connected and the document instructs to connect the pin to power supply [§1.1; Pin Configuration cautions].

### 1.2 Pin I/O circuit types and unused-pin connection (Table 1-1, page 10)

- D31 to D0: I/O circuit type 5; recommended connection when unused: Open [Table 1-1].
- A31 to A1: I/O circuit type 4; recommended connection: Open [Table 1-1].
- READY: I/O circuit type 1; connect to GND via resistor [Table 1-1].
- HLDRQ: connect to VDD via resistor [Table 1-1].
- HLDAK: I/O circuit type 4; Open [Table 1-1].
- SZRQ: connect to VDD via resistor [Table 1-1].
- SIZ16B: connect to GND via resistor [Table 1-1].
- BLOCK: I/O circuit type 4; Open [Table 1-1].
- ICHEEN: connect to VDD via resistor [Table 1-1].
- INT: connect to GND via resistor [Table 1-1].
- INTV3 to INTV0: connect to VDD via resistor [Table 1-1].
- CLK: recommended connection column is "—" [Table 1-1].
- ADRSERR: I/O circuit type 4; Open [Table 1-1].
- IC2: connect to GND; IC3: connect to VDD [Table 1-1].
- Figure 1-1 shows the I/O circuit of each type; the figure is present as an image reference only, so the circuit content is not available as text [§1.2, Figure 1-1].

### 2. REGISTER SET (page 12)

- Registers are classified into two types: general-purpose program register set and dedicated system register set; all registers are 32 bits wide [§2].
- The program register set is composed of general-purpose registers and a program counter [§2.1].
- Thirty-two general-purpose registers r0 to r31 are available; all can be used as data registers or address registers [§2.1(1)].
- r0 and r26 through r30 are implicitly used by some instructions; r1 through r5 and r31 are implicitly used by the assembler and C compiler; the document states special care such as saving and restoring contents is necessary when using these registers [§2.1(1)].
- r0 is the zero register and always holds zeros [Table 2-1].
- r1 is reserved for the assembler and used as a working register to generate 32-bit immediate data [Table 2-1].
- r2 is the handler stack pointer, used as the stack pointer for the handler [Table 2-1].
- r3 is the stack pointer, used to generate a stack frame at a function call [Table 2-1].
- r4 is the global pointer, used to access a global variable in the data area [Table 2-1].
- r5 is the text pointer, pointing to the start address of the text area [Table 2-1].
- r6 to r25 store address or data variables [Table 2-1].
- r26 is string destination bit offset; r27 is string source bit offset; r28 is string length register; r29 is string destination address register; r30 is string address register; all used in bit-string instruction execution [Table 2-1].
- r31 is the link pointer and stores the return address at execution of a JAL instruction [Table 2-1].
- The program counter (PC) indicates the address of the instruction currently executed; bit 0 of the PC is fixed to 0 and execution cannot branch to an odd address [§2.1(2)].
- PC contents are initialized to FFFFFFF0H at reset [§2.1(2)].
- System register numbers: 0 = EIPC, 1 = EIPSW (status saving registers for exception/interrupt); 2 = FEPC, 3 = FEPSW (status saving registers for NMI/duplexed exception); 4 = ECR (exception cause register); 5 = PSW (program status word); 6 = PIR (processor ID register); 7 = TKCW (task control word); 8 to 23 Reserved; 24 = CHCW (cache control word); 25 = ADTRE (address trap register); 26 to 31 Reserved [Table 2-2].
- EIPC and EIPSW save the PC and PSW respectively when an exception or interrupt occurs [Table 2-2].
- FEPC and FEPSW save the PC and PSW respectively when an NMI or duplexed exception occurs [Table 2-2].
- PIR identifies the CPU type number [Table 2-2].
- TKCW controls floating-point operations [Table 2-2].
- CHCW controls the on-chip instruction cache [Table 2-2].
- ADTRE holds an address and is used for address trapping [Table 2-2].
- To read or write a system register, specify a system register number with the system register load (LDSR) or system register store (STSR) instruction [§2.2].

### 3. DATA TYPES (page 15)

- Supported data types: integer (8, 16, 32 bits); unsigned integer (8, 16, 32 bits); bit string; single-precision floating-point data (32 bits) [§3.1].
- The V810 uses little-endian data addressing [§3.1.1].
- A byte is consecutive 8-bit data aligned to a byte boundary, bits numbered 0 (LSB) to 7 (MSB); accessed by specifying address A [§3.1.1(1)].
- A halfword is consecutive 16-bit (2-byte) data aligned to a halfword boundary, bits numbered 0 (LSB) to 15 (MSB); accessed by specifying address A only, lowest bit must be 0 [§3.1.1(2)].
- A word, also called short real, is consecutive 32-bit (4-byte) data aligned to a word boundary, bits numbered 0 (LSB) to 31 (MSB); accessed by specifying address A only, lower two bits must be 0 [§3.1.1(3)].
- All integers are expressed in two's-complement binary notation and are 8, 16, or 32 bits; bit 0 is least significant and the highest bit expresses the sign [§3.1.2].
- Integer ranges: Byte 8 bits –128 to +127; Halfword 16 bits –32768 to +32767; Word 32 bits –2147483648 to +2147483647 [§3.1.2 table].
- Unsigned integer ranges: Byte 8 bits 0 to 255; Halfword 16 bits 0 to 65535; Word 32 bits 0 to 4294967295 [§3.1.3 table].
- Bit-string attributes: A = address of the string data's first word (lower two bits must be 0); B = in-word bit offset in the string data (0 to 31); M = bit length of the string data [§3.1.4].
- Bit-string manipulation direction may be upward (lower to higher addresses) or downward (higher to lower); for upward the first-word address is A and in-word bit offset is B, for downward the first-word address is A + 4 and the in-word bit offset is shown as D; bit length is M in both directions [§3.1.4 table].
- Single-precision floating-point data is 32 bits long and its bit allocation complies with the IEEE single format: 1-bit mantissa sign bit, 8-bit exponent, 23-bit mantissa [§3.1.5].
- The exponent is offset-expressed from the bias value – 127, and the mantissa is binary-expressed with the integer part omitted [§3.1.5].
- Floating-point bit layout shown: bit 31 = s (sign), bits 30 to 23 = exp (8), bits 22 to 0 = mantissa (23) [§3.2 accompanying bit-field table].
- Word data must be aligned to a word boundary (lowest two address bits fixed to 0) and halfword data to a halfword boundary (lowest address bit fixed to 0) [§3.2].
- If data is not aligned as specified, the document states the lowest one bit (in the case of word) or two bits (in the case of halfword) of its address will forcibly be masked with 0s when the data is accessed [§3.2]. (See "Stated gaps and ambiguities" — the word/halfword pairing in this sentence is the reverse of the alignment rule stated in the same section.)

### 4. ADDRESS SPACE (page 18)

- The V810 supports 4 Gbytes of linear memory space and I/O space [§4].
- The CPU outputs 32-bit addresses to memory and I/Os; addresses run from 0 to 2^32 – 1 [§4].
- Bit number 0 of each byte is the LSB and bit number 7 is the MSB; unless otherwise specified, the byte at the lower address of multi-byte data is the LSB and the byte at the higher address is the MSB (little endian) [§4].
- Figure 4-1 is the memory map and Figure 4-2 is the I/O map [§4]. Both appear as image references only; the only map content available as text is "FFFFFFFFH", "General use", and "00000000H" for the I/O map [Figure 4-2].
- Figure 4-1 carries a note directing the reader to Table 6-1 Exception Codes for details [Figure 4-1 Note].

### 5. BUS INTERFACE FUNCTION (page 21)

- The V810 is equipped with a 32-bit data bus [§5].
- Two bus interface modes exist: 32-bit bus mode which uses the data bus in 32 bits, and 16-bit bus fixed mode which fixes the bus in 16 bits [§5].
- Modes can be switched only at reset using the SIZ16B signal [§5].
- 32-bit bus mode has a dynamic bus sizing function used by setting the SZRQ signal active; access to word data (32-bit data) in dynamic bus sizing is executed by loading/storing 16-bit data twice [§5].
- In 16-bit bus fixed mode, access to word data (32-bit data) is executed by activating a bus cycle twice, and the control signal and the A1 signal output values according to the 16-bit system [§5].
- Table 5-1 (32-bit bus mode) byte accesses, columns BE3/BE2/BE1/BE0, A1, bus cycle sequence: address bits (1,0) = (0,0) → 1 1 1 0, A1 = 0, 1 cycle; (0,1) → 1 1 0 1, A1 = 0, 1 cycle; (1,0) → 1 0 1 1, A1 = 0, 1 cycle; (1,1) → 0 1 1 1, A1 = 0, 1 cycle [Table 5-1].
- Table 5-1 halfword accesses: address bits (1,0) = (0,0) → BE 1 1 0 0, A1 = 0, 1 cycle; (1,0) → BE 0 0 1 1, A1 = 0, 1 cycle [Table 5-1].
- Table 5-1 word access: address bits (0,0) → BE 0 0 0 0, A1 = 0, 1 cycle; second row → BE 0 0 1 1, A1 = 1, sequence 2, marked Note "Bus cycle added by dynamic bus sizing" [Table 5-1].
- Table 5-2 (16-bit bus fixed mode) byte accesses hold BE3 and BE2 at Hi-Z throughout: (0,0) → BE1/BE0 = 1 0, A1 = 0, 1 cycle; (0,1) → 0 1, A1 = 0, 1 cycle; (1,0) → 1 0, A1 = 1, 1 cycle; (1,1) → 0 1, A1 = 1, 1 cycle [Table 5-2].
- Table 5-2 halfword accesses: (0,0) → BE1/BE0 = 0 0, A1 = 0, 1 cycle; (1,0) → 0 0, A1 = 1, 1 cycle [Table 5-2].
- Table 5-2 word access: (0,0) → BE1/BE0 = 0 0, A1 = 0, 1 cycle; second row → 0 0, A1 = 1, sequence 2, marked Note "Added bus cycle" [Table 5-2].

### 6. INTERRUPT AND EXCEPTION (page 22)

- Interrupts are events that take place independently of program execution and are classified into maskable interrupts and a non-maskable interrupt; an exception is an event that takes place depending upon program execution [§6].
- The document states there is little difference between interrupt and exception in terms of flow, but the interrupt takes precedence over the exception [§6].
- If an exception, maskable interrupt, or NMI occurs, control is transferred to a handler whose address is determined by the source [§6].
- The exception source can be checked by examining an exception code stored in the ECR (Exception Code Register); each handler analyzes the ECR contents and performs appropriate servicing [§6].
- Reset: classification Interrupt, exception code F F F 0, handler address F F F F F F F 0, restore PC per Note 2 (EIPC and FEPC are undefined) [Table 6-1].
- NMI: Interrupt, code F F D 0, handler address F F F F F F D 0, restore PC = next PC (Note 3) [Table 6-1].
- Duplexed exception: Exception, code per Note 4, handler address F F F F F F D 0, restore PC = current PC [Table 6-1].
- Address trap: Exception, code F F C 0, handler address F F F F F F C 0, restore PC = current PC [Table 6-1].
- Trap instruction (parameter is 0x1n): Exception, code F F B n, handler address F F F F F F B 0, restore PC = next PC [Table 6-1].
- Trap instruction (parameter is 0x0n): Exception, code F F A n, handler address F F F F F F A 0, restore PC = next PC [Table 6-1].
- Invalid instruction code: Exception, code F F 9 0, handler address F F F F F F 9 0, restore PC = current PC [Table 6-1].
- Zero division: Exception, code F F 8 0, handler address F F F F F F 8 0, restore PC = current PC [Table 6-1].
- FIV (floating-point invalid operation): Exception, code F F 7 0, handler address F F F F F F 6 0, restore PC = current PC [Table 6-1].
- FZD (floating-point zero division): Exception, code F F 6 8, handler address F F F F F F 6 0, restore PC = current PC [Table 6-1].
- FOV (floating-point overflow): Exception, code F F 6 4, handler address F F F F F F 6 0, restore PC = current PC [Table 6-1].
- FUD (floating-point underflow): Exception, code F F 6 2, handler address F F F F F F 6 0, restore PC = current PC, marked Note 5 [Table 6-1].
- FPR (floating-point precision degradation): Exception, code F F 6 1, handler address F F F F F F 6 0, restore PC = current PC, marked Note 5 [Table 6-1].
- FRO (floating-point reserved operand): Exception, code F F 6 0, handler address F F F F F F 6 0, restore PC = current PC [Table 6-1].
- INT level n (n = 0 to 15): Interrupt, code F E n 0, handler address F F F F F E n 0, restore PC = next PC (Note 3) [Table 6-1].
- Note 1 states the restore PC column is the PC to be saved to EIPC or FEPC [Table 6-1 Note 1].
- Note 3 states that while an instruction whose execution is aborted by an interrupt (DIV/DIVU, single-precision floating-point data, bit string instruction) is executed, restore PC = current PC [Table 6-1 Note 3].
- Note 4 states the exception code of the exception that occurs for the first time is stored to the lower 16 bits of the ECR, and that of the second exception is stored in the higher 16 bits [Table 6-1 Note 4].
- Note 5 states that in the V810 the floating-point underflow exception and floating-point precision degradation exception do not occur [Table 6-1 Note 5].

### 7. CACHE (page 23)

- Section 7 consists of Figure 7-1, showing the instruction cache configuration provided to the V810 [§7, Figure 7-1]. Figure 7-1 appears as image references only; no cache parameters are given as text in section 7.
- The 1-Kbyte cache memory figure is stated on the front page feature list rather than in section 7 [front page, Features].

### 8. RESET (page 24)

- A low-level input detection on the RESET pin always triggers a system reset [§8].
- All hardware-controlling registers are initialized as shown in Table 8-1; after initialization completes and the RESET pin returns to the high level, the device is released from the resetting state and starts implementation of a program [§8].
- The document states that, if necessary, some registers should be set to user-desired values in the first stage of the program [§8].
- Register state after reset: PC (program counter) = FFFFFFF0H [Table 8-1].
- EIPC (status saving register for interrupt) = Undefined (printed "Undefind") [Table 8-1].
- FEPC (status saving register for NMI) = Undefined (printed "Undefind") [Table 8-1].
- Interrupt cause register FECC = 0000H; EICC = FFF0H [Table 8-1].
- PSW (program status word) = 00008000H [Table 8-1].
- General-purpose register r0 = fixed to 00000000H; r1 to r31 = Undefined (printed "Undefind") [Table 8-1].

### 9. INSTRUCTION SET (page 25)

- V810 instructions are formatted in either 16 bits or 32 bits [§9.1].
- Examples of 16-bit format instructions given: binomial operation, control, and conditional branch [§9.1].
- Examples of 32-bit format instructions given: load/store, I/O manipulate, 16-bit immediate, jump & link, and extended operations [§9.1].
- Some instructions have an unused field; the document states not to write a program that uses this field because it is reserved for future use, and that the unused field must be set to zeros [§9.1].
- Instruction storage in memory: the lower half of an instruction (the half including bit 0) is stored at the lower address; the higher half (the half including bit 15 or 31) is stored at the higher address [§9.1].
- Format I (reg-reg): one 6-bit opcode field and two 5-bit fields specifying general-purpose registers as operands; 16-bit instructions use this format [§9.1(1)].
- Format II (imm-reg): one 6-bit opcode field, one 5-bit immediate field, and one field specifying a general-purpose register operand; 16-bit instructions [§9.1(2)].
- Format III (conditional branch): one 3-bit opcode field, one 4-bit condition code field, and one 9-bit branch displacement field with its LSB masked to 0; 16-bit instructions [§9.1(3)].
- Format IV (intermediate jump): one 6-bit opcode field and one 26-bit displacement field with its LSB masked to 0; 32-bit instructions [§9.1(4)].
- Format V (3-operand): one 6-bit opcode field, two fields specifying general-purpose registers, and one 16-bit immediate field; 32-bit instructions [§9.1(5)].
- Format VI (load/store): one 6-bit opcode field, two fields specifying a general-purpose register, and one 16-bit displacement field; 32-bit instructions [§9.1(6)].
- Format VII (extension): one 6-bit opcode field, two 5-bit general-purpose register fields, and one 6-bit sub-operation code field; the remaining 10 bits are reserved for future use and must be set to zeros; 32-bit instructions [§9.1(7)].
- Operand notation used in the mnemonic list: reg1 = general-purpose register used as a source register; reg2 = general-purpose register used mainly as a destination register and occasionally as a source register; imm5 = 5-bit immediate; imm16 = 16-bit immediate; disp9 = 9-bit displacement; disp16 = 16-bit displacement; disp26 = 26-bit displacement; regID = system register number; vector adr = trap handler address that corresponds to a trap vector [§9.2 legend].
- Table 9-1 lists instruction mnemonics in alphabetical order across nine parts (1/9 through 9/9), with columns Instruction / Operand(s) / Format / CY / OV / S / Z / Instruction Function [Table 9-1].
- Flag column symbols appearing in Table 9-1 are `*`, `0`, and `–`; the document's legend for these symbols is present only as an image reference, so the symbol definitions are not available as text [Table 9-1, Legend].

### 10. ELECTRICAL SPECIFICATIONS (page 37)

- Section 10 is divided into 10.1 (VDD = +5 V ± 10%, page 38), 10.2 (VDD = 2.7 to 3.6 V, page 47), and 10.3 (VDD = 2.2 to 3.6 V, page 51) [CONTENTS].
- The "Supported Electrical Specifications" matrix cross-references operating supply voltage, operating ambient temperature TA, and the three part variants µPD70732-16, µPD70732-20, µPD70732-25 in 120-pin plastic QFP, 120-pin plastic TQFP, and 176-pin ceramic PGA [§10, Supported Electrical Specifications].
- VDD = +5 V ± 10%, TA = –10 to +70°C: specifications exist for QFP at (16 MHz), (20 MHz), (25 MHz), for TQFP at (25 MHz), and for 176-pin ceramic PGA at (25 MHz) [§10 matrix].
- VDD = +5 V ± 10%, TA = –40 to +85°C: specifications exist for the 25 MHz QFP part at (20 MHz) and for TQFP at (20 MHz); other columns are "—" [§10 matrix].
- VDD = 2.7 to 3.6 V, TA = –40 to +85°C: specifications exist for the 25 MHz QFP at (16 MHz) and TQFP at (16 MHz); other columns "—" [§10 matrix].
- VDD = 2.2 to 3.6 V, TA = –40 to +85°C: specifications exist for the 25 MHz QFP at (10 MHz) and TQFP at (10 MHz); other columns "—" [§10 matrix].
- Matrix remarks state that a mark means "with electrical specifications", "—" means "without electrical specifications", and parentheses indicate maximum operating frequency [§10 Remarks 1 and 2].
- Timing figures are given at the end of section 10 as Clock Timing, Reset Timing, Memory/I/O Access Timing, Dynamic Bus Sizing Timing, Interrupt Timing, and Bus Hold Timing; all appear as image references only [§10 timing figure headings].
- The Memory/I/O Access Timing figure carries a Note listing A31 to A1, BE3 to BE0, R/W, MRQ, ST1, ST0, BLOCK, ADRSERR [Memory, I/O Access Timing Note].
- The Bus Hold Timing figure carries Note 1 listing A31 to A1, BE3 to BE0, R/W, MRQ, ST1, ST0, and Note 2 stating the level immediately before the high-impedance state has been stored internally; a Remark states a dashed line indicates high impedance [Bus Hold Timing Notes and Remark].

### 11. PACKAGE DRAWINGS (page 59)

- Package drawings are given for 120-pin plastic QFP (28 x 28), 120-pin plastic TQFP (Fine pitch) (14 x 14), and 176-pin ceramic PGA (Seamweld) [§11].
- The QFP drawing carries package code P120GD-80-LBB, MBB-1 [§11].
- The TQFP drawing carries package code S120GC-40-9EV [§11].

### 12. RECOMMENDED SOLDERING CONDITIONS (page 62)

- The document states the µPD70732 should be soldered and mounted under the conditions recommended in its tables [§12].
- The document refers readers to the information document "Semiconductor Device Mounting Technology Manual" (C10535E) for details of recommended soldering conditions [§12].
- The document states that for soldering methods and conditions other than those recommended, an NEC sales representative should be contacted [§12].
- Table 12-1 covers surface mounting type soldering conditions; Table 12-2 covers insertion type soldering conditions [§12].

### End matter

- Three CMOS handling notes are given: precaution against ESD for semiconductors; handling of unused input pins for CMOS; status before initialization of MOS devices [NOTES FOR CMOS DEVICES 1–3].
- The unused-input-pin note states that input levels of CMOS devices must be fixed high or low using pull-up or pull-down circuitry, and that each unused pin should be connected to VDD or GND with a resistor if it is considered to have a possibility of being an output pin [NOTES FOR CMOS DEVICES 2].
- The initialization note states power-on does not guarantee out-pin levels, I/O settings, or contents of registers, and that reset operation must be executed immediately after power-on for devices having reset function [NOTES FOR CMOS DEVICES 3].
- Regional contact listings are given for NEC Electronics offices in the U.S. (Mountain View, California), Germany (Duesseldorf), UK (Milton Keynes), Italy (Milano), Hong Kong, Korea (Seoul Branch), Singapore, Taiwan (Taipei), Brazil (Sao Paulo-SP), Benelux (Eindhoven), France, Spain (Madrid), and Scandinavia (Taeby, Sweden) [Regional Information].
- NEC device quality grades are defined as "Standard", "Special", and "Specific", with recommended application categories for each; the quality grade of NEC devices is "Standard" unless otherwise specified [end matter].
- The document states anti-radioactive design is not implemented in this product [end matter].
- The document states related documents indicated in the publication may include preliminary versions, and that preliminary versions are not marked as such [end matter].
- V805, V810, and V810 Family are stated to be trademarks of NEC Corporation [end matter].

## Specifications and procedures

### Ordering information (front page)

| Part Number       | Package                                        | Max. operating freq. (MHz) |
| ----------------- | ---------------------------------------------- | -------------------------- |
| µPD70732GD-16-LBB | 120-pin plastic QFP (28 x 28 mm)               | 16                         |
| µPD70732GD-20-LBB | 120-pin plastic QFP (28 x 28 mm)               | 20                         |
| µPD70732GD-25-LBB | 120-pin plastic QFP (28 x 28 mm)               | 25                         |
| µPD70732GC-25-9EV | 120-pin plastic TQFP (Fine pitch) (14 x 14 mm) | 25                         |
| µPD70732R-25      | 176-pin ceramic PGA (Seam weld)                | 25                         |

[Ordering Information]

### Pin configuration cautions

- For the 120-pin plastic QFP (28 x 28 mm) (Top View), µPD70732GD-xx-LBB: leave the IC1 pin open; connect the IC2 pin to GND [Pin Configuration, QFP cautions].
- For the 120-pin plastic TQFP (Fine pitch) (14 x 14 mm) (Top View), µPD70732GC-25-9EV: VDD is power supply pin and all VDD pins should be connected to a +5 V power supply (the same power supply); GND is ground pin and all GND pins should be connected to the same GND; leave the IC1 pin open; connect the IC2 pin to GND [Pin Configuration, TQFP cautions].
- For the 176-pin ceramic PGA (Seam weld), µPD70732R-25: leave the IC1 pin open; connect the IC2 pin to GND; connect the IC3 pin to power supply [Pin Configuration, PGA cautions].
- The document remarks that for the 176-pin ceramic PGA the insertion guide pin is not included in the number of pins [Pin Configuration, PGA remark].
- The QFP and TQFP pin-position drawings appear as image references only; per-pin numbering for those two packages is not available as text [Pin Configuration].

### 176-pin ceramic PGA pin assignment (µPD70732R-25)

Row A: A1 IC2, A2 D12, A3 D13, A4 D10, A5 GND, A6 D6, A7 IC2, A8 D5, A9 IC2, A10 D1, A11 VDD, A12 RESET, A13 IC1, A14 IC1, A15 IC2 [PGA pin table].

Row B: B1 D17, B2 D18, B3 GND, B4 D11, B5 GND, B6 D7, B7 VDD, B8 D3, B9 GND, B10 D0, B11 GND, B12 IC1, B13 GND, B14 IC1, B15 ICHEEN [PGA pin table].

Row C: C1 VDD, C2 VDD, C3 D16, C4 D14, C5 VDD, C6 D8, C7 VDD, C8 D4, C9 D2, C10 IC3, C11 VDD, C12 IC1, C13 IC2, C14 VDD, C15 NMI [PGA pin table].

Row D: D1 D23, D2 D22, D3 D20, D4 GND, D5 D15, D6 D9, D7 VDD, D8 VDD, D9 GND, D10 IC3, D11 IC2, D12 GND, D13 INT, D14 INTV1, D15 GND [PGA pin table].

Row E: E1 D27, E2 D25, E3 D21, E4 D19, E12 IC3, E13 INTV0, E14 IC3, E15 IC1 [PGA pin table].

Row F: F1 VDD, F2 D26, F3 D24, F4 GND, F12 INTV2, F13 INTV3, F14 VDD, F15 GND [PGA pin table].

Row G: G1 D29, G2 D28, G3 IC2, G4 IC2, G12 VDD, G13 IC2, G14 IC1, G15 IC1 [PGA pin table].

Row H: H1 A31, H2 D30, H3 GND, H4 D31, H12 GND, H13 CLK, H14 IC1, H15 IC2 [PGA pin table].

Row J: J1 A30, J2 A29, J3 IC2, J4 VDD, J12 IC2, J13 IC2, J14 IC1, J15 IC1 [PGA pin table].

Row K: K1 IC2, K2 A27, K3 A25, K4 A24, K12 GND, K13 BLOCK, K14 VDD, K15 VDD [PGA pin table].

Row L: L1 A28, L2 A26, L3 A22, L4 A20, L12 HLDAK, L13 VDD, L14 IC1, L15 IC1 [PGA pin table].

Row M: M1 GND, M2 A23, M3 A21, M4 GND, M5 A16, M6 A10, M7 VDD, M8 A5, M9 VDD, M10 ST1, M11 A1, M12 GND, M13 BCYST, M14 DA, M15 SIZ16B [PGA pin table].

Row N: N1 VDD, N2 VDD, N3 A17, N4 A15, N5 VDD, N6 A9, N7 VDD, N8 VDD, N9 A3, N10 HLDRQ, N11 VDD, N12 BE2, N13 BE1, N14 VDD, N15 IC1 [PGA pin table].

Row P: P1 A18, P2 A19, P3 GND, P4 A12, P5 GND, P6 A8, P7 GND, P8 A6, P9 GND, P10 SZRQ, P11 GND, P12 MRQ, P13 GND, P14 ADRSERR, P15 BE0 [PGA pin table].

Row Q: Q1 IC2, Q2 A13, Q3 A14, Q4 A11, Q5 GND, Q6 A7, Q7 IC2, Q8 A4, Q9 IC2, Q10 A2, Q11 READY, Q12 ST0, Q13 BE3, Q14 R/W, Q15 IC2 [PGA pin table].

### Instruction mnemonic list (Table 9-1, alphabetical, pages 27–36)

Flag columns are given in the order CY, OV, S, Z as printed in Table 9-1.

| Instruction | Operand(s)          | Format | CY  | OV  | S   | Z   | Function (as printed)                                       |
| ----------- | ------------------- | ------ | --- | --- | --- | --- | ----------------------------------------------------------- |
| ADD         | reg1, reg2          | I      | *   | *   | *   | *   | Addition                                                    |
| ADD         | imm5, reg2          | II     | *   | *   | *   | *   | Addition                                                    |
| ADDF.S      | reg1, reg2          | VII    | *   | 0   | *   | *   | Floating-point addition                                     |
| ADDI        | imm16, reg1, reg2   | V      | *   | *   | *   | *   | Addition                                                    |
| AND         | reg1, reg2          | I      | –   | 0   | *   | *   | AND                                                         |
| ANDBSU      | –                   | II     | –   | –   | –   | –   | Transfer after ANDing bit strings                           |
| ANDI        | imm16, reg1, reg2   | V      | –   | 0   | 0   | *   | AND                                                         |
| ANDNBSU     | –                   | II     | –   | –   | –   | –   | Transfer after NOTting a bit string then ANDing it          |
| BC          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Carry)                               |
| BE          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Equal)                               |
| BGE         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Greater than or Equal)               |
| BGT         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Greater than)                        |
| BH          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Higher)                              |
| BL          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Lower)                               |
| BLE         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Less than or Equal)                  |
| BLT         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Less than)                           |
| BN          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Negative)                            |
| BNC         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Carry)                           |
| BNE         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Equal)                           |
| BNH         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Higher)                          |
| BNL         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Lower)                           |
| BNV         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Overflow)                        |
| BNZ         | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Not Zero)                            |
| BP          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Positive)                            |
| BR          | disp9               | III    | –   | –   | –   | –   | Unconditional branch                                        |
| BV          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Overflow)                            |
| BZ          | disp9               | III    | –   | –   | –   | –   | Conditional branch (if Zero)                                |
| CAXI        | disp16 [reg1], reg2 | VI     | *   | *   | *   | *   | Inter-processor synchronization in a multi-processor        |
| CMP         | reg1, reg2          | I      | *   | *   | *   | *   | Comparison                                                  |
| CMP         | imm5, reg2          | II     | *   | *   | *   | *   | Comparison                                                  |
| CMPF.S      | reg1, reg2          | VII    | *   | 0   | *   | *   | Floating-point comparison                                   |
| CVT.SW      | reg1, reg2          | VII    | –   | 0   | *   | *   | Data conversion from floating-point to integer              |
| CVT.WS      | reg1, reg2          | VII    | *   | 0   | *   | *   | Data conversion from integer to floating-point              |
| DIV         | reg1, reg2          | I      | –   | *   | *   | *   | Signed division                                             |
| DIVF.S      | reg1, reg2          | VII    | *   | 0   | *   | *   | Floating-point division                                     |
| DIVU        | reg1, reg2          | I      | –   | 0   | *   | *   | Unsigned division                                           |
| HALT        | –                   | II     | –   | –   | –   | –   | Processor stop                                              |
| IN.B        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Port input                                                  |
| IN.H        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Port input                                                  |
| IN.W        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Port input                                                  |
| JAL         | disp26              | IV     | –   | –   | –   | –   | Jump and link                                               |
| JMP         | [reg1]              | I      | –   | –   | –   | –   | Register-indirect unconditional branch                      |
| JR          | disp26              | IV     | –   | –   | –   | –   | Unconditional branch                                        |
| LD.B        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Byte load                                                   |
| LD.H        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Halfword load                                               |
| LD.W        | disp16 [reg1], reg2 | VI     | –   | –   | –   | –   | Word load                                                   |
| LDSR        | reg2, regID         | II     | *   | *   | *   | *   | Loading system register                                     |
| MOV         | reg1, reg2          | I      | –   | –   | –   | –   | Transferring data                                           |
| MOV         | imm5, reg2          | II     | –   | –   | –   | –   | Transferring data                                           |
| MOVBSU      | –                   | II     | –   | –   | –   | –   | Transferring bit strings                                    |
| MOVEA       | imm16, reg1, reg2   | V      | –   | –   | –   | –   | Addition                                                    |
| MOVHI       | imm16, reg1, reg2   | V      | –   | –   | –   | –   | Addition                                                    |
| MUL         | reg1, reg2          | I      | –   | *   | *   | *   | Signed multiplication                                       |
| MULF.S      | reg1, reg2          | VII    | *   | 0   | *   | *   | Floating-point multiplication                               |
| MULU        | reg1, reg2          | I      | –   | *   | *   | *   | Unsigned multiplication                                     |
| NOP         | –                   | III    | –   | –   | –   | –   | No operation                                                |
| NOT         | reg1, reg2          | I      | –   | 0   | *   | *   | Logical NOT                                                 |
| NOTBSU      | –                   | II     | –   | –   | –   | –   | Transfer after NOTting a bit string                         |
| OR          | reg1, reg2          | I      | –   | 0   | *   | *   | OR                                                          |
| ORBSU       | –                   | II     | –   | –   | –   | –   | Transfer after ORing bit strings                            |
| ORI         | imm16, reg1, reg2   | V      | –   | 0   | *   | *   | OR                                                          |
| ORNBSU      | –                   | II     | –   | –   | –   | –   | Transfer after NOTting a bit string and ORing it            |
| OUT.B       | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Port output                                                 |
| OUT.H       | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Port output                                                 |
| OUT.W       | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Port output                                                 |
| RETI        | –                   | II     | *   | *   | *   | *   | Return from a trap or interrupt routine                     |
| SAR         | reg1, reg2          | I      | *   | 0   | *   | *   | Arithmetic right shift                                      |
| SAR         | imm5, reg2          | II     | *   | 0   | *   | *   | Arithmetic right shift                                      |
| SCH0BSU     | –                   | II     | –   | –   | –   | *   | Searching 0s in a bit string                                |
| SCH0BSD     | –                   | II     | –   | –   | –   | *   | Searches "0" bits in the source bit string, and loads r30 … |
| SCH1BSU     | –                   | II     | –   | –   | –   | –   | Searching 1s in a bit string                                |
| SCH1BSD     | –                   | II     | –   | –   | –   | –   | Searches 1s in the source bit string, and loads r30 and …   |
| SETF        | imm5, reg2          | II     | –   | –   | –   | –   | Flag condition setting                                      |
| SHL         | reg1, reg2          | I      | *   | 0   | *   | *   | Logical left shift                                          |
| SHL         | imm5, reg2          | II     | *   | 0   | *   | *   | Logical left shift                                          |
| SHR         | reg1, reg2          | I      | *   | 0   | *   | *   | Logical right shift                                         |
| SHR         | imm5, reg2          | II     | *   | 0   | *   | *   | Logical right shift                                         |
| ST.B        | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Byte store                                                  |
| ST.H        | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Halfword store                                              |
| ST.W        | reg2, disp16 [reg1] | VI     | –   | –   | –   | –   | Word store                                                  |
| STSR        | regID, reg2         | II     | –   | –   | –   | –   | Storing system register contents                            |
| SUB         | reg1, reg2          | I      | *   | *   | *   | *   | Subtraction                                                 |
| SUBF.S      | reg1, reg2          | VII    | *   | 0   | *   | *   | Floating-point subtraction                                  |
| TRAP        | vector              | II     | –   | –   | –   | –   | Software trap                                               |
| TRNC.SW     | reg1, reg2          | VII    | –   | 0   | *   | *   | Conversion from floating-point data to integer              |
| XOR         | reg1, reg2          | I      | –   | 0   | *   | *   | Exclusive OR                                                |
| XORBSU      | –                   | II     | –   | –   | –   | –   | Transfer of exclusive ORed bit string                       |
| XORI        | imm16, reg1, reg2   | V      | –   | 0   | *   | *   | Exclusive OR                                                |
| XORNBSU     | –                   | II     | –   | –   | –   | –   | Transfer after exclusive-ORing a NOTted bit string          |

[Table 9-1 (1/9) through (9/9)]

- The TRAP entry lists four numbered sub-steps of its operation, of which the text carries: (1) saving the restore PC and PSW into the FEPC …; (2) setting an exception code into the ECR's FECC …; (3) setting the PSW's ID flag and clearing the PSW's …; (4) setting the PSW's NP flag if the PSW's EP flag … [Table 9-1 (9/9)].

### 10.1 Specifications when VDD = +5 V ± 10%, (1) TA = –10 to +70°C

Absolute Maximum Ratings (TA = 25°C):

| Parameter                     | Symbol | Test Conditions  | Rating            | Unit |
| ----------------------------- | ------ | ---------------- | ----------------- | ---- |
| Supply voltage                | VDD    |                  | –0.5 to +7.0      | V    |
| Input voltage                 | VI     | VDD = +5 V ± 10% | –0.5 to VDD + 0.3 | V    |
| Clock Input voltage           | VK     | VDD = +5 V ± 10% | –0.5 to VDD + 0.3 | V    |
| Output voltage                | VO     | VDD = +5 V ± 10% | –0.5 to VDD + 0.3 | V    |
| Operating ambient temperature | TA     |                  | –10 to +70        | °C   |
| Storage temperature           | Tstg   |                  | –65 to +150       | °C   |

[§10.1(1) Absolute Maximum Ratings]

DC Characteristics (TA = –10 to +70°C, VDD = +5V ± 10%):

| Parameter                 | Symbol | Test Conditions         | MIN. | TYP.         | MAX.      | Unit |
| ------------------------- | ------ | ----------------------- | ---- | ------------ | --------- | ---- |
| Clock input voltage, high | VKH    |                         | 4.0  |              | VDD + 0.3 | V    |
| Clock input voltage, low  | VKL    |                         | –0.5 |              | +0.6      | V    |
| Input voltage, high       | VIH    |                         | 2.2  |              | VDD + 0.3 | V    |
| Input voltage, low        | VIL    |                         | –0.5 |              | +0.8      | V    |
| Output voltage, high      | VOH    | IOH = –400 µA           | 2.4  |              |           | V    |
| Output voltage, low       | VOL    | IOL = 3.2 mA            |      |              | 0.45      | V    |
| Input leak current, high  | ILIH   | VIN = VDD               |      |              | 10        | µA   |
| Input leak current, low   | ILIL   | VIN = 0 V               |      |              | –10       | µA   |
| Output leak current, high | ILOH   | VO = VDD                |      |              | 10        | µA   |
| Output leak current, low  | ILOL   | VO = 0 V                |      |              | –10       | µA   |
| Supply current            | IDD    | f = 16 MHz              |      | 64 (Note 2)  | 160       | mA   |
| Supply current            | IDD    | f = 20 MHz              |      | 80 (Note 2)  | 200       | mA   |
| Supply current            | IDD    | f = 25 MHz              |      | 100 (Note 2) | 240       | mA   |
| Supply current            | IDD    | Stopping clock (Note 1) |      | 5            |           | µA   |

Note 1: VIL = 0 V, VIH = VDD applied. Note 2: In general benchmark test (Output pins are open.) [§10.1(1) DC Characteristics].

Capacitance (TA = 25°C, VDD = +5 V ± 10%): Input capacitance CI, fC = 1 MHz, MAX. 15 pF; I/O capacitance CIO, MAX. 15 pF [§10.1(1) Capacitance].

AC Characteristics, Clock Input (TA = –10 to +70°C, VDD = +5V ± 10%), values are MIN. unless the table gives a MAX.:

| Parameter                    | Symbol | µPD70732-16 | µPD70732-20 | µPD70732-25 | Unit |
| ---------------------------- | ------ | ----------- | ----------- | ----------- | ---- |
| Clock cycle                  | tCYK   | 62.5        | 50          | 40          | ns   |
| Clock pulse high-level width | tKKH   | 26          | 21          | 17          | ns   |
| Clock pulse low-level width  | tKKL   | 26          | 21          | 17          | ns   |
| Clock rise time              | tKR    | 5           | 4           | 3           | ns   |
| Clock fall time              | tKF    | 5           | 4           | 3           | ns   |

[§10.1(1) AC Characteristics, Clock Input]

AC Characteristics, Reset:

| Parameter                             | Symbol | µPD70732-16           | µPD70732-20          | µPD70732-25          | Unit |
| ------------------------------------- | ------ | --------------------- | -------------------- | -------------------- | ---- |
| RESET hold time (from VDD VALID)      | tHVR   | MIN. 1000 + 20 tCYKR  | MIN. 1000 + 20 tCYKR | MIN. 1000 + 20 tCYKR | ns   |
| Clock cycle (at reset)                | tCYKR  | MIN. 62.5 / MAX. 1000 | MIN. 50 / MAX. 1000  | MIN. 40 / MAX. 1000  | ns   |
| Clock high-level time (at reset)      | tKKHR  | MIN. 26               | MIN. 21              | MIN. 17              | ns   |
| Clock low-level time (at reset)       | tKKLR  | MIN. 26               | MIN. 21              | MIN. 17              | ns   |
| RESET setup time (to CLK↓, active)    | tSRKF  | MIN. 10               | MIN. 10              | MIN. 10              | ns   |
| RESET setup time (to CLK↓, inactive)  | tSRKR  | MIN. 10               | MIN. 10              | MIN. 10              | ns   |
| RESET hold time (from CLK↓)           | tHKR   | MIN. 10               | MIN. 10              | MIN. 10              | ns   |
| RESET pulse low-level width (to CLK↓) | tWRL   | MIN. 20 tCYKR         | MIN. 20 tCYKR        | MIN. 20 tCYKR        | ns   |

[§10.1(1) AC Characteristics, Reset]

AC Characteristics, Memory/I/O Access (MIN./MAX. pairs per part):

| Parameter                                      | Symbol | µPD70732-16 | µPD70732-20 | µPD70732-25 | Unit |
| ---------------------------------------------- | ------ | ----------- | ----------- | ----------- | ---- |
| Address, etc. output delay time (from CLK)     | tDKA   | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| Address, etc. output hold time (from CLK)      | tHKA   | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| BCYST output delay time (from CLK)             | tDKBC  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| BCYST output hold time (from CLK)              | tHKBC  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| DA output delay time (from CLK)                | tDKDA  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| DA output hold time (from CLK)                 | tHKDA  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| READY setup time (to CLK)                      | tSRYK  | 6 / —       | 5 / —       | 4 / —       | ns   |
| READY hold time (from CLK)                     | tHKRY  | 5 / —       | 5 / —       | 4 / —       | ns   |
| Data setup time (to CLK)                       | tSDK   | 6 / —       | 5 / —       | 4 / —       | ns   |
| Data hold time (from CLK)                      | tHKD   | 5 / —       | 5 / —       | 4 / —       | ns   |
| Data output delay time (from active, from CLK) | tDKDT  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| Data output hold time (to active, from CLK)    | tHKDT  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| Data output delay time (from float, from CLK)  | tLZKDT | 5 / 25      | 5 / 20      | 5 / 20      | ns   |
| Data output hold time (to float, from CLK)     | tHZKDT | 5 / 25      | 5 / 20      | 5 / 20      | ns   |

[§10.1(1) AC Characteristics, Memory, I/O Access]

AC Characteristics, Dynamic Bus Sizing: SZRQ setup time (to CLK) tSSZK MIN. 6 / 5 / 4 ns for -16 / -20 / -25; SZRQ hold time (from CLK) tHKSZ MIN. 5 / 5 / 4 ns [§10.1(1) Dynamic Bus Sizing].

AC Characteristics, Interrupt: NMI setup time (to CLK) tSNK MIN. 6 / 5 / 4 ns; NMI hold time (from CLK) tHKN MIN. 5 / 5 / 4 ns; INT, etc. setup time (to CLK) tSIK MIN. 6 / 5 / 4 ns; INT, etc. hold time (from CLK) tHKI MIN. 5 / 5 / 4 ns, for -16 / -20 / -25 [§10.1(1) Interrupt].

AC Characteristics, Bus Hold (MIN./MAX. per part, -16 / -20 / -25):

| Parameter                                        | Symbol | µPD70732-16 | µPD70732-20 | µPD70732-25 | Unit |
| ------------------------------------------------ | ------ | ----------- | ----------- | ----------- | ---- |
| HLDRQ setup time (to CLK)                        | tSHQK  | 6 / —       | 5 / —       | 4 / —       | ns   |
| HLDRQ hold time (from CLK)                       | tHKHQ  | 5 / —       | 5 / —       | 4 / —       | ns   |
| HLDAK output delay time (from CLK)               | tDKHA  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| HLDAK output hold time (from CLK)                | tHKHA  | 2 / 20      | 2 / 15      | 2 / 15      | ns   |
| Address, etc. delay time (from active, from CLK) | tHZKA  | 2 / 25      | 2 / 20      | 2 / 20      | ns   |
| Address, etc. delay time (from float, from CLK)  | tLZKA  | 2 / 25      | 2 / 20      | 2 / 20      | ns   |
| Data delay time (from active, from CLK)          | tHZKD  | 5 / 25      | 5 / 20      | 5 / 20      | ns   |
| Data delay time (from float, from CLK)           | tLZKD  | 5 / 25      | 5 / 20      | 5 / 20      | ns   |
| BCYST delay time (from active, from CLK)         | tHZKBC | 2 / 25      | 2 / 20      | 2 / 20      | ns   |
| BCYST delay time (from float, from CLK)          | tLZKBC | 2 / 25      | 2 / 20      | 2 / 20      | ns   |
| DA delay time (from active, from CLK)            | tHZKDA | 2 / 25      | 2 / 20      | 2 / 20      | ns   |
| DA delay time (from float, from CLK)             | tLZKDA | 2 / 25      | 2 / 20      | 2 / 20      | ns   |

[§10.1(1) Bus Hold]

- §10.1(1) also carries headings for AC Test Input Waveform (Except CLK), AC Test Input Waveform (CLK), AC Test Output Test Points, and Load Conditions; all four are image references only [§10.1(1)].

### 10.1 Specifications when VDD = +5 V ± 10%, (2) TA = –40 to +85°C

- Absolute Maximum Ratings (TA = 25°C) are identical to §10.1(1) except operating ambient temperature TA = –40 to +85°C; supply voltage VDD –0.5 to +7.0 V; VI, VK, VO each –0.5 to VDD + 0.3 V at VDD = +5 V ± 10%; storage temperature Tstg –65 to +150°C [§10.1(2) Absolute Maximum Ratings].
- DC Characteristics (TA = –40 to +85°C, VDD = +5V ± 10%): VKH MIN. 4.0 / MAX. VDD + 0.3 V; VKL MIN. –0.5 / MAX. +0.6 V; VIH MIN. 2.2 / MAX. VDD + 0.3 V; VIL MIN. –0.5 / MAX. +0.8 V; VOH MIN. 2.4 V at IOH = –400 µA; VOL MAX. 0.45 V at IOL = 3.2 mA; ILIH MAX. 10 µA at VIN = VDD; ILIL MAX. –10 µA at VIN = 0 V; ILOH MAX. 10 µA at VO = VDD; ILOL MAX. –10 µA at VO = 0 V [§10.1(2) DC Characteristics].
- Supply current IDD at f = 20 MHz: TYP. 80 (Note 2), MAX. 200 mA; stopping clock (Note 1): TYP. 5 µA [§10.1(2) DC Characteristics].
- The document remarks that operating supply current is approximately proportional to operating clock frequency [§10.1(2) Remark].
- Capacitance (TA = 25°C, VDD = +5 V ± 10%): CI MAX. 15 pF at fC = 1 MHz; CIO MAX. 15 pF [§10.1(2) Capacitance].
- AC Characteristics for §10.1(2) are given for µPD70732-25 only [§10.1(2) AC Characteristics].
- Clock Input: tCYK MIN. 50 ns; tKKH MIN. 21 ns; tKKL MIN. 21 ns; tKR MAX. 4 ns; tKF MAX. 4 ns [§10.1(2) Clock Input].
- Reset: tHVR MIN. 1000 + 20 tCYKR ns; tCYKR MIN. 50 / MAX. 1000 ns; tKKHR MIN. 21 ns; tKKLR MIN. 21 ns; tSRKF MIN. 10 ns; tSRKR MIN. 10 ns; tHKR MIN. 10 ns; tWRL MIN. 20 tCYKR ns [§10.1(2) Reset].
- Memory/I/O Access: tDKA 1 / 15 ns; tHKA 1 / 15 ns; tDKBC 1 / 15 ns; tHKBC 1 / 15 ns; tDKDA 1 / 15 ns; tHKDA 1 / 15 ns; tSRYK MIN. 5 ns; tHKRY MIN. 5 ns; tSDK MIN. 5 ns; tHKD MIN. 5 ns; tDKDT 1 / 15 ns; tHKDT 1 / 15 ns; tLZKDT 5 / 20 ns; tHZKDT 5 / 20 ns (MIN. / MAX.) [§10.1(2) Memory, I/O Access].
- Dynamic Bus Sizing: tSSZK MIN. 5 ns; tHKSZ MIN. 5 ns [§10.1(2) Dynamic Bus Sizing].
- Interrupt: tSNK MIN. 5 ns; tHKN MIN. 5 ns; tSIK MIN. 5 ns; tHKI MIN. 5 ns [§10.1(2) Interrupt].
- Bus Hold: tSHQK MIN. 5 ns; tHKHQ MIN. 5 ns; tDKHA 1 / 15 ns; tHKHA 1 / 15 ns; tHZKA 2 / 20 ns; tLZKA 2 / 20 ns; tHZKD 5 / 20 ns; tLZKD 5 / 20 ns; tHZKBC 2 / 20 ns; tLZKBC 2 / 20 ns; tHZKDA 2 / 20 ns; tLZKDA 2 / 20 ns (MIN. / MAX.) [§10.1(2) Bus Hold].

### 10.2 Specifications when VDD = 2.7 to 3.6 V (page 47)

- Absolute Maximum Ratings (TA = 25°C): VDD –0.5 to +7.0 V; VI –0.5 to VDD + 0.3 V at VDD = 2.7 to 3.6 V; VK –0.5 to VDD + 0.3 V; VO –0.5 to VDD + 0.3 V; operating ambient temperature TA –40 to +85°C; storage temperature Tstg –65 to +150°C [§10.2 Absolute Maximum Ratings].
- DC Characteristics (TA = –40 to +85°C, VDD = 2.7 to 3.6 V): VKH MIN. 0.8 VDD / MAX. VDD + 0.3 V; VKL MIN. –0.5 / MAX. +0.2 VDD V; VIH MIN. 2.0 / MAX. VDD + 0.3 V; VIL MIN. –0.5 / MAX. +0.6 V [§10.2 DC Characteristics].
- Output voltage, high VOH: MIN. 0.85 VDD at IOH = –2.0 mA; MIN. VDD – 0.2 at IOH = –100 µA [§10.2 DC Characteristics].
- Output voltage, low VOL MAX. 0.4 V at IOL = 3.2 mA [§10.2 DC Characteristics].
- Leak currents: ILIH MAX. 5 µA at VIN = VDD; ILIL MAX. –5 µA at VIN = 0 V; ILOH MAX. 5 µA at VO = VDD; ILOL MAX. –5 µA at VO = 0 V [§10.2 DC Characteristics].
- Supply current IDD at f = 16 MHz: TYP. 38 (Note 2), MAX. 100 mA; stopping clock (Note 1): TYP. 3, MAX. 30 µA [§10.2 DC Characteristics].
- Notes: Note 1 VIL = 0 V, VIH = VDD applied; Note 2 in general benchmark test (output pins are open). The document remarks operating supply current is approximately proportional to operating clock frequency [§10.2 Notes and Remark].
- Capacitance (TA = 25°C, VDD = 2.7 to 3.6 V): CI MAX. 15 pF at fC = 1 MHz; CIO MAX. 15 pF [§10.2 Capacitance].
- AC Characteristics in §10.2 are given for µPD70732-25 only [§10.2 AC Characteristics].
- Clock Input: tCYK MIN. 62.5 ns; tKKH MIN. 26 ns; tKKL MIN. 26 ns; tKR MAX. 5 ns; tKF MAX. 5 ns [§10.2 Clock Input].
- Reset: tHVR MIN. 1000 + 20tCYKR ns; tCYKR MIN. 62.5 / MAX. 1000 ns; tKKHR MIN. 26 ns; tKKLR MIN. 26 ns; tSRKF MIN. 10 ns; tSRKR MIN. 10 ns; tHKR MIN. 10 ns; tWRL MIN. 20tCYKR ns [§10.2 Reset].
- Memory/I/O Access (MIN. / MAX.): tDKA 1 / 25 ns; tHKA 1 / 25 ns; tDKBC 1 / 25 ns; tHKBC 1 / 25 ns; tDKDA 1 / 25 ns; tHKDA 1 / 25 ns; tSRYK MIN. 8 ns; tHKRY MIN. 5 ns; tSDK MIN. 8 ns; tHKD MIN. 5 ns; tDKDT 1 / 35 ns; tHKDT 1 / 35 ns; tLZKDT 3 / 40 ns; tHZKDT 3 / 40 ns [§10.2 Memory, I/O Access].
- Dynamic Bus Sizing: tSSZK MIN. 8 ns; tHKSZ MIN. 5 ns [§10.2 Dynamic Bus Sizing].
- Interrupt: tSNK MIN. 8 ns; tHKN MIN. 5 ns; tSIK MIN. 8 ns; tHKI MIN. 5 ns [§10.2 Interrupt].
- Bus Hold: tSHQK MIN. 8 ns; tHKHQ MIN. 5 ns; tDKHA 1 / 25 ns; tHKHA 1 / 25 ns; tHZKA 3 / 30 ns; tLZKA 3 / 30 ns; tHZKD 3 / 40 ns; tLZKD 3 / 40 ns; tHZKBC 3 / 30 ns; tLZKBC 3 / 30 ns; tHZKDA 3 / 30 ns; tLZKDA 3 / 30 ns (MIN. / MAX.) [§10.2 Bus Hold].

### 10.3 Specifications when VDD = 2.2 to 3.6 V (page 51)

- Absolute Maximum Ratings (TA = 25°C): VDD –0.5 to +7.0 V; VI –0.5 to VDD + 0.3 V at VDD = 2.2 to 3.6 V; VK –0.5 to VDD + 0.3 V; VO –0.5 to VDD + 0.3 V; operating ambient temperature TA –40 to +85°C; storage temperature Tstg –65 to +150°C [§10.3 Absolute Maximum Ratings].
- DC Characteristics (TA = –40 to +85°C, VDD = 2.2 to 3.6 V): VKH MIN. 0.8 VDD / MAX. VDD + 0.3 V; VKL MIN. –0.5 / MAX. +0.2 VDD V [§10.3 DC Characteristics].
- Input voltage high VIH has two rows distinguished by a VDD test condition: MIN. 2.0 / MAX. VDD + 0.3 V for one condition, and MIN. 0.8 VDD / MAX. VDD + 0.3 V for the other; the two test-condition cells are printed as "VDD • 2.5 V" and "VDD - 2.5 V" [§10.3 DC Characteristics].
- Input voltage low VIL MIN. –0.5 / MAX. +0.2 VDD V [§10.3 DC Characteristics].
- Output voltage high VOH: MIN. 0.85 VDD at IOH = –2.0 mA; MIN. VDD – 0.2 at IOH = –100 µA [§10.3 DC Characteristics].
- Output voltage low VOL MAX. 0.4 V at IOL = 3.2 mA [§10.3 DC Characteristics].
- Leak currents: ILIH MAX. 5 µA at VIN = VDD; ILIL MAX. –5 µA at VIN = 0 V; ILOH MAX. 5 µA at VO = VDD; ILOL MAX. –5 µA at VO = 0 V [§10.3 DC Characteristics].
- Supply current IDD at f = 10 MHz: TYP. 24 (Note 2), MAX. 70 mA; stopping clock (Note 1): TYP. 3, MAX. 30 µA [§10.3 DC Characteristics].
- Capacitance (TA = 25°C, VDD = 2.2 to 3.6 V): CI MAX. 15 pF at fC = 1 MHz; CIO MAX. 15 pF [§10.3 Capacitance].
- AC Characteristics in §10.3 are given for µPD70732-25 only [§10.3 AC Characteristics].
- Clock Input: tCYK MIN. 100 ns; tKKH MIN. 40 ns; tKKL MIN. 40 ns; tKR MAX. 10 ns; tKF MAX. 10 ns [§10.3 Clock Input].
- Reset: tHVR MIN. 1000 + 20tCYKR ns; tCYKR MIN. 100 / MAX. 1000 ns; tKKHR MIN. 40 ns; tKKLR MIN. 40 ns; tSRKF MIN. 10 ns; tSRKR MIN. 10 ns; tHKR MIN. 15 ns; tWRL MIN. 20tCYKR ns [§10.3 Reset].
- Memory/I/O Access (MIN. / MAX.): tDKA 1 / 35 ns; tHKA 1 / 35 ns; tDKBC 1 / 35 ns; tHKBC 1 / 35 ns; tDKDA 1 / 35 ns; tHKDA 1 / 35 ns; tSRYK MIN. 15 ns; tHKRY MIN. 5 ns; tSDK MIN. 15 ns; tHKD MIN. 5 ns; tDKDT 1 / 50 ns; tHKDT 1 / 50 ns; tLZKDT 3 / 50 ns; tHZKDT 3 / 50 ns [§10.3 Memory, I/O Access].
- Dynamic Bus Sizing: tSSZK MIN. 15 ns; tHKSZ MIN. 5 ns [§10.3 Dynamic Bus Sizing].
- Interrupt: tSNK MIN. 15 ns; tHKN MIN. 5 ns; tSIK MIN. 15 ns; tHKI MIN. 5 ns [§10.3 Interrupt].
- Bus Hold: tSHQK MIN. 15 ns; tHKHQ MIN. 5 ns; tDKHA 1 / 35 ns; tHKHA 1 / 35 ns; tHZKA 3 / 35 ns; tLZKA 3 / 35 ns; tHZKD 3 / 50 ns; tLZKD 3 / 50 ns; tHZKBC 3 / 35 ns; tLZKBC 3 / 35 ns; tHZKDA 3 / 35 ns; tLZKDA 3 / 35 ns (MIN. / MAX.) [§10.3 Bus Hold].

### Package dimensions

120-pin plastic QFP (28 x 28), package code P120GD-80-LBB, MBB-1:

| ITEM | MILLIMETERS        | INCHES                |
| ---- | ------------------ | --------------------- |
| A    | 32.0±0.3           | 1.260±0.012           |
| B    | 28.0±0.2           | 1.102 +0.009 / –0.008 |
| C    | 28.0±0.2           | 1.102 +0.009 / –0.008 |
| D    | 32.0±0.3           | 1.260±0.012           |
| F    | 2.4                | 0.094                 |
| G    | 2.4                | 0.094                 |
| H    | 0.35±0.10          | 0.014 +0.004 / –0.005 |
| I    | 0.15               | 0.006                 |
| J    | 0.8 (T.P.)         | 0.031 (T.P.)          |
| K    | 2.0±0.2            | 0.079 +0.009 / –0.008 |
| L    | 0.8±0.2            | 0.031 +0.009 / –0.008 |
| M    | 0.15 +0.10 / –0.05 | 0.006 +0.004 / –0.003 |
| N    | 0.1                | 0.004                 |
| P    | 3.2                | 0.126                 |
| Q    | 0.1±0.1            | 0.004±0.004           |
| R    | 5°±5°              | 5°±5°                 |
| S    | 3.5 MAX.           | 0.138 MAX.            |

The QFP drawing carries the note that each lead centerline is located within 0.15 mm (0.006 inch) of its true position (T.P.) at maximum material condition [§11, 120-pin plastic QFP].

120-pin plastic TQFP (Fine pitch) (14 x 14), package code S120GC-40-9EV:

| ITEM | MILLIMETERS | INCHES                |
| ---- | ----------- | --------------------- |
| A    | 16.0±0.2    | 0.630±0.008           |
| B    | 14.0±0.2    | 0.551 +0.009 / –0.008 |
| C    | 14.0±0.2    | 0.551 +0.009 / –0.008 |
| D    | 16.0±0.2    | 0.630±0.008           |
| F    | 1.2         | 0.047                 |
| G    | 1.2         | 0.047                 |
| H    | 0.18±0.05   | 0.007±0.002           |
| I    | 0.09        | 0.004                 |
| J    | 0.4 (T.P.)  | 0.016 (T.P.)          |
| K    | 1.0±0.2     | 0.039 +0.009 / –0.008 |
| L    | 0.5±0.2     | 0.020 +0.008 / –0.009 |
| M    | 0.145±0.05  | 0.006 +0.002 / –0.003 |
| N    | 0.08        | 0.003                 |
| P    | 1.0±0.1     | 0.039 +0.005 / –0.004 |
| Q    | 0.1±0.05    | 0.004±0.002           |
| S    | 1.2 MAX.    | 0.048 MAX.            |

The TQFP drawing carries the note that each lead centerline is located within 0.09 mm (0.004 inch) of its true position (T.P.) at maximum material condition [§11, 120-pin plastic TQFP].

176-pin ceramic PGA (Seamweld): A 38.1±0.4 mm (1.500 +0.016 / –0.015 in); D 38.1±0.4 mm (1.500 +0.016 / –0.015 in); F 2.54 (T.P.) mm; E 1.27 mm (0.050 in); G/H/I/J group printed as 2.8±0.3, 0.5 MIN., 4.57 MAX. mm with inch value 0.110; K 1.2±0.2 φ mm (0.047 in); L 0.46±0.05 φ mm (0.018 in); M 0.5 mm (0.020 in). The drawing note states each lead centerline is located within φ0.5 mm (φ0.020 inch) of its true position (T.P.) at maximum material condition [§11, 176-pin ceramic PGA].

### Soldering conditions

Table 12-1, surface mounting, (1) µPD70732GD-16-LBB / µPD70732GD-20-LBB / µPD70732GD-25-LBB, 120-pin plastic QFP (28 x 28 mm), headed "E specification model only":

| Soldering Method | Soldering Conditions                                                                                                             | Recommended condition symbol                        |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------- |
| Infrared reflow  | Package peak temperature 235°C, duration 30 sec. Max. (at 210°C or above), number of times: Twice Max., time limit 7 days (Note) | IR35-367-2 (thereafter 36 hours prebaking)          |
| VPS              | Package peak temperature 215°C, duration 40 sec. Max. (at 200°C or above), number of times: Twice Max., time limit 7 days (Note) | VP15-367-2 (thereafter 36 hours prebaking)          |
| Wave soldering   | Solder bath temperature 260°C Max., duration 10 sec. Max., number of times: Once, time limit 7 days (Note)                       | WS60-367-1 (thereafter 36 hours prebaking required) |
| Partial heating  | Pin temperature 300°C Max., duration 3 sec. Max. (per device side)                                                               | —                                                   |

[Table 12-1(1)]

Table 12-1, surface mounting, (2) µPD70732GC-25-9EV, 120-pin plastic TQFP (Fine pitch) (14 x 14 mm):

| Soldering Method | Soldering Conditions                                                                                                             | Recommended condition symbol               |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| Infrared reflow  | Package peak temperature 235°C, duration 30 sec. Max. (at 210°C or above), number of times: Twice Max., time limit 7 days (Note) | IR35-107-2 (thereafter 10 hours prebaking) |
| VPS              | Package peak temperature 215°C, duration 40 sec. Max. (at 200°C or above), number of times: Twice Max., time limit 7 days (Note) | VP15-107-2 (thereafter 10 hours prebaking) |
| Partial heating  | Pin temperature 300°C Max., duration 3 sec. Max. (per device side)                                                               | —                                          |

[Table 12-1(2)]

Table 12-2, insertion type, µPD70732R-25, 176-pin ceramic PGA (Seam weld): wave soldering at solder bath temperature 260°C Max., duration 10 sec. Max.; partial heating at pin temperature 300°C Max., duration 3 sec. Max. (per one pin) [Table 12-2].

## Constraints and requirements

- The document states the User's Manuals U10661E and U10082E "should be read before starting design work" [front page].
- Bus interface mode can be switched only at reset, using the SIZ16B signal [§5].
- Bit 0 of the PC is fixed to 0 and execution cannot branch to an odd address [§2.1(2)].
- The bit-string first-word address A must have its lower two bits set to 0 [§3.1.4].
- Word data must be aligned to a word boundary and halfword data to a halfword boundary [§3.2].
- The reserved (unused) instruction field must be set to zeros, and the document instructs not to write a program that uses this field [§9.1].
- Format VII's remaining 10 bits are reserved for future use and must be set to zeros [§9.1(7)].
- System registers 8 to 23 and 26 to 31 are Reserved [Table 2-2].
- The document instructs that special care such as saving and restoring register contents is necessary when using r0, r1 to r5, r26 to r30, and r31 [§2.1(1)].
- Absolute maximum ratings caution 1 states not to directly interconnect IC product output (or input/output) pins, or directly connect VDD or VCC to GND; open-drain and open-collector pins can be interconnected, and direct connection is also possible for an external circuit using timing design that avoids output collision with a pin that becomes high-impedance [§10.1(1), §10.1(2), §10.2, §10.3 Cautions 1].
- Absolute maximum ratings caution 2 states product quality may suffer if the absolute maximum rating is exceeded for even a single parameter or even momentarily, that the product must be used under conditions ensuring the ratings are not exceeded, and that ratings and test conditions in the DC and AC characteristics are the normal operation and quality assurance ranges [§10.1(1), §10.1(2), §10.2, §10.3 Cautions 2].
- The soldering tables carry a caution that use of more than one soldering method should be avoided, except for partial heating [Table 12-1(1), Table 12-1(2)].
- The insertion-type soldering table carries a caution to apply wave soldering only to the pins and to be careful not to bring solder into direct contact with the package [Table 12-2].
- The soldering-condition Note states that for the storage period after dry-pack decapsulation, storage conditions are Max. 25°C, 65% RH [Table 12-1(1) Note, Table 12-1(2) Note].
- The document states customers must check the quality grade of each device before using it in a particular application, and that customers intending to use NEC devices for applications other than those specified for Standard quality grade should contact an NEC sales representative in advance [end matter].
- The document states no part of it may be copied or reproduced in any form or by any means without the prior written consent of NEC Corporation [end matter].

## Stated gaps and ambiguities

- §3.2 states the alignment rule as "word data must be aligned to a word boundary (lowest two bits of the address fixed to 0s), and halfword data to a halfword boundary (lowest bit of the address fixed to 0)", then states that unaligned data has "the lowest one bit (in the case of word) or two bits (in the case of halfword)" forcibly masked with 0s. The masking sentence pairs word with one bit and halfword with two bits, the reverse of the boundary rule in the same section. The document does not reconcile the two statements [§3.2].
- Table 8-1 names the interrupt cause register fields FECC and EICC in the reset-state table, but Table 2-2 names system register 4 only as ECR (exception cause register); the document does not state the relationship between FECC/EICC and ECR in the material given [Table 8-1, Table 2-2].
- Table 6-1 assigns exception code F F 7 0 to FIV but handler address F F F F F F 6 0, unlike the other entries where the code digits and the handler address digits correspond; the document does not comment on this [Table 6-1].
- Table 6-1 lists FUD and FPR with codes and handler addresses, while Note 5 states these two exceptions do not occur in the V810 [Table 6-1, Note 5].
- Section 7 (CACHE) contains only Figure 7-1 as an image; cache size (1 Kbyte) is stated only in the front-page feature list, and no cache line size, associativity, or CHCW field layout is given in the text [§7, front page].
- Figure 4-1 (memory map) and Figure 4-2 (I/O map) are images; the address boundaries of the memory map are not available as text, and the I/O map text carries only FFFFFFFFH, "General use", and 00000000H [§4].
- The pin configuration drawings for the 120-pin QFP and 120-pin TQFP are images; per-pin numbering for those two packages is not available as text, unlike the 176-pin PGA whose pin list is tabulated [Pin Configuration].
- Figure 1-1 (Pin I/O Circuit) is an image; the circuit content of types 1, 4, and 5 is not described in text [§1.2].
- Instruction-format bit-field diagrams for Formats I–VII are images; only the prose field descriptions are available as text [§9.1].
- The Legend for Table 9-1's flag symbols `*`, `0`, and `–` is an image; the document's definition of those symbols is not available as text [§9.2 Legend].
- The "Instruction Function" column of Table 9-1 is truncated for many entries, so the full operation descriptions for instructions such as SAR, SHR, SCH0BSD, SCH1BSD, and TRAP are incomplete [Table 9-1].
- Table 9-1 gives the Z flag as `*` for SCH0BSU and SCH0BSD but as `–` for SCH1BSU and SCH1BSD; the document does not comment on the difference [Table 9-1 (7/9)].
- Table 1-1 leaves the "I/O Circuit Type" cell blank for several pins (HLDRQ, SIZ16B, INT, INTV3 to INTV0, CLK, IC1) and the "Recommended Connection Method" cell blank for A31 to A1 and IC1; the document does not state whether blanks continue the value from the row above [Table 1-1].
- §1.1 marks the "bus idle status at reset" of A31 to A1 with "H Note", but the text of that note is not present [§1.1].
- The AC Test Input Waveform, AC Test Output Test Points, and Load Conditions figures in §10.1(1), §10.1(2), §10.2, and §10.3 are images; the test voltage thresholds and load capacitance values are not available as text [§10.1–§10.3].
- The Clock, Reset, Memory/I/O Access, Dynamic Bus Sizing, Interrupt, and Bus Hold timing waveform diagrams are images; the waveform relationships behind the tabulated symbols are not available as text [§10 timing figures].
- §10.3's VIH test-condition cells are printed as "VDD • 2.5 V" and "VDD - 2.5 V"; the comparison operators are not legible, so which VDD range selects the 2.0 V threshold versus the 0.8 VDD threshold is unclear [§10.3 DC Characteristics].
- §10.1(1) DC Characteristics gives a TYP. value of 5 µA for supply current with the clock stopped but no MAX., while §10.2 and §10.3 give TYP. 3 µA and MAX. 30 µA; the document does not comment on the difference [§10.1(1), §10.2, §10.3].
- The Reset AC tables print "Undefind" for EIPC, FEPC, and r1 to r31 in Table 8-1 (apparent spelling of "Undefined" as it appears in the document) [Table 8-1].
- The front-page feature list runs several features together in single lines (for example "Register/flag hazard interlocked by hardware Dynamic bus sizing function (16 bits) 16-bit bus fixing function"), so the boundaries between individual feature bullets are not clearly delimited [front page, Features].
- The 176-pin ceramic PGA dimension table groups items G, H, I, J into one row with values 2.8±0.3, 0.5 MIN., and 4.57 MAX. millimetres and a single inch value 0.110, so the mapping of each item letter to its value is not determinable from the table [§11, 176-pin ceramic PGA].
- The 120-pin QFP dimension table includes item R (5°±5°) which the TQFP table omits, and the TQFP table omits item R entirely; the document does not comment [§11].
- The document states that related documents indicated in the publication may include preliminary versions and that preliminary versions are not marked as such [end matter].
- Section 10's supported-specifications matrix uses a mark/dash convention whose mark glyph is not present in the table cells for the "with electrical specifications" rows; the parenthesised frequencies are present but the presence marks are not [§10 Supported Electrical Specifications, Remarks 1].
