// Check identities shipped in this standalone skill, without upstream site files.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

export function checkReleaseIdentity(root) {
  const read = (name) => fs.readFileSync(path.join(root, name), 'utf8');
  const pkg = JSON.parse(read('package.json'));
  const lock = JSON.parse(read('package-lock.json'));
  const release = JSON.parse(read('skill-release.json'));
  assert.match(pkg.version, /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/);
  assert.equal(lock.version, pkg.version, 'package-lock.json version differs');
  assert.equal(lock.packages?.['']?.version, pkg.version, 'lock root version differs');
  assert.equal(release.version, pkg.version, 'skill-release.json version differs');
  assert.equal(release.skillId, pkg.name, 'skill-release.json identity differs');
  assert.equal(release.channel, pkg.version.includes('-') ? 'development' : 'stable');
  const skillVersion = read('SKILL.md').match(/^\s*version:\s*"([^"]+)"/m)?.[1];
  assert.equal(skillVersion, pkg.version.split('.').slice(0, 2).join('.'), 'SKILL.md version differs');
  assert.ok(read('assets/template.html').includes(
    `<meta name="generator" content="archify ${pkg.version}">`,
  ), 'template generator version differs');
  return pkg.version;
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const root = fileURLToPath(new URL('../', import.meta.url));
  try {
    console.log(`Standalone skill identity verified: ${checkReleaseIdentity(root)}`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}
