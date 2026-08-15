import { type Assembler, r6, r8, r9, r15, r16, r17, r31, type Register } from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch, r15-r17 operands and markers, r31 the jal link, r1 reserved for
// pseudo-instructions.

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
  a.loadImm(value, r8);
  a.cmp(r8, reg);
  a.be(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

// Flag scenarios, each produced by one cmp whose result is r15 - r16.
// Names state the flags they leave: cmp sets flags exactly like sub.
const scenarios = {
  zero: { a: 1, b: 1 }, //                    Z=1 S=0 OV=0 CY=0
  positive: { a: 2, b: 1 }, //                Z=0 S=0 OV=0 CY=0
  negative: { a: 1, b: 2 }, //                Z=0 S=1 OV=0 CY=1
  overflow: { a: 0x80000000, b: 1 }, //       Z=0 S=0 OV=1 CY=0
  overflowNeg: { a: 0x7fffffff, b: -1 }, //   Z=0 S=1 OV=1 CY=1
} as const;

type Scenario = keyof typeof scenarios;

const setFlags = (a: Assembler, scenario: Scenario) => {
  a.loadImm(scenarios[scenario].a >>> 0, r15);
  a.loadImm(scenarios[scenario].b >>> 0, r16);
  a.cmp(r16, r15);
};

// One condition, both ways: a scenario where it must branch and one where it
// must fall through. A wrong take spins with the check number on the cells.
const checkTaken = (a: Assembler, branch: (label: string) => Assembler, scenario: Scenario) => {
  progress(a);
  setFlags(a, scenario);
  const ok = uniq("taken");
  const spin = uniq("spin");
  branch(ok);
  a.label(spin);
  a.br(spin);
  a.label(ok);
};

const checkNotTaken = (a: Assembler, branch: (label: string) => Assembler, scenario: Scenario) => {
  progress(a);
  setFlags(a, scenario);
  const cont = uniq("cont");
  const spin = uniq("spin");
  branch(spin);
  a.br(cont);
  a.label(spin);
  a.br(spin);
  a.label(cont);
};

export default defineRom({
  name: "cpu-branch",
  header: { gameTitle: "OPENFPGA CPU BR", makerCode: "OF", gameCode: "VBRA", revision: 0 },
  expectation:
    "On the Pocket: the centre square fills solid red (CPU halted) and the top row of " +
    "16 status cells reads 0x600D (0110 0000 0000 1101, lit = 1). Failure: the square " +
    "stays hollow and the status cells show the number of the failing check, counted " +
    "in program order in rom.ts; the bottom row shows the PC of the failure spin. In " +
    "Mednafen: loads as OPENFPGA CPU BR and the last halfword written to 0x05000000 " +
    "is 0x600D.",
  program: (a) => {
    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);

    // Checks 1-29: every condition, taken and not taken, against flag
    // scenarios chosen to separate near-identical conditions (S versus S^OV,
    // CY versus CY|Z). br has no false case and nop() has no true one.
    checkTaken(a, (l) => a.br(l), "positive"); //          1
    checkTaken(a, (l) => a.bv(l), "overflow"); //          2
    checkNotTaken(a, (l) => a.bv(l), "positive"); //       3
    checkTaken(a, (l) => a.bl(l), "negative"); //          4
    checkNotTaken(a, (l) => a.bl(l), "positive"); //       5
    checkTaken(a, (l) => a.be(l), "zero"); //              6
    checkNotTaken(a, (l) => a.be(l), "positive"); //       7
    checkTaken(a, (l) => a.bnh(l), "zero"); //             8
    checkNotTaken(a, (l) => a.bnh(l), "positive"); //      9
    checkTaken(a, (l) => a.bn(l), "negative"); //         10
    checkNotTaken(a, (l) => a.bn(l), "overflow"); //      11
    checkTaken(a, (l) => a.blt(l), "overflow"); //        12
    checkNotTaken(a, (l) => a.blt(l), "overflowNeg"); //  13
    checkTaken(a, (l) => a.ble(l), "zero"); //            14
    checkNotTaken(a, (l) => a.ble(l), "overflowNeg"); //  15
    checkTaken(a, (l) => a.bnv(l), "positive"); //        16
    checkNotTaken(a, (l) => a.bnv(l), "overflow"); //     17
    checkTaken(a, (l) => a.bnl(l), "positive"); //        18
    checkNotTaken(a, (l) => a.bnl(l), "negative"); //     19
    checkTaken(a, (l) => a.bne(l), "positive"); //        20
    checkNotTaken(a, (l) => a.bne(l), "zero"); //         21
    checkTaken(a, (l) => a.bh(l), "positive"); //         22
    checkNotTaken(a, (l) => a.bh(l), "zero"); //          23
    checkTaken(a, (l) => a.bp(l), "overflow"); //         24
    checkNotTaken(a, (l) => a.bp(l), "negative"); //      25
    checkTaken(a, (l) => a.bge(l), "overflowNeg"); //     26
    checkNotTaken(a, (l) => a.bge(l), "overflow"); //     27
    checkTaken(a, (l) => a.bgt(l), "overflowNeg"); //     28
    checkNotTaken(a, (l) => a.bgt(l), "zero"); //         29

    // 30: nop is the never-taken branch with displacement 0. Taking it
    // anyway would spin the PC on the nop itself.
    progress(a);
    setFlags(a, "zero");
    a.nop();

    // 31: jal runs the subroutine, links the address of the following
    // instruction into r31, and jmp(r31) comes back. The subroutine leaves a
    // marker so a jal that fell through is caught too.
    progress(a);
    a.movImm(0, r17);
    const returnPc = a.pc + 4;
    a.jal("sub");
    expectEq(a, r17, 0x5a);

    // 32: jr forward.
    progress(a);
    const jrSpin = uniq("spin");
    a.jr("jr_land");
    a.label(jrSpin);
    a.br(jrSpin);
    a.label("jr_land");

    // 33: jmp masks bit 0 of its target, because the PC cannot hold an odd
    // address. The landing pad sits at an even address captured at assembly
    // time; jumping to pad|1 must land on the pad, not one byte past it.
    progress(a);
    a.movImm(0, r17);
    a.br("jmp_over");
    const padPc = a.pc;
    a.label("jmp_pad");
    a.loadImm(0x1d, r17);
    a.jr("jmp_done");
    a.label("jmp_over");
    a.loadImm((padPc | 1) >>> 0, r16);
    a.jmp(r16);
    a.label("jmp_done");
    expectEq(a, r17, 0x1d);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();

    // The jal target, out of the fall-through path. Checks the link register
    // against the address computed when the jal was emitted.
    a.label("sub");
    a.loadImm(0x5a, r17);
    expectEq(a, r31, returnPc);
    a.jmp(r31);
  },
});
