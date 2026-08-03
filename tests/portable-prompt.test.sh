#!/usr/bin/env bash

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT="$REPO_DIR/PROMPT.md"
BUILD="$REPO_DIR/scripts/build-prompt.sh"

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

bash "$BUILD" >/dev/null

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
# Before moving it a third time: cut content or drop a module first, then set
# the number so headroom lands just under the smallest core module again. Print
# the module sizes with `npm run metrics:context` and read them out of
# evals/metrics/context-cost.json rather than guessing.
prompt_bytes=$(wc -c < "$PROMPT" | tr -d ' ')
[ "$prompt_bytes" -le 337000 ] || fail "portable core exceeds 337000-byte budget: $prompt_bytes"

unresolved=$(sed '/^# INLINED REFERENCE: /d; /^# INLINED TEMPLATE: /d; /^# INLINED VALIDATOR: /d' "$PROMPT" |
  grep -En 'templates/PLAN\.template\.mdx|skills/godplans/scripts/validate-plan\.sh|(^|[^[:alnum:]-])plan-format\.md([^[:alnum:]-]|$)' || true)
[ -z "$unresolved" ] || fail "unresolved required local reference remains:\n$unresolved"

first_hash=$(shasum -a 256 "$PROMPT" | awk '{print $1}')
bash "$BUILD" >/dev/null
second_hash=$(shasum -a 256 "$PROMPT" | awk '{print $1}')
[ "$first_hash" = "$second_hash" ] || fail "regeneration is not deterministic"

FULL_PROMPT="$REPO_DIR/PROMPT.full.test.md"
trap 'rm -f "$FULL_PROMPT"' EXIT
bash "$BUILD" --full --output "$FULL_PROMPT" >/dev/null
for ref in $expected_refs $lazy_refs; do
  grep -Fqx "# INLINED REFERENCE: references/$ref.md" "$FULL_PROMPT" ||
    fail "full prompt is missing module: $ref"
done

echo "ok   [portable-prompt]"
