import {
  type Assembler,
  ECR,
  EIPC,
  EIPSW,
  FEPC,
  PSW,
  r2,
  r6,
  r8,
  r9,
  r10,
  r11,
  r12,
  r13,
  r14,
  r15,
  r16,
  r17,
  r18,
  r19,
  r20,
  r21,
  r22,
  r23,
  r24,
  r25,
  r26,
  r27,
  r28,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r10/r11/r15-r17 main operands, r11-r14 flag captures, r1 reserved
// (the vector stubs clobber it). Handlers record into registers the main
// flow then asserts: trap-record r20-r23, trap-high r24, illegal r25/r26,
// zero-divide r27/r28, duplexed r18/r19/r2. r17 selects the trap handler's
// mode: 0 records and returns, 1 traps again to force the duplexed path.

const STATUS = 0x05000000;
const PASS = 0x600d;

let seq = 0;
const uniq = (prefix: string) => `${prefix}_${(seq += 1)}`;

const progress = (a: Assembler) => {
  a.addImm(1, r9);
  a.stH(r9, 0, r6);
};

const expectEq = (a: Assembler, reg: Register, value: number) => {
  const ok = uniq("ok");
  const spin = uniq("spin");
  a.loadImm(value >>> 0, r8);
  a.cmp(r8, reg);
  a.be(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

const captureFlags = (a: Assembler) => {
  a.setf(0x0, r11); // OV
  a.setf(0x1, r12); // CY
  a.setf(0x2, r13); // Z
  a.setf(0x4, r14); // S
};

const expectFlags = (a: Assembler, ov: number, cy: number, z: number, s: number) => {
  expectEq(a, r11, ov);
  expectEq(a, r12, cy);
  expectEq(a, r13, z);
  expectEq(a, r14, s);
};

export default defineRom({
  name: "cpu-except",
  header: { gameTitle: "OPENFPGA CPU EXC", makerCode: "OF", gameCode: "VEXC", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of " +
    "16 status cells reads 0x600D (0110 0000 0000 1101, lit = 1). Failure: the square " +
    "stays hollow and the status cells show the number of the failing check, counted " +
    "in program order in rom.ts; the bottom row shows the PC of the failure spin. In " +
    "Mednafen: loads as OPENFPGA CPU EXC and the last halfword written to 0x05000000 " +
    "is 0x600D.",
  handlers: {
    trap: "onTrap",
    trapHigh: "onTrapHigh",
    invalidOpcode: "onInvalid",
    divideByZero: "onDivZero",
    duplexedException: "onDuplex",
  },
  program: (a) => {
    let duplexRet = 0;

    // ---- handlers first, so their addresses are known when the main
    // flow asserts them; execution still enters at "start" ----

    // Mode 0 records the saved state and returns; mode 1 traps again so the
    // duplexed path runs, then returns through both RETIs.
    a.label("onTrap");
    a.cmpImm(1, r17);
    a.bne("trapRecord");
    duplexRet = a.pc + 2;
    a.trap(1);
    a.reti();
    a.label("trapRecord");
    a.stsr(EIPC, r20);
    a.stsr(EIPSW, r21);
    a.stsr(ECR, r22);
    a.stsr(PSW, r23);
    a.reti();

    a.label("onTrapHigh");
    a.stsr(ECR, r24);
    a.reti();

    // Faults save the faulting instruction itself, so resuming means
    // stepping EIPC over the two-byte instruction by hand.
    a.label("onInvalid");
    a.stsr(ECR, r25);
    a.stsr(EIPC, r26);
    a.mov(r26, r8);
    a.addImm(2, r8);
    a.ldsr(r8, EIPC);
    a.reti();

    a.label("onDivZero");
    a.stsr(ECR, r27);
    a.stsr(EIPC, r28);
    a.mov(r28, r8);
    a.addImm(2, r8);
    a.ldsr(r8, EIPC);
    a.reti();

    a.label("onDuplex");
    a.stsr(ECR, r19);
    a.stsr(FEPC, r18);
    a.stsr(PSW, r2);
    a.reti();

    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // Reset leaves NP set, which would turn the first exception fatal;
    // clearing the PSW is what every real program does before using traps.
    a.movImm(0, r10);
    a.ldsr(r10, PSW);

    // 1: a low-vector trap enters with the next instruction saved, the
    // pre-trap PSW in EIPSW, code 0xFFA3 in ECR's low half, and EP|ID set
    // inside the handler -- plus CY and S from the handler's own mode
    // compare (0 - 1), since entry preserves the flag bits.
    progress(a);
    a.movImm(0, r17);
    const trapRet = a.pc + 2;
    a.trap(3);
    expectEq(a, r20, trapRet);
    expectEq(a, r21, 0x00000000);
    expectEq(a, r22, 0x0000ffa3);
    expectEq(a, r23, 0x0000500a);

    // 2: vector 19 lands on the high handler with code 0xFFB3.
    progress(a);
    a.trap(19);
    expectEq(a, r24, 0x0000ffb3);

    // 3: RETI restores the PSW: carry and zero survive a trap round trip.
    progress(a);
    a.movImm(-1, r15);
    a.movImm(1, r16);
    a.add(r16, r15); // CY=1 Z=1
    a.trap(3);
    captureFlags(a);
    expectFlags(a, 0, 1, 1, 0);

    // 4: an invalid opcode (0x1B) raises 0xFF90 with the faulting address
    // saved; the handler steps EIPC past it to resume.
    progress(a);
    const illAddr = a.pc;
    a.halfword(0x6c00);
    expectEq(a, r25, 0x0000ff90);
    expectEq(a, r26, illAddr);

    // 5: dividing by zero raises 0xFF80 at the divide itself and leaves the
    // dividend register untouched.
    progress(a);
    a.movImm(5, r15);
    a.movImm(0, r11);
    const divAddr = a.pc;
    a.div(r11, r15);
    expectEq(a, r27, 0x0000ff80);
    expectEq(a, r28, divAddr);
    expectEq(a, r15, 5);

    // 6: a trap inside a trap duplexes: ECR carries both codes, FEPC the
    // inner return point, and the duplexed handler sees NP|EP|ID -- plus Z
    // from the mode compare (1 - 1) that chose this path. Both RETIs then
    // unwind cleanly back to here.
    progress(a);
    a.movImm(1, r17);
    a.trap(3);
    expectEq(a, r19, 0xffa1ffa3);
    expectEq(a, r18, duplexRet);
    expectEq(a, r2, 0x0000d001);

    // 7: the read-only system registers carry their fixed values, reserved
    // indexes read zero, and register 31 reads back the absolute value of
    // the last write.
    progress(a);
    a.stsr(6, r15); // PIR
    expectEq(a, r15, 0x00005346);
    a.stsr(7, r15); // TKCW
    expectEq(a, r15, 0x000000e0);
    a.stsr(30, r15);
    expectEq(a, r15, 0x00000004);
    a.stsr(8, r15);
    expectEq(a, r15, 0x00000000);
    a.movImm(-8, r15);
    a.ldsr(r15, 31);
    a.stsr(31, r15);
    expectEq(a, r15, 0x00000008);

    // 8: the wait controller reads back as WCR | 0xFC, both ways.
    progress(a);
    a.loadImm(0x02000024, r16);
    a.movImm(1, r15);
    a.stH(r15, 0, r16);
    a.inB(0, r16, r15);
    expectEq(a, r15, 0x000000fd);
    a.movImm(0, r10);
    a.stH(r10, 0, r16);
    a.inB(0, r16, r15);
    expectEq(a, r15, 0x000000fc);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();
  },
});
