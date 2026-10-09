#!/usr/bin/env bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [codex-runner] $*" >&2
  exit 1
}

mkdir -p "$TMP/bin" "$TMP/case" "$TMP/output"
printf '%s\n' '# evaluation request' > "$TMP/case/REQUEST.md"
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

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'if [ "${1:-}" = "--version" ]; then echo "fake-codex 1.0"; exit 0; fi' \
  'work=""' \
  'last=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -C) work=$2; shift ;;' \
  '    -o) last=$2; shift ;;' \
  '  esac' \
  '  shift' \
  'done' \
  "sed -n '1,\$p' >/dev/null" \
  'mkdir -p "$work/.godplans"' \
  'cp "$GODPLANS_TEST_PLAN" "$work/.godplans/PLAN.mdx"' \
  'cp "$GODPLANS_TEST_SIDECAR" "$work/.godplans/PLAN.json"' \
  'if [ "${GODPLANS_FAKE_COMPANION:-0}" -eq 1 ]; then' \
  '  cp "$GODPLANS_TEST_VALIDATOR" "$work/.godplans/validate-plan.sh"' \
  '  chmod +x "$work/.godplans/validate-plan.sh"' \
  'fi' \
  'printf "%s\n" "evaluation complete" > "$last"' \
  > "$TMP/bin/codex"
chmod +x "$TMP/bin/codex"

set +e
PATH="$TMP/bin:$PATH" \
GODPLANS_TEST_PLAN="$TMP/PLAN.mdx" \
GODPLANS_TEST_SIDECAR="$TMP/PLAN.json" \
GODPLANS_TEST_VALIDATOR="$ROOT/skills/godplans/scripts/validate-plan.sh" \
  "$ROOT/evals/runners/codex.sh" "$TMP/case/REQUEST.md" "$TMP/output/missing/PLAN.mdx" \
  >"$TMP/missing.out" 2>&1
missing_status=$?
set -e
[ "$missing_status" -ne 0 ] || fail "runner accepted a missing validator companion"
grep -q 'did not emit an executable validator' "$TMP/missing.out" || fail "missing companion diagnostic was absent"

PATH="$TMP/bin:$PATH" \
GODPLANS_TEST_PLAN="$TMP/PLAN.mdx" \
GODPLANS_TEST_SIDECAR="$TMP/PLAN.json" \
GODPLANS_TEST_VALIDATOR="$ROOT/skills/godplans/scripts/validate-plan.sh" \
GODPLANS_FAKE_COMPANION=1 \
GODPLANS_EVAL_MODEL=fake-model \
GODPLANS_EVAL_REASONING_EFFORT=medium \
  "$ROOT/evals/runners/codex.sh" "$TMP/case/REQUEST.md" "$TMP/output/complete/PLAN.mdx"

cmp -s "$TMP/PLAN.mdx" "$TMP/output/complete/PLAN.mdx" || fail "plan artifact was not retained"
cmp -s "$TMP/PLAN.json" "$TMP/output/complete/PLAN.json" || fail "plan sidecar was not retained"
cmp -s "$ROOT/skills/godplans/scripts/validate-plan.sh" "$TMP/output/complete/validate-plan.sh" || fail "validator artifact drifted"
grep -q '^codex_version=fake-codex 1.0$' "$TMP/output/complete/RUNNER.txt" || fail "CLI version metadata is missing"
grep -q '^model=fake-model$' "$TMP/output/complete/RUNNER.txt" || fail "model metadata is missing"
grep -q '^reasoning_effort=medium$' "$TMP/output/complete/RUNNER.txt" || fail "reasoning metadata is missing"
grep -q '^usage_source=unavailable$' "$TMP/output/complete/RUNNER.txt" || fail "usage metadata fallback is missing"

# Control arm. The case carries a prior plan at INPUT/.godplans/PLAN.mdx, as the
# replan case does, and its neutral request names PLAN.md. The control's plan
# is what it wrote, never the fixture it left unchanged.
mkdir -p "$TMP/bin-base" "$TMP/control/INPUT/.godplans" "$TMP/codex-home"
printf '%s\n' 'SKILL-ARM-REQUEST' > "$TMP/control/REQUEST.md"
printf '%s\n' 'NEUTRAL-REQUEST. Write your plan to PLAN.md.' > "$TMP/control/REQUEST.baseline.md"
printf '%s\n' '# prior plan fixture' > "$TMP/control/INPUT/.godplans/PLAN.mdx"
cat > "$TMP/bin-base/codex" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
if [ "${1:-}" = "--version" ]; then echo "fake-codex 1.0"; exit 0; fi
work=""
last=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -C) work=$2; shift ;;
    -o) last=$2; shift ;;
  esac
  shift
done
cat > "$GODPLANS_TEST_PROMPT"
case "$GODPLANS_FAKE_MODE" in
  plan-md) printf '%s\n' '# control plan' > "$work/PLAN.md" ;;
  edit-fixture) printf '%s\n' '- control edit in place' >> "$work/.godplans/PLAN.mdx" ;;
  none) ;;
esac
printf '%s\n' 'control final message' > "$last"
FAKE
chmod +x "$TMP/bin-base/codex"

run_control() {
  PATH="$TMP/bin-base:$PATH" CODEX_HOME="$TMP/codex-home" \
  GODPLANS_TEST_PROMPT="$TMP/control-prompt.txt" GODPLANS_FAKE_MODE=$1 \
    "$ROOT/evals/runners/codex-baseline.sh" "$TMP/control/REQUEST.md" "$TMP/output/control-$1/$2"
}

run_control plan-md PLAN.mdx >/dev/null 2>&1 || fail "baseline runner failed"
grep -qx '# control plan' "$TMP/output/control-plan-md/PLAN.mdx" ||
  fail "baseline runner took the INPUT fixture instead of the PLAN.md the control wrote"
grep -q 'NEUTRAL-REQUEST' "$TMP/control-prompt.txt" || fail "baseline runner did not send REQUEST.baseline.md"
if grep -qi -e godplans -e 'SKILL-ARM-REQUEST' "$TMP/control-prompt.txt"; then
  fail "baseline prompt leaks the skill or the skill-arm request"
fi
grep -q '^prompt=neutral-baseline-request$' "$TMP/output/control-plan-md/RUNNER.txt" ||
  fail "baseline runner did not record the neutral request"
run_control none PLAN.mdx >/dev/null 2>&1 || fail "a control that wrote no plan was reported as a runner error"
grep -qx 'control final message' "$TMP/output/control-none/PLAN.mdx" ||
  fail "a control that wrote no plan was scored on the unchanged INPUT fixture"
run_control edit-fixture PLAN.mdx >/dev/null 2>&1 || fail "baseline runner failed on an in-place edit"
grep -q 'control edit in place' "$TMP/output/control-edit-fixture/PLAN.mdx" ||
  fail "a control that edited the prior plan in place lost that edit"
# The refusal branch reads the same paths: a control that plans a request it
# should refuse is recorded as that plan.
rm -rf "$TMP/output/control-plan-md"
run_control plan-md RESPONSE.md >/dev/null 2>&1 || fail "baseline runner failed on a refusal case"
grep -qx '# control plan' "$TMP/output/control-plan-md/RESPONSE.md" ||
  fail "a control plan written to PLAN.md for a refusal case was not recorded"

echo "ok   [codex-runner]"
