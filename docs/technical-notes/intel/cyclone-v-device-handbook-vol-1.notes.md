# Notes: Cyclone V Device Handbook, Volume 1: Device Interfaces and Integration

## Source

- File: `Cyclone_V_Device_Handbook_Vol_1.md` (Markdown transcription of a PDF. Sidecar `Cyclone_V_Device_Handbook_Vol_1_meta.json` holds page/block metadata only)
- Type: reference / device datasheet-companion handbook (vendor FPGA family documentation)
- Extent: 327 pages (page ids 0–326 in the transcription metadata). ~74,000 words. 10 chapters
- Version or date stated in document: every chapter carries the date `2023.10.18`. Per-chapter document numbers: CV-52001 (ch.1), CV-52002 (ch.2), CV-52003 (ch.3), CV-52004 (ch.4), CV-52005 (ch.5), CV-52006 (ch.6), CV-52007 (ch.7), CV-52008 (ch.8), CV-52009 (ch.9), CV-52010 (ch.10). Each chapter ends with its own revision history, earliest entry "October 2011, 1.0, Initial release".
- Author or publisher stated in document: Intel Corporation. Cover carries the Altera address "101 Innovation Drive San Jose, CA 95134 www.altera.com". Text uses both "Intel" and "Altera" as the recommending party depending on chapter vintage.

## Scope

The handbook documents the device-level interfaces and integration features of the Cyclone V FPGA family: logic fabric (LAB/ALM), embedded memory, variable-precision DSP blocks, clock networks and PLLs, I/O features and termination, external memory interfaces, configuration/design security/remote system upgrade, SEU mitigation, JTAG boundary-scan testing, and power management. Coverage spans six variants, Cyclone V E, GX, GT, SE, SX and ST, where SE, SX, and ST are the SoC variants containing a hard processor system (HPS).

The document explicitly defers several classes of information elsewhere: transceiver details to *Cyclone V Device Handbook Volume 2: Transceivers*. All electrical/timing specifications (POR delay, tRAMP, tCD2UM, DLL frequency ranges, programmable IOE delay values, TCCS/SW values, battery specs, absolute maximum ratings) to the *Cyclone V Device Datasheet*. Per-package pin assignments to the *Cyclone V Device Pin-Out Files* and *Pin Connection Guidelines*. Multiplier counts and per-package hard-memory-controller availability to the *Cyclone V Device Overview*. And memory-controller usage detail to the *External Memory Interface Handbook*. Each chapter links to a "Cyclone V Device Handbook: Known Issues" knowledge-base article that lists planned updates.

## Key concepts

- **ALM (adaptive logic module).** The basic building block of the LAB, configurable for logic, arithmetic, and register functions. [p.1-1]
- **LAB (logic array block).** A configurable logic block containing a group of ALMs plus dedicated logic driving control signals to those ALMs. [p.1-1]
- **MLAB.** A memory LAB. A superset of the LAB that includes all LAB features and can be used as memory. A quarter of the available LABs in Cyclone V devices can be used as MLAB. [p.1-1, p.1-2]
- **M10K block.** 10 Kb block of dedicated memory resource, described as ideal for larger memory arrays with a large number of independent ports. [p.2-1]
- **Variable precision DSP block.** DSP block supporting 9-bit, 18-bit, and 27-bit word lengths with pre-adder, internal coefficient bank, accumulator, and chainout adder. [p.3-1]
- **GCLK / RCLK / PCLK.** Global clock, regional clock, and periphery clock networks, organized as a hierarchy. [p.4-1]
- **SCLK (section clock).** An additional routing layer ("spine clock") between GCLK/RCLK/PCLK and the per-LAB-row clock routing. [p.4-10]
- **Fractional PLL.** PLL that can function as either a fractional PLL or an integer PLL, using a delta-sigma modulator (DSM) on the M counter for fractional mode. [p.4-19, p.4-38]
- **IOE (I/O element).** Bidirectional I/O buffer plus I/O registers supporting embedded SDR or DDR transfer, located in I/O blocks around the device periphery. [p.5-29]
- **OCT (on-chip termination).** On-chip series (R_S), parallel (R_T), and differential (R_D) termination, with or without calibration. [p.5-38]
- **RZQ pin.** External-reference-resistor pin in each OCT calibration block, connected to GND through an external 100 Ω or 240 Ω resistor. [p.5-47]
- **TCCS (transmitter channel-to-channel skew).** The difference between the fastest and slowest data output transitions, including tCO variation and clock skew. [p.5-80]
- **RSKM (receiver skew margin).** The timing margin between the receiver's clock input and the data input sampling window. [p.5-81]
- **SW (sampling window).** The period of time input data must be stable for the LVDS receiver to sample successfully. A device property that varies with device speed grade. [p.5-81]
- **UniPHY IP.** Self-calibrating physical-layer IP for external memory interfaces. [p.6-12]
- **MPFE (multi-port front end).** The fabric interface through which user logic accesses the hard memory controller. [p.6-36]
- **CvP (configuration via protocol).** Configuration of the FPGA over PCIe through the PCIe hard IP block instead of external flash or ROM. [p.7-2]
- **EMR (error message register).** 67-bit register holding error details for single-bit and double-adjacent errors detected in user mode. [p.8-6]
- **Internal scrubbing.** Internal correction of single-bit and double-adjacent soft errors in user mode without reconfiguration. [p.8-2]
- **BSC (boundary-scan cell).** 3-bit peripheral element of the boundary-scan register associated with an I/O pin. [p.9-11]
- **POR (power-on reset) circuitry.** Circuitry holding the device in reset until monitored power supplies are within the recommended operating range. [p.10-5]

## Content

### Chapter 1: Logic Array Blocks and Adaptive Logic Modules (CV-52001)

- MLAB supports a maximum of 640 bits of simple dual-port SRAM. Each ALM in an MLAB can be configured as a 32 x 2 memory block, producing a 32 x 20 simple dual-port SRAM block. [p.1-2]
- Each LAB can drive 30 ALMs through fast-local and direct-link interconnects: ten ALMs in the given LAB and ten in each of the two adjacent LABs. [p.1-3]
- Neighbouring LABs, MLABs, M10K blocks, or DSP blocks from the left or right can drive a LAB's local interconnect through the direct link connection. [p.1-3]
- Each LAB has two unique clock sources and three clock enable signals. The LAB control block generates up to three clocks from them, and an inverted clock source counts as an individual clock source. [p.1-4]
- De-asserting a clock enable signal turns off the corresponding LAB-wide clock. [p.1-4]
- One ALM contains four programmable registers. Each register has data, clock, synchronous and asynchronous clear, and synchronous load ports. [p.1-5]
- Global signals, GPIO pins, or internal logic can drive an ALM register's clock and clear control signals. GPIO pins or internal logic drive the clock enable signal. [p.1-5]
- Two ALM outputs can drive column, row, or direct link routing connections, and one of those two can also drive local interconnect resources. [p.1-6]
- Register packing allows unrelated register and combinational logic to be packed into a single ALM. The register output can also feed back into the LUT of the same ALM. [p.1-6]
- The ALM operates in one of four modes: normal, extended LUT, arithmetic, shared arithmetic. [p.1-8]
- Normal mode implements two functions in one ALM or a single function of up to six inputs, with up to eight data inputs from the LAB local interconnect. [p.1-8]
- Extended LUT mode implements a 7-input function. If that function is unregistered, the unused eighth input is available for register packing. [p.1-8]
- Arithmetic mode uses two sets of two 4-input LUTs with two dedicated full adders, and provides resource savings of up to 50% for functions that can use the mode. [p.1-8]
- The two-bit carry select feature halves the propagation delay of carry chains within the ALM. [p.1-9]
- Carry chains can begin in either the first ALM or the fifth ALM in a LAB. [p.1-9]
- The Intel Quartus Prime Compiler creates carry chains longer than 20 ALMs (10 ALMs in arithmetic or shared arithmetic mode) by linking LABs together automatically. A carry chain can continue as far as a full column. [p.1-9]
- Shared arithmetic mode configures the ALM with four 4-input LUTs, each computing either the sum or the carry of three inputs, implementing a 3-input add. [p.1-10]
- The shared arithmetic chain can begin in either the first or sixth ALM in a LAB. [p.1-10]
- In every LAB the column is top-half bypassable. In MLAB, columns are bottom-half bypassable. [p.1-10]
- Chapter revision history spans October 2011 (v1.0, initial release) to August 2016 (2016.08.24, description of clock source added to the LAB Control Signals section). [p.1-11]

### Chapter 2: Embedded Memory Blocks (CV-52002)

- Cyclone V devices contain two memory block types: 10 Kb M10K blocks and 640-bit MLABs. [p.2-1]
- Each MLAB is made up of ten ALMs, configurable as ten 32 x 2 blocks giving one 32 x 20 simple dual-port SRAM block per MLAB. [p.2-1]
- MLABs are described as optimized for shift registers in DSP applications, wide shallow FIFO buffers, and filter delay lines. [p.2-1]
- Embedded memory capacity, Cyclone V E. [Table 2-1, p.2-1]

  | Device | M10K blocks | M10K Kb | MLAB blocks | MLAB Kb | Total Kb |
  | ------ | ----------- | ------- | ----------- | ------- | -------- |
  | A2     | 176         | 1,760   | 314         | 196     | 1,956    |
  | A4     | 308         | 3,080   | 485         | 303     | 3,383    |
  | A5     | 446         | 4,460   | 679         | 424     | 4,884    |
  | A7     | 686         | 6,860   | 1338        | 836     | 7,696    |
  | A9     | 1,220       | 12,200  | 2748        | 1,717   | 13,917   |

- Embedded memory capacity, Cyclone V GX. [Table 2-1, p.2-2]

  | Device | M10K blocks | M10K Kb | MLAB blocks | MLAB Kb | Total Kb |
  | ------ | ----------- | ------- | ----------- | ------- | -------- |
  | C3     | 135         | 1,350   | 291         | 182     | 1,532    |
  | C4     | 250         | 2,500   | 678         | 424     | 2,924    |
  | C5     | 446         | 4,460   | 678         | 424     | 4,884    |
  | C7     | 686         | 6,860   | 1338        | 836     | 7,696    |
  | C9     | 1,220       | 12,200  | 2748        | 1,717   | 13,917   |

- Embedded memory capacity, Cyclone V GT. [Table 2-1, p.2-2]

  | Device | M10K blocks | M10K Kb | MLAB blocks | MLAB Kb | Total Kb |
  | ------ | ----------- | ------- | ----------- | ------- | -------- |
  | D5     | 446         | 4,460   | 679         | 424     | 4,884    |
  | D7     | 686         | 6,860   | 1338        | 836     | 7,696    |
  | D9     | 1,220       | 12,200  | 2748        | 1,717   | 13,917   |

- Embedded memory capacity, Cyclone V SE. [Table 2-1, p.2-2]

  | Device | M10K blocks | M10K Kb | MLAB blocks | MLAB Kb | Total Kb |
  | ------ | ----------- | ------- | ----------- | ------- | -------- |
  | A2     | 140         | 1,400   | 221         | 138     | 1,538    |
  | A4     | 270         | 2,700   | 370         | 231     | 2,460    |
  | A5     | 397         | 3,970   | 768         | 480     | 4,450    |
  | A6     | 553         | 5,530   | 994         | 621     | 6,151    |

  Cyclone V SX C2, C4, C5, C6 carry the same figures as SE A2, A4, A5, A6 respectively. Cyclone V ST D5 matches SE A5 and D6 matches SE A6.
- The Intel Quartus Prime software automatically partitions user-defined memory into memory blocks based on the design's speed and size constraints. The RAM IP core in the IP Catalog assigns memory to a specific block size manually. [p.2-2]
- Single-port SRAM in an MLAB is implemented through emulation by the Intel Quartus Prime software, with minimal additional use of logic resources. [p.2-2]
- Because of the MLAB's dual-purpose architecture, only data input and output registers are available in the block. MLABs gain read address registers from the ALMs, while write address and read data registers are internal to the MLAB. [p.2-2]
- In true dual-port RAM mode two write operations to the same memory location are possible, but the memory blocks have no internal conflict resolution circuitry. The document instructs implementing external conflict resolution logic to avoid unknown data being written. [p.2-3]
- Same-port read-during-write applies to a single-port RAM or the same port of a true dual-port RAM. Available output modes are a "new data" mode (M10K) and a "don't care" mode (M10K, MLAB). [Table 2-2, p.2-3]
- Mixed-port read-during-write applies to simple and true dual-port RAM modes where two ports read and write the same address on the same clock. Output modes listed are "new data" (MLAB), "old data" (M10K, MLAB), and "don't care" (M10K, MLAB). [Table 2-3, p.2-4]
- In dual-port RAM mode, mixed-port read-during-write is supported if the input registers share the same clock, and the output value during the operation is "unknown". [p.2-5]
- By default the Intel Quartus Prime software initializes RAM cells to zero unless a `.mif` is specified. All memory blocks support `.mif` initialization, and even a pre-initialized memory powers up with its output cleared. [p.2-7]
- Maximum operating frequency is 315 MHz for M10K and 420 MHz for MLAB. Capacity per block including parity bits is 10,240 bits for M10K and 640 bits for MLAB. [Table 2-5, p.2-7]
- Packed mode, simple dual-port mixed width, true dual-port mixed width, and FIFO buffer mixed width are supported on M10K only, not on MLAB. [Table 2-5, p.2-8]
- Asynchronous memory is supported on MLAB only for flow-through read. M10K does not support it. [Table 2-5, p.2-8]
- Write and read operations are triggered on rising clock edges for both M10K and MLAB. [Table 2-5, p.2-8]
- Maximum single-port RAM / ROM configurations: MLAB 32 deep at x16, x18, or x20. 256 deep at x40 or x32. 512 at x20 or x16. 1K at x10 or x8. 2K at x5 or x4. 4K at x2. 8K at x1. [Table 2-6, p.2-9]
- MLABs do not support mixed-width port configurations. [p.2-9]
- M10K mixed-width configurations pair 8K x 1, 4K x 2, 2K x 4, 1K x 8, 512 x 16, and 256 x 32 with each other, and separately pair 2K x 5, 1K x 10, 512 x 20, and 256 x 40 with each other, in both simple dual-port and true dual-port mode. [Tables 2-7 and 2-8, p.2-9 to p.2-10]
- Supported memory modes are single-port RAM, simple dual-port RAM, true dual-port RAM (M10K only), shift-register, ROM, and FIFO. MLAB supports all except true dual-port RAM. [Table 2-9, p.2-10 to p.2-11]
- MLABs do not support mixed-width FIFO mode. The SCFIFO and DCFIFO IP cores implement single- and dual-clock asynchronous FIFO buffers. [Table 2-9, p.2-11]
- Clocking-mode support: single clock mode in all memory modes. Read/write clock mode only in simple dual-port and FIFO. Input/output clock mode in single-port, simple dual-port, true dual-port, and ROM. Independent clock mode only in true dual-port and ROM. [Table 2-10, p.2-12]
- Clock enable signals are not supported for write address, byte enable, and data input registers on MLAB blocks. [p.2-12]
- Read/write clock mode: the read clock controls data-output, read-address, and read-enable registers. The write clock controls data-input, write-address, write-enable, and byte enable registers. [p.2-13]
- Input/output clock mode: the input clock controls all registers related to data input including data, address, byte enables, read enables, and write enables. The output clock controls the data output registers. [p.2-13]
- In all clocking modes, asynchronous clears are available only for output latches and output registers. For independent clock mode this applies on both ports. [p.2-13]
- A simultaneous read/write to the same address in read/write clock mode produces unknown output read data. Single-clock or input/output clock mode with a selected read-during-write behaviour is required for a known value. [p.2-13]
- MLAB memory blocks support simultaneous read/write operations only in single clock mode. [p.2-13]
- Independent clock enables are supported in read/write clock mode (both read and write clocks) and in independent clock mode (registers of both ports). [p.2-13]
- Parity-bit support is described with two variants: one where the parity bit is the fifth bit associated with each 4 data bits in data widths of 5, 10, 20, and 40 (bits 4, 9, 14, 19, 24, 29, 34, and 39), with parity bits skipped during read or write in non-parity data widths. And one where the parity bit is the ninth bit associated with each byte and can store a parity bit or serve as an additional bit. In both, the parity function is not performed on the parity bit. [Table 2-11, p.2-14]
- Byte enable controls mask input data so only specific bytes are written. Unwritten bytes retain previously written values. [p.2-14]
- The `byteena` signal is high (enabled) by default, so `wren` alone controls writing by default. Byte enables are active high. The byte enable registers have no clear port. The MSB and LSB of `byteena` correspond to the MSB and LSB of the data bus. [p.2-14]
- With parity bits in use, the byte enable function controls 8 data bits and 2 parity bits on M10K blocks, and all 10 bits in the widest mode on MLABs. [p.2-14]
- `byteena[1:0]` in x20 data width: `11` (default) writes [19:10] and [9:0]. `10` writes [19:10]. `01` writes [9:0]. [Table 2-12, p.2-14]
- `byteena[3:0]` in x40 data width: `1111` (default) writes [39:30], [29:20], [19:10], [9:0]. `1000` writes [39:30]. `0100` writes [29:20]. `0010` writes [19:10]. `0001` writes [9:0]. [Table 2-13, p.2-14 to p.2-15]
- In M10K blocks the masked data byte output appears as a "don't care" value. In MLABs it appears as either a "don't care" value or the current data at that location, controllable through the Intel Quartus Prime software. [p.2-15]
- Packed mode (M10K only) packs two independent single-port RAM blocks into one memory block by placing the physical RAM in true dual-port mode and using the MSB of the address to distinguish the two logical RAMs. Each independent single-port RAM must not exceed half the target block size. [p.2-16]
- Address clock enable, port name `addressstall`, holds the previous address value for as long as the signal is enabled (`addressstall = 1`). Default value is low (disabled). In dual-port mode each port has its own independent address clock enable. [p.2-16]
- Revision entry 2015.01.23 records that Cyclone V GX C3 figures were updated from 119 to 135 M10K blocks, 1,190 to 1,350 M10K Kb, 255 to 291 MLAB blocks, 159 to 181 MLAB Kb, and 1,349 to 1,531 total Kb. [p.2-18 to p.2-19]

### Chapter 3: Variable Precision DSP Blocks (CV-52003)

- Stated DSP block features. [p.3-1]

  - fully registered multiplication
  - 9-bit, 18-bit, and 27-bit word lengths
  - Two 18 x 19 complex multiplications
  - Built-in addition, subtraction, and dual 64-bit accumulation
  - Cascading 19-bit or 27-bit tap-delay line
  - Cascading 64-bit output bus between blocks without external logic
  - Hard pre-adder in 19-bit and 27-bit mode for symmetric filters
  - Internal coefficient register bank
  - 18-bit and 27-bit systolic FIR filters with distributed output adder
- When the pre-adder feature is enabled, input cascade support is not available. [footnote 1, p.3-2; p.3-4]
- Multiplier resources per device, Cyclone V E. [Table 3-2, p.3-2 to p.3-3]

  | Device | DSP blocks | 9 x 9 | 18 x 18 | 27 x 27 | 18 x 18 multiplier-adder | 18 x 18 summed with 36-bit input |
  | ------ | ---------- | ----- | ------- | ------- | ------------------------ | -------------------------------- |
  | A2     | 25         | 75    | 50      | 25      | 25                       | 25                               |
  | A4     | 66         | 198   | 132     | 66      | 66                       | 66                               |
  | A5     | 150        | 450   | 300     | 150     | 150                      | 150                              |
  | A7     | 156        | 468   | 312     | 156     | 156                      | 156                              |
  | A9     | 342        | 1,026 | 684     | 342     | 342                      | 342                              |

- Multiplier resources, Cyclone V GX. The notes record four columns here where the Cyclone V E entry records six. [Table 3-2, p.3-3]

  | Device | DSP blocks | 9 x 9 | 18 x 18 | 27 x 27 |
  | ------ | ---------- | ----- | ------- | ------- |
  | C3     | 57         | 171   | 114     | 57      |
  | C4     | 70         | 210   | 140     | 70      |
  | C5     | 150        | 450   | 300     | 150     |
  | C7     | 156        | 468   | 312     | 156     |
  | C9     | 342        | 1,026 | 684     | 342     |

  Cyclone V GT D5, D7, D9 match GX C5, C7, C9.
- Multiplier resources, Cyclone V SE. The notes record four columns here where the Cyclone V E entry records six. [Table 3-2, p.3-3]

  | Device | DSP blocks | 9 x 9 | 18 x 18 | 27 x 27 |
  | ------ | ---------- | ----- | ------- | ------- |
  | A2     | 36         | 108   | 72      | 36      |
  | A4     | 84         | 252   | 168     | 84      |
  | A5     | 87         | 261   | 174     | 87      |
  | A6     | 112        | 336   | 224     | 112     |

  Cyclone V SX C2, C4, C5, C6 match SE A2, A4, A5, A6. Cyclone V ST D5 matches SE A5 and D6 matches SE A6.
- Supported Intel Quartus Prime IP cores for the DSP block: LPM_MULT, ALTERA_MULT_ADD, ALTMULT_COMPLEX, ALTMEMMULT. [p.3-4]
- To use the pre-adder feature, all input data and multipliers must have the same clock setting. [p.3-4]
- In both 18-bit and 27-bit modes, the coefficient feature and the pre-adder feature can be used independently. [p.3-4]
- Double accumulation registers are 64-bit, located between the output register bank and the accumulator, and are set statically in the programming file. [p.3-4, p.3-8]
- Block architecture elements: input register bank, pre-adder, internal coefficient, multipliers, adder, accumulator and chainout adder, systolic registers, double accumulation register, output register bank. [p.3-4 to p.3-5]
- All registers in the DSP blocks are positive-edge triggered and cleared on power up. Each multiplier operand can feed an input register or a multiplier directly, bypassing the input registers. [p.3-5]
- Input registers are controlled by CLK[2..0], ENA[2..0], and ACLR[0]. [p.3-5]
- The tap-delay line feature drives the top leg of the multiplier input, which is `dataa_y0` and `datab_y1` in 18 x 19 mode and `dataa_y0` only in 27 x 27 mode, from general routing or the cascade chain. [p.3-6]
- Each DSP block has two 19-bit pre-adders, configurable as two independent 19-bit pre-adders or one 27-bit pre-adder. [p.3-7]
- Pre-adder input configurations: 18-bit (signed) addition or subtraction for 18 x 19 mode. 17-bit (unsigned) addition or subtraction for 18 x 19 mode. 26-bit addition or subtraction for 27 x 27 mode. [p.3-7]
- The internal coefficient supports up to eight constant coefficients for the multiplicands in 18-bit and 27-bit modes. COEFSELA/COEFSELB control the coefficient multiplexer selection. [p.3-7]
- There are two multipliers per DSP block, configurable as one 27 x 27 multiplier, two 18 (signed/unsigned) x 19 (signed) multipliers, or three 9 x 9 multipliers. [p.3-8]
- Adder sizing by mode: one 64-bit adder with the 64-bit accumulator. Two 37-bit adders for two 18 x 19 multiplications. Three 18-bit adders for three 9 x 9 multiplication results. [p.3-8]
- The DSP block supports a 64-bit accumulator and a 64-bit adder, dynamically controlled by NEGATE, LOADCONST, and ACCUMULATE. [p.3-8]
- Accumulator function encoding: zeroing (disables the accumulator) is NEGATE 0, LOADCONST 0, ACCUMULATE 0. Loading an initial value uses NEGATE 0, LOADCONST 1, ACCUMULATE 0 (only one bit of the 64-bit preload value may be set). The remaining rows are NEGATE 0 / LOADCONST X / ACCUMULATE 1 and NEGATE 1 / LOADCONST X / ACCUMULATE 1. [Table 3-3, p.3-8 to p.3-9]
- The accumulator and chainout adder features are not supported in two independent 18 x 19 modes and three independent 9 x 9 modes. [p.3-8]
- There are two systolic registers per DSP block. The first set consists of 18-bit and 19-bit registers registering the 18-bit and 19-bit inputs of the upper multiplier, the second set delays the chainout output to the next DSP block. All systolic registers must be clocked with the same clock source as the output register bank, and both are bypassed when the block is not in systolic FIR mode. [p.3-5, p.3-9]
- Enabling the double accumulation register causes an extra clock cycle delay in the accumulator feedback path. The register shares CLK, ENA, and ACLR settings with the output register bank, and enables two accumulator channels using the same number of DSP blocks. [p.3-9]
- The 64-bit bypassable output register bank is triggered on the positive clock edge, cleared after power up, and controlled by CLK[2..0], ENA[2..0], and ACLR[1]. [p.3-9]
- Independent multiplier mode configurations and multipliers per block: 9 x 9 → 3. 18 x 25 → 1. 20 x 24 → 1. 27 x 27 → 1. [Table 3-4, p.3-10]
- In three 9 x 9 independent multiplier mode, three pairs of data are packed into the `ax` and `ay` ports and the result contains three 18-bit products. [p.3-11]
- For the two-multiplier independent mode, n = 19 and m = 37 for 18 x 19 mode. N = 18 and m = 36 for 18 x 18 mode. [p.3-11]
- In 18 x 25 and 20 x 24 independent multiplier modes the result can be up to 52 bits when combined with a chainout adder or accumulator. In 27 x 27 mode it can be up to 64 bits. [p.3-12, p.3-13]
- The 18 x 19 complex multiplier mode uses two DSP blocks: the imaginary part [(a × d) + (b × c)] is implemented in the first block and the real part [(a × c) − (b × d)] in the second. [p.3-13]
- For 18 x 18 multiplication summed with a 36-bit input, the upper multiplier provides the 18 x 18 multiplication while the bottom multiplier is bypassed, and `datab_y1[17..0]` and `datab_y1[35..18]` are concatenated to produce the 36-bit input. [p.3-15]
- In systolic FIR mode the multiplier input can come from four source sets: two dynamic inputs. One dynamic input and one coefficient input. One coefficient input and one pre-adder output. One dynamic input and one pre-adder output. [p.3-16]
- 18-bit systolic FIR mode configures the adders as dual 44-bit adders, giving 8 bits of overhead over 36-bit products, allowing a total of 256 multiplier products. [p.3-16]
- 27-bit systolic FIR mode configures the chainout adder or accumulator for 64-bit operation, giving 10 bits of overhead over 54-bit products, allowing a total of 1,024 multiplier products, and implements one stage of systolic filter per DSP block. [p.3-17]

### Chapter 4: Clock Networks and PLLs (CV-52004)

- Cyclone V devices contain three clock network types organized hierarchically: global clock (GCLK), regional clock (RCLK), and periphery clock (PCLK) networks. [p.4-1]
- Dedicated clock input pins are CLK[0..11][p,n] on the larger Cyclone V E, GX, and GT devices and CLK[0..7][p,n] on the SE, SX, and ST devices. Cyclone V E A2 and A4 and Cyclone V GX C3 provide only CLK[0..3][p,n], CLK[6][p,n], and CLK[8..11][p,n], while the corresponding restricted SoC set is CLK[0..3][p,n] and CLK[6,7][p,n]. [Table 4-1, p.4-2 to p.4-3]
- GCLKs can drive throughout the device and serve as low-skew clock sources for ALMs, DSP, embedded memory, and PLLs. IOEs and internal logic can also drive GCLKs to create internally generated global clocks and high fan-out control signals. [p.4-4]
- RCLK networks apply only to the quadrant they drive into and provide the lowest clock insertion delay and skew for logic contained within a single device quadrant. [p.4-6]
- Cyclone V devices provide only horizontal PCLKs from the left periphery. PCLKs have higher skew than GCLK and RCLK networks and can be used for general purpose routing. [p.4-8]
- PLD-transceiver interface clocks, horizontal I/O pins, and internal logic can drive the PCLK networks. [p.4-8]
- Cyclone V devices provide 30 section clock (SCLK) networks in each spine clock per quadrant. SCLK networks can drive six row clocks in each LAB row, nine column I/O clocks, and two core reference clocks. [p.4-10]
- GCLK, RCLK, PCLK, and PLL feedback clocks share the same routing to the SCLKs, and the total number of clock resources must not exceed the SCLK limits in each region for the design to fit. [p.4-10]
- The entire device clock region has the maximum insertion delay compared with other clock regions but reaches every destination. The document names it a good option for global reset and clear signals. [p.4-11]
- A dual-regional clock region is formed by a single source (a clock pin or PLL output) driving two RCLK networks, one from each quadrant. Routing this signal on an entire side has approximately the same delay as an RCLK region. [p.4-11]
- Dual-regional clock region is only supported for quadrant 3 and quadrant 4 in Cyclone V SE, SX, and ST devices. [p.4-11]
- When CLK pins are used as single-ended clock inputs, only the CLK<#>p pins have dedicated connections to the PLL. CLK<#>n pins drive PLLs over global or regional clock networks with no dedicated routing path. Altera recommends the CLK<#>p pins for optimal performance in that case. [p.4-12]
- Internally generated GCLKs, RCLKs, or PCLKs cannot drive the Cyclone V PLLs. The PLL input clock must come from dedicated clock input pins, PLL-fed GCLKs, or PLL-fed RCLKs. [p.4-12]
- Every three HSSI outputs generate a group of four PCLKs to the core. [p.4-13]
- Dedicated clock input pin to GCLK connectivity for E, GX, and GT devices: GCLK[0,1,2,3,4,5,6,7] ← CLK[0,1,2,3]. GCLK[8,9,10,11] ← CLK[4,5,6,7] (only CLK[6] is available on E A2, E A4, and GX C3). GCLK[0,1,2,3,12,13,14,15] ← CLK[8,9,10,11]. [Table 4-2, p.4-13]
- Dedicated clock input pin to GCLK connectivity for SE, SX, and ST devices: GCLK[0,1,2,3,4,5,6,7] ← CLK[0,1,2,3]. GCLK[8,9,10,11] ← CLK[4,5] (not applicable to SE A2, SE A4, SX C2, SX C4). GCLK[0,1,2,3,12,13,14,15] ← CLK[6,7]. [Table 4-3, p.4-13]
- A given clock input pin can drive two adjacent RCLK networks to create a dual-regional clock network. Tables 4-4 and 4-5 list the explicit RCLK index sets reachable from each CLK pin. [p.4-13 to p.4-14]
- Every GCLK, RCLK, and PCLK network has its own clock control block, providing clock source selection (dynamic selection only for GCLKs), global clock multiplexing, and clock power down (static or dynamic clock enable/disable only for GCLKs and RCLKs). [p.4-15]
- Clock control block input mapping: `inclk[0]` and `inclk[1]` are fed by any of the four dedicated clock pins on the same side of the device. `inclk[2]` by PLL counters `c0` and `c2` from PLLs on the same side (top, bottom, right) or PLL counter `c4` (left side). `inclk[3]` by PLL counters `c1` and `c3` (top, bottom, right) and is not connected for the clock control block on the left side. [Table 4-6, p.4-15]
- When the GCLK clock source is selected dynamically, up to two PLL counter outputs and up to two clock pins can be selected. [p.4-15]
- The RCLK select block clock source can only be controlled statically, using configuration bit settings in the `.sof` or `.pof` file. [p.4-16]
- Input clock sources and `clkena` signals for the GCLK and RCLK network multiplexers are set through the ALTCLKCTRL IP core. With dynamic selection, inputs are chosen using the CLKSELECT[0..1] signal, with clock pins feeding `inclk[0..1]` and PLL outputs feeding `inclk[2..3]`. [p.4-16]
- Unused GCLK, RCLK, and PCLK networks are automatically powered down through configuration bit settings in the `.sof` or `.pof` file. [p.4-17]
- GCLK or RCLK networks that drive PLLs cannot be dynamically enabled or disabled, and the clock enable/disable circuit of the clock control block cannot be used when the GCLK or RCLK output drives a PLL input. [p.4-17, p.4-18]
- The `clkena` signal is synchronous to the falling edge of the clock output. `clkena` signals are supported at the clock network level rather than at the PLL output counter level, so the clock can be gated off without a PLL. [p.4-18]
- Cyclone V devices have an additional metastability register aiding asynchronous enable and disable of the GCLK and RCLK networks, optionally bypassable in the Intel Quartus Prime software. [p.4-18]
- The PLL can remain locked independent of the `clkena` signals because the loop-related counters are not affected. [p.4-18]
- The Cyclone V family contains fractional PLLs that can function as fractional or integer PLLs, with output counters dedicated to each fractional PLL. The devices offer up to 8 fractional PLLs in the larger densities. [p.4-19]
- PLL features. [Table 4-7, p.4-19 to p.4-20]

  | Feature                              | Support                                                                                          |
  | ------------------------------------ | ------------------------------------------------------------------------------------------------ |
  | Integer PLL                          | yes                                                                                              |
  | Fractional PLL                       | yes                                                                                              |
  | C output counters                    | 9                                                                                                |
  | M, N, C counter sizes                | 1 to 512                                                                                         |
  | Dedicated external clock outputs     | 2 single-ended and 1 differential                                                                |
  | Dedicated clock input pins           | 4 single-ended or 4 differential                                                                 |
  | External feedback input pin          | single-ended or differential                                                                     |
  | Spread-spectrum input clock tracking | yes                                                                                              |
  | Compensation modes                   | source synchronous, direct, normal, zero-delay buffer, external feedback, and LVDS all supported |
  | Phase shift resolution               | 78.125 ps                                                                                        |
  | Programmable duty cycle              | yes                                                                                              |
  | Power down mode                      | yes                                                                                              |
- The smallest phase shift is the VCO period divided by eight. For degree increments the device can shift all output frequencies in increments of at least 45°, with smaller increments possible depending on frequency and divide parameters. [footnote 6, p.4-20]
- Spread-spectrum input clock tracking is qualified: input clock jitter must be within input jitter tolerance specifications and the modulation frequency of the input clock must be below the PLL bandwidth specified in the Fitter report. [footnote 5, p.4-20]
- Physical counters for the fractional PLLs are arranged in up-to-down and down-to-up sequences. [p.4-20]
- Cyclone V devices provide a PLL for each group of three transceiver channels, located in a strip. For a PLL in the strip only counters C[4..8] are used in a clock network, while C[0..3] support high-speed HSSI requirements. Transceivers can only use the PLLs located in the strip. [p.4-21]
- Physical locations of the fractional PLLs correspond to the coordinates in the Intel Quartus Prime Chip Planner. Figures 4-16 to 4-22 give the per-density PLL location maps. [p.4-21 to p.4-27]
- For design migration between Cyclone V SX C2, C4, C5, and C6 devices where a PLL must drive both HSSI and a clock network, the document instructs using the PLLs on the left side of the device. The left-side PLL location is FRACTIONALPLL_X0_Y14 for C2, C4, and C5 and FRACTIONALPLL_X0_Y32 for C6. [Table 4-8, p.4-27]
- One fractional PLL can use up to 9 output counters and all external clock outputs. [p.4-28]
- Two PLL cascading types are supported: PLL-to-PLL cascading (expands the effective range of the pre-scale counter N and multiply counter M. Cyclone V devices use only the `adjpllin` input clock source for inter-cascading between fracturable fractional PLLs) and counter-output-to-counter-output cascading (expands the effective range of C counters). [p.4-28 to p.4-29]
- Altera recommends a low bandwidth setting for the source (upstream) PLL and a high bandwidth setting for the destination (downstream) PLL when cascading. [p.4-28]
- Two external clock output pins are associated with each corner fractional PLL, organized as one of the following. [p.4-29]

  - two single-ended clock outputs
  - One differential clock output
  - Two single-ended clock outputs plus one single-ended clock input in the I/O driver feedback for ZDB mode
  - One single-ended clock output plus one single-ended feedback input for single-ended EFB mode
  - One differential clock output plus one differential feedback input for differential EFB
  - External clock output support depends on device density and package
- Any of the output counters C[0..8] or the M counter can feed the dedicated external clock outputs, so one counter or frequency can drive all output pins available from a given PLL. [p.4-29]
- Each pin of a single-ended output pair can be in-phase or 180° out-of-phase. The Intel Quartus Prime software places a NOT gate into the IOE to implement the 180° pin. [p.4-30]
- Clock output pin pairs support the same I/O standard for the pin pair, LVDS, differential HSTL, and differential SSTL. [p.4-30]
- Driving `areset` high resets the PLL counters, clears the PLL output, places the PLL out-of-lock, and returns the VCO to its nominal setting. Driving `areset` low resynchronizes the PLL as it re-locks. [p.4-30 to p.4-31]
- The `areset` signal must be asserted every time the PLL loses lock to guarantee the correct phase relationship between PLL input and output clocks, and must be included if PLL reconfiguration or clock switchover is enabled or if phase relationships must be maintained after loss of lock. [p.4-31]
- If the PLL input clock is not toggling or is unstable after power up, `areset` should be asserted after the input clock is stable and within specifications. [p.4-31]
- The `locked` signal indicates that the PLL has locked onto the reference clock and that PLL clock outputs are operating at the phase and frequency set in the IP Catalog. [p.4-31]
- Six clock feedback modes are described: source synchronous, LVDS compensation, direct, normal compensation, zero-delay buffer (ZDB), and external feedback (EFB). Each allows clock multiplication and division, phase shifting, and programmable duty cycle. [p.4-31]
- Input and output delays are fully compensated only when the dedicated clock input pins associated with a given PLL are used as the clock source. Compensation may be incomplete when a GCLK or RCLK network drives the PLL or when a non-associated dedicated clock pin drives it. [p.4-31]
- Source synchronous mode compensates for the delay of the clock network used and for the difference in delay between the data-pin-to-IOE-register-input path and the clock-input-pin-to-PLL-PFD-input path. Altera recommends it for source synchronous data transfers. [p.4-32]
- LVDS compensation mode maintains the data and clock timing relationship at the internal SERDES capture register except that the clock is inverted (180° phase shift), which the output counter must provide. [p.4-32]
- Direct mode performs no clock network compensation and provides better jitter performance because the clock feedback into the PFD passes through less circuitry. [p.4-33]
- Normal compensation mode phase-aligns an internal clock to the input clock pin and fully compensates the delay introduced by the GCLK or RCLK network. The external clock output pin has a phase delay relative to the clock input pin, reported by the Intel Quartus Prime Timing Analyzer. [p.4-33]
- ZDB mode is supported on all Cyclone V PLLs. It requires the same I/O standard on input clocks and clock outputs, prohibits differential I/O standards on the PLL clock input or output pins, and requires a bidirectional I/O pin assigned a single-ended I/O standard to connect the `fbout` and `fbin` ports. [p.4-34]
- To avoid signal reflection in ZDB mode, board traces must not be placed on the bidirectional feedback I/O pin. [p.4-34]
- In EFB mode the output of the M counter (`fbout`) feeds back to the PLL `fbin` input through a board trace and becomes part of the feedback loop. One dual-purpose external clock output becomes the `fbin` pin, and the same I/O standard must be used on input clock, feedback input, and clock outputs. [p.4-36]
- EFB mode is supported only on the corner fractional PLLs, and for Cyclone V E A2 and A4 and Cyclone V GX C3 only on the left corner fractional PLLs. [p.4-36]
- Each PLL provides clock synthesis using M/(N × C) scaling factors. The input clock is divided by pre-scale factor N then multiplied by feedback factor M, with the control loop driving the VCO to match fin × (M/N). [p.4-37]
- When enabled, the VCO post divider divides the VCO frequency by two. When bypassed, the VCO frequency goes to the output port undivided. [p.4-37]
- For multiple PLL outputs with different frequencies, the VCO is set to the least common multiple of the output frequencies that meets its frequency specifications. The document's example is outputs of 33 and 66 MHz producing a VCO setting of 660 MHz. [p.4-37]
- Each PLL has one pre-scale counter N and one multiply counter M with a range of 1 to 512 for both. The N counter has no duty-cycle control. Post-scale counters have a 50% duty cycle setting. High- and low-count values for each counter range from 1 to 256, and their sum selects the divide value. [p.4-37]
- The delta-sigma modulator (DSM) works with the M counter to enable fractional mode by dynamically changing the M counter divide value cycle to cycle so the average M value is non-integer. [p.4-38]
- In fractional mode the M counter divide value equals the sum of the "clock high" count, "clock low" count, and a fractional value equal to K/2^X, where K is an integer between 0 and (2^X – 1) and X = 8, 16, 24, or 32. In integer mode M is an integer and the DSM is disabled. [p.4-38]
- The minimum programmable phase shift increment is 1/8 of the VCO period. The document's example is a PLL at a VCO frequency of 1000 MHz giving phase shift steps of 125 ps. [p.4-38]
- Programmable duty cycle precision is defined as 50% divided by the post-scale counter value. The document's example is a C0 counter of 10 giving 5% steps for duty-cycle choices from 5% to 90%. In external feedback mode the counter driving the `fbin` pin must be set to a 50% duty cycle. [p.4-38]
- Three clock switchover modes are supported: automatic switchover (clock sense circuit switches to `inclk0` or `inclk1` when the current reference stops toggling), manual clock switchover (controlled by `extswitch` going logic low to logic high and staying high for at least three clock cycles), and automatic switchover with manual override. [p.4-39]
- The clock switchover circuit sends three status signals from the PLL, `clkbad[0]`, `clkbad[1]`, and `activeclock`. [p.4-39]
- `clkbad[0]` and `clkbad[1]` are not valid if the frequency difference between `inclk0` and `inclk1` is greater than 20%. When the difference exceeds 20%, `activeclock` is the only valid status signal. [p.4-40]
- Automatic clock switchover mode requires that both clock inputs are running when the FPGA is configured and that the periods of the two clock inputs differ by no more than 20%. [p.4-40]
- If the current clock input stops toggling while the other clock is also not toggling, switchover is not initiated and the `clkbad[0..1]` signals are not valid. [p.4-40]
- Altera recommends resetting the PLL using `areset` to maintain phase relationships between PLL input and output clocks when using clock switchover. [p.4-40]
- The automatic clock-sense circuitry cannot monitor input clock frequencies with a frequency difference of more than 100% (2×). The document's example of frequencies requiring `extswitch` control is `inclk0` at 66 MHz and `inclk1` at 200 MHz. [p.4-41]
- In automatic override with manual switchover mode, `activeclock` mirrors `extswitch`, neither `clkbad` signal goes high because both clocks remain functional, and the circuit is positive-edge sensitive so the falling edge of `extswitch` does not switch back. [p.4-42]
- In manual clock switchover mode `inclk0` is selected by default. `extswitch` must be brought back low for the PLL to re-gain lock, and pulsing it high for at least three `inclk` cycles performs another switchover event. [p.4-42]
- If `inclk0` and `inclk1` are different frequencies and always running, the minimum `extswitch` high time must be greater than or equal to three cycles of the slower of the two. [p.4-42]
- When a switchover delay is specified in the ALTERA_PLL IP core, `extswitch` must be held high for at least three `inclk` cycles plus the specified number of delay cycles to initiate a switchover. [p.4-43]
- Clock switchover guideline: assert `areset` for at least 10 ns after performing a clock switchover, then wait for `locked` to go high and be stable before re-enabling the PLL output clocks. [p.4-43]
- Clock switchover guideline: applications requiring clock switchover with small frequency drift must use a low-bandwidth PLL, which reacts more slowly to input clock changes but also increases lock time. [p.4-43]
- The VCO frequency gradually decreases when the current clock is lost and then increases as the VCO locks onto the backup clock. [p.4-43]
- PLL reconfiguration and dynamic phase shifting are deferred to AN 661: *Implementing Fractional PLL Reconfiguration with Altera PLL and Altera PLL Reconfig IP Cores*. [p.4-44]
- Revision entry 2019.04.26 records that the signal name was corrected from `clkswitch` to `extswitch`. [p.4-44]

### Chapter 5: I/O Features (CV-52005)

- Listed I/O feature set. [p.5-1]

  - single-ended, non-voltage-referenced, and voltage-referenced I/O standards
  - LVDS, RSDS, mini-LVDS, HSTL, HSUL, and SSTL
  - SERDES
  - Programmable output current strength, slew rate, bus-hold, pull-up resistor, pre-emphasis, I/O delay, and voltage output differential (VOD)
  - Open-drain output
  - R_S OCT with and without calibration
  - R_T OCT
  - R_D OCT
  - High-speed differential I/O support
- Cyclone V E GPIO counts per package. A blank cell means the package is not offered for that device. [Table 5-1, p.5-1]

  | Device    | M383 | U324 | F256 | M484 | U484 | F484 | F672 | F896 |
  | --------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
  | A2 and A4 | 223  | 176  | 128  |      | 224  | 224  |      |      |
  | A5        | 175  |      |      |      | 224  | 240  |      |      |
  | A7        |      |      |      | 240  | 240  | 240  | 336  | 480  |
  | A9        |      |      |      |      | 240  | 224  | 336  | 480  |

- Cyclone V GT transceiver counts are stated for transceivers ≤5 Gbps. 6 Gbps transceiver channel count support depends on package and channel usage and is deferred to Volume 2. [Table 5-3, p.5-2]
- For the SoC variants, the stated HPS I/O counts are the number of I/Os in the HPS and do not correlate with the number of HPS-specific I/O pins in the FPGA. Each HPS-specific pin in the FPGA may be mapped to several HPS I/Os. [Tables 5-4 to 5-6, p.5-3 to p.5-4]
- Cyclone V SE package plan: A2, A4, A5, A6 all list U484 66 FPGA GPIO / 151 HPS I/O and U672 145 FPGA GPIO / 181 HPS I/O. A5 and A6 additionally list F896 288 FPGA GPIO / 181 HPS I/O. [Table 5-4, p.5-3]
- Cyclone V ST D5 and D6 list 288 FPGA GPIO, 181 HPS I/O, and 9 transceivers. [Table 5-6, p.5-3 to p.5-4]
- Vertical migration paths shaded in red are achievable only if no more than 175 GPIOs are used for the M383 package and 138 GPIOs for the U672 package. These paths are not shown in the Intel Quartus Prime Pin Migration View. [p.5-5]
- Migration across device densities in the same package option is possible if the devices have the same dedicated pins, configuration pins, and power pins. [p.5-5]
- Pin migration compatibility is verified with the Pin Migration View window in the Intel Quartus Prime Pin Planner. The documented procedure is: [p.5-6]

  1. create pin assignments in Assignments > Pin Planner
  2. If necessary run Analysis & Elaboration, Analysis & Synthesis, or a full compile to populate node names
  3. Click View > Pin Migration View
  4. Select migration devices via Device > Migration compatibility > Migration Devices
  5. Right-click and use Show Columns for more pin information
  6. Turn on Show migration differences to see only differing pins
  7. Use Pin Finder (with Show only highlighted pins) to find pins by functionality
  8. Click Export to write a `.csv`
- FPGA I/O supported standards include 3.3 V and 3.0 V LVTTL/LVCMOS (JESD8-B), 3.0 V PCI (PCI Rev. 2.2), 3.0 V PCI-X (PCI-X Rev. 1.0), 2.5/1.8/1.5/1.2 V LVCMOS, SSTL-2/-18/-15 Class I and II, 1.8/1.5/1.2 V HSTL Class I and II, their differential forms, LVDS (ANSI/TIA/EIA-644), RSDS, mini-LVDS, LVPECL, SLVS (JESD8-13), Sub-LVDS, HiSpi, SSTL-15 (JESD79-3D), SSTL-135, SSTL-125, HSUL-12, and the differential forms of the last four. [Table 5-7, p.5-7 to p.5-8]
- The 3.3 V PCI I/O standard is not supported, and the 3.3 V PCI-X standard is not supported because PCI-X does not meet the PCI-X I–V curve requirement at the linear region. [footnotes 7 and 8, p.5-7]
- Cyclone V devices support the true RSDS output standard with data rates of up to 230 Mbps and the true mini-LVDS output standard with data rates of up to 340 Mbps, using true LVDS output buffer types on all I/O banks. [footnotes 9 and 10, p.5-8]
- HPS I/O standard support splits by column and row: HPS column I/O supports 3.3 V and 3.0 V LVTTL/LVCMOS, 2.5 V, 1.8 V, and 1.5 V LVCMOS, and 1.5 V HSTL Class I and II. HPS row I/O supports 1.8 V LVCMOS, SSTL-18 Class I and II, SSTL-15 Class I and II, SSTL-135, and HSUL-12. [Table 5-8, p.5-8 to p.5-9]
- Typical supply levels: 3.3 V LVTTL/LVCMOS has VCCIO output 3.3 V and VCCPD 3.3 V. 3.0 V variants 3.0 V / 3.0 V. 2.5 V LVCMOS 2.5 V / 2.5 V. 1.8 V, 1.5 V, and 1.2 V LVCMOS use VCCPD 2.5 V. [Table 5-9, p.5-9]
- Voltage-referenced standard levels. [Table 5-9, p.5-9 to p.5-11]

  | Standard               | VCCIO output | VREF  | VTT  |
  | ---------------------- | ------------ | ----- | ---- |
  | SSTL-2                 | 2.5          | 1.25  | 1.25 |
  | SSTL-18 and 1.8 V HSTL | 1.8          | 0.9   | 0.9  |
  | SSTL-15 and 1.5 V HSTL | 1.5          | 0.75  | 0.75 |
  | 1.2 V HSTL             | 1.2          | 0.6   | 0.6  |
  | SSTL-135               | 1.35         | 0.675 |      |
  | SSTL-125               | 1.25         | 0.625 |      |
  | HSUL-12                | 1.2          | 0.6   |      |

  All use VCCPD 2.5 V.
- Input buffers for SSTL, HSTL, Differential SSTL, Differential HSTL, LVDS, RSDS, mini-LVDS, LVPECL, HSUL, and Differential HSUL are powered by VCCPD. [footnote 11, p.5-9]
- LVPECL is listed as differential clock input only, and SLVS, Sub-LVDS, and HiSpi as input only. [Table 5-9, p.5-10 to p.5-11]
- MultiVolt I/O support (VCCIO / VCCPD / input signal / output signal): 1.2 / 2.5 / 1.2 / 1.2. 1.25 / 2.5 / 1.25 / 1.25. 1.35 / 2.5 / 1.35 / 1.35. 1.5 / 2.5 / 1.5, 1.8 / 1.5. 1.8 / 2.5 / 1.5, 1.8 / 1.8. 2.5 / 2.5 / 2.5, 3.0, 3.3 / 2.5. 3.0 / 3.0 / 2.5, 3.0, 3.3 / 3.0. 3.3 / 3.3 / 2.5, 3.0, 3.3 / 3.3. [Table 5-10, p.5-11]
- VCCPD power pins must be connected to a 2.5 V, 3.0 V, or 3.3 V power supply. Using them to supply pre-driver power increases output pin performance. [p.5-11]
- If the input signal is 3.0 V or 3.3 V, Altera recommends using a clamping diode on the I/O pins. [p.5-11]
- Each I/O bank has its own VCCIO pins and supports only one VCCIO of 1.2, 1.25, 1.35, 1.5, 1.8, 2.5, 3.0, or 3.3 V. An I/O bank can support any number of input signals with different I/O standard assignments if those standards support the bank's VCCIO level. [p.5-12]
- An I/O bank supports non-voltage-referenced output signals only at the VCCIO voltage. The document's example is a bank with a 2.5 V VCCIO supporting 2.5 V, 3.0 V, and 3.3 V inputs but only 2.5 V output. [p.5-12]
- Each I/O bank contains a dedicated VREF pin and can have only a single VCCIO voltage level and a single VREF level. [p.5-12]
- Voltage-referenced input standards use their own VCCPD level as the power source, allowing voltage-referenced input signals in a bank with VCCIO of 2.5 V or below. However, a voltage-referenced input with R_T OCT enabled requires the bank VCCIO to match the input standard voltage, so R_T OCT cannot be supported for HSTL-15 when VCCIO is 2.5 V. [p.5-12 to p.5-13]
- Voltage-referenced bidirectional and output signals must match the VCCIO voltage of the I/O bank. [p.5-13]
- Mixed-standard examples: a bank can support SSTL-18 inputs and outputs plus 1.8 V inputs and outputs with 1.8 V VCCIO and 0.9 V VREF. A bank can support 1.5 V standards, 1.8 V inputs (but not outputs), and 1.5 V HSTL with 1.5 V VCCIO and 0.75 V VREF. [p.5-13]
- The corner fractional PLLs can drive the LVDS receiver and driver channels, but the clock tree network cannot cross over to different I/O regions. The Intel Quartus Prime compiler checks this and issues an error if violated. [p.5-13]
- Spread-spectrum input clock is not supported in LVDS. [p.5-13]
- To drive the LVDS channels, the PLLs must be used in integer PLL mode. [p.5-13]
- The dedicated reference clock pin of the same I/O bank used by the data channel must be used for LVDS. Table 5-11 lists the substitute reference clock bank for banks without a dedicated reference clock pin, pairing data channel banks 3A/3B, 5A/5B, and 7A/8A across variants. [p.5-13 to p.5-14]
- Each PLL can drive all the LVDS channels located at the same edge of the chip. [p.5-14]
- Both corner PLLs can drive LVDS channels simultaneously, one driving all transmitter channels and the other all receiver channels in the same bank. Both can also drive duplex channels in the same bank provided the channels driven by each PLL are not interleaved. No separation is required between the groups. [p.5-14]
- With the **Use External PLL** option on the ALTLVDS transmitter and receiver, the following signals are required from an Altera_PLL IP core: serial clock input to the SERDES, load enable to the SERDES, parallel clock for transmitter fabric logic and for the receiver `rx_syncclock` port and receiver fabric logic, and the asynchronous PLL reset port of the ALTLVDS receiver. [p.5-16]
- Altera_PLL to ALTLVDS signal mapping: serial clock output `outclk0` → `tx_inclock` and `rx_inclock`. Load enable output `outclk1` → `tx_enable` and `rx_enable`. Parallel clock output `outclk2` → transmitter and receiver core logic. `~(locked)` → `pll_areset` on the receiver. The serial clock output can only drive `tx_inclock` and `rx_inclock` and cannot drive core logic. [Table 5-12, p.5-16 to p.5-17]
- The `pll_areset` signal is automatically enabled for the LVDS receiver in external PLL mode and does not exist for LVDS transmitter instantiation when the external PLL option is enabled. [Table 5-12, p.5-17]
- Example Altera_PLL parameter values for external PLL mode (assuming clock and data edge-aligned at the device pins, no DPA or soft-CDR): `outclk0` frequency = data rate, phase shift −180°, duty cycle 50%. `outclk1` frequency = data rate/serialization factor, phase shift [(deserialization factor − 2)/deserialization factor] × 360°, duty cycle 100/serialization factor. `outclk2` frequency = data rate/serialization factor, phase shift −180/serialization factor, duty cycle 50%. [Table 5-13, p.5-17]
- For other clock and data phase relationships, Altera recommends first instantiating ALTLVDS_RX and ALTLVDS_TX without external PLL mode, compiling, noting the frequency, phase shift, and duty cycle for each clock output, and entering those in the Altera_PLL parameter editor. [p.5-17]
- When generating the Altera_PLL IP core, the Left/Right PLL option is configured to set up the PLL in LVDS mode. Instantiation of `pll_areset` is optional, and the `rx_enable` and `rx_inclock` input ports are not used and can be left unconnected. [p.5-19]
- VCCPD sharing exceptions. [p.5-19]

  - In Cyclone V E, GX, and GT, banks 1A (if available) and 2A share VCCPD
  - Banks 3B and 4A share
  - Banks 7A and 8A share
  - Cyclone V SE, SX, and ST: banks 1A (if available) and 2A share
  - Banks 3B and 4A share
  - Banks 6A and 6B share
  - All other I/O banks have individual VCCPD
- VCCIO/VCCPD compatibility examples: with VCCPD3B connected to 2.5 V, VCCIO pins for banks 3B and 4A can be 1.2 V, 1.25 V, 1.35 V, 1.5 V, 1.8 V, or 2.5 V. With VCCPD3B connected to 3.0 V, VCCIO for banks 3B and 4A must be 3.0 V. [p.5-20]
- VREF pin restrictions: shared VREF pins cannot be assigned as LVDS or external memory interface pins. SSTL, HSTL, and HSUL I/O standards do not support shared VREF pins. Signal integrity analysis of the board design is required to determine FMAX when a shared VREF pin is used. [p.5-20]
- For 3.3 V interfacing, the document instructs not violating the device absolute maximum ratings and offers a tip to perform IBIS or SPICE simulations to confirm overshoot and undershoot are within specification. [p.5-20]
- Transmitter application guidance: use slow slew rate and series termination, with a series termination resistor placed physically close to the driver, to match driver impedance to transmission line impedance. Receiver application guidance: use the on-chip clamping diode to limit overshoot and undershoot. [p.5-20 to p.5-21]
- Two LVDS guidelines are given to avoid adverse impact on LVDS performance: an I/O restrictions guideline, to avoid excessive jitter on the LVDS transmitter output pins. And a differential pad placement rule for each device, to avoid crosstalk effects. The restriction details are deferred to the *Cyclone V Device Family Pin Connection Guidelines* and the pad mapping spreadsheets in *Cyclone V Differential Pad Placement Rule and Pad Mapping Files*. [p.5-21]
- For general purpose high-speed signals faster than 200 MHz, the document instructs avoiding HMC DQ pins as the input pin and avoiding HMC DQ and command pins as the output pin, because signals using hard memory controller pins route through HMCPHY_RE routing elements with higher routing delay. [p.5-21]
- I/O bank layouts: Cyclone V E devices show banks 8A, 7A, 1A, 6A, 5B, 5A, 3A, 3B, 4A. GX and GT add a transceiver block. SE shows HPS column I/O, HPS core, and HPS row I/O in place of the right-side FPGA banks. SX and ST combine a transceiver block with the HPS structure. [Figures 5-6 to 5-9, p.5-21 to p.5-23]
- Modular I/O banks have independent power supplies allowing each bank to support different I/O standards, and each bank can support multiple I/O standards that use the same VCCIO and VCCPD voltages. [p.5-24]
- Modular I/O bank totals, Cyclone V E. [Tables 5-14 and 5-15, p.5-24 to p.5-25]

  | Device    | M383 | U324 | F256 | M484 | U484 | F484 | F672 | F896 |
  | --------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- |
  | A2 and A4 | 223  | 176  | 128  |      | 224  | 224  |      |      |
  | A5        | 175  |      |      |      | 224  | 240  |      |      |
  | A7        |      |      |      | 240  | 240  | 240  | 336  | 480  |
  | A9        |      |      |      |      | 240  | 224  | 336  | 480  |

- Modular I/O bank totals, Cyclone V GX. [Tables 5-16 and 5-17, p.5-25 to p.5-26]

  | Device    | M301 | M383 | U324 | M484 | U484 | F484 | F672 | F896 | F1152 |
  | --------- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----- |
  | C3        |      |      | 144  |      | 208  | 208  |      |      |       |
  | C4 and C5 | 129  | 175  |      |      | 224  | 240  | 336  |      |       |
  | C7        |      |      |      | 240  | 240  | 240  | 336  | 480  |       |
  | C9        |      |      |      |      | 240  | 224  | 336  | 480  | 560   |

- Modular I/O bank totals, Cyclone V GT. [Tables 5-18 and 5-19, p.5-26 to p.5-27]

  | Device | M301 | M383 | M484 | U484 | F484 | F672 | F896 | F1152 |
  | ------ | ---- | ---- | ---- | ---- | ---- | ---- | ---- | ----- |
  | D5     | 129  | 175  |      | 224  | 240  | 336  |      |       |
  | D7     |      |      | 240  | 240  | 240  | 336  | 480  |       |
  | D9     |      |      |      | 240  | 224  | 336  | 480  | 560   |

- Modular I/O bank totals, SoC variants. [Tables 5-20 to 5-22, p.5-27 to p.5-28]

  | Device                      | U484 | U672 | F896                 |
  | --------------------------- | ---- | ---- | -------------------- |
  | Cyclone V SE A2, A4, A5, A6 | 203  | 312  | 455 (A5 and A6 only) |
  | Cyclone V SX C2, C4, C5, C6 |      | 312  | 455 (C5 and C6 only) |
  | Cyclone V ST D5 and D6      |      |      | 455                  |

- SoC bank structure: FPGA I/O banks 3A, 3B, 4A, 5A, 5B, and 8A. HPS row I/O banks 6A and 6B. HPS column I/O banks 7A, 7B, 7C, and 7D. HPS row and column I/O counts are the number of HPS-specific I/O pins on the device, and each such pin may map to several HPS I/Os. [Tables 5-20 to 5-22, p.5-27 to p.5-28]
- The IOE input path consists of DDR input registers, alignment and synchronization registers, and half data rate blocks. The output path consists of output or OE registers, alignment registers, and half data rate blocks. Each block in every path can be bypassed. [Table 5-23, p.5-29]
- The input path uses the deskew delay to adjust the input register clock delay across process, voltage, and temperature (PVT) variations. [Table 5-23, p.5-29]
- One dynamic OCT control is available for each DQ/DQS group. [Figure 5-10, p.5-30]
- Programmable slew rate settings are 0 (Slow) and 1 (Fast), default 1, assignment name "Slew Rate", supported in HPS I/O. Slew rate control is disabled if the R_S OCT feature is used. [Table 5-24 and footnote 12, p.5-31]
- Programmable output buffer delay settings are 0 ps (default), 50 ps, 100 ps, and 150 ps, assignment name "Output Buffer Delay", not supported in HPS I/O. [Table 5-24, p.5-31]
- Open-drain output is enabled using the OPNDRN primitive. Bus-hold is disabled if the weak pull-up resistor feature is used, and the pull-up resistor is disabled if bus-hold is used. [footnotes 13, 14, 15, p.5-32]
- Programmable differential output voltage settings are 0 (low), 1 (medium), and 2 (high), default 1, assignment name "Programmable Differential Output Voltage (VOD)", supported for LVDS, RSDS, and mini-LVDS, not supported in HPS I/O. [Table 5-24, p.5-33]
- The on-chip clamp diode setting is On or Off (default Off), assignment name "Clamping Diode", supported for 3.0/3.3 V LVTTL, 3.0/3.3 LVCMOS, 3.0 V PCI, and 3.0 V PCI-X, and supported in HPS I/O. It is recommended to be turned on for 3.3 V I/O standards, and the PCI clamp diode is enabled by default for 3.0 V PCI and 3.0 V PCI-X. The on-chip clamp diode is available on all GPIO pins in all Cyclone V device variants. [Table 5-24 and footnotes 16, 17, p.5-33]
- Programmable current strength settings in mA: 3.3 V LVTTL 16, 8, 4 (HPS supports all except 16 mA). 3.3 V LVCMOS 2. 3.0 V LVTTL and 3.0 V LVCMOS 16, 12, 8, 4. 2.5 V LVCMOS 16, 12, 8, 4. 1.8 V and 1.5 V LVCMOS 12, 10, 8, 6, 4, 2. 1.2 V LVCMOS 8, 6, 4, 2. [Table 5-25, p.5-33 to p.5-34]
- Programmable current strength for voltage-referenced standards in mA: SSTL-2 Class I 12, 10, 8 and Class II 16. SSTL-18 Class I 12, 10, 8, 6, 4 and Class II 16. SSTL-15 Class I 12, 10, 8, 6, 4 and Class II 16. 1.8/1.5/1.2 V HSTL Class I 12, 10, 8, 6, 4 and Class II 16. [Table 5-25, p.5-33 to p.5-34]
- Intel recommends performing IBIS or SPICE simulations to determine the best current strength setting, and Altera recommends the same for the best slew rate setting. [p.5-34]
- Programmable output slew rate is available for single-ended I/O standards and emulated LVDS output standards, and can be specified pin-by-pin because each I/O pin contains a slew rate control. [p.5-34]
- Programmable IOE delays are used to ensure zero hold times, minimize setup times, or increase clock-to-output times. Each pin can have a different pin-to-input-register or output-register-to-output-pin delay. [p.5-35]
- There are four levels of output buffer delay settings, built inside the single-ended output buffer, with no delay by default. The delay chains independently control rising and falling edge delays, enabling duty-cycle adjustment, channel-to-channel skew compensation, deliberate skew to reduce simultaneous switching output (SSO) noise, and improved memory-interface timing margins. [p.5-35]
- Programmable pre-emphasis assignment: To `tx_out`, assignment name "Programmable Pre-emphasis", allowed values 0 (disabled) and 1 (enabled), default 1. [Table 5-26, p.5-36]
- Programmable VOD assignment: To `tx_out`, assignment name "Programmable Differential Output Voltage (VOD)", allowed values 00 (low), 01 (medium), 10 (high), default 01. [Table 5-27, p.5-36]
- Open-drain output is either high-Z or logic low. It can be enabled by designing the tristate buffer with the OPNDRN primitive or by turning on the **Auto Open-Drain Pins** option. The I/O buffer's open-drain feature provides the best propagation delay from OE to output. [p.5-37]
- Bus-hold circuitry is active only after configuration and captures the value present on the pin at the end of configuration. It uses a resistor with nominal resistance R_BH of approximately 7 kΩ to weakly pull the signal to the last-driven state, and drives the I/O pin voltage lower than the VCCIO level to prevent over-driving. Bus-hold must be disabled to configure the I/O pin for differential signals. [p.5-38]
- Programmable weak pull-up resistors are supported only on user I/O pins. For dedicated configuration pins, dedicated clock pins, and JTAG pins with internal pull-up resistors, the resistor values are not programmable. [p.5-38]
- Cyclone V devices support OCT in all FPGA I/O banks. For the HPS I/Os, the column I/Os do not support OCT with calibration. [p.5-38]
- R_S OCT without calibration is supported on output only, for single-ended and voltage-referenced I/O standards. [p.5-39]
- Uncalibrated R_S OCT output settings, in Ω. [Table 5-29, p.5-39 to p.5-40]

  | I/O standard                                                                            | Settings           |
  | --------------------------------------------------------------------------------------- | ------------------ |
  | 3.0 V LVTTL/LVCMOS, 2.5 V, 1.8 V, 1.5 V, and 1.2 V LVCMOS                               | 25, 50             |
  | All Class I standards (SSTL-2/-18/-15, 1.8/1.5/1.2 V HSTL and their differential forms) | 50                 |
  | All Class II                                                                            | 25                 |
  | SSTL-15 and Differential SSTL-15                                                        | 25, 50, 34, 40     |
  | SSTL-135, SSTL-125 and their differential forms                                         | 34, 40             |
  | HSUL-12 and Differential HSUL-12                                                        | 34, 40, 48, 60, 80 |
- If matching impedance is selected, current strength is no longer selectable. [p.5-40]
- Calibrated R_S OCT settings pair the same resistance values with an RZQ of 100 Ω for the 25/50 settings and 240 Ω for the 34/40 and HSUL-12 (34, 40, 48, 60, 80) settings. [Table 5-30, p.5-41 to p.5-42]
- The R_S OCT calibration circuit compares the total I/O buffer impedance to the external reference resistor on the RZQ pin and dynamically enables or disables transistors until they match. Calibration occurs at the end of device configuration, after which the circuit powers down and stops changing driver characteristics. [p.5-41]
- R_T OCT with calibration is available only for input and bidirectional pin configurations, not output pins, and requires the bank VCCIO to match the I/O standard of the pin where R_T OCT is enabled. [p.5-43]
- Calibrated R_T OCT input settings: 50 Ω with RZQ 100 Ω for SSTL-2/-18/-15 Class I and II, 1.8/1.5/1.2 V HSTL Class I and II, and their differential forms. 20, 30, 40, 60, 120 Ω with RZQ 240 Ω for SSTL-15, SSTL-135, SSTL-125 and their differential forms. [Table 5-31, p.5-43 to p.5-44]
- Dynamic OCT state by direction: dynamic R_T OCT is enabled when the bidirectional I/O acts as a receiver and disabled when it acts as a driver. Dynamic R_S OCT is disabled as a receiver and enabled as a driver. [Table 5-32, p.5-45]
- Intel recommends using OCT with the SSTL-15, SSTL-135, and SSTL-125 I/O standards for external memory interfaces to save board space and cost by reducing the number of external termination resistors. [p.5-45]
- R_D OCT is supported in all I/O banks and can only be used if VCCPD is set to 2.5 V. OCT for differential LVDS and SLVS input buffers has a nominal resistance value of 100 Ω. [p.5-46]
- Each device has four OCT calibration blocks, each containing one RZQ pin. The RZQ pin is connected to GND through an external 100 Ω or 240 Ω resistor depending on the R_S or R_T OCT value, and shares the VCCIO supply of its I/O bank. [p.5-47]
- R_S and R_T OCT can be used in the same I/O bank for different I/O standards if those standards use the same VCCIO supply voltage. R_S OCT and programmable current strength cannot be configured for the same I/O buffer. [p.5-47]
- Calibrated R_S and calibrated R_T OCT are supported on all I/O pins except dedicated configuration pins. [p.5-47]
- All I/O banks with the same VCCIO can share one OCT calibration block. Banks without calibration blocks share the blocks in banks that have them. All I/O banks support OCT calibration with different VCCIO voltage standards, up to the number of available calibration blocks. [p.5-48]
- OCT calibration sharing example: because banks 5A and 7A have the same VCCIO as bank 3A, all three banks can be calibrated with calibration block CB3 located in bank 3A, by serially shifting the R_S OCT calibration codes out to the I/O banks around the periphery. [p.5-49]
- External termination schemes by standard: no external termination required for 3.3/3.0 V LVTTL and LVCMOS, 3.0 V PCI, 3.0 V PCI-X, and 2.5/1.8/1.5/1.2 V LVCMOS. Single-ended SSTL termination for SSTL-2/-18/-15 Class I and II. Single-ended HSTL termination for 1.8/1.5/1.2 V HSTL Class I and II. Differential SSTL termination for the differential SSTL classes. LVDS, differential LVPECL, and SLVS terminations for those standards. [Table 5-33, p.5-50 to p.5-51]
- Voltage-referenced I/O standards require an input VREF and a termination voltage (VTT), with the receiving device's reference voltage tracking the transmitting device's termination voltage. SSTL-125, SSTL-135, and SSTL-15 typically do not require external board termination. [p.5-51]
- R_S and R_T OCT cannot be used simultaneously. [p.5-51]
- Differential HSTL, SSTL, and HSUL inputs use LVDS differential input buffers, but R_D support is available only if the I/O standard is LVDS. Their outputs are not true differential outputs and instead use two single-ended outputs with the second programmed as inverted. [p.5-54]
- All I/O banks have dedicated circuitry supporting true LVDS, RSDS, SLVS, and mini-LVDS output through true LVDS output buffers without resistor networks. [p.5-55]
- Emulated LVDS, RSDS, and mini-LVDS output buffers use two single-ended output buffers with an external single-resistor or three-resistor network and can be tri-stated. The figure gives R_S as 120 Ω and R_P as 170 Ω, and resistor values must satisfy (R_S × R_P/2)/(R_S + R_P/2) = 50 Ω. [p.5-56 to p.5-57]
- Altera recommends additional IBIS or SPICE simulations to validate that custom resistor values meet the RSDS or mini-LVDS I/O standard requirements. [p.5-57]
- LVPECL is supported on input clock pins only: LVPECL input operation uses LVDS input buffers and LVPECL output operation is not supported. AC coupling is used if the LVPECL common-mode voltage of the output buffer does not match the input common-mode voltage, and DC-coupled LVPECL is supported if the output common mode voltage is within the Cyclone V LVPECL input buffer specification. [p.5-58]
- Differential transmitter and receiver dedicated circuitry: true differential buffer supports LVDS, mini-LVDS, and RSDS on the transmitter and LVDS, SLVS, mini-LVDS, and RSDS on the receiver. SERDES is up to 10 bit serializer on the transmitter and up to 10 bit deserializer on the receiver. Programmable VOD is statically assignable on the transmitter only. Skew adjustment on the receiver is manual. Receiver termination is 100 Ω in LVDS and SLVS standards. [Table 5-34, p.5-59]
- The locations of the dedicated SERDES circuitry and the high-speed I/Os are given as per-density figures: Cyclone V E A2 and A4. GX C3. GX C4, C5, C7, C9 together with GT D5, D7, D9. SE A2, A4, A5, A6. And SX C2, C4, C5, C6 together with ST D5 and D6. [Figures 5-29 to 5-33, p.5-59 to p.5-61]
- The LVDS SERDES figure shows a shared PLL between transmitter and receiver. If they do not share the same PLL, two fractional PLLs are required. In SDR and DDR modes the data width is 1 and 2 bits respectively. [p.5-62]
- Both row and column I/Os support true LVDS input buffers with R_D OCT and true LVDS output buffers. Cyclone V devices offer single-ended I/O reference clock support for the fractional PLL that drives the SERDES. [p.5-63]
- True LVDS output buffers cannot be tri-stated. [p.5-63]
- The stated LVDS channel counts exclude dedicated clock pins, and each I/O sub-bank can support up to two independent ALTLVDS interfaces (for example two interfaces in bank 8A driven by two different PLLs, provided the LVDS channels are not interleaved). [p.5-63]
- LVDS channel counts (TX/RX) at the extremes. [Tables 5-35 to 5-37, p.5-63 to p.5-70]

  | Device and package                               | Top   | Left | Right | Bottom |
  | ------------------------------------------------ | ----- | ---- | ----- | ------ |
  | Cyclone V E A2/A4, 256-pin FineLine BGA          | 8/8   | 4/4  | 8/8   | 12/12  |
  | Cyclone V GX C9 and GT D9, 1152-pin FineLine BGA | 48/48 |      | 44/44 | 48/48  |

- LVDS channel counts (TX/RX) for the SoC variants. [Tables 5-38 to 5-40, p.5-70 to p.5-71]

  | Device and package                                     | Top   | Right | Bottom |
  | ------------------------------------------------------ | ----- | ----- | ------ |
  | SE A2/A4 and A5/A6, 484-pin Ultra FineLine BGA         | 1/2   | 4/4   | 10/12  |
  | SE A2/A4 and A5/A6, 672-pin Ultra FineLine BGA         | 1/2   | 5/6   | 26/29  |
  | SE A5/A6, SX C5/C6, and ST D5/D6, 896-pin FineLine BGA | 20/20 | 12/12 | 40/40  |

- Emulated LVDS is supported on all I/O banks: unutilized true LVDS input channels can be used as emulated LVDS output buffers (eTX), which use two single-ended output buffers with an external resistor network to support LVDS, mini-LVDS, and RSDS, and support tri-state capability. [p.5-71]
- The LVDS transmitter serializer takes up to 10 bits wide parallel data from the FPGA fabric, clocks it into the load registers, and serializes it using shift registers clocked by the fractional PLL. The MSB of the parallel data is transmitted first. [p.5-71 to p.5-72]
- The fractional PLL generates the parallel clocks (`rx_outclock` and `tx_outclock`), the load enable signal `LVDS_LOAD_EN`, and the `diffioclk` signal running at serial data rate. The serialization factor is statically set to x4, x5, x6, x7, x8, x9, or x10, and the load enable signal is derived from that setting. [p.5-72]
- Any transmitter data channel can be configured to generate a source-synchronous transmitter clock output. The output clock can be divided by a factor of 1, 2, 4, 6, 8, or 10 depending on the serialization factor, and the fractional PLLs provide additional phase shifts in 45° increments. [p.5-72]
- The serializer can be bypassed to support DDR (x2) and SDR (x1) operations for serialization factors of 2 and 1. The IOE contains two data output registers each operable in DDR or SDR mode. In DDR mode `tx_inclock` clocks the IOE register. In SDR mode data passes directly through the IOE. [p.5-73]
- The receiver has a differential buffer, fractional PLLs shareable with the transmitter, a data realignment block, and a deserializer. Receiver pin I/O standard can be statically set to LVDS, SLVS, mini-LVDS, or RSDS in the Assignment Editor. [p.5-73 to p.5-74]
- The deserializer includes shift registers and parallel load registers and sends a maximum of 10 bits to the internal logic. [p.5-74]
- Data realignment (bit slip) is controlled by the optional `RX_CHANNEL_DATA_ALIGN` port, which slips the data one bit on its rising edge. Requirements are a minimum pulse width of one period of the parallel clock in the logic array, a minimum low time between pulses of one parallel clock period, edge-triggered operation, and valid data available two parallel clock cycles after the rising edge. [p.5-74 to p.5-75]
- The data realignment circuit can have up to 11 bit-times of insertion before rollover. The programmable bit rollover point is 1 to 11 bit-times independent of the deserialization factor and should be set equal to or greater than the deserialization factor. The optional `RX_CDA_MAX` status port indicates reaching the preset rollover point. [p.5-75]
- The deserialization factor is statically set to x4, x5, x6, x7, x8, x9, or x10, and the deserializer can be bypassed to support DDR (x2) or SDR (x1) operations. [p.5-75]
- In LVDS receiver mode, input serial data is registered at the rising edge of the serial `LVDS_diffioclk` clock produced by the left and right PLLs. That clock also drives the data realignment and deserializer blocks. [p.5-76]
- LVDS mode allows statically selecting the optimal phase between the source synchronous clock and the received serial data to compensate skew. [p.5-77]
- Cyclone V devices provide a 100 Ω on-chip differential termination option on each differential receiver channel for LVDS standards, enabled in the Assignment Editor. All I/O pins and dedicated clock input pins support R_D OCT. The assignment is To `rx_in`, assignment name "Input Termination", value "Differential". [Table 5-41, p.5-77 to p.5-78]
- Source-synchronous timing analysis is based on the skew between data and clock signals rather than clock-to-output setup times, and is influenced by board skew, cable skew, and clock jitter. [p.5-78]
- For operation at 840 Mbps with a serialization factor of 10, the external clock is multiplied by 10. Phase alignment can be set in the PLL to coincide with the sampling window of each data bit, and data is sampled on the falling edge of the multiplied clock. [p.5-78]
- The bit-order and word boundary figure for one differential channel assumes the serialization factor equals the clock multiplication factor, phase alignment uses edge alignment, and the operation is implemented in hard SERDES. [p.5-79]
- Differential bit naming for 18 differential channels with internal 8-bit parallel data: channel 1 MSB 7 / LSB 0, channel 2 MSB 15 / LSB 8, incrementing by 8 per channel through channel 18 at MSB 143 / LSB 136. [Table 5-42, p.5-79 to p.5-80]
- For LVDS transmitters the Timing Analyzer provides the TCCS value in the TCCS report (`report_TCCS`) in the compilation report. The TCCS value is also available from the device datasheet. [p.5-80]
- RSKM is defined by RSKM = (TUI − SW − TCCS)/2, where TUI (time unit interval) is the time period of the serial data. A positive RSKM value indicates the LVDS receiver can sample the data properly and a negative value indicates it cannot. [p.5-81]
- The RSKM report is generated with the `report_RSKM` command in the Timing Analyzer and shows SW, TUI, and RSKM values for non-DPA LVDS mode. Obtaining the RSKM value requires assigning the input delay to the LVDS receiver, and if no input delay is set the receiver channel-to-channel skew defaults to zero. The input delay can also be set directly in a Synopsys Design Constraint file (`.sdc`) with `set_input_delay`. [p.5-82]
- Revision entry 2019.03.19 records a correction to the number of I/O pins for I/O banks 5B and 6A in the F672 package of the Cyclone V GX C5 and C7 devices. [p.5-83]

### Chapter 6: External Memory Interfaces (CV-52006)

- Supported external memory standards are DDR3 SDRAM, DDR2 SDRAM, and LPDDR2 SDRAM. The hard memory controller supports them at full rate and the soft memory controller at half rate. [Table 6-1, p.6-1]
- External memory interface performance (maximum hard controller / maximum soft controller / minimum frequency): DDR3 SDRAM at 1.5 V 400 / 303 / 303 MHz. DDR3 SDRAM at 1.35 V 400 / 303 / 303 MHz. DDR2 SDRAM at 1.8 V 400 / 300 / 167 MHz. LPDDR2 SDRAM at 1.2 V 333 / 300 / 167 MHz. [Table 6-2, p.6-1 to p.6-2]
- HPS external memory interface performance (HPS hard controller): DDR3 SDRAM at 1.5 V 400 MHz. DDR3 SDRAM at 1.35 V 400 MHz. DDR2 SDRAM at 1.8 V 400 MHz. LPDDR2 SDRAM at 1.2 V 333 MHz. The HPS is available in Cyclone V SoC devices only. [Table 6-3, p.6-2]
- Maximum and minimum operating frequencies depend on the memory interface standard and the supported delay-locked loop (DLL) frequency listed in the device datasheet. [p.6-1]
- Memory interface circuitry is available in every I/O bank that does not support transceivers. The devices offer differential input buffers for differential read-data strobe and clock operations, and memory clock pins are generated with double data rate input/output (DDRIO) registers. [p.6-2]
- The devices support DQ and DQS signals with DQ bus modes of x8 or x16. The x4 bus mode is not supported. [p.6-3]
- DQSn pins not used for clocking can be used as DQ pins. Unused DQ/DQS pins can be used as user I/Os, except that unused HPS DQ/DQS pins on Cyclone V SE, SX, and ST devices cannot be used as user I/Os. [p.6-3]
- Some specific DQ pins can also be used as RZQ pins. For x8 or x16 DQ/DQS groups whose members are used as RZQ pins, Altera recommends assigning the DQ and DQS pins manually, otherwise the Intel Quartus Prime software might produce a "no-fit" error. [p.6-3]
- In the pin tables, DQS and DQSn differential data strobe/clock pin pairs are listed as DQSXY and DQSnXY, where X indicates the DQ/DQS grouping number and Y indicates the device side: top (T), bottom (B), left (L), or right (R). [p.6-3]
- The F484 package of the Cyclone V E A9, GX C9, and GT D9 devices can support only a 24-bit hard memory controller on the top side using the T_DQ_0 to T_DQ_23 pin assignments. The T_DQ_32 to T_DQ_39 assignments listed in the "HMC Pin Assignment" columns of those pin tables cannot be used for the hard memory controller. [p.6-3]
- Maximum data pins per DQ/DQS group: 11 in x8 mode and 23 in x16 mode. Both modes support DQSn and optional data mask. [Table 6-4, p.6-4]
- The maximum number of data pins per group varies with signalling: with single-ended DQS signalling the maximum includes data mask connected to the DQS bus network. With differential or complementary DQS signalling the maximum decreases by one. For DDR3 and DDR2 interfaces each x8 group requires one DQS pin and may also require one DQSn pin and one DM pin, further reducing the available data pins. [p.6-3 to p.6-4]
- DQ/DQS group counts per side range from 1 x8 group (Cyclone V E 256-pin FineLine BGA left side) up to 12 x8 and 4 x16 groups on the top and bottom and 11 x8 and 4 x16 on the right in the 1152-pin FineLine BGA of Cyclone V GX C9 and GT D9. [Tables 6-5 to 6-7, p.6-4 to p.6-10]
- DQ/DQS groups for the SoC variants. The SX table figures are for the soft memory controller. Hard memory controller groups come from the device pin table. [Tables 6-8 to 6-10, p.6-10 to p.6-11]

  | Device and package                                         | Top            | Right | Bottom          |
  | ---------------------------------------------------------- | -------------- | ----- | --------------- |
  | SE A2 and A4, 484-pin Ultra FineLine BGA                   |                | 1 x8  | 2 x8            |
  | SE A4/A5/A6 and SX C2/C4/C5/C6, 672-pin Ultra FineLine BGA |                | 1 x8  | 8 x8 and 2 x16  |
  | SE A5/A6, SX C5/C6, and ST D5/D6, 896-pin FineLine BGA     | 5 x8 and 2 x16 | 3 x8  | 10 x8 and 3 x16 |

- Device features available for external memory interfaces: DQS phase-shift circuitry, PHY Clock (PHYCLK) networks, DQS logic block, dynamic OCT control, IOE registers, delay chains, and hard memory controllers. [p.6-12]
- The UniPHY IP instantiates a PLL to generate related clocks for the memory interface and can dynamically choose the number of delay chains required. The amount of delay equals the intrinsic delay of the delay element plus the product of the number of delay steps and the value of the delay steps. [p.6-12]
- The UniPHY IP and the Altera memory controller IP core can run at half the I/O interface frequency of the memory devices. The IOE contains built-in circuitry to convert data from full rate (I/O frequency) to half rate (controller frequency) and back. [p.6-12]
- In the external memory interface datapath, the DQ/DQS read and write signals may be bidirectional or unidirectional depending on the memory standard. A bidirectional signal is active during both read and write operations, and each register block can be bypassed. The document notes slight block differences between memory interface standards. [Figure 6-1, p.6-13]
- The DLL provides phase shift to the DQS pins on read transactions when the DQS pins act as input clocks or strobes to the FPGA. [p.6-13]
- There are a maximum of four DLLs, located in each corner of the device, and each can be clocked at a different frequency. [p.6-18]
- Each DLL can access the two adjacent sides from its location, so two different interfaces at the same frequency on the two sides adjacent to a DLL can both have their DQS delay settings controlled by that DLL. [p.6-18]
- I/O banks between two DLLs can use settings from either or both adjacent DLLs. The document's example is DQS1R taking phase-shift settings from DLL_TR while DQS2R takes them from DLL_BR. [p.6-18]
- The DLL reference clock may come from PLL output clocks or clock input pins. If a dedicated PLL generates only the DLL input reference clock, the document instructs setting the PLL mode to Direct Compensation for better performance. [p.6-18 to p.6-19]
- DLL reference clock inputs from PLLs: for Cyclone V E (A2, A4, A5, A7, A9), GX (C4, C5, C7, C9), and GT (D5, D7, D9), DLL_TL, DLL_TR, DLL_BL, and DLL_BR each take `pllout` from the corresponding corner PLL. For Cyclone V GX C3, DLL_BL has no PLL source. For SE A2/A4/A5/A6, SX C2/C4/C5/C6, and ST D5/D6, DLL_TR has no PLL source. [Tables 6-11 to 6-13, p.6-19 to p.6-20]
- The DLL can shift incoming DQS signals by 0° or 90°. DQS pins referenced to the same DLL may have different phase shifts but must all be at one frequency and all be a multiple of 90°. [p.6-20]
- The DQS delay settings from the DLL are 7-bit and gray-coded to reduce jitter when the DLL updates the settings. They vary with PVT to implement the phase-shift delay. [p.6-18, p.6-20]
- With a 0° shift, the DQS signal bypasses both the DLL and the DQS logic blocks, and the Intel Quartus Prime software automatically sets the DQ input delay chains so that DQ-to-DQS skew at the DQ IOE registers is negligible. [p.6-20]
- For Cyclone V SoC devices, HPS DQS delay settings can be fed only to the HPS DQS logic block. [p.6-20]
- The DLL input reference clock passes through a chain of up to eight delay elements. A phase comparator issues an `upndn` signal to a Gray-code counter that increments or decrements the 7-bit delay setting to bring the input reference clock and the delay chain output into phase. [p.6-21]
- The DLL can be reset from the logic array or a user I/O pin. After each reset, 2,560 clock cycles must elapse for the DLL to lock before data can be captured properly, because the DLL phase comparator requires 2,560 clock cycles to lock and calculate the correct input clock period. [p.6-21]
- The PHYCLK network is a dedicated high-speed, low-skew balanced clock tree. The top and bottom sides have up to four PHYCLK networks each and the left and right side I/O banks have up to two, with each network spanning one I/O bank and driven by one adjacent PLL. [p.6-21]
- The DQS logic block, connected to each DQS/CQ/CQn/QK# pin, consists of update enable circuitry, DQS delay chains, and DQS postamble circuitry. [p.6-26]
- The update enable circuitry allows enough time for DQS delay settings to travel from the DQS phase-shift circuitry or core logic to all DQS logic blocks before the next change, using the input reference clock or a user clock from the core. The UniPHY IP uses this circuit by default. [p.6-27]
- Two delay elements in the DQS delay chain have the same characteristics: delay elements in the DQS logic block and delay elements in the DLL. The number of delay chains required is set automatically by the UniPHY IP based on the chosen operating frequency. [p.6-27 to p.6-28]
- In Cyclone V SE, SX, and ST devices the DQS delay chain is controlled by the DQS phase-shift circuitry only. [p.6-28]
- DQS postamble circuitry uses dedicated postamble registers to ground the shifted DQS signal at the end of a read operation, ensuring glitches on the DQS input during the postamble state do not affect the DQ IOE registers. In the preamble state DQS is low just after a high-impedance state. In the postamble state DQS is low just before returning to a high-impedance state. [p.6-28]
- The half data rate (HDR) block in the postamble enable circuitry is clocked by the half-rate resynchronization clock from the I/O clock divider. An AND gate after the postamble register outputs avoids postamble glitches from a previous read burst on a non-consecutive read burst, giving half-a-clock-cycle latency for `dqsenable` assertion and zero latency for deassertion. Altera recommends using these registers if the controller runs at half the frequency of the I/Os. [p.6-28]
- The dynamic OCT control block contains the registers required to dynamically turn R_T OCT on during a read and off during a write. [p.6-29]
- The DDR input registers block contains three registers: registers A and B capture data on the positive and negative clock edges while register C aligns the captured data using the same clock as register A. The read FIFO block resynchronizes data to the system clock domain and lowers the data rate to half rate. [p.6-30]
- For DDR3 and DDR2 SDRAM interfaces the DQS and DQSn signals must be inverted. Altera's memory interface IPs invert them automatically. [p.6-30]
- The output and output-enable path is divided into the HDR block and the output and output-enable registers, each bypassable. Half-rate data is converted to full rate by the HDR block clocked by the half-rate clock from the PLL, and the output-enable path mirrors the output path so both experience the same delay and latency. [p.6-30]
- Every I/O block contains a run-time adjustable delay chain between the output registers and output buffer, the input buffer and input register, the output enable and output buffer, and the R_T OCT enable-control register and output buffer. The DQS delay chain can be bypassed to achieve a 0° phase shift. [p.6-31]
- Each DQS logic block contains a delay chain after the `dqsbusout` output and another before the `dqsenable` input. [p.6-32]
- The I/O and DQS configuration blocks are shift registers used to dynamically change device configuration bit settings. The shift registers power up low, every I/O pin contains one I/O configuration register, and every DQS pin contains one DQS configuration block in addition to the I/O configuration register. [p.6-33]
- The hard memory controllers support LPDDR2, DDR2, and DDR3 SDRAM interfaces, allow higher memory interface frequencies with shorter latency cycles than core-logic controllers, and use dedicated I/O pins for data, address, command, control, clock, and ground. Those dedicated pins can be used as regular I/O pins if the hard memory controllers are unused. [p.6-34]
- The hard memory controller is stated to be functionally similar to the High-Performance Controller II (HPC II). [p.6-34]
- Hard memory controller memory interface data widths: 8, 16, and 32 bit data. 16 bit data + 8 bit ECC. 32 bit data + 8 bit ECC. [Table 6-14, p.6-34]
- The hard memory controller supports up to four gigabits density parts and two chip selects. [Table 6-14, p.6-34]
- Supported memory burst lengths: DDR3 burst length of 8 and burst chop of 4. DDR2 burst lengths of 4 and 8. LPDDR2 burst lengths of 2, 4, 8, and 16. [Table 6-14, p.6-34]
- The controller supports out-of-order execution of DRAM commands with address collision detection and in-order return of results, and a starvation counter that ensures all requests are served after a predefined time-out period. [Table 6-14, p.6-34]
- ECC support is standard Hamming single error correction, double error detection (SECDED). [Table 6-14, p.6-36]
- The multi-port front end (MPFE) and its fabric interface provide up to six command ports, four read-data ports, and four write-data ports. [p.6-36]
- MPFE port counts (command / write-data / read-data): Cyclone V E A2 and A4 4 / 2 / 2. E A5, A7, A9 6 / 4 / 4. GX C3 4 / 2 / 2. GX C4, C5, C7, C9 6 / 4 / 4. GT D5, D7, D9 6 / 4 / 4. [Table 6-15, p.6-37]
- Bonding is supported only for hard memory controllers configured with one port and must not be used when there is more than one port in each hard memory controller. [p.6-37]
- When two hard memory controllers are bonded, data going out to the user logic is synchronized but data going out to memory is not. The bonding controllers remain independent with two separate address buses and two independent command buses that are calibrated separately. [p.6-37]
- ECC support for a bonded interface must be implemented external to the hard memory controllers, and a memory interface using bonding has higher average latency, with bonding through the core fabric causing higher latency still. [p.6-37]
- The SoC devices (Cyclone V SX C2, C4, C5, C6 and ST D5, D6) have no bonding support. [p.6-39]
- Hard memory controller width per side, Cyclone V E. Each cell is top / bottom. [Table 6-16, p.6-40]

  | Device    | M383     | F256 | U324 | M484  | U484  | F484  | F672  | F896  |
  | --------- | -------- | ---- | ---- | ----- | ----- | ----- | ----- | ----- |
  | A2 and A4 | ≤ 24 / 0 | 0/0  | 0/0  |       | 24/0  | 24/0  |       |       |
  | A5        | ≤ 24 / 0 |      |      |       | 24/24 | 40/24 |       |       |
  | A7        |          |      |      | 24/24 | 24/24 | 40/24 | 40/40 | 40/40 |
  | A9        |          |      |      |       | 24/24 | 24/24 | 40/40 | 40/40 |

- Hard memory controller width per side, Cyclone V GX. Each cell is top / bottom. [Table 6-17, p.6-40 to p.6-41]

  | Device    | M301 | M383     | U324 | M484  | U484  | F484  | F672  | F896  | F1152 |
  | --------- | ---- | -------- | ---- | ----- | ----- | ----- | ----- | ----- | ----- |
  | C3        |      |          | 0/0  |       | 24/0  | 24/0  |       |       |       |
  | C4 and C5 | 0/0  | ≤ 24 / 0 |      |       | 24/24 | 40/24 | 40/40 |       |       |
  | C7        |      |          |      | 24/24 | 24/24 | 40/24 | 40/40 | 40/40 |       |
  | C9        |      |          |      |       | 24/24 | 24/24 | 40/40 | 40/40 | 40/40 |

- Hard memory controller width per side, Cyclone V GT. Each cell is top / bottom. [Table 6-18, p.6-41]

  | Device | M301 | M383     | M484  | U484  | F484  | F672  | F896  | F1152 |
  | ------ | ---- | -------- | ----- | ----- | ----- | ----- | ----- | ----- |
  | D5     | 0/0  | ≤ 24 / 0 |       | 24/24 | 40/24 | 40/40 |       |       |
  | D7     |      |          | 24/24 | 24/24 | 40/24 | 40/40 | 40/40 |       |
  | D9     |      |          |       | 24/24 | 24/24 | 40/40 | 40/40 | 40/40 |

- Hard memory controller width per side, SoC variants. Each cell is top / bottom. [Tables 6-19, 6-21, 6-23, p.6-42 to p.6-43]

  | Device                      | U484 | U672 | F896               |
  | --------------------------- | ---- | ---- | ------------------ |
  | Cyclone V SE A2, A4, A5, A6 | 0/0  | 0/40 | 0/40 (A5, A6 only) |
  | SX C2, C4, C5, C6           |      | 0/40 | 0/40 (C5, C6 only) |
  | ST D5 and D6                |      |      | 0/40               |

- HPS hard memory controller width. [Tables 6-20, 6-22, 6-24, p.6-42 to p.6-43]

  | Device                      | U484 | U672 | F896             |
  | --------------------------- | ---- | ---- | ---------------- |
  | Cyclone V SE A2, A4, A5, A6 | 32   | 40   | 40 (A5, A6 only) |
  | SX C2, C4, C5, C6           |      | 40   | 40 (C5, C6 only) |
  | ST D5 and D6                |      |      | 40               |

- Revision entry 2022.07.05 records that the Cyclone V E hard memory controller width table was updated to add information for package U484 of the Cyclone V E A9 device. [p.6-44]

### Chapter 7: Configuration, Design Security, and Remote System Upgrades (CV-52007)

- Cyclone V devices support 1.8 V, 2.5 V, 3.0 V, and 3.3 V programming voltages and several configuration schemes. [p.7-1]
- The configuration schemes covered are FPP (x8 and x16), AS (x1 and x4), PS, JTAG, and CvP over PCIe. The schemes-and-features table lists 1-bit, 8-bit, and 16-bit data widths and a JTAG entry of 1 bit at 33 MHz. [Table 7-1, p.7-2]
- CvP configures the device through PCIe instead of an external flash or ROM, offers the fastest configuration rate, and conforms to the PCIe 100 ms power-up-to-active time requirement. [p.7-2]
- The partial reconfiguration feature is available for Cyclone V E, GX, SE, and SX devices with the "SC" suffix in the part number. The document directs contacting local Intel sales representatives for device availability and ordering. [footnote 19, p.7-2]
- MSEL pins must be hardwired to VCCPGM or GND without pull-up or pull-down resistors. Altera recommends connecting them directly because driving MSEL from a microprocessor or other controlling device may not guarantee the VIL or VIH of the MSEL pins, which must be maintained throughout the configuration stages. [p.7-2]
- MSEL is a five-pin bus, MSEL[4..0]. The listed MSEL codes are: [Table 7-2, p.7-2 to p.7-3]

  | Scheme and options                                      | VCCPGM            | Fast POR | Standard POR |
  | ------------------------------------------------------- | ----------------- | -------- | ------------ |
  | FPP x16, compression disabled, design security disabled | 1.8/2.5/3.0/3.3 V | `00000`  | `00100`      |
  | FPP x16, design security enabled                        | 1.8/2.5/3.0/3.3 V | `00001`  | `00101`      |
  | FPP x16, compression enabled                            | 1.8/2.5/3.0/3.3 V | `00010`  | `00110`      |
  | PS                                                      |                   | `10000`  | `10001`      |
  | AS x1 and x4                                            | 3.0/3.3 V         | `10010`  | `10011`      |

  The document also lists a further group with codes `10100`/`11000`, `10101`/`11001`, and `10110`/`11010`. JTAG uses any valid MSEL pin setting.
- The configuration scheme must also be selected in the Configuration page of the Device and Pin Options dialog box, which sets the corresponding option bit in the programming file. [p.7-3]
- Reconfiguration is initiated by pulling nCONFIG low to at least the minimum tCFG low-pulse width (except for partial reconfiguration). When pulled low, nSTATUS and CONF_DONE are pulled low and all I/O pins are tied to an internal weak pull-up. [p.7-3]
- During power up, all power supplies monitored by the POR circuitry, including VCCPGM and VCCPD, must ramp from 0 V to the recommended operating voltage within the ramp-up time specification. Otherwise nCONFIG must be held low until all supplies reach the recommended level. [p.7-5]
- The configuration input buffers do not share power lines with the regular I/O buffers, so the configuration input pin operating voltage is independent of VCCIO during configuration and Cyclone V devices do not require configuration voltage constraints on VCCIO. [p.7-5]
- VCCPD is a dedicated programming power supply powering the I/O pre-drivers and the JTAG I/O pins TCK, TMS, TDI, and TDO. Supported configuration voltages are 2.5, 3.0, and 3.3 V. If bank VCCIO is 2.5 V or lower, VCCPD must be powered at 2.5 V. If VCCIO is greater than 2.5 V, VCCPD must be greater than VCCIO (VCCIO 3.0 V requires VCCPD at 3.0 V or above. VCCIO 3.3 V requires VCCPD at 3.3 V). [p.7-5]
- POR delay is the interval between all POR-monitored supplies reaching the recommended operating voltage and nSTATUS being released high. POR delay is set using the MSEL pins, and user I/O pins are tied to an internal weak pull-up until the device is configured. [p.7-5]
- Configuration can be restarted automatically with the **Auto-restart configuration after error** option on the General page of Device and Pin Options. Otherwise nSTATUS can be monitored to detect errors and configuration restarted by pulling nCONFIG low for at least tCFG. [p.7-6]
- The initialization clock source is the internal oscillator (default), the CLKUSR pin, or the DCLK pin. With the internal oscillator the device is provided with enough clock cycles for proper initialization. [p.7-6]
- If CLKUSR is the initialization clock source and nCONFIG is pulled low to restart configuration during initialization, CLKUSR or DCLK must continue toggling until nSTATUS goes low and then high again. [p.7-6]
- After CONF_DONE goes high, the CLKUSR or DCLK pin is enabled after the time specified by tCD2CU. After that period the device requires a minimum number of clock cycles specified by Tinit to initialize properly and enter user mode as specified by tCD2UMC. [p.7-6]
- The optional INIT_DONE pin can be enabled to monitor the initialization stage. After INIT_DONE is pulled high, initialization is complete and the design starts executing. [p.7-6]
- During device initialization the FPGA registers, core logic, and I/O are not released from reset at the same time. Intel recommends holding the entire design in reset for a period following the tCD2UM or tCD2UMC specifications before starting any operation, and states that the tCD2UM range for Cyclone V devices is between 175 us to 437 us. [p.7-6 to p.7-7]
- For an external device reacting to an FPGA output pin, the document instructs ensuring the external device ignores the FPGA output pin state until the external INIT_DONE pin goes high, and keeping the input state to the external device constant with external logic until then. [p.7-7]
- FPP timing notes: after power up the FPGA holds nSTATUS low for the POR delay. CONF_DONE is low after power up, before and during configuration. DCLK must not be left floating after configuration although it is ignored and may toggle. FPP x16 uses DATA[15..0] and FPP x8 uses DATA[7..0], with DATA[15..5] available as user I/O after configuration depending on dual-purpose pin settings. After CONF_DONE goes high, two additional falling edges on DCLK begin initialization and entry into user mode. [Figures 7-2 and 7-3, p.7-8 to p.7-9]
- When the DCLK-to-DATA[] ratio is greater than 1, DCLK may be paused by holding it low, and when DCLK restarts the external host must provide data on the DATA[15..0] pins prior to the first DCLK rising edge. [Figure 7-3, p.7-9]
- AS timing note: the time between the nCSO falling edge and the first toggling of DCLK is more than 15 ns. In AS x4 mode the signal represents AS_DATA[3..0] and the EPCQ sends 4 bits of data for each DCLK cycle. [Figure 7-4, p.7-10]
- Configuration pin power sources: TDI, TMS, TCK, and TDO are powered by VCCPD of the bank in which the pin resides. CLKUSR, DEV_OE, DEV_CLRn, and DATA[15..5] are powered by VCCPGM during configuration and by VCCIO of their bank when used as user I/O pins. [p.7-11]
- The DCLK, AS_DATA0, AS_DATA1, AS_DATA2, AS_DATA3, and nCSO pins have 25 kOhm pull-up resistors when the MSEL pins are set to the AS configuration scheme. [p.7-11]
- Configuration pin roles: MSEL[4..0] input powered by VCCPGM. nSTATUS and CONF_DONE bidirectional, VCCPGM/pull-up. nCE and nCONFIG input, VCCPGM. nCEO output with user-mode I/O role, pull-up. CRC_ERROR and INIT_DONE optional outputs with user-mode I/O role, pull-up. PR_REQUEST (input), PR_READY, PR_ERROR, PR_DONE (outputs) for partial reconfiguration and CvP_CONFDONE (output) for CvP, all VCCPGM/VCCIO. [Table 7-3, p.7-12 to p.7-13]
- Intel recommends using the General Purpose I/O (GPIO) IBIS model for the configuration pins. [p.7-13]
- Configuration pin I/O standards and drive strength. All are 3.0 V LVTTL, fast slew rate only, OCT not enabled. [Table 7-4, p.7-13 to p.7-14]

  | Pin                                         | Drive strength | Function      |
  | ------------------------------------------- | -------------- | ------------- |
  | nSTATUS                                     | 4 mA           | dedicated     |
  | CONF_DONE                                   | 4 mA           | dedicated     |
  | CvP_CONFDONE                                | 4 mA           | dual function |
  | DCLK                                        | 12 mA          | dedicated     |
  | TDO                                         | 12 mA          | dedicated     |
  | AS_DATA0/ASDO, AS_DATA1, AS_DATA2, AS_DATA3 | 8 mA           | dedicated     |
  | INIT_DONE                                   | 8 mA           | dual function |
  | CRC_ERROR                                   | 8 mA           | dual function |
  | nCSO                                        | 8 mA           | dedicated     |

- Dual-purpose configuration pin options in Device and Pin Options. The table also carries "Enable PR pin" (General). [Table 7-5, p.7-14]

  | Pin       | Option text                           | Category                 |
  | --------- | ------------------------------------- | ------------------------ |
  | CLKUSR    | "Enable user-supplied start-up clock" | General                  |
  | DEV_CLRn  | "Enable device-wide reset"            | General                  |
  | DEV_OE    | "Enable device-wide output enable"    | General                  |
  | INIT_DONE | "Enable INIT_DONE output"             | General                  |
  | nCEO      | "Enable nCEO pin"                     | General                  |
  | CRC_ERROR |                                       | Error Detection CRC page |

- The FPP configuration scheme uses an external host such as a microprocessor, MAX II device, or MAX V device, supports 8- and 16-bit data widths, and is described as the fastest method to configure Cyclone V devices. Configuration data can be stored as `.rbf`, `.hex`, or `.ttf`. [p.7-15]
- Two DCLK falling edges are required after CONF_DONE goes high to begin device initialization, for both uncompressed and compressed configuration data in an FPP configuration. [p.7-15]
- FPP multi-device pin guidelines: tie nCONFIG, nSTATUS, DCLK, DATA[], and CONF_DONE of all devices in the chain together. Ensure DCLK and DATA[] are buffered for every fourth device to prevent signal integrity and clock skew problems. All devices in the chain must use the same data width. Devices configured from the same configuration data must be of the same package and density. [p.7-16]
- Tying CONF_DONE and nSTATUS together makes the devices initialize and enter user mode at the same time. If any device flags an error on nSTATUS it resets the chain, configuration stops for the entire chain, and all devices must be reconfigured. [p.7-16]
- When a device completes configuration, its nCEO pin is released low to activate the nCE pin of the next device, and configuration of the second device begins automatically in one clock cycle. When all nCE pins are connected to GND, configuration for those devices begins and ends at the same time. [p.7-17]
- Configuration data in the `.rbf` file is little endian. For the byte sequence 02 1B EE 01 in FPP x8, the LSB of a byte is BIT0 and the MSB is BIT7, giving D[7..0] values 0000 0010, 0001 1011, 1110 1110, 0000 0001. [Table 7-6, p.7-18]
- In FPP x16 the first byte in the file is the LSB of the configuration word and the second byte is the MSB, so the same file bytes form WORD0 = 1B02 and WORD1 = 01EE. Upper and lower bits or bytes must not be swapped. Sending incorrect configuration data may cause unexpected behavior on the CONF_DONE signal. [Table 7-7, p.7-18 to p.7-19]
- The AS configuration scheme supports AS x1 (1-bit data width) and AS x4 (4-bit data width). AS x4 provides four times faster configuration time, and in AS the Cyclone V device controls the configuration interface. [p.7-19]
- After power-up in AS, the device drives DCLK with the default 12.5 MHz internal oscillator to read the configuration bitstream from serial flash, and determines configuration options (clock source, DCLK frequency, AS x1 or AS x4) by reading option bits located from 0x80 to 0x127 at the start of the programming file. [p.7-19]
- If AS configuration is interrupted (for example by data corruption), nSTATUS asserts low to indicate a configuration error then deasserts high to restart configuration. With no image or a corrupted image in the serial flash, nSTATUS pulses low repeatedly as the control block retries indefinitely. [p.7-19]
- The maximum DCLK frequency supported by the AS configuration scheme is 100 MHz, except for the AS multi-device configuration scheme. DCLK can be sourced from CLKUSR or the internal oscillator, with internal oscillator choices of 12.5, 25, 50, or 100 MHz selectable in the Configuration page of Device and Pin Options. [p.7-19]
- In AS, the device drives control signals on the falling edge of DCLK and latches configuration data on the following falling edge. [p.7-19]
- Only AS x1 mode supports multi-device configuration. The first device in the chain is the configuration master and subsequent devices are configuration slaves. [p.7-21]
- AS multi-device pin guidelines: hardwire the MSEL pins of the first device to AS and the MSEL pins of subsequent devices to PS. Tie nCONFIG, nSTATUS, DCLK, DATA[], and CONF_DONE of all devices together. Buffer DCLK and DATA[] every fourth device. Any other Altera device supporting PS configuration can be part of the chain as a configuration slave. [p.7-22]
- AS configuration time estimates: for AS x1, `.rbf` size × (minimum DCLK period / 1 bit per DCLK cycle). For AS x4, `.rbf` size × (minimum DCLK period / 4 bits per DCLK cycle). Compressing the configuration data reduces configuration time by a design-dependent amount. [p.7-23]
- EPCS devices support AS x1 mode. EPCQ devices support AS x1 and AS x4 modes. [p.7-23]
- During configuration the device enables the EPCS or EPCQ by driving nCSO low into the device's nCS pin, uses DCLK and ASDO to send operation commands and read address signals, and receives data on AS_DATA[] from the EPCS/EPCQ DATA[] pin. [p.7-24]
- To gain control of the EPCS pins, nCONFIG must be held low and nCE pulled high, which resets the device and tri-states the AS configuration pins. [p.7-24]
- Data setup timing slack must satisfy tDCLK − (tBT_DCLK + tCLQV + tBT_DATA) ≥ tDSU, and hold timing slack must satisfy tBT_DCLK + tCLQX + tBT_DATA ≥ tDH, where tDCLK is the DCLK period, tBT_DCLK and tBT_DATA are board trace propagation delays for DCLK and data, tCLQV is clock low to output valid, tCLQX is output hold time, and tDSU and tDH are the minimum data setup and hold times required by the FPGA. [p.7-24 to p.7-25]
- EPCS and EPCQ devices can be programmed in-system using a USB-Blaster, EthernetBlaster, EthernetBlaster II, or ByteBlaster II download cable, or using a microprocessor with the SRunner software driver. In-system programming can use either the AS programming interface or the JTAG interface, with the JTAG route requiring the serial flash loader (SFL) IP to be downloaded into the device as a bridge. [p.7-25]
- When programming EPCS and EPCQ, the download cable disables access to the AS interface by driving nCE high and pulls nCONFIG low to hold the device in the reset stage. After programming completes the cable releases nCE and nCONFIG, allowing the pull-down and pull-up resistors to drive the pins to GND and VCCPGM. [p.7-28]
- During EPCQ programming with the download cable, DATA0 transfers programming data, operation command, and address information into the EPCQ. During verification, DATA1 transfers programming data back to the download cable. [p.7-28]
- The PS configuration scheme uses an external host, either a microprocessor, MAX II device, MAX V device, or host PC. Configuration data can be stored as `.pof`, `.rbf`, `.hex`, or `.ttf`. [p.7-29]
- With `.rbf`, `.hex`, or `.ttf` in PS, the LSB of each data byte is sent first. The document's example is the byte sequence 02 1B EE 01 FA transmitted as 0100-0000 1101-1000 0111-0111 1000-0000 0101-1111. [p.7-29]
- Configuration data in PS is shifted serially into the DATA0 pin. With the Intel Quartus Prime programmer and CLKUSR enabled, no clock source needs to be provided for the pin to initialize the device. [p.7-29]
- PS multi-device pin guidelines: tie nCONFIG, nSTATUS, DCLK, DATA0, and CONF_DONE of all devices together. Devices configured from the same configuration data must be of the same package and density. [p.7-32]
- JTAG instructions take precedence over other configuration schemes. The Intel Quartus Prime software generates a `.sof` for JTAG configuration, and JRunner with `.rbf` or a `.jam`/`.jbc` file can be used with third-party programmer tools. [p.7-34]
- To configure a single device in a JTAG chain the programming software sets other devices to bypass mode, transferring data from TDI to TDO through a single bypass register with configuration data available on TDO one clock cycle later. [p.7-35]
- CONF_DONE low indicates configuration has failed and CONF_DONE high indicates configuration was successful. After configuration data is transmitted serially through TDI, the TCK port is clocked an additional 1,222 cycles to perform device initialization. [p.7-35]
- JTAG multi-device guidelines: isolate the CONF_DONE and nSTATUS pins so each device enters user mode independently. The number of devices in a chain is limited only by the drive capability of the download cable. With four or more devices in a JTAG chain, buffer the TCK, TDI, and TMS pins with an on-board buffer. [p.7-36]
- The CONFIG_IO JTAG instruction configures the I/O buffers through the JTAG port before or during device configuration, interrupting configuration and enabling all JTAG instructions. Otherwise only the BYPASS, IDCODE, and SAMPLE JTAG instructions can be issued. After board-level testing the device must be reconfigured by issuing PULSE_NCONFIG over JTAG or by pulsing nCONFIG low in FPP, PS, or AS. [p.7-37]
- Cyclone V devices can receive a compressed configuration bitstream and decompress it in real time during configuration. Preliminary data indicates compression typically reduces the configuration file size by 30% to 55% depending on the design. [p.7-38]
- Decompression is supported in all configuration schemes except JTAG. [p.7-38]
- Compression is enabled before compilation via Assignment > Device > Device and Pin Options > Configuration > **Generate compressed bitstreams**, or after compilation via File > Convert Programming Files, selecting the output type, adding a `.sof` under SOF Data, and turning on the Compression check box in its Properties. [p.7-38]
- A combination of compressed and uncompressed configuration in the same multi-device chain is supported only for AS or PS multi-device configuration, and is not allowed for FPP because of the difference in the DCLK-to-DATA[] ratio. [p.7-38 to p.7-39]
- Remote system upgrade sequence: logic in the device receives a configuration image from a remote location over a protocol such as TCP/IP, PCI, UDP, UART, or a proprietary interface. The logic stores the image in non-volatile configuration memory. The logic starts a reconfiguration cycle with the new image. On error the circuitry detects it, reverts to a safe configuration image, and provides error status. [p.7-39]
- Each device requires one factory image, which processes errors from the remote system upgrade circuitry, communicates with the remote host and stores new application images in local non-volatile memory, determines the application image to load, enables or disables the user watchdog timer and loads its time-out value, and instructs the circuitry to start a reconfiguration cycle. [p.7-40]
- Image storage locations in EPCS or EPCQ devices: the factory configuration image at start address PGM[23..0] = 24'h000000. Application configuration images at any sector boundary, with Altera recommending only one image per sector boundary. [p.7-40]
- For EPCQ 256, the application configuration image address granularity must be 32'h00000100, with the most significant 24 bits of the 32-bit start address written to the PGM[23..0] bits. If the Intel Quartus Prime software or SRunner software is not used for EPCQ 256 programming, the EPCQ 256 device must be put into four-byte addressing mode before programming and configuring. [p.7-40]
- The remote system upgrade circuitry contains the remote system upgrade registers, a watchdog timer, and a state machine controlling them. The Altera Remote Update IP core controls the RU_DOUT, RU_SHIFTnLD, RU_CAPTnUPDT, RU_CLK, RU_DIN, RU_nCONFIG, and RU_nRSTIMER signals internally. [p.7-41]
- The remote system upgrade circuitry is enabled by selecting Active Serial x1/x4 or Configuration Device from the Configuration scheme list, then selecting Remote from the Configuration mode list, both in the Configuration page of the Device and Pin Options dialog box. The Remote Update Intel FPGA IP core provides a memory-like interface to the remote system upgrade circuitry. [p.7-42]
- Remote system upgrade registers. [Table 7-8, p.7-43]

  | Register | Clocking and access                                                                                                                                                      |
  | -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
  | Shift    | accessible by the logic array and clocked by RU_CLK, with bits[4..0] taking the status register contents and bits[37..0] taking the update and control register contents |
  | Control  | clocked by the 10-MHz internal oscillator                                                                                                                                |
  | Update   | clocked by RU_CLK and updated by the factory configuration                                                                                                               |
  | Status   | updated by the circuitry after each reconfiguration to indicate the triggering event                                                                                     |

- Control register bits: bit 0 AnF ("Application not Factory"), reset value 1'b0. Bits 1..24 PGM[0..23], reset value 24'h000000, holding the upper 24 bits of the AS configuration start address (StAdd[31..8]) with the 8 LSB zero. Bit 25 Wd_en (user watchdog timer enable), reset value 1'b0. Bits 26..37 Wd_timer[11..0] (user watchdog time-out value), reset value 12'b000000000000. These are the default values after the device exits POR and during reconfiguration back to the factory configuration image. [Table 7-9 and footnote 22, p.7-43 to p.7-44]
- Status register bits, all with reset value 1'b0. [Table 7-10 and footnote 23, p.7-44]

  | Bit | Name         | Meaning                                    |
  | --- | ------------ | ------------------------------------------ |
  | 0   | CRC          | CRC error during application configuration |
  | 1   | nSTATUS      | nSTATUS asserted                           |
  | 2   | Core_nCONFIG | reconfiguration triggered from the core    |
  | 3   | nCONFIG      | nCONFIG asserted                           |
  | 4   | Wd           | user watchdog timer expired                |

  After the device exits POR and power-up, the status register content is 5'b00000.
- Remote system upgrade state machine operation: after power-up the registers reset to 0 and the factory image loads. User logic sets the AnF bit to 1, the application image start address, and the watchdog timer settings. When the configuration reset (RU_CONFIG) goes low, the state machine updates the control register from the update register and triggers reconfiguration with the application image. On error the state machine falls back to the factory image, resets the control and update registers to 0, and updates the status register with error information. On success the system stays in the application configuration. [p.7-44]
- The user watchdog timer prevents a faulty application configuration from stalling the device indefinitely. It is automatically disabled in the factory configuration and enabled in the application configuration, and begins counting as soon as the application configuration enters user mode. On expiry the circuitry generates a time-out signal and updates the status register. [p.7-44 to p.7-45]
- The watchdog counter is 29 bits wide with a maximum count value of 2^29. Only the most significant 12 bits are specified when setting the timer value, and the granularity of the timer setting is 2^17 cycles. [p.7-45]
- Design security features listed include secure operation mode for both volatile and non-volatile key through the tamper protection bit setting. Security against copying (the security key is stored in the device and cannot be read out through any interface, and configuration file read-back is not supported). Security against reverse engineering (the configuration file formats are proprietary). And security against tampering (with the tamper protection bit set, the device accepts only configuration files encrypted with the same key). [p.7-45]
- When compression is used with the design security feature, the configuration file is first compressed and then encrypted by the Intel Quartus Prime software. Using design security with an FPP configuration scheme requires a different DCLK-to-DATA[] ratio. [p.7-45]
- The Altera Unique Chip ID IP core acquires the chip ID of an FPGA device and allows identifying the device in a design as part of a security feature protecting against an unauthorized device. [p.7-46]
- In JTAG secure mode (entered after power-up when the tamper-protection bit is enabled), only the mandatory JTAG 1149.1 instructions SAMPLE/PRELOAD, BYPASS, EXTEST, and the optional IDCODE and SHIFT_EDERROR_REG are allowed. The UNLOCK instruction deactivates JTAG secure mode and the LOCK instruction restores it, and both can only be issued during user mode. [p.7-46]
- Two security key types are offered: volatile (reprogrammable, powered by the VCCBAT battery) and non-volatile (one-time programming, with third-party vendors offering in-socket programming). VCCBAT is a dedicated power supply for volatile key storage that continuously supplies power to the volatile register regardless of the on-chip supply condition. [Table 7-11 and footnotes 24, 25, p.7-46 to p.7-47]
- Key programming is performed through the JTAG pins interface, and nSTATUS must be released high before any key-programming attempt. The KEY_CLR_VREG JTAG instruction clears the volatile key and KEY_VERIFY verifies that it has been cleared. [p.7-47]
- Security modes: no key. Volatile key (with or without tamper protection bit set). Non-volatile key (with or without tamper protection bit set). With the tamper protection bit set, unencrypted configuration files are not accepted. There is no configuration-time impact compared with unencrypted schemes except FPP with AES, decompression, or both,, which requires a DCLK up to ×4 the data rate. [Table 7-12, p.7-47]
- Unencrypted configuration bitstreams in the volatile key and non-volatile key security modes are supported for board-level testing only. [p.7-48]
- For the volatile key with tamper protection bit set, the device does not accept the encrypted configuration file if the volatile key is erased, and the key cannot be reprogrammed. For the volatile key mode without the tamper protection bit, the key can be reprogrammed if erased. [p.7-48]
- Enabling the tamper protection bit disables test mode and disables programming through the JTAG interface. The process is irreversible and prevents Altera from carrying out failure analysis. [p.7-48]
- Design security implementation steps: the Intel Quartus Prime software generates the design security key programming file and encrypts the configuration data using a user-defined 256-bit security key. The encrypted configuration file is stored in external memory. The AES key programming file is programmed into the device through a JTAG interface. At system power-up the external memory device sends the encrypted configuration file to the device. [p.7-48]
- Revision entry 2019.01.16 records the addition of the note that DCLK, AS_DATA0, AS_DATA1, AS_DATA2, AS_DATA3, and nCSO have 25 kOhm pull-up resistors in the AS configuration scheme. Entry 2018.11.23 records the addition of the "Evaluating Data Setup and Hold Timing Slack in AS Configuration" topic and the removal of "Trace Length and Loading Guideline". [p.7-49]

### Chapter 8: SEU Mitigation (CV-52008)

- The on-chip error detection CRC circuitry performs auto-detection of CRC errors during configuration, optional CRC error detection and identification in user mode, optional internal scrubbing in user mode, and testing of error detection functions by deliberately injecting errors through the JTAG interface, all without impact on fitting or device performance. [p.8-1]
- At configuration, the Intel Quartus Prime software computes a 16-bit CRC value for each frame. A configuration bitstream can contain more than one CRC value depending on the number of data frames, and the data frame length varies by device. [p.8-1]
- During configuration the precomputed CRC value shifts into the CRC circuitry while the FPGA CRC engine computes the CRC for the data frame. A mismatch sets nSTATUS low to indicate a configuration error. [p.8-1]
- In user mode, each data frame stored in the CRAM contains a 32-bit precomputed CRC value. The error detection circuitry continuously computes a 32-bit CRC for each CRAM frame and compares it with the precomputed value. [p.8-2]
- If the CRC values match, the 32-bit CRC signature in the syndrome register is set to zero. Otherwise the signature is non-zero, the CRC_ERROR pin is pulled high, and the error type and location are identified. [p.8-2]
- Within a frame, the error detection circuitry can detect all single-, double-, triple-, quadruple-, and quintuple-bit errors. Bit location and error type are reported for single-bit and double-adjacent errors, and bit-location reporting is not guaranteed for other error patterns. The document states the probability of detection for all error patterns is 99.9999%. [p.8-2]
- The user-mode error detection process continues until the device is reset by setting the nCONFIG signal low. [p.8-2]
- Internal scrubbing corrects single-bit and double-adjacent errors detected in each data frame in user mode without reconfiguring the device. The feature is available for Cyclone V E, GX, SE, and SX devices with the "SC" suffix in the part number. [p.8-2]
- Estimated minimum EMR update interval in µs, Cyclone V E: A2 1.47, A4 1.47, A5 1.79, A7 2.33, A9 3.23. Cyclone V GX: C3 1.09, C4 1.79, C5 1.79, C7 2.33, C9 3.23. Cyclone V GT: D5 1.79, D7 2.33, D9 3.23. [Table 8-1, p.8-3]
- Estimated minimum EMR update interval in µs, SoC variants: A2 1.77, A4 1.77, A5 2.31, A6 2.31. C4 1.77, C5 2.31, C6 2.31. D5 2.31, D6 2.31. Using a lower clock frequency increases the interval and therefore the time required to recover from an SEU. [Table 8-1 and p.8-3]
- The error detection process speed is controlled by a clock frequency division factor of 2^n set in the Intel Quartus Prime software. With a 100 MHz internal oscillator the maximum error detection frequency is 100 MHz and the minimum 390 kHz, with valid n values 0, 1, 2, 3, 4, 5, 6, 7, 8 giving a divisor range of 1 – 256. [Table 8-2, p.8-3 to p.8-4]
- The error detection clock frequency depends on the device and on the internal oscillator frequency, which varies from 42.6 MHz to 100 MHz. [p.8-4]
- Entire-device CRC calculation times can be computed as Maximum time (n) = 2^(n-8) × tMAX and Minimum time (n) = 2^n / minimum divisor setting × tMIN, where the range of n is from 0 to 8. tMIN uses the maximum clock frequency with the minimum divisor factor per member code and tMAX uses the minimum clock frequency with the maximum divisor factor of 8. [p.8-4]
- Device EDCRC detection times, Cyclone V E. [Table 8-3, p.8-4]

  | Device | tMIN (ms) | tMAX (s) | Minimum divisor setting |
  | ------ | --------- | -------- | ----------------------- |
  | A2     | 9         | 2.76     | 2                       |
  | A4     | 9         | 2.76     | 2                       |
  | A5     | 14        | 4.21     | 2                       |
  | A7     | 12        | 7.36     | 1                       |
  | A9     | 23        | 13.93    | 1                       |

- Device EDCRC detection times, Cyclone V GX and GT. [Table 8-3, p.8-5]

  | Device | tMIN (ms) | tMAX (s) | Minimum divisor setting |
  | ------ | --------- | -------- | ----------------------- |
  | C3     | 12        | 1.83     | 4                       |
  | C4     | 14        | 4.21     | 2                       |
  | C5     | 14        | 4.21     | 2                       |
  | C7     | 12        | 7.36     | 1                       |
  | C9     | 23        | 13.93    | 1                       |
  | D7     | 12        | 7.36     | 1                       |
  | D9     | 23        | 13.93    | 1                       |

  Cyclone V GT: D5 14 / 4.21 / 2.
- Device EDCRC detection times, SoC variants. [Table 8-3, p.8-5]

  | Device | tMIN (ms) | tMAX (s) | Minimum divisor setting |
  | ------ | --------- | -------- | ----------------------- |
  | SE A2  | 14        | 4.21     | 2                       |
  | SE A4  | 14        | 4.21     | 2                       |
  | SE A5  | 12        | 7.36     | 1                       |
  | SE A6  | 12        | 7.36     | 1                       |
  | SX C2  | 14        | 4.21     | 2                       |
  | SX C4  | 14        | 4.21     | 2                       |
  | SX C5  | 12        | 7.36     | 1                       |
  | SX C6  | 12        | 7.36     | 1                       |
  | ST D5  | 12        | 7.36     | 1                       |
  | ST D6  | 12        | 7.36     | 1                       |

- Error detection is enabled through Assignments > Device > Device and Pin Options > Error Detection CRC, turning on **Enable Error Detection CRC_ERROR pin**, optionally **Enable open drain on CRC_ERROR pin** (turning it off sets the pin as output), optionally **Enable internal scrubbing**, and selecting a valid divisor in the **Divide error check frequency by** list. [p.8-5]
- Error detection registers and widths. [Table 8-5, p.8-6 to p.8-7]

  | Register                      | Width   | Note                                                     |
  | ----------------------------- | ------- | -------------------------------------------------------- |
  | syndrome register             | 32 bits | holds the CRC signature calculated for the current frame |
  | Error message register (EMR)  | 67 bits |                                                          |
  | JTAG update register          | 67 bits |                                                          |
  | JTAG shift register           | 67 bits | accessed via the SHIFT_EDERROR_REG JTAG instruction      |
  | User update register          | 67 bits |                                                          |
  | User shift register           | 67 bits |                                                          |
  | JTAG fault injection register | 46 bits | used with the EDERROR_INJECT JTAG instruction            |
  | Fault injection register      | 46 bits |                                                          |

- Error types reported in the EMR error type field (bits 3, 2, 1, 0): `0000` no CRC error. `0001` location of a single-bit error is identified. `0010` location of a double-adjacent error is identified. `1111` error types other than single-bit and double-adjacent errors. [Table 8-6, p.8-8]
- JTAG fault injection register field ranges: bit range 31:0, 41:32, and 45:42, with error-byte encodings `0000` no error, `0001` single-bit error, `0010` double adjacent error. [Table 8-7, p.8-8]
- The user-mode error detection process activates automatically when the FPGA enters user mode and continues to run until the device is reset, even when an error is detected in the current frame. [p.8-8]
- Timing: the CRC_ERROR pin is always driven low during CRC calculation. When an error occurs the EDCRC hard block takes 32 clock cycles to update the EMR, after which the pin is driven high, so EMR contents can be retrieved starting at the rising edge of CRC_ERROR. The pin stays high until the current frame is read and is then driven low again for 32 clock cycles. The read operation must complete within one frame of the CRC verification to ensure information integrity. [p.8-9]
- Error information can be retrieved via the core interface or the JTAG interface using the SHIFT_EDERROR_REG JTAG instruction. [p.8-9]
- To recover from a CRC error, the hosting system drives the nCONFIG signal low and waits a safe time before reconfiguring the device. [p.8-9]
- The EDERROR_INJECT JTAG instruction (code `00 0001 0101`) injects single or double-adjacent errors into the configuration data by controlling the JTAG fault injection register. Errors can only be injected into the first frame of the configuration data, error information can be monitored at any time, and Altera recommends reconfiguring the FPGA after the test completes. [Table 8-8, p.8-9 to p.8-10]
- The testing process can be automated by creating a Jam file (`.jam`), verifying CRC functionality in-system and on-the-fly without reconfiguring the device. [p.8-10]
- Revision entries 2019.10.03 and 2018.06.01 both record updates to the Minimum time calculation formula in *CRC Calculation Time For Entire Device*. [p.8-10]

### Chapter 9: JTAG Boundary-Scan Testing (CV-52009)

- Cyclone V devices support IEEE Std. 1149.1 BST, and BST can be performed before, after, and during configuration. [p.9-1]
- The IDCODE is unique for each Cyclone V device and is used to identify devices in a JTAG chain. It is 32 bits, composed of a 4-bit version field, a 16-bit part number, an 11-bit manufacture identity, and a 1-bit LSB. In all listed devices the version is `0000`, the manufacture identity is `000 0110 1110`, and the LSB is `1`. [Table 9-1, p.9-1 to p.9-3]
- IDCODE part numbers, Cyclone V E: A2 `0010 1011 0001 0101`. A4 `0010 1011 0000 0101`. A5 `0010 1011 0010 0010`. A7 `0010 1011 0001 0011`. A9 `0010 1011 0001 0100`. [Table 9-1, p.9-2]
- IDCODE part numbers, Cyclone V GX. [Table 9-1, p.9-2]

  | Device | Part number           |
  | ------ | --------------------- |
  | C3     | `0010 1011 0000 0001` |
  | C4     | `0010 1011 0001 0010` |
  | C5     | `0010 1011 0000 0010` |
  | C7     | `0010 1011 0000 0011` |
  | C9     | `0010 1011 0000 0100` |

  Cyclone V GT D5, D7, and D9 carry the same part numbers as GX C5, C7, and C9 respectively.
- IDCODE part numbers, Cyclone V SE. [Table 9-1, p.9-2 to p.9-3]

  | Device | Part number           |
  | ------ | --------------------- |
  | A2     | `0010 1101 0001 0001` |
  | A4     | `0010 1101 0000 0001` |
  | A5     | `0010 1101 0001 0010` |
  | A6     | `0010 1101 0000 0010` |

  Cyclone V SX C2, C4, C5, and C6 carry the same part numbers as SE A2, A4, A5, and A6. Cyclone V ST D5 is `0010 1101 0001 0010` and D6 is `0010 1101 0000 0010`.
- Supported JTAG instruction codes. [Table 9-2, p.9-3 to p.9-7]

  | Instruction    | Code           |
  | -------------- | -------------- |
  | SAMPLE/PRELOAD | `00 0000 0101` |
  | EXTEST         | `00 0000 1111` |
  | BYPASS         | `11 1111 1111` |
  | USERCODE       | `00 0000 0111` |
  | IDCODE         | `00 0000 0110` |
  | HIGHZ          | `00 0000 1011` |
  | CLAMP          | `00 0000 1010` |
  | PULSE_NCONFIG  | `00 0000 0001` |
  | CONFIG_IO      | `00 0000 1101` |
  | LOCK           | `01 1111 0000` |
  | UNLOCK         | `11 0011 0001` |
  | KEY_CLR_VREG   | `00 0010 1001` |
  | KEY_VERIFY     | `00 0001 0011` |

- EXTEST forces a test pattern at the output pins and captures results at the input pins to detect opens and shorts. Its high-impedance state is overridden by the bus hold and weak pull-up resistor features. [Table 9-2, p.9-4]
- USERCODE examines the user electronic signature (UES) and places the 32-bit USERCODE register between TDI and TDO. The UES value is the default value before configuration and is only user-defined after the device is configured. [Table 9-2, p.9-4]
- IDCODE is the default instruction at power up and in the TAP RESET state, so the JTAG device ID can be shifted out by going to the SHIFT_DR state without loading any instruction. [Table 9-2, p.9-5]
- HIGHZ sets all user I/O pins to an inactive drive state and places the 1-bit bypass register between TDI and TDO. CLAMP places the bypass register between TDI and TDO while holding the I/O pins to the state defined by the boundary-scan register update register data. For both, the programmable weak pull-up resistor or bus hold feature overrides the pin value when testing after configuration. [Table 9-2, p.9-5 to p.9-6]
- PULSE_NCONFIG emulates pulsing the nCONFIG pin low to trigger reconfiguration without affecting the physical pin. [Table 9-2, p.9-6]
- CONFIG_IO allows I/O reconfiguration through the JTAG ports using the I/O configuration shift register (IOCSR) for JTAG testing, and can only be issued after the nSTATUS pin goes high. [Table 9-2, p.9-6]
- LOCK can only be accessed through JTAG core access in user mode and cannot be accessed through external JTAG pins in test or user mode. [Table 9-2, p.9-6]
- If the device is in a reset state and the nCONFIG or nSTATUS signal is low, the device IDCODE might not be read correctly. The IDCODE instruction must be issued only when nCONFIG and nSTATUS are high. [p.9-7]
- In JTAG secure mode (entered after power up when the tamper-protection bit is enabled), the JTAG pins support only BYPASS, SAMPLE/PRELOAD, EXTEST, IDCODE, SHIFT_EDERROR_REG, and UNLOCK. [p.9-7]
- The document carries a caution never to invoke the following private instruction codes, which can damage and render the device unusable: `1100010000`, `0011001001`, `1100010011`, `1100010111`, `0111100000`, `1110110011`, `0011100101`, `0011100110`, `0000101010`, `0000101011`. [p.9-7]
- Four dedicated JTAG pins are used, TDI, TDO, TMS, and TCK. Cyclone V devices do not support the optional TRST pin. [p.9-8]
- The TCK pin has an internal weak pull-down resistor while TDI and TMS have internal weak pull-up resistors. The 3.3, 3.0, or 2.5 V VCCPD supply of I/O bank 3A powers TDO, TDI, TMS, and TCK, and all user I/O pins are tri-stated during JTAG configuration. [p.9-8]
- The TDO output buffer meets VOH (MIN) of 2.4 V for VCCPD of 3.3 V or 3.0 V and VOH (MIN) of 2.0 V for VCCPD of 2.5 V. The supported TDO/TDI voltage combination table marks all combinations of Cyclone V TDO VCCPD (3.3, 3.0, 2.5 V) with device TDI input buffers at VCCPD 3.3, 3.0, 2.5 V and non-Cyclone V VCC 3.3, 2.5, 1.8, 1.5 V as supported, with the requirement that the TDO output voltage level meets the specification of the TDI pin it drives and that a non-Cyclone V input buffer must be tolerant to the TDO VCCPD voltage. [Table 9-3 and footnote 26, p.9-8]
- BYPASS, IDCODE, and SAMPLE JTAG instructions can be issued before, after, or during configuration without interrupting configuration. To perform testing before configuration nCONFIG must be held low, and to perform BST during configuration the CONFIG_IO instruction interrupts configuration, after which PULSE_CONFIG or a low pulse on nCONFIG reconfigures the device. [p.9-8]
- The chip-wide reset (DEV_CLRn) and chip-wide output enable (DEV_OE) pins do not affect JTAG boundary-scan or configuration operations. [p.9-8]
- The IEEE Std. 1149.1 BST circuitry is enabled after the device powers up. For Cyclone V SoC FPGAs both the HPS and the FPGA must be powered up to perform BST, and the HPS should be held in reset while performing BST to stop the I/Os being accessed or set up by the HPS. [p.9-9]
- To permanently disable the IEEE Std. 1149.1 circuitry: connect TMS to the VCCPD supply of Bank 3A, TCK to GND, TDI to the VCCPD supply of Bank 3A, and leave TDO open. The JTAG pins are dedicated and no software option is available to disable JTAG in Cyclone V devices. [Table 9-4 and footnote 27, p.9-9]
- BST guideline: if the "10..." pattern does not shift out of the instruction register through TDO during the first clock cycle of the SHIFT_IR state, the TAP controller did not reach the proper state. The remedies given are to return to the RESET state and send the code `01100` to the TMS pin to advance to SHIFT_IR, and to check the connections to the VCC, GND, JTAG, and dedicated configuration pins. [p.9-10]
- BST guideline: perform a SAMPLE/PRELOAD test cycle before the first EXTEST test cycle so that known data is present at the device pins on entering EXTEST mode. If the OEJ update register contains 0, the data in the OUTJ update register is driven out. [p.9-10]
- BST guideline: EXTEST testing is not supported during in-circuit reconfiguration. Testing must wait for configuration to complete or use the CONFIG_IO instruction to interrupt configuration. [p.9-10]
- BST guideline: after configuration, pins in a differential pin pair cannot be tested. Performing BST after configuration requires editing and redefining the BSC group corresponding to those differential pin pairs as an internal cell. [p.9-10]
- The boundary-scan register is a serial shift register using TDI as input and TDO as output, consisting of 3-bit peripheral elements associated with Cyclone V I/O pins, usable to test external pin connections or capture internal data. [p.9-10]
- The 3-bit BSC comprises capture registers connected to internal device data through the OUTJ, OEJ, and PIN_IN signals, and update registers connected to external data through the PIN_OUT and PIN_OE signals. The TAP controller generates the global shift, clock, and update control signals internally, and a decode of the instruction register generates the MODE signal. The data signal path runs from serial data in (SDI) to serial data out (SDO). [p.9-11]
- The TDI, TDO, TMS, and TCK pins, all VCC and GND pin types, and VREF pins do not have BSCs. [p.9-11]
- Boundary-scan cell behaviour by pin type: user I/O pins capture OUTJ, OEJ, PIN_IN and drive PIN_OUT, PIN_OE, INJ. Dedicated input pins capture 0, 1, PIN_IN and drive nothing, with PIN_IN driving to the control logic. Dedicated bidirectional (open drain) pins capture 0, OEJ, PIN_IN with PIN_IN driving to the configuration control. Dedicated bidirectional pins capture OUTJ, OEJ, PIN_IN with PIN_IN driving to the configuration control and OUTJ to the output buffer. Dedicated output pins capture OUTJ, 0, 0 with OUTJ driving to the output buffer. [Table 9-5, p.9-11 to p.9-12]
- Pin-type footnotes: dedicated inputs include PLL_ENA, VCCSEL, PORSEL, nIO_PULLUP, nCONFIG, MSEL0, MSEL1, MSEL2, MSEL3, MSEL4, and nCE. Dedicated bidirectional (open drain) includes CONF_DONE and nSTATUS. Dedicated bidirectional includes DCLK. Dedicated output includes nCEO. [footnotes 28–31, p.9-12]

### Chapter 10: Power Management (CV-52010)

- Total power consumption consists of static power (consumed by the configured device when powered up with no clocks operating) and dynamic power (additional consumption due to signal activity or toggling). [p.10-1]
- Dynamic power is given by P = ½CV² × frequency, where P is power, C is load capacitance, and V is the supply voltage level. The document notes power is design-dependent and determined by the operating frequency of the design. [p.10-1 to p.10-2]
- The hot-socketing circuitry monitors the VCCIO, VCCPD, and VCC power supplies and all VCCIO and VCCPD banks. These supplies can be powered up or down in any sequence. [p.10-2]
- During hot-socketing operation the I/O pin capacitance is less than 15 pF and the clock pin capacitance is less than 20 pF. [p.10-2]
- Stated hot-socketing advantages: signals can be driven into I/O, dedicated input, and dedicated clock pins before or during power up or power down without damaging the device, and external input signals to an unpowered device will not power the supplies through internal paths. Output buffers are tri-stated during system power up or power down. A device can be inserted into or removed from a powered-up system board without damaging or interfering with board operation. And the devices are immune to latch up when hot-socketed into an active system. [p.10-2]
- Altera uses GND as a reference for hot-socketing and I/O buffer circuitry designs. GND must be connected between boards before connecting the power supplies, otherwise a pulled-up GND could cause an out-of-specification I/O voltage or over-current condition. [p.10-2]
- The hot-socketing feature tri-states the output buffer during power up and power down. When the supplies are below the threshold voltage the circuitry generates an internal HOTSCKT signal, which prevents excess I/O leakage during power up. [p.10-2]
- The output buffer cannot flip from the state set by the hot-socketing circuitry at very low voltage. To allow CONF_DONE and nSTATUS to operate during configuration, the hot-socketing feature is not applied to those configuration pins, so they will drive out during power up and power down. [p.10-3]
- The weak pull-up resistor (R) in the IOE is enabled during configuration download to keep the I/O pins from floating, and the 3.3-V tolerance control circuit allows the I/O pins to be driven by 3.3 V before the power supplies are powered while preventing the I/O pins from driving out before the device enters user mode. [p.10-3]
- Power-up sequence recommendation: power up VCCBAT at any time. Ramp the Group 1 power rails to a minimum of 80% of their full rail before Group 2 starts. Power up VCCE_GXB and VCCL_GXB together with VCC. [p.10-4]
- Maximum power supply current transient and typical duration. [Table 10-1 and footnote 32, p.10-4 to p.10-5]

  | Supply    | Max transient | Typical duration |
  | --------- | ------------- | ---------------- |
  | VCCPD     | 1000 mA       | 50 µs            |
  | VCCIO     | 250 mA        | 200 µs           |
  | VCC_AUX   | 400 mA        | 10 µs            |
  | VCC       | 350 mA        | 100 µs           |
  | VCCPD_HPS | 400 mA        | 50 µs            |
  | VCCIO_HPS | 100 mA        | 200 µs           |
  | VCC_HPS   | 420 mA        | 100 µs           |

  Only typical duration is provided because it may vary with board design.
- The current transients at VCCPD and VCCPD_HPS occur only when the recommended power-up sequence is not followed. The transients at VCCIO and VCCIO_HPS occur if those rails are powered up before VCCPD and VCCPD_HPS respectively. The transients at VCC_AUX, VCC, and VCC_HPS may occur with any power-up sequence. VCCPD_HPS, VCCIO_HPS, and VCC_HPS rails are only available on Cyclone V SX, SE, and ST devices. [footnotes 33–40, p.10-4 to p.10-5]
- The stated maximum currents for VCCIO and VCCPD (and for VCCIO_HPS and VCCPD_HPS) apply to all voltage levels supported by the Cyclone V device. [footnotes 34 and 39, p.10-4 to p.10-5]
- These transients have a finite duration bounded by the time at which the device enters configuration mode. For Cyclone V SX, SE, and ST devices the transients may be observed after powering up and before all supplies reach the recommended operating range. The document instructs comparing the table against the minimum current requirements in the Early Power Estimator (EPE) and accounting for any excess in the power regulator design. [p.10-4]
- The POR circuitry keeps the device in the reset state until the power supply outputs are within the recommended operating range. A POR event occurs when the device is powered up until the supplies reach that range within the maximum power supply ramp time, tRAMP. If tRAMP is not met, the I/O pins and programming registers remain tri-stated and device configuration could fail. [p.10-5]
- The POR circuitry uses an individual detecting circuit to monitor each configuration-related power supply independently, with the main POR circuitry gated by the outputs of all individual detectors. The main POR signal is asserted when power starts to ramp up and released after the last ramp-up power reaches the POR trip level. [p.10-6]
- In user mode the main POR signal is asserted when any monitored power supply goes below its POR trip level, forcing the device into the reset state. [p.10-6]
- During power-up mode the POR circuitry checks the functionality of the I/O level shifters powered by the VCCPD and VCCPGM supplies, and the main POR circuitry waits for all individual POR circuitries to release the POR signal before allowing the control block to start programming the device. [p.10-6]
- Power supplies monitored by the POR circuitry: VCC_AUX, VCCBAT, VCC, VCCPD, VCCPGM, VCC_HPS, VCCPD_HPS, VCCRSTCLK_HPS, VCC_AUX_SHARED. Only VCCPD3A and VCCPD5A are monitored among the VCCPD rails. [Table 10-2 and footnote 41, p.10-7]
- Power supplies not monitored by the POR circuitry: VCCE_GXBL, VCCH_GXBL, VCCL_GXBL, VCCA_FPLL, VCCIO, VCCIO_HPS, VCCPLL_HPS. [Table 10-2, p.10-7]
- For the device to exit POR, the VCCBAT power supply must be powered even if the volatile key is not used. [p.10-7]
- Revision entry 2017.09.19 records the addition of a note to VCCPD in *Power Supplies Monitored and Not Monitored*. Entry January 2015 (2015.01.23) records the addition of VCC_AUX_SHARED to the monitored supplies. Entry June 2013 (2013.06.28) records the addition of power-up sequences for Cyclone V SX, SE, and ST devices. [p.10-8]

## Specifications and procedures

Cross-chapter collection of the document's exact procedural steps and formulas. Values in this section duplicate the anchored bullets above and carry the same anchors.

- **RSKM equation:** `RSKM = (TUI − SW − TCCS) / 2`. [p.5-81]
- **Emulated LVDS resistor network equation:** `(R_S × R_P/2) / (R_S + R_P/2) = 50 Ω`, with the figure giving R_S = 120 Ω and R_P = 170 Ω. [p.5-56 to p.5-57]
- **PLL synthesis:** output ports use M/(N × C) scaling. The control loop drives the VCO to match `fin × (M/N)`. [p.4-37]
- **PLL fractional value:** `K/2^X`, K an integer between 0 and (2^X – 1), X = 8, 16, 24, or 32. [p.4-38]
- **AS configuration time (x1):** `.rbf size × (minimum DCLK period / 1 bit per DCLK cycle)`. **AS x4:** `.rbf size × (minimum DCLK period / 4 bits per DCLK cycle)`. [p.7-23]
- **AS data setup slack:** `tDCLK − (tBT_DCLK + tCLQV + tBT_DATA) ≥ tDSU`. **AS hold slack:** `tBT_DCLK + tCLQX + tBT_DATA ≥ tDH`. [p.7-24 to p.7-25]
- **Entire-device CRC calculation time:** `Maximum time (n) = 2^(n-8) × tMAX`. `Minimum time (n) = 2^n / minimum divisor setting × tMIN`, n from 0 to 8. [p.8-4]
- **Dynamic power:** `P = ½CV² × frequency`. [p.10-1]
- **Basic FIR equation:** `y[n] = Σ (i=1..k) c[i] x[n−i−1]`. [p.3-16]
- **Complex multiplication:** `(a + jb) × (c + jd) = [(a × c) − (b × d)] + j[(a × d) + (b × c)]`. [p.3-13]
- **Procedure, verifying pin migration compatibility:** eight numbered steps beginning with Assignments > Pin Planner and ending with Export to `.csv`. [p.5-6]
- **Procedure, enabling compression before compilation:** three numbered steps ending in **Generate compressed bitstreams**. **After compilation:** six numbered steps under File > Convert Programming Files. [p.7-38]
- **Procedure, enabling error detection and internal scrubbing:** eight numbered steps under Assignments > Device > Device and Pin Options > Error Detection CRC. [p.8-5]
- **Procedure, design security implementation:** four numbered steps from key-file generation through device configuration with the encrypted file. [p.7-48]
- **Procedure, remote system upgrade state machine:** five numbered steps from power-up factory image load through staying in the application configuration after successful reconfiguration. [p.7-44]

## Constraints and requirements

- Memory block setup or hold time must not be violated on any input register during read or write operations, in single-port RAM, simple dual-port RAM, true dual-port RAM, or ROM mode. The document marks this as a Caution against corrupting memory contents. [p.2-10, p.2-12]
- The memory blocks have no internal conflict resolution circuitry, so external conflict resolution logic must be implemented for true dual-port writes to the same location. [p.2-3]
- Each independent single-port RAM in M10K packed mode must not exceed half the target block size. [p.2-16]
- To use the DSP pre-adder, all input data and multipliers must have the same clock setting. Enabling the pre-adder removes input cascade support. [p.3-2, p.3-4]
- All DSP systolic registers must be clocked with the same clock source as the output register bank. [p.3-9]
- The PLL input clock must come from dedicated clock input pins, PLL-fed GCLKs, or PLL-fed RCLKs. Internally generated clock networks cannot drive the PLLs. [p.4-12]
- `areset` must be asserted every time the PLL loses lock to guarantee the correct phase relationship, and must be included when PLL reconfiguration or clock switchover is enabled. [p.4-31]
- Automatic clock switchover requires both clock inputs running at FPGA configuration and periods differing by no more than 20%. [p.4-40]
- Manual clock switchover requires `extswitch` to be held high for at least three `inclk` cycles (plus any specified delay cycles), and both `inclk0` and `inclk1` must be running when `extswitch` goes high. [p.4-42, p.4-43]
- ZDB mode requires the same I/O standard on input clocks and clock outputs and prohibits differential I/O standards on the PLL clock input or output pins. The bidirectional feedback I/O pin must be assigned a single-ended I/O standard. [p.4-34]
- EFB mode requires the same I/O standard on the input clock, feedback input, and clock outputs, and is supported only on corner fractional PLLs. [p.4-36]
- To drive LVDS channels, the PLLs must be used in integer PLL mode. [p.5-13, p.5-71, p.5-73]
- R_D OCT can only be used if VCCPD is set to 2.5 V. [p.5-46]
- R_T OCT with calibration requires the bank VCCIO to match the I/O standard of the pin where it is enabled, and is not available on output pins. [p.5-43]
- R_S OCT and R_T OCT cannot be used simultaneously. R_S OCT and programmable current strength cannot be configured for the same I/O buffer. [p.5-47, p.5-51]
- Slew rate control is disabled if the R_S OCT feature is used. Bus-hold and the programmable pull-up resistor are mutually exclusive. Bus-hold must be disabled to configure an I/O pin for differential signals. [p.5-31, p.5-32, p.5-38]
- Voltage-referenced bidirectional and output signals must match the bank VCCIO voltage. Each bank supports only one VCCIO and one VREF level. [p.5-12, p.5-13]
- VCCPD power pins must be connected to a 2.5 V, 3.0 V, or 3.3 V power supply. [p.5-11]
- The DQ x4 bus mode is not supported. Only x8 and x16 are supported. [p.6-3]
- Unused HPS DQ/DQS pins on Cyclone V SE, SX, and ST devices cannot be used as user I/Os. [p.6-3]
- DQS phase shifts on pins referenced by the same DLL must all be a multiple of 90° and all at one frequency. [p.6-20]
- After each DLL reset, 2,560 clock cycles must elapse before data can be captured properly. [p.6-21]
- Hard memory controller bonding is supported only for controllers configured with one port. ECC for a bonded interface must be implemented external to the controllers. [p.6-37]
- MSEL pins must be hardwired to VCCPGM or GND without pull-up or pull-down resistors, and their VIL/VIH must be maintained throughout the configuration stages. [p.7-2]
- If bank VCCIO is 2.5 V or lower, VCCPD must be 2.5 V. If VCCIO is greater than 2.5 V, VCCPD must be greater than VCCIO. [p.7-5]
- All FPP chain devices must use the same data width, and devices sharing one configuration data set must be of the same package and density (FPP and PS). [p.7-16, p.7-32]
- DCLK and DATA[] must be buffered every fourth device in FPP and AS multi-device chains. [p.7-16, p.7-22]
- Two additional DCLK falling edges after CONF_DONE goes high are required to begin initialization in FPP, PS, and the timing waveforms generally. [p.7-8, p.7-9, p.7-11, p.7-15]
- Decompression is supported in all configuration schemes except JTAG, and mixed compressed/uncompressed multi-device chains are allowed only for AS or PS. [p.7-38, p.7-38 to p.7-39]
- The EPCQ 256 application configuration image address granularity must be 32'h00000100, and non-Quartus/non-SRunner programming requires four-byte addressing mode first. [p.7-40]
- Enabling the tamper protection bit is irreversible, disables test mode, and disables JTAG programming. With a volatile key and the tamper bit set, an erased key cannot be reprogrammed. [p.7-48]
- Errors can only be injected into the first frame of the configuration data using EDERROR_INJECT. [p.8-10]
- The EMR read operation must complete within one frame of the CRC verification to ensure information integrity. [p.8-9]
- The listed JTAG private instruction codes must never be invoked, as they can damage and render the device unusable. [p.9-7]
- The IDCODE JTAG instruction must be issued only when nCONFIG and nSTATUS are high. [p.9-7]
- Cyclone V SoC FPGAs require both HPS and FPGA to be powered up for BST, with the HPS held in reset. [p.9-9]
- EXTEST is not supported during in-circuit reconfiguration. [p.9-10]
- GND must be connected between boards before connecting power supplies during hot socketing. [p.10-2]
- Group 1 power rails must be ramped to a minimum of 80% of their full rail before Group 2 starts. VCCE_GXB and VCCL_GXB must be powered up together with VCC. [p.10-4]
- VCCBAT must be powered for the device to exit POR, even if the volatile key is not used. [p.10-7]

Recommendations, recorded as such (the document's own modal strength preserved):

- Altera recommends using the CLK<#>p pins for optimal performance when single-ended clock inputs drive the PLLs. [p.4-12]
- Altera recommends a low bandwidth setting for the upstream PLL and a high bandwidth setting for the downstream PLL when cascading. [p.4-28]
- Altera recommends source synchronous mode for source synchronous data transfers. [p.4-32]
- Altera recommends resetting the PLL using `areset` to maintain phase relationships when using clock switchover. [p.4-40]
- Altera recommends using a clamping diode on the I/O pins if the input signal is 3.0 V or 3.3 V. [p.5-11]
- Intel recommends performing IBIS or SPICE simulations to determine the best current strength setting, and Altera recommends the same for slew rate and for validating custom emulated-LVDS resistor values. [p.5-34, p.5-57]
- Intel recommends using OCT with the SSTL-15, SSTL-135, and SSTL-125 I/O standards for external memory interfaces. [p.5-45, p.5-51]
- Altera recommends assigning DQ and DQS pins manually for x8 or x16 groups whose members are used as RZQ pins. [p.6-3]
- Altera recommends using the HDR registers in the postamble enable circuitry if the controller runs at half the frequency of the I/Os. [p.6-28]
- Intel recommends holding the entire design in reset following the tCD2UM or tCD2UMC specifications before starting any operation after entering user mode. [p.7-6 to p.7-7]
- Intel recommends using the GPIO IBIS model for the configuration pins. [p.7-13]
- Altera recommends storing only one remote-system-upgrade image at one sector boundary. [p.7-40]
- Altera recommends reconfiguring the FPGA after an EDERROR_INJECT test completes. [p.8-10]
- The document instructs setting a PLL that generates only the DLL input reference clock to Direct Compensation mode for better performance. [p.6-18 to p.6-19]

## Stated gaps and ambiguities

- The document defers all electrical and timing specifications to the *Cyclone V Device Datasheet*. The notes therefore contain no numeric values for these. [p.4-20, p.5-9, p.5-20, p.5-35, p.5-58, p.6-1, p.6-21, p.7-1, p.7-6, p.7-19, p.10-2, p.10-5, p.10-7]

  - POR delay and tRAMP
  - Ramp-up time specifications
  - tSTATUS, tCFG, tCD2CU, Tinit, tCD2UM, tCD2UMC
  - DCLK frequency specification for AS
  - FPP, AS, PS, and JTAG configuration timing
  - DLL frequency-mode ranges
  - Programmable IOE delay and output buffer delay values
  - TCCS and sampling window values
  - VICM specification for LVPECL
  - VREF pin capacitance
  - Absolute maximum ratings and maximum allowed overshoot
  - Hot-socketing specifications
  - Battery specifications for VCCBAT
  - And estimated uncompressed `.rbf` file sizes and FPP DCLK-to-DATA[] ratio
  - The notes therefore contain no numeric values for these
- The number of multipliers per device and which device packages and feature options contain hard memory controllers are deferred to the *Cyclone V Device Overview*. The maximum LVDS data rate is likewise deferred there. [p.3-1, p.5-62, p.6-40]
- Transceiver detail, including 6 Gbps transceiver channel counts, is deferred to *Cyclone V Device Handbook Volume 2: Transceivers*. [p.5-2, p.5-3]
- Per-package pin availability, DQ pin counts per group, external clock output availability, hard memory controller pin identification, and PLL connectivity to GCLK and RCLK networks are deferred to the pin-out files, pin connection guidelines, and an external PLL-connectivity spreadsheet. [p.4-2, p.4-15, p.4-30, p.5-21, p.6-3]
- Each chapter links to a "Cyclone V Device Handbook: Known Issues" knowledge-base article that "lists the planned updates to the Cyclone V Device Handbook chapters". The content of those planned updates is not in the document.
- Transcription artefact: several wide tables lost their column headers or row labels during conversion, so some cells cannot be attributed to a specific column. The tables noted while reading are:

  | Table                | Subject                               | What was lost                                                                                                                   |
  | -------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
  | Table 2-4            | initial power-up values               | the Memory Type column, leaving four rows of Used/Bypassed → Zero (cleared)/Read memory contents without block-type attribution |
  | Table 2-11           | parity bit support                    | the two descriptions cannot be reliably assigned to the M10K and MLAB columns                                                   |
  | Table 3-1            | supported operational modes           | the mode names, leaving only the resource-instance counts and Yes/No support columns                                            |
  | Table 4-1            | clock resources                       | the per-device resource counts are largely lost                                                                                 |
  | Table 5-2, Table 5-3 | GX and GT package plans               | GPIO and XCVR columns interleave                                                                                                |
  | Table 5-11           | LVDS reference clock pin substitution | the Device Variant column is partly blank                                                                                       |
  | Table 7-1            | configuration schemes                 | the scheme names are missing from the leftmost column                                                                           |
  | Table 7-2            | MSEL settings                         | the configuration scheme label is missing from the first code group                                                             |

- Table 2-9 (memory modes) descriptions are truncated mid-sentence in several rows, for example "You can perform only one read or one write operation at a time. deasserted. operation."
- The document states two different byte-enable/parity relationships in adjacent places without reconciling them: Table 2-11 describes a parity bit that is "the fifth bit associated with each 4 data bits in data widths of 5, 10, 20, and 40" and one that is "the ninth bit associated with each byte", while the byte-enable text states that "on the M10K blocks, the byte enable function controls 8 data bits and 2 parity bits; on the MLABs, the byte enable function controls all 10 bits in the widest mode". The mapping between the two statements is not made explicit. [p.2-14]
- Configuration data compression figures are explicitly hedged: "Preliminary data indicates that compression typically reduces the configuration file size by 30% to 55% depending on the design." [p.7-38]
- The document does not state the content of the "Group 1" and "Group 2" power rail sets referenced by the power-up sequence recommendation in text. That grouping appears only in Figure 10-3, which is not transcribed. [p.10-4]
- Figures and block diagrams throughout are present only as image references in the transcription. Their internal content (for example the fractional PLL high-level block diagram, the PLL location maps, the IOE structure, the DQS pin/DLL connection maps, the PHYCLK network maps, and the error message register map) is not available in text form.
