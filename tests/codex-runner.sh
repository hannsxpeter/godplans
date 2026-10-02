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

echo "ok   [codex-runner]"
