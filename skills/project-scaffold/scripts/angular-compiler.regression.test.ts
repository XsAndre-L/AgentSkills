import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import ts from "typescript";

test("generated Angular compiler options are accepted by the selected TypeScript version", () => {
  const project = mkdtempSync(join(tmpdir(), "project-scaffold-typescript-"));
  try {
    const result = Bun.spawnSync([
      process.execPath, resolve(import.meta.dir, "scaffold.ts"), "apply",
      "--root", project, "--profile", "angular-webquark", "--json",
    ], { stdout: "pipe", stderr: "pipe" });
    expect(result.exitCode, Buffer.from(result.stderr).toString()).toBe(0);
    const frontend = join(project, "frontend");
    const pkg = JSON.parse(readFileSync(join(frontend, "package.json"), "utf8"));
    expect(pkg.devDependencies.typescript).toBe(`~${ts.version}`);
    const config = ts.readConfigFile(join(frontend, "tsconfig.json"), ts.sys.readFile);
    expect(config.error).toBeUndefined();
    const parsed = ts.parseJsonConfigFileContent(config.config, ts.sys, frontend);
    expect(parsed.errors).toEqual([]);
    const source = join(frontend, "compiler-smoke.ts");
    writeFileSync(source, "export const value: number = 1;\n");
    const program = ts.createProgram([source], { ...parsed.options, noEmit: true });
    const diagnostics = ts.getPreEmitDiagnostics(program);
    expect(diagnostics.map((d) => ts.flattenDiagnosticMessageText(d.messageText, "\n"))).toEqual([]);
  } finally {
    rmSync(project, { recursive: true, force: true });
  }
});
