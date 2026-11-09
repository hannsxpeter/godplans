#!/usr/bin/env sh

set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TMP_ROOT=${TMPDIR:-/tmp}/godplans-install-test.$$
PASS_COUNT=0

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT HUP INT TERM

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  echo "ok $PASS_COUNT - $1"
}

new_fixture() {
  fixture=$TMP_ROOT/fixture-$1
  mkdir -p "$fixture/skills"
  cp "$ROOT/install.sh" "$fixture/install.sh"
  cp -R "$ROOT/skills/godplans" "$fixture/skills/godplans"
  printf '%s\n' "$1" > "$fixture/skills/godplans/install-test-payload"
}

run_global() {
  fixture=$1
  home=$2
  shift 2
  HOME=$home \
    AGENTS_SKILLS_DIR=$home/.agents/skills \
    CLAUDE_SKILLS_DIR=$home/.claude/skills \
    sh "$fixture/install.sh" "$@"
}

run_project() {
  fixture=$1
  home=$2
  project=$3
  shift 3
  HOME=$home sh "$fixture/install.sh" --project "$project" "$@"
}

assert_file_contains() {
  grep -F "$2" "$1" >/dev/null 2>&1 || fail "$1 does not contain: $2"
}

mkdir -p "$TMP_ROOT"

# Documented aliases must resolve to their canonical destination names.
new_fixture alias
home=$TMP_ROOT/home-alias
mkdir -p "$home"
run_global "$fixture" "$home" --tools claude,codex >/dev/null
[ -L "$home/.agents/skills/godplans" ] || fail "codex alias did not install the agents target"
[ -L "$home/.claude/skills/godplans" ] || fail "claude target was not installed"
for agent_alias in cursor zed vscode copilot gemini gemini-cli opencode amp kilo goose; do
  run_global "$fixture" "$home" --tools "$agent_alias" >/dev/null
  [ -L "$home/.agents/skills/godplans" ] || fail "$agent_alias alias did not install the agents target"
done
run_global "$fixture" "$home" --tools claude-code >/dev/null
[ -L "$home/.claude/skills/godplans" ] || fail "claude-code alias did not install the Claude target"
run_global "$fixture" "$home" --tools factory-droid --copy >/dev/null
[ -d "$home/.factory/skills/godplans" ] || fail "factory-droid alias did not install the Factory target"
pass "documented aliases map to canonical targets"

# Unknown names and mode-incompatible selections must fail before writing.
new_fixture reject
home=$TMP_ROOT/home-reject
project=$TMP_ROOT/project-reject
mkdir -p "$home" "$project"
if run_global "$fixture" "$home" --tools agents,unknown >"$TMP_ROOT/unknown.out" 2>&1; then
  fail "unknown tool name succeeded"
fi
assert_file_contains "$TMP_ROOT/unknown.out" "Unknown tool: unknown"
[ ! -e "$home/.agents/skills/godplans" ] || fail "validation wrote a target before rejecting an unknown tool"
if run_global "$fixture" "$home" --tools copilot-cloud >"$TMP_ROOT/global-noop.out" 2>&1; then
  fail "project-only target succeeded in global mode"
fi
assert_file_contains "$TMP_ROOT/global-noop.out" "not available in global mode"
if run_project "$fixture" "$home" "$project" --tools factory >"$TMP_ROOT/project-noop.out" 2>&1; then
  fail "global-only target succeeded in project mode"
fi
assert_file_contains "$TMP_ROOT/project-noop.out" "not available in project mode"
run_global "$fixture" "$home" --tools factory --copy >/dev/null
[ -d "$home/.factory/skills/godplans" ] || fail "an explicitly selected undetected tool silently did nothing"
pass "invalid and no-op target selections are rejected atomically"

# Both installation forms must work in both scopes.
new_fixture matrix
home=$TMP_ROOT/home-matrix
project=$TMP_ROOT/project-matrix
mkdir -p "$home" "$project"
run_global "$fixture" "$home" --tools agents >/dev/null
[ -L "$home/.agents/skills/godplans" ] || fail "global symlink install did not create a symlink"
run_global "$fixture" "$home" --tools claude --copy >/dev/null
[ -d "$home/.claude/skills/godplans" ] || fail "global copy install did not create a directory"
[ ! -L "$home/.claude/skills/godplans" ] || fail "global copy install created a symlink"
run_project "$fixture" "$home" "$project" --tools agents >/dev/null
[ -L "$project/.agents/skills/godplans" ] || fail "project symlink install did not create a symlink"
run_project "$fixture" "$home" "$project" --tools claude,copilot-cloud --copy >/dev/null
[ -d "$project/.claude/skills/godplans" ] || fail "project copy install missed Claude"
[ -d "$project/.github/skills/godplans" ] || fail "project copy install missed Copilot cloud"
[ ! -L "$project/.github/skills/godplans" ] || fail "project Copilot copy created a symlink"
pass "copy and symlink installs work globally and per project"

# The global agents and claude roots honor their override variables at
# non-default paths, and --help names them. run_global pins both to the fake
# HOME, so these runs call the installer directly.
new_fixture override
home=$TMP_ROOT/home-override
mkdir -p "$home"
HOME=$home AGENTS_SKILLS_DIR=$TMP_ROOT/custom-agents CLAUDE_SKILLS_DIR=$TMP_ROOT/custom-claude \
  sh "$fixture/install.sh" --tools agents,claude >/dev/null
[ -L "$TMP_ROOT/custom-agents/godplans" ] || fail "AGENTS_SKILLS_DIR was ignored"
[ -L "$TMP_ROOT/custom-claude/godplans" ] || fail "CLAUDE_SKILLS_DIR was ignored"
[ ! -e "$home/.agents/skills/godplans" ] || fail "AGENTS_SKILLS_DIR override still wrote under HOME"
[ ! -e "$home/.claude/skills/godplans" ] || fail "CLAUDE_SKILLS_DIR override still wrote under HOME"
HOME=$home AGENTS_SKILLS_DIR=$TMP_ROOT/custom-agents CLAUDE_SKILLS_DIR=$TMP_ROOT/custom-claude \
  sh "$fixture/install.sh" --tools agents,claude --uninstall >/dev/null
[ ! -e "$TMP_ROOT/custom-agents/godplans" ] || fail "uninstall left the AGENTS_SKILLS_DIR install"
[ ! -e "$TMP_ROOT/custom-claude/godplans" ] || fail "uninstall left the CLAUDE_SKILLS_DIR install"
sh "$fixture/install.sh" --help > "$TMP_ROOT/help.out"
assert_file_contains "$TMP_ROOT/help.out" "AGENTS_SKILLS_DIR=DIR CLAUDE_SKILLS_DIR=DIR"
[ "$(tail -n 1 "$TMP_ROOT/help.out")" = "instructions are printed at the end." ] ||
  fail "--help does not print the whole usage block"
pass "global root overrides are honored and documented"

# An unowned directory must survive install and uninstall attempts.
new_fixture collision
home=$TMP_ROOT/home-collision
mkdir -p "$home/.agents/skills/godplans"
printf '%s\n' keep > "$home/.agents/skills/godplans/sentinel"
if run_global "$fixture" "$home" --tools agents >"$TMP_ROOT/collision-install.out" 2>&1; then
  fail "install replaced an unowned destination"
fi
assert_file_contains "$TMP_ROOT/collision-install.out" "Refusing to replace unowned destination"
assert_file_contains "$home/.agents/skills/godplans/sentinel" "keep"
if run_global "$fixture" "$home" --tools agents --uninstall >"$TMP_ROOT/collision-uninstall.out" 2>&1; then
  fail "uninstall accepted an unowned destination"
fi
assert_file_contains "$TMP_ROOT/collision-uninstall.out" "Refusing to remove unowned destination"
assert_file_contains "$home/.agents/skills/godplans/sentinel" "keep"
pass "unowned destinations are preserved on install and uninstall"

# Installer-owned copies must update and uninstall cleanly.
new_fixture owned-copy
home=$TMP_ROOT/home-owned-copy
mkdir -p "$home"
run_global "$fixture" "$home" --tools agents --copy >/dev/null
assert_file_contains "$home/.agents/skills/godplans/install-test-payload" "owned-copy"
printf '%s\n' updated > "$fixture/skills/godplans/install-test-payload"
run_global "$fixture" "$home" --tools agents --copy >/dev/null
assert_file_contains "$home/.agents/skills/godplans/install-test-payload" "updated"
run_global "$fixture" "$home" --tools agents --uninstall >/dev/null
[ ! -e "$home/.agents/skills/godplans" ] || fail "owned copy survived uninstall"
pass "owned copies can be updated and uninstalled"

# Installer-owned symlinks must reinstall and uninstall cleanly.
new_fixture owned-link
home=$TMP_ROOT/home-owned-link
mkdir -p "$home"
run_global "$fixture" "$home" --tools agents >/dev/null
run_global "$fixture" "$home" --tools agents >/dev/null
[ -L "$home/.agents/skills/godplans" ] || fail "owned symlink reinstall did not preserve link mode"
mv "$fixture" "$fixture-moved"
fixture=$fixture-moved
run_global "$fixture" "$home" --tools agents >/dev/null
[ -f "$home/.agents/skills/godplans/install-test-payload" ] || fail "owned symlink was not repaired after its source moved"
run_global "$fixture" "$home" --tools agents --uninstall >/dev/null
[ ! -e "$home/.agents/skills/godplans" ] || fail "owned symlink survived uninstall"
pass "owned symlinks can be repaired, reinstalled, and uninstalled"

# A stale ownership record must not authorize deletion of a replacement.
new_fixture stale
home=$TMP_ROOT/home-stale
mkdir -p "$home"
run_global "$fixture" "$home" --tools agents >/dev/null
rm "$home/.agents/skills/godplans"
mkdir -p "$home/.agents/skills/godplans"
printf '%s\n' replacement > "$home/.agents/skills/godplans/sentinel"
if run_global "$fixture" "$home" --tools agents --uninstall >"$TMP_ROOT/stale.out" 2>&1; then
  fail "stale ownership record authorized unowned deletion"
fi
assert_file_contains "$home/.agents/skills/godplans/sentinel" "replacement"
rm -rf "$home/.agents/skills/godplans"
mkdir -p "$TMP_ROOT/unowned-link-target"
printf '%s\n' other > "$TMP_ROOT/unowned-link-target/sentinel"
ln -s "$TMP_ROOT/unowned-link-target" "$home/.agents/skills/godplans"
if run_global "$fixture" "$home" --tools agents --uninstall >"$TMP_ROOT/stale-link.out" 2>&1; then
  fail "stale ownership record authorized deletion of a replacement symlink"
fi
assert_file_contains "$home/.agents/skills/godplans/sentinel" "other"
pass "stale ownership state does not delete directory or symlink replacements"

# Force is the explicit escape hatch for unowned install and uninstall.
new_fixture force
home=$TMP_ROOT/home-force
mkdir -p "$home/.agents/skills/godplans"
printf '%s\n' replace > "$home/.agents/skills/godplans/sentinel"
run_global "$fixture" "$home" --tools agents --copy --force >/dev/null
[ ! -e "$home/.agents/skills/godplans/sentinel" ] || fail "forced install preserved the collision"
assert_file_contains "$home/.agents/skills/godplans/install-test-payload" "force"
run_global "$fixture" "$home" --tools agents --uninstall >/dev/null
mkdir -p "$home/.agents/skills/godplans"
printf '%s\n' remove > "$home/.agents/skills/godplans/sentinel"
run_global "$fixture" "$home" --tools agents --uninstall --force >/dev/null
[ ! -e "$home/.agents/skills/godplans" ] || fail "forced uninstall preserved the unowned destination"
pass "force explicitly permits replacement and removal"

# Installing never rewrites the source checkout's tracked PROMPT.md; lint
# prompt-fresh keeps the committed prompt current instead.
new_fixture prompt
mkdir -p "$fixture/scripts"
cp "$ROOT/scripts/build-prompt.sh" "$fixture/scripts/build-prompt.sh"
chmod +x "$fixture/scripts/build-prompt.sh"
printf '%s\n' 'source prompt sentinel' > "$fixture/PROMPT.md"
home=$TMP_ROOT/home-prompt
mkdir -p "$home"
run_global "$fixture" "$home" --tools agents >/dev/null
assert_file_contains "$fixture/PROMPT.md" "source prompt sentinel"
pass "install leaves the source PROMPT.md untouched"

# A copy install omits Python bytecode found in the source checkout, and never
# deletes it from the source.
new_fixture bytecode
mkdir -p "$fixture/skills/godplans/scripts/__pycache__"
printf '%s\n' bytecode > "$fixture/skills/godplans/scripts/__pycache__/style-stats.cpython-314.pyc"
printf '%s\n' bytecode > "$fixture/skills/godplans/scripts/stray.pyc"
home=$TMP_ROOT/home-bytecode
mkdir -p "$home"
run_global "$fixture" "$home" --tools agents --copy >/dev/null
[ -f "$home/.agents/skills/godplans/install-test-payload" ] || fail "bytecode fixture copy did not install"
[ ! -e "$home/.agents/skills/godplans/scripts/__pycache__" ] || fail "copy install shipped __pycache__"
[ ! -e "$home/.agents/skills/godplans/scripts/stray.pyc" ] || fail "copy install shipped a .pyc file"
[ -f "$fixture/skills/godplans/scripts/__pycache__/style-stats.cpython-314.pyc" ] ||
  fail "copy install deleted bytecode from the source checkout"
pass "copy install omits Python bytecode"

echo "1..$PASS_COUNT"
