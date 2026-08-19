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
bash -n "$ROOT/evals/runners/codex.sh"

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
# the control happens to write to .godplans/, so scope this to printf lines.
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
    format: "godplans/plan-json@1",
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

test -x "$ROOT/evals/runners/codex-baseline.sh" || fail "baseline runner is not executable"
bash -n "$ROOT/evals/runners/codex-baseline.sh"
if grep -q 'ln -s' "$ROOT/evals/runners/codex-baseline.sh"; then
  fail "baseline runner linked the skill into its workspace"
fi

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

echo "ok   [eval-harness]"
