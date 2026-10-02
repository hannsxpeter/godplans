#!/usr/bin/env bash
# Run godplans behavioral cases through any compatible agent runner.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="${GODPLANS_EVAL_CASES:-$ROOT/evals/cases}"
RUNNER="${GODPLANS_EVAL_RUNNER:-}"
BASELINE_RUNNER="${GODPLANS_EVAL_BASELINE_RUNNER:-}"
VALIDATOR="${GODPLANS_VALIDATOR:-$ROOT/skills/godplans/scripts/validate-plan.sh}"
OUTPUT="$ROOT/evals/output"
CHECK_ONLY=0
SCORE_ONLY=0
BASELINE=0
SELECTED=""

usage() {
  cat <<'USAGE'
Usage: bash scripts/eval.sh [options] [case ...]

Run behavioral cases through GODPLANS_EVAL_RUNNER and score the artifacts.

Options:
  --check-cases       Validate case manifests without running an agent.
  --score-only        Rescore artifacts already present under --output.
  --baseline          Also run each case through GODPLANS_EVAL_BASELINE_RUNNER
                      (the same agent and model with no godplans skill loaded)
                      and score it against the same expectations. Reports the
                      per-case and aggregate delta. The baseline arm is a
                      measurement, never a gate: it cannot fail the run.
  --output DIRECTORY  Read or write evaluation artifacts in DIRECTORY.
  -h, --help          Show this help.

Without --baseline the harness proves conformance to godplans' own
expectations. It cannot show that a godplans plan beats what the same agent
produces unaided. That claim requires the control arm.
USAGE
}

die() {
  echo "eval: $*" >&2
  exit 2
}

append_selected() {
  if [ -z "$SELECTED" ]; then
    SELECTED=$1
  else
    SELECTED="$SELECTED $1"
  fi
}

while [ $# -gt 0 ]; do
  case "$1" in
    --check-cases) CHECK_ONLY=1 ;;
    --score-only) SCORE_ONLY=1 ;;
    --baseline) BASELINE=1 ;;
    --output)
      [ $# -gt 1 ] || die "--output needs a directory"
      OUTPUT=$2
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    --*) die "unknown option: $1" ;;
    *) append_selected "$1" ;;
  esac
  shift
done

[ -d "$CASES" ] || die "case directory not found: $CASES"

case_dirs() {
  if [ -n "$SELECTED" ]; then
    for id in $SELECTED; do
      [ -d "$CASES/$id" ] || die "unknown case: $id"
      printf '%s\n' "$CASES/$id"
    done
  else
    find "$CASES" -mindepth 1 -maxdepth 1 -type d -print | LC_ALL=C sort
  fi
}

validate_expectations() {
  file=$1
  outcome_count=0
  # read fails on a final line with no newline; the second test keeps it.
  while IFS='|' read -r op arg value || [ -n "$op$arg$value" ]; do
    case "$op" in
      ''|'#'*) continue ;;
      outcome)
        case "$arg" in plan|refusal) ;; *) return 1 ;; esac
        outcome_count=$((outcome_count + 1))
        ;;
      frontmatter|domain)
        [ -n "$arg" ] && [ -n "$value" ] || return 1
        ;;
      gate)
        [ -n "$arg" ] && [ -n "$value" ] || return 1
        ;;
      contains|contains-ci|not-contains)
        [ -n "$arg" ] || return 1
        ;;
      max-count)
        [ -n "$arg" ] || return 1
        case "$value" in ''|*[!0-9]*) return 1 ;; esac
        ;;
      *) return 1 ;;
    esac
  done < "$file"
  [ "$outcome_count" -eq 1 ]
}

# Score one artifact against one EXPECTATIONS file. Sets SCORE_PASSED and
# SCORE_TOTAL. Emits MISS lines on stderr only when a report label is given,
# so the baseline arm stays quiet: its misses are the measurement, not a fault.
score_artifact() {
  score_artifact_path=$1
  score_expectations=$2
  score_report_label=${3:-}
  SCORE_PASSED=0
  SCORE_TOTAL=0

  while IFS='|' read -r op arg value || [ -n "$op$arg$value" ]; do
    case "$op" in ''|'#'*) continue ;; esac
    SCORE_TOTAL=$((SCORE_TOTAL + 1))
    ok=0
    if [ -s "$score_artifact_path" ]; then
      case "$op" in
        outcome)
          if [ "$arg" = "plan" ]; then
            "$VALIDATOR" --allow-planning "$score_artifact_path" >/dev/null 2>&1 && ok=1
          else
            ok=1
          fi
          ;;
        frontmatter)
          grep -Eq "^${arg}:[[:space:]]*${value}[[:space:]]*$" "$score_artifact_path" && ok=1
          ;;
        domain)
          grep -Eq "^[|][[:space:]]*${arg}[[:space:]]*[|][[:space:]]*${value}[[:space:]]*[|]" "$score_artifact_path" && ok=1
          ;;
        contains)
          grep -Fq -- "$arg" "$score_artifact_path" && ok=1
          ;;
        contains-ci)
          grep -Fiq -- "$arg" "$score_artifact_path" && ok=1
          ;;
        not-contains)
          if ! grep -Fq -- "$arg" "$score_artifact_path"; then ok=1; fi
          ;;
        max-count)
          count=$(grep -Fc -- "$arg" "$score_artifact_path" || true)
          [ "$count" -le "$value" ] && ok=1
          ;;
        gate)
          grep -Fq -- "$value" "$score_artifact_path" && ok=1
          ;;
      esac
    elif [ "$op" = "not-contains" ]; then
      # A missing artifact trivially lacks the string. Credit it so an empty
      # baseline cannot score points for producing nothing at all.
      ok=1
    fi

    if [ "$ok" -eq 1 ]; then
      SCORE_PASSED=$((SCORE_PASSED + 1))
    elif [ -n "$score_report_label" ]; then
      printf '%s\tMISS\t%s|%s|%s\n' "$score_report_label" "$op" "$arg" "$value" >&2
    fi
  done < "$score_expectations"
}

# Skill minus control, with an explicit sign so a loss never reads as "+-N".
signed_delta() {
  if [ "$1" -ge 0 ]; then
    printf '+%s' "$1"
  else
    printf '%s' "$1"
  fi
}

CASE_LIST=$(mktemp)
trap 'rm -f "$CASE_LIST"' EXIT
case_dirs > "$CASE_LIST"

while IFS= read -r dir; do
  [ -f "$dir/REQUEST.md" ] || die "missing REQUEST.md in $dir"
  [ -f "$dir/EXPECTATIONS" ] || die "missing EXPECTATIONS in $dir"
  validate_expectations "$dir/EXPECTATIONS" || die "invalid EXPECTATIONS in $dir"
  expected_outcome=$(awk -F'|' '$1 == "outcome" { print $2; exit }' "$dir/EXPECTATIONS")
  if [ "$expected_outcome" = "plan" ] && grep -Eiq 'PLAN[.]mdx[^[:alnum:]]+only' "$dir/REQUEST.md"; then
    die "plan case contradicts the required validator companion: $dir"
  fi
  # The neutral control request must not leak the skill it is meant to omit.
  # A REQUEST.baseline.md that names godplans, the .godplans path, or the
  # validator companion would hand the control the very format the delta is
  # supposed to measure, so reject it here rather than at run time.
  if [ -f "$dir/REQUEST.baseline.md" ] &&
     grep -Eiq 'godplans|\.godplans|SKILL\.md|validator companion|PLAN\.mdx' "$dir/REQUEST.baseline.md"; then
    die "REQUEST.baseline.md leaks the skill (godplans/.godplans/PLAN.mdx/validator): $dir"
  fi
done < "$CASE_LIST"

if [ "$CHECK_ONLY" -eq 1 ]; then
  echo "ok   [eval-cases]"
  exit 0
fi

[ -x "$VALIDATOR" ] || die "validator is not executable: $VALIDATOR"
if [ "$SCORE_ONLY" -eq 0 ]; then
  [ -n "$RUNNER" ] || die "set GODPLANS_EVAL_RUNNER to an executable runner"
  [ -x "$RUNNER" ] || die "runner is not executable: $RUNNER"
  if [ "$BASELINE" -eq 1 ]; then
    [ -n "$BASELINE_RUNNER" ] || die "--baseline needs GODPLANS_EVAL_BASELINE_RUNNER"
    [ -x "$BASELINE_RUNNER" ] || die "baseline runner is not executable: $BASELINE_RUNNER"
    [ "$BASELINE_RUNNER" != "$RUNNER" ] || die "baseline runner must not be the skill runner"
  fi
fi

mkdir -p "$OUTPUT"
failed=0
skill_points=0
base_points=0
arm_total=0

while IFS= read -r dir; do
  id=$(basename "$dir")
  expected_outcome=$(awk -F'|' '$1 == "outcome" { print $2; exit }' "$dir/EXPECTATIONS")
  out_dir="$OUTPUT/$id"
  if [ "$SCORE_ONLY" -eq 0 ]; then
    rm -rf "$out_dir"
    mkdir -p "$out_dir"
  fi

  if [ "$expected_outcome" = "plan" ]; then
    artifact="$out_dir/PLAN.mdx"
  else
    artifact="$out_dir/RESPONSE.md"
  fi

  if [ "$SCORE_ONLY" -eq 0 ]; then
    if ! "$RUNNER" "$dir/REQUEST.md" "$artifact"; then
      printf '%s\tFAIL\trunner\n' "$id"
      failed=1
      continue
    fi
  fi

  artifact_set_ok=1
  if [ "$expected_outcome" = "plan" ]; then
    companion="$out_dir/validate-plan.sh"
    sidecar="$out_dir/PLAN.json"
    [ -s "$artifact" ] || artifact_set_ok=0
    [ -x "$companion" ] || artifact_set_ok=0
    [ -s "$sidecar" ] || artifact_set_ok=0
    cmp -s "$VALIDATOR" "$companion" || artifact_set_ok=0
    if [ "$artifact_set_ok" -eq 1 ]; then
      node -e '
        const fs = require("node:fs");
        const crypto = require("node:crypto");
        const plan = fs.readFileSync(process.argv[1]);
        const sidecar = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
        const digest = "sha256:" + crypto.createHash("sha256").update(plan).digest("hex");
        if (sidecar.plan_digest !== digest) process.exit(1);
      ' "$artifact" "$sidecar" || artifact_set_ok=0
    fi
  else
    [ -s "$artifact" ] || artifact_set_ok=0
    [ ! -e "$out_dir/PLAN.mdx" ] || artifact_set_ok=0
  fi
  if [ "$artifact_set_ok" -eq 0 ]; then
    printf '%s\tFAIL\tartifacts\n' "$id"
    failed=1
    continue
  fi

  score_artifact "$artifact" "$dir/EXPECTATIONS" "$id"
  passed=$SCORE_PASSED
  total=$SCORE_TOTAL

  if [ "$passed" -eq "$total" ]; then
    printf '%s\tPASS\t%s/%s\n' "$id" "$passed" "$total"
  else
    printf '%s\tFAIL\t%s/%s\n' "$id" "$passed" "$total"
    failed=1
  fi

  if [ "$BASELINE" -eq 1 ]; then
    base_dir="$out_dir/baseline"
    if [ "$expected_outcome" = "plan" ]; then
      base_artifact="$base_dir/PLAN.mdx"
    else
      base_artifact="$base_dir/RESPONSE.md"
    fi

    if [ "$SCORE_ONLY" -eq 0 ]; then
      rm -rf "$base_dir"
      mkdir -p "$base_dir"
      if ! "$BASELINE_RUNNER" "$dir/REQUEST.md" "$base_artifact"; then
        printf '%s\tBASE\trunner-error\n' "$id"
        continue
      fi
    fi

    score_artifact "$base_artifact" "$dir/EXPECTATIONS" ""
    printf '%s\tBASE\t%s/%s\tdelta %s\n' "$id" "$SCORE_PASSED" "$SCORE_TOTAL" "$(signed_delta "$((passed - SCORE_PASSED))")"
    skill_points=$((skill_points + passed))
    base_points=$((base_points + SCORE_PASSED))
    arm_total=$((arm_total + total))
  fi
done < "$CASE_LIST"

if [ "$BASELINE" -eq 1 ] && [ "$arm_total" -gt 0 ]; then
  printf 'AGGREGATE\tskill %s/%s\tbaseline %s/%s\tdelta %s\n' \
    "$skill_points" "$arm_total" "$base_points" "$arm_total" "$(signed_delta "$((skill_points - base_points))")"
fi

node "$ROOT/scripts/summarize-eval.js" "$OUTPUT"

exit "$failed"
