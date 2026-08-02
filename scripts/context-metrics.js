#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const output = path.join(root, 'evals', 'metrics', 'context-cost.json');
const check = process.argv.includes('--check');
const references = path.join(root, 'skills', 'godplans', 'references');

const coreModules = [
  'compliance',
  'discovery',
  'product',
  'architecture',
  'stack',
  'database',
  'security',
  'exemplar',
  'plan-format',
];
const lazyModules = [
  'doc-set',
  'llm',
  'ux',
  'ui',
  'seo',
  'code-quality',
  'style-genome',
  'agent-memory',
  'repo',
  'build',
  'roadmap',
  'deploy',
  'observe',
  'launch',
];

function measure(file) {
  const bytes = fs.readFileSync(file);
  return {
    bytes: bytes.length,
    estimated_tokens: Math.ceil(bytes.length / 4),
    sha256: crypto.createHash('sha256').update(bytes).digest('hex'),
  };
}

function moduleMeasurements(names) {
  return Object.fromEntries(names.map((name) => [
    name,
    measure(path.join(references, `${name}.md`)),
  ]));
}

function sum(measurements) {
  return Object.values(measurements).reduce((total, value) => ({
    bytes: total.bytes + value.bytes,
    estimated_tokens: total.estimated_tokens + value.estimated_tokens,
  }), { bytes: 0, estimated_tokens: 0 });
}

const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'godplans-context-'));
const fullPrompt = path.join(temporary, 'PROMPT.full.md');
try {
  execFileSync('bash', ['scripts/build-prompt.sh', '--full', '--output', fullPrompt], {
    cwd: root,
    stdio: 'ignore',
  });

  const core = moduleMeasurements(coreModules);
  const lazy = moduleMeasurements(lazyModules);
  const document = {
    format: 'godplans/context-cost@1',
    estimate: {
      method: 'ceil(raw_utf8_bytes / 4)',
      limitation: 'Provider tokenizers differ. Published model runs record actual input and output token usage in RUNNER.txt and METRICS.json.',
    },
    portable_core: measure(path.join(root, 'PROMPT.md')),
    portable_full_generated: measure(fullPrompt),
    native_skill_entry: measure(path.join(root, 'skills', 'godplans', 'SKILL.md')),
    core_modules: core,
    core_modules_total: sum(core),
    lazy_modules: lazy,
    lazy_modules_total: sum(lazy),
  };
  const serialized = `${JSON.stringify(document, null, 2)}\n`;

  if (check) {
    if (!fs.existsSync(output) || fs.readFileSync(output, 'utf8') !== serialized) {
      process.stderr.write('Context metrics are stale. Run `npm run metrics:context`.\n');
      process.exitCode = 1;
    } else {
      process.stdout.write('Context metrics are current.\n');
    }
  } else {
    fs.mkdirSync(path.dirname(output), { recursive: true });
    fs.writeFileSync(output, serialized);
    process.stdout.write(`Wrote ${path.relative(root, output)}.\n`);
  }
} finally {
  fs.rmSync(temporary, { recursive: true, force: true });
}
