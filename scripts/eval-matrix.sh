#!/usr/bin/env bash
# Run the full behavioral matrix across three host-authenticated model families.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# The matrix is always the full roster. eval.sh is handed this path explicitly
# so an exported GODPLANS_EVAL_CASES cannot shrink a published run.
CASES="$ROOT/evals/cases"
ROSTER="$ROOT/evals/cases-roster.txt"
PROFILES="${GODPLANS_MATRIX_PROFILES:-codex claude gemini}"
OUTPUT=""
CHECK_ONLY=0

usage() {
  cat <<'USAGE'
Usage: bash scripts/eval-matrix.sh [--check] [--output DIRECTORY]

Runs every behavioral case listed in evals/cases-roster.txt, skill and neutral
control arms, for the Codex, Claude, and Gemini runner families. The case
directories under evals/cases/ must match the roster exactly. Raw artifacts and
summaries are retained under evals/results/ by default. A failing case or
runner in one family still lets the other families run; the command then exits
non-zero.
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

# The committed roster is the expected case set. Deriving it from the
# directories alone would let a deleted, renamed, or sparse-checkout-missing
# case shrink the published case count without any error, so the directories
# on disk must match the roster exactly, in both directions.
[ -d "$CASES" ] || { echo "case directory not found: $CASES" >&2; exit 1; }
[ -f "$ROSTER" ] || { echo "case roster not found: $ROSTER" >&2; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' "$ROSTER" |
  grep -v '^$' > "$WORK/roster.raw" || true
roster_ok=1
while IFS= read -r case_name; do
  if ! printf '%s\n' "$case_name" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._-]*$'; then
    echo "invalid case name in evals/cases-roster.txt: $case_name" >&2
    roster_ok=0
  fi
done < "$WORK/roster.raw"
LC_ALL=C sort "$WORK/roster.raw" > "$WORK/roster"
LC_ALL=C sort -u "$WORK/roster" > "$WORK/roster.unique"
find "$CASES" -mindepth 1 -maxdepth 1 -type d -print | sed 's|.*/||' | LC_ALL=C sort > "$WORK/disk"
LC_ALL=C uniq -d "$WORK/roster" > "$WORK/duplicate"
LC_ALL=C comm -23 "$WORK/disk" "$WORK/roster.unique" > "$WORK/unlisted"
LC_ALL=C comm -13 "$WORK/disk" "$WORK/roster.unique" > "$WORK/missing"
while IFS= read -r case_name; do
  echo "duplicate case in evals/cases-roster.txt: $case_name" >&2
  roster_ok=0
done < "$WORK/duplicate"
while IFS= read -r case_name; do
  echo "case directory evals/cases/$case_name is not in evals/cases-roster.txt" >&2
  roster_ok=0
done < "$WORK/unlisted"
while IFS= read -r case_name; do
  echo "evals/cases-roster.txt lists $case_name, but evals/cases/$case_name does not exist" >&2
  roster_ok=0
done < "$WORK/missing"
[ "$roster_ok" -eq 1 ] || exit 1
[ -s "$WORK/roster.unique" ] || { echo "evals/cases-roster.txt lists no cases" >&2; exit 1; }

# Each case must carry everything both arms read; a half-added case fails here
# instead of surfacing later as a missing arm.
while IFS= read -r case_name; do
  for required in REQUEST.md REQUEST.baseline.md EXPECTATIONS; do
    [ -f "$CASES/$case_name/$required" ] || {
      echo "matrix case $case_name is incomplete: missing $required" >&2
      exit 1
    }
  done
done < "$WORK/roster.unique"
GODPLANS_EVAL_CASES="$CASES" bash "$ROOT/scripts/eval.sh" --check-cases >/dev/null

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
# A summary left by an earlier run into the same directory must not stand in
# for this one if it fails.
rm -f "$OUTPUT/MATRIX.json" "$OUTPUT/MATRIX.md"

# eval.sh exits non-zero on any failing case. Record that per profile instead
# of letting set -e discard the families that have not run yet.
status=0
for profile in $PROFILES; do
  profile_output="$OUTPUT/$profile"
  mkdir -p "$profile_output"
  GODPLANS_EVAL_CASES="$CASES" \
  GODPLANS_EVAL_RUNNER="$ROOT/evals/runners/$profile.sh" \
  GODPLANS_EVAL_BASELINE_RUNNER="$ROOT/evals/runners/$profile-baseline.sh" \
    bash "$ROOT/scripts/eval.sh" --baseline --output "$profile_output" \
    | tee "$profile_output/EVAL.tsv" || status=1
done

# The summarizer rejects a profile that lacks either arm for any case, so a
# missing run fails the matrix instead of publishing a partial one.
node "$ROOT/scripts/summarize-matrix.js" "$OUTPUT" $PROFILES || status=1
if [ "$status" -eq 0 ]; then
  echo "ok   $OUTPUT"
else
  echo "FAIL [eval-matrix] at least one family failed; per-family rows are under $OUTPUT" >&2
fi
exit "$status"
