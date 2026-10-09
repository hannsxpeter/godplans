#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [eval-harness] $*" >&2
  exit 1
}

test -x "$ROOT/scripts/eval.sh" || fail "scripts/eval.sh is not executable"
test -x "$ROOT/evals/runners/codex.sh" || fail "Codex runner is not executable"

# Global-skill isolation. A machine that runs these evals almost always has
# godplans installed globally (in ~/.codex/skills and ~/.agents/skills), which
# Codex discovers regardless of the workspace. Without isolation, BOTH arms
# load the skill and the control measures godplans against itself. Both Codex
# runners must isolate HOME and CODEX_HOME; only the skill runner may link the
# project-local skill.
for codex_runner in codex codex-baseline; do
  runner_path="$ROOT/evals/runners/$codex_runner.sh"
  bash -n "$runner_path"
  grep -q 'HOME="\$ISO_HOME" CODEX_HOME="\$ISO_CODEX_HOME" codex' "$runner_path" \
    || fail "$codex_runner.sh does not isolate HOME and CODEX_HOME from global skills"
done
grep -q 'ln -s' "$ROOT/evals/runners/codex.sh" || fail "skill runner no longer links the project skill"
if grep -q 'ln -s' "$ROOT/evals/runners/codex-baseline.sh"; then
  fail "baseline runner links a skill into its workspace"
fi

# Neutral control request. The baseline runner must prefer REQUEST.baseline.md
# and must not hand the control the skill's own output path.
grep -q 'REQUEST.baseline.md' "$ROOT/evals/runners/codex-baseline.sh" \
  || fail "baseline runner does not prefer REQUEST.baseline.md"
# The prompt handed to the control (the printf preamble lines) must not name
# the skill's output path. The candidate-search loop may still accept a plan
# the control writes to .godplans/, so scope this to printf lines; that loop's
# preference for PLAN.md over an unchanged INPUT fixture is exercised in
# tests/codex-runner.sh and tests/vendor-runner.sh.
if grep -E "printf.*\.godplans" "$ROOT/evals/runners/codex-baseline.sh"; then
  fail "baseline runner names a .godplans path in the prompt handed to the control"
fi
for case_dir in "$ROOT"/evals/cases/*/; do
  base_request="$case_dir/REQUEST.baseline.md"
  [ -f "$base_request" ] || fail "case $(basename "$case_dir") is missing REQUEST.baseline.md for the control arm"
  if grep -Eiq 'godplans|\.godplans|SKILL\.md|PLAN\.mdx|validator companion' "$base_request"; then
    fail "REQUEST.baseline.md leaks the skill in $(basename "$case_dir")"
  fi
done

help_output=$("$ROOT/scripts/eval.sh" --help)
printf '%s\n' "$help_output" | grep -q '^Usage:' || fail "help is missing a Usage line"
if printf '%s\n' "$help_output" | grep -q 'set -euo pipefail'; then
  fail "help leaked shell implementation"
fi

"$ROOT/scripts/eval.sh" --check-cases >/dev/null
"$ROOT/scripts/eval-matrix.sh" --check >/dev/null

mkdir -p "$TMP/cases/plan-case" "$TMP/cases/refusal-case" "$TMP/bin"

printf '%s\n' '# plan request' > "$TMP/cases/plan-case/REQUEST.md"
printf '%s\n' \
  'outcome|plan|' \
  'frontmatter|mode|greenfield' \
  'frontmatter|archetype|cli-tool' \
  'domain|security|applicable' \
  'contains|GP-101|' \
  'gate|prepublication|fresh-prepublication' \
  'not-contains|PLACEHOLDER|' \
  'max-count|## Open Questions|1' \
  > "$TMP/cases/plan-case/EXPECTATIONS"

printf '%s\n' '# refusal request' > "$TMP/cases/refusal-case/REQUEST.md"
printf '%s\n' \
  'outcome|refusal|' \
  'contains-ci|Usage Policy|' \
  'not-contains|GP-101|' \
  > "$TMP/cases/refusal-case/EXPECTATIONS"

printf '%s\n' 'Produce PLAN.mdx only.' > "$TMP/cases/plan-case/REQUEST.md"
if GODPLANS_EVAL_CASES="$TMP/cases" "$ROOT/scripts/eval.sh" --check-cases >/dev/null 2>&1; then
  fail "plan-only request contradicted the companion artifact contract"
fi
printf '%s\n' '# plan request' > "$TMP/cases/plan-case/REQUEST.md"

cp -R "$TMP/cases" "$TMP/cases with space"
if ! GODPLANS_EVAL_CASES="$TMP/cases with space" "$ROOT/scripts/eval.sh" --check-cases >/dev/null 2>&1; then
  fail "case validation failed when the case path contained spaces"
fi

printf '%s\n' '#!/usr/bin/env sh' \
  'set -eu' \
  'case "$1" in' \
  '  */plan-case/REQUEST.md)' \
  '    cp "$GODPLANS_TEST_PLAN" "$2"' \
  '    cp "$GODPLANS_TEST_VALIDATOR" "$(dirname "$2")/validate-plan.sh"' \
  '    cp "$GODPLANS_TEST_SIDECAR" "$(dirname "$2")/PLAN.json"' \
  '    chmod +x "$(dirname "$2")/validate-plan.sh"' \
  '    ;;' \
  '  */refusal-case/REQUEST.md)' \
  '    printf "%s\n" "Refused under the usage policy." > "$2"' \
  '    ;;' \
  '  *) exit 9 ;;' \
  'esac' \
  > "$TMP/bin/runner"
chmod +x "$TMP/bin/runner"

printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$TMP/bin/validator"
chmod +x "$TMP/bin/validator"

printf '%s\n' \
  '---' \
  'name: example' \
  'status: planning' \
  'mode: greenfield' \
  'archetype: cli-tool' \
  '---' \
  '| security | applicable | scaled baseline |' \
  'fresh-prepublication' \
  '- [ ] GP-101 [W1.1] Example task' \
  '## Open Questions' \
  > "$TMP/PLAN.mdx"

node -e '
  const fs = require("node:fs");
  const crypto = require("node:crypto");
  const plan = fs.readFileSync(process.argv[1]);
  fs.writeFileSync(process.argv[2], JSON.stringify({
    format: "godplans/plan-json@2",
    plan_digest: "sha256:" + crypto.createHash("sha256").update(plan).digest("hex")
  }));
' "$TMP/PLAN.mdx" "$TMP/PLAN.json"

GODPLANS_EVAL_CASES="$TMP/cases" \
GODPLANS_EVAL_RUNNER="$TMP/bin/runner" \
GODPLANS_VALIDATOR="$TMP/bin/validator" \
GODPLANS_TEST_PLAN="$TMP/PLAN.mdx" \
GODPLANS_TEST_VALIDATOR="$TMP/bin/validator" \
GODPLANS_TEST_SIDECAR="$TMP/PLAN.json" \
  "$ROOT/scripts/eval.sh" --output "$TMP/output" > "$TMP/run.out"

grep -q '^plan-case[[:space:]]PASS[[:space:]]8/8$' "$TMP/run.out" || fail "plan case did not pass all expectations"
grep -q '^refusal-case[[:space:]]PASS[[:space:]]3/3$' "$TMP/run.out" || fail "refusal case did not pass all expectations"
test -f "$TMP/output/plan-case/PLAN.mdx" || fail "plan output was not retained"
test -f "$TMP/output/plan-case/PLAN.json" || fail "plan sidecar was not retained"
test -f "$TMP/output/refusal-case/RESPONSE.md" || fail "refusal output was not retained"

GODPLANS_EVAL_CASES="$TMP/cases" \
GODPLANS_VALIDATOR="$TMP/bin/validator" \
  "$ROOT/scripts/eval.sh" --score-only --output "$TMP/output" > "$TMP/rescore.out"
grep -q '^plan-case[[:space:]]PASS[[:space:]]8/8$' "$TMP/rescore.out" || fail "saved plan did not rescore"
grep -q '^refusal-case[[:space:]]PASS[[:space:]]3/3$' "$TMP/rescore.out" || fail "saved refusal did not rescore"

rm "$TMP/output/plan-case/validate-plan.sh"
if GODPLANS_EVAL_CASES="$TMP/cases" GODPLANS_VALIDATOR="$TMP/bin/validator" \
  "$ROOT/scripts/eval.sh" --score-only --output "$TMP/output" >/dev/null 2>&1; then
  fail "score-only accepted a missing validator companion"
fi

cp "$TMP/bin/validator" "$TMP/output/plan-case/validate-plan.sh"
chmod +x "$TMP/output/plan-case/validate-plan.sh"
perl -0pi -e 's/fresh-prepublication/stale-prepublication/' "$TMP/output/plan-case/PLAN.mdx"
if GODPLANS_EVAL_CASES="$TMP/cases" GODPLANS_VALIDATOR="$TMP/bin/validator" \
  "$ROOT/scripts/eval.sh" --score-only --output "$TMP/output" >/dev/null 2>&1; then
  fail "score-only accepted a violated gate invariant"
fi

printf '%s\n' 'outcome|unknown|' > "$TMP/cases/plan-case/EXPECTATIONS"
if GODPLANS_EVAL_CASES="$TMP/cases" "$ROOT/scripts/eval.sh" --check-cases >/dev/null 2>&1; then
  fail "invalid expectation operation was accepted"
fi

# Control arm. Restore the manifest mutated above and run both arms into a
# fresh output directory so no earlier mutation leaks into the comparison.
printf '%s\n' \
  'outcome|plan|' \
  'frontmatter|mode|greenfield' \
  'frontmatter|archetype|cli-tool' \
  'domain|security|applicable' \
  'contains|GP-101|' \
  'gate|prepublication|fresh-prepublication' \
  'not-contains|PLACEHOLDER|' \
  'max-count|## Open Questions|1' \
  > "$TMP/cases/plan-case/EXPECTATIONS"

if GODPLANS_EVAL_CASES="$TMP/cases" GODPLANS_EVAL_RUNNER="$TMP/bin/runner" \
  "$ROOT/scripts/eval.sh" --baseline --output "$TMP/base-output" >/dev/null 2>&1; then
  fail "--baseline ran without a baseline runner"
fi

if GODPLANS_EVAL_CASES="$TMP/cases" GODPLANS_EVAL_RUNNER="$TMP/bin/runner" \
  GODPLANS_EVAL_BASELINE_RUNNER="$TMP/bin/runner" \
  "$ROOT/scripts/eval.sh" --baseline --output "$TMP/base-output" >/dev/null 2>&1; then
  fail "--baseline accepted the skill runner as its own control"
fi

# A weak control: it answers, but produces none of the plan structure.
printf '%s\n' '#!/usr/bin/env sh' \
  'set -eu' \
  'printf "%s\n" "An unaided answer with no plan structure." > "$2"' \
  > "$TMP/bin/baseline-runner"
chmod +x "$TMP/bin/baseline-runner"

GODPLANS_EVAL_CASES="$TMP/cases" \
GODPLANS_EVAL_RUNNER="$TMP/bin/runner" \
GODPLANS_EVAL_BASELINE_RUNNER="$TMP/bin/baseline-runner" \
GODPLANS_VALIDATOR="$TMP/bin/validator" \
GODPLANS_TEST_PLAN="$TMP/PLAN.mdx" \
GODPLANS_TEST_VALIDATOR="$TMP/bin/validator" \
GODPLANS_TEST_SIDECAR="$TMP/PLAN.json" \
  "$ROOT/scripts/eval.sh" --baseline --output "$TMP/base-output" > "$TMP/baseline.out" 2> "$TMP/baseline.err" \
  || fail "the control arm changed the exit code"

grep -q '^plan-case[[:space:]]PASS[[:space:]]8/8$' "$TMP/baseline.out" || fail "skill arm regressed under --baseline"
grep -q '^plan-case[[:space:]]BASE[[:space:]]' "$TMP/baseline.out" || fail "no control row for the plan case"
grep -q '^AGGREGATE[[:space:]]' "$TMP/baseline.out" || fail "no aggregate row"
grep -q 'delta +' "$TMP/baseline.out" || fail "no delta reported"
test -f "$TMP/base-output/plan-case/baseline/PLAN.mdx" || fail "control artifact was not retained"
if grep -q '^plan-case[[:space:]]MISS' "$TMP/baseline.err"; then
  fail "control misses were reported as skill-arm misses"
fi

# A final EXPECTATIONS line with no trailing newline is still an assertion,
# both when the manifest is validated and when an artifact is scored.
mkdir -p "$TMP/eof-cases/eof-case" "$TMP/eof-output/eof-case"
printf '%s\n' '# refusal request' > "$TMP/eof-cases/eof-case/REQUEST.md"
printf 'contains|Refused|\noutcome|refusal|' > "$TMP/eof-cases/eof-case/EXPECTATIONS"
GODPLANS_EVAL_CASES="$TMP/eof-cases" "$ROOT/scripts/eval.sh" --check-cases >/dev/null 2>&1 ||
  fail "an outcome line without a trailing newline was not read"
printf 'outcome|refusal|\ncontains|MUST-APPEAR|' > "$TMP/eof-cases/eof-case/EXPECTATIONS"
printf '%s\n' 'Refused under the usage policy.' > "$TMP/eof-output/eof-case/RESPONSE.md"
if GODPLANS_EVAL_CASES="$TMP/eof-cases" GODPLANS_VALIDATOR="$TMP/bin/validator" \
  "$ROOT/scripts/eval.sh" --score-only --output "$TMP/eof-output" >"$TMP/eof.out" 2>"$TMP/eof.err"; then
  fail "score-only dropped a final expectation that had no trailing newline"
fi
grep -q '^eof-case[[:space:]]FAIL[[:space:]]1/2$' "$TMP/eof.out" ||
  fail "the unterminated final expectation was not scored"
grep -q '^eof-case[[:space:]]MISS[[:space:]]contains|MUST-APPEAR|$' "$TMP/eof.err" ||
  fail "the unterminated final expectation was not reported as a miss"

# A control that beats the skill arm reports a signed negative delta, never "+-N".
mkdir -p "$TMP/delta-cases/control-wins"
printf '%s\n' '# refusal request' > "$TMP/delta-cases/control-wins/REQUEST.md"
printf '%s\n' 'outcome|refusal|' 'contains|CONTROL-ONLY|' > "$TMP/delta-cases/control-wins/EXPECTATIONS"
printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\n" "skill answer" > "$2"' > "$TMP/bin/weak-skill"
printf '%s\n' '#!/usr/bin/env sh' 'printf "%s\n" "CONTROL-ONLY answer" > "$2"' > "$TMP/bin/strong-control"
chmod +x "$TMP/bin/weak-skill" "$TMP/bin/strong-control"
if GODPLANS_EVAL_CASES="$TMP/delta-cases" \
  GODPLANS_EVAL_RUNNER="$TMP/bin/weak-skill" \
  GODPLANS_EVAL_BASELINE_RUNNER="$TMP/bin/strong-control" \
  GODPLANS_VALIDATOR="$TMP/bin/validator" \
  "$ROOT/scripts/eval.sh" --baseline --output "$TMP/delta-output" >"$TMP/delta.out" 2>/dev/null; then
  fail "a failing skill arm exited zero"
fi
grep -q '^control-wins[[:space:]]BASE[[:space:]]2/2[[:space:]]delta -1$' "$TMP/delta.out" ||
  fail "a negative per-case delta was not reported as -1"
grep -q '^AGGREGATE[[:space:]]skill 1/2[[:space:]]baseline 2/2[[:space:]]delta -1$' "$TMP/delta.out" ||
  fail "a negative aggregate delta was not reported as -1"
if grep -q 'delta +-' "$TMP/delta.out"; then
  fail "a negative delta carried a plus sign"
fi

# The matrix coordinator runs against a scratch repository, so its fake
# profiles and two-case roster never touch the real runners, cases, or roster.
MATRIX_ROOT="$TMP/matrix-repo"
mkdir -p "$MATRIX_ROOT/scripts" "$MATRIX_ROOT/evals/runners" "$MATRIX_ROOT/evals/cases"
for script in eval.sh eval-matrix.sh summarize-eval.js summarize-matrix.js; do
  cp "$ROOT/scripts/$script" "$MATRIX_ROOT/scripts/$script"
done
add_matrix_case() {
  mkdir -p "$MATRIX_ROOT/evals/cases/$1"
  printf '%s\n' '# refusal request' > "$MATRIX_ROOT/evals/cases/$1/REQUEST.md"
  printf '%s\n' '# neutral request' > "$MATRIX_ROOT/evals/cases/$1/REQUEST.baseline.md"
  printf '%s\n' 'outcome|refusal|' 'contains|REFUSED|' > "$MATRIX_ROOT/evals/cases/$1/EXPECTATIONS"
}
add_matrix_case alpha
add_matrix_case beta
printf '%s\n' '# scratch roster' 'alpha' '  beta  # trailing comment' '' > "$MATRIX_ROOT/evals/cases-roster.txt"

write_runner() {
  printf '%s\n' '#!/usr/bin/env sh' 'set -eu' "$2" > "$1"
  chmod +x "$1"
}
for profile in fa fb fc; do
  write_runner "$MATRIX_ROOT/evals/runners/$profile.sh" 'printf "%s\n" "REFUSED by policy" > "$2"'
  write_runner "$MATRIX_ROOT/evals/runners/$profile-baseline.sh" 'printf "%s\n" "plain answer" > "$2"'
done

run_matrix() {
  GODPLANS_MATRIX_PROFILES="fa fb fc" GODPLANS_VALIDATOR="$TMP/bin/validator" \
    bash "$MATRIX_ROOT/scripts/eval-matrix.sh" "$@"
}

run_matrix --check >/dev/null 2>"$TMP/matrix-check.err" ||
  fail "matrix check rejected a complete two-case roster: $(cat "$TMP/matrix-check.err")"
mv "$MATRIX_ROOT/evals/cases/beta/REQUEST.baseline.md" "$TMP/beta-baseline.md"
if run_matrix --check >/dev/null 2>"$TMP/matrix-incomplete.err"; then
  fail "matrix check accepted a case without a control request"
fi
grep -q 'beta' "$TMP/matrix-incomplete.err" || fail "incomplete matrix case was not named"
mv "$TMP/beta-baseline.md" "$MATRIX_ROOT/evals/cases/beta/REQUEST.baseline.md"

# The roster, not the directory listing, is the expected case set. A case
# directory the roster does not list, or a listed case whose directory is gone,
# fails the check instead of changing the case count.
add_matrix_case gamma
if run_matrix --check >/dev/null 2>"$TMP/matrix-unlisted.err"; then
  fail "matrix check accepted a case directory missing from the roster"
fi
grep -q 'evals/cases/gamma is not in evals/cases-roster.txt' "$TMP/matrix-unlisted.err" ||
  fail "an unlisted case directory was not named: $(cat "$TMP/matrix-unlisted.err")"
rm -rf "$MATRIX_ROOT/evals/cases/gamma"
mv "$MATRIX_ROOT/evals/cases/beta" "$TMP/beta-case"
if run_matrix --check >/dev/null 2>"$TMP/matrix-dropped.err"; then
  fail "matrix check accepted a roster case whose directory is missing"
fi
grep -q 'lists beta, but evals/cases/beta does not exist' "$TMP/matrix-dropped.err" ||
  fail "a dropped case was not named: $(cat "$TMP/matrix-dropped.err")"
mv "$TMP/beta-case" "$MATRIX_ROOT/evals/cases/beta"
cp "$MATRIX_ROOT/evals/cases-roster.txt" "$TMP/roster.saved"
printf '%s\n' 'alpha' 'beta' 'alpha' > "$MATRIX_ROOT/evals/cases-roster.txt"
if run_matrix --check >/dev/null 2>"$TMP/matrix-duplicate.err"; then
  fail "matrix check accepted a duplicate roster entry"
fi
grep -q 'duplicate case in evals/cases-roster.txt: alpha' "$TMP/matrix-duplicate.err" ||
  fail "a duplicate roster entry was not named: $(cat "$TMP/matrix-duplicate.err")"
cp "$TMP/roster.saved" "$MATRIX_ROOT/evals/cases-roster.txt"
run_matrix --check >/dev/null 2>"$TMP/matrix-check.err" ||
  fail "matrix check rejected the restored roster: $(cat "$TMP/matrix-check.err")"

# One failing case in the first profiles must not abort the profiles after it.
write_runner "$MATRIX_ROOT/evals/runners/fb.sh" \
  'case "$1" in */alpha/*) printf "%s\n" "plain answer" > "$2" ;; *) printf "%s\n" "REFUSED by policy" > "$2" ;; esac'
if run_matrix --output "$TMP/matrix-fail" >/dev/null 2>&1; then
  fail "matrix exited zero with a failing case"
fi
test -s "$TMP/matrix-fail/fc/EVAL.tsv" || fail "a failing profile aborted the profiles after it"
test -s "$TMP/matrix-fail/MATRIX.json" || fail "a failing case suppressed the matrix summary"

# A missing run fails the matrix and leaves no summary, but later profiles still run.
write_runner "$MATRIX_ROOT/evals/runners/fb.sh" \
  'case "$1" in */alpha/*) exit 1 ;; *) printf "%s\n" "REFUSED by policy" > "$2" ;; esac'
if run_matrix --output "$TMP/matrix-missing" >/dev/null 2>"$TMP/matrix-missing.err"; then
  fail "matrix exited zero with a missing run"
fi
test -s "$TMP/matrix-missing/fc/EVAL.tsv" || fail "a runner error aborted the profiles after it"
[ ! -e "$TMP/matrix-missing/MATRIX.json" ] || fail "matrix summarized a profile with a missing run"
grep -q 'profile fb has no scored skill or control arm for alpha' "$TMP/matrix-missing.err" ||
  fail "the missing run was not named: $(cat "$TMP/matrix-missing.err")"

# A control run that errors leaves a `BASE runner-error` marker, not a score.
# eval.sh does not fail on it, so the summarizer must, naming only that arm.
write_runner "$MATRIX_ROOT/evals/runners/fb.sh" 'printf "%s\n" "REFUSED by policy" > "$2"'
write_runner "$MATRIX_ROOT/evals/runners/fb-baseline.sh" \
  'case "$1" in */alpha/*) exit 1 ;; *) printf "%s\n" "plain answer" > "$2" ;; esac'
if run_matrix --output "$TMP/matrix-no-control" >/dev/null 2>"$TMP/matrix-no-control.err"; then
  fail "matrix exited zero with a missing control run"
fi
test -s "$TMP/matrix-no-control/fc/EVAL.tsv" || fail "a control runner error aborted the profiles after it"
grep -q '^alpha[[:space:]]BASE[[:space:]]runner-error$' "$TMP/matrix-no-control/fb/EVAL.tsv" ||
  fail "the control runner error was not recorded in EVAL.tsv"
[ ! -e "$TMP/matrix-no-control/MATRIX.json" ] || fail "matrix summarized a profile with a missing control run"
grep -q 'profile fb has no scored control arm for alpha' "$TMP/matrix-no-control.err" ||
  fail "the missing control run was not named: $(cat "$TMP/matrix-no-control.err")"
write_runner "$MATRIX_ROOT/evals/runners/fb-baseline.sh" 'printf "%s\n" "plain answer" > "$2"'

run_matrix --output "$TMP/matrix-pass" >/dev/null 2>&1 || fail "a clean matrix run failed"
node -e '
  const matrix = require(process.argv[1]);
  if (matrix.case_count !== 2) throw new Error("case count");
' "$TMP/matrix-pass/MATRIX.json" || fail "matrix did not take its case count from the roster"

echo "ok   [eval-harness]"
