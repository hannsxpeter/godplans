#!/usr/bin/env bash
# Host-authenticated no-skill judge for blind external plan packets.

set -euo pipefail

[ $# -eq 2 ] || { echo "usage: $0 PACKET.md GRADE.json" >&2; exit 2; }
PROVIDER="${GODPLANS_GRADE_PROVIDER:-}"
PACKET=$1
OUTPUT=$2
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
RAW="$(mktemp)"
LOG="$(dirname "$OUTPUT")/$(basename "$OUTPUT" .json).$PROVIDER.log"
trap 'rm -rf "$WORK"; rm -f "$RAW"' EXIT

case "$PROVIDER" in claude|gemini) ;; *)
  echo "GODPLANS_GRADE_PROVIDER must be claude or gemini" >&2
  exit 2
  ;;
esac

if [ "$PROVIDER" = "gemini" ]; then
  mkdir -p "$WORK/.gemini"
  printf '%s\n' '{"skills":{"enabled":false},"hooksConfig":{"enabled":false}}' \
    > "$WORK/.gemini/settings.json"
fi

PROMPT="You are an independent blind evaluator. No planning or audit skill is installed. Read the packet, apply its rubric exactly, and return only one JSON object that matches the packet's Required JSON schema."
set +e
if [ "$PROVIDER" = "claude" ]; then
  MODEL="${GODPLANS_GRADE_CLAUDE_MODEL:-sonnet}"
  (
    cd "$WORK"
    claude -p \
      --safe-mode \
      --disable-slash-commands \
      --tools "" \
      --output-format json \
      --json-schema "$(tr -d '\n' < "$ROOT/evals/external/GRADE.schema.json")" \
      --model "$MODEL" \
      "$PROMPT

$(sed -n '1,$p' "$PACKET")"
  ) >"$RAW" 2>"$LOG"
  STATUS=$?
else
  MODEL="${GODPLANS_GRADE_GEMINI_MODEL:-gemini-2.5-pro}"
  (
    cd "$WORK"
    gemini \
      --approval-mode plan \
      --output-format json \
      --model "$MODEL" \
      --prompt "$PROMPT Return no Markdown fences.

$(sed -n '1,$p' "$PACKET")"
  ) >"$RAW" 2>"$LOG"
  STATUS=$?
fi
set -e
[ "$STATUS" -eq 0 ] || { tail -n 40 "$LOG" >&2; exit "$STATUS"; }

node - "$PROVIDER" "$RAW" "$OUTPUT" <<'NODE'
const fs = require('node:fs');
const [provider, rawPath, outputPath] = process.argv.slice(2);
const raw = JSON.parse(fs.readFileSync(rawPath, 'utf8'));
let value = provider === 'claude' ? raw.structured_output || raw.result : raw.response || raw.result;
if (typeof value === 'string') {
  value = value.trim().replace(/^```json\s*/, '').replace(/```\s*$/, '');
  value = JSON.parse(value);
}
fs.writeFileSync(outputPath, `${JSON.stringify(value, null, 2)}\n`);
NODE

printf '%s\n' \
  "runner=$PROVIDER-grade" \
  "arm=blind-judge" \
  "authentication=host-cli" \
  "customization_mode=$([ "$PROVIDER" = "claude" ] && printf safe-mode || printf workspace-scoped)" \
  "cli_version=$("$PROVIDER" --version 2>/dev/null | head -1)" \
  "model=$MODEL" \
  > "$(dirname "$OUTPUT")/$(basename "$OUTPUT" .json).RUNNER.txt"
