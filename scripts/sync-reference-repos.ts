#!/usr/bin/env node

import * as NodeRuntime from "@effect/platform-node/NodeRuntime";
import * as NodeServices from "@effect/platform-node/NodeServices";
import * as Console from "effect/Console";
import * as Effect from "effect/Effect";
import * as FileSystem from "effect/FileSystem";
import * as Option from "effect/Option";
import * as Path from "effect/Path";
import * as Schema from "effect/Schema";
import * as Stream from "effect/Stream";
import { Command, Flag } from "effect/unstable/cli";
import { ChildProcess, ChildProcessSpawner } from "effect/unstable/process";

import { fromYaml } from "./lib/schemaYaml.ts";
import { referenceRepos, type ReferenceRepo } from "./lib/reference-repos.ts";

export type ReferenceRepoSyncAction = "clone" | "update";

export interface ReferenceRepoSyncOptions {
  readonly rootDir?: string | undefined;
  readonly repoId?: string | undefined;
  readonly latest?: boolean | undefined;
  readonly dryRun?: boolean | undefined;
}

export interface ReferenceRepoSyncPlan {
  readonly repo: ReferenceRepo;
  readonly action: ReferenceRepoSyncAction;
  readonly ref: string;
  readonly directory: string;
  readonly steps: ReadonlyArray<ReadonlyArray<string>>;
}

export class ReferenceRepoSelectionError extends Schema.TaggedErrorClass<ReferenceRepoSelectionError>()(
  "ReferenceRepoSelectionError",
  {
    repoId: Schema.String,
    expectedRepoIds: Schema.Array(Schema.String),
  },
) {
  override get message(): string {
    return `Unknown reference repo "${this.repoId}". Expected one of: ${this.expectedRepoIds.join(", ")}.`;
  }
}

export class ReferenceRepoVersionSourceError extends Schema.TaggedErrorClass<ReferenceRepoVersionSourceError>()(
  "ReferenceRepoVersionSourceError",
  {
    operation: Schema.Literals(["read", "parse"]),
    repoId: Schema.String,
    sourcePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Reference repo "${this.repoId}" version source operation "${this.operation}" failed for ${this.sourcePath}.`;
  }
}

export class ReferenceRepoVersionResolutionError extends Schema.TaggedErrorClass<ReferenceRepoVersionResolutionError>()(
  "ReferenceRepoVersionResolutionError",
  {
    repoId: Schema.String,
    sourcePath: Schema.String,
    packageVersionPath: Schema.Array(Schema.String),
  },
) {
  override get message(): string {
    return `No version was found for reference repo "${this.repoId}" at ${this.sourcePath}:${this.packageVersionPath.join(".")}.`;
  }
}

export class ReferenceRepoGitError extends Schema.TaggedErrorClass<ReferenceRepoGitError>()(
  "ReferenceRepoGitError",
  {
    operation: Schema.Literals(["spawn", "communicate", "exit"]),
    repoId: Schema.String,
    action: Schema.Literals(["clone", "update"]),
    repository: Schema.String,
    ref: Schema.String,
    directory: Schema.String,
    step: Schema.Array(Schema.String),
    exitCode: Schema.optional(Schema.Number),
    stdout: Schema.optional(Schema.String),
    stderr: Schema.optional(Schema.String),
    cause: Schema.optional(Schema.Defect()),
  },
) {
  override get message(): string {
    const headline = `Reference repo "${this.repoId}" failed to ${this.action} during "${this.operation}": git ${this.step.join(" ")}`;
    const output = [this.stderr, this.stdout]
      .map((text) => text?.trim())
      .filter((text) => text !== undefined && text.length > 0)
      .join("\n");
    return output.length > 0 ? `${headline}\n${output}` : headline;
  }
}

export const ReferenceRepoSyncError = Schema.Union([
  ReferenceRepoSelectionError,
  ReferenceRepoVersionSourceError,
  ReferenceRepoVersionResolutionError,
  ReferenceRepoGitError,
]);
export type ReferenceRepoSyncError = typeof ReferenceRepoSyncError.Type;
export const isReferenceRepoSyncError = Schema.is(ReferenceRepoSyncError);

const decodeJsonSource = Schema.decodeUnknownEffect(Schema.UnknownFromJsonString);
const decodeYamlSource = Schema.decodeEffect(fromYaml(Schema.Unknown));

const collectStreamAsString = <E>(stream: Stream.Stream<Uint8Array, E>): Effect.Effect<string, E> =>
  stream.pipe(
    Stream.decodeText(),
    Stream.runFold(
      () => "",
      (acc, chunk) => acc + chunk,
    ),
  );

function readNestedString(input: unknown, keys: ReadonlyArray<string>): string | undefined {
  let value = input;
  for (const key of keys) {
    if (typeof value !== "object" || value === null || !(key in value)) {
      return undefined;
    }
    value = (value as Record<string, unknown>)[key];
  }
  return typeof value === "string" && value.length > 0 ? value : undefined;
}

function decodeVersionSource(
  repo: ReferenceRepo,
  sourcePath: string,
  content: string,
): Effect.Effect<unknown, ReferenceRepoSyncError> {
  const decode =
    repo.versionSourcePath.endsWith(".yaml") || repo.versionSourcePath.endsWith(".yml")
      ? decodeYamlSource
      : decodeJsonSource;
  return decode(content).pipe(
    Effect.mapError(
      (cause) =>
        new ReferenceRepoVersionSourceError({
          operation: "parse",
          repoId: repo.id,
          sourcePath,
          cause,
        }),
    ),
  );
}

function getSelectedRepos(
  repoId: string | undefined,
): Effect.Effect<ReadonlyArray<ReferenceRepo>, ReferenceRepoSyncError> {
  if (!repoId) {
    return Effect.succeed(referenceRepos);
  }

  const repo = referenceRepos.find((candidate) => candidate.id === repoId);
  return repo
    ? Effect.succeed([repo])
    : Effect.fail(
        new ReferenceRepoSelectionError({
          repoId,
          expectedRepoIds: referenceRepos.map((candidate) => candidate.id),
        }),
      );
}

export const resolveReferenceRepoRef = Effect.fn("resolveReferenceRepoRef")(function* (
  repo: ReferenceRepo,
  rootDir: string,
  latest: boolean,
) {
  if (latest) {
    return repo.latestRef;
  }

  const fs = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const versionSourcePath = path.join(rootDir, repo.versionSourcePath);
  const versionSourceContent = yield* fs.readFileString(versionSourcePath).pipe(
    Effect.mapError(
      (cause) =>
        new ReferenceRepoVersionSourceError({
          operation: "read",
          repoId: repo.id,
          sourcePath: versionSourcePath,
          cause,
        }),
    ),
  );
  const versionSource = yield* decodeVersionSource(repo, versionSourcePath, versionSourceContent);
  const version = readNestedString(versionSource, repo.packageVersionPath);

  if (!version) {
    return yield* new ReferenceRepoVersionResolutionError({
      repoId: repo.id,
      sourcePath: versionSourcePath,
      packageVersionPath: repo.packageVersionPath,
    });
  }

  return `${repo.versionTagPrefix}${version}`;
});

export const planReferenceRepoSync = Effect.fn("planReferenceRepoSync")(function* (
  repo: ReferenceRepo,
  rootDir: string,
  latest: boolean,
) {
  const fs = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const directory = path.join(rootDir, repo.prefix);
  const action: ReferenceRepoSyncAction = (yield* fs.exists(path.join(directory, ".git")))
    ? "update"
    : "clone";
  const ref = yield* resolveReferenceRepoRef(repo, rootDir, latest);

  return {
    repo,
    action,
    ref,
    directory,
    // A shallow detached checkout, not a clone or a subtree. .repos/ is
    // ignored, so nothing here enters our history; we only ever read these
    // sources. Depth 1 keeps mednafen-git from dragging in years of history
    // we will never look at, and fetching the ref directly means a pinned
    // commit costs the same as a branch.
    steps: [
      ["init", "--quiet"],
      ["fetch", "--depth=1", "--force", repo.repository, ref],
      ["checkout", "--quiet", "--force", "--detach", "FETCH_HEAD"],
    ],
  } satisfies ReferenceRepoSyncPlan;
});

const runGitStep = Effect.fn("runGitStep")(function* (
  plan: ReferenceRepoSyncPlan,
  step: ReadonlyArray<string>,
) {
  const spawner = yield* ChildProcessSpawner.ChildProcessSpawner;
  const errorContext = {
    repoId: plan.repo.id,
    action: plan.action,
    repository: plan.repo.repository,
    ref: plan.ref,
    directory: plan.directory,
    step,
  } as const;
  const child = yield* spawner
    .spawn(ChildProcess.make("git", [...step], { cwd: plan.directory }))
    .pipe(
      Effect.mapError(
        (cause) =>
          new ReferenceRepoGitError({
            ...errorContext,
            operation: "spawn",
            cause,
          }),
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
      (cause) =>
        new ReferenceRepoGitError({
          ...errorContext,
          operation: "communicate",
          cause,
        }),
    ),
  );

  if (exitCode !== 0) {
    return yield* new ReferenceRepoGitError({
      ...errorContext,
      operation: "exit",
      exitCode,
      stdout,
      stderr,
    });
  }

  if (stdout.trim().length > 0) {
    yield* Console.log(stdout.trim());
  }
});

export const syncReferenceRepos = Effect.fn("syncReferenceRepos")(function* (
  options: ReferenceRepoSyncOptions = {},
) {
  const fs = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const rootDir = path.resolve(options.rootDir ?? process.cwd());
  const repos = yield* getSelectedRepos(options.repoId);
  const dryRun = options.dryRun ?? false;
  const plans: Array<ReferenceRepoSyncPlan> = [];

  for (const repo of repos) {
    const plan = yield* planReferenceRepoSync(repo, rootDir, options.latest ?? false);
    plans.push(plan);
    yield* Console.log(
      `${plan.action === "clone" ? "Cloning" : "Updating"} ${repo.id} at ${plan.ref}.`,
    );
    if (dryRun) {
      continue;
    }

    yield* fs.makeDirectory(plan.directory, { recursive: true }).pipe(
      Effect.mapError(
        (cause) =>
          new ReferenceRepoGitError({
            repoId: repo.id,
            action: plan.action,
            repository: repo.repository,
            ref: plan.ref,
            directory: plan.directory,
            step: ["init", "--quiet"],
            operation: "spawn",
            cause,
          }),
      ),
    );
    for (const step of plan.steps) {
      yield* runGitStep(plan, step).pipe(Effect.scoped);
    }
  }

  return plans;
});

export const syncReferenceReposCommand = Command.make(
  "sync-reference-repos",
  {
    repo: Flag.string("repo").pipe(
      Flag.withDescription("Sync only the named reference repo. Defaults to all configured repos."),
      Flag.optional,
    ),
    latest: Flag.boolean("latest").pipe(
      Flag.withDescription(
        "Sync each repo from its latest branch instead of the installed version.",
      ),
      Flag.withDefault(false),
    ),
    root: Flag.string("root").pipe(
      Flag.withDescription("Workspace root used to resolve versions and checkout directories."),
      Flag.optional,
    ),
    dryRun: Flag.boolean("dry-run").pipe(
      Flag.withDescription("Print what each repo would be synced to without running git."),
      Flag.withDefault(false),
    ),
  },
  ({ repo, latest, root, dryRun }) =>
    syncReferenceRepos({
      repoId: Option.getOrUndefined(repo),
      rootDir: Option.getOrUndefined(root),
      latest,
      dryRun,
    }),
).pipe(
  Command.withDescription(
    "Check out the reference emulator sources under .repos/, which is git-ignored.",
  ),
);

if (import.meta.main) {
  Command.run(syncReferenceReposCommand, { version: "0.0.0" }).pipe(
    Effect.provide(NodeServices.layer),
    NodeRuntime.runMain,
  );
}
