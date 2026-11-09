#!/usr/bin/env node
'use strict';

// Single source of version truth: package.json. Writes that version into every
// surface listed below, then regenerates the prompt and the context metrics
// that hash it, so a release never hand-edits version strings in lockstep. The
// CHANGELOG.md heading is not a surface here: release-prepare.js stubs it.
// --check only compares and writes nothing. Run: npm run version:sync (or
// version:check).

const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const usage = 'Usage: node scripts/version-sync.js [--check]\n';
const args = process.argv.slice(2);
if (args.includes('-h') || args.includes('--help')) {
  process.stdout.write(usage);
  process.exit(0);
}
const unknown = args.find((arg) => arg !== '--check');
if (unknown !== undefined) {
  process.stderr.write(`Unknown argument: ${unknown}\n${usage}`);
  process.exit(2);
}
const check = args.includes('--check');
const version = JSON.parse(fs.readFileSync(path.join(root, 'package.json'), 'utf8')).version;

const surfaces = [
  ['skills/godplans/SKILL.md', /^(\s+version:\s*")([0-9]+\.[0-9]+\.[0-9]+)(")/m, () => `${version}`, 1, 3],
  ['skills/godplans/SKILL.md', /^(## Skill version:\s*)([0-9]+\.[0-9]+\.[0-9]+)/m, () => `${version}`, 1, null],
  ['plugins/godplans/.claude-plugin/plugin.json', /^(\s+"version":\s*")([0-9]+\.[0-9]+\.[0-9]+)(")/m, () => `${version}`, 1, 3],
  ['.claude-plugin/marketplace.json', /^(\s+"version":\s*")([0-9]+\.[0-9]+\.[0-9]+)(")/m, () => `${version}`, 1, 3],
  ['README.md', /(version-)([0-9]+\.[0-9]+\.[0-9]+)(-blue)/, () => `${version}`, 1, 3],
  ['skills/godplans/templates/PLAN.template.mdx', /(godplans v)([0-9]+\.[0-9]+\.[0-9]+)/, () => `${version}`, 1, null],
];

const mismatches = [];
for (const [rel, regex, target, pre, post] of surfaces) {
  const file = path.join(root, rel);
  const text = fs.readFileSync(file, 'utf8');
  const match = text.match(regex);
  if (!match) { mismatches.push(`${rel}: no version surface matched ${regex}`); continue; }
  const corrected = `${match[pre]}${target()}${post ? match[post] : ''}`;
  if (match[0] === corrected) continue;
  if (check) mismatches.push(`${rel}: "${match[0]}" should be "${corrected}"`);
  else { fs.writeFileSync(file, text.replace(regex, corrected)); process.stdout.write(`  synced ${rel}: "${match[0]}" -> "${corrected}"\n`); }
}

if (check) {
  if (mismatches.length) {
    process.stderr.write(`Version surfaces are stale:\n  ${mismatches.join('\n  ')}\nTo fix: run \`npm run version:sync\`.\n`);
    process.exitCode = 1;
  } else process.stdout.write(`All version surfaces are ${version}.\n`);
} else if (mismatches.length) {
  process.stderr.write(`Could not sync:\n  ${mismatches.join('\n  ')}\n`);
  process.exitCode = 1;
} else {
  // The metrics hash PROMPT.md and SKILL.md, so they go stale on every bump and
  // must be rebuilt after the prompt, never before it.
  execFileSync('bash', ['scripts/build-prompt.sh'], { cwd: root, stdio: 'inherit' });
  execFileSync('node', ['scripts/context-metrics.js'], { cwd: root, stdio: 'inherit' });
  process.stdout.write(`Version surfaces synced to ${version}; prompt and context metrics regenerated.\n`);
}
