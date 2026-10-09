#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');

const usage = 'Usage: node scripts/summarize-eval.js [OUTPUT_DIR]  (default evals/output)\n';
const arg = process.argv[2];
if (arg === '-h' || arg === '--help') {
  process.stdout.write(usage);
  process.exit(0);
}
if ((arg && arg.startsWith('-')) || process.argv.length > 3) {
  process.stderr.write(usage);
  process.exit(2);
}
const output = path.resolve(arg || 'evals/output');

function runnerMetadata(file) {
  if (!fs.existsSync(file)) return {};
  const entries = {};
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const index = line.indexOf('=');
    if (index < 1) continue;
    entries[line.slice(0, index)] = line.slice(index + 1);
  }
  return entries;
}

function armSummary(records) {
  const numeric = ['input_tokens', 'cached_input_tokens', 'output_tokens', 'total_tokens'];
  const totals = Object.fromEntries(numeric.map((key) => [key, 0]));
  let measuredRuns = 0;
  for (const record of records) {
    if (record.usage_source === 'unavailable' || record.total_tokens === undefined) continue;
    measuredRuns++;
    for (const key of numeric) totals[key] += Number(record[key] || 0);
  }
  return {
    runs: records.length,
    measured_runs: measuredRuns,
    plan_runs: records.filter((record) => record.outcome === 'plan').length,
    totals,
    tokens_per_plan: records.filter((record) => record.outcome === 'plan' && record.total_tokens !== undefined).length
      ? Math.round(records
        .filter((record) => record.outcome === 'plan' && record.total_tokens !== undefined)
        .reduce((sum, record) => sum + Number(record.total_tokens || 0), 0)
        / records.filter((record) => record.outcome === 'plan' && record.total_tokens !== undefined).length)
      : null,
  };
}

const skill = [];
const control = [];
if (fs.existsSync(output)) {
  for (const entry of fs.readdirSync(output, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const caseDir = path.join(output, entry.name);
    const outcome = fs.existsSync(path.join(caseDir, 'PLAN.mdx')) ? 'plan' : 'refusal';
    skill.push({
      case: entry.name,
      outcome,
      ...runnerMetadata(path.join(caseDir, 'RUNNER.txt')),
    });
    const baseline = path.join(caseDir, 'baseline');
    if (fs.existsSync(baseline)) {
      control.push({
        case: entry.name,
        outcome,
        ...runnerMetadata(path.join(baseline, 'RUNNER.txt')),
      });
    }
  }
}

const document = {
  format: 'godplans/eval-metrics@1',
  output,
  arms: {
    skill: armSummary(skill),
    control: armSummary(control),
  },
  runs: {
    skill,
    control,
  },
};

fs.mkdirSync(output, { recursive: true });
fs.writeFileSync(path.join(output, 'METRICS.json'), `${JSON.stringify(document, null, 2)}\n`);
process.stdout.write(`METRICS\t${path.join(output, 'METRICS.json')}\n`);
