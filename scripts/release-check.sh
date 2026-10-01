#!/usr/bin/env bash
# Release-grade local evidence. Requires the pinned official validator and gh.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

die() {
  printf '[fail] %s\n' "$*" >&2
  exit 1
}

# Resolution order: an explicit SKILLS_REF_BIN, then the documented repository
# venv, then PATH. Whichever validator is found, the release gate fails when it
# cannot run; it never skips the official validation.
if [ -n "${SKILLS_REF_BIN:-}" ]; then
  VALIDATOR=$SKILLS_REF_BIN
elif [ -x "$REPO_DIR/.venv-skills-ref/bin/skills-ref" ]; then
  VALIDATOR="$REPO_DIR/.venv-skills-ref/bin/skills-ref"
elif command -v skills-ref >/dev/null 2>&1; then
  VALIDATOR=$(command -v skills-ref)
else
  printf '%s\n' "[fail] skills-ref is required for release validation." >&2
  printf '%s\n' "Install the pinned validator in an isolated environment:" >&2
  printf '%s\n' "  python3 -m venv .venv-skills-ref" >&2
  printf '%s\n' "  .venv-skills-ref/bin/pip install -r requirements/skills-ref.txt" >&2
  printf '%s\n' "Then set SKILLS_REF_BIN=.venv-skills-ref/bin/skills-ref and rerun." >&2
  exit 1
fi

# A validator that cannot execute (a stale shim, a deleted interpreter) is a
# broken tool, not a verdict on the skill, so it gets its own message.
probe_status=0
"$VALIDATOR" --version >/dev/null || probe_status=$?
[ "$probe_status" -eq 0 ] ||
  die "could not execute $VALIDATOR (exit $probe_status); reinstall it or set SKILLS_REF_BIN"
validate_status=0
"$VALIDATOR" validate "$REPO_DIR/skills/godplans" || validate_status=$?
case "$validate_status" in
  0) ;;
  126|127) die "could not execute $VALIDATOR (exit $validate_status)" ;;
  *) die "official skills-ref validator rejected skills/godplans (exit $validate_status)" ;;
esac

# release:prepare stubs the new CHANGELOG section with a placeholder line, and
# the GitHub release notes are cut from that section verbatim. Match only that
# exact stub (scripts/release-prepare.js), so a real note that names the word
# TODO, such as one about R-REPO-6, still passes.
CHANGELOG_STUB='- TODO: describe this release.'
top_section=$(awk '/^## \[/ { if (seen) exit; seen = 1 } seen { print }' "$REPO_DIR/CHANGELOG.md")
[ -n "$top_section" ] || die "CHANGELOG.md has no version section"
if printf '%s\n' "$top_section" | grep -Fqx -- "$CHANGELOG_STUB"; then
  die "the top CHANGELOG.md section still holds the release:prepare stub ($CHANGELOG_STUB); write the release notes first"
fi

if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  printf '%s\n' "[fail] authenticated gh CLI is required for tag and release parity." >&2
  exit 1
fi

cd "$REPO_DIR"
SKILLS_REF_BIN="$VALIDATOR" npm run check
bash scripts/eval.sh --check-cases
bash scripts/lint.sh tag-release-parity --verbose
# npm test accepts untracked, unignored files so work in progress can be
# tested; a release ships exactly what is committed.
bash tests/package-contents.sh --tracked-only
printf '%s\n' "ok   [release-check]"
