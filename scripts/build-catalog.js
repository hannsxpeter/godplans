#!/usr/bin/env node
'use strict';

// The validator embeds `my %catalog_max = (...)` and `my %doc_catalog = (...)`
// so it stays a single portable file. Both blocks are DERIVED from the
// reference modules (the second from doc-set.md), not hand-maintained: this
// regenerates them (or verifies them with --check) using the same extraction
// the regression suite uses. Adding a requirement or a catalog row never
// desyncs the validator.
// Maintainer tooling: it lives outside the shipped skill, which never runs it.
// Run: node scripts/build-catalog.js [--check] (npm run catalog, catalog:check)

const fs = require('node:fs');
const path = require('node:path');

const skillRoot = path.resolve(__dirname, '..', 'skills', 'godplans');
const referencesDir = path.join(skillRoot, 'references');
const validatorPath = path.join(skillRoot, 'scripts/validate-plan.sh');
const usage = 'Usage: node scripts/build-catalog.js [--check]\n';
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

// Extraction mirrors tests/validate-plan.sh and the definedPrefixes scan in
// scripts/lint-parity.js: within a `## Plan requirements` section, collect each
// R-<PREFIX>-<N> that starts a line (after an optional list marker and an
// optional **). Ids cited mid-sentence are cross-references to other modules
// and define nothing. Every prefix must be contiguous 1..max.
const seen = {};
for (const file of fs.readdirSync(referencesDir).filter((name) => name.endsWith('.md'))) {
  const lines = fs.readFileSync(path.join(referencesDir, file), 'utf8').split(/\r?\n/);
  let inside = false;
  for (const line of lines) {
    if (/^## Plan requirements\s*$/.test(line)) { inside = true; continue; }
    if (inside && /^## /.test(line)) { inside = false; }
    if (!inside) continue;
    const m = line.match(/^\s*(?:(?:[0-9]+\.|[-*])\s+)?(?:\*\*)?R-([A-Z][A-Z0-9-]*)-([0-9]+)/);
    if (m) (seen[m[1]] ||= new Set()).add(Number(m[2]));
  }
}

const errors = [];
const maxima = {};
for (const prefix of Object.keys(seen)) {
  const numbers = [...seen[prefix]].sort((a, b) => a - b);
  const max = numbers[numbers.length - 1];
  if (numbers.length !== max) errors.push(`${prefix}: gap in requirement ids (have ${numbers.length}, max ${max})`);
  maxima[prefix] = max;
}
if (errors.length) {
  process.stderr.write(`Requirement id gaps:\n  ${errors.join('\n  ')}\n`);
  process.exit(1);
}

// The documentation catalog is the same problem in a second table: the
// validator has to know every catalog id and its owning module, and a
// hand-maintained copy desyncs the first time doc-set.md gains a row.
const docSetPath = path.join(referencesDir, 'doc-set.md');
const documents = {};
const docErrors = [];
for (const line of fs.readFileSync(docSetPath, 'utf8').split(/\r?\n/)) {
  const row = line.match(/^\|\s*`([a-z]+\.[a-z0-9-]+)`\s*\|\s*(durable|evidence|transient)\s*\|\s*([a-z-]+)\s*\|/);
  if (!row) continue;
  const [, id, durability, owner] = row;
  if (documents[id]) docErrors.push(`${id}: duplicate catalog row`);
  documents[id] = `${owner}|${durability}`;
}
if (!Object.keys(documents).length) docErrors.push('doc-set.md: no catalog rows matched');
// The row regex already guarantees a stage and an owner. What it cannot know is
// whether the owner is a domain the validator plans, so read that list from the
// validator itself instead of keeping a second copy here.
const validator = fs.readFileSync(validatorPath, 'utf8');
const domainTable = validator.match(/^my %known_domain\s*=\s*map\s*\{\s*\$_\s*=>\s*1\s*\}\s*qw\(([^)]*)\)\s*;/m);
if (!domainTable) {
  docErrors.push('validate-plan.sh: could not read the %known_domain table');
} else {
  const knownDomains = new Set(domainTable[1].split(/\s+/).filter(Boolean));
  for (const [id, value] of Object.entries(documents)) {
    const owner = value.split('|')[0];
    if (!knownDomains.has(owner)) docErrors.push(`${id}: owner '${owner}' is not a validator domain`);
  }
}
if (docErrors.length) {
  process.stderr.write(`Document catalog problems:\n  ${docErrors.join('\n  ')}\n`);
  process.exit(1);
}

const block = `my %catalog_max = (\n${Object.keys(maxima).sort().map((p) => `    ${p} => ${maxima[p]},`).join('\n')}\n);`;
const docBlock = `my %doc_catalog = (\n${Object.keys(documents).sort().map((id) => `    '${id}' => '${documents[id]}',`).join('\n')}\n);`;
const rebuilt = validator
  .replace(/my %catalog_max = \([^)]*\);/, block)
  .replace(/my %doc_catalog = \([^)]*\);/, docBlock);

if (check) {
  if (validator === rebuilt) {
    process.stdout.write('Validator catalog is fresh.\n');
  } else {
    process.stderr.write('Validator catalog is stale. To fix: run `npm run catalog`.\n');
    process.exitCode = 1;
  }
} else if (validator === rebuilt) {
  process.stdout.write('Validator catalog already fresh.\n');
} else {
  fs.writeFileSync(validatorPath, rebuilt);
  process.stdout.write(`Rewrote %catalog_max (${Object.keys(maxima).length} prefixes) and %doc_catalog (${Object.keys(documents).length} documents) in validate-plan.sh.\n`);
}
