#!/usr/bin/env bash
# Release tooling regressions: release-check.sh validator resolution, changelog
# guard, gate wiring, and GitHub About parity, and the version sync that
# release:prepare runs.
# Everything runs in scratch copies, so no tracked file, venv, or tag is
# touched.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail() {
  echo "FAIL [release-tooling] $*" >&2
  exit 1
}

# CI and `npm run release:check` export SKILLS_REF_BIN. Each case below sets it
# explicitly when it wants one, so resolution cases start without it. GitHub
# Actions exports GITHUB_EVENT_NAME, which decides whether About drift fails or
# warns, so every case starts as a local run and the About cases set it.
unset SKILLS_REF_BIN GITHUB_EVENT_NAME

# Fake tools. The broken validator mimics a stale pipx shim whose interpreter
# was deleted. The fake gh fails authentication, so a release check that gets
# past its local guards stops there instead of reaching the network or npm.
BIN="$TMP/bin"
mkdir -p "$BIN/broken" "$BIN/fake-gh"
printf '%s\n' '#!/nonexistent/godplans-test-python' > "$BIN/broken/skills-ref"
printf '%s\n' '#!/usr/bin/env sh' 'case "$1" in --version) echo "skills-ref, version 0.0.0" ;; validate) echo "fixture rejection" >&2; exit 1 ;; esac' \
  > "$BIN/rejecting"
printf '%s\n' '#!/usr/bin/env sh' 'case "$1" in --version) echo "skills-ref, version 0.0.0" ;; validate) echo "Valid skill: $2" ;; esac' \
  > "$BIN/accepting"
printf '%s\n' '#!/usr/bin/env sh' 'exit 1' > "$BIN/fake-gh/gh"
chmod +x "$BIN/broken/skills-ref" "$BIN/rejecting" "$BIN/accepting" "$BIN/fake-gh/gh"

RC="$TMP/rc"
mkdir -p "$RC/scripts" "$RC/skills/godplans"
cp "$ROOT/scripts/release-check.sh" "$RC/scripts/release-check.sh"
# The top section names the word TODO in a real note; only the exact stub that
# release:prepare writes may block a release.
printf '%s\n' '# Changelog' '' '## [9.9.9] - 2026-01-01' '' '### Fixed' '' '- Real notes.' \
  '- R-REPO-6 now also rejects TODO markers in shell scripts.' '' \
  '## [9.9.8] - 2025-12-31' '' '- TODO markers in an older section are history.' > "$RC/CHANGELOG.md"

# Runs the scratch release check with PATH limited to the fake tools plus the
# system directories, so a skills-ref or gh installed on this machine is never
# picked up.
release_check() {
  extra_path=$1
  shift
  env PATH="$extra_path:$BIN/fake-gh:/usr/bin:/bin" "$@" bash "$RC/scripts/release-check.sh"
}

if release_check "$BIN/broken" SKILLS_REF_BIN="$BIN/broken/skills-ref" >"$TMP/explicit.out" 2>&1; then
  fail "release check passed with a validator that cannot execute"
fi
grep -q 'could not execute' "$TMP/explicit.out" ||
  fail "an unrunnable SKILLS_REF_BIN was not reported as such: $(cat "$TMP/explicit.out")"
if grep -q 'rejected' "$TMP/explicit.out"; then
  fail "an unrunnable validator was reported as rejecting the skill"
fi

if release_check "$BIN/broken" SKILLS_REF_BIN="$BIN/rejecting" >"$TMP/rejected.out" 2>&1; then
  fail "release check passed when the validator rejected the skill"
fi
grep -q 'rejected skills/godplans' "$TMP/rejected.out" ||
  fail "a rejecting validator was not reported as a rejection: $(cat "$TMP/rejected.out")"

if release_check "$BIN/broken" >"$TMP/path.out" 2>&1; then
  fail "release check skipped an unrunnable validator found on PATH"
fi
grep -q 'could not execute' "$TMP/path.out" ||
  fail "an unrunnable PATH validator was not reported as such: $(cat "$TMP/path.out")"

# The documented repository venv wins over a broken shim on PATH.
mkdir -p "$RC/.venv-skills-ref/bin"
printf '%s\n' '#!/usr/bin/env sh' 'case "$1" in --version) exit 0 ;; validate) echo "venv validator ran" >&2; exit 1 ;; esac' \
  > "$RC/.venv-skills-ref/bin/skills-ref"
chmod +x "$RC/.venv-skills-ref/bin/skills-ref"
if release_check "$BIN/broken" >"$TMP/venv.out" 2>&1; then
  fail "release check passed with a rejecting venv validator"
fi
grep -q 'venv validator ran' "$TMP/venv.out" ||
  fail "the repository venv validator was not preferred over PATH: $(cat "$TMP/venv.out")"
rm -rf "$RC/.venv-skills-ref"

# A clean top section passes the changelog guard and stops at the fake gh.
if release_check "$BIN/broken" SKILLS_REF_BIN="$BIN/accepting" >"$TMP/clean.out" 2>&1; then
  fail "release check passed without an authenticated gh"
fi
grep -q 'authenticated gh CLI is required' "$TMP/clean.out" ||
  fail "a clean changelog did not reach the gh check: $(cat "$TMP/clean.out")"

# Past its local guards the release check runs the repository gates. With
# stand-ins for gh, npm, and the gate scripts, it must finish and check the
# package against committed files only. There is no scripts/eval.sh stand-in:
# npm run check already covers the evaluation contracts, so the gate must not
# call it again. The gh stand-in answers `repo view` from about.json beside it,
# shaped like `gh repo view --json description,repositoryTopics` output.
mkdir -p "$BIN/ok-tools" "$RC/tests"
printf '%s\n' '#!/usr/bin/env sh' \
  'if [ "$1 $2" = "repo view" ]; then cat "$(dirname "$0")/about.json"; fi' 'exit 0' > "$BIN/ok-tools/gh"
printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "$BIN/ok-tools/npm"
printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$RC/scripts/lint.sh"
printf '%s\n' '#!/usr/bin/env bash' 'printf "%s\n" "$*" > "$(dirname "$0")/package-contents.args"' \
  > "$RC/tests/package-contents.sh"
chmod +x "$BIN/ok-tools/gh" "$BIN/ok-tools/npm"
# The About comparison runs node; link the real one in rather than widening PATH.
NODE_BIN=$(command -v node) || fail "node is required to run this test"
ln -s "$NODE_BIN" "$BIN/ok-tools/node"
printf '%s\n' '{' '  "description": "Fixture description.",' '  "keywords": ["alpha", "beta"]' '}' > "$RC/package.json"
# Matching About text, with one extra topic, which is allowed.
printf '%s\n' '{"description":"Fixture description.","repositoryTopics":[{"name":"beta"},{"name":"alpha"},{"name":"gamma"}]}' \
  > "$BIN/ok-tools/about.json"
env PATH="$BIN/ok-tools:/usr/bin:/bin" SKILLS_REF_BIN="$BIN/accepting" \
  bash "$RC/scripts/release-check.sh" >"$TMP/full.out" 2>&1 ||
  fail "release check failed with every gate stubbed to pass: $(cat "$TMP/full.out")"
grep -q 'ok   \[release-check\]' "$TMP/full.out" || fail "release check did not finish"
[ "$(cat "$RC/tests/package-contents.args" 2>/dev/null)" = "--tracked-only" ] ||
  fail "release check did not check the package against tracked files only"

# An About description that differs from package.json, or a keyword missing
# from the topics, fails a local release check and a push to main, and names
# the gh command that fixes it.
printf '%s\n' '{"description":"An older About text.","repositoryTopics":[{"name":"alpha"}]}' \
  > "$BIN/ok-tools/about.json"
about_wants() {
  for want in 'the repository description differs from package.json description' \
    'the repository topics lack package.json keywords: beta' \
    'fix: gh repo edit hannsxpeter/godplans --description "Fixture description." --add-topic beta'; do
    grep -Fq "$want" "$1" || fail "About drift output lacks [$want]: $(cat "$1")"
  done
}
for event in local push; do
  rm -f "$RC/tests/package-contents.args"
  event_env=
  [ "$event" = "local" ] || event_env="GITHUB_EVENT_NAME=$event"
  if env PATH="$BIN/ok-tools:/usr/bin:/bin" SKILLS_REF_BIN="$BIN/accepting" $event_env \
    bash "$RC/scripts/release-check.sh" >"$TMP/about-$event.out" 2>&1; then
    fail "release check ($event) passed with GitHub About drift"
  fi
  grep -q '^\[fail\] GitHub About drifted' "$TMP/about-$event.out" ||
    fail "release check ($event) did not fail on About drift: $(cat "$TMP/about-$event.out")"
  about_wants "$TMP/about-$event.out"
  [ ! -e "$RC/tests/package-contents.args" ] || fail "release check ($event) went on past GitHub About drift"
done
# Pull request CI only warns: the About text is live state that no branch
# carries, so the drift is printed with its fix and the gate goes on.
rm -f "$RC/tests/package-contents.args"
env PATH="$BIN/ok-tools:/usr/bin:/bin" SKILLS_REF_BIN="$BIN/accepting" GITHUB_EVENT_NAME=pull_request \
  bash "$RC/scripts/release-check.sh" >"$TMP/about-pr.out" 2>&1 ||
  fail "release check failed on About drift in pull request CI: $(cat "$TMP/about-pr.out")"
grep -q '^\[warn\] GitHub About drifted' "$TMP/about-pr.out" ||
  fail "About drift in pull request CI printed no warning: $(cat "$TMP/about-pr.out")"
about_wants "$TMP/about-pr.out"
grep -q 'ok   \[release-check\]' "$TMP/about-pr.out" ||
  fail "release check did not finish after an About warning"
[ "$(cat "$RC/tests/package-contents.args" 2>/dev/null)" = "--tracked-only" ] ||
  fail "release check skipped the package check after an About warning"
# No topics at all reads as every keyword missing, not as a crash.
printf '%s\n' '{"description":"Fixture description.","repositoryTopics":null}' > "$BIN/ok-tools/about.json"
if env PATH="$BIN/ok-tools:/usr/bin:/bin" SKILLS_REF_BIN="$BIN/accepting" \
  bash "$RC/scripts/release-check.sh" >"$TMP/notopics.out" 2>&1; then
  fail "release check passed with no repository topics"
fi
grep -Fq 'fix: gh repo edit hannsxpeter/godplans --add-topic alpha,beta' "$TMP/notopics.out" ||
  fail "missing topics were not named: $(cat "$TMP/notopics.out")"

# release:prepare from a scratch copy: version sync must leave every derived
# artifact current, and the TODO stub it writes must block the release check.
REPO="$TMP/repo"
mkdir -p "$REPO/scripts" "$REPO/evals/metrics" "$REPO/skills" "$REPO/.claude-plugin" "$REPO/plugins/godplans/.claude-plugin"
for file in package.json CHANGELOG.md README.md PROMPT.md; do
  cp "$ROOT/$file" "$REPO/$file"
done
cp "$ROOT/.claude-plugin/marketplace.json" "$REPO/.claude-plugin/marketplace.json"
cp "$ROOT/plugins/godplans/.claude-plugin/plugin.json" "$REPO/plugins/godplans/.claude-plugin/plugin.json"
cp -R "$ROOT/skills/godplans" "$REPO/skills/godplans"
cp "$ROOT/evals/metrics/context-cost.json" "$REPO/evals/metrics/context-cost.json"
for script in version-sync.js release-prepare.js build-prompt.sh context-metrics.js release-check.sh; do
  cp "$ROOT/scripts/$script" "$REPO/scripts/$script"
done

(cd "$REPO" && node scripts/release-prepare.js 99.0.0) >"$TMP/prepare.out" 2>&1 ||
  fail "release:prepare failed in a scratch copy: $(cat "$TMP/prepare.out")"
(cd "$REPO" && node scripts/version-sync.js --check) >/dev/null 2>&1 ||
  fail "release:prepare left a version surface stale"
(cd "$REPO" && node scripts/context-metrics.js --check) >/dev/null 2>&1 ||
  fail "release:prepare left the context metrics stale"
grep -q '^## \[99\.0\.0\] - ' "$REPO/CHANGELOG.md" || fail "release:prepare did not stub the CHANGELOG"

if env PATH="$BIN/fake-gh:/usr/bin:/bin" SKILLS_REF_BIN="$BIN/accepting" \
  bash "$REPO/scripts/release-check.sh" >"$TMP/todo.out" 2>&1; then
  fail "release check passed with the TODO changelog stub"
fi
grep -q 'release:prepare stub' "$TMP/todo.out" ||
  fail "the TODO changelog stub was not named: $(cat "$TMP/todo.out")"
if grep -q 'authenticated gh CLI is required' "$TMP/todo.out"; then
  fail "the changelog guard ran after the gh check"
fi

echo "ok   [release-tooling]"
