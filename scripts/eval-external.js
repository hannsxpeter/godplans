#!/usr/bin/env node
'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
let matrix;
let output;
let sourceProfile = 'codex';
let sample = 5;
const judges = [];

function take(flag, index) {
  if (index + 1 >= args.length) throw new Error(`${flag} needs a value`);
  return args[index + 1];
}

for (let index = 0; index < args.length; index++) {
  switch (args[index]) {
    case '--matrix': matrix = path.resolve(take('--matrix', index++)); break;
    case '--output': output = path.resolve(take('--output', index++)); break;
    case '--source-profile': sourceProfile = take('--source-profile', index++); break;
    case '--sample': sample = Number(take('--sample', index++)); break;
    case '--judge': {
      const value = take('--judge', index++);
      const separator = value.indexOf('=');
      if (separator < 1) throw new Error('--judge uses LABEL=RUNNER, where RUNNER is a relative or absolute path');
      // The label names the judge's grade directory, so it must be one safe
      // path segment, and a repeated label would grade one judge against itself.
      const label = value.slice(0, separator);
      if (!/^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(label)) throw new Error(`invalid judge label: ${label}`);
      if (judges.some((judge) => judge.label === label)) throw new Error(`duplicate judge label: ${label}`);
      judges.push({ label, runner: path.resolve(value.slice(separator + 1)) });
      break;
    }
    case '-h':
    case '--help':
      process.stdout.write('Usage: node scripts/eval-external.js --matrix DIR --output DIR --judge LABEL=RUNNER --judge LABEL=RUNNER [--source-profile NAME] [--sample 5]\n');
      process.exit(0);
    default: throw new Error(`unknown option: ${args[index]}`);
  }
}

if (!matrix || !output) throw new Error('--matrix and --output are required');
if (!Number.isInteger(sample) || sample < 5) throw new Error('--sample must be at least 5');
if (judges.length < 2) throw new Error('at least two external judges are required for an inter-rater gap');
for (const judge of judges) {
  fs.accessSync(judge.runner, fs.constants.X_OK);
}

const source = path.join(matrix, sourceProfile);
const caseRoot = path.join(root, 'evals', 'cases');
const candidates = fs.readdirSync(source, { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name)
  .filter((name) => fs.existsSync(path.join(source, name, 'PLAN.mdx'))
    && fs.existsSync(path.join(source, name, 'baseline', 'PLAN.mdx')))
  .sort()
  .slice(0, sample);
if (candidates.length < sample) {
  throw new Error(`source profile has only ${candidates.length} complete plan pairs, need ${sample}`);
}

const rubric = fs.readFileSync(path.join(root, 'evals', 'external', 'RUBRIC.md'), 'utf8');
// Every judge reads the grade shape from its packet, so a judge whose CLI
// cannot enforce a JSON schema gets the same contract as one that can.
const gradeSchema = fs.readFileSync(path.join(root, 'evals', 'external', 'GRADE.schema.json'), 'utf8');
const packetDir = path.join(output, 'packets');
const gradeDir = path.join(output, 'grades');
fs.mkdirSync(packetDir, { recursive: true });
fs.mkdirSync(gradeDir, { recursive: true });

const blinding = {};
for (const caseName of candidates) {
  const swap = parseInt(crypto.createHash('sha256').update(caseName).digest('hex').slice(0, 2), 16) % 2 === 1;
  const treatment = fs.readFileSync(path.join(source, caseName, 'PLAN.mdx'), 'utf8');
  const control = fs.readFileSync(path.join(source, caseName, 'baseline', 'PLAN.mdx'), 'utf8');
  const brief = fs.readFileSync(path.join(caseRoot, caseName, 'REQUEST.baseline.md'), 'utf8');
  const plans = swap ? { A: control, B: treatment } : { A: treatment, B: control };
  blinding[caseName] = swap ? { A: 'control', B: 'treatment' } : { A: 'treatment', B: 'control' };
  const packet = [
    `# Packet ${caseName}`,
    '',
    '## Project brief',
    '',
    brief.trim(),
    '',
    rubric.trim(),
    '',
    '## Required JSON',
    '',
    'Return one JSON object that validates against this schema. The criterion keys are decision_completeness, falsifiability, execution_actionability, risk_targeting, proportionality, and internal_consistency; total is their sum.',
    '',
    '```json',
    gradeSchema.trim(),
    '```',
    '',
    '## Plan A',
    '',
    plans.A.trim(),
    '',
    '## Plan B',
    '',
    plans.B.trim(),
    '',
    `Set packet_id to "${caseName}".`,
    '',
  ].join('\n');
  fs.writeFileSync(path.join(packetDir, `${caseName}.md`), packet);
}

for (const judge of judges) {
  const judgeDir = path.join(gradeDir, judge.label);
  fs.mkdirSync(judgeDir, { recursive: true });
  for (const caseName of candidates) {
    const grade = path.join(judgeDir, `${caseName}.json`);
    const result = spawnSync(judge.runner, [path.join(packetDir, `${caseName}.md`), grade], {
      cwd: root,
      stdio: 'inherit',
    });
    if (result.status !== 0) throw new Error(`judge ${judge.label} failed on ${caseName}`);
  }
}

const criteria = ['decision_completeness', 'falsifiability', 'execution_actionability', 'risk_targeting', 'proportionality', 'internal_consistency'];
const raw = {};
for (const judge of judges) {
  raw[judge.label] = {};
  for (const caseName of candidates) {
    const file = path.join(gradeDir, judge.label, `${caseName}.json`);
    const grade = JSON.parse(fs.readFileSync(file, 'utf8'));
    if (grade.packet_id !== caseName || !Array.isArray(grade.plans) || grade.plans.length !== 2) {
      throw new Error(`invalid grade shape: ${file}`);
    }
    const labels = new Set();
    for (const plan of grade.plans) {
      if (!['A', 'B'].includes(plan.label) || labels.has(plan.label)) throw new Error(`invalid plan labels: ${file}`);
      labels.add(plan.label);
      let total = 0;
      for (const criterion of criteria) {
        const score = plan.scores?.[criterion];
        if (!Number.isInteger(score) || score < 1 || score > 5) throw new Error(`invalid ${criterion}: ${file}`);
        total += score;
      }
      if (plan.total !== total) throw new Error(`total does not match criterion scores: ${file}`);
    }
    if (!['A', 'B', 'tie'].includes(grade.preference) || typeof grade.rationale !== 'string' || !grade.rationale.trim()) {
      throw new Error(`invalid preference or rationale: ${file}`);
    }
    raw[judge.label][caseName] = grade;
  }
}

const judgeSummary = {};
for (const judge of judges) {
  let treatment = 0;
  let control = 0;
  let treatmentPreferences = 0;
  let controlPreferences = 0;
  let ties = 0;
  for (const caseName of candidates) {
    const grade = raw[judge.label][caseName];
    const byLabel = Object.fromEntries(grade.plans.map((plan) => [plan.label, plan]));
    for (const label of ['A', 'B']) {
      if (blinding[caseName][label] === 'treatment') treatment += byLabel[label].total;
      else control += byLabel[label].total;
    }
    if (grade.preference === 'tie') ties++;
    else if (blinding[caseName][grade.preference] === 'treatment') treatmentPreferences++;
    else controlPreferences++;
  }
  judgeSummary[judge.label] = {
    treatment_mean: treatment / candidates.length,
    control_mean: control / candidates.length,
    mean_delta: (treatment - control) / candidates.length,
    preferences: { treatment: treatmentPreferences, control: controlPreferences, tie: ties },
  };
}

let gapTotal = 0;
let gapCount = 0;
for (let left = 0; left < judges.length; left++) {
  for (let right = left + 1; right < judges.length; right++) {
    for (const caseName of candidates) {
      const leftPlans = Object.fromEntries(raw[judges[left].label][caseName].plans.map((plan) => [plan.label, plan.total]));
      const rightPlans = Object.fromEntries(raw[judges[right].label][caseName].plans.map((plan) => [plan.label, plan.total]));
      for (const label of ['A', 'B']) {
        gapTotal += Math.abs(leftPlans[label] - rightPlans[label]);
        gapCount++;
      }
    }
  }
}

const summary = {
  format: 'godplans/external-grade@1',
  source_profile: sourceProfile,
  sample_size: candidates.length,
  judges: judgeSummary,
  mean_absolute_inter_rater_gap: gapCount ? gapTotal / gapCount : null,
  cases: candidates,
};
fs.writeFileSync(path.join(output, 'BLINDING.json'), `${JSON.stringify(blinding, null, 2)}\n`);
fs.writeFileSync(path.join(output, 'SUMMARY.json'), `${JSON.stringify(summary, null, 2)}\n`);

const lines = [
  '# Blind external grading summary',
  '',
  `Sample: ${candidates.length} plan pairs. Mean absolute inter-rater gap: ${summary.mean_absolute_inter_rater_gap.toFixed(2)} points on a 30-point scale.`,
  '',
  '| Judge | Treatment mean | Control mean | Delta | Preferences (treatment/control/tie) |',
  '|---|---:|---:|---:|---:|',
];
for (const judge of judges) {
  const result = judgeSummary[judge.label];
  lines.push(`| ${judge.label} | ${result.treatment_mean.toFixed(2)} | ${result.control_mean.toFixed(2)} | ${result.mean_delta.toFixed(2)} | ${result.preferences.treatment}/${result.preferences.control}/${result.preferences.tie} |`);
}
lines.push('', 'Raw packets and grades are retained beside this summary. The blinding map was applied only after every grade existed.', '');
fs.writeFileSync(path.join(output, 'SUMMARY.md'), `${lines.join('\n')}\n`);
process.stdout.write(`ok   ${output}\n`);
