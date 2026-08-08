#!/usr/bin/env node

import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import * as Console from "effect/Console";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Option from "effect/Option";
import * as Path from "effect/Path";
import * as Schema from "effect/Schema";
import { Command, Flag } from "effect/unstable/cli";
import { pathToFileURL } from "node:url";

import { buildRom, type BuiltRom, type RomSpec } from "#scripts/lib/vb-rom";

// Sources sit beside the Verilog they test; images are disposable and land in a
// gitignored directory at the repository root.
export const romSourceDirPath = ["src", "roms"] as const;
export const romOutputDirName = ".roms";
export const romSourceFileName = "rom.ts";

export interface RomBuildOptions {
  readonly rootDir?: string | undefined;
  readonly romName?: string | undefined;
}

export class RomSourceDiscoveryError extends Schema.TaggedErrorClass<RomSourceDiscoveryError>()(
  "RomSourceDiscoveryError",
  {
    sourceDir: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Listing ROM sources under ${this.sourceDir} failed.`;
  }
}

export class RomSourceLoadError extends Schema.TaggedErrorClass<RomSourceLoadError>()(
  "RomSourceLoadError",
  {
    sourcePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Loading the ROM source ${this.sourcePath} failed.`;
  }
}

export class RomAssemblyError extends Schema.TaggedErrorClass<RomAssemblyError>()(
  "RomAssemblyError",
  {
    sourcePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Assembling the ROM defined by ${this.sourcePath} failed.`;
  }
}

export class RomWriteError extends Schema.TaggedErrorClass<RomWriteError>()("RomWriteError", {
  outputPath: Schema.String,
  cause: Schema.Defect(),
}) {
  override get message(): string {
    return `Writing ${this.outputPath} failed.`;
  }
}

export class RomSelectionError extends Schema.TaggedErrorClass<RomSelectionError>()(
  "RomSelectionError",
  {
    romName: Schema.String,
    availableRomNames: Schema.Array(Schema.String),
  },
) {
  override get message(): string {
    return `No ROM named ${this.romName}. Available: ${this.availableRomNames.join(", ")}.`;
  }
}

export const RomBuildError = Schema.Union([
  RomSourceDiscoveryError,
  RomSourceLoadError,
  RomAssemblyError,
  RomWriteError,
  RomSelectionError,
]);
export type RomBuildError = typeof RomBuildError.Type;
export const isRomBuildError = Schema.is(RomBuildError);

export interface RomSource {
  readonly directoryName: string;
  readonly sourcePath: string;
}

export const findRomSources = Effect.fn("findRomSources")(function* (sourceDir: string) {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;

  const entries = yield* fileSystem
    .readDirectory(sourceDir)
    .pipe(Effect.mapError((cause) => new RomSourceDiscoveryError({ sourceDir, cause })));

  const sources: Array<RomSource> = [];
  for (const entry of [...entries].sort()) {
    const sourcePath = path.join(sourceDir, entry, romSourceFileName);
    const exists = yield* fileSystem
      .exists(sourcePath)
      .pipe(Effect.mapError((cause) => new RomSourceDiscoveryError({ sourceDir, cause })));
    if (exists) sources.push({ directoryName: entry, sourcePath });
  }

  return sources;
});

export const loadRomSpec = Effect.fn("loadRomSpec")(function* (source: RomSource) {
  const module = yield* Effect.tryPromise({
    try: () => import(pathToFileURL(source.sourcePath).href) as Promise<{ default?: RomSpec }>,
    catch: (cause) => new RomSourceLoadError({ sourcePath: source.sourcePath, cause }),
  });

  const spec = module.default;
  if (spec === undefined) {
    return yield* new RomSourceLoadError({
      sourcePath: source.sourcePath,
      cause: new Error("the module has no default export; use `export default defineRom({...})`"),
    });
  }

  return spec;
});

const formatSize = (bytes: number): string =>
  bytes >= 1024 * 1024 ? `${bytes / 1024 / 1024}MB` : `${bytes / 1024}KB`;

export const buildRoms = Effect.fn("buildRoms")(function* (options: RomBuildOptions = {}) {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;

  const rootDir = path.resolve(options.rootDir ?? process.cwd());
  const sourceDir = path.join(rootDir, ...romSourceDirPath);
  const outputDir = path.join(rootDir, romOutputDirName);

  const allSources = yield* findRomSources(sourceDir);
  const sources =
    options.romName === undefined
      ? allSources
      : allSources.filter((source) => source.directoryName === options.romName);

  if (options.romName !== undefined && sources.length === 0) {
    return yield* new RomSelectionError({
      romName: options.romName,
      availableRomNames: allSources.map((source) => source.directoryName),
    });
  }

  yield* fileSystem
    .makeDirectory(outputDir, { recursive: true })
    .pipe(Effect.mapError((cause) => new RomWriteError({ outputPath: outputDir, cause })));

  const built: Array<BuiltRom> = [];

  for (const source of sources) {
    const spec = yield* loadRomSpec(source);

    const rom = yield* Effect.try({
      try: () => buildRom(spec),
      catch: (cause) => new RomAssemblyError({ sourcePath: source.sourcePath, cause }),
    });

    const outputPath = path.join(outputDir, `${rom.name}.vb`);
    yield* fileSystem
      .writeFile(outputPath, rom.bytes)
      .pipe(Effect.mapError((cause) => new RomWriteError({ outputPath, cause })));

    yield* Console.log(
      `${rom.name}.vb  ${formatSize(rom.sizeBytes)}  ` +
        `${rom.codeBytes} bytes of code  "${rom.header.gameTitle}"`,
    );
    // Printed next to the image because this line is what gets handed to
    // whoever runs the hardware test.
    yield* Console.log(`  pass: ${rom.expectation}`);

    built.push(rom);
  }

  yield* Console.log("");
  yield* Console.log(`Built ${built.length} ROM(s) into ${outputDir}.`);

  return built;
});

export const buildRomsCommand = Command.make(
  "build-roms",
  {
    root: Flag.string("root").pipe(
      Flag.withDescription("Repository root holding src/roms/. Defaults to the current directory."),
      Flag.optional,
    ),
    rom: Flag.string("rom").pipe(
      Flag.withDescription("Build only the ROM in src/roms/<name>/. Defaults to all of them."),
      Flag.optional,
    ),
  },
  ({ root, rom }) =>
    buildRoms({
      rootDir: Option.getOrUndefined(root),
      romName: Option.getOrUndefined(rom),
    }),
).pipe(Command.withDescription("Assemble every test ROM under src/roms/ into .roms/."));

if (import.meta.main) {
  Command.run(buildRomsCommand, { version: "0.0.0" }).pipe(
    Effect.provide(NodeServices.layer),
    NodeRuntime.runMain,
  );
}
