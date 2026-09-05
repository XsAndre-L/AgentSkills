# Developing this standalone import

Run `npm ci`, then `npm test` inside this directory. The test command checks
generated brand marks and validators, local release identities, the five
bundled golden renders, and standalone runtime suites. `npm run render:examples`
updates the HTML beside the bundled JSON examples.

The original upstream website, benchmark repositories, release archives, and
release-publishing scripts are not part of this skill. Their imported tests
remain available as reference, but require the full upstream checkout and are
listed explicitly in `scripts/run-tests.mjs`. Some mix runtime checks with
upstream documentation assertions; the standalone command does not claim to
run those suites. New test files run by default.

Website build commands have been removed from this import because their inputs
are not present. The local release-identity check verifies `package.json`,
`package-lock.json`, `skill-release.json`, `SKILL.md`, and the HTML template.
It does not validate upstream release tags or hosted assets.

Browser suites may report skips when Chrome is unavailable. The optional
`npm run test:webm` exercises the standalone WebM smoke workflow.

The repository packaging script excludes development dependencies, scripts,
tests, and this document from `archify.skill`; rendering needs only Node.js.
