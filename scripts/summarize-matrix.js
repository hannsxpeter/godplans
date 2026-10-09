#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const output = path.resolve(process.argv[2]);
const profiles = process.argv.slice(3);
// The committed roster, not the directory listing, defines the expected cases,
// so a case missing from disk fails here rather than shrinking case_count.
// eval-matrix.sh has already checked that the two agree.
const expectedCases = [...new Set(fs.readFileSync(path.join(root, 'evals', 'cases-roster.txt'), 'utf8')
  .split('\n')
  .map((line) => line.replace(/#.*/, '').trim())
  .filter(Boolean))]
  .sort();

// Only a score counts as an arm. eval.sh also writes marker rows such as
// `FAIL\trunner`, `FAIL\tartifacts`, and `BASE\trunner-error` for a run that
// produced nothing to score, and those must read as a missing arm.
const SCORE = /^[0-9]+\/[0-9]+$/;

function parseEval(file) {
  const cases = {};
  let aggregate = null;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const fields = line.split('\t');
    if (fields[0] === 'AGGREGATE') {
      aggregate = fields.slice(1);
      continue;
    }
    if (!expectedCases.includes(fields[0])) continue;
    cases[fields[0]] ||= {};
    if (!SCORE.test(fields[2] || '')) continue;
    if (fields[1] === 'PASS' || fields[1] === 'FAIL') {
      cases[fields[0]].skill = fields[2];
      cases[fields[0]].status = fields[1];
    } else if (fields[1] === 'BASE') {
      cases[fields[0]].control = fields[2];
      cases[fields[0]].delta = fields[3];
    }
  }
  return { cases, aggregate };
}

function die(message) {
  process.stderr.write(`summarize-matrix: ${message}\n`);
  process.exit(1);
}

const results = {};
for (const profile of profiles) {
  const directory = path.join(output, profile);
  const evalFile = path.join(directory, 'EVAL.tsv');
  const metricsFile = path.join(directory, 'METRICS.json');
  if (!fs.existsSync(evalFile) || !fs.existsSync(metricsFile)) {
    die(`profile ${profile} is missing EVAL.tsv or METRICS.json`);
  }
  const parsed = parseEval(evalFile);
  for (const caseName of expectedCases) {
    const missing = ['skill', 'control'].filter((arm) => !parsed.cases[caseName]?.[arm]);
    if (missing.length) die(`profile ${profile} has no scored ${missing.join(' or ')} arm for ${caseName}`);
  }
  results[profile] = {
    ...parsed,
    metrics: JSON.parse(fs.readFileSync(metricsFile, 'utf8')),
  };
}

const document = {
  format: 'godplans/model-family-matrix@1',
  case_count: expectedCases.length,
  profiles,
  results,
};
fs.writeFileSync(path.join(output, 'MATRIX.json'), `${JSON.stringify(document, null, 2)}\n`);

const lines = [
  '# Full model-family evaluation matrix',
  '',
  `Cases per family: ${expectedCases.length}. Every family includes a godplans arm and a neutral no-skill control arm.`,
  '',
  '| Family | Aggregate | Skill tokens per plan | Control tokens per plan |',
  '|---|---:|---:|---:|',
];
for (const profile of profiles) {
  const result = results[profile];
  lines.push(`| ${profile} | ${result.aggregate?.join('; ') || 'not reported'} | ${result.metrics.arms.skill.tokens_per_plan ?? 'unavailable'} | ${result.metrics.arms.control.tokens_per_plan ?? 'unavailable'} |`);
}
lines.push('', 'Raw PLAN.mdx, PLAN.json, validator, control plan, runner metadata, CLI event logs, and per-family score rows are retained below this directory.', '');
fs.writeFileSync(path.join(output, 'MATRIX.md'), `${lines.join('\n')}\n`);
