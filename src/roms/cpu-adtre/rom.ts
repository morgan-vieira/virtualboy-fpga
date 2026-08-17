import {
  type Assembler,
  ADTRE,
  PSW,
  r6,
  r8,
  r9,
  r11,
  r12,
  r13,
  r14,
  r15,
  r19,
  r20,
  r21,
  r22,
  type Register,
} from "#scripts/lib/v810";
import { defineRom } from "#scripts/lib/vb-rom";

// The address trap: with AE set in PSW and ADTRE on an instruction's
// address, the CPU raises 0xFFC0 before fetching it, restore at current
// PC, AE cleared on entry [Scroll, CPU > Exceptions > Address Trap; V810
// manual ch.8]. The handler steps EIPC past the trapped instruction to
// resume -- the documented obligation, since returning unchanged re-traps.
//
// The arming stubs sit at the end of the program so the trap targets'
// addresses exist as constants when the stubs load them; execution reaches
// the stubs by jumping forward and returns by jumping back.
//
// Register budget: r6 status base, r9 check counter, r8 expected-value
// scratch (also the handler's EIPC step scratch -- safe, the trap only
// fires at the armed addresses), r11-r15 work; the handler records into
// r20 (ECR), r21 (EIPC), r22 (PSW) and counts in r19.

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

export default defineRom({
  name: "cpu-adtre",
  header: { gameTitle: "OPENFPGA CPU ADT", makerCode: "OF", gameCode: "VADT", revision: 0 },
  expectation:
    "On the Pocket, with Core Settings > Diagnostic Overlay set to On: the centre " +
    "square fills solid red (CPU halted) and the top row of 16 status cells reads " +
    "0x600D (0110 0000 0000 1101, lit = 1). Failure: the square stays hollow and " +
    "the cells show the failing check's number, counted in program order in rom.ts. " +
    "In Mednafen the ROM freezes at check 1 by design: beetle-vb stores ADTRE but " +
    "never checks it, so its trap never fires; the core follows the documents and " +
    "MiSTer.",
  handlers: { addressTrap: "onAdt" },
  program: (a) => {
    let t1Addr = 0;
    let t2Addr = 0;

    a.label("onAdt");
    a.stsr(4, r20); // ECR
    a.stsr(0, r21); // EIPC
    a.stsr(PSW, r22);
    a.stsr(0, r8);
    a.addImm(2, r8);
    a.ldsr(r8, 0); // resume past the trapped instruction
    a.addImm(1, r19);
    a.reti();

    a.label("start");
    a.di();
    a.loadImm(STATUS, r6);
    a.movImm(0, r9);
    a.movImm(0, r19);
    a.movImm(0, r11);
    a.ldsr(r11, PSW);
    a.di();

    // 1: an armed address traps before it executes: documented code, the
    // trapped PC saved, the instruction itself skipped by the handler.
    progress(a);
    a.jr("arm1");
    a.label("seq1");
    a.movImm(3, r13);
    t1Addr = a.pc;
    a.movImm(7, r13); // never runs: the handler steps over it
    a.movImm(5, r14);
    expectEq(a, r20, 0xffc0);
    expectEq(a, r21, t1Addr);
    expectEq(a, r13, 3);
    expectEq(a, r14, 5);
    expectEq(a, r19, 1);

    // 2: PSW inside the handler carried EP|ID with AE stripped.
    progress(a);
    expectEq(a, r22, 0x00005000);

    // 3: with AE clear, an armed address executes untrapped.
    progress(a);
    a.loadImm(0x00001000, r12); // ID only
    a.ldsr(r12, PSW);
    a.jr("arm2");
    a.label("seq2");
    a.movImm(2, r13);
    t2Addr = a.pc;
    a.movImm(9, r13); // executes: no trap without AE
    expectEq(a, r13, 9);
    expectEq(a, r19, 1);

    // Success.
    a.loadImm(PASS, r15);
    a.stH(r15, 0, r6);
    a.hang();

    // ---- arming stubs: emitted last, executed mid-flow ----
    a.label("arm1");
    a.loadImm(t1Addr, r11);
    a.ldsr(r11, ADTRE);
    a.loadImm(0x00003000, r12); // AE | ID
    a.ldsr(r12, PSW);
    a.jr("seq1");

    a.label("arm2");
    a.loadImm(t2Addr, r11);
    a.ldsr(r11, ADTRE);
    a.jr("seq2");
  },
});
