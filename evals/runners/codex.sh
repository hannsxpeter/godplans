#!/usr/bin/env bash
# Run one behavioral case with the locally authenticated Codex CLI.

set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 REQUEST.md OUTPUT" >&2; exit 2; }

REQUEST=$1
OUTPUT=$2
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CASE_DIR="$(cd "$(dirname "$REQUEST")" && pwd)"
WORK="$(mktemp -d)"
ISO_HOME="$(mktemp -d)"
ISO_CODEX_HOME="$ISO_HOME/.codex"
LAST="$WORK/last-message.md"
OUTPUT_DIR="$(dirname "$OUTPUT")"
CODEX_LOG="$OUTPUT_DIR/codex.log"
CODEX_EVENTS="$OUTPUT_DIR/codex-events.jsonl"
trap 'rm -rf "$WORK" "$ISO_HOME"' EXIT

command -v codex >/dev/null 2>&1 || { echo "codex CLI not found" >&2; exit 2; }

# Isolate the globally installed skill set. Codex discovers skills in
# $CODEX_HOME/skills and $HOME/.agents/skills as well as the project, so on a
# machine with godplans (or its sibling skills) installed globally, both arms
# would silently load them and the comparison would measure nothing. Both
# runners isolate identically; the only isolation difference between arms is
# the project-local skill link below (the control also reads the neutral
# REQUEST.baseline.md). Auth and settings are copied so the arms share one
# model and one reasoning effort.
REAL_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
mkdir -p "$ISO_CODEX_HOME"
[ -f "$REAL_CODEX_HOME/auth.json" ] && cp "$REAL_CODEX_HOME/auth.json" "$ISO_CODEX_HOME/auth.json"
[ -f "$REAL_CODEX_HOME/config.toml" ] && cp "$REAL_CODEX_HOME/config.toml" "$ISO_CODEX_HOME/config.toml"
[ -e "$ISO_CODEX_HOME/skills" ] && { echo "isolated CODEX_HOME must not carry skills" >&2; exit 2; }

CODEX_MODEL=${GODPLANS_EVAL_MODEL:-configured-default}
CODEX_EFFORT=${GODPLANS_EVAL_REASONING_EFFORT:-configured-default}
RESOLVED_MODEL=$CODEX_MODEL
if [ "$RESOLVED_MODEL" = "configured-default" ] && [ -f "$REAL_CODEX_HOME/config.toml" ]; then
  RESOLVED_MODEL=$(awk -F= '/^[[:space:]]*model[[:space:]]*=/ { value=$2; gsub(/[[:space:]"]/, "", value); print value; exit }' "$REAL_CODEX_HOME/config.toml")
  RESOLVED_MODEL=${RESOLVED_MODEL:-unavailable}
fi
CODEX_ARGS=(
  exec
  --ephemeral
  --sandbox workspace-write
  --skip-git-repo-check
  --color never
  --json
  -C "$WORK"
  -o "$LAST"
)
if [ "$CODEX_MODEL" != "configured-default" ]; then
  CODEX_ARGS+=(-m "$CODEX_MODEL")
fi
if [ "$CODEX_EFFORT" != "configured-default" ]; then
  CODEX_ARGS+=(-c "model_reasoning_effort=\"$CODEX_EFFORT\"")
fi

if [ -d "$CASE_DIR/INPUT" ]; then
  cp -R "$CASE_DIR/INPUT/." "$WORK/"
fi

mkdir -p "$WORK/.agents/skills"
ln -s "$ROOT/skills/godplans" "$WORK/.agents/skills/godplans"
mkdir -p "$OUTPUT_DIR"

set +e
{
  printf '%s\n\n' 'Use the project-local godplans skill for the following evaluation request.'
  printf '%s\n' 'Work entirely inside the current workspace. Do not implement application code.'
  printf '%s\n\n' 'For a plan outcome, emit the complete godplans artifact set under .godplans/. For a compliance hard stop, explain the refusal in the final response and do not create a plan.'
  sed -n '1,$p' "$REQUEST"
} | HOME="$ISO_HOME" CODEX_HOME="$ISO_CODEX_HOME" codex "${CODEX_ARGS[@]}" - >"$CODEX_EVENTS" 2>"$CODEX_LOG"
CODEX_STATUS=$?
set -e
if [ "$CODEX_STATUS" -ne 0 ]; then
  tail -n 40 "$CODEX_LOG" >&2
  exit "$CODEX_STATUS"
fi

printf '%s\n' \
  "runner=codex" \
  "arm=skill" \
  "global_skills=isolated" \
  "codex_version=$(codex --version)" \
  "model=$CODEX_MODEL" \
  "resolved_model=$RESOLVED_MODEL" \
  "reasoning_effort=$CODEX_EFFORT" \
  > "$OUTPUT_DIR/RUNNER.txt"
node - "$CODEX_EVENTS" >> "$OUTPUT_DIR/RUNNER.txt" <<'NODE'
const fs = require('node:fs');
let input = 0;
let cached = 0;
let output = 0;
let found = false;
for (const line of fs.readFileSync(process.argv[2], 'utf8').split('\n')) {
  if (!line.trim()) continue;
  let event;
  try { event = JSON.parse(line); } catch { continue; }
  if (!event.usage) continue;
  found = true;
  input += Number(event.usage.input_tokens || 0);
  cached += Number(event.usage.cached_input_tokens || 0);
  output += Number(event.usage.output_tokens || 0);
}
process.stdout.write(`usage_source=${found ? 'cli-json' : 'unavailable'}\n`);
process.stdout.write(`input_tokens=${input}\n`);
process.stdout.write(`cached_input_tokens=${cached}\n`);
process.stdout.write(`output_tokens=${output}\n`);
process.stdout.write(`total_tokens=${input + output}\n`);
NODE
case "$OUTPUT" in
  */PLAN.mdx)
    [ -s "$WORK/.godplans/PLAN.mdx" ] || { echo "Codex did not emit PLAN.mdx" >&2; exit 1; }
    [ -x "$WORK/.godplans/validate-plan.sh" ] || { echo "Codex did not emit an executable validator" >&2; exit 1; }
    [ -s "$WORK/.godplans/PLAN.json" ] || { echo "Codex did not emit PLAN.json" >&2; exit 1; }
    cmp -s "$ROOT/skills/godplans/scripts/validate-plan.sh" "$WORK/.godplans/validate-plan.sh" || {
      echo "Codex emitted a validator that differs from the shipped source" >&2
      exit 1
    }
    node -e '
      const fs = require("node:fs");
      const crypto = require("node:crypto");
      const plan = fs.readFileSync(process.argv[1]);
      const sidecar = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
      const digest = "sha256:" + crypto.createHash("sha256").update(plan).digest("hex");
      if (sidecar.plan_digest !== digest) process.exit(1);
    ' "$WORK/.godplans/PLAN.mdx" "$WORK/.godplans/PLAN.json" || {
      echo "Codex emitted a stale PLAN.json sidecar" >&2
      exit 1
    }
    cp "$WORK/.godplans/PLAN.mdx" "$OUTPUT"
    cp "$WORK/.godplans/validate-plan.sh" "$(dirname "$OUTPUT")/validate-plan.sh"
    cp "$WORK/.godplans/PLAN.json" "$(dirname "$OUTPUT")/PLAN.json"
    ;;
  */RESPONSE.md)
    [ ! -e "$WORK/.godplans/PLAN.mdx" ] || { echo "Codex emitted a plan for a refusal case" >&2; exit 1; }
    [ -s "$LAST" ] || { echo "Codex returned an empty refusal" >&2; exit 1; }
    cp "$LAST" "$OUTPUT"
    ;;
  *)
    echo "unsupported output path: $OUTPUT" >&2
    exit 2
    ;;
esac
