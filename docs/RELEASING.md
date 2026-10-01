# Releasing godplans

Releases are cut from a clean `main` branch after the release pull request is
merged. The Git tag, GitHub release, and every version surface use the same
SemVer value.

## Release checklist

1. Run `npm run release:prepare -- <patch|minor|major|X.Y.Z>`. It bumps the
   version in package.json, which is the single source of truth, then runs
   `npm run version:sync` to write it into every other surface (SKILL.md
   frontmatter and body, marketplace metadata, plugin metadata, the README
   version badge, and the PLAN template) and to regenerate PROMPT.md and the
   context metrics. When CHANGELOG.md has no heading for the new version yet,
   it adds a top entry dated today (UTC) whose body is an `### Added` heading
   over the stub line `- TODO: describe this release.`.
   `scripts/version-sync.js` holds the authoritative surface list, so add new
   surfaces there rather than to this checklist alone.
2. Replace the stub body with the real release notes and confirm the heading
   date. `npm run release:check` fails while the top CHANGELOG section still
   holds that exact stub line; a note that merely names TODO passes.
3. Run `npm run generate` (catalog, then prompt, then context metrics) after
   every source is final, so the validator tables, PROMPT.md, and
   `evals/metrics/context-cost.json` match what ships.
4. Install the pinned official validator in an isolated environment, then run
   `npm run release:check` from a clean checkout. It looks for the validator in
   `SKILLS_REF_BIN`, then `.venv-skills-ref/bin/skills-ref`, then `PATH`, and
   fails when it finds none or the one it finds cannot execute. (Inside a plain
   `npm run check`, the `official-validator` lint check only prints a visible
   skip when no validator is installed or one it found on its own cannot
   execute.) It includes `npm run check`, the CHANGELOG stub
   guard, deterministic evaluation contracts, official validation of the
   canonical `skills/godplans` package, immutable action pins, tag-to-release
   parity, and a package-contents check against committed files only
   (`tests/package-contents.sh --tracked-only`), so a file under a shipped
   path that git does not track fails the release.
5. Open a ready pull request and wait for the `release quality` job in the `lint` workflow.
6. Merge the pull request to `main` without bypassing a failed required check.
7. Pull the merged `main`, create annotated tag `vX.Y.Z`, and push the tag.
8. Create the GitHub release from the matching CHANGELOG section.
9. Verify the release page, tag target, default branch version, and a clean
   local worktree.
10. Check the repository's GitHub About text and topics against package.json:
    the About text should say what `description` says and make no claim it
    does not, and the topics should include every entry in `keywords`. Fix
    drift with `gh repo edit --description`, `--add-topic`, and
    `--remove-topic`; GitHub allows at most 20 topics, so a stale topic has to
    go before a new keyword fits.

## Commands

```bash
npm run release:prepare -- X.Y.Z   # then replace the CHANGELOG stub body
npm run generate
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
gh repo view hannsxpeter/godplans --json description,repositoryTopics \
  --jq '.description, ([.repositoryTopics[].name] | join(" "))'
node -p "const p = require('./package.json'); p.description + '\n' + p.keywords.join(' ')"
```

Run the release check again after the release is published so the new tag and
GitHub release enter the parity set. Do not reuse or move a published tag. A
failed release gets a new patch version.
