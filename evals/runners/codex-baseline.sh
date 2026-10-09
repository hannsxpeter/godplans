#!/usr/bin/env bash
# Control arm: run one behavioral case with the SAME Codex CLI, model, and
# reasoning effort as runners/codex.sh, but with no godplans skill available.
#
# Fairness rules, because a rigged control proves nothing:
#   - identical agent, model, reasoning effort, workspace, and INPUT fixture
#   - a NEUTRAL request. The case REQUEST.md is written for the skill arm: it
#     says "Use godplans" and "produce the godplans artifact set under
#     .godplans/". Handing that to a skill-less agent is not a fair control;
#     it tells the agent to use a tool it does not have, and in practice the
#     agent burns its whole turn web-searching for the skill's format and
#     writes nothing. So the control reads REQUEST.baseline.md when present:
#     the same task and constraints, de-branded, asking for a plan at a
#     neutral path. If no baseline request exists, the runner warns and falls
#     back to REQUEST.md, and that run is not a fair comparison.
#   - nothing from the skill leaks in: no godplans name, no .godplans path, no
#     format contract, requirement IDs, validator, phase method, or PLAN.mdx
#     vocabulary in the preamble
#   - a missing plan file means the final response is scored in its place,
#     never hidden as a runner error

set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 REQUEST.md OUTPUT" >&2; exit 2; }

REQUEST=$1
OUTPUT=$2
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

# Isolate the globally installed skill set, identically to runners/codex.sh.
# This is the load-bearing line of the whole control arm: Codex discovers
# skills in $CODEX_HOME/skills and $HOME/.agents/skills, so on a machine where
# godplans is installed globally (the common case, since a maintainer runs the
# evals), the control would silently load it and measure godplans against
# itself. Both arms isolate the same way; the ONLY isolation difference between
# them is that this runner never links the skill into its workspace.
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

# No .agents/skills link: that absence is the whole point of this arm.
mkdir -p "$OUTPUT_DIR"

REQUEST_BASELINE="$CASE_DIR/REQUEST.baseline.md"
if [ -f "$REQUEST_BASELINE" ]; then
  PROMPT_SOURCE="$REQUEST_BASELINE"
else
  PROMPT_SOURCE="$REQUEST"
  echo "warning: no REQUEST.baseline.md for $(basename "$CASE_DIR"); the control is running a godplans-phrased request and is NOT a fair comparison" >&2
fi

set +e
{
  printf '%s\n\n' 'Work entirely inside the current workspace. Do not implement application code. Complete the following task.'
  sed -n '1,$p' "$PROMPT_SOURCE"
} | HOME="$ISO_HOME" CODEX_HOME="$ISO_CODEX_HOME" codex "${CODEX_ARGS[@]}" - >"$CODEX_EVENTS" 2>"$CODEX_LOG"
CODEX_STATUS=$?
set -e
if [ "$CODEX_STATUS" -ne 0 ]; then
  tail -n 40 "$CODEX_LOG" >&2
  exit "$CODEX_STATUS"
fi

if [ "$PROMPT_SOURCE" = "$REQUEST_BASELINE" ]; then
  prompt_kind="neutral-baseline-request"
else
  prompt_kind="fallback-skill-phrased-request-UNFAIR"
fi
printf '%s\n' \
  "runner=codex-baseline" \
  "arm=baseline-no-skill" \
  "global_skills=isolated" \
  "prompt=$prompt_kind" \
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

# Print the plan the control wrote. Accept any plausible path, so the baseline
# is not penalized for choosing a different one, but prefer the path the
# neutral request names (PLAN.md), and never take an INPUT fixture the control
# left unchanged (a replan case's prior .godplans/PLAN.mdx) as its own plan.
control_plan() {
  for candidate in PLAN.md plan.md PLAN.mdx .godplans/PLAN.mdx; do
    [ -s "$WORK/$candidate" ] || continue
    if [ -f "$CASE_DIR/INPUT/$candidate" ] && cmp -s "$WORK/$candidate" "$CASE_DIR/INPUT/$candidate"; then
      continue
    fi
    printf '%s\n' "$WORK/$candidate"
    return 0
  done
  return 1
}

case "$OUTPUT" in
  */PLAN.mdx)
    if plan=$(control_plan); then
      cp "$plan" "$OUTPUT"
      exit 0
    fi
    # No plan file: score the final response instead. It will fail the
    # structural assertions, which is the honest result, not an error.
    cp "$LAST" "$OUTPUT" 2>/dev/null || : > "$OUTPUT"
    ;;
  */RESPONSE.md)
    if plan=$(control_plan); then
      # The baseline planned a request it should have refused. Record the plan
      # so the refusal assertions fail against real evidence.
      cp "$plan" "$OUTPUT"
    else
      cp "$LAST" "$OUTPUT" 2>/dev/null || : > "$OUTPUT"
    fi
    ;;
  *)
    echo "unsupported output path: $OUTPUT" >&2
    exit 2
    ;;
esac
