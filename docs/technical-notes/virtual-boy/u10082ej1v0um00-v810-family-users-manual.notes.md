# Notes: V810 FAMILY 32-BIT MICROPROCESSOR, ARCHITECTURE volume

## Source

- File: `U10082EJ1V0UM00.md`
- Type: reference / architecture user's manual (CPU architecture specification)
- Extent: ~31,000 words. Body paginated 1–143 (Chapters 1–9 plus Appendices A–C)
- Version or date stated in document: not stated (document number `U10082EJ1V0UM00` appears in the filename only. The document text itself does not state a revision or date)
- Author or publisher stated in document: NEC Corporation. V805, V810, V820, V821, V830, V851, V810 family, V850 family, and V800 series are stated to be trademarks of NEC Corporation. [front matter]

## Scope

The document states its purpose as introducing the architecture of the NEC V810 family of 32-bit RISC microprocessors (the cover names the V805, V810, V820, V821). Its chapters cover the register set, data types, address space, instruction formats and instruction set, interrupt and exception, cache dump/restore functions, the debug support function, and reset. [INTRODUCTION; CONTENTS]

The document explicitly excludes hardware details and electrical specifications: it directs readers to "USER'S MANUAL–HARDWARE" of each device for hardware functions and to the data sheet of each device for electrical specifications. [INTRODUCTION, "How to read this manual"]

The document states that the V810 family User's Manuals consist of hardware and architecture versions for each device, and that this manual is the architecture version. [INTRODUCTION, "Organization"]

## Key concepts

- **Halfword.** Data consisting of 2 bytes. [INTRODUCTION; CHAPTER 4]
- **Word.** Data consisting of 4 bytes. [INTRODUCTION; CHAPTER 4]
- **Program register set.** The register set "generally used by the programmer", comprising r0–r31 and PC. [§2, §2.1]
- **System register set.** The register set "usually used by the OS (operating system)", which controls processor status, holds exception/interrupt information, and manages tasks. [§2, §2.2]
- **Duplexed exception.** An exception that occurs when PSW.EP = 1. [§2.2.2]
- **Fatal exception (MACHINE FAULT).** The condition entered when an exception-causing event occurs while PSW.NP = 1. [§5.3 TRAP p.99; §6.1]
- **Restore PC.** The PC value saved to EIPC or FEPC for a given exception or interrupt. Table 6-1 states per-source whether it is the current PC or the next PC. [Table 6-1, p.117]
- **Bit string.** Variable-length data, 0 to 2^32–1 bits, described by a first word address, an in-word bit offset, and a bit length. [§3.1.4]
- **Upward and downward** (bit string)**.** Upward is the direction in which the address increases. Downward is the direction in which the address decreases. [§3.1.4]
- **Interrupt compared with exception.** Interrupts take place independently of program execution (maskable interrupts and one non-maskable interrupt). An exception takes place depending upon program execution. The document states there is little difference in flow, "but the interrupt takes precedence over the exception". [CHAPTER 6, p.117]

## Content

### Front matter and conventions

- Numeric representation convention: binary is written `xxxx` or `xxxxB`. Decimal `xxxx`. Hexadecimal `xxxxH`. [INTRODUCTION, "Legend"]
- Data significance convention: higher on left, lower on right. Memory map addresses: top = high, bottom = low. Active low is marked by a top bar over pin and signal names. [INTRODUCTION, "Legend"]
- Exponent suffixes: K = 2^10 = 1024, M = 2^20 = 1024^2, G = 2^30 = 1024^3. [INTRODUCTION, "Related documents"]
- Related-document table lists: V805 Data Sheet ID-3292, V805 User's Manual IEU-1371, V810 Data Sheet ID-3293, V810 User's Manual IEU-1370, V805/V810 User's Manual Hardware "To be published", V820 Data Sheet ID-3301, V820 User's Manual IEU-852, V821 User's Manual Hardware U10077J, CA732 C compiler package manuals EEU-952 / EEU-966 / EEU-953. Asterisked numbers are stated to be Japanese-version document numbers. [INTRODUCTION, related documents table]
- Front matter includes three CMOS handling notes: precaution against ESD, handling of unused input pins (unused CMOS inputs must be fixed high or low via pull-up or pull-down, or tied to VDD or GND through a resistor), and status before initialization (power-on does not define initial MOS device status. Reset must be executed immediately after power-on for devices having a reset function). [NOTES FOR CMOS DEVICES 1–3]
- NEC quality grades are stated as "Standard", "Special", and "Specific", with V810-family devices being "Standard" unless otherwise specified. Anti-radioactive design is stated as not implemented in this product. [front matter]

### CHAPTER 1 OVERVIEW (p.1)

- The V810 family is described as NEC's RISC microprocessors using the V810 as the CPU core, designed for embedded control applications. [CHAPTER 1, p.1]
- Stated features: 1K-byte cache memory. Pipeline structure of 1 clock pitch. 16-bit instructions (with some exceptions). Separate 32-bit address/data buses. 32 general-purpose 32-bit registers. 4G-byte linear address space. Register/flag hazard interlocked by hardware. [§1.1, p.2]
- Stated instruction features: floating-point operation instructions based upon IEEE754 data format. Bit string instructions. [§1.1, p.2]
- Stated interrupt feature: 16 levels of high-speed interrupt responses. [§1.1, p.2]
- The V810 family is stated to be one of the V800 series. The V850 family is described as a single-chip microprocessor for control purposes, and the V810 family as a microprocessor for data processing purposes. The V830 family is described as an advanced high-speed version. [§1.2, p.3]

### CHAPTER 2 REGISTER SET (p.5)

- All registers are 32 bits wide. [CHAPTER 2, p.5]
- Thirty-two general-purpose registers r0 to r31 are available. All can be used as data registers or address registers, but r0 and r26 to r31 are implicitly used by instructions. [§2.1.1, p.6]
- r0 is the zero register and always holds 0. [§2.1.1, p.6]
- r1 is the assembler-reserved register: a working register for creating 32-bit immediates, implicitly used when the assembler calculates an effective address. [§2.1.1(2), p.6]
- r2 is the handler stack pointer (hp), reserved as the stack pointer of the handler. [§2.1.1(2), p.6; Fig. 2-1]
- r3 is the stack pointer (sp), reserved for stack frame creation when a function is called. [§2.1.1(2), p.6; Fig. 2-1]
- r4 is the global pointer (gp), used to access a global variable in the data area. [§2.1.1(2), p.6; Fig. 2-1]
- r5 is the text pointer (tp), pointing to the beginning of the text area. [§2.1.1(2), p.6; Fig. 2-1]
- r26 is the string destination start bit offset. Bits 31 through 5 are automatically cleared before the instruction executes. On interrupt it stores the offset value in the resume word. [§2.1.1(1), p.6]
- r27 is the string source start bit offset. Bits 31 through 5 are automatically cleared before the instruction executes. On interrupt it stores the offset value in the resume word. [§2.1.1(1), p.6]
- r28 is the string length register, storing the number of bits for string processing. If the instruction is aborted by an interrupt it holds the remaining length. [§2.1.1(1), p.6]
- r29 is the string destination start address register. Bits 1 and 0 are automatically cleared to 0 before execution. On abort it holds the resume start word address. For a search instruction, r29 holds the sum of the number of bits skipped, and on abort the number of bits skipped before the abort. [§2.1.1(1), p.6]
- r30 is the string start (source) address register. Bits 1 and 0 are automatically cleared before execution. On abort it holds the resume word address. r30 additionally holds the value to be set to the lock word for CAXI, the higher 32 bits of the multiplication result for MUL/MULU, and the remainder for DIV/DIVU. [§2.1.1(1), p.7]
- r31 is the link pointer (lp) and implicitly stores the return destination address of the JAL instruction. [§2.1.1(1), p.7; Fig. 2-1]
- Software-reserved registers (r1–r5) are implicitly used by the assembler and compiler. The document directs that their contents be saved and restored when used as variable registers, and refers to the assembler/compiler manual for details. [§2.1.1(2), p.6]
- The program counter (PC) indicates the address of the instruction currently executed. Bit 0 of the PC is fixed to 0 and execution cannot branch to an odd address. PC is initialized to FFFFFFF0H at reset. [§2.1.2, p.7]

#### System registers (§2.2, p.8)

- EIPC saves the current PC and EIPSW saves the current PSW when an exception or interrupt occurs. Only one set each exists, so the document states these registers must be saved by program if multiplexed exception or interrupt is enabled. [§2.2.1, p.8]
- Bit 0 of EIPC and bits 31 through 20, 11, and 10 of EIPSW are fixed to 0. [§2.2.1, p.8]
- PC and PSW are saved to FEPC and FEPSW instead of EIPC/EIPSW if an exception occurs while PSW.EP is set (duplexed or fatal exception), or when NMI occurs. [§2.2.1, p.8]
- Bit 0 of FEPC and bits 31 through 20, 11, and 10 of FEPSW are fixed to 0. [§2.2.2, p.8]
- ECR (exception source register) holds the source of an exception, maskable interrupt, or NMI. ECR is read-only. Data cannot be written to it with LDSR. [§2.2.3, p.9]
- ECR field layout: bits 31-16 = FECC, "Exception code in case of NMI/duplexed exception". Bits 15-0 = EICC, "Exception code in case of interrupt/exception". [§2.2.3, p.9]
- PSW is a collection of flags indicating program status (result of instruction execution) and processor status. A field changed by LDSR becomes valid immediately after the LDSR completes. [§2.2.4, p.9]
- PSW bit 31-20 = RFU, reserved field fixed to 0. [§2.2.4, p.9]
- PSW bits 19-16 = I3-I0, Interrupt Level, the maskable interrupt enable level. [§2.2.4, p.9]
- PSW bit 15 = NP (NMI Pending): set when NMI is accepted. NMI is masked and multiplexed interrupt is disabled. NP = 0 means NMI processing is not in progress. NP = 1 means it is. [§2.2.4, p.9]
- PSW bit 14 = EP (Exception Pending): set when an exceptional event occurs, and masks interrupt. EP = 0 means exception/trap/interrupt processing is not in progress. EP = 1 means it is. [§2.2.4, p.9]
- PSW bit 13 = AE (Address Trap Enable): AE = 0 address trap function is not active. AE = 1 it is active. [§2.2.4, p.9]
- PSW bit 12 = ID (Interrupt Disable): ID = 0 interrupt is enabled. ID = 1 interrupt is disabled. [§2.2.4, p.9]
- PSW bits 11, 10 = RFU, reserved field fixed to 0. [§2.2.4, p.9]
- PSW bit 9 = FRO (Floating Reserved Operand): 1 if a reserved operand exception occurs during floating-point operation. [§2.2.4, p.10]
- PSW bit 8 = FIV (Floating Invalid): 1 if invalid operation occurs during floating-point operation. [§2.2.4, p.10]
- PSW bit 7 = FZD (Floating Zero Divide): 1 if zero division occurs during floating-point operation. [§2.2.4, p.10]
- PSW bit 6 = FOV (Floating OverFlow): 1 if overflow occurs. [§2.2.4, p.10]
- PSW bit 5 = FUD (Floating UnderFlow): 1 if underflow occurs. [§2.2.4, p.10]
- PSW bit 4 = FPR (Floating Precision): FPR = 0 precision does not degrade. FPR = 1 precision degrades. [§2.2.4, p.11]
- PSW bit 3 = CY (Carry): CY = 1 carry is generated. [§2.2.4, p.11]
- PSW bit 2 = OV (Overflow): OV = 1 overflow occurs. [§2.2.4, p.11]
- PSW bit 1 = S (Sign): S = 0 result of operation is positive or zero. S = 1 result of operation is negative. [§2.2.4, p.11]
- PSW bit 0 = Z (Zero): Z = 1 result of operation is zero. [§2.2.4, p.11]
- PIR (processor ID register) identifies the CPU type number of the V810 family and is stated to be "0000810XH" in each device. No data can be written to PIR with LDSR. [§2.2.5, p.12]
- PIR fields: bits 31-16 = RFU (fixed to 0). Bits 15-4 = PT (Processor Type, field indicating type number of CPU). Bits 3-0 = NECRV (NEC reserved). [§2.2.5, p.12]
- TKCW (task control word) controls floating-point operations, is read-only, cannot be written with LDSR, and the document states it is "currently fixed", provided for future interchangeability. [§2.2.6, p.13]
- TKCW fields. [§2.2.6, p.13]

  | Bits      | Field | Name                                                 |
  | --------- | ----- | ---------------------------------------------------- |
  | bits 31-9 | RFU   | fixed to 0                                           |
  | Bit 8     | OTM   | Operand Trap Mask                                    |
  | Bit 7     | FIT   | Floating Invalid Operation Trap Enable               |
  | Bit 6     | FZT   | Floating-Zero Divide Trap Enable                     |
  | Bit 5     | FVT   | Floating-Overflow Trap Enable                        |
  | Bit 4     | FUT   | Floating-Underflow Trap Enable                       |
  | Bit 3     | FPT   | Floating-Precision Trap Enable                       |
  | Bit 2     | RDI   | Floating Rounding Control Bit for Integer Conversion |
  | Bits 1, 0 | RD    | Floating Rounding Control                            |

- CHCW (cache control word) controls the internal instruction cache, described as 128 entries × 8 bytes = 1K bytes. Cache memory becomes valid when an instruction next to the LDSR instruction has been fetched. ICR, ICD, ICE, and ICC must be exclusively set to 1. [§2.2.7, p.14]
- CHCW fields. [§2.2.7, p.14]

  | Bits       | Field | Name                      |
  | ---------- | ----- | ------------------------- |
  | bits 31-8  | SA    | Spill-Out Base Address    |
  | Bits 31-20 | CEN   | Clear Entry Number        |
  | Bits 19-8  | CEC   | Clear Entry Count         |
  | Bits 7, 6  | RFU   | fixed to 0                |
  | Bit 5      | ICR   | Instruction Cache Restore |
  | Bit 4      | ICD   | Instruction Cache Dump    |
  | Bits 3, 2  | RFU   | fixed to 0                |
  | Bit 1      | ICE   | Instruction Cache Enable  |
  | Bit 0      | ICC   | Instruction Cache Clear   |

- ICR, ICD, and ICC each start their operation when set to 1 and always read back as 0. ICE = 1 enables the instruction cache, ICE = 0 disables it (contents are saved). [§2.2.7, p.14]
- CHCW Note 1: an interrupt occurring during restore/dump/clear is internally held and accepted after the operation finishes. The maskable interrupt is held internally only when the EP, NP, and ID flags of PSW are all 0. [§2.2.7 Note 1, p.14]
- CHCW Note 2: to make the cache active, make the ICHEEN signal active and set the ICE bit of the cache control word. [§2.2.7 Note 2, p.14]
- ADTRE is a 32-bit register holding a trap address (TA) used to detect address coincidence with the PC and generate an address trap. Bit 0 of ADTRE is fixed to 0. [§2.2.8, p.15]

#### System register numbers (§2.2.9, p.15)

| Number | Register                                    | LDSR     | STSR    |
| ------ | ------------------------------------------- | -------- | ------- |
| 0      | EIPC (Exception/Interrupt PC)               | enabled  | enabled |
| 1      | EIPSW (Exception/Interrupt PSW)             | enabled  | enabled |
| 2      | FEPC (Fatal Error PC)                       | enabled  | enabled |
| 3      | FEPSW (Fatal Error PSW)                     | enabled  | enabled |
| 4      | ECR (Exception Cause Register)              | disabled | enabled |
| 5      | PSW (Program Status Word)                   | enabled  | enabled |
| 6      | PIR (Processor ID Register)                 | disabled | enabled |
| 7      | TKCW (TasK Control Word)                    | disabled | enabled |
| 8–23   | Reserved                                    |          |         |
| 24     | CHCW (CacHe Control Word)                   | enabled  | enabled |
| 25     | ADTRE (ADdress Trap Register for Execution) | enabled  | enabled |
| 26–31  | Reserved                                    |          |         |

[§2.2.9, p.15]
- The table legend states "●" means access enabled (cannot be set in some cases) and that operation is not guaranteed if a Reserved register is accessed. [§2.2.9, p.15]

### CHAPTER 3 DATA TYPES (p.17)

- Supported data types: integer (8, 16, 32 bits). Unsigned integer (8, 16, 32 bits). Bit string. Single-precision floating-point data (32 bits). [§3.1, p.17]
- Addressing of the V810 family is little endian. [§3.1.1, p.18]
- A byte is contiguous 8-bit data starting from any byte boundary. Bits are numbered 0 (LSB) to 7 (MSB). Specified by its address A. [§3.1.1(1), p.18]
- A halfword is contiguous 2-byte (16-bit) data starting from any halfword boundary. Bits 0 (LSB) to 15 (MSB). Specified by address A with lowest bit 0, occupying A and A+1. [§3.1.1(2), p.18]
- A word/short real is contiguous 4-byte (32-bit) data starting from any word boundary. Bits 0 (LSB) to 31 (MSB). Specified by address A with lower 2 bits 0, occupying A, A+1, A+2, A+3. [§3.1.1(3), p.18]
- Integers are 2's complement binary. Ranges: byte 8 bits –128 to +127. Halfword 16 bits –32768 to +32767. Word 32 bits –2147483648 to +2147483647. [§3.1.2, p.19]
- Unsigned integer ranges: byte 8 bits 0 to 255. Halfword 16 bits 0 to 65535. Word 32 bits 0 to 4294967295. No sign bit exists. [§3.1.3, p.19]
- Bit string length is variable from 0 to 2^32–1 and is specified by three attributes: first word address A (lower 2 bits are 0), bit offset B in word (0 to 31), and bit length M (0 to 2^32–1). [§3.1.4, p.19]
- Bit string attribute table: for upward manipulation the first word address is A, in-word bit offset B, length M. For downward manipulation the first word address is A + 4, in-word bit offset D, length M. [§3.1.4, p.19]
- Single-precision floating-point data is 32 bits conforming to the IEEE single format: 1 mantissa sign bit, 8 exponent bits (offset representation from bias value –127), and 23 mantissa bits (binary representation with integer omitted). [§3.1.5, p.20]
- Field layout diagram shows sign bit s, exponent bits 30..23 (8 bits), mantissa bits 22..0 (23 bits). [§3.1.5 figure, p.20]
- Word data must be aligned at the word boundary (lower 2 address bits 0) and halfword data at the halfword boundary (lower 1 address bit 0). Unless aligned, the low bits are automatically masked to 0 for access, 2 bits for word data and 1 bit for halfword data. [§3.2, p.20]

### CHAPTER 4 ADDRESS SPACE (p.21)

- 4G bytes of linear memory space and I/O space are supported. The CPU outputs 32-bit addresses to memory and I/Os, so addresses run from 0 to 2^32–1. [CHAPTER 4, p.21]
- Bit 0 of each byte is the LSB and bit 7 the MSB. Unless otherwise specified the byte at the lower address is the LSB and the byte at the higher address the MSB (little endian). [CHAPTER 4, p.21]
- Fig. 4-1 Memory Map (p.22) and Fig. 4-2 I/O Map (p.23) are reproduced as images only. Their contents are not transcribed in the source file. Fig. 4-1 carries a note directing the reader to Table 6-1 Exception Codes. [§4.1, pp.22–23]
- Two kinds of address are generated: the instruction address (used by branching instructions) and the operand address (used by data-accessing instructions). [§4.2, p.24]
- The instruction address is determined by the PC contents and is automatically incremented (+2) according to the byte number of the instruction fetched. [§4.2.1, p.24]
- Relative addressing (PC relative): 9- or 26-bit displacement encoded with instruction signs is added to the PC. The displacement is 2's complement data with bit 8 and bit 25 as sign bits. Used by Bcond disp9, JR disp26, and JAL disp26. [§4.2.1(1), pp.24–25]
- Register addressing (register indirect): transfers the contents of the general register (r0 to r31) specified by the instruction to the PC. Used by JMP [reg1]. [§4.2.1(2), p.26]
- Operand register addressing accesses general registers specified by the general register specification field. Used by instructions with operand formats reg1 or reg2. [§4.2.2(1), p.27]
- Immediate addressing contains 5-bit and 16-bit data in the instruction codes. Used by instructions with operand formats imm5 or imm16. [§4.2.2(2), p.27]
- Based addressing adds the contents of the general register specified by the addressing specification code to a 16-bit displacement to form the operand address. Used by instructions with operand format disp16 [reg1]. [§4.2.2(3), p.27]

### CHAPTER 5 INSTRUCTION FORMAT AND INSTRUCTION SET (p.29)

#### 5.1 Instruction Format (p.29)

- Two instruction sizes exist: 16-bit and 32-bit. 16-bit instructions are binary operation, control, and branch instructions. 32-bit instructions are load/store, I/O manipulation, 16-bit immediate, jump and link, and extended instructions. [§5.1, p.29]
- Some instructions have an unused field reserved for future expansion, which must be fixed to 0. [§5.1, p.29]
- Instruction storage order in memory: the lower part of each instruction (including bit 0) goes to the lower address side. The higher part (including bit 15 or 32) goes to the higher address side. [§5.1, p.29]
- Format I (reg-reg): 16-bit. 6-bit op code field and two general-purpose register specification fields. Bit layout used throughout §5.3 is op code in bits 15-10, reg2 in bits 9-5, reg1 in bits 4-0. [§5.1(1), p.29; §5.3 op code diagrams]
- Format II (imm-reg): 16-bit. 6-bit op code field, a 5-bit immediate field, and a general-purpose register specification field. Layout: op code bits 15-10, reg2 bits 9-5, imm5 bits 4-0. [§5.1(2), p.29; §5.3 op code diagrams]
- Format III (conditional branch): 16-bit. 3-bit op code field, 4-bit condition code, and 9-bit branch displacement field whose least significant bit is 0. [§5.1(3), p.29]
- Format IV (middle-distance jump): 32-bit branch instruction with a 6-bit op code field and a 26-bit displacement whose least significant bit is 0. [§5.1(4), p.30]
- Format V (3-operand): 32-bit. 6-bit op code field, two general-purpose register specification fields, and a 16-bit immediate field (imm16 in bits 31-16). [§5.1(5), p.30; §5.3 op code diagrams]
- Format VI (load/store): 32-bit. 6-bit op code field, two general-purpose register specification fields, and a 16-bit displacement (disp16 in bits 31-16). [§5.1(6), p.30; §5.3 op code diagrams]
- Format VII (extended): 32-bit. 6-bit op code field, two general-purpose register specification fields, and a 6-bit sub-op code field. Layout in §5.3: op code 111110 in bits 15-10, reg2 bits 9-5, reg1 bits 4-0, sub-op code bits 31-26, RFU bits 25-16. [§5.1(7), p.30; §5.3 op code diagrams]

#### 5.2 Instruction Outline (pp.31–38)

- Load/store instructions (Table 5-1, p.31): LD.B Load Byte, LD.H Load Halfword, LD.W Load Word, ST.B Store Byte, ST.H Store Halfword, ST.W Store Word. The document states load/store instructions "transfer data from the memory to the register". [§5.2(1), p.31]
- Integer arithmetic operation instructions (Table 5-2, p.32): MOV Move, MOVHI Add, ADD Add, ADDI Add, MOVEA Add, SUB Subtract, MUL Multiply, MULU Multiply Unsigned, DIV Divide, DIVU Divide Unsigned, CMP Compare, SETF Set Flag Condition. [§5.2(2), p.32]
- Logical operation instructions (Table 5-3, p.33): OR, ORI, AND, ANDI, XOR Exclusive-OR, XORI Exclusive-OR, NOT, SHL Shift Logical Left, SHR Shift Logical Right, SAR Shift Arithmetic Right. Several bits can be shifted in one clock using the barrel shifter. [§5.2(3), p.33]
- I/O instructions (Table 5-4, p.34): IN.B Input Byte, IN.H Input Halfword, IN.W Input Word, OUT.B Output Byte, OUT.H Output Halfword, OUT.W Output Word. [§5.2(4), p.34]
- Program control instructions (Table 5-5, p.35): JMP Jump, JR Jump Relative, JAL Jump and Link, BGT, BGE, BLT, BLE, BH Branch on Higher, BNH, BL Branch on Lower, BNL, BE Branch on Equal, BNE, BV Branch on Overflow, BNV, BN Branch on Negative, BP Branch on Positive, BC Branch on Carry, BNC, BZ Branch on Zero, BNZ, BR Branch Always, NOP No Branch (No Operation). [§5.2(5), p.35]
- Bit string instructions (Table 5-6, p.36): SCH0BSU, SCH0BSD, SCH1BSU, SCH1BSD, MOVBSU, NOTBSU, ANDBSU, ANDNBSU, ORBSU, ORNBSU, XORBSU, XORNBSU. These perform bit search, transfer, and logical operation transfer for any bit length in the memory space. [§5.2(6), p.36]
- Floating-point operation instructions (Table 5-7, p.37): CMPF.S Compare Floating Short, CVT.WS Convert Word Integer to Short Floating, CVT.SW Convert Short Floating to Word Integer, ADDF.S, SUBF.S, MULF.S, DIVF.S, TRNC.SW Truncate Short Floating to Word Integer. [§5.2(7), p.37]
- Special instructions (Table 5-8, p.38): LDSR Load System Register, STSR Store System Register, TRAP Trap, RETI Return from Trap or Interrupt, CAXI Compare and Exchange Interlocked, HALT Halt. [§5.2(8), p.38]

#### 5.3 Instruction Set: description conventions (p.39)

- Operand symbols. [§5.3, p.39]

  | Symbol       | Meaning                                                        |
  | ------------ | -------------------------------------------------------------- |
  | `reg1`       | general-purpose register (used as source register)             |
  | `reg2`       | general-purpose register (mainly used as destination register) |
  | `imm5`       | 5-bit immediate                                                |
  | `imm16`      | 16-bit immediate                                               |
  | `disp9`      | 9-bit displacement                                             |
  | `disp16`     | 16-bit displacement                                            |
  | `disp26`     | 26-bit displacement                                            |
  | `regID`      | system register number                                         |
  | `vector adr` | trap handler address corresponding to vector                   |

- Operation symbols. [§5.3, p.39]

  | Symbol                   | Meaning                                                      |
  | ------------------------ | ------------------------------------------------------------ |
  | `<-`                     | substitution                                                 |
  | `\|\|`                   | bit connection                                               |
  | `GR [x]`                 | general-purpose register x                                   |
  | `SR [x]`                 | system register x                                            |
  | `sign-extend (x)`        | extends sign of x to word length                             |
  | `zero-extend(x)`         | zero-extends x to word length                                |
  | `converted (x)`          | converts type of x with rounding direction depending on TKCW |
  | `truncate (x)`           | converts type of x with rounding direction 0                 |
  | `Load-Memory (x, y)`     | reads data of size y from address x                          |
  | `Store-Memory (x, y, z)` | writes data y of size z to address x                         |
  | `Input-Port (x, y)`      | reads data of size y from port address x                     |
  | `Output-Port (x, y, z)`  | writes data y of size z to port address x                    |
  | `adr`                    | 32-bit unsigned address                                      |

- Flag notation: `–` not affected, `0` affected to 0, `1` affected to 1. Floating-point instructions additionally show FRO, FIV, FZD, FOV, FUD, FPR. [§5.3, p.39]
- Each entry carries the headings: Instruction format, Operation, Format, Op code, Flag, Instruction, Remarks, Supplement, Exception, Note. [§5.3, p.39]

#### 5.3 Instruction Set: per-instruction entries

- **ADD.** `ADD reg1, reg2` (Format I, op code 000001) and `ADD imm5, reg2` (Format II, op code 010001). Operation: `GR[reg2] <- GR[reg2] + GR[reg1]`. `GR[reg2] <- GR[reg2] + sign-extend(imm5)`. Flags: CY = 1 if carry occurs from MSB. OV = 1 if Integer-Overflow occurs. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.41]
- **ADDF.S.** `ADDF.S reg1, reg2`, Format VII, op code 111110 with sub-op code 000100. Operation `GR[reg2] <- GR[reg2] + GR[reg1]`. Flags: CY = 1 if GR[reg2] negative. OV = 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 if operand is denormal number, non-number (NaN), or indefinite. FIV, FZD not affected. FOV = 1 if result exceeds maximum normalized number. FUD = 1 if result is less than minimum (absolute value) normalized number. FPR = 1 if degradation in precision is detected. S has the same value as CY. Exceptions: floating-point reserved operand exception, floating-point overflow exception. [§5.3, pp.42–43]
- ADDF.S: if the two operands are equal in absolute value but different in sign, the sign of the zero result depends on the rounding mode, and because the V810 family rounding mode is "Toward nearest" the result is "positive zero". [§5.3 ADDF.S, p.42]
- ADDF.S underflow behaviour: FUD is set but no trap occurs and zero is stored to reg2. FPR set on rounding degradation does not trap. The rounded result is stored to reg2. [§5.3 ADDF.S Note, p.43]
- **ADDI.** `ADDI imm16, reg1, reg2`, Format V, op code 101001. Operation `GR[reg2] <- GR[reg1] + sign-extend(imm16)`. Flags: CY carry from MSB. OV integer overflow. S negative. Z zero. reg1 is not affected. [§5.3, p.44]
- **AND.** `AND reg1, reg2`, Format I, op code 001101. Operation `GR[reg2] <- GR[reg2] AND GR[reg1]`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.45]
- **ANDBSU.** `ANDBSU`, Format II, op code 011111 with sub-field 01001 (bits 4-0). Operation `destination <- destination AND source`. All of CY, OV, S, Z unaffected. Uses r30 (source word address), r27 (source bit offset), r28 (string length), r29 (destination word address), r26 (destination bit offset). Transfer runs from lower toward higher address. [§5.3, p.46]
- **ANDI.** `ANDI imm16, reg1, reg2`, Format V, op code 101101. Operation `GR[reg2] <- GR[reg1] AND zero-extend(imm16)`. Flags: CY –. OV 0. S 0. Z = 1 if GR[reg2] is 0. [§5.3, p.47]
- **ANDNBSU.** `ANDNBSU`, Format II, op code 011111 with sub-field 01101. Operation `destination <- destination AND (NOT source)`. Flags unaffected. Same r26–r30 register usage as ANDBSU. [§5.3, p.48]
- **Bcond.** `Bcond disp9`, Format III, op code `100$$$$` in bits 15-9 with disp9 in bits 8-0 (bit 0 is 0). The `$$$$` field is the condition (Table 5-9). Operation: if condition satisfied then `PC <- PC + (sign-extend) disp9`. Flags unaffected. Bit 0 of the 9-bit displacement is masked with 0. The PC used in the calculation is the address of the first byte of the Bcond instruction itself, so a displacement of 0 branches to the instruction itself. [§5.3, pp.49–50]
- **Table 5-9 Conditional Branch Instructions** (p.50):

  | Mnemonic | Condition code | Condition               | Note                |
  | -------- | -------------- | ----------------------- | ------------------- |
  | BGT      | 1111           | `((S xor OV) or Z) = 0` | greater than signed |
  | BGE      | 1110           | `(S xor OV) = 0`        |                     |
  | BLT      | 0110           | `(S xor OV) = 1`        |                     |
  | BLE      | 0111           | `((S xor OV) or Z) = 1` |                     |
  | BH       | 1011           | `(CY or Z) = 0`         |                     |
  | BNL      | 1001           | `CY = 0`                |                     |
  | BL       | 0001           | `CY = 1`                |                     |
  | BNH      | 0011           | `(CY or Z) = 1`         |                     |
  | BE       | 0010           | `Z = 1`                 |                     |
  | BNE      | 1010           | `Z = 0`                 |                     |
  | BV       | 0000           | `OV = 1`                |                     |
  | BNV      | 1000           | `OV = 0`                |                     |
  | BN       | 0100           | `S = 1`                 |                     |
  | BP       | 1100           | `S = 0`                 |                     |
  | BC       | 0001           | `CY = 1`                |                     |
  | BNC      | 1001           | `CY = 0`                |                     |
  | BZ       | 0010           | `Z = 1`                 |                     |
  | BNZ      | 1010           | `Z = 0`                 |                     |
  | BR       | 0101           | always                  | unconditional       |
  | NOP      | 1101           | not always              | does not branch     |

  [Table 5-9, p.50]
- **CAXI.** `CAXI disp16 [reg1], reg2`, Format VI, op code 111010. Operation: locked. `adr <- GR[reg1] + (sign-extend) disp16`. `tmp <- Load-Memory(adr, Word)`. If `GR[reg2] = tmp` then `Store-Memory(adr, GR[30], Word)` and `GR[reg2] <- tmp`, else `Store-Memory(adr, tmp, Word)` and `GR[reg2] <- tmp`. Unlocked. Flags: CY = 1 if borrow occurs from MSB as result of comparison. OV = 1 if Integer-Overflow occurs as result of comparison. S = 1 if comparison result negative. Z = 1 if comparison result is 0. [§5.3, pp.51–52]
- CAXI is described as an instruction to synchronize processors in a multi-processor system. Pre-execution state: GR[30] holds the new lock word to be set, GR[reg2] the lock word previously read, and the word at the address specified by GR[reg1] the lock word. Its six steps are: lock the bus, fetch the lock word, compare with the previously read lock word and reflect on flags, set the new lock word if they coincide, set the fetched lock word to GR[reg2] if they do not, release the bus lock. [§5.3 CAXI, pp.51–52]
- **CMP.** `CMP reg1, reg2` (Format I, op code 000011) and `CMP imm5, reg2` (Format II, op code 010011). Operation: `result <- GR[reg2] – GR[reg1]`. `result <- GR[reg2] – sign-extend(imm5)`. Flags: CY = 1 if borrow from MSB. OV = 1 if Integer-Overflow. S = 1 if result negative. Z = 1 if result is 0. Neither operand register is affected. [§5.3, p.53]
- **CMPF.S.** `CMPF.S reg1, reg2`, Format VII, sub-op code 000000. Operation `result <- GR[reg2] – GR[reg1]`. Flags: CY = 1 if result negative. OV = 0. S = 1 if result negative. Z = 1 if result is 0. FRO = 1 if operand is denormal, NaN, or indefinite. FIV, FZD, FOV, FUD, FPR not affected. S has the same value as CY. Exception: floating-point reserved operand exception. [§5.3, p.54]
- **CVT.SW.** `CVT.SW reg1, reg2`, Format VII, sub-op code 000011. Operation `GR[reg2] <- convert(GR[reg1])`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 if GR[reg2] is denormal, NaN, or indefinite. FIV = 1 if invalid operation occurs. FZD, FOV, FUD –. FPR = 1 if degradation in precision is detected. Exceptions: floating-point reserved operand exception, floating-point invalid operation exception. [§5.3, pp.55–56]
- CVT.SW: if the result is a word-length integer that cannot be expressed in a given range, the invalid floating-point operation exception occurs, FIV is set, a trap occurs, and reg2 and other flags are not affected. [§5.3 CVT.SW Note, p.56]
- **CVT.WS.** `CVT.WS reg1, reg2`, Format VII, sub-op code 000010. Operation `GR[reg2] <- convert(GR[reg1])`. Flags: CY = 1 if GR[reg2] negative. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO, FIV, FZD, FOV, FUD –. FPR = 1 if degradation in precision is detected. S has the same value as CY. Exception: None. [§5.3, p.57]
- **DIV.** `DIV reg1, reg2`, Format I, op code 001001. Operation `GR[30] <- GR[reg2] MOD GR[reg1] (signed)`. `GR[reg2] <- GR[reg2] ÷ GR[reg1] (signed)`. Flags: CY –. OV = 1 if Integer-Overflow. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. Division is carried out so the sign of the remainder matches the sign of the dividend. Overflow is set if the maximum value (80000000H) is divided by –1 (FFFFFFFFH). The negative maximum value is stored in reg2 and 0 in r30. Exception: zero division exception, on which reg2, r30, and flags are not affected. [§5.3, p.58]
- **DIVF.S.** `DIVF.S reg1, reg2`, Format VII, sub-op code 000111. Operation `GR[reg2] <- GR[reg2] ÷ GR[reg1]`. Flags: CY = 1 if GR[reg2] negative. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 if operand is denormal, NaN, or indefinite. FIV = 1 if invalid operation occurs. FZD = 1 if zero division occurs. FOV = 1 if result exceeds maximum normalized number. FUD = 1 if result is below minimum normalized number. FPR = 1 if precision degrades. Exceptions: floating-point reserved operand, invalid operation, zero division, and overflow exceptions. [§5.3, pp.59–60]
- DIVF.S: if reg2 data is zero and reg1 data is neither zero nor a denormalized number, the result is zero. The sign of the result is the exclusive OR of the two operands' sign fields. If both operands are zero the floating-point invalid operation exception occurs. If reg1 is zero and reg2 is a normalized number, the floating-point zero division exception occurs. On underflow FUD is set without a trap and a denormal number is stored to reg2. [§5.3 DIVF.S, pp.59–60]
- **DIVU.** `DIVU reg1, reg2`, Format I, op code 001011. Operation `GR[30] <- GR[reg2] MOD GR[reg1] (unsigned)`. `GR[reg2] <- GR[reg2] ÷ GR[reg1] (unsigned)`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. If r30 is specified as reg2, the quotient is stored in r30. The flags are set as if the result were signed data. Exception: zero division exception. [§5.3, p.61]
- **HALT.** `HALT`, Format II, op code 011010. Operation: Halt. Flags unaffected. Exception: None. If an interrupt is accepted in the HALT status, the address of the instruction next to the HALT instruction is stored in EIPC or FEPC. [§5.3, p.62]
- **IN.** `IN.B disp16 [reg1], reg2`, `IN.H disp16 [reg1], reg2`, `IN.W disp16 [reg1], reg2`. Format VI. Op code `1110*$` where `*$` = 00 for IN.B, 01 for IN.H, 11 for IN.W. Operation: `adr <- GR[reg1] + (sign-extend) disp16` then `GR[reg2] <- zero-extend(Input-Port(adr, size))`. Flags unaffected. IN.H masks bit 0 of the 32-bit port address with 0. IN.W masks bits 0 and 1. [§5.3, p.63]
- **JAL.** `JAL disp26`, Format IV, op code 101011. Operation `GR[31] <- PC + 4`. `PC <- PC + (sign-extend) disp26`. Flags unaffected. Bit 0 of the 26-bit displacement is masked with 0. The PC used is the address of the first byte of the JAL instruction itself. [§5.3, p.64]
- **JMP.** `JMP [reg1]`, Format I, op code 000110. Operation `PC <- GR[reg1]`. Flags unaffected. Bit 0 of the address is masked with 0. [§5.3, p.65]
- **JR.** `JR disp26`, Format IV, op code 101010. Operation `PC <- PC + (sign-extend) disp26`. Flags unaffected. Bit 0 of the 26-bit displacement is masked with 0. [§5.3, p.66]
- **LD.** `LD.B disp16[reg1], reg2`, `LD.H disp16[reg1], reg2`, `LD.W disp16[reg1], reg2`. Format VI. Op code `1100*$` where `*$` = 00 for LD.B, 01 for LD.H, 11 for LD.W. Operation: `adr <- GR[reg1] + (sign-extend) disp16` then `GR[reg2] <- sign-extend(Load-Memory(adr, size))`. Flags unaffected. LD.B and LD.H sign-extend the loaded data to word length. LD.H masks bit 0 of the address, LD.W masks bits 0 and 1. [§5.3, p.67]
- **LDSR.** `LDSR reg2, regID`, Format II, op code 011100 with regID carried in the imm5 field. Operation `SR[regID] <- GR[reg2]`. reg2 is not affected. If LDSR is executed to a reserved or write-disabled system register, operation is not guaranteed. Exception: None. If regID is 5 (PSW), the value of each corresponding bit of reg2 is set to each flag of the PSW. [§5.3, p.68]
- **MOV.** `MOV reg1, reg2` (Format I, op code 000000) and `MOV imm5, reg2` (Format II, op code 010000). Operation `GR[reg2] <- GR[reg1]`. `GR[reg2] <- sign-extend(imm5)`. All flags unaffected. [§5.3, p.69]
- **MOVBSU.** `MOVBSU`, Format II, op code 011111 with sub-field 01011. Operation `destination <- source`. Flags unaffected. Uses r26–r30 as described for the bit string instructions. Transfer runs from lower toward higher address. [§5.3, p.70]
- **MOVEA.** `MOVEA imm16, reg1, reg2`, Format V, op code 101000. Operation `GR[reg2] <- GR[reg1] + sign-extend(imm16)`. Flags unaffected. The document states explicitly that neither reg1 nor the flags are affected. [§5.3, p.71]
- **MOVHI.** `MOVHI imm16, reg1, reg2`, Format V, op code 101111. Operation `GR[reg2] <- GR[reg1] + (imm16 || 0^16)`. Flags unaffected. Adds word data whose higher 16 bits are the immediate and lower 16 bits are all 0. [§5.3, p.72]
- **MUL.** `MUL reg1, reg2`, Format I, op code 001000. Operation `result <- GR[reg2] × GR[reg1] (signed)`. `GR[30] <- result (higher 32 bits)`. `GR[reg2] <- result (lower 32 bits)`. Flags: CY –. OV = 1 if Integer-Overflow. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. If r30 is specified as reg2, the lower 32 bits are stored in r30. Overflow is set if the doubleword result is not equal to the value sign-extended from the lower 32 bits to doubleword length. [§5.3, p.73]
- **MULF.S.** `MULF.S reg1, reg2`, Format VII, sub-op code 000110. Operation `GR[reg2] <- GR[reg2] × GR[reg1]`. Flags: CY = 1 if GR[reg2] negative. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 for denormal/NaN/indefinite operand. FIV, FZD –. FOV = 1 on overflow. FUD = 1 on underflow. FPR = 1 on precision degradation. If one operand is zero and the other is zero or a normalized number, the result is zero. The result sign is the exclusive OR of the operand sign fields. Exceptions: floating-point reserved operand, floating-point overflow. [§5.3, pp.74–75]
- **MULU.** `MULU reg1, reg2`, Format I, op code 001010. Operation `result <- GR[reg2] × GR[reg1] (unsigned)`. `GR[30] <- higher 32 bits`. `GR[reg2] <- lower 32 bits`. Flags: CY –. OV = 1 if Integer-Overflow. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. Overflow is set if the doubleword result is not equal to the value zero-extended from the lower 32 bits to doubleword length. [§5.3, p.76]
- **NOT.** `NOT reg1, reg2`, Format I, op code 001111. Operation `GR[reg2] <- NOT(GR[reg1])` (1's complement). Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.77]
- **NOTBSU.** `NOTBSU`, Format II, op code 011111 with sub-field shown as 011111 in the op code table (Appendix C places NOTBSU at bits 4..3 = 1, bits 2..0 = 7). Operation `destination <- NOT(source)`. Flags unaffected. [§5.3, p.78; Appendix C(c), p.143]
- **OR.** `OR reg1, reg2`, Format I. Operation `GR[reg2] <- GR[reg2] OR GR[reg1]`. Flags listed in §5.3 as CY –, OV 0 (the S and Z rows are absent from the §5.3 entry). Table B-2 gives op code 001100. [§5.3, p.79; Table B-2, p.142]
- **ORBSU.** `ORBSU`, Format II, op code 011111 with sub-field 01000. Operation `destination <- destination OR source`. Flags unaffected. [§5.3, p.80]
- **ORI.** `ORI imm16, reg1, reg2`, Format V, op code 101100. Operation `GR[reg2] <- GR[reg1] OR zero-extend(imm16)`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.81]
- **ORNBSU.** `ORNBSU`, Format II, op code 011111 with sub-field 01100. Operation `destination <- destination OR (NOT source)`. Flags unaffected. [§5.3, p.82]
- **OUT.** `OUT.B reg2, disp16 [reg1]`, `OUT.H reg2, disp16 [reg1]`, `OUT.W reg2, disp16 [reg1]`. Format VI. Op code `1111*$` where `*$` = 00 for OUT.B, 01 for OUT.H, 11 for OUT.W. Operation: `adr <- GR[reg1] + (sign-extend) disp16` then `Output-Port(adr, GR[reg2], size)`. Flags unaffected. OUT.B outputs the lower 1 byte of reg2. OUT.H outputs the lower 2 bytes and masks bit 0 of the address. OUT.W outputs the word and masks bits 0 and 1. [§5.3, p.83]
- **RETI.** `RETI`, Format II, op code 011001. Operation: if `PSW.NP = 1` then `PC <- FEPC`, `PSW <- FEPSW`, else `PC <- EIPC`, `PSW <- EIPSW`. Flags: CY, OV, S, Z each take the read value that is restored. [§5.3, p.84]
- **SAR.** `SAR reg1, reg2` (Format I, op code 000111) and `SAR imm5, reg2` (Format II, op code 010111). Operation: arithmetic right shift of GR[reg2] by GR[reg1], or by `zero-extend(imm5)`. Flags: CY = 1 if the bit shifted out last is 1, but 0 if the number of shifts is 0. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. The shift copies the MSB value sequentially to the MSB. The register form uses the lower 5 bits of reg1. Shift counts range 0 to +31. If the number of shifts is 0, reg2 holds its prior value. [§5.3, p.85]
- **SCH0BS.** `SCH0BSU` and `SCH0BSD`, Format II, op code 011111 with sub-field `0000*` where `*` = 0 for SCH0BSU and 1 for SCH0BSD. Operation: finds the first 0 from a specified bit string. Flags: CY –. OV –. S –. Z = 1 if the bit is not found, otherwise 0. [§5.3, pp.86–87]
- SCH0BS work registers (Supplement table): r27 bit offset in source word. r28 string length. r29 number of bits skipped until detection. r30 source word address. [§5.3 SCH0BS, p.87]
- **SCH1BS.** `SCH1BSU` and `SCH1BSD`, Format II, op code 011111 with sub-field `0001*` where `*` = 0 for SCH1BSU and 1 for SCH1BSD. Operation: finds the first 1 from a specified bit string. Flags: CY –. OV –. S –. Z = 1 if the bit is not found, otherwise 0. [§5.3, pp.88–89]
- SCH1BS behaviour: on detection, the bit address 1 bit before the first 1 found is stored in r30 and r27. The number of bits skipped before detection is added to r29. The number of bits searched is subtracted from r28. The Z flag is cleared to 0. If the bit is not found, the bit address 1 bit before the source bit string is stored in r30 and r27, the number of bits skipped is added to r29, r28 becomes 0, and Z is set to 1. If r28 (string length) is 0 on entry, Z is set to 1 and r27 through r30 are not affected. [§5.3 SCH1BS, p.88]
- SCH1BSU searches upward from the bit position given by r30 and r27, from the lower address (first address) toward the higher address (end address), for the length in r28. SCH1BSD searches downward, from the higher address (end address) toward the lower address (first address). The document states the address to be set in r30 and r27 at start of execution therefore differs by search direction even for the same bit string. [§5.3 SCH1BS, p.88]
- **SETF.** `SETF imm5, reg2`, Format II, op code 010010. Operation: if condition satisfied then `GR[reg2] <- 00000001H` else `GR[reg2] <- 00000000H`. Flags unaffected. The condition is given by the lower 4 bits of the 5-bit immediate. The highest bit is ignored. [§5.3, pp.90–91]
- **Table 5-10 Condition Codes** (p.91):

  | Code | Mnemonic | Condition               |
  | ---- | -------- | ----------------------- |
  | 0000 | V        | `OV = 1`                |
  | 1000 | NV       | `OV = 0`                |
  | 0001 | C/L      | `CY = 1`                |
  | 1001 | NC/NL    | `CY = 0`                |
  | 0010 | Z        | `Z = 1`                 |
  | 1010 | NZ       | `Z = 0`                 |
  | 0011 | NH       | `(CY or Z) = 1`         |
  | 1011 | H        | `(CY or Z) = 0`         |
  | 0100 | S/N      | `S = 1`                 |
  | 1100 | NS/P     | `S = 0`                 |
  | 0101 | T        | always 1                |
  | 1101 | F        | always 0                |
  | 0110 | LT       | `(S xor OV) = 1`        |
  | 1110 | GE       | `(S xor OV) = 0`        |
  | 0111 | LE       | `((S xor OV) or Z) = 1` |
  | 1111 | GT       | `((S xor OV) or Z) = 0` |

  [Table 5-10, p.91]
- **SHL.** `SHL reg1, reg2` (Format I, op code 000100) and `SHL imm5, reg2` (Format II, op code 010100). Logical left shift, sending 0 to the LSB side. Flags: CY = 1 if the bit shifted out last is 1, but 0 if the number of shifts is 0. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. Shift counts 0 to +31. The register form uses the lower 5 bits of reg1. [§5.3, p.92]
- **SHR.** `SHR reg1, reg2` (Format I, op code 000101) and `SHR imm5, reg2` (Format II, op code 010101). Logical right shift, sending 0 to the MSB side. Flags: CY = 1 if the bit shifted out last is 1, but 0 if the number of shifts is 0. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. Shift counts 0 to +31. [§5.3, p.93]
- **ST.** `ST.B reg2, disp16[reg1]`, `ST.H reg2, disp16[reg1]`, `ST.W reg2, disp16[reg1]`. Format VI. Op code `1101*$` where `*$` = 00 for ST.B, 01 for ST.H, 11 for ST.W. Operation: `adr <- GR[reg1] + (sign-extend) disp16` then `Store-Memory(adr, GR[reg2], size)`. Flags unaffected. ST.B stores the lower 1 byte of reg2. ST.H stores the lower 2 bytes and masks bit 0 of the address. ST.W stores the word and masks bits 0 and 1. [§5.3, p.94]
- **STSR.** `STSR regID, reg2`, Format II, op code 011101 with regID carried in the imm5 field. Operation `GR[reg2] <- SR[regID]`. Flags unaffected. The system register contents are not affected. If STSR is executed to a reserved system register, operation is not guaranteed. [§5.3, p.95]
- **SUB.** `SUB reg1, reg2`, Format I, op code 000010. Operation `GR[reg2] <- GR[reg2] – GR[reg1]`. Flags: CY = 1 if borrow occurs from MSB. OV = 1 if Integer-Overflow. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.96]
- **SUBF.S.** `SUBF.S reg1, reg2`, Format VII, sub-op code 000101. Operation `GR[reg2] <- GR[reg2] – GR[reg1]`. Flags: CY = 1 if GR[reg2] negative. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 for denormal/NaN/indefinite operand. FIV, FZD –. FOV = 1 on overflow. FUD = 1 on underflow. FPR = 1 on precision degradation. S has the same value as CY. If the two operands are equal in both absolute value and sign, the sign of the result depends on the rounding mode, and because the rounding mode is "Toward nearest" the result is "positive zero". Exceptions: floating-point reserved operand, floating-point overflow. [§5.3, pp.97–98]
- **TRAP.** `TRAP vector`, Format II, op code 011000. Flags unaffected. Operation: if `PSW.NP = 1` then fatal exception (MACHINE FAULT). Else if `PSW.EP = 1` then `FEPC <- restored PC`, `FEPSW <- PSW`, `ECR.FECC <- exception code`, `PSW.NP <- 1`, `PSW.ID <- 1`, `PSW.AE <- 0`, `PC <- <NMI handler address>`. Else `EIPC <- restored PC`, `EIPSW <- PSW`, `ECR.EICC <- exception code`, `PSW.EP <- 1`, `PSW.ID <- 1`, `PSW.AE <- 0`, `PC <- <vector adr>`. [§5.3, pp.99–100]
- TRAP fatal exception processing indicates the machine fault status using the ST1, ST0, and MRQ signals, starts the write cycle, sequentially outputs the source code (OR of FFFF0000H and the exception code) and the current PSW and PC to the data bus, and stops. [§5.3 TRAP, p.99]
- TRAP: the trap vector range is stated as 0–31, and the restore PC is the address of the instruction next to the TRAP instruction. The condition flags are not affected in either the duplexed or the normal path. [§5.3 TRAP, p.100]
- **TRNC.SW.** `TRNC.SW reg1, reg2`, Format VII, sub-op code 001011. Operation `GR[reg2] <- truncate(GR[reg1])`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. FRO = 1 if GR[reg1] is denormal, NaN, or indefinite. FIV = 1 if invalid operation occurs. FZD, FOV, FUD –. FPR = 1 if precision degrades. Exceptions: floating-point reserved operand, floating-point invalid operation. [§5.3, pp.101–102]
- **XOR.** `XOR reg1, reg2`, Format I, op code 001110. Operation `GR[reg2] <- GR[reg2] XOR GR[reg1]`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.103]
- **XORBSU.** `XORBSU`, Format II, op code 011111 with sub-field 01010. Operation `destination <- destination XOR source`. Flags unaffected. [§5.3, p.104]
- **XORI.** `XORI imm16, reg1, reg2`, Format V, op code 101110. Operation `GR[reg2] <- GR[reg1] XOR zero-extend(imm16)`. Flags: CY –. OV 0. S = 1 if GR[reg2] negative. Z = 1 if GR[reg2] is 0. [§5.3, p.105]
- **XORNBSU.** `XORNBSU`, Format II, op code 011111 with sub-field 01110. Operation `destination <- destination XOR (NOT source)`. Flags unaffected. [§5.3, p.106]
- Every arithmetic bit string instruction entry (MOVBSU, NOTBSU, ANDBSU, ANDNBSU, ORBSU, ORNBSU, XORBSU, XORNBSU) carries the same Supplement: r26–r30 are the work registers of the bit string instruction and hold information necessary for aborting and resuming the instruction while it executes. They are r26 bit offset in destination word, r27 bit offset in source word, r28 string length, r29 destination word address, and r30 source word address. [§5.3, pp.46, 48, 70, 78, 80, 82, 104, 106]

#### 5.4 Instruction Execution Clock Cycles (p.107)

- Table 5-11 data is stated to be the minimum execution clock cycles with cache hit, no hazard, and no wait, excluding bit string instructions. [§5.4.1, p.107]
- For LD.W, ST.W, IN.W, and OUT.W the execution clock cycles differ according to the external bus width. [§5.4.1, p.107]
- Integer arithmetic and logical operation cycle counts. [Table 5-11 (1/3), p.107]

  | Instruction                               | Cycles |
  | ----------------------------------------- | ------ |
  | MOV, ADD, SUB, CMP, SHL, SHR (reg1, reg2) | 1      |
  | MUL                                       | 13     |
  | DIV                                       | 38     |
  | MULU                                      | 13     |
  | DIVU                                      | 36     |
  | OR                                        | 1      |
  | MOV imm5, reg2                            | 1      |
  | MOVEA imm16, reg1, reg2                   | 1      |

- Special instruction cycle counts: TRAP imm5 = 15. RETI = 10. CAXI disp16 [reg1], reg2 = 22 on a 32-bit bus. [Table 5-11 (2/3), p.108]
- Program control cycle counts: JMP [reg1] = 3. JR (disp26)[PC] = 3. JAL = 3. Bcond (disp9)[PC] taken = 3. [Table 5-11 (2/3), p.108]
- Load/store cycle counts: LD.B and LD.H = 1–3 (Note 1). LD.W = 1–3 on a 32-bit bus (Note 1) and 1–5 on a 16-bit bus (Note 2). ST.B = 1 (2) (Note 3). ST.W = 1 (2) on a 32-bit bus and 1 (4) on a 16-bit bus (Note 3). [Table 5-11 (2/3), p.108]
- I/O instruction cycle counts: IN.B = 3. IN.W = 3 on a 32-bit bus. OUT.B = 1 (2) (Note 3). OUT.W = 1 (2) on a 32-bit bus and 1 (4) on a 16-bit bus (Note 3). [Table 5-11 (2/3), p.108]
- Note 1: LD instruction cycles (excluding LD.W in 16-bit bus mode) depend on the preceding instruction. 3 cycles when executed alone. 2 cycles when an LD instruction precedes it (for the latter one). 1 cycle when it follows an instruction that requires many execution clock cycles and does not perform any operations conflicting with the LD instructions. [Table 5-11 Note 1, p.108]
- Note 2: LD.W in 16-bit bus mode. 5 cycles when executed alone. 4 cycles when an LD instruction precedes it. 1 cycle when it follows an instruction requiring many execution clock cycles with no conflicting operations. [Table 5-11 Note 2, p.109]
- Floating-point instruction cycle counts. [Table 5-11 (3/3), p.109]

  | Instruction | Cycles |
  | ----------- | ------ |
  | CVT.WS      | 5–16   |
  | CVT.SW      | 9–14   |
  | TRNC.SW     | 8–14   |
  | CMPF.S      | 7–10   |
  | ADDF.S      | 9–28   |
  | SUBF.S      | 12–28  |
  | MULF.S      | 8–30   |
  | DIVF.S      | 44     |

- Table 5-12 covers the search bit string instructions SCH0BSU, SCH1BSU, SCH0BSD, SCH1BSD, and is stated to show minimum execution clock cycles with cache hit, no hazard, and no wait in 32-/16-bit bus mode. Cycle counts are tabulated by boundary condition (positions of start and end points), search range in words, and pattern detection position (1st word, 2nd word, pth word, Nth word, no detection). [§5.4.2, p.110]
- Table 5-12 sample values, 32-bit bus, SCH0BSU/SCH1BSU: bit string length = 0 gives 13 cycles. Single-word range gives 29 cycles. Two-word ranges give values such as 38/39/40, 28/47/47, 28/52/46, 38/41/35. N-word ranges give forms such as `3p + 35` at the pth word, `3N + 33` at the Nth word, and `3N + 34` when there is no detection. [Table 5-12(a), pp.110–111]
- Table 5-12 sample values, 32-bit bus, SCH0BSD/SCH1BSD: bit string length = 0 gives 15 cycles. Single-word range gives 26 cycles (28 when no detection). N-word ranges give forms such as `3p + 49`, `3N + 49`, `3N + 43`, `3p + 40`, `3N + 42`, `3N + 34`. [Table 5-12(a) 2/2, p.111]
- Table 5-12 sample values, 16-bit bus, SCH0BSU/SCH1BSU: bit string length = 0 gives 13 cycles. Single-word range gives 31 cycles. N-word ranges give forms such as `5p + 35`, `5N + 33`, `5N + 34`, `5p + 46`, `5N + 44`, `5N + 45`. [Table 5-12(b) 1/2, p.112]
- Table 5-12 sample values, 16-bit bus, SCH0BSD/SCH1BSD: bit string length = 0 gives 15 cycles. Single-word range gives 28 cycles (30 when no detection). A two-word range gives 33 / 52 / 54. The transcription of this sub-table is truncated partway through. [Table 5-12(b) 2/2, p.113]
- Table 5-13 covers the arithmetic bit string instructions (MOVBSU, NOTBSU, ANDBSU, ANDNBSU, ORBSU, ORNBSU, XORBSU, XORNBSU) and is stated to show minimum execution clock cycles "without cache hit, no hazard, and no wait". [§5.4.3, p.114]
- Table 5-13 cycle counts by transfer type. A blank cell is printed as a dash in the source.

  | Type  | 1 word, 32-bit bus | 1 word, 16-bit bus | 2 word, 32-bit bus | 2 word, 16-bit bus | Nth word, 32-bit bus | Nth word, 16-bit bus |
  | ----- | ------------------ | ------------------ | ------------------ | ------------------ | -------------------- | -------------------- |
  | TYPE1 | 32                 | 38                 | 41                 | 53                 | `6N + 30`            | `12N + 30`           |
  | TYPE2 | 32                 | 38                 | 42                 | 54                 | `6N + 31`            | `12N + 31`           |
  | TYPE3 | 37                 | 43                 | 48                 | 60                 | `6N + 35`            | `12N + 35`           |
  | TYPE4 | 43                 | 49                 | 49                 | 61                 | `6N + 36`            | `6N + 36`            |
  | TYPE5 | 32                 | 38                 | 43                 | 55                 | `6N + 31`            | `12N + 31`           |
  | TYPE6 | 14                 | 20                 |                    |                    |                      |                      |
  | TYPE7 | 37                 | 43                 |                    |                    |                      |                      |

  N is stated to be the number of words of memory space occupied by the source bit string, where N is the last word of the source bit string. [Table 5-13, p.114]
- Table 5-14 boundary conditions selecting the transfer type: with length ≠ 0 and src. ofs = dst. ofs, TYPE1 if src. ofs + length is a multiple of the word number and TYPE2 if not. When the number of words of the bit string and of the memory string are the same, TYPE3 if dst. ofs = 0 and TYPE5 if dst. ofs ≠ 0. TYPE4 when they are not the same. TYPE6 when length = 0. TYPE7 when the source and destination bit strings are in the same word and src. ofs > dst. ofs. [Table 5-14, p.115]
- Table 5-14 legend: `length` is bit string length, `src. ofs` is the bit offset in word of the source bit string, `dst. ofs` is the bit offset in word of the destination bit string. [Table 5-14 Remark, p.115]

### CHAPTER 6 INTERRUPT AND EXCEPTION (p.117)

- If a maskable interrupt or NMI occurs, control is transferred to a handler whose address is determined by the source. The exception source is checked by examining the exception code stored in the ECR (Exception Code Register). Each handler analyzes the ECR contents and performs appropriate processing. [CHAPTER 6, p.117]
- **Table 6-1 Exception Codes** (p.117), listing exception/interrupt, classification, exception code, handler address, and restore PC:

| Exception or interrupt                     | Classification     | Exception code | Handler address | Restore PC                               |
| ------------------------------------------ | ------------------ | -------------- | --------------- | ---------------------------------------- |
| Reset                                      | Interrupt          | FFF0           | FFFFFFF0H       | per Note 2 (EIPC and FEPC are undefined) |
| NMI                                        | Interrupt          | FFD0           | FFFFFFD0H       | next PC (Note 3)                         |
| Duplexed exception                         | Exception          | per Note 4     | FFFFFFD0H       | current PC                               |
| Address trap                               | Exception          | FFC0           | FFFFFFC0H       | current PC                               |
| Trap instruction (parameter is 0x1n)       | Exception          | FFBn           | FFFFFFB0H       | next PC                                  |
| Trap instruction (parameter is 0x0n)       | Exception          | FFAn           | FFFFFFA0H       | next PC                                  |
| Invalid instruction code                   | Exception          | FF90           | FFFFFF90H       | current PC                               |
| Zero division                              | Exception          | FF80           | FFFFFF80H       | current PC                               |
| FIV (floating-point invalid operation)     | Exception          | FF70           | FFFFFF60H       | current PC                               |
| FZD (floating-point zero division)         | Exception          | FF68           | FFFFFF60H       | current PC                               |
| FOV (floating-point overflow)              | Exception          | FF64           | FFFFFF60H       | current PC                               |
| FUD (floating-point underflow)             | Exception (Note 5) | FF62           | FFFFFF60H       | current PC                               |
| FPR (floating-point precision degradation) | Exception (Note 5) | FF61           | FFFFFF60H       | current PC                               |
| FRO (floating-point reserved operand)      | Exception          | FF60           | FFFFFF60H       | current PC                               |
| INT level n (n = 0–15)                     | Interrupt          | FEn0           | FFFFFEn0H       | next PC (Note 3)                         |

[Table 6-1, p.117]
- Table 6-1 Note 1: the restore PC column is the PC to be saved to EIPC or FEPC. Note 3: while an instruction whose execution is aborted by an interrupt is executed, restore PC = current PC. Note 4: for a duplexed exception, the exception code of the first exception is stored in the lower 16 bits of the ECR and the code of the second in the higher 16 bits. Note 5: in the V810 family, the floating-point underflow exception and floating-point precision degradation exception do not occur. [Table 6-1 Notes, p.117]
- **Table 6-2 Instructions Aborted by Interrupt** (p.117): the DIV/DIVU instruction, floating-point operation instructions, and bit string instructions. [Table 6-2, p.117]
- Exception processing sequence (§6.1): (1) if PSW.NP is already set, proceed to fatal exception processing. (2) if PSW.EP is already set, proceed to duplexed exception processing. (3) save the restore PC to EIPC. (4) save the current PSW to EIPSW. (5) write the exception code to the lower 16 bits of the ECR (EICC). (6) set the EP and ID bits of the PSW and clear the AE bit. (7) jump to the handler address. [§6.1, p.118]
- Fatal exception processing (§6.1 step 8): becomes the machine faults status, starts the write cycle, and sequentially outputs the source code of the fatal exception (OR of FFFF0000H and the exception code) at address 00000000H, the current PSW at address 00000004H, and the current PC at address 00000008H to the data bus. Then halts until reset. [§6.1, p.118]
- Duplexed exception processing (§6.1 step 9): saves the restore PC to FEPC. Saves the current PSW to FEPSW. Writes the exception code of the source causing the duplexed exception to the higher 16 bits of the ECR (FECC). Sets the NP and ID bits of the PSW and clears the AE bit. Jumps to address FFFFFFD0H (NMI handler address). [§6.1, p.118]
- Maskable interrupts are caused by the INT input. EIPC and EIPSW are used to save PC and PSW. [§6.2.1, p.119]
- The maskable interrupt is masked by the logical sum of PSW.NP, PSW.EP, and PSW.ID. The interrupt is not accepted if the interrupt level n is lower than the interrupt enable level (I3-I0) of the PSW (n < I3-I0). Therefore the highest-level interrupt (n = 15) cannot be disabled by the interrupt enable level. [§6.2.1, p.119]
- Maskable interrupt processing sequence: (1) save the restore PC to EIPC. (2) save the current PSW to EIPSW. (3) write the exception code to the lower 16 bits of the ECR (EICC). (4) set the EP and ID bits of the PSW and clear the AE bit. (5) set n+1 (the accepted interrupt level plus 1) into the I (I3-I0) field of the PSW, but set 15 if the accepted interrupt is the highest level (n = 15). (6) jump to the handler address. [§6.2.1, p.119]
- The non-maskable interrupt is caused by the NMI input. FEPC and FEPSW are used to save PC and PSW. [§6.2.2, p.121]
- If another NMI request occurs while an NMI is being processed (PSW.NP = 1), the request is internally held by the processor. The document notes an exception: an NMI request occurring during the period in which the latch is cleared by internal processing immediately after the start of processing the first NMI is not held in the internal latch. If PSW.NP is then cleared to 0 using RETI or LDSR, new NMI processing is started from the internally held request. [§6.2.2, p.121]
- NMI processing sequence: (1) save the restore PC to FEPC. (2) save the current PSW to FEPSW. (3) write the exception code to the higher 16 bits of the ECR (FECC). (4) set the NP and ID bits of the PSW and clear the AE bit. (5) jump to address FFFFFFD0H (NMI handler address). [§6.2.2, p.121]
- Returning from an exception event other than the fatal exception uses the RETI instruction: if PSW.NP = 1 the restore PC and PSW are restored from FEPC and FEPSW, and if NP = 0 from EIPC and EIPSW. Then the restored PC and PSW are set and execution jumps to the PC. [§6.3, p.122]
- **Table 6-3 Priorities of Interrupts and Exceptions** (p.123) covers RESET, NMI, INT (maskable interrupt), AD-TR (address trap), TRAP (trap instruction), I-OPC (illegal op code), DIV0 (zero division), and FLOAT (floating-point exceptions: invalid operation, zero division, overflow, and reserved operand exceptions). Legend: `*` item on the left ignores the item above. `✕` item on the left is ignored by the item above. `–` item on the left does not occur simultaneously with the item above. `<-` item on the left has higher priority than the item above. `↑` item above has higher priority than the item on the left. [Table 6-3, p.123]
- Table 6-3 shows RESET ignoring all other listed sources, and NMI, INT, and AD-TR being ignored by RESET. [Table 6-3, p.123]
- **Table 6-4 Priorities of Floating-Point Exceptions** (p.124) covers FRO (reserved operand), FIV (invalid operation), FZD (zero division), FOV (overflow), FUD (underflow), and FPR (precision degradation), with the same `*` / `✕` / `–` legend. The Remark states FUD and FPR do not occur on the V810 family. [Table 6-4, p.124]
- Interrupt execution timing: an interrupt is accepted when an instruction is executed. If the instruction takes 2 or more clocks, the interrupt is accepted during the last 1 clock of the instruction. If an interrupt request is issued while no instruction is executed (in wait or bus hold status), the interrupt is accepted when the next instruction is executed. [§6.4.3, p.124]

### CHAPTER 7 CACHE DUMP/RESTORE FUNCTIONS (p.125)

- The cache dump/restore functions serve to inspect the contents of the internal instruction cache memory. [CHAPTER 7, p.125]
- Fig. 7-1 Cache Configuration (p.125) and Fig. 7-2 Cache Dump Format (p.127) are reproduced as images only. Their contents are not transcribed in the source file. [CHAPTER 7, pp.125, 127]
- Inspection procedure using the cache control word via LDSR: <1> prepare data to be restored to the cache. <2> clear the ICE bit to "0" to disable the cache. <3> set the first address of the restore data in the SA field and set the ICR bit to "1" to start restoring. <4> set the first address of the dump area in the SA field and set the ICD bit to "1" to start dump execution. <5> inspect the contents of the cache dumped to the dump area. <6> set the start entry number and the number of entries to be cleared in the CEN and CEC fields and set the ICC bit to "1" to start clearing (all the entries must be eventually cleared). <7> set the ICE bit to "1" to enable the cache. [CHAPTER 7 (2), p.126]
- While the cache is dumped, restored, or cleared, interrupts are disabled. An interrupt request generated during this period is internally held until the processing ends, so start of interrupt processing is delayed. A maskable interrupt is ignored unless all of the NP, EP, and ID flags of the PSW are "0". [CHAPTER 7 (2), p.126]
- The interrupt disable period can be shortened by processing each entry using the CEN and CEC fields. However, all entries must be eventually cleared. [CHAPTER 7 (2), p.126]
- The cache dump format figure is annotated with the addresses SA+0, SA+4, SA+8, SA+12, SA+1016, SA+1020, SA+1024, SA+1532. [Fig. 7-2, p.127]

### CHAPTER 8 DEBUG SUPPORT FUNCTION (p.129)

- The address trap function is made valid by setting the trap address (TA: Trap Address) in the address trap register (ADTRE) and setting the AE bit of the PSW. [CHAPTER 8, p.129]
- When the program runs with the address trap function enabled and the current PC contents (= first address of an instruction) coincide with the trap address TA, the V810 family performs exception processing and transfers control to the address trap handler routine at address FFFFFFC0H. [CHAPTER 8, p.129]

### CHAPTER 9 RESET (p.131)

- When the RESET pin goes low, the system reset is triggered and each on-chip hardware is initialized. When RESET goes high, the device is released from the reset state and program execution starts. The document directs that the contents of each register be initialized as required in the program. [CHAPTER 9; §9.1, p.131]
- **Table 9-1 Register Status after Reset** (p.131): PC = FFFFFFF0H. EIPC (interrupt status saving register) undefined. FEPC (NMI status saving register) undefined. ECR FECC = 0000H. ECR EICC = FFF0H. PSW = 00008000H. r0 = 00000000H fixed. r1–r31 undefined. [Table 9-1, p.131]
- The V810 family starts program execution from FFFFFFF0H when reset. Immediately after reset the interrupt request is not acknowledged. To use interrupts, the document directs setting the NP bit of the PSW to 0. [§9.2, p.131]

### APPENDIX A INSTRUCTION MNEMONIC (alphabetical order) (p.133)

- Appendix A lists instruction mnemonics in alphabetical order with operand, format, CY/OV/S/Z effects, a brief instruction function, and the page number of the full description, so that brief explanations can be found "in the same way as consulting a dictionary". [APPENDIX A, p.133]
- The Appendix A legend repeats the operand symbol definitions (reg1, reg2, imm5, imm16, disp9, disp16, disp26, regID, vector adr). [APPENDIX A Legend, p.133]
- Table A-1's page column gives these locations for the full §5.3 descriptions. [Table A-1, pp.134–140]

  | Mnemonic        | Page |
  | --------------- | ---- |
  | ADD             | 41   |
  | ADDF.S          | 42   |
  | ADDI            | 44   |
  | AND             | 45   |
  | ANDBSU          | 46   |
  | ANDI            | 47   |
  | ANDNBSU         | 48   |
  | Bcond           | 50   |
  | CAXI            | 51   |
  | CMP             | 53   |
  | CMPF.S          | 54   |
  | CVT.SW          | 55   |
  | CVT.WS          | 57   |
  | DIV             | 58   |
  | DIVF.S          | 59   |
  | DIVU            | 61   |
  | HALT            | 62   |
  | IN              | 63   |
  | JAL             | 64   |
  | JMP             | 65   |
  | JR              | 66   |
  | LD              | 67   |
  | LDSR            | 68   |
  | MOV             | 69   |
  | MOVBSU          | 70   |
  | MOVEA           | 71   |
  | MOVHI           | 72   |
  | MUL             | 73   |
  | MULF.S          | 74   |
  | MULU            | 76   |
  | NOT             | 77   |
  | NOTBSU          | 78   |
  | OR              | 79   |
  | ORBSU           | 80   |
  | ORI             | 81   |
  | ORNBSU          | 82   |
  | OUT             | 83   |
  | RETI            | 84   |
  | SAR             | 85   |
  | SCH0BSU/SCH0BSD | 86   |
  | SCH1BSU/SCH1BSD | 88   |
  | NOP             | 89   |
  | SETF            | 90   |
  | SHL             | 92   |
  | SHR             | 93   |
  | ST              | 94   |
  | STSR            | 95   |
  | SUB             | 96   |
  | SUBF.S          | 97   |
  | TRAP            | 99   |
  | TRNC.SW         | 101  |
  | XOR             | 103  |
  | XORBSU          | 104  |
  | XORI            | 105  |
  | XORNBSU         | 106  |

### APPENDIX B INSTRUCTION LIST (p.141)

- Table B-1 is a mnemonic list pairing each op code mnemonic with its function name (LD.B Load Byte through HALT Halt). [Table B-1, p.141]
- **Table B-2 Instruction Set** (p.142) maps 6-bit op codes to instruction and format:

  | Op code   | Instruction              | Format |
  | --------- | ------------------------ | ------ |
  | 000000    | MOV reg1, reg2           | I      |
  | 000001    | ADD reg1, reg2           | I      |
  | 000010    | SUB reg1, reg2           | I      |
  | 000011    | CMP reg1, reg2           | I      |
  | 000100    | SHL reg1, reg2           | I      |
  | 000101    | SHR reg1, reg2           | I      |
  | 000110    | JMP [reg1]               | I      |
  | 000111    | SAR reg1, reg2           | I      |
  | 001000    | MUL reg1, reg2           | I      |
  | 001001    | DIV reg1, reg2           | I      |
  | 001010    | MULU reg1, reg2          | I      |
  | 001011    | DIVU reg1, reg2          | I      |
  | 001100    | OR reg1, reg2            | I      |
  | 001101    | AND reg1, reg2           | I      |
  | 001111    | NOT reg1, reg2           | I      |
  | 010000    | MOV imm5, reg2           | II     |
  | 010001    | ADD imm5, reg2           | II     |
  | 010010    | SETF imm5, reg2          | II     |
  | 010011    | CMP imm5, reg2           | II     |
  | 010100    | SHL imm5, reg2           | II     |
  | 010101    | SHR imm5, reg2           | II     |
  | 010110    | unassigned               |        |
  | 010111    | SAR imm5, reg2           | II     |
  | 011000    | TRAP vector              | II     |
  | 011001    | RETI                     | II     |
  | 011010    | HALT                     | II     |
  | 011011    | unassigned               |        |
  | 011100    | LDSR reg2, regID         | II     |
  | 011101    | STSR regID, reg2         | II     |
  | 011110    | unassigned               |        |
  | 011111    | Bstr                     | II     |
  | `100$$$$` | Bcond disp9              | III    |
  | 101000    | MOVEA imm16, reg1, reg2  | V      |
  | 101001    | ADDI imm16, reg1, reg2   | V      |
  | 101010    | JR disp26                | IV     |
  | 101011    | JAL disp26               | IV     |
  | 101100    | ORI                      | V      |
  | 101101    | ANDI                     | V      |
  | 101110    | XORI                     | V      |
  | 101111    | MOVHI                    | V      |
  | 110000    | LD.B disp16 [reg1], reg2 | VI     |
  | 110001    | LD.H                     | VI     |
  | 110010    | unassigned               |        |
  | 110011    | LD.W                     | VI     |
  | 110100    | ST.B reg2, disp16 [reg1] | VI     |
  | 110101    | ST.H                     | VI     |
  | 110110    | unassigned               |        |
  | 110111    | ST.W                     | VI     |
  | 111000    | IN.B                     | VI     |
  | 111001    | IN.H                     | VI     |
  | 111010    | CAXI disp16 [reg1], reg2 | VI     |
  | 111011    | IN.W                     | VI     |
  | 111100    | OUT.B                    | VI     |
  | 111101    | OUT.H                    | VI     |
  | 111110    | Fpp reg1, reg2           | VII    |
  | 111111    | OUT.W                    | VI     |

  [Table B-2, p.142]

### APPENDIX C OP CODE MAP (p.143)

Op code map (a) is indexed by bits 15..13 down the rows against bits 12..10 across the columns. [Appendix C(a), p.143]

| Row | 0     | 1    | 2       | 3       | 4     | 5     | 6       | 7     | Format  |
| --- | ----- | ---- | ------- | ------- | ----- | ----- | ------- | ----- | ------- |
| 0   | MOV   | ADD  | SUB     | CMP     | SHL   | SHR   | JMP     | SAR   | I       |
| 1   | MUL   | DIV  | MULU    | DIVU    | OR    | AND   | XOR     | NOT   | I       |
| 2   | MOV   | ADD  | SETF    | CMP     | SHL   | SHR   | (blank) | SAR   | II      |
| 3   | TRAP  | RETI | HALT    | (blank) | LDSR  | STSR  | (blank) | Bstr  | II      |
| 4   |       |      |         | Bcond   |       |       |         |       | III     |
| 5   | MOVEA | ADDI | JR      | JAL     | ORI   | ANDI  | XORI    | MOVHI | IV, V   |
| 6   | LD.B  | LD.H | (blank) | LD.W    | ST.B  | ST.H  | (blank) | ST.W  | VI      |
| 7   | IN.B  | IN.H | CAXI    | IN.W    | OUT.B | OUT.H | Fpp     | OUT.W | VI, VII |

Branch instruction condition-code map (b) is indexed by bit 12 down the rows against bits 11..9 across the columns. [Appendix C(b), p.143]

| Row | 0   | 1       | 2       | 3   | 4  | 5   | 6   | 7   |
| --- | --- | ------- | ------- | --- | -- | --- | --- | --- |
| 0   | BV  | BC/BL   | BZ/BE   | BNH | BN | BR  | BLT | BLE |
| 1   | BNV | BNC/BNL | BNZ/BNE | BH  | BP | NOP | BGE | BGT |

Bit string manipulation sub-op code map (c) is indexed by bits 4..3 down the rows against bits 2..0 across the columns. [Appendix C(c), p.143]

| Row | 0       | 1       | 2       | 3       | 4      | 5       | 6       | 7      |
| --- | ------- | ------- | ------- | ------- | ------ | ------- | ------- | ------ |
| 0   | SCH0BSU | SCH0BSD | SCH1BSU | SCH1BSD |        |         |         |        |
| 1   | ORBSU   | ANDBSU  | XORBSU  | MOVBSU  | ORNBSU | ANDNBSU | XORNBSU | NOTBSU |

Floating-point operation sub-op code map (d) is indexed by bits 31..29 down the rows against bits 28..26 across the columns. Rows 2 through 7 are blank. [Appendix C(d), p.143]

| Row | 0      | 1 | 2      | 3       | 4      | 5      | 6      | 7      |
| --- | ------ | - | ------ | ------- | ------ | ------ | ------ | ------ |
| 0   | CMPF.S |   | CVT.WS | CVT.SW  | ADDF.S | SUBF.S | MULF.S | DIVF.S |
| 1   |        |   |        | TRNC.SW |        |        |        |        |

## Specifications and procedures

- Instruction format bit layouts (Format I through Format VII) as given in §5.1 and consistently used in the §5.3 op code diagrams are recorded above under "5.1 Instruction Format". [§5.1, pp.29–30]
- Full system register number table (0–7, 24, 25, with 8–23 and 26–31 reserved) and LDSR/STSR accessibility is recorded above under "System register numbers". [§2.2.9, p.15]
- Full exception code / handler address / restore PC table is recorded above under Table 6-1. [Table 6-1, p.117]
- Exception, maskable interrupt, and NMI processing step sequences are recorded above under Chapter 6. [§6.1, §6.2.1, §6.2.2, pp.118–121]
- The cache inspection procedure steps <1> through <7> are recorded above under Chapter 7. [CHAPTER 7 (2), p.126]
- Register status after reset is recorded above under Table 9-1. [Table 9-1, p.131]

## Constraints and requirements

- Bit 0 of the PC is fixed to 0 and execution cannot branch to an odd address. [§2.1.2, p.7]
- EIPC bit 0, FEPC bit 0, and bits 31–20, 11, 10 of EIPSW and FEPSW are fixed to 0. [§2.2.1, §2.2.2, p.8]
- ECR cannot be written with LDSR. PIR cannot be written with LDSR. TKCW cannot be written with LDSR. [§2.2.3, §2.2.5, §2.2.6, pp.9–13]
- ICR, ICD, ICE, and ICC in the CHCW "must be exclusively set to 1". [§2.2.7, p.14]
- To make the cache active, the ICHEEN signal must be made active in addition to setting the CHCW ICE bit. [§2.2.7 Note 2, p.14]
- All cache entries must eventually be cleared when using the CEN/CEC piecewise clearing approach. [CHAPTER 7 (2), p.126]
- Word data must be aligned at the word boundary and halfword data at the halfword boundary. Unaligned accesses have the low address bits automatically masked to 0. [§3.2, p.20]
- Unused instruction fields are reserved for future expansion and must be fixed to 0. [§5.1, p.29]
- Operation is not guaranteed if a reserved system register is accessed, and not guaranteed if LDSR targets a reserved or write-disabled system register or if STSR targets a reserved system register. [§2.2.9, p.15; §5.3 LDSR p.68; §5.3 STSR p.95]
- EIPC and EIPSW must be saved by program if multiplexed exception or interrupt is enabled, since only one set exists. [§2.2.1, p.8]
- The maskable interrupt of level n = 15 cannot be disabled by the interrupt enable level. [§6.2.1, p.119]
- A maskable interrupt is held internally during cache restore/dump/clear only when PSW.EP, PSW.NP, and PSW.ID are all 0. [§2.2.7 Note 1, p.14; CHAPTER 7 (2), p.126]
- Immediately after reset the interrupt request is not acknowledged. The PSW NP bit must be set to 0 to use interrupts. [§9.2, p.131]
- The rounding mode of the V810 family is stated to be "Toward nearest". [§5.3 ADDF.S p.42; §5.3 SUBF.S p.97]
- The floating-point underflow (FUD) exception and floating-point precision degradation (FPR) exception do not occur in the V810 family. [Table 6-1 Note 5, p.117; Table 6-4 Remark, p.124]
- Software-reserved registers r1–r5: the document directs saving and restoring their contents when they are used as variable registers, and refers to the assembler/compiler manual for details. [§2.1.1(2), p.6]
- The document states the reader is assumed to have general knowledge of electric engineering, logic circuits, and microcomputers. [INTRODUCTION, "How to read this manual"]
- The document states that related documents indicated in the publication may include preliminary versions and that preliminary versions are not marked as such. [INTRODUCTION, "Related documents"]

## Stated gaps and ambiguities

- The document says CVT.WS is Format VII but prints its op code field as `1111110` (7 bits), whereas every other Format VII instruction prints `111110` (6 bits). The document does not reconcile this. [§5.3 CVT.WS, p.57]
- Table 5-9 assigns the same condition code to more than one mnemonic: 0001 to both BL and BC. 1001 to both BNL and BNC. 0010 to both BE and BZ. 1010 to both BNE and BNZ. Appendix C(b) shows these as combined cells (BC/BL, BNC/BNL, BZ/BE, BNZ/BNE). The document does not describe them as distinct encodings. [Table 5-9, p.50; Appendix C(b), p.143]
- The SCH0BS entry's Remarks text describes searching for a "1" and storing "the bit address 1 bit before the 1 found first", and refers to the SCH1BSU and SCH1BSD instructions, although the entry's Operation line states "Finds the first 0 from a specified bit string". The document does not reconcile the two. [§5.3 SCH0BS, pp.86–87]
- The §5.3 OR entry's op code diagram is empty and only the CY and OV flag rows are printed. The S and Z rows are absent. The op code 001100 for OR appears only in Table B-2 and Appendix C(a). [§5.3 OR, p.79; Table B-2, p.142]
- Table B-2 has no row for op code 001110, although Appendix C(a) places XOR at bits 15..13 = 1, bits 12..10 = 6 (= 001110) and the §5.3 XOR entry prints op code 001110. [§5.3 XOR p.103; Table B-2 p.142; Appendix C(a) p.143]
- The CAXI op code diagram prints the bits 4-0 field as `imm5` rather than `reg1`, while the instruction format is `CAXI disp16 [reg1], reg2` and Table B-2 classifies CAXI as Format VI. [§5.3 CAXI, p.51; Table B-2, p.142]
- Table A-1 lists SETF with Format I, while the §5.3 SETF entry states Format II and Table B-2 lists op code 010010 as Format II. The document does not reconcile this. [Table A-1 p.138; §5.3 SETF p.90; Table B-2 p.142]
- Table A-1's SAR row for the `reg1, reg2` operand form is captioned "Arithmetic left shift", while the SAR entry in §5.3 and the `imm5, reg2` row in Table A-1 describe an arithmetic right shift. [Table A-1 p.138; §5.3 SAR p.85]
- The NOTBSU op code diagram in §5.3 prints the bits 4-0 sub-field as `011111`, a 6-bit value in a 5-bit field, while Appendix C(c) places NOTBSU at bits 4..3 = 1, bits 2..0 = 7. [§5.3 NOTBSU p.78; Appendix C(c) p.143]
- Table 5-11 as printed does not list clock cycles for ST.H, IN.H, or OUT.H, nor for LD.W / ST.W / IN.W / OUT.W in 16-bit bus mode in every row, nor a not-taken cycle count for Bcond (only "taken = 3"). [Table 5-11, pp.107–109]
- Table 5-12 (32-bit bus, part 1) carries a row group labelled "SCH2BSU", a mnemonic that appears nowhere else in the document. §5.4.2 states the table covers SCH0BSU, SCH1BSU, SCH0BSD, and SCH1BSD. [Table 5-12(a), pp.110–111]
- The 16-bit-bus half of Table 5-12 (part 4/4) is cut off partway through the row list in the source file. [Table 5-12(b) 2/2, p.113]
- Table 5-13 is introduced as showing minimum execution clock cycles "without cache hit, no hazard, and no wait", whereas Tables 5-11 and 5-12 are introduced as showing minimum cycles "with cache hit". The document does not explain the difference. [§5.4.1 p.107; §5.4.2 p.110; §5.4.3 p.114]
- Table 6-4 labels one row "FTV" in a table whose legend defines FIV (floating-point invalid operation) and no FTV. [Table 6-4, p.124]
- Table 6-1 gives FIV the exception code FF70 but the handler address FFFFFF60H, unlike the other rows where the low bits of the code and handler address agree. The document does not comment on this. [Table 6-1, p.117]
- Fig. 4-1 Memory Map, Fig. 4-2 I/O Map, Fig. 2-2 System Registers, Fig. 7-1 Cache Configuration, and Fig. 7-2 Cache Dump Format are present only as image references in the source file. Their contents are not available as text. [pp.8, 22, 23, 125, 127]
- Table 5-2 lists MOVHI, ADDI, and MOVEA all with the function name "Add", without distinguishing them at that point in the text. [Table 5-2, p.32]
- Table 5-1 states that load/store instructions "transfer data from the memory to the register", without separately characterising the store direction. [§5.2(1), p.31]
- The V810 family is described as having "16 levels of high-speed interrupt responses" in §1.1, and Table 6-1 lists INT level n for n = 0–15. The document does not define the pins or sources behind those levels beyond referring to the INT input. [§1.1 p.2; Table 6-1 p.117; §6.2.1 p.119]
- Signal and pin names appear only incidentally: RESET (pin), ICHEEN (signal), ST1, ST0, and MRQ (signals used to indicate machine fault status), INT (input), and NMI (input). The document does not give a pin list, directing readers to the hardware manual instead. [§2.2.7 Note 2 p.14; §5.3 TRAP p.99; §6.2.1 p.119; §6.2.2 p.121; §9.1 p.131; INTRODUCTION]
