#!/usr/bin/env bash
# Behavioral regression for the Claude and Gemini runners (vendor-cli.sh and
# vendor-grade.sh). Stand-in claude and gemini executables sit first on PATH,
# so no model is ever called. Each stand-in records its flags, prompt, and
# workspace at call time, because the runner deletes the workspace on exit.

set -euo pipefail

# The runners read the model and effort overrides that evals/README.md and
# evals/external/README.md document for real runs, and the stand-in CLI reads
# its own mode variables.
# One exported in the caller's shell must not change what this offline test
# expects, so every case starts from the defaults and sets what it needs.
unset GODPLANS_CLAUDE_MODEL GODPLANS_CLAUDE_EFFORT GODPLANS_GEMINI_MODEL \
  GODPLANS_GRADE_CLAUDE_MODEL GODPLANS_GRADE_GEMINI_MODEL \
  GODPLANS_VENDOR_PROVIDER GODPLANS_VENDOR_ARM GODPLANS_GRADE_PROVIDER \
  GODPLANS_FAKE_MODE GODPLANS_FAKE_ROLE

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [vendor-runner] $*" >&2
  exit 1
}

RUNNERS="$ROOT/evals/runners"
mkdir -p "$TMP/bin" "$TMP/out"

# Stand-in CLI. GODPLANS_FAKE_ROLE=grade answers as a judge; otherwise it plans.
# GODPLANS_FAKE_MODE picks what a planning turn leaves in the workspace:
# companion (the full .godplans/ artifact set), no-validator (the plan and
# sidecar only), plan-md (a PLAN.md, which the neutral request names),
# edit-fixture (an in-place edit of the INPUT plan), or none (only a final
# message).
cat > "$TMP/bin/claude" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
name=$(basename "$0")
if [ "${1:-}" = "--version" ]; then echo "fake-$name 2.0"; exit 0; fi
log=$GODPLANS_TEST_LOG
: > "$log.args"
count=0
for arg in "$@"; do
  count=$((count + 1))
  if [ "$count" -lt "$#" ]; then printf '%s\n' "$arg" >> "$log.args"; fi
  prompt=$arg
done
printf '%s\n' "$prompt" > "$log.prompt"
if [ -f .gemini/settings.json ]; then cp .gemini/settings.json "$log.settings"; else rm -f "$log.settings"; fi
if [ -f .agents/skills/godplans/SKILL.md ]; then echo present > "$log.skill"; else echo absent > "$log.skill"; fi

if [ "${GODPLANS_FAKE_ROLE:-plan}" = "grade" ]; then
  grade='{"packet_id":"probe","plans":[{"label":"A","scores":{"decision_completeness":4,"falsifiability":4,"execution_actionability":4,"risk_targeting":4,"proportionality":4,"internal_consistency":4},"total":24},{"label":"B","scores":{"decision_completeness":3,"falsifiability":3,"execution_actionability":3,"risk_targeting":3,"proportionality":3,"internal_consistency":3},"total":18}],"preference":"A","rationale":"fixture"}'
  if [ "$name" = "claude" ]; then
    printf '{"structured_output":%s}\n' "$grade"
  else
    node -e 'process.stdout.write(JSON.stringify({ response: "```json\n" + process.argv[1] + "\n```" }) + "\n")' "$grade"
  fi
  exit 0
fi

case "${GODPLANS_FAKE_MODE:-none}" in
  companion|no-validator)
    mkdir -p .godplans
    cp "$GODPLANS_TEST_PLAN" .godplans/PLAN.mdx
    cp "$GODPLANS_TEST_SIDECAR" .godplans/PLAN.json
    if [ "$GODPLANS_FAKE_MODE" = "companion" ]; then
      cp "$GODPLANS_TEST_VALIDATOR" .godplans/validate-plan.sh
      chmod +x .godplans/validate-plan.sh
    fi
    ;;
  plan-md) printf '%s\n' '# control plan written to the requested path' > PLAN.md ;;
  edit-fixture) printf '%s\n' '- [ ] T-9 control edit in place' >> .godplans/PLAN.mdx ;;
  none) ;;
esac
if [ "$name" = "claude" ]; then
  printf '%s\n' '{"result":"final message","usage":{"input_tokens":10,"cache_read_input_tokens":100,"cache_creation_input_tokens":5,"output_tokens":2}}'
else
  printf '%s\n' '{"response":"final message","stats":{"models":{"fake":{"tokens":{"prompt":7,"cached":1,"candidates":3}}}}}'
fi
FAKE
chmod +x "$TMP/bin/claude"
cp "$TMP/bin/claude" "$TMP/bin/gemini"

# Cases. The plan case carries a prior plan in INPUT/.godplans/, as the replan
# case does; the unfair case has no neutral request.
for case_name in skill-case plan-case refusal-case unfair-case; do
  mkdir -p "$TMP/cases/$case_name"
  printf '%s\n' "SKILL-ARM-REQUEST for $case_name" > "$TMP/cases/$case_name/REQUEST.md"
done
for case_name in skill-case plan-case refusal-case; do
  printf '%s\n' "NEUTRAL-REQUEST for $case_name. Write your plan to PLAN.md." \
    > "$TMP/cases/$case_name/REQUEST.baseline.md"
done
mkdir -p "$TMP/cases/plan-case/INPUT/.godplans"
printf '%s\n' '# prior plan fixture' '- [x] T-1 completed earlier' \
  > "$TMP/cases/plan-case/INPUT/.godplans/PLAN.mdx"
printf '%s\n' '{"name":"fixture"}' > "$TMP/cases/plan-case/INPUT/package.json"

printf '%s\n' '# valid plan artifact' > "$TMP/PLAN.mdx"
node -e '
  const fs = require("node:fs");
  const crypto = require("node:crypto");
  const bytes = fs.readFileSync(process.argv[1]);
  fs.writeFileSync(process.argv[2], JSON.stringify({
    format: "godplans/plan-json@2",
    plan_digest: "sha256:" + crypto.createHash("sha256").update(bytes).digest("hex")
  }));
' "$TMP/PLAN.mdx" "$TMP/PLAN.json"
printf '%s\n' '{"format":"godplans/plan-json@2","plan_digest":"sha256:0"}' > "$TMP/stale.json"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$TMP/drifted-validator.sh"

LOG="$TMP/cli"
# run RUNNER CASE OUTPUT [VAR=VALUE ...]: run one runner with the stand-ins.
run() {
  runner=$1
  case_name=$2
  output=$3
  shift 3
  env PATH="$TMP/bin:$PATH" \
    GODPLANS_TEST_LOG="$LOG" \
    GODPLANS_TEST_PLAN="$TMP/PLAN.mdx" \
    GODPLANS_TEST_SIDECAR="$TMP/PLAN.json" \
    GODPLANS_TEST_VALIDATOR="$ROOT/skills/godplans/scripts/validate-plan.sh" \
    "$@" \
    "$RUNNERS/$runner" "$TMP/cases/$case_name/REQUEST.md" "$output"
}

has_flag() {
  grep -qx -- "$1" "$LOG.args"
}

line() {
  grep -qx -- "$2" "$1" || fail "$(basename "$(dirname "$1")")/$(basename "$1") lacks '$2'"
}

# Claude skill arm: the plugin is loaded under safe mode, and the plan counts
# only with a byte-identical validator and a sidecar whose digest matches.
if run claude.sh skill-case "$TMP/out/no-plan/PLAN.mdx" >"$TMP/no-plan.out" 2>&1; then
  fail "skill arm accepted a run that wrote no plan"
fi
grep -q 'did not emit PLAN.mdx' "$TMP/no-plan.out" || fail "missing plan diagnostic was absent"
if run claude.sh skill-case "$TMP/out/no-companion/PLAN.mdx" GODPLANS_FAKE_MODE=no-validator \
  >"$TMP/no-companion.out" 2>&1; then
  fail "skill arm accepted a plan without the validator companion"
fi
grep -q 'did not emit an executable validator' "$TMP/no-companion.out" ||
  fail "missing companion diagnostic was absent"
if run claude.sh skill-case "$TMP/out/stale/PLAN.mdx" GODPLANS_FAKE_MODE=companion \
  GODPLANS_TEST_SIDECAR="$TMP/stale.json" >"$TMP/stale.out" 2>&1; then
  fail "skill arm accepted a stale PLAN.json sidecar"
fi
grep -q 'emitted a stale PLAN.json sidecar' "$TMP/stale.out" || fail "stale sidecar diagnostic was absent"
if run claude.sh skill-case "$TMP/out/drift/PLAN.mdx" GODPLANS_FAKE_MODE=companion \
  GODPLANS_TEST_VALIDATOR="$TMP/drifted-validator.sh" >"$TMP/drift.out" 2>&1; then
  fail "skill arm accepted a drifted validator"
fi
grep -q 'differs from the shipped source' "$TMP/drift.out" || fail "drifted validator diagnostic was absent"

run claude.sh skill-case "$TMP/out/claude-skill/PLAN.mdx" GODPLANS_FAKE_MODE=companion \
  GODPLANS_CLAUDE_MODEL=fake-model GODPLANS_CLAUDE_EFFORT=medium >/dev/null 2>&1 ||
  fail "claude skill arm rejected a complete artifact set"
cmp -s "$TMP/PLAN.mdx" "$TMP/out/claude-skill/PLAN.mdx" || fail "plan artifact was not retained"
cmp -s "$TMP/PLAN.json" "$TMP/out/claude-skill/PLAN.json" || fail "plan sidecar was not retained"
cmp -s "$ROOT/skills/godplans/scripts/validate-plan.sh" "$TMP/out/claude-skill/validate-plan.sh" ||
  fail "validator artifact drifted"
has_flag --safe-mode || fail "claude skill arm does not run in safe mode"
grep -A1 -x -- '--plugin-dir' "$LOG.args" | grep -qx -- "$ROOT/plugins/godplans" ||
  fail "claude skill arm does not load the godplans plugin directory"
grep -q 'SKILL-ARM-REQUEST' "$LOG.prompt" || fail "claude skill arm did not send REQUEST.md"
runner_txt="$TMP/out/claude-skill/RUNNER.txt"
for expected in runner=claude arm=skill customization_mode=safe-mode prompt=skill-request \
  'cli_version=fake-claude 2.0' model=fake-model reasoning_effort=medium usage_source=cli-json; do
  line "$runner_txt" "$expected"
done
# Anthropic input_tokens excludes cache reads and writes; the runner adds both
# so totals compare with Codex, whose input_tokens includes cached input.
for expected in input_tokens=115 cached_input_tokens=100 output_tokens=2 total_tokens=117; do
  line "$runner_txt" "$expected"
done

# Claude control arm: no plugin, slash commands off, the neutral request only.
run claude-baseline.sh plan-case "$TMP/out/claude-control/PLAN.mdx" GODPLANS_FAKE_MODE=plan-md \
  >/dev/null 2>&1 || fail "claude control arm failed"
has_flag --safe-mode || fail "claude control arm does not run in safe mode"
has_flag --disable-slash-commands || fail "claude control arm leaves slash commands on"
if has_flag --plugin-dir; then fail "claude control arm loads a plugin directory"; fi
grep -q 'NEUTRAL-REQUEST for plan-case' "$LOG.prompt" || fail "claude control arm did not send REQUEST.baseline.md"
if grep -qi -e godplans -e 'SKILL-ARM-REQUEST' "$LOG.prompt"; then
  fail "claude control prompt leaks the skill or the skill-arm request"
fi
for expected in arm=baseline customization_mode=safe-mode prompt=neutral-baseline-request; do
  line "$TMP/out/claude-control/RUNNER.txt" "$expected"
done

# The control's plan is the PLAN.md its request names, never the prior plan the
# INPUT fixture placed at .godplans/PLAN.mdx.
grep -qx '# control plan written to the requested path' "$TMP/out/claude-control/PLAN.mdx" ||
  fail "control arm took the INPUT fixture instead of the PLAN.md it wrote"
run claude-baseline.sh plan-case "$TMP/out/claude-none/PLAN.mdx" GODPLANS_FAKE_MODE=none \
  >/dev/null 2>&1 || fail "a control that wrote no plan was reported as a runner error"
grep -qx 'final message' "$TMP/out/claude-none/PLAN.mdx" ||
  fail "a control that wrote no plan was scored on the unchanged INPUT fixture"
run claude-baseline.sh plan-case "$TMP/out/claude-edit/PLAN.mdx" GODPLANS_FAKE_MODE=edit-fixture \
  >/dev/null 2>&1 || fail "claude control arm failed on an in-place edit"
grep -q 'T-9 control edit in place' "$TMP/out/claude-edit/PLAN.mdx" ||
  fail "a control that edited the prior plan in place lost that edit"

# A control that plans a request it should refuse is recorded as that plan.
run claude-baseline.sh refusal-case "$TMP/out/claude-refusal-plan/RESPONSE.md" GODPLANS_FAKE_MODE=plan-md \
  >/dev/null 2>&1 || fail "claude control arm failed on a refusal case"
grep -q 'control plan written to the requested path' "$TMP/out/claude-refusal-plan/RESPONSE.md" ||
  fail "a control plan for a refusal case was not recorded"
run claude-baseline.sh refusal-case "$TMP/out/claude-refusal/RESPONSE.md" GODPLANS_FAKE_MODE=none \
  >/dev/null 2>&1 || fail "claude control arm failed on a refusal"
grep -qx 'final message' "$TMP/out/claude-refusal/RESPONSE.md" || fail "a control refusal was not retained"

# Without a neutral request the control warns and says so in RUNNER.txt.
run claude-baseline.sh unfair-case "$TMP/out/claude-unfair/PLAN.mdx" >/dev/null 2>"$TMP/unfair.err" ||
  fail "claude control arm failed without a neutral request"
grep -q 'control is not fair' "$TMP/unfair.err" || fail "the unfair fallback did not warn"
line "$TMP/out/claude-unfair/RUNNER.txt" prompt=fallback-skill-phrased-request-UNFAIR

# Gemini skill arm: the skill is copied into the workspace, settings untouched.
run gemini.sh skill-case "$TMP/out/gemini-skill/PLAN.mdx" GODPLANS_FAKE_MODE=companion \
  >/dev/null 2>&1 || fail "gemini skill arm rejected a complete artifact set"
grep -qx present "$LOG.skill" || fail "gemini skill arm did not copy the skill into its workspace"
[ ! -e "$LOG.settings" ] || fail "gemini skill arm disabled workspace skills"
grep -A1 -x -- '--approval-mode' "$LOG.args" | grep -qx yolo || fail "gemini skill arm approval mode changed"
for expected in runner=gemini arm=skill customization_mode=workspace-scoped model=gemini-2.5-pro \
  reasoning_effort=provider-default input_tokens=7 cached_input_tokens=1 output_tokens=3 total_tokens=10; do
  line "$TMP/out/gemini-skill/RUNNER.txt" "$expected"
done

# Gemini control arm: no skill copy, and workspace settings turn skills and
# hooks off.
run gemini-baseline.sh plan-case "$TMP/out/gemini-control/PLAN.mdx" GODPLANS_FAKE_MODE=plan-md \
  >/dev/null 2>&1 || fail "gemini control arm failed"
grep -qx absent "$LOG.skill" || fail "gemini control arm has the skill in its workspace"
node -e '
  const settings = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
  if (settings.skills?.enabled !== false || settings.hooksConfig?.enabled !== false) process.exit(1);
' "$LOG.settings" || fail "gemini control arm left skills or hooks enabled"
grep -q 'NEUTRAL-REQUEST for plan-case' "$LOG.prompt" || fail "gemini control arm did not send REQUEST.baseline.md"
grep -qx '# control plan written to the requested path' "$TMP/out/gemini-control/PLAN.mdx" ||
  fail "gemini control arm took the INPUT fixture instead of the PLAN.md it wrote"
for expected in arm=baseline customization_mode=workspace-scoped prompt=neutral-baseline-request; do
  line "$TMP/out/gemini-control/RUNNER.txt" "$expected"
done

# Blind judges: Claude with no tools and the grade schema, Gemini in plan
# approval mode with workspace skills off. Both write the parsed grade.
printf '%s\n' '# Packet probe' '## Required JSON' 'packet body' > "$TMP/packet.md"
mkdir -p "$TMP/grades"
run_grade() {
  env PATH="$TMP/bin:$PATH" GODPLANS_TEST_LOG="$LOG" GODPLANS_FAKE_ROLE=grade \
    "$RUNNERS/$1" "$TMP/packet.md" "$TMP/grades/$2.json"
}
check_grade() {
  node -e '
    const grade = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
    if (grade.packet_id !== "probe" || grade.plans.length !== 2 || grade.preference !== "A") process.exit(1);
  ' "$TMP/grades/$1.json" || fail "$1 judge did not write the parsed grade"
}

run_grade claude-grade.sh claude >/dev/null 2>&1 || fail "claude judge failed"
check_grade claude
has_flag --safe-mode || fail "claude judge does not run in safe mode"
has_flag --disable-slash-commands || fail "claude judge leaves slash commands on"
[ "$(awk 'previous == "--tools" { print "[" $0 "]" } { previous = $0 }' "$LOG.args")" = "[]" ] ||
  fail "claude judge does not run with an empty tool list"
grep -A1 -x -- '--json-schema' "$LOG.args" | grep -q '"preference"' ||
  fail "claude judge is not given the grade schema"
grep -q 'packet body' "$LOG.prompt" || fail "claude judge did not receive the packet"
for expected in runner=claude-grade arm=blind-judge customization_mode=safe-mode model=sonnet; do
  line "$TMP/grades/claude.RUNNER.txt" "$expected"
done

run_grade gemini-grade.sh gemini >/dev/null 2>&1 || fail "gemini judge failed"
check_grade gemini
grep -A1 -x -- '--approval-mode' "$LOG.args" | grep -qx plan || fail "gemini judge does not run in plan approval mode"
[ -f "$LOG.settings" ] || fail "gemini judge workspace does not disable skills and hooks"
grep -qF "the packet's Required JSON schema" "$LOG.prompt" ||
  fail "gemini judge prompt does not point at the packet's schema"
for expected in runner=gemini-grade arm=blind-judge customization_mode=workspace-scoped model=gemini-2.5-pro; do
  line "$TMP/grades/gemini.RUNNER.txt" "$expected"
done

echo "ok   [vendor-runner]"
