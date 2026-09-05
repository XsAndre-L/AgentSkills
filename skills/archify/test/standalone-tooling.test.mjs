import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { checkReleaseIdentity } from '../scripts/check-release-identity.mjs';

const root = fileURLToPath(new URL('../', import.meta.url));

test('standalone npm commands reference files inside this skill', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8'));
  for (const command of Object.values(pkg.scripts)) {
    for (const match of command.matchAll(/\bnode\s+(\S+)/g)) {
      const script = path.resolve(root, match[1]);
      assert.ok(script.startsWith(root), `script escapes the skill: ${command}`);
      assert.ok(fs.statSync(script).isFile(), `missing script: ${command}`);
    }
  }
});

test('standalone identity check accepts the import and rejects a stale release file', () => {
  const fixture = fs.mkdtempSync(path.join(os.tmpdir(), 'archify-local-identity-'));
  try {
    for (const relative of ['package.json', 'package-lock.json', 'skill-release.json', 'SKILL.md', 'assets/template.html']) {
      const target = path.join(fixture, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.copyFileSync(path.join(root, relative), target);
    }
    assert.equal(checkReleaseIdentity(fixture), checkReleaseIdentity(root));
    const releasePath = path.join(fixture, 'skill-release.json');
    const release = JSON.parse(fs.readFileSync(releasePath, 'utf8'));
    release.version = '0.0.0';
    fs.writeFileSync(releasePath, JSON.stringify(release));
    assert.throws(() => checkReleaseIdentity(fixture), /skill-release.json version differs/);
  } finally {
    fs.rmSync(fixture, { recursive: true, force: true });
  }
});
