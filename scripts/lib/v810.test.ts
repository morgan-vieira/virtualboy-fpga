// Expected values here were worked out by hand from the field layout in
// .repos/beetle-vb-libretro/mednafen/hw_cpu/v810/, so a passing run means our
// bytes decode the way the reference emulator's decoder reads them. Deriving
// them from the assembler instead would make this file agree with itself and
// prove nothing.

import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { Assembler, AssemblyError, PSW, r0, r1, r2, r3, r6, r7, r31 } from "#scripts/lib/v810";
import {
  buildRom,
  decodeHeader,
  encodeHeader,
  HEADER_BYTES,
  MIN_ROM_BYTES,
  RomError,
  ROM_ORIGIN,
  TRAILER_BYTES,
  vectors,
  VECTOR_TABLE_BYTES,
} from "#scripts/lib/vb-rom";

const halfwords = (build: (asm: Assembler) => void): ReadonlyArray<number> => {
  const asm = new Assembler({ origin: ROM_ORIGIN });
  build(asm);
  const { bytes } = asm.assemble();
  assert.equal(bytes.length % 2, 0, "instruction stream is not a whole number of halfwords");
  return Array.from(
    { length: bytes.length / 2 },
    (_unused, i) => bytes[i * 2]! | (bytes[i * 2 + 1]! << 8),
  );
};

describe("format I — [op:6][reg2:5][reg1:5]", () => {
  it("puts the destination in reg2 and the source in reg1", () => {
    // mov r7, r6 means r6 = r7, so the source r7 is the one in the low field.
    assert.deepEqual(
      halfwords((asm) => asm.mov(r7, r6)),
      [(0x00 << 10) | (6 << 5) | 7],
    );
    assert.deepEqual(
      halfwords((asm) => asm.add(r1, r2)),
      [(0x01 << 10) | (2 << 5) | 1],
    );
    assert.deepEqual(
      halfwords((asm) => asm.cmp(r2, r3)),
      [(0x03 << 10) | (3 << 5) | 2],
    );
  });

  it("encodes jmp with the target register in reg1", () => {
    assert.deepEqual(
      halfwords((asm) => asm.jmp(r1)),
      [0x1801],
    );
  });
});

describe("format II — [op:6][reg2:5][imm5:5]", () => {
  it("encodes a signed 5-bit immediate", () => {
    assert.deepEqual(
      halfwords((asm) => asm.movImm(-1, r6)),
      [(0x10 << 10) | (6 << 5) | 0x1f],
    );
    assert.deepEqual(
      halfwords((asm) => asm.movImm(15, r6)),
      [(0x10 << 10) | (6 << 5) | 15],
    );
  });

  it("rejects an immediate that does not fit", () => {
    assert.throws(() => halfwords((asm) => asm.movImm(16, r6)), AssemblyError);
    assert.throws(() => halfwords((asm) => asm.movImm(-17, r6)), AssemblyError);
  });

  it("puts the system register number in the immediate field", () => {
    assert.deepEqual(
      halfwords((asm) => asm.ldsr(r6, PSW)),
      [(0x1c << 10) | (6 << 5) | PSW],
    );
    assert.deepEqual(
      halfwords((asm) => asm.stsr(PSW, r6)),
      [(0x1d << 10) | (6 << 5) | PSW],
    );
  });

  it("encodes the operand-less system instructions", () => {
    assert.deepEqual(
      halfwords((asm) => asm.halt()),
      [0x1a << 10],
    );
    assert.deepEqual(
      halfwords((asm) => asm.reti()),
      [0x19 << 10],
    );
    assert.deepEqual(
      halfwords((asm) => asm.ei()),
      [0x16 << 10],
    );
    assert.deepEqual(
      halfwords((asm) => asm.di()),
      [0x1e << 10],
    );
  });
});

describe("format III — [100][cond:4][disp9]", () => {
  it("encodes a backward branch as a negative displacement from the branch itself", () => {
    const encoded = halfwords((asm) => {
      asm.label("top");
      asm.nop();
      asm.br("top");
    });
    assert.equal(encoded[1], (0x8000 | (0x5 << 9) | (-2 & 0x1fe)) & 0xffff);
  });

  it("encodes a forward branch", () => {
    const encoded = halfwords((asm) => {
      asm.bne("done");
      asm.nop();
      asm.label("done");
      asm.halt();
    });
    assert.equal(encoded[0], 0x8000 | (0xa << 9) | 4);
  });

  it("encodes nop as the never-taken branch", () => {
    assert.deepEqual(
      halfwords((asm) => asm.nop()),
      [0x8000 | (0xd << 9)],
    );
  });

  it("rejects a branch further than the 9-bit displacement reaches", () => {
    assert.throws(
      () =>
        halfwords((asm) => {
          asm.br("far");
          for (let i = 0; i < 200; i += 1) asm.nop();
          asm.label("far");
          asm.halt();
        }),
      AssemblyError,
    );
  });

  it("rejects a branch to a label that was never defined", () => {
    assert.throws(() => halfwords((asm) => asm.br("nowhere")), AssemblyError);
  });
});

describe("format IV — [op:6][disp26 hi:10] [disp26 lo:16]", () => {
  it("splits the displacement across both halfwords", () => {
    const encoded = halfwords((asm) => {
      asm.label("top");
      asm.jr("target");
      for (let i = 0; i < 100; i += 1) asm.nop();
      asm.label("target");
      asm.halt();
    });
    const disp = 204;
    assert.equal(encoded[0], (0x2a << 10) | ((disp >>> 16) & 0x3ff));
    assert.equal(encoded[1], disp & 0xffff);
  });

  it("encodes a negative displacement", () => {
    const encoded = halfwords((asm) => {
      asm.label("top");
      asm.nop();
      asm.jal("top");
    });
    const disp = -2;
    assert.equal(encoded[1], (0x2b << 10) | ((disp >>> 16) & 0x3ff));
    assert.equal(encoded[2], disp & 0xffff);
  });
});

describe("format V — [op:6][reg2:5][reg1:5] [imm16]", () => {
  it("puts the destination in reg2 and the source in reg1", () => {
    assert.deepEqual(
      halfwords((asm) => asm.movea(0x1234, r0, r6)),
      [(0x28 << 10) | (6 << 5) | 0, 0x1234],
    );
    assert.deepEqual(
      halfwords((asm) => asm.movhi(0x0700, r0, r7)),
      [(0x2f << 10) | (7 << 5) | 0, 0x0700],
    );
  });
});

describe("format VI — load and store", () => {
  it("puts the destination in reg2 and the base in reg1 for a load", () => {
    assert.deepEqual(
      halfwords((asm) => asm.ldW(4, r6, r7)),
      [(0x33 << 10) | (7 << 5) | 6, 4],
    );
  });

  it("puts the stored value in reg2 and the base in reg1 for a store", () => {
    // The mirror image of a load: st.w r7, 0[r6] writes r7, so r7 takes the
    // field that held the destination on the load side.
    assert.deepEqual(
      halfwords((asm) => asm.stW(r7, 0, r6)),
      [(0x37 << 10) | (7 << 5) | 6, 0],
    );
    assert.deepEqual(
      halfwords((asm) => asm.outW(r7, 0, r6)),
      [(0x3f << 10) | (7 << 5) | 6, 0],
    );
  });

  it("encodes a negative displacement", () => {
    assert.deepEqual(
      halfwords((asm) => asm.ldH(-2, r6, r7)),
      [(0x31 << 10) | (7 << 5) | 6, 0xfffe],
    );
  });
});

describe("loadImm", () => {
  it("uses one movea when the value fits a sign-extended 16 bits", () => {
    assert.deepEqual(
      halfwords((asm) => asm.loadImm(0x0000_1234, r6)),
      [(0x28 << 10) | (6 << 5) | 0, 0x1234],
    );
  });

  it("uses one movhi when the low half is zero", () => {
    assert.deepEqual(
      halfwords((asm) => asm.loadImm(0x0700_0000, r6)),
      [(0x2f << 10) | (6 << 5) | 0, 0x0700],
    );
  });

  it("pre-increments the high half when movea would sign-extend the low half negative", () => {
    // 0xF800 sign-extends to -0x800, so the high half has to be 6 rather than 5
    // for the pair to land on 0x0005F800 and not 64KB below it.
    assert.deepEqual(
      halfwords((asm) => asm.loadImm(0x0005_f800, r6)),
      [(0x2f << 10) | (6 << 5) | 0, 0x0006, (0x28 << 10) | (6 << 5) | 6, 0xf800],
    );
  });

  it("reaches the top of the address space with a single movea", () => {
    assert.deepEqual(
      halfwords((asm) => asm.loadImm(0xffff_fff0, r6)),
      [(0x28 << 10) | (6 << 5) | 0, 0xfff0],
    );
  });
});

describe("labels", () => {
  it("resolves to a virtual address, not a file offset", () => {
    const asm = new Assembler({ origin: ROM_ORIGIN });
    asm.nop();
    asm.label("here");
    const { labels } = asm.assemble();
    assert.equal(labels.get("here"), ROM_ORIGIN + 2);
  });

  it("rejects a duplicate", () => {
    const asm = new Assembler({ origin: ROM_ORIGIN });
    asm.label("twice");
    assert.throws(() => asm.label("twice"), AssemblyError);
  });
});

describe("ROM header", () => {
  const header = {
    gameTitle: "OPENFPGA HALT",
    makerCode: "OF",
    gameCode: "VHLT",
    revision: 3,
  };

  it("lays the fields out where an emulator reads them", () => {
    const bytes = encodeHeader(header);
    assert.equal(bytes.length, HEADER_BYTES);
    assert.equal(String.fromCharCode(...bytes.subarray(0x00, 0x14)), "OPENFPGA HALT       ");
    assert.deepEqual(Array.from(bytes.subarray(0x14, 0x19)), [0, 0, 0, 0, 0]);
    assert.equal(String.fromCharCode(...bytes.subarray(0x19, 0x1b)), "OF");
    assert.equal(String.fromCharCode(...bytes.subarray(0x1b, 0x1f)), "VHLT");
    assert.equal(bytes[0x1f], 3);
  });

  it("rejects fields that are the wrong width", () => {
    assert.throws(() => encodeHeader({ ...header, makerCode: "OFP" }), RomError);
    assert.throws(() => encodeHeader({ ...header, gameCode: "VHL" }), RomError);
    assert.throws(() => encodeHeader({ ...header, gameTitle: "X".repeat(21) }), RomError);
    assert.throws(() => encodeHeader({ ...header, revision: 10 }), RomError);
  });

  it("rejects a title outside ASCII rather than mangling the Shift-JIS", () => {
    assert.throws(() => encodeHeader({ ...header, gameTitle: "バーチャル" }), RomError);
  });
});

describe("ROM image", () => {
  const spec = {
    name: "fixture",
    header: {
      gameTitle: "FIXTURE",
      makerCode: "OF",
      gameCode: "VFIX",
      revision: 0,
    },
    expectation: "used by the tests only",
    program: (asm: Assembler) => {
      asm.label("start");
      asm.loadImm(0xdeadbeef, r7);
      asm.hang();
    },
  };

  it("is a power of two, no smaller than the minimum a Virtual Boy accepts", () => {
    const rom = buildRom(spec);
    assert.equal(rom.sizeBytes, MIN_ROM_BYTES);
    assert.equal(rom.sizeBytes & (rom.sizeBytes - 1), 0);
    assert.equal(rom.bytes.length, rom.sizeBytes);
  });

  it("puts the code at offset zero and fills the gap with 0xFF", () => {
    const rom = buildRom(spec);
    assert.notEqual(rom.bytes[0], 0xff, "code should start at offset 0");
    for (let i = rom.codeBytes; i < rom.sizeBytes - TRAILER_BYTES; i += 1) {
      assert.equal(rom.bytes[i], 0xff, `gap byte at ${i} is not erased-flash fill`);
    }
  });

  it("puts the header 0x220 from the end, where an emulator looks for it", () => {
    const rom = buildRom(spec);
    assert.deepEqual(decodeHeader(rom.bytes), spec.header);
  });

  it("points the reset vector at the entry label", () => {
    const rom = buildRom(spec);
    // Length varies: a far jump to an address with a zero low half needs only
    // movhi and jmp, so the stub is 6 bytes here and 10 elsewhere.
    const expected = new Assembler({ origin: vectors.reset });
    expected.jumpFar(rom.entryAddress);
    const stub = expected.assemble().bytes;
    const slotOffset = rom.sizeBytes - 0x10;
    assert.deepEqual(
      Array.from(rom.bytes.subarray(slotOffset, slotOffset + stub.length)),
      Array.from(stub),
    );
    assert.equal(rom.entryAddress, ROM_ORIGIN);
  });

  it("stubs every unhandled vector with a halt that cannot run on", () => {
    const rom = buildRom(spec);
    const vipSlot = rom.sizeBytes - (0x100000000 - vectors.vip);
    assert.equal(rom.bytes[vipSlot]! | (rom.bytes[vipSlot + 1]! << 8), 0x1a << 10);
    assert.equal(
      rom.bytes[vipSlot + 2]! | (rom.bytes[vipSlot + 3]! << 8),
      (0x8000 | (0x5 << 9) | (-2 & 0x1fe)) & 0xffff,
    );
  });

  it("jumps to a named handler when one is given", () => {
    const rom = buildRom({
      ...spec,
      program: (asm: Assembler) => {
        asm.label("start");
        asm.hang();
        asm.label("onVip");
        asm.reti();
      },
      handlers: { vip: "onVip" },
    });
    const vipSlot = rom.sizeBytes - (0x100000000 - vectors.vip);
    const expected = new Assembler({ origin: vectors.vip });
    expected.jumpFar(ROM_ORIGIN + 4);
    const stub = expected.assemble().bytes;
    assert.deepEqual(
      Array.from(rom.bytes.subarray(vipSlot, vipSlot + stub.length)),
      Array.from(stub),
    );
  });

  it("keeps the whole vector table inside the last 0x200 bytes", () => {
    const rom = buildRom(spec);
    for (const address of Object.values(vectors)) {
      const offset = rom.sizeBytes - (0x100000000 - address);
      assert.ok(
        offset >= rom.sizeBytes - VECTOR_TABLE_BYTES && offset < rom.sizeBytes,
        `vector at ${address.toString(16)} lands outside the table`,
      );
    }
  });

  it("grows to the next power of two when the code outgrows the image", () => {
    const rom = buildRom({
      ...spec,
      program: (asm: Assembler) => {
        asm.label("start");
        for (let i = 0; i < 512; i += 1) asm.nop();
        asm.hang();
      },
    });
    assert.equal(rom.sizeBytes, 2048);
  });

  it("refuses a forced size that the code does not fit inside", () => {
    assert.throws(
      () =>
        buildRom({
          ...spec,
          sizeBytes: MIN_ROM_BYTES,
          program: (asm: Assembler) => {
            asm.label("start");
            for (let i = 0; i < 512; i += 1) asm.nop();
          },
        }),
      RomError,
    );
  });

  it("refuses a size that is not a power of two", () => {
    assert.throws(() => buildRom({ ...spec, sizeBytes: 1536 }), RomError);
  });

  it("refuses a ROM with no entry label", () => {
    assert.throws(
      () => buildRom({ ...spec, program: (asm: Assembler) => void asm.hang() }),
      RomError,
    );
  });

  it("refuses a handler pointing at a label that does not exist", () => {
    assert.throws(() => buildRom({ ...spec, handlers: { vip: "missing" } }), RomError);
  });
});

describe("the halt ROM", () => {
  it("builds, and lands its reset vector on real code", async () => {
    const module = await import("#roms/halt/rom");
    const rom = buildRom(module.default);

    assert.equal(rom.name, "halt");
    assert.equal(rom.sizeBytes, MIN_ROM_BYTES);
    assert.equal(rom.entryAddress, ROM_ORIGIN);
    assert.deepEqual(decodeHeader(rom.bytes), module.default.header);

    // di, the first instruction the CPU reaches after the reset vector.
    assert.equal(rom.bytes[0]! | (rom.bytes[1]! << 8), 0x1e << 10);
    assert.ok(rom.codeBytes > 0 && rom.codeBytes < MIN_ROM_BYTES - TRAILER_BYTES);
    assert.equal(r31, 31);
  });
});
