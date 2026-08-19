#!/usr/bin/env bash
# Run the full behavioral matrix across three host-authenticated model families.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROFILES="${GODPLANS_MATRIX_PROFILES:-codex claude gemini}"
OUTPUT=""
CHECK_ONLY=0

usage() {
  cat <<'USAGE'
Usage: bash scripts/eval-matrix.sh [--check] [--output DIRECTORY]

Runs all eleven behavioral cases, skill and neutral control arms, for the Codex,
Claude, and Gemini runner families. Raw artifacts and summaries are retained
under evals/results/ by default.
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) CHECK_ONLY=1 ;;
    --output)
      shift
      [ "$#" -gt 0 ] || { echo "--output needs a directory" >&2; exit 2; }
      OUTPUT=$1
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

case_count=$(find "$ROOT/evals/cases" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
[ "$case_count" -eq 11 ] || {
  echo "matrix requires exactly 11 cases, found $case_count" >&2
  exit 1
}

profile_count=0
seen_profiles=" "
for profile in $PROFILES; do
  if ! printf '%s\n' "$profile" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
    echo "invalid matrix profile name: $profile" >&2
    exit 2
  fi
  case "$seen_profiles" in
    *" $profile "*) echo "duplicate matrix profile: $profile" >&2; exit 2 ;;
  esac
  seen_profiles="$seen_profiles$profile "
  profile_count=$((profile_count + 1))
  skill_runner="$ROOT/evals/runners/$profile.sh"
  control_runner="$ROOT/evals/runners/$profile-baseline.sh"
  [ -x "$skill_runner" ] || { echo "missing runner: $skill_runner" >&2; exit 1; }
  [ -x "$control_runner" ] || { echo "missing runner: $control_runner" >&2; exit 1; }
  bash -n "$skill_runner"
  bash -n "$control_runner"
done
[ "$profile_count" -ge 3 ] || {
  echo "matrix requires at least three model-family profiles" >&2
  exit 1
}

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "ok   [eval-matrix]"
  exit 0
fi

# Runner authentication belongs to the host. The skill and this coordinator
# never require, read, or prescribe provider credentials.
for profile in $PROFILES; do
  case "$profile" in
    codex)
      command -v codex >/dev/null 2>&1 || { echo "codex CLI not found" >&2; exit 2; }
      ;;
    claude)
      command -v claude >/dev/null 2>&1 || { echo "claude CLI not found" >&2; exit 2; }
      ;;
    gemini)
      command -v gemini >/dev/null 2>&1 || { echo "gemini CLI not found" >&2; exit 2; }
      ;;
    *)
      # Custom profiles own their capability and authentication preflight.
      ;;
  esac
done

if [ -z "$OUTPUT" ]; then
  revision=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo no-git)
  run_date=$(date -u +%Y-%m-%d)
  OUTPUT="$ROOT/evals/results/$run_date-$revision"
fi
mkdir -p "$OUTPUT"

for profile in $PROFILES; do
  profile_output="$OUTPUT/$profile"
  mkdir -p "$profile_output"
  GODPLANS_EVAL_RUNNER="$ROOT/evals/runners/$profile.sh" \
  GODPLANS_EVAL_BASELINE_RUNNER="$ROOT/evals/runners/$profile-baseline.sh" \
    bash "$ROOT/scripts/eval.sh" --baseline --output "$profile_output" \
    | tee "$profile_output/EVAL.tsv"
done

node "$ROOT/scripts/summarize-matrix.js" "$OUTPUT" $PROFILES
echo "ok   $OUTPUT"
