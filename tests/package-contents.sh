#!/usr/bin/env bash
# Package contents. By default (npm test) every packed path must be tracked or
# an untracked file git does not ignore, so a new case or reference that is
# still being written passes while ignored junk (bytecode, logs, editor
# backups) fails. With --tracked-only (release-check.sh) every packed path must
# be tracked, because a release ships exactly what is committed.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

fail() {
  echo "FAIL [package-contents] $*" >&2
  exit 1
}

MODE=working-tree
case "${1:-}" in
  '') ;;
  --tracked-only) MODE=tracked ;;
  *) fail "unknown option: $1 (expected --tracked-only)" ;;
esac

# packed_strays DIR MODE OUT: write the npm pack manifest for the package in
# DIR to OUT.json and the packed paths git does not allow under MODE to OUT,
# one per line. npm packs from the filesystem and ships ignored files under a
# "files" entry, so git is the reference for what the package may contain.
packed_strays() {
  (cd "$1" && npm pack --dry-run --json --ignore-scripts) > "$3.json"
  if [ "$2" = tracked ]; then
    git -C "$1" ls-files -z > "$3.allowed"
  else
    git -C "$1" ls-files -z --cached --others --exclude-standard > "$3.allowed"
  fi
  node - "$3.json" "$3.allowed" > "$3" <<'NODE'
const fs = require('fs');
const [packFile, allowedFile] = process.argv.slice(2);
const allowed = new Set(fs.readFileSync(allowedFile, 'utf8').split('\0').filter(Boolean));
const packed = JSON.parse(fs.readFileSync(packFile, 'utf8'))[0].files.map((entry) => entry.path);
for (const file of packed.filter((path) => !allowed.has(path)).sort()) process.stdout.write(`${file}\n`);
NODE
}

# Prove both modes against a scratch repository that packs with the real
# "files" list before trusting a clean result from them: an untracked new file
# passes the working-tree mode and fails the tracked mode, an ignored file fails
# both, and Python bytecode is never packed at all.
FIXTURE="$TMP/fixture"
mkdir -p "$FIXTURE/skills/demo/scripts/__pycache__"
node -e '
  const manifest = require(process.argv[1]);
  process.stdout.write(JSON.stringify({ name: "fixture", version: "0.0.0", private: true, files: manifest.files }));
' "$ROOT/package.json" > "$FIXTURE/package.json"
printf '%s\n' '*.bak' > "$FIXTURE/.gitignore"
printf '%s\n' tracked > "$FIXTURE/skills/demo/SKILL.md"
git -C "$FIXTURE" init -q
git -C "$FIXTURE" config core.excludesFile /dev/null
git -C "$FIXTURE" add package.json .gitignore skills/demo/SKILL.md
printf '%s\n' new > "$FIXTURE/skills/demo/new-case.md"
packed_strays "$FIXTURE" working-tree "$TMP/fixture-new"
[ ! -s "$TMP/fixture-new" ] ||
  fail "an untracked, unignored new file failed the working-tree check: $(cat "$TMP/fixture-new")"
packed_strays "$FIXTURE" tracked "$TMP/fixture-tracked"
grep -qx 'skills/demo/new-case.md' "$TMP/fixture-tracked" ||
  fail "the tracked-only check missed an untracked file"
printf '%s\n' junk > "$FIXTURE/skills/demo/notes.bak"
packed_strays "$FIXTURE" working-tree "$TMP/fixture-ignored"
grep -qx 'skills/demo/notes.bak' "$TMP/fixture-ignored" ||
  fail "the working-tree check missed an ignored file"
printf '%s\n' bytecode > "$FIXTURE/skills/demo/scripts/__pycache__/helper.cpython-314.pyc"
printf '%s\n' bytecode > "$FIXTURE/skills/demo/scripts/helper.pyc"
packed_strays "$FIXTURE" working-tree "$TMP/fixture-bytecode"
if grep -q '\.pyc"' "$TMP/fixture-bytecode.json"; then
  fail "package.json \"files\" would pack Python bytecode"
fi

cd "$ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
  fail "package contents are checked against git; run this from a git checkout"
packed_strays "$ROOT" "$MODE" "$TMP/stray"

node - "$TMP/stray.json" "$ROOT/package.json" <<'NODE' || exit 1
const fs = require('fs');
const [packFile, packageFile] = process.argv.slice(2);

const manifest = JSON.parse(fs.readFileSync(packageFile, 'utf8'));
if (manifest.private !== true) {
  process.stderr.write('FAIL [package-contents] package.json must be private; godplans is not published to npm\n');
  process.exit(1);
}

const payload = JSON.parse(fs.readFileSync(packFile, 'utf8'));
const paths = new Set(payload[0].files.map((entry) => entry.path));
for (const required of [
  'scripts/release-check.sh',
  'scripts/eval-matrix.sh',
  'scripts/eval-external.js',
  'scripts/eval-outcome.js',
  'scripts/outcome-summary.js',
  'evals/cases-roster.txt',
  'evals/external/RUBRIC.md',
  'evals/metrics/context-cost.json',
  'evals/outcomes/README.md',
  'requirements/skills-ref.txt'
]) {
  if (!paths.has(required)) {
    process.stderr.write(`FAIL [package-contents] missing ${required}\n`);
    process.exit(1);
  }
}
NODE

if [ -s "$TMP/stray" ]; then
  if [ "$MODE" = tracked ]; then
    fail "the package would ship files git does not track:
$(sed 's/^/  /' "$TMP/stray")"
  fi
  fail "the package would ship files git ignores:
$(sed 's/^/  /' "$TMP/stray")"
fi

echo "ok   [package-contents]"
