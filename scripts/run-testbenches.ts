#!/usr/bin/env node

import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import * as Console from "effect/Console";
import * as Duration from "effect/Duration";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Option from "effect/Option";
import * as Path from "effect/Path";
import * as Schema from "effect/Schema";
import * as Stream from "effect/Stream";
import { Command, Flag } from "effect/unstable/cli";
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process";

// A module's testbench is src/tests/<module>.v, named for the module it
// exercises and compiled against the synthesizable sources under src/fpga/core/.
// The compiled programs and any waveform dumps are disposable and land in a
// gitignored directory at the root.
export const testbenchSourceDirPath = ["src", "tests"] as const;
export const moduleLibraryDirPath = ["src", "fpga", "core"] as const;
export const testbenchOutputDirName = ".sim";
export const testbenchFileSuffix = ".v";

// $fatal and $error only exist under a SystemVerilog generation, and they are how
// a self-checking bench reports. Synthesizable sources carry no timescale of their
// own, so the inheritance warning fires on every module and says nothing.
const iverilogFlags = ["-g2012", "-Wall", "-Wno-timescale"] as const;

// Icarus resolves an instantiated module to <library>/<module name>.v, which is
// why a module's file name has to match the module inside it.
const moduleLibraryFlag = "-y";

export const defaultTimeoutSeconds = 60;

export interface TestbenchRunOptions {
  readonly rootDir?: string | undefined;
  readonly testbenchName?: string | undefined;
  readonly timeoutSeconds?: number | undefined;
}

export class TestbenchDiscoveryError extends Schema.TaggedErrorClass<TestbenchDiscoveryError>()(
  "TestbenchDiscoveryError",
  {
    sourceDir: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Listing testbenches under ${this.sourceDir} failed.`;
  }
}

export class TestbenchSelectionError extends Schema.TaggedErrorClass<TestbenchSelectionError>()(
  "TestbenchSelectionError",
  {
    testbenchName: Schema.String,
    availableTestbenchNames: Schema.Array(Schema.String),
  },
) {
  override get message(): string {
    const available = this.availableTestbenchNames.join(", ");
    return `No testbench named ${this.testbenchName}. Available: ${available.length > 0 ? available : "none"}.`;
  }
}

export class TestbenchToolError extends Schema.TaggedErrorClass<TestbenchToolError>()(
  "TestbenchToolError",
  {
    operation: Schema.Literals(["spawn", "communicate"]),
    tool: Schema.Literals(["iverilog", "vvp"]),
    testbenchName: Schema.String,
    command: Schema.Array(Schema.String),
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    const headline = `Running ${this.tool} for ${this.testbenchName} failed during "${this.operation}": ${this.command.join(" ")}`;
    return this.operation === "spawn"
      ? `${headline}\nIcarus Verilog installs to C:\\iverilog on morgan-vieira's machine; check that its bin directory is on PATH.`
      : headline;
  }
}

export class TestbenchFailure extends Schema.TaggedErrorClass<TestbenchFailure>()(
  "TestbenchFailure",
  {
    stage: Schema.Literals(["compile", "simulate", "timeout"]),
    testbenchName: Schema.String,
    command: Schema.Array(Schema.String),
    exitCode: Schema.optional(Schema.Number),
    output: Schema.String,
  },
) {
  override get message(): string {
    const reason =
      this.stage === "compile"
        ? `did not compile (exit ${this.exitCode})`
        : this.stage === "timeout"
          ? "never finished; it is missing a $finish or is stuck"
          : `failed (exit ${this.exitCode})`;
    const headline = `${this.testbenchName} ${reason}: ${this.command.join(" ")}`;
    const output = this.output.trim();
    return output.length > 0 ? `${headline}\n${indent(output)}` : headline;
  }
}

export class TestbenchRunFailed extends Schema.TaggedErrorClass<TestbenchRunFailed>()(
  "TestbenchRunFailed",
  {
    failedTestbenchNames: Schema.Array(Schema.String),
    testbenchCount: Schema.Number,
  },
) {
  override get message(): string {
    return `${this.failedTestbenchNames.length} of ${this.testbenchCount} testbenches failed: ${this.failedTestbenchNames.join(", ")}.`;
  }
}

export const TestbenchRunError = Schema.Union([
  TestbenchDiscoveryError,
  TestbenchSelectionError,
  TestbenchToolError,
  TestbenchFailure,
  TestbenchRunFailed,
]);
export type TestbenchRunError = typeof TestbenchRunError.Type;
export const isTestbenchRunError = Schema.is(TestbenchRunError);

export interface Testbench {
  /**
   * File base name, which is the name of the module under test:
   * `host_video_timing`. The bench module inside carries a `_tb` suffix so it
   * cannot collide with the module it instantiates.
   */
  readonly name: string;
  readonly sourcePath: string;
}

const indent = (text: string): string =>
  text
    .split("\n")
    .map((line) => `  ${line}`)
    .join("\n");

const collectStreamAsString = <E>(stream: Stream.Stream<Uint8Array, E>): Effect.Effect<string, E> =>
  stream.pipe(
    Stream.decodeText(),
    Stream.runFold(
      () => "",
      (acc, chunk) => acc + chunk,
    ),
  );

export const findTestbenches = Effect.fn("findTestbenches")(function* (sourceDir: string) {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;

  const entries = yield* fileSystem
    .readDirectory(sourceDir)
    .pipe(Effect.mapError((cause) => new TestbenchDiscoveryError({ sourceDir, cause })));

  return [...entries]
    .filter((entry) => entry.endsWith(testbenchFileSuffix))
    .sort()
    .map((entry) => ({
      name: entry.slice(0, -".v".length),
      sourcePath: path.join(sourceDir, entry),
    }));
});

const runTool = Effect.fn("runTool")(function* (
  tool: "iverilog" | "vvp",
  args: ReadonlyArray<string>,
  context: { readonly testbenchName: string; readonly cwd: string },
) {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
  const command = [tool, ...args] as const;
  const errorContext = { tool, testbenchName: context.testbenchName, command } as const;

  const child = yield* spawner
    .spawn(ChildProcess.make(tool, [...args], { cwd: context.cwd }))
    .pipe(
      Effect.mapError(
        (cause) => new TestbenchToolError({ ...errorContext, operation: "spawn", cause }),
      ),
    );

  const [stdout, stderr, exitCode] = yield* Effect.all(
    [
      collectStreamAsString(child.stdout),
      collectStreamAsString(child.stderr),
      child.exitCode.pipe(Effect.map(Number)),
    ],
    { concurrency: "unbounded" },
  ).pipe(
    Effect.mapError(
      (cause) => new TestbenchToolError({ ...errorContext, operation: "communicate", cause }),
    ),
  );

  return { command, exitCode, output: [stdout, stderr].filter((text) => text.length > 0).join("") };
});

/**
 * Compiles one testbench and runs it. Succeeds only when the bench ran to
 * completion without reporting; fails with a `TestbenchFailure` otherwise.
 */
export const runTestbench = Effect.fn("runTestbench")(function* (
  testbench: Testbench,
  paths: { readonly moduleLibraryDir: string; readonly outputDir: string },
  timeout: Duration.Duration,
) {
  const path = yield* Path.Path;
  const programPath = path.join(paths.outputDir, `${testbench.name}.vvp`);

  const compile = yield* runTool(
    "iverilog",
    [
      ...iverilogFlags,
      moduleLibraryFlag,
      paths.moduleLibraryDir,
      "-o",
      programPath,
      testbench.sourcePath,
    ],
    { testbenchName: testbench.name, cwd: paths.outputDir },
  ).pipe(Effect.scoped);

  if (compile.exitCode !== 0) {
    return yield* new TestbenchFailure({
      stage: "compile",
      testbenchName: testbench.name,
      command: compile.command,
      exitCode: compile.exitCode,
      output: compile.output,
    });
  }

  // Run from the output directory so a bench's $dumpfile lands beside its program.
  const simulate = yield* runTool("vvp", [programPath], {
    testbenchName: testbench.name,
    cwd: paths.outputDir,
  }).pipe(
    Effect.scoped,
    Effect.timeoutOrElse({
      duration: timeout,
      orElse: () =>
        new TestbenchFailure({
          stage: "timeout",
          testbenchName: testbench.name,
          command: ["vvp", programPath],
          output: `No result after ${Duration.toSeconds(timeout)} seconds.`,
        }),
    }),
  );

  // $fatal exits nonzero but $error does not, so its marker in the output is the
  // only thing that distinguishes a reporting bench from a silent one.
  const reportedError = /^ERROR:/m.test(simulate.output);
  if (simulate.exitCode !== 0 || reportedError) {
    return yield* new TestbenchFailure({
      stage: "simulate",
      testbenchName: testbench.name,
      command: simulate.command,
      exitCode: simulate.exitCode,
      output: simulate.output,
    });
  }

  return compile.output.trim();
});

export const runTestbenches = Effect.fn("runTestbenches")(function* (
  options: TestbenchRunOptions = {},
) {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;

  const rootDir = path.resolve(options.rootDir ?? process.cwd());
  const sourceDir = path.join(rootDir, ...testbenchSourceDirPath);
  const moduleLibraryDir = path.join(rootDir, ...moduleLibraryDirPath);
  const outputDir = path.join(rootDir, testbenchOutputDirName);
  const timeout = Duration.seconds(options.timeoutSeconds ?? defaultTimeoutSeconds);

  const allTestbenches = yield* findTestbenches(sourceDir);
  const testbenches =
    options.testbenchName === undefined
      ? allTestbenches
      : allTestbenches.filter((testbench) => testbench.name === options.testbenchName);

  if (options.testbenchName !== undefined && testbenches.length === 0) {
    return yield* new TestbenchSelectionError({
      testbenchName: options.testbenchName,
      availableTestbenchNames: allTestbenches.map((testbench) => testbench.name),
    });
  }

  if (testbenches.length === 0) {
    yield* Console.log(`No *${testbenchFileSuffix} testbenches under ${sourceDir}.`);
    return [];
  }

  yield* fileSystem
    .makeDirectory(outputDir, { recursive: true })
    .pipe(Effect.mapError((cause) => new TestbenchDiscoveryError({ sourceDir: outputDir, cause })));

  const failedTestbenchNames: Array<string> = [];

  for (const testbench of testbenches) {
    const outcome = yield* runTestbench(testbench, { moduleLibraryDir, outputDir }, timeout).pipe(
      Effect.result,
    );

    if (outcome._tag === "Failure") {
      failedTestbenchNames.push(testbench.name);
      yield* Console.log(`${testbench.name}  FAILED`);
      yield* Console.log(indent(outcome.failure.message));
      continue;
    }

    // A pass is silent: a self-checking bench that had anything to say would have
    // said it through $fatal. Compiler warnings still surface.
    yield* Console.log(`${testbench.name}  ok`);
    if (outcome.success.length > 0) yield* Console.log(indent(outcome.success));
  }

  yield* Console.log("");
  yield* Console.log(
    `Ran ${testbenches.length} testbench(es): ${testbenches.length - failedTestbenchNames.length} passed, ${failedTestbenchNames.length} failed.`,
  );

  if (failedTestbenchNames.length > 0) {
    return yield* new TestbenchRunFailed({
      failedTestbenchNames,
      testbenchCount: testbenches.length,
    });
  }

  return testbenches;
});

export const runTestbenchesCommand = Command.make(
  "run-testbenches",
  {
    root: Flag.string("root").pipe(
      Flag.withDescription(
        "Repository root holding src/tests/. Defaults to the current directory.",
      ),
      Flag.optional,
    ),
    bench: Flag.string("bench").pipe(
      Flag.withDescription(
        "Run only this testbench, named for its module. Defaults to all of them.",
      ),
      Flag.optional,
    ),
    timeout: Flag.integer("timeout").pipe(
      Flag.withDescription("Seconds a single simulation may run before it is killed."),
      Flag.withDefault(defaultTimeoutSeconds),
    ),
  },
  ({ root, bench, timeout }) =>
    runTestbenches({
      rootDir: Option.getOrUndefined(root),
      testbenchName: Option.getOrUndefined(bench),
      timeoutSeconds: timeout,
    }),
).pipe(
  Command.withDescription(
    "Compile and run every Verilog testbench under src/tests/ with Icarus Verilog.",
  ),
);

if (import.meta.main) {
  Command.run(runTestbenchesCommand, { version: "0.0.0" }).pipe(
    Effect.provide(NodeServices.layer),
    NodeRuntime.runMain,
  );
}
