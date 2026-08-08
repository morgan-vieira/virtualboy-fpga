// The header and vector table are anchored to the end of the file rather than
// to a fixed address because the cart is mirrored: the address bus masks with
// size - 1, so a 1KB ROM and a 2MB ROM both boot from their own last sixteen
// bytes. The core has to reproduce that mirroring or a small test ROM will not
// reach its own reset vector.
//
// Layout taken from VUEngine Studio's vb.ld.njk and confirmed against
// beetle-vb's loader in .repos/beetle-vb-libretro/libretro.cpp.

import { Assembler, type AssembledProgram } from "#scripts/lib/v810";

export const ROM_ORIGIN = 0x07000000;

export const HEADER_BYTES = 0x20;
export const VECTOR_TABLE_BYTES = 0x200;
export const TRAILER_BYTES = HEADER_BYTES + VECTOR_TABLE_BYTES;

// beetle-vb rejects anything outside 256 bytes to 16MB, or not a power of two.
// The floor is 1KB rather than 256 because that is the smallest power of two
// the 0x220-byte trailer fits inside with room for code.
export const MIN_ROM_BYTES = 1024;
export const MAX_ROM_BYTES = 1 << 24;

export const GAME_TITLE_MAX_LENGTH = 20;
export const MAKER_CODE_LENGTH = 2;
export const GAME_CODE_LENGTH = 4;

// Hardware interrupts sit at 0xFFFFFE00 | (level << 4); the levels come from
// beetle-vb's VBIRQ_SOURCE_* and the exception addresses from v810_cpu.h. trap
// and trapHigh are one vector each because the CPU picks between them on bit 4
// of the trap number.
export const vectors = {
  keypad: 0xfffffe00,
  timer: 0xfffffe10,
  expansion: 0xfffffe20,
  link: 0xfffffe30,
  vip: 0xfffffe40,
  fpu: 0xffffff60,
  divideByZero: 0xffffff80,
  invalidOpcode: 0xffffff90,
  trap: 0xffffffa0,
  trapHigh: 0xffffffb0,
  duplexedException: 0xffffffd0,
  reset: 0xfffffff0,
} as const;

export type VectorName = keyof typeof vectors;

export const vectorNames = Object.keys(vectors) as ReadonlyArray<VectorName>;

export class RomError extends Error {
  override readonly name = "RomError";
}

const fail = (message: string): never => {
  throw new RomError(message);
};

export interface RomHeader {
  readonly gameTitle: string;
  readonly makerCode: string;
  readonly gameCode: string;
  readonly revision: number;
}

export interface RomSpec {
  readonly name: string;
  readonly header: RomHeader;
  // Required, because nobody building the ROM can see the Pocket. Say what a
  // pass looks like before the ROM is written, or it is testing too much.
  readonly expectation: string;
  readonly program: (asm: Assembler) => void;
  readonly entry?: string;
  readonly handlers?: Partial<Record<VectorName, string>>;
  readonly sizeBytes?: number;
}

export interface BuiltRom {
  readonly name: string;
  readonly bytes: Uint8Array;
  readonly sizeBytes: number;
  readonly codeBytes: number;
  readonly header: RomHeader;
  readonly expectation: string;
  readonly entryAddress: number;
}

export const defineRom = (spec: RomSpec): RomSpec => spec;

const nextPowerOfTwo = (value: number): number => {
  let result = MIN_ROM_BYTES;
  while (result < value) result *= 2;
  return result;
};

const asciiBytes = (text: string, field: string): Uint8Array => {
  const bytes = new Uint8Array(text.length);
  for (let i = 0; i < text.length; i += 1) {
    const code = text.charCodeAt(i);
    // Real carts store Shift-JIS. ASCII is a subset of it, so rejecting the
    // rest beats silently mangling a title nobody would notice was wrong.
    if (code > 0x7f) {
      fail(`${field} must be ASCII, got "${text}" — Shift-JIS beyond ASCII is not supported`);
    }
    bytes[i] = code;
  }
  return bytes;
};

export const encodeHeader = (header: RomHeader): Uint8Array => {
  const { gameTitle, makerCode, gameCode, revision } = header;

  if (gameTitle.length > GAME_TITLE_MAX_LENGTH) {
    fail(`gameTitle is ${gameTitle.length} characters, limit is ${GAME_TITLE_MAX_LENGTH}`);
  }
  if (makerCode.length !== MAKER_CODE_LENGTH) {
    fail(`makerCode must be exactly ${MAKER_CODE_LENGTH} characters, got "${makerCode}"`);
  }
  if (gameCode.length !== GAME_CODE_LENGTH) {
    fail(`gameCode must be exactly ${GAME_CODE_LENGTH} characters, got "${gameCode}"`);
  }
  if (!Number.isInteger(revision) || revision < 0 || revision > 9) {
    fail(`revision must be an integer 0-9, got ${revision}`);
  }

  const bytes = new Uint8Array(HEADER_BYTES);
  // Fields are space-padded to fixed widths, except 0x14-0x18 which is reserved
  // and stays zero the way a real cart leaves it.
  bytes.fill(0x20, 0x00, 0x14);
  bytes.set(asciiBytes(gameTitle, "gameTitle"), 0x00);
  bytes.set(asciiBytes(makerCode, "makerCode"), 0x19);
  bytes.set(asciiBytes(gameCode, "gameCode"), 0x1b);
  bytes[0x1f] = revision;
  return bytes;
};

export const decodeHeader = (rom: Uint8Array): RomHeader => {
  if (rom.length < TRAILER_BYTES) fail(`image is ${rom.length} bytes, too small to hold a header`);
  const base = rom.length - TRAILER_BYTES;
  const text = (from: number, to: number): string =>
    String.fromCharCode(...rom.subarray(base + from, base + to));
  return {
    gameTitle: text(0x00, 0x14).trimEnd(),
    makerCode: text(0x19, 0x1b),
    gameCode: text(0x1b, 0x1f),
    revision: rom[base + 0x1f] ?? 0,
  };
};

export const buildRom = (spec: RomSpec): BuiltRom => {
  const asm = new Assembler({ origin: ROM_ORIGIN });
  spec.program(asm);
  const program: AssembledProgram = asm.assemble();

  const entry = spec.entry ?? "start";
  const entryAddress = program.labels.get(entry);
  if (entryAddress === undefined) {
    throw new RomError(
      `ROM "${spec.name}" has no "${entry}" label for the reset vector to jump to`,
    );
  }

  const required = program.bytes.length + TRAILER_BYTES;
  const sizeBytes = spec.sizeBytes ?? nextPowerOfTwo(required);

  if (sizeBytes < MIN_ROM_BYTES || sizeBytes > MAX_ROM_BYTES) {
    fail(
      `ROM "${spec.name}" is ${sizeBytes} bytes, outside the 1KB-16MB range a Virtual Boy accepts`,
    );
  }
  if ((sizeBytes & (sizeBytes - 1)) !== 0) {
    fail(`ROM "${spec.name}" is ${sizeBytes} bytes, which is not a power of two`);
  }
  if (required > sizeBytes) {
    fail(
      `ROM "${spec.name}" needs ${required} bytes (${program.bytes.length} of code plus a ` +
        `${TRAILER_BYTES}-byte trailer) but is only ${sizeBytes}`,
    );
  }

  // 0xFF is what erased flash reads as, and what VUEngine's linker script fills
  // its gaps with.
  const image = new Uint8Array(sizeBytes).fill(0xff);
  image.set(program.bytes, 0);
  image.set(encodeHeader(spec.header), sizeBytes - TRAILER_BYTES);

  const handlers = spec.handlers ?? {};
  for (const name of vectorNames) {
    const slot = new Assembler({ origin: vectors[name] });
    const label = name === "reset" ? entry : handlers[name];
    const target = label === undefined ? undefined : program.labels.get(label);

    if (label !== undefined && target === undefined) {
      fail(`ROM "${spec.name}" points the ${name} vector at missing label "${label}"`);
    }

    // An unnamed vector halts rather than falling through to the 0xFF fill, so
    // a stray interrupt freezes visibly instead of doing something that looks
    // like a core bug.
    if (target === undefined) slot.hang();
    else slot.jumpFar(target);

    const slotOffset = sizeBytes - (0x100000000 - vectors[name]);
    image.set(slot.assemble().bytes, slotOffset);
  }

  return {
    name: spec.name,
    bytes: image,
    sizeBytes,
    codeBytes: program.bytes.length,
    header: spec.header,
    expectation: spec.expectation,
    entryAddress,
  };
};
