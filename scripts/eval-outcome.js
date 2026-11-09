#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { writeOutcomeSummary } = require('./outcome-summary');

const root = path.resolve(__dirname, '..');
const args = process.argv.slice(2);
const options = {};
for (let index = 0; index < args.length; index++) {
  const key = args[index];
  if (key === '-h' || key === '--help') {
    process.stdout.write('Usage: node scripts/eval-outcome.js --case ID --plan-runner PATH --control-plan-runner PATH --build-runner PATH --audit-runner PATH --output DIR\n');
    process.exit(0);
  }
  if (!key.startsWith('--') || index + 1 >= args.length) throw new Error(`invalid option: ${key}`);
  options[key.slice(2)] = args[++index];
}
for (const key of ['case', 'plan-runner', 'control-plan-runner', 'build-runner', 'audit-runner', 'output']) {
  if (!options[key]) throw new Error(`--${key} is required`);
}

const caseDir = path.join(root, 'evals', 'outcomes', 'cases', options.case);
const output = path.resolve(options.output);
const input = path.join(caseDir, 'INPUT');
const request = path.join(caseDir, 'REQUEST.md');
const verify = path.join(caseDir, 'VERIFY.sh');

// A command that could not run is a fault in the harness, never evidence about
// the build. Any exit status VERIFY.sh itself returns, 126 and 127 included,
// is the verdict on the build: under set -e an `npm test` whose script names a
// tool the build never installed exits 127, and that is a failing build.
class HarnessError extends Error {}

function fail(error) {
  const kind = error instanceof HarnessError ? 'harness error: ' : '';
  process.stderr.write(`eval-outcome: ${kind}${error.message}\n`);
  process.exit(1);
}

try {
  fs.accessSync(request, fs.constants.R_OK);
} catch {
  fail(new HarnessError(`REQUEST.md is not readable: ${request}`));
}
try {
  fs.accessSync(verify, fs.constants.X_OK);
} catch {
  fail(new HarnessError(`VERIFY.sh is not executable: ${verify}`));
}

function executable(file) {
  try {
    fs.accessSync(file, fs.constants.X_OK);
    return fs.statSync(file).isFile();
  } catch {
    return false;
  }
}

// A missing absolute interpreter surfaces as a spawn error, but
// `#!/usr/bin/env NAME` hands the lookup to env, which exits 127 when NAME is
// not on PATH: the same status as a failing command inside VERIFY.sh. Resolve
// the interpreter here, before any arm runs, so that case stays a harness error.
const shebang = fs.readFileSync(verify, 'utf8').split('\n', 1)[0];
if (!shebang.startsWith('#!')) fail(new HarnessError(`VERIFY.sh has no #! interpreter line: ${verify}`));
const [interpreter = '', ...interpreterArgs] = shebang.slice(2).trim().split(/\s+/);
const wanted = path.basename(interpreter) === 'env'
  ? interpreterArgs.find((arg) => !arg.startsWith('-') && !arg.includes('='))
  : interpreter;
const resolvable = Boolean(wanted) && (wanted.includes('/')
  ? executable(wanted)
  : (process.env.PATH || '').split(path.delimiter).some((dir) => executable(path.join(dir || '.', wanted))));
if (!resolvable) fail(new HarnessError(`VERIFY.sh interpreter ${wanted || '(none)'} cannot run: ${verify}`));

for (const key of ['plan-runner', 'control-plan-runner', 'build-runner', 'audit-runner']) {
  options[key] = path.resolve(options[key]);
  fs.accessSync(options[key], fs.constants.X_OK);
}

// spawnSync runs no shell, so a command that cannot start at all (missing,
// not executable, a bad #! line) arrives as result.error, and a signal leaves
// status null. Both are harness errors for every command. Returns the status.
function spawn(command, commandArgs, stdoutFile) {
  const settings = { cwd: root, stdio: stdoutFile ? ['ignore', 'pipe', 'inherit'] : 'inherit' };
  const result = spawnSync(command, commandArgs, settings);
  if (stdoutFile && result.stdout) fs.writeFileSync(stdoutFile, result.stdout);
  const name = path.basename(command);
  if (result.error) throw new HarnessError(`${name} could not start: ${result.error.message}`);
  if (result.status === null) throw new HarnessError(`${name} was stopped by ${result.signal}`);
  return result.status;
}

// The plan, build, and audit runners are harness machinery: any failure stops
// the run, and 126/127 (a command the runner needs is missing) is named as a
// harness error.
function runStep(command, commandArgs) {
  const status = spawn(command, commandArgs);
  const name = path.basename(command);
  if (status === 126 || status === 127) {
    throw new HarnessError(`${name} could not execute a command (exit ${status})`);
  }
  if (status !== 0) throw new Error(`${name} exited ${status}`);
}

const arms = {
  treatment: { planRunner: options['plan-runner'] },
  control: { planRunner: options['control-plan-runner'] },
};
fs.mkdirSync(output, { recursive: true });
// A same-day rerun reuses the date-named output directory. A summary left by
// an earlier run must not stand beside this run's arms if this run fails.
fs.rmSync(path.join(output, 'SUMMARY.json'), { force: true });
fs.rmSync(path.join(output, 'SUMMARY.md'), { force: true });

try {
  for (const [arm, config] of Object.entries(arms)) {
    const armDir = path.join(output, arm);
    const planDir = path.join(armDir, 'plan');
    const buildDir = path.join(armDir, 'build');
    const auditDir = path.join(armDir, 'audit');
    fs.mkdirSync(planDir, { recursive: true });
    runStep(config.planRunner, [request, path.join(planDir, 'PLAN.mdx')]);
    runStep(options['build-runner'], [path.join(planDir, 'PLAN.mdx'), input, buildDir]);
    const verifyLog = path.join(armDir, 'VERIFY.log');
    const verifyPassed = spawn(verify, [path.join(buildDir, 'repository')], verifyLog) === 0;
    fs.mkdirSync(auditDir, { recursive: true });
    runStep(options['audit-runner'], [path.join(buildDir, 'repository'), auditDir]);
    config.verifyPassed = verifyPassed;
  }

  writeOutcomeSummary({
    output,
    caseId: options.case,
    treatmentVerified: arms.treatment.verifyPassed,
    controlVerified: arms.control.verifyPassed,
  });
} catch (error) {
  fail(error);
}
process.stdout.write(`ok   ${output}\n`);
