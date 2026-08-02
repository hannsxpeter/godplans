# Releasing godplans

Releases are cut from a clean `main` branch after the release pull request is
merged. The Git tag, GitHub release, and every version surface use the same
SemVer value.

## Release checklist

1. Add the new top entry to CHANGELOG.md with the release date.
2. Update the version in package.json, which is the single source of truth, and
   sync it into every other surface: SKILL.md frontmatter and body, marketplace
   metadata, plugin metadata, the README version badge, and the PLAN template.
   `npm run release:prepare -- <patch|minor|major|X.Y.Z>` does the bump, the
   sync, the prompt rebuild, and a stubbed CHANGELOG entry in one command;
   `scripts/version-sync.js` holds the authoritative surface list, so add new
   surfaces there rather than to this checklist alone.
3. Run `npm run build:prompt` after every inlined source is final.
4. Install the pinned official validator in an isolated environment, then run
   `npm run release:check` from a clean checkout. It includes `npm run check`,
   deterministic evaluation contracts, official validation of the canonical
   `skills/godplans` package, immutable action
   pins, tag-to-release parity, and a package dry run.
5. Open a ready pull request and wait for the `release quality` workflow.
6. Merge the pull request to `main` without bypassing a failed required check.
7. Pull the merged `main`, create annotated tag `vX.Y.Z`, and push the tag.
8. Create the GitHub release from the matching CHANGELOG section.
9. Verify the release page, tag target, default branch version, and a clean
   local worktree.

## Commands

```bash
npm run build:prompt
python3 -m venv .venv-skills-ref
.venv-skills-ref/bin/pip install -r requirements/skills-ref.txt
SKILLS_REF_BIN="$PWD/.venv-skills-ref/bin/skills-ref" npm run release:check
version=X.Y.Z
release_notes=$(mktemp)
trap 'rm -f "$release_notes"' EXIT HUP INT TERM
awk -v version="$version" '
  index($0, "## [" version "] - ") == 1 { capture = 1; next }
  capture && /^## \[/ { exit }
  capture { print }
' CHANGELOG.md > "$release_notes"
test -s "$release_notes"
git tag -a "v$version" -m "godplans v$version"
git push origin "v$version"
gh release create "v$version" --verify-tag --title "godplans v$version" --notes-file "$release_notes"
rm -f "$release_notes"
trap - EXIT HUP INT TERM
```

Run the release check again after the release is published so the new tag and
GitHub release enter the parity set. Do not reuse or move a published tag. A
failed release gets a new patch version.
