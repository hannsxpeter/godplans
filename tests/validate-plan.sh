#!/usr/bin/env bash

set -u

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VALIDATOR="$ROOT_DIR/skills/godplans/scripts/validate-plan.sh"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/godplans-validator.XXXXXX")"
PASS_COUNT=0
FAIL_COUNT=0

trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

write_valid_plan() {
  file=$1
  status=$2
  cat > "$file" <<'EOF'
---
name: validator-fixture
plan_version: 1
status: PLAN_STATUS
created: 2026-07-13
updated: 2026-07-13
mode: greenfield
product_form: cli-or-sdk
archetype: cli-tool
archetype_confidence: high
overlays: []
public_release: false
source_revision: none
input_digest: sha256:1c7ca1006bb3157ad989c1f1dd1cd1d6e8e2a44d9509821ffa43f3be205a12d5
validated_at: 2026-07-13T12:00:00Z
domains_applicable: [product, architecture, stack, security, code-quality, style-genome, agent-memory, repo, build, roadmap]
domains_deferred: []
domains_excluded: [database, llm, ux, ui, seo, deploy, observe, launch]
progress:
  phases_total: 2
  phases_done: 0
  tasks_total: 3
  tasks_done: 0
---

# Validator fixture master plan

Done means the validator fixture passes every structural check.

## Scope and non-goals

In scope: validator behavior. Non-goals: application code.

## Plan provenance

Source revision: none
Input digest: sha256:1c7ca1006bb3157ad989c1f1dd1cd1d6e8e2a44d9509821ffa43f3be205a12d5
Validated at: 2026-07-13T12:00:00Z
Evidence inventory:
- `intake` = `sha256:1111111111111111111111111111111111111111111111111111111111111111`

## Product form

Primary: CLI or SDK. A vertical slice runs from command parsing through deterministic output and a consumer fixture.

### Archetype confidence

- Primary: cli-tool (score 0.86)
- Runner-up: library (score 0.29)
- Margin: 57 points
- Confidence: high
- Vetoes applied: none
- Overlays: none
- If the runner-up is right: +1 tasks and +0 phases; the consumer fixture becomes a published API surface check

## Compliance gate

Result: pass.

## Applicability matrix

| Domain | Status | Reason |
|---|---|---|
| product | applicable | fixture requirement |
| architecture | applicable | shell and embedded Perl boundary |
| stack | applicable | stock macOS and Linux toolchain |
| database | excluded | by-design: the validator reads a plan and writes a sidecar, holding no state between runs; revisit when: any task introduces a datastore or a persisted cache |
| security | applicable | execution lifecycle is a safety boundary |
| llm | excluded | by-design: every check is deterministic Perl with no model call; revisit when: any task adds a model SDK dependency or a prompt template |
| ux | excluded | by-design: the only interaction is one command and an exit code; revisit when: the validator gains an interactive or multi-step flow |
| ui | excluded | by-design: output is stdout text with no rendered surface; revisit when: any task adds a rendered view the project owns |
| seo | excluded | by-design: nothing the validator produces is crawlable; revisit when: the project publishes a page a search engine can reach |
| code-quality | applicable | validator coverage |
| style-genome | applicable | portable shell conventions |
| agent-memory | applicable | execution rules travel with the plan |
| repo | applicable | validator ships in the skill package |
| build | applicable | validator is the emitted application artifact |
| roadmap | applicable | fixture tasks exercise ordering |
| deploy | excluded | by-design: the validator ships inside the skill package and is never deployed; revisit when: any task publishes a hosted or installable service |
| observe | excluded | by-design: nothing runs long enough to observe; revisit when: any task adds a long-running process or a scheduled job |
| launch | excluded | by-design: distribution is the skill release, not a public activation; revisit when: public_release flips to true |

### Module disposition

- product: landed R-PRD-1; dropped-by scale R-PRD-9 (fixture scope: no pricing surface to plan)
- architecture: landed R-ARCH-4; dropped-by scale R-ARCH-10 (one shell entry point, no heavy pattern to justify)
- stack: landed R-STACK-1
- security: landed R-SEC-1
- code-quality: landed R-CODE-21
- style-genome: landed R-DNA-14
- agent-memory: landed R-MEM-2
- repo: landed R-REPO-21
- build: landed R-BUILD-1
- roadmap: landed R-ROAD-1

## Decisions

The fixture uses two ordered phases.

### D1: portable runtime boundary

The validator uses Bash 3.2 plus stock Perl instead of a compiled runtime.
Falsifier:
- Signal: Perl availability on every supported platform
- Failure boundary: any supported platform ships without Perl
- Replan action: return to planning and replace the embedded parser with a supported runtime

## Requirements

R-1.1: WHEN validation runs THE SYSTEM SHALL return a reliable exit code.

## Architecture

The shell entry point delegates parsing to portable Perl.

## Style genome

ASCII text and Bash 3.2 compatible shell.

## Agent memory

The plan remains the source of truth.

## Documentation set

This manifest covers documentation committed to this repository. Documents held in a wiki or a compliance platform are marked present-elsewhere.

| Document | Stage | Verdict | Owner | Selected by, or reason and revisit when |
|---|---|---|---|---|
| decide.adr | decide | required | architecture | the portable runtime boundary is D1; written by GP-101 |
| build.readme | build | required | repo | always; written by GP-102 |
| build.style-genome | build | required | style-genome | always; written by GP-102 |
| govern.manifest | govern | required | repo | always; written by GP-102 |
| verify.dod | verify | required | product | always; written by GP-201 |
| operate.runbook | operate | not-applicable | observe | by-design: the validator is a script with no deployed surface to operate; revisit when: any task adds a hosted service or a scheduled job |
| serve.user-guide | serve | not-applicable | launch | absent: no external user was named in intake; revisit when: the validator ships to users outside this repository |

## Phases

## Phase 1: Validator behavior

Goal: validate the core plan contract.

### Wave 1.1

- [ ] GP-101 [W1.1] Parse plan state
  - Files: skills/godplans/scripts/validate-plan.sh
  - Depends on: none
  - Reuses: repository shell conventions
  - Acceptance: frontmatter and counters are checked
  - Verify: `bash tests/validate-plan.sh`
  - Requirements: R-1.1, R-CODE-21, R-ARCH-4, R-STACK-1

- [ ] GP-102 [W1.1] Check task references
  - Files: tests/validate-plan.sh
  - Depends on: GP-101
  - Reuses: validator fixture
  - Acceptance: dependencies and requirement IDs resolve
  - Verify: `bash tests/validate-plan.sh`
  - Requirements: R-1.1, R-CODE-21, R-REPO-21, R-DNA-14

Checkpoint: malformed plans fail with a diagnostic.
Checkpoint verify: `test -x skills/godplans/scripts/validate-plan.sh`

Must-haves:
- Truth: invalid plans return nonzero
- Artifact: skills/godplans/scripts/validate-plan.sh exists
- Link: the regression suite invokes the shipped validator

## Phase 2: Verification

Goal: prove the validator contract end to end.

### Wave 2.1

- [ ] GP-201 [W2.1] Run full validator regression suite
  - Files: tests/validate-plan.sh
  - Depends on: GP-101, GP-102
  - Reuses: repository lint entry point
  - Acceptance: all regression cases pass
  - Verify: `bash tests/validate-plan.sh`
  - Requirements: R-1.1, R-CODE-21, R-ROAD-1, R-BUILD-1, R-MEM-2, R-PRD-1, R-SEC-1

Checkpoint: the portable suite passes from a fresh checkout.
Checkpoint verify: `test -x tests/validate-plan.sh`

Must-haves:
- Truth: the validator reports a valid plan
- Artifact: tests/validate-plan.sh is executable
- Link: plan-format.md points to the validator

## Open Questions

None.

## Rules for executing agents

Only approved or executing plans may be executed.

## Session log

- 2026-07-13 plan created
EOF
  PLAN_STATUS="$status" perl -0pi -e 's/status: PLAN_STATUS/status: $ENV{PLAN_STATUS}/' "$file"
}

record_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'ok   %s\n' "$1"
}

record_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL %s: %s\n' "$1" "$2" >&2
}

expect_pass() {
  name=$1
  shift
  output=$("$VALIDATOR" "$@" 2>&1)
  status=$?
  if [ "$status" -eq 0 ]; then
    record_pass "$name"
  else
    record_fail "$name" "expected success, got $status: $output"
  fi
}

expect_fail() {
  name=$1
  expected=$2
  shift 2
  output=$("$VALIDATOR" "$@" 2>&1)
  status=$?
  if [ "$status" -eq 0 ]; then
    record_fail "$name" "expected failure"
  elif printf '%s\n' "$output" | grep -F "$expected" >/dev/null 2>&1; then
    record_pass "$name"
  else
    record_fail "$name" "missing diagnostic '$expected': $output"
  fi
}

new_case() {
  CASE_NUMBER=$((CASE_NUMBER + 1))
  CASE_FILE="$TMP_DIR/case-$CASE_NUMBER.mdx"
  cp "$BASE_PLAN" "$CASE_FILE"
}

BASE_PLAN="$TMP_DIR/valid-planning.mdx"
CASE_NUMBER=0
write_valid_plan "$BASE_PLAN" planning

expect_pass "planning validation mode" --allow-planning "$BASE_PLAN"
expect_fail "planning execution gate" "requires status approved or executing" "$BASE_PLAN"

TABLE_PLAN="$TMP_DIR/valid-requirements-table.mdx"
cp "$BASE_PLAN" "$TABLE_PLAN"
perl -0pi -e 's/R-1\.1: WHEN validation runs THE SYSTEM SHALL return a reliable exit code\./| ID | Acceptance |\n|---|---|\n| R-1.1 | WHEN validation runs THE SYSTEM SHALL return a reliable exit code. |/' "$TABLE_PLAN"
expect_pass "local requirement in Markdown table" --allow-planning "$TABLE_PLAN"

ISOLATED_DIR="$TMP_DIR/standalone-companion"
mkdir "$ISOLATED_DIR"
cp "$VALIDATOR" "$ISOLATED_DIR/validate-plan.sh"
cp "$BASE_PLAN" "$ISOLATED_DIR/PLAN.mdx"
chmod +x "$ISOLATED_DIR/validate-plan.sh"
REPOSITORY_VALIDATOR="$VALIDATOR"
VALIDATOR="$ISOLATED_DIR/validate-plan.sh"
expect_pass "standalone copied validator" --allow-planning "$ISOLATED_DIR/PLAN.mdx"
VALIDATOR="$REPOSITORY_VALIDATOR"

ACTUAL_CATALOG="$TMP_DIR/actual-catalog"
EMBEDDED_CATALOG="$TMP_DIR/embedded-catalog"
perl -ne '
  $inside = 1, next if /^## Plan requirements\s*$/;
  $inside = 0 if $inside && /^## /;
  if ($inside) {
    while (/(R-([A-Z][A-Z0-9-]*)-([0-9]+))/g) {
      $seen{$2}{$3} = 1;
    }
  }
  if (eof) {
    $inside = 0;
  }
  END {
    for $prefix (sort keys %seen) {
      @numbers = sort { $a <=> $b } keys %{$seen{$prefix}};
      die "catalog gap for $prefix\n" if @numbers != $numbers[-1];
      print "$prefix $numbers[-1]\n";
    }
  }
' "$ROOT_DIR"/skills/godplans/references/*.md > "$ACTUAL_CATALOG"
perl -ne 'print "$1 $2\n" if /^    ([A-Z][A-Z0-9-]*) => ([0-9]+),$/' "$REPOSITORY_VALIDATOR" | sort > "$EMBEDDED_CATALOG"
if diff -u "$ACTUAL_CATALOG" "$EMBEDDED_CATALOG" >/dev/null 2>&1; then
  record_pass "embedded requirement catalog is current"
else
  record_fail "embedded requirement catalog is current" "validator catalog differs from domain modules"
fi

APPROVED_PLAN="$TMP_DIR/valid-approved.mdx"
write_valid_plan "$APPROVED_PLAN" approved
expect_pass "approved execution gate" "$APPROVED_PLAN"

EXECUTING_PLAN="$TMP_DIR/valid-executing.mdx"
write_valid_plan "$EXECUTING_PLAN" executing
expect_pass "executing execution gate" "$EXECUTING_PLAN"

PARTIAL_PLAN="$TMP_DIR/valid-partial.mdx"
write_valid_plan "$PARTIAL_PLAN" executing
perl -0pi -e 's/- \[ \] GP-10/- [x] GP-10/g; s/phases_done: 0/phases_done: 1/; s/tasks_done: 0/tasks_done: 2/' "$PARTIAL_PLAN"
expect_pass "derived completed phase counters" "$PARTIAL_PLAN"

DONE_PLAN="$TMP_DIR/valid-done.mdx"
write_valid_plan "$DONE_PLAN" done
expect_fail "done execution gate" "requires status approved or executing" "$DONE_PLAN"
expect_pass "done structural validation" --allow-planning "$DONE_PLAN"

new_case
perl -0pi -e 's/tasks_total: 3/tasks_total: 4/' "$CASE_FILE"
expect_fail "wrong task total" "tasks_total is 4, derived value is 3" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/tasks_done: 0/tasks_done: 1/' "$CASE_FILE"
expect_fail "wrong task done count" "tasks_done is 1, derived value is 0" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/phases_total: 2/phases_total: 3/' "$CASE_FILE"
expect_fail "wrong phase total" "phases_total is 3, derived value is 2" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/phases_done: 0/phases_done: 1/' "$CASE_FILE"
expect_fail "wrong phase done count" "phases_done is 1, derived value is 0" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/GP-102 \[W1\.1\]/GP-101 [W1.1]/' "$CASE_FILE"
expect_fail "duplicate task definitions" "duplicate task definition ID GP-101" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Phase 2: Verification/## Phase 3: Verification/' "$CASE_FILE"
expect_fail "non-sequential phase numbers" "expected Phase 2, found Phase 3" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/GP-101 \[W1\.1\]/GP-101/' "$CASE_FILE"
expect_fail "missing task wave" "GP-101 has malformed task heading" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/GP-101 \[W1\.1\]/GP-101 [W2.1]/' "$CASE_FILE"
expect_fail "task wave phase mismatch" "GP-101 wave phase 2 does not match Phase 1" --allow-planning "$CASE_FILE"

for field in Files "Depends on" Reuses Acceptance Verify Requirements; do
  new_case
  FIELD="$field" perl -0pi -e 's/^  - \Q$ENV{FIELD}\E:.*\n//m' "$CASE_FILE"
  expect_fail "missing $field field" "GP-101 missing required field: $field" --allow-planning "$CASE_FILE"
done

new_case
perl -0pi -e 's/Verify: `bash tests\/validate-plan\.sh`/Verify: Manual: open the report/' "$CASE_FILE"
expect_fail "manual task verification" "Verify must be one executable command in backticks" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Depends on: GP-101/Depends on: GP-999/' "$CASE_FILE"
expect_fail "unknown dependency" "GP-102 depends on undefined task GP-999" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Depends on: none/Depends on: GP-201/' "$CASE_FILE"
expect_fail "forward dependency" "GP-101 depends on later task GP-201" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Depends on: GP-101/Depends on: sometimes GP-101/' "$CASE_FILE"
expect_fail "malformed dependency" "GP-102 has malformed Depends on value" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/(- \[ \] GP-101.*?  - Requirements: )[^\n]+/$1R-1.1, R-NOPE-1/s' "$CASE_FILE"
expect_fail "unknown domain requirement" "undefined requirement R-NOPE-1" --allow-planning "$CASE_FILE"

new_case
CODE_MAX=$(perl -ne 'print $1 if /^\s+CODE => (\d+),/' "$REPOSITORY_VALIDATOR")
CODE_OOR="R-CODE-$((CODE_MAX + 1))"
perl -0pi -e "s/R-CODE-21/$CODE_OOR/" "$CASE_FILE"
expect_fail "out-of-range domain requirement" "undefined requirement $CODE_OOR" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/R-1\.1, R-CODE-21/R-9.9, R-CODE-21/' "$CASE_FILE"
expect_fail "unknown local requirement" "undefined requirement R-9.9" --allow-planning "$CASE_FILE"

new_case
perl -CSD -e 'print chr(0x2014), "\n"' >> "$CASE_FILE"
expect_fail "banned Unicode" "banned Unicode" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Open Questions\n/## Questions\n/' "$CASE_FILE"
expect_fail "missing Open Questions" "expected exactly one ## Open Questions section, found 0" --allow-planning "$CASE_FILE"

new_case
printf '\n## Open Questions\n\nDuplicate.\n' >> "$CASE_FILE"
expect_fail "duplicate Open Questions" "expected exactly one ## Open Questions section, found 2" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Phase 2: Verification/## Phase 2: Release/' "$CASE_FILE"
expect_fail "missing final Verification phase" "final phase must be Verification" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^name:.*\n//m' "$CASE_FILE"
expect_fail "missing frontmatter field" "missing frontmatter field: name" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^  tasks_done:.*\n//m' "$CASE_FILE"
expect_fail "missing progress counter" "missing progress counter: tasks_done" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/plan_version: 1/plan_version: zero/' "$CASE_FILE"
expect_fail "invalid plan version" "plan_version must be a positive integer" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/updated: 2026-07-13/updated: July 13/' "$CASE_FILE"
expect_fail "invalid updated date" "updated must use YYYY-MM-DD" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/status: planning/status: paused/' "$CASE_FILE"
expect_fail "invalid lifecycle status" "invalid status 'paused'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/mode: greenfield/mode: rewrite/' "$CASE_FILE"
expect_fail "invalid plan mode" "invalid mode 'rewrite'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/product_form: cli-or-sdk/product_form: website/' "$CASE_FILE"
expect_fail "invalid product form" "invalid product_form 'website'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/public_release: false/public_release: maybe/' "$CASE_FILE"
expect_fail "invalid public release flag" "public_release must be true or false" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/R-1\.1, R-CODE-21/R-1.1, R-SEC-26/' "$CASE_FILE"
expect_fail "non-public plan with hardening role marker" "public_release false must not cite R-SEC-26" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/R-1\.1, R-CODE-21/R-1.1, R-ROAD-21/' "$CASE_FILE"
expect_fail "non-public plan with prepublication gate role marker" "public_release false must not cite R-ROAD-21" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/R-1\.1, R-CODE-21/R-1.1, R-LAUNCH-22/' "$CASE_FILE"
expect_fail "non-public plan with activation role marker" "public_release false must not cite R-LAUNCH-22" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^source_revision:.*\n//m' "$CASE_FILE"
expect_fail "missing source revision" "missing frontmatter field: source_revision" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/input_digest: sha256:[0-9a-f]+/input_digest: latest/' "$CASE_FILE"
expect_fail "invalid input digest" "input_digest must be sha256" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/input_digest: sha256:[0-9a-f]+/input_digest: sha256:0000000000000000000000000000000000000000000000000000000000000000/' "$CASE_FILE"
expect_fail "placeholder input digest" "input_digest must not use the all-zero placeholder" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/validated_at: 2026-07-13T12:00:00Z/validated_at: yesterday/' "$CASE_FILE"
expect_fail "invalid validation timestamp" "validated_at must use UTC ISO-8601" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Plan provenance\n\n/## Evidence\n\n/' "$CASE_FILE"
expect_fail "missing Plan provenance" "expected exactly one ## Plan provenance section, found 0" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Evidence inventory:/Evidence list:/' "$CASE_FILE"
expect_fail "incomplete Plan provenance" "Plan provenance is missing Evidence inventory:" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Source revision: none/Source revision: 0123456789abcdef0123456789abcdef01234567/' "$CASE_FILE"
expect_fail "mismatched provenance source revision" "Plan provenance Source revision does not match frontmatter source_revision" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Input digest: sha256:[0-9a-f]{64}/Input digest: sha256:cf2597de8c02e80d716a6c4a97d4c03cd75a566771121170be7c46bcf3b709e5/' "$CASE_FILE"
expect_fail "mismatched provenance input digest" "Plan provenance Input digest does not match frontmatter input_digest" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Validated at: 2026-07-13T12:00:00Z/Validated at: 2026-07-14T12:00:00Z/' "$CASE_FILE"
expect_fail "mismatched provenance validation timestamp" "Plan provenance Validated at does not match frontmatter validated_at" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- `intake` = `sha256:[0-9a-f]{64}`\n//m' "$CASE_FILE"
expect_fail "empty provenance inventory" "Plan provenance Evidence inventory must contain at least one item" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/`intake`/`readme`/' "$CASE_FILE"
expect_fail "provenance inventory missing intake" "Plan provenance Evidence inventory must contain exactly one intake item" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/- `intake` = `sha256:([0-9a-f]{64})`/- intake = sha256:$1/' "$CASE_FILE"
expect_fail "malformed provenance inventory" "malformed Plan provenance inventory item" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/(- `intake` = `sha256:[0-9a-f]{64}`)/$1\n$1/' "$CASE_FILE"
expect_fail "duplicate provenance inventory label" "duplicate Plan provenance inventory label: intake" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/(Source revision: none)/$1\n$1/' "$CASE_FILE"
expect_fail "duplicate provenance field label" "Plan provenance has duplicate Source revision label" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/sha256:1111111111111111111111111111111111111111111111111111111111111111`/sha256:2222222222222222222222222222222222222222222222222222222222222222`/' "$CASE_FILE"
expect_fail "mismatched provenance aggregate digest" "Plan provenance Input digest does not match the Evidence inventory aggregate" --allow-planning "$CASE_FILE"

PROVENANCE_PLAN="$TMP_DIR/valid-multi-item-provenance.mdx"
cp "$BASE_PLAN" "$PROVENANCE_PLAN"
perl -0pi -e '
  s/1c7ca1006bb3157ad989c1f1dd1cd1d6e8e2a44d9509821ffa43f3be205a12d5/cf2597de8c02e80d716a6c4a97d4c03cd75a566771121170be7c46bcf3b709e5/g;
  s/- `intake` = `sha256:1111111111111111111111111111111111111111111111111111111111111111`/- `readme` = `sha256:2222222222222222222222222222222222222222222222222222222222222222`\n- `intake` = `sha256:1111111111111111111111111111111111111111111111111111111111111111`/
' "$PROVENANCE_PLAN"
expect_pass "valid provenance inventory aggregate" --allow-planning "$PROVENANCE_PLAN"

new_case
perl -0pi -e 's/## Product form\n/## Delivery form\n/' "$CASE_FILE"
expect_fail "missing Product form" "expected exactly one ## Product form section, found 0" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/public_release: false/public_release: true/' "$CASE_FILE"
expect_fail "public release requires prepublication gate" "public release requires a prepublication gate task" --allow-planning "$CASE_FILE"

PUBLIC_PLAN="$TMP_DIR/valid-public-release.mdx"
cp "$BASE_PLAN" "$PUBLIC_PLAN"
perl -0pi -e '
  s/public_release: false/public_release: true/;
  s/(- \[ \] GP-101.*?  - Requirements: )[^\n]+/$1R-1.1, R-SEC-26, R-ARCH-4, R-STACK-1/s;
  s/(- \[ \] GP-102.*?  - Acceptance: )[^\n]+/$1fresh prepublication check records checked_at, hardening_revision, finding_counts, policy, verdict, owner, justification, accepted_at, and expires_at after current hardening evidence; any later change invalidates the pass/s;
  s/(- \[ \] GP-102.*?  - Requirements: )[^\n]+/$1R-1.1, R-ROAD-21, R-REPO-21, R-DNA-14/s;
  s/(- \[ \] GP-201.*?  - Depends on: )[^\n]+/$1GP-102/s;
  s/(- \[ \] GP-201.*?  - Requirements: )[^\n]+/$1R-1.1, R-LAUNCH-22, R-ROAD-1, R-BUILD-1, R-MEM-2, R-PRD-1, R-SEC-1, R-CODE-21/s
' "$PUBLIC_PLAN"
expect_pass "public release with ordered hardening gate activation chain" --allow-planning "$PUBLIC_PLAN"

GATE_BEFORE_HARDENING_PLAN="$TMP_DIR/gate-before-hardening.mdx"
cp "$PUBLIC_PLAN" "$GATE_BEFORE_HARDENING_PLAN"
perl -0pi -e 's/R-SEC-26/R-TEMP-1/; s/R-ROAD-21/R-SEC-26/; s/R-TEMP-1/R-ROAD-21/' "$GATE_BEFORE_HARDENING_PLAN"
expect_fail "prepublication gate before hardening" "prepublication gate must follow the latest hardening task" --allow-planning "$GATE_BEFORE_HARDENING_PLAN"

GATE_WITHOUT_HARDENING_DEPENDENCY_PLAN="$TMP_DIR/gate-without-hardening-dependency.mdx"
cp "$PUBLIC_PLAN" "$GATE_WITHOUT_HARDENING_DEPENDENCY_PLAN"
perl -0pi -e 's/(- \[ \] GP-102.*?  - Depends on: )GP-101/$1none/s' "$GATE_WITHOUT_HARDENING_DEPENDENCY_PLAN"
expect_fail "prepublication gate without hardening dependency" "prepublication gate must depend on the latest hardening task GP-101" --allow-planning "$GATE_WITHOUT_HARDENING_DEPENDENCY_PLAN"

ACTIVATION_WITHOUT_GATE_DEPENDENCY_PLAN="$TMP_DIR/activation-without-gate-dependency.mdx"
cp "$PUBLIC_PLAN" "$ACTIVATION_WITHOUT_GATE_DEPENDENCY_PLAN"
perl -0pi -e 's/(- \[ \] GP-201.*?  - Depends on: )GP-102/$1GP-101/s' "$ACTIVATION_WITHOUT_GATE_DEPENDENCY_PLAN"
expect_fail "public activation without gate dependency" "public activation must depend on the prepublication gate GP-102" --allow-planning "$ACTIVATION_WITHOUT_GATE_DEPENDENCY_PLAN"

INTERVENING_TASK_PLAN="$TMP_DIR/intervening-task-before-activation.mdx"
cp "$PUBLIC_PLAN" "$INTERVENING_TASK_PLAN"
perl -0pi -e 's/tasks_total: 3/tasks_total: 4/; s/(Checkpoint: malformed plans fail with a diagnostic\.)/- [ ] GP-103 [W1.1] Intervene after the prepublication gate\n  - Files: docs\/release\/notes.md\n  - Depends on: GP-102\n  - Reuses: release fixture\n  - Acceptance: release notes exist\n  - Verify: `test -s docs\/release\/notes.md`\n  - Requirements: R-1.1, R-CODE-21\n\n$1/' "$INTERVENING_TASK_PLAN"
expect_fail "task between prepublication gate and activation" "public activation must immediately follow the prepublication gate GP-102" --allow-planning "$INTERVENING_TASK_PLAN"

DUPLICATE_ACTIVATION_PLAN="$TMP_DIR/duplicate-public-activation.mdx"
cp "$PUBLIC_PLAN" "$DUPLICATE_ACTIVATION_PLAN"
perl -0pi -e 's/R-1\.1, R-ROAD-21/R-1.1, R-ROAD-21, R-LAUNCH-22/' "$DUPLICATE_ACTIVATION_PLAN"
expect_fail "duplicate public activation markers" "public release requires exactly one first activation task citing R-LAUNCH-22, found 2" --allow-planning "$DUPLICATE_ACTIVATION_PLAN"

DEFERRED_PLAN="$TMP_DIR/valid-deferred-domain.mdx"
cp "$BASE_PLAN" "$DEFERRED_PLAN"
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | deferred | trigger: the first public page task enters the roadmap; reversible until pages ship without metadata |/' "$DEFERRED_PLAN"
perl -0pi -e 's/^domains_deferred: \[\]$/domains_deferred: [seo]/m; s/^(domains_excluded: \[[^\]]*), seo(.*)$/$1$2/m' "$DEFERRED_PLAN"
expect_pass "deferred domain with trigger" --allow-planning "$DEFERRED_PLAN"

new_case
perl -0pi -e 's/^(domains_excluded: \[)database, /$1/m' "$CASE_FILE"
expect_fail "frontmatter drops an excluded domain" "frontmatter domains_excluded does not match the applicability matrix: missing database" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^(domains_applicable: \[product), /$1, database, /m' "$CASE_FILE"
expect_fail "frontmatter promotes an excluded domain" "frontmatter domains_applicable does not match the applicability matrix: database is excluded in the matrix" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^domains_deferred: \[\]$/domains_deferred: [product]/m' "$CASE_FILE"
expect_fail "frontmatter invents a deferral" "frontmatter domains_deferred does not match the applicability matrix: product is applicable in the matrix" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^domains_deferred: \[\]$/domains_deferred: [analytics]/m' "$CASE_FILE"
expect_fail "frontmatter names an unknown domain" "frontmatter domains_deferred names unknown domain analytics" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^domains_deferred: \[\]$/domains_deferred:\n  - name: observe\n    trigger: first real user/m' "$CASE_FILE"
expect_fail "frontmatter domain list must be inline" "frontmatter domains_deferred must be a single inline list" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/- \[ \] GP-101 \[W1\.1\]/- [ ] GP-101 [P] [W1.1]/; s{  - Files: tests/validate-plan\.sh\n  - Depends on: GP-101}{  - Files: skills/godplans/scripts/validate-plan.sh\n  - Depends on: GP-101}' "$CASE_FILE"
expect_fail "parallel task shares a wave file" "GP-101 and GP-102 are both in W1.1 and one is marked [P], but they share skills/godplans/scripts/validate-plan.sh" --allow-planning "$CASE_FILE"

PARALLEL_PLAN="$TMP_DIR/valid-parallel-tasks.mdx"
cp "$BASE_PLAN" "$PARALLEL_PLAN"
perl -0pi -e 's/- \[ \] GP-101 \[W1\.1\]/- [ ] GP-101 [P] [W1.1]/; s/- \[ \] GP-102 \[W1\.1\]/- [ ] GP-102 [P] [W1.1]/' "$PARALLEL_PLAN"
expect_pass "parallel tasks with disjoint files" --allow-planning "$PARALLEL_PLAN"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | deferred | reversible until pages ship |/' "$CASE_FILE"
expect_fail "deferred domain without trigger" "applicability matrix defers seo without a trigger" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | deferred | trigger: first public page ships |/' "$CASE_FILE"
expect_fail "deferred domain without reversibility" "applicability matrix defers seo without a reversibility argument" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | deferred | trigger: later; reversible because no pages exist |/' "$CASE_FILE"
expect_fail "deferred domain with vague trigger" "applicability matrix defers seo with a vague trigger" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | skipped | nothing to index |/' "$CASE_FILE"
expect_fail "invalid matrix status" "applicability matrix row for seo has invalid status 'skipped'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | excluded |  |/' "$CASE_FILE"
expect_fail "excluded domain without reason" "applicability matrix excludes seo without a reason" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/(\| product \| applicable \| fixture requirement \|\n)/$1| product | applicable | duplicate row |\n/' "$CASE_FILE"
expect_fail "duplicate matrix row" "applicability matrix has a duplicate row for product" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| architecture \|.*\n//m' "$CASE_FILE"
expect_fail "missing matrix domain" "applicability matrix is missing domain architecture" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| architecture \| applicable \| shell and embedded Perl boundary \|/| architecture | deferred | trigger: first package; reversible until then |/' "$CASE_FILE"
expect_fail "load-bearing domain cannot defer" "cannot defer load-bearing domain architecture" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Applicability matrix\n/## Domains\n/' "$CASE_FILE"
expect_fail "missing Applicability matrix" "expected exactly one ## Applicability matrix section, found 0" --allow-planning "$CASE_FILE"

FALSIFIER_PLAN="$TMP_DIR/valid-decision-falsifier.mdx"
cp "$BASE_PLAN" "$FALSIFIER_PLAN"
expect_pass "decision with falsifier" --allow-planning "$FALSIFIER_PLAN"

new_case
perl -0pi -e 's/Falsifier:\n- Signal: Perl availability on every supported platform\n- Failure boundary: any supported platform ships without Perl\n- Replan action: return to planning and replace the embedded parser with a supported runtime\n//' "$CASE_FILE"
expect_fail "decision missing falsifier" "decision D1 (line " --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/(### D1: portable runtime boundary)/$1\n\n### D1: duplicate/' "$CASE_FILE"
expect_fail "duplicate decision heading" "duplicate decision heading D1" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Replan action: return to planning and replace the embedded parser with a supported runtime/Replan action: wait and see/' "$CASE_FILE"
expect_fail "falsifier must return to planning" "Replan action must explicitly return to planning" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/Failure boundary: any supported platform ships without Perl/Failure boundary: things go badly/' "$CASE_FILE"
expect_fail "falsifier boundary must be observable" "Failure boundary lacks an observable event or numeric threshold" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/### D1: portable runtime boundary/### D1 portable runtime boundary/' "$CASE_FILE"
expect_fail "malformed decision heading" "malformed decision heading" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/### D1: portable runtime boundary.*?## Requirements/## Requirements/s' "$CASE_FILE"
expect_fail "missing decision entries" "Decisions must contain at least one" --allow-planning "$CASE_FILE"

JSON_OUT="$TMP_DIR/plan.json"
expect_pass "emit JSON sidecar" --allow-planning --emit-json "$JSON_OUT" "$BASE_PLAN"
node -e '
  const fs = require("node:fs");
  const crypto = require("node:crypto");
  const plan = fs.readFileSync(process.argv[1]);
  const doc = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
  const digest = "sha256:" + crypto.createHash("sha256").update(plan).digest("hex");
  if (doc.format !== "godplans/plan-json@1") throw new Error("bad format tag");
  if (doc.plan_digest !== digest) throw new Error("plan_digest mismatch");
  if (doc.status !== "planning") throw new Error("status mismatch");
  if (doc.public_release !== false) throw new Error("public_release mismatch");
  if (doc.tasks.length !== 3) throw new Error("task count mismatch");
  if (doc.tasks[0].id !== "GP-101" || doc.tasks[0].wave !== "W1.1") throw new Error("task shape mismatch");
  if (doc.tasks[1].depends_on[0] !== "GP-101") throw new Error("depends_on mismatch");
  if (doc.tasks[2].requirements.indexOf("R-CODE-21") < 0) throw new Error("requirements mismatch");
  if (doc.phases.length !== 2 || doc.phases[1].name !== "Verification") throw new Error("phase shape mismatch");
  if (doc.applicability.length !== 18) throw new Error("applicability mismatch");
  if (doc.decisions.length !== 1 || doc.decisions[0].falsifier.signal.indexOf("Perl") < 0) throw new Error("decision mismatch");
  if (doc.metrics.task_history.active !== 3 || doc.metrics.task_history.superseded !== 0) throw new Error("history mismatch");
' "$BASE_PLAN" "$JSON_OUT" && record_pass "JSON sidecar content" || record_fail "JSON sidecar content" "node assertion failed"

HISTORY_PLAN="$TMP_DIR/plan-with-superseded-task.mdx"
cp "$BASE_PLAN" "$HISTORY_PLAN"
perl -0pi -e 's/(Checkpoint: malformed plans fail with a diagnostic\.)/~~- [ ] GP-103 [W1.2] Add crawl metadata~~\n  - Superseded: no public surface remains in scope\n  - Requirements: R-SEO-1\n\n$1/' "$HISTORY_PLAN"
HISTORY_JSON="$TMP_DIR/history.json"
expect_pass "emit superseded task metrics" --allow-planning --emit-json "$HISTORY_JSON" "$HISTORY_PLAN"
node -e '
  const doc = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
  if (doc.superseded_tasks.length !== 1 || doc.superseded_tasks[0].id !== "GP-103") throw new Error("superseded task missing");
  if (doc.metrics.task_history.historical !== 4) throw new Error("historical count mismatch");
  if (doc.metrics.task_history.supersession_rate !== 0.25) throw new Error("supersession rate mismatch");
  const seo = doc.metrics.domains.find((entry) => entry.domain === "seo");
  if (!seo || seo.supersession_rate !== 1) throw new Error("domain supersession rate mismatch");
' "$HISTORY_JSON" && record_pass "superseded task metric content" || record_fail "superseded task metric content" "node assertion failed"

HALFLIFE_OUT="$TMP_DIR/PLAN.metrics.json"
if "$ROOT_DIR/skills/godplans/scripts/plan-halflife.sh" "$HISTORY_PLAN" "$HALFLIFE_OUT" >/dev/null &&
   node -e '
     const doc = JSON.parse(require("node:fs").readFileSync(process.argv[1], "utf8"));
     if (doc.format !== "godplans/plan-half-life@1") throw new Error("format mismatch");
     if (doc.metrics.task_history.superseded !== 1) throw new Error("metric mismatch");
   ' "$HALFLIFE_OUT"; then
  record_pass "plan half-life report"
else
  record_fail "plan half-life report" "report generation failed"
fi

DRIFT_PLAN="$TMP_DIR/drift-check.mdx"
cp "$BASE_PLAN" "$DRIFT_PLAN"
perl -0pi -e '
  s/status: planning/status: executing/;
  s/phases_done: 0/phases_done: 1/;
  s/tasks_done: 0/tasks_done: 2/;
  s/- \[ \] GP-10/- [x] GP-10/g;
  s/  - Verify: `bash tests\/validate-plan\.sh`/  - Verify: `test -f package.json`/g;
  s/Checkpoint verify: `test -x skills\/godplans\/scripts\/validate-plan\.sh`/Checkpoint verify: `test -f package.json`/
' "$DRIFT_PLAN"
if "$VALIDATOR" --drift-check 1 "$DRIFT_PLAN" >/dev/null 2>&1; then
  record_pass "phase-boundary drift check"
else
  record_fail "phase-boundary drift check" "completed task or checkpoint recheck failed"
fi

RECHECK_PLAN="$TMP_DIR/drift-recheck.mdx"
cp "$DRIFT_PLAN" "$RECHECK_PLAN"
printf '%s\n' 'stable evidence' > "$TMP_DIR/recheck.txt"
RECHECK_DIGEST=$(shasum -a 256 "$TMP_DIR/recheck.txt" | awk '{print $1}')
AGGREGATE_DIGEST=$(node -e '
  const crypto = require("node:crypto");
  const entries = {
    intake: "1111111111111111111111111111111111111111111111111111111111111111",
    "recheck.txt": process.argv[1],
  };
  const input = Object.keys(entries).sort().map((key) => `${key}\t${entries[key]}\n`).join("");
  process.stdout.write(crypto.createHash("sha256").update(input).digest("hex"));
' "$RECHECK_DIGEST")
RECHECK_DIGEST="$RECHECK_DIGEST" AGGREGATE_DIGEST="$AGGREGATE_DIGEST" perl -0pi -e '
  s/1c7ca1006bb3157ad989c1f1dd1cd1d6e8e2a44d9509821ffa43f3be205a12d5/$ENV{AGGREGATE_DIGEST}/g;
  s/(- `intake` = `sha256:[0-9a-f]{64}`)/$1\n- [recheck] `recheck.txt` = `sha256:$ENV{RECHECK_DIGEST}`/;
  s/`test -f package.json`/`test -f recheck.txt`/g
' "$RECHECK_PLAN"
if (cd "$TMP_DIR" && "$VALIDATOR" --drift-check 1 "$RECHECK_PLAN" >/dev/null 2>&1); then
  record_pass "phase-boundary provenance recheck"
else
  record_fail "phase-boundary provenance recheck" "stable evidence failed"
fi
printf '%s\n' 'drifted evidence' > "$TMP_DIR/recheck.txt"
output=$(cd "$TMP_DIR" && "$VALIDATOR" --drift-check 1 "$RECHECK_PLAN" 2>&1) && status=0 || status=$?
if [ "$status" -ne 0 ] && printf '%s\n' "$output" | grep -F "recheck evidence drifted: recheck.txt" >/dev/null; then
  record_pass "phase-boundary provenance drift fails"
else
  record_fail "phase-boundary provenance drift fails" "drift was not rejected: $output"
fi

new_case
perl -0pi -e 's/^Checkpoint verify:.*\n//m' "$CASE_FILE"
expect_fail "missing checkpoint verification" "Phase 1 is missing Checkpoint verify" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/## Decisions\n/## Choices\n/' "$CASE_FILE"
expect_fail "missing Decisions section" "expected exactly one ## Decisions section, found 0" --allow-planning "$CASE_FILE"

# Exclusion tripwires: an exclusion with no evidence state and no expiry reads
# exactly like a considered decision, which is the row an auditor pulls first.

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | excluded | by-design: nothing the validator produces is crawlable |/' "$CASE_FILE"
expect_fail "excluded domain without tripwire" "applicability matrix excludes seo without a revisit when: tripwire" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | excluded | nothing the validator produces is crawlable; revisit when: the project publishes a reachable page |/' "$CASE_FILE"
expect_fail "excluded domain without evidence state" "applicability matrix excludes seo without an evidence state" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | excluded | unknown: nobody checked for crawlable routes; revisit when: the project publishes a reachable page |/' "$CASE_FILE"
expect_fail "excluded domain on an unknown state" "applicability matrix excludes seo on evidence state 'unknown'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| seo \| excluded \|[^\n]*\|/| seo | excluded | by-design: nothing is crawlable; revisit when: later |/' "$CASE_FILE"
expect_fail "excluded domain with a vague tripwire" "applicability matrix excludes seo with a vague revisit when: predicate" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/\| repo \| applicable \| validator ships in the skill package \|/| repo | excluded | by-design: no repository is planned; revisit when: the project gains a version-controlled home |/; s/^(domains_applicable: \[[^\]]*), repo(.*)$/$1$2/m; s/^(domains_excluded: \[)/$1repo, /m' "$CASE_FILE"
expect_fail "load-bearing domain cannot be excluded" "applicability matrix cannot exclude load-bearing domain repo" --allow-planning "$CASE_FILE"

# Module disposition: the only place a module requirement may leave the plan.

new_case
perl -0pi -e 's/### Module disposition\n/### Module notes\n/' "$CASE_FILE"
expect_fail "missing module disposition" "expected a ### Module disposition block" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- roadmap: landed R-ROAD-1\n//m' "$CASE_FILE"
expect_fail "module disposition skips an applicable module" "module disposition is missing applicable module roadmap" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- roadmap: landed R-ROAD-1$/- roadmap: landed R-ROAD-1; dropped-by vibes R-ROAD-9 (felt heavy)/m' "$CASE_FILE"
expect_fail "module disposition names an unknown layer" "drops by unknown layer 'vibes'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- roadmap: landed R-ROAD-1$/- roadmap: landed R-ROAD-1; dropped-by scale R-ROAD-9/m' "$CASE_FILE"
expect_fail "module disposition drops without a reason" "dropped-by clause without a parenthesised reason" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- roadmap: landed R-ROAD-1$/- roadmap: landed R-ROAD-1; dropped-by scale R-ROAD-1 (cut for the weekend appetite)/m' "$CASE_FILE"
expect_fail "module disposition lands and drops one id" "module disposition for roadmap both lands and drops R-ROAD-1" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- build: landed R-BUILD-1$/- build: landed none; dropped-by scale R-BUILD-1 (cut for the weekend appetite)/m' "$CASE_FILE"
expect_fail "module disposition drops a requirement a task cites" "module disposition drops R-BUILD-1 but GP-201 still traces to it" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- stack: landed R-STACK-1$/- stack: landed R-STACK-7/m' "$CASE_FILE"
expect_fail "module disposition lands an unreferenced requirement" "module disposition lands R-STACK-7 but nothing in the plan references it" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- stack: landed R-STACK-1$/- stack: landed R-SEC-1/m' "$CASE_FILE"
expect_fail "module disposition crosses module prefixes" "module disposition for stack lists R-SEC-1, which is not an R-STACK requirement" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- product: landed R-PRD-1;[^\n]*$/- product: landed R-PRD-1\n- observe: landed R-OBS-1/m' "$CASE_FILE"
expect_fail "module disposition covers an excluded module" "module disposition covers observe, which the applicability matrix marks excluded" --allow-planning "$CASE_FILE"

# Documentation set: selection, ownership, and defended absences.

new_case
perl -0pi -e 's/## Documentation set\n/## Docs\n/' "$CASE_FILE"
expect_fail "missing documentation set" "expected exactly one ## Documentation set section, found 0" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^This manifest covers documentation committed to this repository[^\n]*\n//m' "$CASE_FILE"
expect_fail "documentation set without a boundary statement" "documentation set must state its boundary" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| build\.readme \| build \| required \| repo \|[^\n]*\|$/| build.manual | build | required | repo | always; written by GP-102 |/m' "$CASE_FILE"
expect_fail "documentation set invents a catalog id" "documentation set names build.manual, which is not a doc-set.md catalog id" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| build\.readme \| build \| required \| repo \|([^\n]*)\|$/| build.readme | build | required | build |$1|/m' "$CASE_FILE"
expect_fail "documentation set reassigns ownership" "documentation set row build.readme names owner 'build'; the catalog owner is repo" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| build\.readme \| build \| required \| repo \|[^\n]*\|$/| build.readme | verify | required | repo | always; written by GP-102 |/m' "$CASE_FILE"
expect_fail "documentation set moves a document between stages" "documentation set row build.readme declares stage 'verify'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| build\.readme \| build \| required \| repo \|[^\n]*\|$/| build.readme | build | required | repo | always, and somebody will get to it |/m' "$CASE_FILE"
expect_fail "required document with no writing task" "documentation set row build.readme is required but names no GP task" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| build\.readme \| build \| required \| repo \|[^\n]*\|$/| build.readme | build | required | repo | always; written by GP-909 |/m' "$CASE_FILE"
expect_fail "required document names a nonexistent task" "documentation set row build.readme names GP-909, which is not a task in this plan" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| serve\.user-guide \| serve \| not-applicable \| launch \|[^\n]*\|$/| serve.user-guide | serve | not-applicable | launch | no external user was named in intake |/m' "$CASE_FILE"
expect_fail "excluded document without a tripwire" "documentation set excludes serve.user-guide without a revisit when: tripwire" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| serve\.user-guide \| serve \| not-applicable \| launch \|[^\n]*\|$/| serve.user-guide | serve | not-applicable | launch | unknown: nobody asked who reads this; revisit when: the validator ships to users outside this repository |/m' "$CASE_FILE"
expect_fail "excluded document on an unknown state" "documentation set excludes serve.user-guide on evidence state 'unknown'" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| serve\.user-guide \| serve \| not-applicable \| launch \|[^\n]*\|$/| serve.user-guide | serve | not-applicable | launch | absent: no external user was named in intake; revisit when: post-MVP |/m' "$CASE_FILE"
expect_fail "excluded document with a vague tripwire" "documentation set excludes serve.user-guide with a vague revisit when: predicate" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^\| operate\.runbook \| operate \| not-applicable \| observe \|[^\n]*\|$/| operate.runbook | operate | required | observe | always; written by GP-201 |/m' "$CASE_FILE"
expect_fail "required document owned by an excluded module" "its owner module observe is excluded in the applicability matrix" --allow-planning "$CASE_FILE"

# Archetype confidence: the label is arithmetic over the plan's own scores.

new_case
perl -0pi -e 's/^- Margin: 57 points$/- Margin: 40 points/m' "$CASE_FILE"
expect_fail "archetype margin disagrees with the scores" "Margin is 40 but the scores give 57" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- Confidence: high$/- Confidence: medium/m; s/^archetype_confidence: high$/archetype_confidence: medium/m' "$CASE_FILE"
expect_fail "archetype confidence contradicts its own arithmetic" "archetype confidence states medium but a margin of 57" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^archetype_confidence: high$/archetype_confidence: low/m' "$CASE_FILE"
expect_fail "frontmatter confidence contradicts the block" "frontmatter archetype_confidence is low but the block" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- Primary: cli-tool \(score 0\.86\)$/- Primary: library (score 0.86)/m' "$CASE_FILE"
expect_fail "archetype block disagrees with frontmatter" "Primary is library but frontmatter archetype is cli-tool" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- Primary: cli-tool \(score 0\.86\)$/- Primary: cli-tool (score 0.40)/m; s/^- Runner-up: library \(score 0\.29\)$/- Runner-up: none/m; s/^- Margin: 57 points$/- Margin: 40 points/m; s/^- Confidence: high$/- Confidence: low/m; s/^archetype_confidence: high$/archetype_confidence: low/m' "$CASE_FILE"
expect_fail "archetype below the floor keeps a named archetype" "below the 0.45 floor, so frontmatter archetype must be unknown" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- If the runner-up is right: [^\n]*$/- If the runner-up is right: some rework in the packaging tasks/m' "$CASE_FILE"
expect_fail "archetype counterfactual priced in adjectives" "counterfactual must be priced in tasks and phases" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^- Overlays: none$/- Overlays: public-ui/m' "$CASE_FILE"
expect_fail "archetype overlays disagree with frontmatter" "Overlays says 'public-ui' but frontmatter overlays is []" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^### Archetype confidence\n/### Archetype notes\n/m' "$CASE_FILE"
expect_fail "missing archetype confidence block" "expected exactly one ### Archetype confidence block, found 0" --allow-planning "$CASE_FILE"

LOW_CONFIDENCE_PLAN="$TMP_DIR/valid-low-confidence.mdx"
cp "$BASE_PLAN" "$LOW_CONFIDENCE_PLAN"
perl -0pi -e '
  s/^archetype: cli-tool$/archetype: unknown/m;
  s/^archetype_confidence: high$/archetype_confidence: low/m;
  s/^- Primary: cli-tool \(score 0\.86\)$/- Primary: cli-tool (score 0.40)/m;
  s/^- Runner-up: library \(score 0\.29\)$/- Runner-up: library (score 0.36)/m;
  s/^- Margin: 57 points$/- Margin: 4 points/m;
  s/^- Confidence: high$/- Confidence: low/m;
  s/^None\.$/### Q1: Is this a cli-tool or a library, given the archetype score of 0.40?\n- Owner: the maintainer (the answer is theirs to give)\n- Blocks: build, from the start of Phase 1\n- Decide by: 2026-08-14, the Phase 1 wave boundary\n- Why it matters: the archetype sets the matrix defaults and the documentation set.\n- Options: (a) cli-tool; (b) library; (c) both, published as a library with a thin command wrapper.\n- Recommended default: (a), which the current entry point already matches./m
' "$LOW_CONFIDENCE_PLAN"
expect_pass "low confidence with the archetype asked" --allow-planning "$LOW_CONFIDENCE_PLAN"

CASE_FILE="$TMP_DIR/low-confidence-unasked.mdx"
cp "$LOW_CONFIDENCE_PLAN" "$CASE_FILE"
perl -0pi -e 's/^### Q1: Is this a cli-tool or a library[^\n]*$/### Q1: Which package registry receives the release?/m' "$CASE_FILE"
expect_fail "low confidence without the archetype question" "archetype belongs in ## Open Questions" --allow-planning "$CASE_FILE"

CASE_FILE="$TMP_DIR/low-confidence-assure.mdx"
cp "$LOW_CONFIDENCE_PLAN" "$CASE_FILE"
perl -0pi -e 's/^\| serve\.user-guide \| serve \| not-applicable \| launch \|([^\n]*)\|$/| assure.threat-model | assure | not-applicable | security | by-design: no auth boundary and no stored personal data; revisit when: any task adds a session or persists user data |/m' "$CASE_FILE"
expect_fail "low confidence deletes an assure row" "not-applicable while archetype confidence is low" --allow-planning "$CASE_FILE"

# Overlays raise and never lower.

new_case
perl -0pi -e 's/^overlays: \[\]$/overlays: [public-ui]/m; s/^- Overlays: none$/- Overlays: public-ui/m' "$CASE_FILE"
expect_fail "overlay domain excluded anyway" "which the public-ui overlay covers" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^overlays: \[\]$/overlays: [telemetry]/m' "$CASE_FILE"
expect_fail "unknown overlay" "names unknown overlay telemetry" --allow-planning "$CASE_FILE"

new_case
perl -0pi -e 's/^overlays: \[\]$/overlays: ai-system/m' "$CASE_FILE"
expect_fail "overlays must be an inline list" "overlays must be a single inline list" --allow-planning "$CASE_FILE"

OVERLAY_PLAN="$TMP_DIR/valid-overlay.mdx"
cp "$BASE_PLAN" "$OVERLAY_PLAN"
perl -0pi -e '
  s/^overlays: \[\]$/overlays: [shipped-artifact]/m;
  s/^- Overlays: none$/- Overlays: shipped-artifact/m;
  s/^\| deploy \| excluded \|[^\n]*\|$/| deploy | deferred | trigger: the first distribution task enters the roadmap; reversible until an artifact is published |/m;
  s/^(domains_excluded: \[[^\]]*), deploy(.*)$/$1$2/m;
  s/^domains_deferred: \[\]$/domains_deferred: [deploy]/m
' "$OVERLAY_PLAN"
expect_pass "overlay domain may defer" --allow-planning "$OVERLAY_PLAN"

# Brownfield absent: claims carry the search that came back empty.

BROWNFIELD_PLAN="$TMP_DIR/valid-brownfield-absent.mdx"
cp "$BASE_PLAN" "$BROWNFIELD_PLAN"
perl -0pi -e '
  s/^mode: greenfield$/mode: brownfield/m;
  s/^\| seo \| excluded \|[^\n]*\|$/| seo | excluded | absent: no HTML template or route table under src (`grep -rl "<html" src` returns nothing); revisit when: the project publishes a page a search engine can reach |/m
' "$BROWNFIELD_PLAN"
expect_pass "brownfield absent claim with a citation" --allow-planning "$BROWNFIELD_PLAN"

CASE_FILE="$TMP_DIR/brownfield-absent-uncited.mdx"
cp "$BROWNFIELD_PLAN" "$CASE_FILE"
perl -0pi -e 's/^\| seo \| excluded \|[^\n]*\|$/| seo | excluded | absent: no HTML template or route table under src; revisit when: the project publishes a page a search engine can reach |/m' "$CASE_FILE"
expect_fail "brownfield absent claim with no search" "absent: claim with no backticked command" --allow-planning "$CASE_FILE"

DOC_CATALOG_ACTUAL="$TMP_DIR/doc-catalog-actual"
DOC_CATALOG_EMBEDDED="$TMP_DIR/doc-catalog-embedded"
perl -ne 'print "$1 $3 $2\n" if /^\|\s*`([a-z]+\.[a-z0-9-]+)`\s*\|\s*(durable|evidence|transient)\s*\|\s*([a-z-]+)\s*\|/' \
  "$ROOT_DIR/skills/godplans/references/doc-set.md" | sort > "$DOC_CATALOG_ACTUAL"
perl -ne "print \"\$1 \$2 \$3\n\" if /^    '([a-z]+\.[a-z0-9-]+)' => '([a-z-]+)\|(durable|evidence|transient)',\$/" \
  "$VALIDATOR" | sort > "$DOC_CATALOG_EMBEDDED"
if diff -u "$DOC_CATALOG_ACTUAL" "$DOC_CATALOG_EMBEDDED" >/dev/null 2>&1; then
  record_pass "embedded document catalog is current"
else
  record_fail "embedded document catalog is current" "validator doc catalog differs from doc-set.md"
fi

SIDECAR_PLAN="$TMP_DIR/sidecar-source.mdx"
cp "$BASE_PLAN" "$SIDECAR_PLAN"
SIDECAR_JSON="$TMP_DIR/sidecar.json"
if "$VALIDATOR" --allow-planning --emit-json "$SIDECAR_JSON" "$SIDECAR_PLAN" >/dev/null 2>&1 \
    && node -e '
      const doc = require(process.argv[1]);
      const seo = doc.applicability.find((row) => row.domain === "seo");
      const repo = doc.module_disposition.find((row) => row.module === "repo");
      const readme = doc.documentation.find((row) => row.id === "build.readme");
      const product = doc.module_disposition.find((row) => row.module === "product");
      if (doc.archetype_confidence !== "high") throw new Error("archetype confidence missing");
      if (!Array.isArray(doc.overlays)) throw new Error("overlays missing");
      if (!seo || seo.evidence_state !== "by-design" || !seo.revisit_when) throw new Error("applicability tripwire missing");
      if (!repo || !repo.landed.includes("R-REPO-21")) throw new Error("module disposition missing");
      if (!product || product.dropped[0].layer !== "scale") throw new Error("dropped layer missing");
      if (!readme || readme.owner !== "repo" || readme.durability !== "durable") throw new Error("documentation row missing");
    ' "$SIDECAR_JSON"; then
  record_pass "sidecar carries tripwires, disposition, and documentation"
else
  record_fail "sidecar carries tripwires, disposition, and documentation" "sidecar payload incomplete"
fi

if [ "$FAIL_COUNT" -ne 0 ]; then
  printf '\n%d passed, %d failed\n' "$PASS_COUNT" "$FAIL_COUNT" >&2
  exit 1
fi

printf '\n%d validator regression checks passed\n' "$PASS_COUNT"
