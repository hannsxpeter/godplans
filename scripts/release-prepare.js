#!/usr/bin/env node
'use strict';

// One command to start a release: bump the semver in package.json, sync every
// version surface from it, regenerate the prompt and context metrics, and stub
// a CHANGELOG entry whose TODO line release:check refuses to ship.
// Usage: npm run release:prepare -- <patch|minor|major|X.Y.Z>

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const usage = 'Usage: npm run release:prepare -- <patch|minor|major|X.Y.Z>\n';
const bump = process.argv[2];
if (bump === '-h' || bump === '--help') {
  process.stdout.write(usage);
  process.exit(0);
}
// A leading dash would reach npm version as a flag, not a bump.
if (!bump || bump.startsWith('-') || process.argv.length > 3) {
  process.stderr.write(usage);
  process.exit(2);
}

execFileSync('npm', ['version', bump, '--no-git-tag-version', '--allow-same-version'], { cwd: root, stdio: 'inherit' });
const version = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).version;

execFileSync('node', ['scripts/version-sync.js'], { cwd: root, stdio: 'inherit' });

const changelogPath = path.join(root, 'CHANGELOG.md');
let changelog = fs.readFileSync(changelogPath, 'utf8');
if (!changelog.includes(`## [${version}]`)) {
  const today = new Date().toISOString().slice(0, 10);
  const stub = `## [${version}] - ${today}\n\n### Added\n\n- TODO: describe this release.\n\n`;
  changelog = changelog.replace(/\n(## \[)/, `\n${stub}$1`);
  fs.writeFileSync(changelogPath, changelog);
  process.stdout.write(`  stubbed CHANGELOG entry for ${version}\n`);
}

process.stdout.write(`\nPrepared ${version}. Next: write the CHANGELOG body, then commit, open a PR, and tag on merge.\n`);
