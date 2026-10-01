#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$REPO_DIR/scripts/build-prompt.sh"
# Every build goes to a scratch path. The test asserts on a fresh build; lint
# prompt-fresh owns the comparison with the committed PROMPT.md, so a test run
# must never rewrite the tracked file or leave files in the repository.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
PROMPT="$TMP/PROMPT.md"
FULL_PROMPT="$TMP/PROMPT.full.md"
STAMP="$TMP/stamp"

fail() {
  echo "FAIL [portable-prompt] $*" >&2
  exit 1
}

marker_count() {
  grep -Fxc "$1" "$PROMPT" || true
}

assert_marker_once() {
  marker=$1
  count=$(marker_count "$marker")
  [ "$count" -eq 1 ] || fail "expected marker once, found $count: $marker"
}

expected_refs="
compliance
discovery
product
architecture
stack
database
security
exemplar
plan-format
"

lazy_refs="
business
llm
ux
ui
seo
code-quality
style-genome
agent-memory
repo
build
roadmap
deploy
observe
launch
"

touch "$STAMP"
# A one-second gap lets a filesystem with whole-second mtimes see a later write.
sleep 1
GODPLANS_PROMPT_OUT="$PROMPT" bash "$BUILD" >/dev/null

previous_line=0
for ref in $expected_refs; do
  marker="# INLINED REFERENCE: references/$ref.md"
  assert_marker_once "$marker"
  title=$(sed -n '1p' "$REPO_DIR/skills/godplans/references/$ref.md")
  title_count=$(marker_count "$title")
  [ "$title_count" -eq 1 ] || fail "expected module title once, found $title_count: $title"
  line=$(grep -Fnx "$marker" "$PROMPT" | cut -d: -f1)
  [ "$line" -gt "$previous_line" ] || fail "reference order is not workflow order at $ref"
  previous_line=$line
done

for ref in $lazy_refs; do
  marker="# INLINED REFERENCE: references/$ref.md"
  count=$(marker_count "$marker")
  [ "$count" -eq 0 ] || fail "lazy module was inlined into the core: $ref"
  grep -Fq "references/$ref.md" "$PROMPT" ||
    fail "portable core does not route to lazy module: $ref"
done

template_marker="# INLINED TEMPLATE: templates/PLAN.template.mdx"
assert_marker_once "$template_marker"
template_title="# PROJECT-NAME master plan"
template_title_count=$(marker_count "$template_title")
[ "$template_title_count" -eq 1 ] || fail "expected template content once, found $template_title_count"
template_line=$(grep -Fnx "$template_marker" "$PROMPT" | cut -d: -f1)
[ "$template_line" -gt "$previous_line" ] || fail "template does not follow plan-format"

validator_marker="# INLINED VALIDATOR: scripts/validate-plan.sh"
assert_marker_once "$validator_marker"
validator_line=$(grep -Fnx "$validator_marker" "$PROMPT" | cut -d: -f1)
[ "$validator_line" -gt "$template_line" ] || fail "validator does not follow the template"
validator_shebangs=$(grep -Fxc '#!/usr/bin/env bash' "$PROMPT" || true)
[ "$validator_shebangs" -eq 2 ] || fail "expected validator and metric script shebangs, found $validator_shebangs"

halflife_marker="# INLINED SCRIPT: scripts/plan-halflife.sh"
assert_marker_once "$halflife_marker"
halflife_line=$(grep -Fnx "$halflife_marker" "$PROMPT" | cut -d: -f1)
[ "$halflife_line" -gt "$validator_line" ] || fail "plan half-life script does not follow the validator"

grep -Fq 'Weekend plans have at most 3 phases and 8 tasks.' "$PROMPT" ||
  fail "portable prompt is missing the weekend scale ceiling"
grep -Fq 'Create the validator companion before drafting the plan.' "$PROMPT" ||
  fail "portable prompt is missing the pre-draft companion gate"
grep -Fq 'Pick product form before archetype and domain composition.' "$PROMPT" ||
  fail "portable prompt is missing product-form routing"
grep -Fq 'expected exactly one ## Plan provenance section' "$PROMPT" ||
  fail "portable prompt is missing provenance validation"

# The budget exists to make growth visible, not to be raised whenever it fires.
# The invariant it encodes: headroom stays under one core module, so a
# module-sized addition trips the gate instead of sliding past it, while an
# ordinary edit does not. The number is derived from that rule, not chosen.
#
# Raised at 1.11.0: archetype scoring and overlays into discovery, the
# documentation-set and exclusion-tripwire grammar into plan-format, and roughly
# 25 KB of machine checks into the validator, which the core inlines whole
# because the portable surface has no skill files to read. That left 9 KB.
#
# Raised at 1.12.1, to 337000. 1.12.0 added the four capacity requirements to
# architecture and paid the gate's price first: the requirement prose was
# compressed and four task seeds consolidated into two, roughly 3 KB cut before
# the number moved. What remained was 53 bytes of headroom, at which point the
# gate could no longer tell a new module from a typo and failed CI on any edit
# at all. A gate that fires on everything measures nothing. 337000 restores
# 7053 bytes against a 7070-byte smallest core module (compliance), which is
# the invariant above, stated in bytes.
#
# Raised at 1.14.0, to 347923. That release closed roughly 25 validator gaps
# (about 3.6 KB of checks the core inlines whole) and wired the business domain
# into the orchestrator, discovery, the template, and the validator tables
# (about 1.5 KB; the business module itself stays lazy). It paid first: the
# Phase 5b failure-class list became a pointer to the exemplar gate it
# duplicated, and the plan-format machine-checks summary was regrouped, about
# 2.2 KB cut. 347923 leaves 7053 bytes against compliance at 7070 again.
#
# Before moving it a fourth time: cut content or drop a module first, then set
# the number so headroom lands just under the smallest core module again. Print
# the module sizes with `npm run metrics:context` and read them out of
# evals/metrics/context-cost.json rather than guessing.
prompt_bytes=$(wc -c < "$PROMPT" | tr -d ' ')
[ "$prompt_bytes" -le 347923 ] || fail "portable core exceeds 347923-byte budget: $prompt_bytes"

unresolved_paths() {
  sed '/^# INLINED REFERENCE: /d; /^# INLINED TEMPLATE: /d; /^# INLINED VALIDATOR: /d; /^# INLINED SCRIPT: /d' "$1" |
    grep -En 'templates/PLAN\.template\.mdx|skills/godplans/scripts/validate-plan\.sh|scripts/plan-halflife\.sh|(^|[^[:alnum:]-])plan-format\.md([^[:alnum:]-]|$)' || true
}

# A portable reader has no skill checkout, so it can run the half-life script
# only from where the prompt tells it to save the inlined copy: beside the
# validator companion that the script calls as its sibling.
assert_halflife_portable() {
  label=$1
  file=$2
  tr '\n' ' ' < "$file" | grep -Fq 'save the inlined plan half-life script as `.godplans/plan-halflife.sh`' ||
    fail "$label prompt does not say where to save the plan half-life script"
  grep -Fq '`bash .godplans/plan-halflife.sh .godplans/PLAN.mdx .godplans/PLAN.metrics.json`' "$file" ||
    fail "$label prompt does not run the saved plan half-life script"
}

unresolved=$(unresolved_paths "$PROMPT")
[ -z "$unresolved" ] || fail "unresolved required local reference remains:\n$unresolved"
assert_halflife_portable core "$PROMPT"

# The header lists what the core inlines, and compliance comes first.
sed -n '1,/^---$/p' "$PROMPT" | tr '\n' ' ' | grep -Fq 'This slim core includes compliance,' ||
  fail "core header does not list the inlined compliance module"

bash "$BUILD" --output "$TMP/PROMPT.second.md" >/dev/null
cmp -s "$PROMPT" "$TMP/PROMPT.second.md" || fail "regeneration is not deterministic"

bash "$BUILD" --full --output "$FULL_PROMPT" >/dev/null
for ref in $expected_refs $lazy_refs; do
  grep -Fqx "# INLINED REFERENCE: references/$ref.md" "$FULL_PROMPT" ||
    fail "full prompt is missing module: $ref"
done
unresolved=$(unresolved_paths "$FULL_PROMPT")
[ -z "$unresolved" ] || fail "unresolved required local reference remains in the full prompt:\n$unresolved"
assert_halflife_portable full "$FULL_PROMPT"

# A rewritten "the inlined X reference" must point at a module this prompt
# actually inlines; the generic full-mode rewrite would otherwise turn a path
# to a file outside the skill into a reference to nothing.
for file in "$PROMPT" "$FULL_PROMPT"; do
  for name in $(grep -o 'the inlined [a-z-]* reference' "$file" | awk '{print $3}' | sort -u); do
    grep -Fqx "# INLINED REFERENCE: references/$name.md" "$file" ||
      fail "${file##*/} says 'the inlined $name reference' but inlines no references/$name.md"
  done
done

for written in "$REPO_DIR/PROMPT.md" "$REPO_DIR/PROMPT.full.md"; do
  if [ -e "$written" ] && [ -n "$(find "$written" -newer "$STAMP")" ]; then
    fail "test run rewrote ${written#"$REPO_DIR"/}"
  fi
done
[ ! -e "$REPO_DIR/PROMPT.full.test.md" ] || fail "test run left PROMPT.full.test.md in the repository"

echo "ok   [portable-prompt]"
