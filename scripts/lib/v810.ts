// Every encoding here was read off the decoder in
// .repos/beetle-vb-libretro/mednafen/hw_cpu/v810/ rather than from memory: an
// assembler bug and a core bug are indistinguishable from the outside, since
// both surface as a test ROM misbehaving on hardware. Check new opcodes against
// that decoder and add a test before trusting them.

export type Register = number;

// r0 always reads zero. r1 is the assembler temporary, so the pseudo-
// instructions below are free to clobber it; a real toolchain assumes the same.
export const r0 = 0;
export const r1 = 1;
export const r2 = 2;
export const r3 = 3;
export const r4 = 4;
export const r5 = 5;
export const r6 = 6;
export const r7 = 7;
export const r8 = 8;
export const r9 = 9;
export const r10 = 10;
export const r11 = 11;
export const r12 = 12;
export const r13 = 13;
export const r14 = 14;
export const r15 = 15;
export const r16 = 16;
export const r17 = 17;
export const r18 = 18;
export const r19 = 19;
export const r20 = 20;
export const r21 = 21;
export const r22 = 22;
export const r23 = 23;
export const r24 = 24;
export const r25 = 25;
export const r26 = 26;
export const r27 = 27;
export const r28 = 28;
export const r29 = 29;
export const r30 = 30;
export const r31 = 31;

export const EIPC = 0;
export const EIPSW = 1;
export const FEPC = 2;
export const FEPSW = 3;
export const ECR = 4;
export const PSW = 5;
export const PIR = 6;
export const TKCW = 7;
export const CHCW = 24;
export const ADTRE = 25;

const COND_V = 0x0;
const COND_L = 0x1;
const COND_E = 0x2;
const COND_NH = 0x3;
const COND_N = 0x4;
const COND_T = 0x5;
const COND_LT = 0x6;
const COND_LE = 0x7;
const COND_NV = 0x8;
const COND_NL = 0x9;
const COND_NE = 0xa;
const COND_H = 0xb;
const COND_P = 0xc;
const COND_F = 0xd;
const COND_GE = 0xe;
const COND_GT = 0xf;

// Bit string, CAXI and the format VII group share one opcode each; the
// sub-opcode constants below tell the members apart [v810_opt.h].
const OP_BSTR = 0x1f;
const OP_CAXI = 0x3a;
const OP_FPP = 0x3e;

const SUB_SCH0BSU = 0x00;
const SUB_SCH0BSD = 0x01;
const SUB_SCH1BSU = 0x02;
const SUB_SCH1BSD = 0x03;
const SUB_ORBSU = 0x08;
const SUB_ANDBSU = 0x09;
const SUB_XORBSU = 0x0a;
const SUB_MOVBSU = 0x0b;
const SUB_ORNBSU = 0x0c;
const SUB_ANDNBSU = 0x0d;
const SUB_XORNBSU = 0x0e;
const SUB_NOTBSU = 0x0f;

const SUB_CMPF_S = 0x00;
const SUB_CVT_WS = 0x02;
const SUB_CVT_SW = 0x03;
const SUB_ADDF_S = 0x04;
const SUB_SUBF_S = 0x05;
const SUB_MULF_S = 0x06;
const SUB_DIVF_S = 0x07;
const SUB_XB = 0x08;
const SUB_XH = 0x09;
const SUB_REV = 0x0a;
const SUB_TRNC_SW = 0x0b;
const SUB_MPYHW = 0x0c;

const OP_MOV = 0x00;
const OP_ADD = 0x01;
const OP_SUB = 0x02;
const OP_CMP = 0x03;
const OP_SHL = 0x04;
const OP_SHR = 0x05;
const OP_JMP = 0x06;
const OP_SAR = 0x07;
const OP_MUL = 0x08;
const OP_DIV = 0x09;
const OP_MULU = 0x0a;
const OP_DIVU = 0x0b;
const OP_OR = 0x0c;
const OP_AND = 0x0d;
const OP_XOR = 0x0e;
const OP_NOT = 0x0f;
const OP_MOV_I = 0x10;
const OP_ADD_I = 0x11;
const OP_SETF = 0x12;
const OP_CMP_I = 0x13;
const OP_SHL_I = 0x14;
const OP_SHR_I = 0x15;
const OP_EI = 0x16;
const OP_SAR_I = 0x17;
const OP_TRAP = 0x18;
const OP_RETI = 0x19;
const OP_HALT = 0x1a;
const OP_LDSR = 0x1c;
const OP_STSR = 0x1d;
const OP_DI = 0x1e;
const OP_MOVEA = 0x28;
const OP_ADDI = 0x29;
const OP_JR = 0x2a;
const OP_JAL = 0x2b;
const OP_ORI = 0x2c;
const OP_ANDI = 0x2d;
const OP_XORI = 0x2e;
const OP_MOVHI = 0x2f;
const OP_LD_B = 0x30;
const OP_LD_H = 0x31;
const OP_LD_W = 0x33;
const OP_ST_B = 0x34;
const OP_ST_H = 0x35;
const OP_ST_W = 0x37;
const OP_IN_B = 0x38;
const OP_IN_H = 0x39;
const OP_IN_W = 0x3b;
const OP_OUT_B = 0x3c;
const OP_OUT_H = 0x3d;
const OP_OUT_W = 0x3f;

export class AssemblyError extends Error {
  override readonly name = "AssemblyError";
}

const fail = (message: string): never => {
  throw new AssemblyError(message);
};

const checkRegister = (value: number, what: string): number =>
  Number.isInteger(value) && value >= 0 && value <= 31
    ? value
    : fail(`${what} must be a register r0-r31, got ${value}`);

const checkImm5 = (value: number): number =>
  Number.isInteger(value) && value >= -16 && value <= 15
    ? value & 0x1f
    : fail(`5-bit signed immediate out of range (-16..15), got ${value}`);

const checkUimm5 = (value: number): number =>
  Number.isInteger(value) && value >= 0 && value <= 31
    ? value
    : fail(`5-bit unsigned immediate out of range (0..31), got ${value}`);

const checkImm16 = (value: number): number =>
  Number.isInteger(value) && value >= -0x8000 && value <= 0xffff
    ? value & 0xffff
    : fail(`16-bit immediate out of range (-32768..65535), got ${value}`);

// Both displacements are measured from the address of the instruction itself,
// and both drop their low bit because instructions are halfword-aligned.
const checkDisp9 = (disp: number, label: string): number =>
  disp >= -0x100 && disp <= 0xfe
    ? disp & 0x1fe
    : fail(`branch to ${label} is ${disp} bytes away, out of range (-256..254)`);

const checkDisp26 = (disp: number, label: string): number =>
  disp >= -0x2000000 && disp <= 0x1fffffe
    ? disp & 0x3fffffe
    : fail(`jump to ${label} is ${disp} bytes away, out of range (+/-32MB)`);

type FixupKind = "disp9" | "disp26";

interface Fixup {
  readonly kind: FixupKind;
  readonly offset: number;
  readonly pc: number;
  readonly label: string;
}

export interface AssembledProgram {
  readonly bytes: Uint8Array;
  readonly origin: number;
  readonly labels: ReadonlyMap<string, number>;
}

export interface AssemblerOptions {
  readonly origin: number;
}

export class Assembler {
  readonly origin: number;

  #bytes: Array<number> = [];
  #labels = new Map<string, number>();
  #fixups: Array<Fixup> = [];

  constructor(options: AssemblerOptions) {
    this.origin = options.origin;
  }

  get offset(): number {
    return this.#bytes.length;
  }

  get pc(): number {
    return (this.origin + this.#bytes.length) >>> 0;
  }

  label(name: string): this {
    if (this.#labels.has(name)) fail(`duplicate label "${name}"`);
    if (this.offset % 2 !== 0) fail(`label "${name}" is not halfword-aligned`);
    this.#labels.set(name, this.pc);
    return this;
  }

  byte(...values: ReadonlyArray<number>): this {
    for (const value of values) this.#bytes.push(value & 0xff);
    return this;
  }

  halfword(...values: ReadonlyArray<number>): this {
    for (const value of values) {
      this.#bytes.push(value & 0xff, (value >>> 8) & 0xff);
    }
    return this;
  }

  word(...values: ReadonlyArray<number>): this {
    for (const value of values) {
      this.#bytes.push(
        value & 0xff,
        (value >>> 8) & 0xff,
        (value >>> 16) & 0xff,
        (value >>> 24) & 0xff,
      );
    }
    return this;
  }

  ascii(text: string): this {
    for (let i = 0; i < text.length; i += 1) {
      const code = text.charCodeAt(i);
      if (code > 0x7f) fail(`ascii() got a non-ASCII character in "${text}"`);
      this.#bytes.push(code);
    }
    return this;
  }

  align(boundary: number): this {
    while (this.#bytes.length % boundary !== 0) this.#bytes.push(0xff);
    return this;
  }

  #formatI(op: number, reg1: Register, reg2: Register): this {
    return this.halfword(
      (op << 10) | (checkRegister(reg2, "reg2") << 5) | checkRegister(reg1, "reg1"),
    );
  }

  mov(src: Register, dest: Register): this {
    return this.#formatI(OP_MOV, src, dest);
  }

  add(src: Register, dest: Register): this {
    return this.#formatI(OP_ADD, src, dest);
  }

  sub(src: Register, dest: Register): this {
    return this.#formatI(OP_SUB, src, dest);
  }

  cmp(src: Register, dest: Register): this {
    return this.#formatI(OP_CMP, src, dest);
  }

  shl(amount: Register, dest: Register): this {
    return this.#formatI(OP_SHL, amount, dest);
  }

  shr(amount: Register, dest: Register): this {
    return this.#formatI(OP_SHR, amount, dest);
  }

  sar(amount: Register, dest: Register): this {
    return this.#formatI(OP_SAR, amount, dest);
  }

  mul(src: Register, dest: Register): this {
    return this.#formatI(OP_MUL, src, dest);
  }

  mulu(src: Register, dest: Register): this {
    return this.#formatI(OP_MULU, src, dest);
  }

  div(src: Register, dest: Register): this {
    return this.#formatI(OP_DIV, src, dest);
  }

  divu(src: Register, dest: Register): this {
    return this.#formatI(OP_DIVU, src, dest);
  }

  or(src: Register, dest: Register): this {
    return this.#formatI(OP_OR, src, dest);
  }

  and(src: Register, dest: Register): this {
    return this.#formatI(OP_AND, src, dest);
  }

  xor(src: Register, dest: Register): this {
    return this.#formatI(OP_XOR, src, dest);
  }

  not(src: Register, dest: Register): this {
    return this.#formatI(OP_NOT, src, dest);
  }

  jmp(target: Register): this {
    return this.#formatI(OP_JMP, target, r0);
  }

  #formatII(op: number, imm5: number, reg2: Register): this {
    return this.halfword((op << 10) | (checkRegister(reg2, "reg2") << 5) | (imm5 & 0x1f));
  }

  movImm(value: number, dest: Register): this {
    return this.#formatII(OP_MOV_I, checkImm5(value), dest);
  }

  addImm(value: number, dest: Register): this {
    return this.#formatII(OP_ADD_I, checkImm5(value), dest);
  }

  cmpImm(value: number, dest: Register): this {
    return this.#formatII(OP_CMP_I, checkImm5(value), dest);
  }

  shlImm(amount: number, dest: Register): this {
    return this.#formatII(OP_SHL_I, checkUimm5(amount), dest);
  }

  shrImm(amount: number, dest: Register): this {
    return this.#formatII(OP_SHR_I, checkUimm5(amount), dest);
  }

  sarImm(amount: number, dest: Register): this {
    return this.#formatII(OP_SAR_I, checkUimm5(amount), dest);
  }

  setf(condition: number, dest: Register): this {
    return this.#formatII(OP_SETF, checkUimm5(condition), dest);
  }

  trap(vector: number): this {
    return this.#formatII(OP_TRAP, checkUimm5(vector), r0);
  }

  // The system register number rides in the 5-bit immediate field, not in a
  // register field, so these read backwards from every other format II op.
  ldsr(src: Register, sysReg: number): this {
    return this.#formatII(OP_LDSR, checkUimm5(sysReg), src);
  }

  stsr(sysReg: number, dest: Register): this {
    return this.#formatII(OP_STSR, checkUimm5(sysReg), dest);
  }

  ei(): this {
    return this.#formatII(OP_EI, 0, r0);
  }

  di(): this {
    return this.#formatII(OP_DI, 0, r0);
  }

  reti(): this {
    return this.#formatII(OP_RETI, 0, r0);
  }

  halt(): this {
    return this.#formatII(OP_HALT, 0, r0);
  }

  #branch(condition: number, label: string): this {
    this.#fixups.push({ kind: "disp9", offset: this.offset, pc: this.pc, label });
    return this.halfword(0x8000 | (condition << 9));
  }

  br(label: string): this {
    return this.#branch(COND_T, label);
  }

  be(label: string): this {
    return this.#branch(COND_E, label);
  }

  bne(label: string): this {
    return this.#branch(COND_NE, label);
  }

  bl(label: string): this {
    return this.#branch(COND_L, label);
  }

  bnl(label: string): this {
    return this.#branch(COND_NL, label);
  }

  bh(label: string): this {
    return this.#branch(COND_H, label);
  }

  bnh(label: string): this {
    return this.#branch(COND_NH, label);
  }

  blt(label: string): this {
    return this.#branch(COND_LT, label);
  }

  ble(label: string): this {
    return this.#branch(COND_LE, label);
  }

  bgt(label: string): this {
    return this.#branch(COND_GT, label);
  }

  bge(label: string): this {
    return this.#branch(COND_GE, label);
  }

  bn(label: string): this {
    return this.#branch(COND_N, label);
  }

  bp(label: string): this {
    return this.#branch(COND_P, label);
  }

  bv(label: string): this {
    return this.#branch(COND_V, label);
  }

  bnv(label: string): this {
    return this.#branch(COND_NV, label);
  }

  // The V810 has no dedicated nop; the architectural one is a branch on a
  // condition that is always false.
  nop(): this {
    return this.halfword(0x8000 | (COND_F << 9));
  }

  #jump(op: number, label: string): this {
    this.#fixups.push({ kind: "disp26", offset: this.offset, pc: this.pc, label });
    return this.halfword(op << 10, 0);
  }

  jr(label: string): this {
    return this.#jump(OP_JR, label);
  }

  jal(label: string): this {
    return this.#jump(OP_JAL, label);
  }

  #formatV(op: number, imm16: number, src: Register, dest: Register): this {
    return this.halfword(
      (op << 10) | (checkRegister(dest, "dest") << 5) | checkRegister(src, "src"),
      checkImm16(imm16),
    );
  }

  movea(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_MOVEA, value, src, dest);
  }

  movhi(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_MOVHI, value, src, dest);
  }

  addi(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_ADDI, value, src, dest);
  }

  ori(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_ORI, value, src, dest);
  }

  andi(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_ANDI, value, src, dest);
  }

  xori(value: number, src: Register, dest: Register): this {
    return this.#formatV(OP_XORI, value, src, dest);
  }

  #load(op: number, disp: number, base: Register, dest: Register): this {
    return this.halfword(
      (op << 10) | (checkRegister(dest, "dest") << 5) | checkRegister(base, "base"),
      checkImm16(disp),
    );
  }

  #store(op: number, src: Register, disp: number, base: Register): this {
    return this.halfword(
      (op << 10) | (checkRegister(src, "src") << 5) | checkRegister(base, "base"),
      checkImm16(disp),
    );
  }

  ldB(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_LD_B, disp, base, dest);
  }

  ldH(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_LD_H, disp, base, dest);
  }

  ldW(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_LD_W, disp, base, dest);
  }

  stB(src: Register, disp: number, base: Register): this {
    return this.#store(OP_ST_B, src, disp, base);
  }

  stH(src: Register, disp: number, base: Register): this {
    return this.#store(OP_ST_H, src, disp, base);
  }

  stW(src: Register, disp: number, base: Register): this {
    return this.#store(OP_ST_W, src, disp, base);
  }

  inB(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_IN_B, disp, base, dest);
  }

  inH(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_IN_H, disp, base, dest);
  }

  inW(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_IN_W, disp, base, dest);
  }

  outB(src: Register, disp: number, base: Register): this {
    return this.#store(OP_OUT_B, src, disp, base);
  }

  outH(src: Register, disp: number, base: Register): this {
    return this.#store(OP_OUT_H, src, disp, base);
  }

  outW(src: Register, disp: number, base: Register): this {
    return this.#store(OP_OUT_W, src, disp, base);
  }

  // CAXI reads like a load — the lock word address is disp[base] — and the
  // exchange value rides implicitly in r30.
  caxi(disp: number, base: Register, dest: Register): this {
    return this.#load(OP_CAXI, disp, base, dest);
  }

  // Bit string instructions take no operands: the string descriptors live in
  // r26-r30 and the sub-opcode rides in the imm5 field.
  #bitString(subop: number): this {
    return this.halfword((OP_BSTR << 10) | subop);
  }

  sch0bsu(): this {
    return this.#bitString(SUB_SCH0BSU);
  }

  sch0bsd(): this {
    return this.#bitString(SUB_SCH0BSD);
  }

  sch1bsu(): this {
    return this.#bitString(SUB_SCH1BSU);
  }

  sch1bsd(): this {
    return this.#bitString(SUB_SCH1BSD);
  }

  orbsu(): this {
    return this.#bitString(SUB_ORBSU);
  }

  andbsu(): this {
    return this.#bitString(SUB_ANDBSU);
  }

  xorbsu(): this {
    return this.#bitString(SUB_XORBSU);
  }

  movbsu(): this {
    return this.#bitString(SUB_MOVBSU);
  }

  ornbsu(): this {
    return this.#bitString(SUB_ORNBSU);
  }

  andnbsu(): this {
    return this.#bitString(SUB_ANDNBSU);
  }

  xornbsu(): this {
    return this.#bitString(SUB_XORNBSU);
  }

  notbsu(): this {
    return this.#bitString(SUB_NOTBSU);
  }

  // Format VII: the sub-opcode occupies the top six bits of the second
  // halfword, which are instruction bits 31-26 [v810_oploop.inc DO_AM_FPP].
  #formatVII(subop: number, src: Register, dest: Register): this {
    return this.halfword(
      (OP_FPP << 10) | (checkRegister(dest, "dest") << 5) | checkRegister(src, "src"),
      subop << 10,
    );
  }

  cmpfS(src: Register, dest: Register): this {
    return this.#formatVII(SUB_CMPF_S, src, dest);
  }

  cvtWs(src: Register, dest: Register): this {
    return this.#formatVII(SUB_CVT_WS, src, dest);
  }

  cvtSw(src: Register, dest: Register): this {
    return this.#formatVII(SUB_CVT_SW, src, dest);
  }

  addfS(src: Register, dest: Register): this {
    return this.#formatVII(SUB_ADDF_S, src, dest);
  }

  subfS(src: Register, dest: Register): this {
    return this.#formatVII(SUB_SUBF_S, src, dest);
  }

  mulfS(src: Register, dest: Register): this {
    return this.#formatVII(SUB_MULF_S, src, dest);
  }

  divfS(src: Register, dest: Register): this {
    return this.#formatVII(SUB_DIVF_S, src, dest);
  }

  trncSw(src: Register, dest: Register): this {
    return this.#formatVII(SUB_TRNC_SW, src, dest);
  }

  mpyhw(src: Register, dest: Register): this {
    return this.#formatVII(SUB_MPYHW, src, dest);
  }

  rev(src: Register, dest: Register): this {
    return this.#formatVII(SUB_REV, src, dest);
  }

  // XB and XH operate on reg2 alone; the reg1 field is left zero, which is
  // the encoding one source says the hardware requires.
  xb(dest: Register): this {
    return this.#formatVII(SUB_XB, r0, dest);
  }

  xh(dest: Register): this {
    return this.#formatVII(SUB_XH, r0, dest);
  }

  // movea sign-extends its immediate, so a low half with bit 15 set subtracts
  // 0x10000 from the result. The high half is pre-incremented to cancel that
  // out — without it every address ending above 0x8000 lands 64KB short.
  loadImm(value: number, dest: Register): this {
    const low = value & 0xffff;
    const high = ((value >>> 16) + (low & 0x8000 ? 1 : 0)) & 0xffff;
    if (high === 0) return this.movea((low << 16) >> 16, r0, dest);
    this.movhi(high, r0, dest);
    return low === 0 ? this : this.movea((low << 16) >> 16, dest, dest);
  }

  // jr only reaches +/-32MB, which is not far enough to get from the vector
  // table at the top of the address space down to code linked at the cart base.
  // Costs r1 and four more bytes than a jr would.
  jumpFar(address: number): this {
    this.loadImm(address, r1);
    return this.jmp(r1);
  }

  // halt alone is not a stop: an interrupt wakes the CPU and execution runs on
  // into whatever follows. The branch back onto it makes the stop permanent.
  hang(): this {
    const label = `__hang_${this.offset.toString(16)}`;
    this.label(label).halt();
    return this.br(label);
  }

  assemble(): AssembledProgram {
    const bytes = Uint8Array.from(this.#bytes);

    for (const fixup of this.#fixups) {
      const target = this.#labels.get(fixup.label);
      if (target === undefined) {
        throw new AssemblyError(`branch to undefined label "${fixup.label}"`);
      }
      const disp = (target - fixup.pc) | 0;

      if (fixup.kind === "disp9") {
        const encoded = checkDisp9(disp, fixup.label);
        bytes[fixup.offset] = encoded & 0xff;
        bytes[fixup.offset + 1] = (bytes[fixup.offset + 1] ?? 0) | ((encoded >>> 8) & 0x01);
      } else {
        const encoded = checkDisp26(disp, fixup.label);
        bytes[fixup.offset] = (encoded >>> 16) & 0xff;
        bytes[fixup.offset + 1] = (bytes[fixup.offset + 1] ?? 0) | ((encoded >>> 24) & 0x03);
        bytes[fixup.offset + 2] = encoded & 0xff;
        bytes[fixup.offset + 3] = (encoded >>> 8) & 0xff;
      }
    }

    return { bytes, origin: this.origin, labels: new Map(this.#labels) };
  }
}
