#!/usr/bin/env bash
# Shared host-authenticated runner for Claude Code and Gemini CLI evaluation arms.

set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 REQUEST.md OUTPUT" >&2; exit 2; }

PROVIDER="${GODPLANS_VENDOR_PROVIDER:-}"
ARM="${GODPLANS_VENDOR_ARM:-}"
REQUEST=$1
OUTPUT=$2
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CASE_DIR="$(cd "$(dirname "$REQUEST")" && pwd)"
WORK="$(mktemp -d)"
LAST="$WORK/last-message.md"
OUTPUT_DIR="$(dirname "$OUTPUT")"
RAW="$OUTPUT_DIR/$PROVIDER-result.json"
LOG="$OUTPUT_DIR/$PROVIDER.log"
USAGE="$OUTPUT_DIR/$PROVIDER-usage.txt"

trap 'rm -rf "$WORK"' EXIT

case "$PROVIDER" in
  claude|gemini) ;;
  *) echo "GODPLANS_VENDOR_PROVIDER must be claude or gemini" >&2; exit 2 ;;
esac
case "$ARM" in
  skill|baseline) ;;
  *) echo "GODPLANS_VENDOR_ARM must be skill or baseline" >&2; exit 2 ;;
esac

command -v "$PROVIDER" >/dev/null 2>&1 || {
  echo "$PROVIDER CLI not found" >&2
  exit 2
}

if [ -d "$CASE_DIR/INPUT" ]; then
  cp -R "$CASE_DIR/INPUT/." "$WORK/"
fi

PROMPT_SOURCE="$REQUEST"
if [ "$ARM" = "skill" ]; then
  if [ "$PROVIDER" = "claude" ]; then
    :
  else
    mkdir -p "$WORK/.agents/skills"
    cp -R "$ROOT/skills/godplans" "$WORK/.agents/skills/godplans"
  fi
else
  if [ "$PROVIDER" = "gemini" ]; then
    mkdir -p "$WORK/.gemini"
    printf '%s\n' '{"skills":{"enabled":false},"hooksConfig":{"enabled":false}}' \
      > "$WORK/.gemini/settings.json"
  fi
  if [ -f "$CASE_DIR/REQUEST.baseline.md" ]; then
    PROMPT_SOURCE="$CASE_DIR/REQUEST.baseline.md"
  else
    echo "warning: no REQUEST.baseline.md for $(basename "$CASE_DIR"); control is not fair" >&2
  fi
fi

PROMPT_FILE="$WORK/eval-prompt.txt"
if [ "$ARM" = "skill" ]; then
  {
    printf '%s\n\n' 'Use the project-local godplans skill for this evaluation request.'
    printf '%s\n' 'Work entirely inside the current workspace. Do not implement application code.'
    printf '%s\n\n' 'For a plan outcome, emit PLAN.mdx, PLAN.json, and the executable validator under .godplans/. For a compliance hard stop, explain the refusal and create no plan.'
    sed -n '1,$p' "$PROMPT_SOURCE"
  } > "$PROMPT_FILE"
else
  {
    printf '%s\n\n' 'Work entirely inside the current workspace. Do not implement application code. Complete the following task.'
    sed -n '1,$p' "$PROMPT_SOURCE"
  } > "$PROMPT_FILE"
fi

mkdir -p "$OUTPUT_DIR"
set +e
if [ "$PROVIDER" = "claude" ]; then
  MODEL="${GODPLANS_CLAUDE_MODEL:-sonnet}"
  EFFORT="${GODPLANS_CLAUDE_EFFORT:-high}"
  if [ "$ARM" = "skill" ]; then
    (
      cd "$WORK"
      claude -p \
        --safe-mode \
        --plugin-dir "$ROOT/plugins/godplans" \
        --output-format json \
        --model "$MODEL" \
        --effort "$EFFORT" \
        --dangerously-skip-permissions \
        --no-session-persistence \
        "$(sed -n '1,$p' "$PROMPT_FILE")"
    ) >"$RAW" 2>"$LOG"
  else
    (
      cd "$WORK"
      claude -p \
        --safe-mode \
        --disable-slash-commands \
        --output-format json \
        --model "$MODEL" \
        --effort "$EFFORT" \
        --dangerously-skip-permissions \
        --no-session-persistence \
        "$(sed -n '1,$p' "$PROMPT_FILE")"
    ) >"$RAW" 2>"$LOG"
  fi
  STATUS=$?
else
  MODEL="${GODPLANS_GEMINI_MODEL:-gemini-2.5-pro}"
  EFFORT="provider-default"
  (
    cd "$WORK"
    gemini \
      --approval-mode yolo \
      --output-format json \
      --model "$MODEL" \
      --prompt "$(sed -n '1,$p' "$PROMPT_FILE")"
  ) >"$RAW" 2>"$LOG"
  STATUS=$?
fi
set -e
if [ "$STATUS" -ne 0 ]; then
  tail -n 40 "$LOG" >&2
  exit "$STATUS"
fi

node - "$PROVIDER" "$RAW" "$LAST" "$USAGE" <<'NODE'
const fs = require('node:fs');
const [provider, rawPath, lastPath, usagePath] = process.argv.slice(2);
const doc = JSON.parse(fs.readFileSync(rawPath, 'utf8'));
let result = '';
let input = 0;
let cached = 0;
let output = 0;
let cost = null;
if (provider === 'claude') {
  result = doc.result || '';
  const usage = doc.usage || {};
  // Anthropic's input_tokens excludes cache reads and cache writes. Codex
  // counts cached input inside input_tokens, so add both to compare totals.
  cached = Number(usage.cache_read_input_tokens || 0);
  const created = Number(usage.cache_creation_input_tokens || 0);
  input = Number(usage.input_tokens || 0) + cached + created;
  output = Number(usage.output_tokens || 0);
  cost = doc.total_cost_usd ?? null;
} else {
  result = doc.response || doc.result || '';
  const tokens = doc.stats?.models
    ? Object.values(doc.stats.models).map((model) => model.tokens || {})
    : [];
  for (const usage of tokens) {
    input += Number(usage.prompt || usage.input || 0);
    cached += Number(usage.cached || 0);
    output += Number(usage.candidates || usage.output || 0);
  }
}
fs.writeFileSync(lastPath, result);
const lines = [
  `usage_source=${input || output ? 'cli-json' : 'unavailable'}`,
  `input_tokens=${input}`,
  `cached_input_tokens=${cached}`,
  `output_tokens=${output}`,
  `total_tokens=${input + output}`,
];
if (cost !== null) lines.push(`cost_usd=${cost}`);
fs.writeFileSync(usagePath, `${lines.join('\n')}\n`);
NODE

if [ "$ARM" = "skill" ]; then
  prompt_kind="skill-request"
elif [ "$PROMPT_SOURCE" = "$CASE_DIR/REQUEST.baseline.md" ]; then
  prompt_kind="neutral-baseline-request"
else
  prompt_kind="fallback-skill-phrased-request-UNFAIR"
fi
if [ "$PROVIDER" = "claude" ]; then
  customization_mode="safe-mode"
else
  customization_mode="workspace-scoped"
fi
printf '%s\n' \
  "runner=$PROVIDER" \
  "arm=$ARM" \
  "authentication=host-cli" \
  "customization_mode=$customization_mode" \
  "prompt=$prompt_kind" \
  "cli_version=$("$PROVIDER" --version 2>/dev/null | head -1)" \
  "model=$MODEL" \
  "reasoning_effort=$EFFORT" \
  > "$OUTPUT_DIR/RUNNER.txt"
sed -n '1,$p' "$USAGE" >> "$OUTPUT_DIR/RUNNER.txt"

# Print the plan the control wrote, preferring the path the neutral request
# names (PLAN.md) and never taking an INPUT fixture the control left unchanged
# (a replan case's prior .godplans/PLAN.mdx) as its own plan.
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
    if [ "$ARM" = "skill" ]; then
      [ -s "$WORK/.godplans/PLAN.mdx" ] || { echo "$PROVIDER did not emit PLAN.mdx" >&2; exit 1; }
      [ -s "$WORK/.godplans/PLAN.json" ] || { echo "$PROVIDER did not emit PLAN.json" >&2; exit 1; }
      [ -x "$WORK/.godplans/validate-plan.sh" ] || { echo "$PROVIDER did not emit an executable validator" >&2; exit 1; }
      cmp -s "$ROOT/skills/godplans/scripts/validate-plan.sh" "$WORK/.godplans/validate-plan.sh" || {
        echo "$PROVIDER emitted a validator that differs from the shipped source" >&2
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
        echo "$PROVIDER emitted a stale PLAN.json sidecar" >&2
        exit 1
      }
      cp "$WORK/.godplans/PLAN.mdx" "$OUTPUT"
      cp "$WORK/.godplans/PLAN.json" "$OUTPUT_DIR/PLAN.json"
      cp "$WORK/.godplans/validate-plan.sh" "$OUTPUT_DIR/validate-plan.sh"
    elif plan=$(control_plan); then
      cp "$plan" "$OUTPUT"
    else
      cp "$LAST" "$OUTPUT" 2>/dev/null || : > "$OUTPUT"
    fi
    ;;
  */RESPONSE.md)
    if [ "$ARM" = "skill" ] && [ -e "$WORK/.godplans/PLAN.mdx" ]; then
      echo "$PROVIDER emitted a plan for a refusal case" >&2
      exit 1
    fi
    if [ "$ARM" = "baseline" ] && plan=$(control_plan); then
      # The control planned a request it should have refused. Record the plan
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
