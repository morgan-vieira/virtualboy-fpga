"use strict";

// Runs inside the VS Code extension host launched by scripts/format-with-vscode.ts.
const vscode = require("vscode");

const formatterExtensionId = process.env.FORMAT_EXTENSION_ID;
const includeGlob = process.env.FORMAT_INCLUDE_GLOB;
const probeLanguage = process.env.FORMAT_PROBE_LANGUAGE;
const probeContent = process.env.FORMAT_PROBE_CONTENT;
const excludeGlob = "{**/node_modules/**,**/.repos/**,**/.vscode-test/**}";
const probeAttempts = 30;
const probeIntervalMs = 500;

// An extension backed by a language server finishes activating before the server
// registers its formatting provider, and formatDocument is a silent no-op until it does:
// files in that window get reported as already formatted. Wait until the provider answers
// on scratch content the formatter is known to rewrite.
async function waitForFormatter() {
  const document = await vscode.workspace.openTextDocument({
    language: probeLanguage,
    content: probeContent,
  });
  for (let attempt = 0; attempt < probeAttempts; attempt += 1) {
    const edits = await vscode.commands.executeCommand(
      "vscode.executeFormatDocumentProvider",
      document.uri,
    );
    if (edits !== undefined) return;
    await new Promise((resolve) => setTimeout(resolve, probeIntervalMs));
  }
  throw new Error(
    `${formatterExtensionId} registered no ${probeLanguage} formatter within ` +
      `${(probeAttempts * probeIntervalMs) / 1000}s.`,
  );
}

async function run() {
  if (!formatterExtensionId || !includeGlob) {
    throw new Error("FORMAT_EXTENSION_ID and FORMAT_INCLUDE_GLOB must both be set.");
  }

  const formatter = vscode.extensions.getExtension(formatterExtensionId);
  if (!formatter) {
    throw new Error(`Extension ${formatterExtensionId} is not installed in this VS Code instance.`);
  }
  await formatter.activate();
  if (probeLanguage && probeContent) await waitForFormatter();

  const uris = await vscode.workspace.findFiles(includeGlob, excludeGlob);
  uris.sort((a, b) => a.fsPath.localeCompare(b.fsPath));

  let changed = 0;
  for (const uri of uris) {
    const document = await vscode.workspace.openTextDocument(uri);
    await vscode.window.showTextDocument(document, { preview: false });
    await vscode.commands.executeCommand("editor.action.formatDocument");
    const wasDirty = document.isDirty;
    if (wasDirty) {
      changed += 1;
      if (!(await document.save())) {
        throw new Error(`Saving ${uri.fsPath} failed.`);
      }
    }
    console.log(`${wasDirty ? "formatted" : "unchanged"} ${vscode.workspace.asRelativePath(uri)}`);
    await vscode.commands.executeCommand("workbench.action.closeActiveEditor");
  }

  console.log(`Done: ${uris.length} files checked, ${changed} reformatted.`);
}

module.exports = { run };
