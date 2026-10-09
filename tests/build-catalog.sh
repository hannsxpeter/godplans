#!/usr/bin/env bash
# The catalog generator is maintainer tooling under scripts/, outside the
# shipped skill. It must resolve the skill from its own location, and every
# documentation-set owner must be a domain the validator knows.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [build-catalog] $*" >&2
  exit 1
}

[ ! -e "$ROOT/skills/godplans/scripts/build-catalog.js" ] ||
  fail "the maintainer catalog generator ships inside the skill"

# Every mutation below happens in a scratch copy, never the tracked validator.
REPO="$TMP/repo"
mkdir -p "$REPO/scripts" "$REPO/skills/godplans/scripts"
cp "$ROOT/scripts/build-catalog.js" "$REPO/scripts/build-catalog.js"
cp -R "$ROOT/skills/godplans/references" "$REPO/skills/godplans/references"
cp "$ROOT/skills/godplans/scripts/validate-plan.sh" "$REPO/skills/godplans/scripts/validate-plan.sh"
VALIDATOR="$REPO/skills/godplans/scripts/validate-plan.sh"

(cd "$TMP" && node "$REPO/scripts/build-catalog.js" --check >/dev/null) ||
  fail "a fresh catalog failed --check when run outside the repository root"

# Only an id that starts a line defines a requirement. A mid-sentence citation
# of the next SEC number is a cross-reference and must not raise %catalog_max;
# the same id starting a line in security.md is a definition and must.
sec_max=$(sed -n 's/^ *SEC => \([0-9][0-9]*\),$/\1/p' "$VALIDATOR")
[ -n "$sec_max" ] || fail "fixture could not read SEC from %catalog_max"
next="R-SEC-$((sec_max + 1))"
REFS="$REPO/skills/godplans/references"
cp "$REFS/business.md" "$TMP/business.md"
cp "$REFS/security.md" "$TMP/security.md"
perl -0pi -e "s/^## Plan requirements\n/## Plan requirements\n\nThis module also relies on $next from security.\n/m" "$REFS/business.md"
grep -Fq "relies on $next from" "$REFS/business.md" || fail "fixture did not add the cross-reference"
node "$REPO/scripts/build-catalog.js" --check >"$TMP/xref.out" 2>&1 ||
  fail "a mid-sentence cross-reference changed the catalog: $(cat "$TMP/xref.out")"
cp "$TMP/business.md" "$REFS/business.md"
perl -0pi -e "s/^## Plan requirements\n/## Plan requirements\n\n$((sec_max + 1)). $next: A fixture requirement.\n/m" "$REFS/security.md"
grep -q "^$((sec_max + 1))\. $next:" "$REFS/security.md" || fail "fixture did not add the defining line"
if node "$REPO/scripts/build-catalog.js" --check >"$TMP/def.out" 2>&1; then
  fail "a new defining line did not change the catalog"
fi
grep -Fq 'Validator catalog is stale' "$TMP/def.out" ||
  fail "a new defining line was not reported as stale: $(cat "$TMP/def.out")"
cp "$TMP/security.md" "$REFS/security.md"

# Reassign the first catalog row to an owner the validator has no domain for.
DOC_SET="$REPO/skills/godplans/references/doc-set.md"
cp "$DOC_SET" "$TMP/doc-set.md"
perl -0pi -e 's/^(\|\s*`[a-z]+\.[a-z0-9-]+`\s*\|\s*(?:durable|evidence|transient)\s*\|\s*)[a-z-]+/${1}marketing/m' "$DOC_SET"
grep -q '| marketing |' "$DOC_SET" || fail "fixture did not rewrite a catalog owner"
if node "$REPO/scripts/build-catalog.js" --check >"$TMP/check.out" 2>&1; then
  fail "--check accepted a documentation owner outside the validator domains"
fi
grep -Fq "owner 'marketing' is not a validator domain" "$TMP/check.out" ||
  fail "unknown owner was not named: $(cat "$TMP/check.out")"
if node "$REPO/scripts/build-catalog.js" >"$TMP/write.out" 2>&1; then
  fail "regeneration accepted a documentation owner outside the validator domains"
fi
cmp -s "$ROOT/skills/godplans/scripts/validate-plan.sh" "$VALIDATOR" ||
  fail "a rejected catalog still rewrote the validator"

# Without the validator's domain table there is nothing to check owners against.
cp "$TMP/doc-set.md" "$DOC_SET"
perl -0pi -e 's/my %known_domain = /my %renamed_domain = /' "$VALIDATOR"
if node "$REPO/scripts/build-catalog.js" --check >"$TMP/table.out" 2>&1; then
  fail "--check passed without the validator's known-domain table"
fi
grep -Fq '%known_domain' "$TMP/table.out" ||
  fail "a missing known-domain table was not named: $(cat "$TMP/table.out")"

echo "ok   [build-catalog]"
