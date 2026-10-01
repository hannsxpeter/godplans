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
