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
import { fileURLToPath } from "node:url";

import { downloadAndUnzipVSCode, runTests, runVSCodeCommand } from "@vscode/test-electron";

export interface FormatTarget {
  readonly extensionId: string;
  readonly include: string;
  // Settings for the disposable profile. Any built-in formatter competing with the
  // target's must be turned off here: given two candidates, VS Code stops to ask which
  // to use and writes the answer into the workspace's own .vscode/settings.json.
  readonly profileSettings?: Readonly<Record<string, unknown>> | undefined;
  // Scratch content the formatter is guaranteed to rewrite, used by the runner to tell
  // that a language server has finished registering. Omit for extensions that register
  // their formatter as they activate.
  readonly probe?: { readonly language: string; readonly content: string } | undefined;
}

// The formatters we use only ship as VS Code extensions, so each target names the
// extension that formats it and the files it owns. Keep these in step with the
// per-language editor.defaultFormatter entries in .vscode/settings.json.
export const markdownTarget: FormatTarget = {
  extensionId: "yzhang.markdown-all-in-one",
  include: "**/*.md",
};

export const typescriptTarget: FormatTarget = {
  extensionId: "oxc.oxc-vscode",
  include: "**/*.ts",
  profileSettings: { "typescript.format.enable": false, "javascript.format.enable": false },
  probe: { language: "typescript", content: "const   probe    =   1\n" },
};

export interface FormatOptions {
  readonly rootDir?: string | undefined;
}

export class VsCodeDownloadError extends Schema.TaggedErrorClass<VsCodeDownloadError>()(
  "VsCodeDownloadError",
  {
    cachePath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Downloading VS Code into ${this.cachePath} failed.`;
  }
}

export class FormatterInstallError extends Schema.TaggedErrorClass<FormatterInstallError>()(
  "FormatterInstallError",
  {
    extensionId: Schema.String,
    extensionsDir: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Installing ${this.extensionId} into ${this.extensionsDir} failed.`;
  }
}

export class ProfileWriteError extends Schema.TaggedErrorClass<ProfileWriteError>()(
  "ProfileWriteError",
  {
    settingsPath: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Writing the disposable profile settings to ${this.settingsPath} failed.`;
  }
}

export class FormatterRunError extends Schema.TaggedErrorClass<FormatterRunError>()(
  "FormatterRunError",
  {
    include: Schema.String,
    rootDir: Schema.String,
    cause: Schema.Defect(),
  },
) {
  override get message(): string {
    return `Formatting ${this.include} under ${this.rootDir} failed.`;
  }
}

export const FormatError = Schema.Union([
  VsCodeDownloadError,
  FormatterInstallError,
  ProfileWriteError,
  FormatterRunError,
]);
export type FormatError = typeof FormatError.Type;
export const isFormatError = Schema.is(FormatError);

// Formatting happens inside a disposable VS Code instance: download one into
// .vscode-test/, install the target's extension into an isolated profile, then run
// scripts/format-runner/runner.cjs in its extension host to format and save every
// matching file in the workspace.
export const formatFiles = Effect.fn("formatFiles")(function* (
  target: FormatTarget,
  options: FormatOptions = {},
) {
  const fileSystem = yield* FileSystem.FileSystem;
  const path = yield* Path.Path;
  const rootDir = path.resolve(options.rootDir ?? process.cwd());
  const cachePath = path.join(rootDir, ".vscode-test");
  const extensionsDir = path.join(cachePath, "extensions");
  const userDataDir = path.join(cachePath, "user-data");
  const runnerDir = fileURLToPath(new URL("./format-runner", import.meta.url));

  yield* Console.log(`Preparing VS Code in ${cachePath}.`);
  const vscodeExecutablePath = yield* Effect.tryPromise({
    try: () => downloadAndUnzipVSCode({ cachePath }),
    catch: (cause) => new VsCodeDownloadError({ cachePath, cause }),
  });

  yield* Console.log(`Installing ${target.extensionId}.`);
  yield* Effect.tryPromise({
    try: () =>
      runVSCodeCommand(
        [
          "--install-extension",
          target.extensionId,
          "--force",
          "--extensions-dir",
          extensionsDir,
          "--user-data-dir",
          userDataDir,
        ],
        { cachePath },
      ),
    catch: (cause) =>
      new FormatterInstallError({
        extensionId: target.extensionId,
        extensionsDir,
        cause,
      }),
  });

  const profileSettingsPath = path.join(userDataDir, "User", "settings.json");
  yield* fileSystem.makeDirectory(path.dirname(profileSettingsPath), { recursive: true }).pipe(
    Effect.andThen(
      fileSystem.writeFileString(
        profileSettingsPath,
        JSON.stringify(target.profileSettings ?? {}, null, 2),
      ),
    ),
    Effect.mapError((cause) => new ProfileWriteError({ settingsPath: profileSettingsPath, cause })),
  );

  yield* Console.log(`Formatting ${target.include} under ${rootDir}.`);
  yield* Effect.tryPromise({
    try: () =>
      runTests({
        vscodeExecutablePath,
        extensionDevelopmentPath: runnerDir,
        extensionTestsPath: path.join(runnerDir, "runner.cjs"),
        extensionTestsEnv: {
          FORMAT_EXTENSION_ID: target.extensionId,
          FORMAT_INCLUDE_GLOB: target.include,
          FORMAT_PROBE_LANGUAGE: target.probe?.language,
          FORMAT_PROBE_CONTENT: target.probe?.content,
        },
        launchArgs: [
          rootDir,
          `--extensions-dir=${extensionsDir}`,
          `--user-data-dir=${userDataDir}`,
          // The built-in git extension chokes on symlinked paths (.claude/skills)
          // and floods the log; the formatter does not need it.
          "--disable-extension=vscode.git",
        ],
      }),
    catch: (cause) => new FormatterRunError({ include: target.include, rootDir, cause }),
  });
});

export const formatWithVsCodeCommand = Command.make(
  "format-with-vscode",
  {
    language: Flag.choiceWithValue("language", [
      ["markdown", markdownTarget],
      ["typescript", typescriptTarget],
    ]).pipe(Flag.withDescription("Which set of files to format.")),
    root: Flag.string("root").pipe(
      Flag.withDescription(
        "Workspace root whose files are formatted. Defaults to the current directory.",
      ),
      Flag.optional,
    ),
  },
  ({ language, root }) => formatFiles(language, { rootDir: Option.getOrUndefined(root) }),
).pipe(Command.withDescription("Format a workspace with the VS Code extension that owns it."));

if (import.meta.main) {
  Command.run(formatWithVsCodeCommand, { version: "0.0.0" }).pipe(
    Effect.provide(NodeServices.layer),
    NodeRuntime.runMain,
  );
}
