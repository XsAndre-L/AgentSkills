import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../', import.meta.url));
// These imported suites depend on upstream website, release, or benchmark
// assets absent from this standalone skill. Keep the exclusions explicit so
// newly added suites run by default. See DEVELOPMENT.md for the test boundary.
const upstreamOnly = new Set([
  'automatic-port-spread.test.mjs',
  'brand-marks.test.mjs',
  'checkout-line-endings.test.mjs',
  'clean-skill-staging.test.mjs',
  'community-proof-intake.test.mjs',
  'cursor-onboarding.test.mjs',
  'gallery.test.mjs',
  'generated-artifact-xml.test.mjs',
  'guide-page.test.mjs',
  'landing.test.mjs',
  'ordinary-model-floor.test.mjs',
  'preview-contract.test.mjs',
  'proof-aperture.test.mjs',
  'reach-share-card.test.mjs',
  'readme-showcase.test.mjs',
  'real-repository-proof.test.mjs',
  'release-identity.test.mjs',
  'release-package-gates.test.mjs',
  'repository-language-metadata.test.mjs',
  'route-share-card.test.mjs',
  'site-language-continuity.test.mjs',
  'stable-update-manifest.test.mjs',
  'start-page.test.mjs',
]);
const tests = fs.readdirSync(path.join(root, 'test'))
  .filter((name) => name.endsWith('.test.mjs') && !upstreamOnly.has(name)).sort();
console.log(`Running ${tests.length} standalone suites; ${upstreamOnly.size} upstream integration suites require the full upstream checkout.`);
const result = spawnSync(process.execPath, [
  '--test', '--test-concurrency=2', ...tests.map((name) => path.join(root, 'test', name)),
], { cwd: root, stdio: 'inherit' });
if (result.error) throw result.error;
process.exitCode = result.status ?? 1;
