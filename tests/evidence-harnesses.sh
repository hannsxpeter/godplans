#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [evidence-harnesses] $*" >&2
  exit 1
}

if grep -R -E '(ANTHROPIC|GEMINI|GOOGLE)_API_[K]EY' \
  "$ROOT/skills" "$ROOT/evals" "$ROOT/scripts" "$ROOT/README.md" "$ROOT/docs" \
  >/dev/null; then
  fail "skill and evaluation surfaces must not require provider key variables"
fi

mkdir -p "$TMP/matrix/codex" "$TMP/bin"
case_count=0
for case_dir in "$ROOT"/evals/cases/*; do
  case_name=$(basename "$case_dir")
  if grep -q '^outcome|plan|' "$case_dir/EXPECTATIONS" && [ "$case_count" -lt 5 ]; then
    mkdir -p "$TMP/matrix/codex/$case_name/baseline"
    printf '%s\n' "# treatment plan for $case_name" > "$TMP/matrix/codex/$case_name/PLAN.mdx"
    printf '%s\n' "# control plan for $case_name" > "$TMP/matrix/codex/$case_name/baseline/PLAN.mdx"
    case_count=$((case_count + 1))
  fi
done
[ "$case_count" -eq 5 ] || fail "could not prepare five external-grade pairs"

for judge in one two; do
  if [ "$judge" = "one" ]; then
    score_a=24
    score_b=18
  else
    score_a=22
    score_b=20
  fi
  printf '%s\n' \
    '#!/usr/bin/env bash' \
    'set -eu' \
    'packet=$(sed -n "s/^# Packet //p" "$1" | head -1)' \
    'node - "$packet" "$2" '"$score_a"' '"$score_b"' <<'"'"'NODE'"'"'' \
    'const fs = require("node:fs");' \
    'const [packet, output, totalA, totalB] = process.argv.slice(2);' \
    'const criteria = ["decision_completeness", "falsifiability", "execution_actionability", "risk_targeting", "proportionality", "internal_consistency"];' \
    'const scores = (total) => { const base = Math.floor(Number(total) / criteria.length); const extra = Number(total) % criteria.length; return Object.fromEntries(criteria.map((key, index) => [key, base + (index < extra ? 1 : 0)])); };' \
    'const grade = { packet_id: packet, plans: [{ label: "A", scores: scores(totalA), total: Number(totalA) }, { label: "B", scores: scores(totalB), total: Number(totalB) }], preference: "A", rationale: "fixture" };' \
    'fs.writeFileSync(output, JSON.stringify(grade));' \
    'NODE' \
    > "$TMP/bin/judge-$judge"
  chmod +x "$TMP/bin/judge-$judge"
done

node "$ROOT/scripts/eval-external.js" \
  --matrix "$TMP/matrix" \
  --source-profile codex \
  --judge "one=$TMP/bin/judge-one" \
  --judge "two=$TMP/bin/judge-two" \
  --output "$TMP/external" >/dev/null

node -e '
  const summary = require(process.argv[1]);
  if (summary.sample_size !== 5) throw new Error("sample size");
  if (summary.mean_absolute_inter_rater_gap !== 2) throw new Error("inter-rater gap");
  if (!summary.judges.one || !summary.judges.two) throw new Error("judge summary");
' "$TMP/external/SUMMARY.json" || fail "external-grade summary is wrong"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'printf "%s\n" "treatment" > "$2"' \
  > "$TMP/bin/plan-treatment"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'printf "%s\n" "control" > "$2"' \
  > "$TMP/bin/plan-control"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'plan=$1' \
  'output=$3' \
  'mkdir -p "$output/repository/test"' \
  'cp "$plan" "$output/repository/arm.txt"' \
  'printf "%s\n" '"'"'{"scripts":{"test":"node --test"}}'"'"' > "$output/repository/package.json"' \
  'printf "%s\n" '"'"'const test = require("node:test"); const assert = require("node:assert"); test("fixture", () => assert.equal(1, 1));'"'"' > "$output/repository/test/fixture.test.js"' \
  > "$TMP/bin/build"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -eu' \
  'repo=$1' \
  'output=$2' \
  'mkdir -p "$output"' \
  'if grep -q control "$repo/arm.txt"; then findings='"'"'[{"severity":"Critical","status":"open"},{"severity":"High","status":"open"}]'"'"'; else findings="[]"; fi' \
  'printf '"'"'{"audit":{"engine_version":"2.11.0","pack_version":"2.11.0"},"findings":%s,"computed":{"verdict":"fixture"}}\n'"'"' "$findings" > "$output/AUDIT.json"' \
  > "$TMP/bin/audit"
chmod +x "$TMP/bin/plan-treatment" "$TMP/bin/plan-control" "$TMP/bin/build" "$TMP/bin/audit"

node "$ROOT/scripts/eval-outcome.js" \
  --case tenant-notes-api \
  --plan-runner "$TMP/bin/plan-treatment" \
  --control-plan-runner "$TMP/bin/plan-control" \
  --build-runner "$TMP/bin/build" \
  --audit-runner "$TMP/bin/audit" \
  --output "$TMP/outcome" >/dev/null

node -e '
  const summary = require(process.argv[1]);
  if (!summary.treatment_better) throw new Error("treatment result");
  if (summary.critical_or_high_delta !== -2) throw new Error("finding delta");
  if (!summary.treatment.verify_passed || !summary.control.verify_passed) throw new Error("verification");
' "$TMP/outcome/SUMMARY.json" || fail "build-outcome summary is wrong"

for verify_script in "$ROOT"/evals/outcomes/cases/*/VERIFY.sh; do
  bash -n "$verify_script" || fail "invalid shell syntax: ${verify_script#"$ROOT"/}"
  [ -x "$verify_script" ] || fail "outcome verifier is not executable: ${verify_script#"$ROOT"/}"
done

# A verifier that cannot run is a harness error, not a build that failed
# verification; any exit status the verifier itself returns is the verdict.
# The probe case lives in a scratch repository so the real outcome cases never
# change mode or content.
OUTCOME_ROOT="$TMP/outcome-repo"
PROBE="$OUTCOME_ROOT/evals/outcomes/cases/probe"
mkdir -p "$OUTCOME_ROOT/scripts" "$PROBE"
cp "$ROOT/scripts/eval-outcome.js" "$ROOT/scripts/outcome-summary.js" "$OUTCOME_ROOT/scripts/"
printf '%s\n' '# probe request' > "$PROBE/REQUEST.md"

run_probe() {
  node "$OUTCOME_ROOT/scripts/eval-outcome.js" \
    --case probe \
    --plan-runner "$TMP/bin/plan-treatment" \
    --control-plan-runner "$TMP/bin/plan-control" \
    --build-runner "$TMP/bin/build" \
    --audit-runner "$TMP/bin/audit" \
    --output "$1"
}

printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$PROBE/VERIFY.sh"
chmod 644 "$PROBE/VERIFY.sh"
if run_probe "$TMP/probe-mode" >/dev/null 2>"$TMP/probe-mode.err"; then
  fail "a non-executable VERIFY.sh was scored as a verification result"
fi
[ ! -e "$TMP/probe-mode/SUMMARY.json" ] || fail "a non-executable VERIFY.sh still produced a summary"
grep -q 'VERIFY.sh is not executable' "$TMP/probe-mode.err" ||
  fail "a non-executable VERIFY.sh was not named: $(cat "$TMP/probe-mode.err")"

# An interpreter the verifier names but the host lacks. Through env it would
# exit 127 like a failing command, so it must be caught before any arm runs.
for shebang in '#!/usr/bin/env godplans-missing-interpreter' '#!/nonexistent/godplans-missing-interpreter'; do
  printf '%s\n' "$shebang" 'exit 0' > "$PROBE/VERIFY.sh"
  chmod 755 "$PROBE/VERIFY.sh"
  rm -rf "$TMP/probe-interpreter"
  if run_probe "$TMP/probe-interpreter" >/dev/null 2>"$TMP/probe-interpreter.err"; then
    fail "a verifier whose interpreter is missing was scored ($shebang)"
  fi
  [ ! -e "$TMP/probe-interpreter/treatment" ] || fail "arms ran before the missing interpreter was caught ($shebang)"
  grep -q 'harness error: VERIFY.sh interpreter' "$TMP/probe-interpreter.err" ||
    fail "a missing verifier interpreter was not a harness error: $(cat "$TMP/probe-interpreter.err")"
done

# A command inside the verifier that the build never installed exits 127.
# That is the build failing verification, not a harness fault.
printf '%s\n' '#!/usr/bin/env bash' 'set -eu' 'godplans-missing-verifier-command' > "$PROBE/VERIFY.sh"
run_probe "$TMP/probe-missing" >/dev/null 2>"$TMP/probe-missing.err" ||
  fail "an exit 127 inside the verifier stopped the harness: $(cat "$TMP/probe-missing.err")"
node -e '
  const summary = require(process.argv[1]);
  if (summary.treatment.verify_passed || summary.control.verify_passed) throw new Error("verification");
' "$TMP/probe-missing/SUMMARY.json" || fail "an exit 127 inside the verifier was not recorded as a failed verification"

printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$PROBE/VERIFY.sh"
run_probe "$TMP/probe-fail" >/dev/null 2>&1 || fail "an ordinary verification failure stopped the harness"
node -e '
  const summary = require(process.argv[1]);
  if (summary.treatment.verify_passed || summary.control.verify_passed) throw new Error("verification");
' "$TMP/probe-fail/SUMMARY.json" || fail "an ordinary verification failure was not recorded"

# A verifier stopped by a signal is a harness error. Rerunning into a directory
# that already holds a summary must not leave that stale summary behind.
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$PROBE/VERIFY.sh"
run_probe "$TMP/probe-rerun" >/dev/null 2>&1 || fail "a passing probe run failed"
[ -f "$TMP/probe-rerun/SUMMARY.json" ] || fail "a passing probe run wrote no summary"
printf '%s\n' '#!/usr/bin/env bash' 'kill -TERM $$' > "$PROBE/VERIFY.sh"
if run_probe "$TMP/probe-rerun" >/dev/null 2>"$TMP/probe-rerun.err"; then
  fail "a verifier stopped by a signal was scored as a verification result"
fi
grep -q 'harness error: VERIFY.sh was stopped by SIGTERM' "$TMP/probe-rerun.err" ||
  fail "a signalled verifier was not a harness error: $(cat "$TMP/probe-rerun.err")"
[ ! -e "$TMP/probe-rerun/SUMMARY.json" ] || fail "a failed rerun left the earlier SUMMARY.json in place"

echo "ok   [evidence-harnesses]"
