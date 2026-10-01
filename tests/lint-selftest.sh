#!/usr/bin/env bash
# tests/lint-selftest.sh: prove that every scripts/lint.sh check fails when it
# should.
#
# Copies the repository (every tracked file and every untracked file git does
# not ignore) into a temporary directory once, and gives the copy its own git
# repository so ignore rules apply and nothing here touches the real index. A
# baseline run proves every --all check passes on that copy. Then each case
# starts from a fresh copy, injects one violation, runs only the relevant
# checks by name, and asserts that scripts/lint.sh exits 1 and prints the
# message naming the problem. The temporary path contains a space on purpose.
#
# The official validator and gh are stand-ins written here, so the result
# never depends on what is installed. Every nested lint runs under the bash
# running this script ($BASH), so /bin/bash tests/lint-selftest.sh tests 3.2.
#
# Usage: bash tests/lint-selftest.sh      (exit 0 when every case passes)
# Bash 3.2 compatible. Writes only inside a temporary directory.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/godplans lint selftest.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
TMP="$(cd "$TMP" && pwd)"
BASE="$TMP/base"
CASE="$TMP/case"
BIN="$TMP/bin"
PASS=0
FAIL=0
OUT=""
RC=0
VALIDATOR_BIN="$BIN/skills-ref-ok"

ok()   { PASS=$((PASS + 1)); }
bad()  { FAIL=$((FAIL + 1)); printf 'FAIL [lint-selftest] %s\n' "$*"; }
show() { printf '%s\n' "$OUT" | sed -n '1,30p' | sed 's/^/    | /'; }

# fresh: a new working copy of the pristine base in $CASE.
fresh() { rm -rf "$CASE"; cp -Rp "$BASE" "$CASE"; }

# run [ARG...]: run the lint in $CASE. Sets OUT and RC. SKILLS_REF_BIN is
# VALIDATOR_BIN; an empty VALIDATOR_BIN leaves the lint to find one itself.
run() {
  RC=0
  OUT="$(cd "$CASE" && SKILLS_REF_BIN="$VALIDATOR_BIN" "${BASH:-bash}" scripts/lint.sh "$@" 2>&1)" || RC=$?
}

# expect NAME RC TEXT...: the last run exited RC and printed every TEXT.
expect() {
  name=$1
  want=$2
  shift 2
  if [ "$RC" != "$want" ]; then
    bad "$name: lint exited $RC, want $want"
    show
    return 0
  fi
  miss=""
  for t in "$@"; do
    printf '%s\n' "$OUT" | grep -qF -- "$t" || miss="$miss [$t]"
  done
  if [ -n "$miss" ]; then
    bad "$name: output lacks$miss"
    show
  else
    ok
  fi
}

# lacks NAME TEXT: the last run did not print TEXT.
lacks() {
  if printf '%s\n' "$OUT" | grep -qF -- "$2"; then
    bad "$1: output should not contain [$2]"
    show
  else
    ok
  fi
}

# count_is NAME N TEXT: the last run printed exactly N lines containing TEXT.
count_is() {
  n=$(printf '%s\n' "$OUT" | grep -cF -- "$3" || true)
  if [ "$n" = "$2" ]; then ok; else bad "$1: $n lines contain [$3], want $2"; show; fi
}

# replace_once FILE OLD NEW: replace the first occurrence of fixed text OLD.
replace_once() {
  awk -v o="$2" -v n="$3" '!done && (i = index($0, o)) { $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); done = 1 } { print }' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# ---- stand-in tools -----------------------------------------------------------
mkdir -p "$BIN" "$TMP/gh-bin" "$TMP/gh-noauth" "$TMP/crash-bin"
printf '#!/bin/sh\nexit 0\n' > "$BIN/skills-ref-ok"
printf '#!/bin/sh\n[ "$1" = "--version" ] && exit 0\necho "Invalid skill: selftest rejection"\nexit 1\n' > "$BIN/skills-ref-reject"
printf '#!%s/no-such-interpreter\n' "$TMP" > "$BIN/skills-ref-broken"
printf '#!/bin/sh\nexit 0\n' > "$TMP/gh-bin/gh"
printf '#!/bin/sh\nexit 1\n' > "$TMP/gh-noauth/gh"
printf '#!/bin/sh\necho "perl: simulated crash" >&2\nexit 2\n' > "$TMP/crash-bin/perl"
chmod +x "$BIN"/* "$TMP/gh-bin/gh" "$TMP/gh-noauth/gh" "$TMP/crash-bin/perl"

# ---- one pristine copy -----------------------------------------------------
mkdir -p "$BASE"
if ! git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'FAIL [lint-selftest] %s is not a git work tree; the self-test needs git to copy it\n' "$ROOT" >&2
  exit 1
fi
(cd "$ROOT" && git ls-files -z --cached --others --exclude-standard |
  while IFS= read -r -d '' f; do
    if [ -e "$f" ] || [ -L "$f" ]; then printf '%s\0' "$f"; fi
  done |
  tar -cf - --null -T -) | (cd "$BASE" && tar -xf -)
(cd "$BASE" && git init -q && git add -A) >/dev/null 2>&1
if [ ! -f "$BASE/scripts/lint.sh" ] || [ ! -d "$BASE/.git" ]; then
  printf 'FAIL [lint-selftest] could not copy the repository into %s\n' "$BASE" >&2
  exit 1
fi
PACKAGE_VERSION=$(awk -F'"' '/"version":/ { print $4; exit }' "$BASE/package.json")
HAVE_PYTHON=0
if command -v python3 >/dev/null 2>&1 && python3 -c 'import ast' >/dev/null 2>&1; then
  HAVE_PYTHON=1
fi

# ---- baseline: the unmodified copy passes every --all check ----------------
fresh
run --all
expect "baseline" 0 "ok   [unicode-clean]" "ok   [domain-parity]" "ok   [official-validator]" "ok   [context-metrics]"
lacks "baseline has no failure" "FAIL ["
lacks "--all leaves out the release-only check" "[tag-release-parity]"
if [ "$FAIL" -gt 0 ]; then
  printf 'lint-selftest: the unmodified copy already fails; fix that before trusting the cases below\n'
fi

# ---- arguments ---------------------------------------------------------------
run dir-name-match no-such-check
expect "an unknown check name fails" 1 "Unknown check: no-such-check"
lacks "no check runs when a name is unknown" "ok   [dir-name-match]"
run ""
expect "an empty check name fails instead of running nothing" 1 "Empty or blank check name: ''"
run dir-name-match " "
expect "a blank check name fails" 1 "Empty or blank check name: ' '"
lacks "no check runs when a name is blank" "ok   [dir-name-match]"
run dir-name-match references-exist
expect "several names run every named check" 0 "ok   [dir-name-match]" "ok   [references-exist]"
run --verbose dir-name-match
expect "--verbose before a name runs only that check" 0 "ok   [dir-name-match]"
lacks "--verbose is only a flag" "[unicode-clean]"
run dir-name-match --verbose
expect "--verbose after a name is still only a flag" 0 "ok   [dir-name-match]"
lacks "--verbose after a name runs nothing else" "[unicode-clean]"

# ---- one failure never stops the run ---------------------------------------
fresh
printf 'a \342\200\224 b\n' >> "$CASE/docs/ABOUT.md"
printf '%s\n' '{ invalid json' > "$CASE/evals/cases/brownfield-cli/INPUT/package.json"
run --all
expect "--all reports every failing check and runs the rest" 1 \
  "FAIL [unicode-clean] non-ASCII character in docs/ABOUT.md:" \
  "FAIL [json-valid] invalid JSON: evals/cases/brownfield-cli/INPUT/package.json" \
  "ok   [context-metrics]" \
  "FAIL [lint] failing checks: unicode-clean json-valid"

# A check that crashes (perl exits 2) fails the run, and the next check runs.
fresh
RC=0
OUT="$(cd "$CASE" && PATH="$TMP/crash-bin:$PATH" SKILLS_REF_BIN="$VALIDATOR_BIN" "${BASH:-bash}" scripts/lint.sh unicode-clean dir-name-match 2>&1)" || RC=$?
expect "a check that crashes fails the run" 1 "FAIL [unicode-clean] the check stopped early (exit 2)" "ok   [dir-name-match]"
lacks "a crash is never reported as a pass" "ok   [unicode-clean]"

# ---- unicode-clean -----------------------------------------------------------
fresh
printf 'Launch \360\237\232\200 now\n' >> "$CASE/README.md"                                 # emoji, tracked .md
printf '# \342\200\234quoted\342\200\235\n' >> "$CASE/skills/godplans/scripts/style-stats.py" # smart quotes, tracked .py
printf '# a \342\206\222 b\n' >> "$CASE/requirements/skills-ref.txt"                        # arrow, tracked .txt
printf 'tree\n\342\224\234\342\224\200 x\n' > "$CASE/docs/new notes.md"                       # box drawing, untracked
mkdir -p "$CASE/.godplans" "$CASE/.venv-skills-ref/lib"
printf 'plan \342\200\224 local\n' > "$CASE/.godplans/PLAN.mdx"                               # git-ignored
printf '{"name": "caf\303\251"}\n' > "$CASE/.venv-skills-ref/lib/METADATA.json"               # git-ignored
run unicode-clean
expect "unicode-clean flags tracked .md, .py, and .txt files and untracked files" 1 \
  "FAIL [unicode-clean] non-ASCII character in README.md:" \
  "FAIL [unicode-clean] non-ASCII character in skills/godplans/scripts/style-stats.py:" \
  "FAIL [unicode-clean] non-ASCII character in requirements/skills-ref.txt:" \
  "FAIL [unicode-clean] non-ASCII character in docs/new notes.md:"
lacks "unicode-clean skips git-ignored plan output" ".godplans/PLAN.mdx"
lacks "unicode-clean skips the git-ignored validator venv" ".venv-skills-ref"

# Without git (an unpacked npm tarball or an export), a name allowlist and a
# prune list stand in for the ignore rules.
fresh
rm -rf "$CASE/.git"
run unicode-clean json-valid
expect "without git a clean copy passes" 0 "ok   [unicode-clean]" "ok   [json-valid]"
mkdir -p "$CASE/.godplans" "$CASE/.venv-skills-ref/lib" "$CASE/node_modules/dep" "$CASE/.claude/worktrees/other"
printf 'plan \342\200\224 local\n' > "$CASE/.godplans/PLAN.mdx"
printf '{"truncated": ' > "$CASE/.godplans/PLAN.json"
printf '{"name": "caf\303\251"\n' > "$CASE/.venv-skills-ref/lib/METADATA.json"
printf '{"name": "caf\303\251"\n' > "$CASE/node_modules/dep/package.json"
printf 'a \342\200\224 b\n' > "$CASE/.claude/worktrees/other/README.md"
printf '# \342\200\234quoted\342\200\235\n' >> "$CASE/skills/godplans/scripts/style-stats.py"
run unicode-clean json-valid
expect "without git authored files are still scanned" 1 \
  "FAIL [unicode-clean] non-ASCII character in skills/godplans/scripts/style-stats.py:" \
  "ok   [json-valid]"
lacks "without git plan output is skipped" ".godplans/PLAN"
lacks "without git the validator venv is skipped" ".venv-skills-ref"
lacks "without git node_modules is skipped" "node_modules"
lacks "without git other worktrees are skipped" ".claude/worktrees"

# ---- version-parity ----------------------------------------------------------
fresh
perl -0pi -e 's/"version": "[^"]+"/"version": "9.9.9"/' "$CASE/package.json"
run version-parity
expect "version-parity flags package drift" 1 "FAIL [version-parity] package version (9.9.9) != SKILL.md version"

fresh
rm "$CASE/.claude-plugin/marketplace.json"
run version-parity
expect "version-parity names a missing surface" 1 "FAIL [version-parity] missing version surface: .claude-plugin/marketplace.json"
lacks "a missing surface is a failure, not a crash" "stopped early"

# ---- description-length and description-parity -----------------------------
fresh
perl -0pi -e 's/^description: .*$/"description: \"" . join(" ", ("plan") x 220) . "\""/me' "$CASE/skills/godplans/SKILL.md"
run description-length
expect "description-length flags a long description" 1 "FAIL [description-length] description is 1099 characters; Agent Skills spec bound is 1-1024"

# Only one double-quoted line is read; a folded or continued description is
# refused by name rather than measured.
fresh
perl -0pi -e 's/^description: "(.*)"$/my $d = $1; $d =~ s{(.{60,}?) }{$1\n  }g; "description: >-\n  $d"/me' "$CASE/skills/godplans/SKILL.md"
run description-length description-parity
expect "a folded description is refused" 1 \
  "FAIL [description-length] cannot read the SKILL.md description: skills/godplans/SKILL.md description must be one double-quoted line" \
  "FAIL [description-parity] cannot compare descriptions: skills/godplans/SKILL.md description must be one double-quoted line"
fresh
perl -0pi -e 's/^description: "(.{40,}?) (.*)"$/description: "$1\n  $2"/m' "$CASE/skills/godplans/SKILL.md"
run description-length
expect "a double-quoted description continued on a second line is refused" 1 "FAIL [description-length] cannot read the SKILL.md description: skills/godplans/SKILL.md description must be one double-quoted line"

# Escapes are decoded before measuring and comparing: 24 characters, not 26.
fresh
perl -0pi -e 's/^description: ".*"$/description: "Plan \\"everything\\" first."/m' "$CASE/skills/godplans/SKILL.md"
perl -0pi -e 's/("description": )"[^"]*"/$1"Plan \\"everything\\" first."/' "$CASE/plugins/godplans/.claude-plugin/plugin.json"
perl -0pi -e 's/("source": "\.\/plugins\/godplans",\s*"description": )"[^"]*"/$1"Plan \\"everything\\" first."/' "$CASE/.claude-plugin/marketplace.json"
run --verbose description-length description-parity
expect "an escaped quote is one character and compares decoded" 0 "description length: 24" "ok   [description-length]" "ok   [description-parity]"

fresh
perl -0pi -e 's/("description": )"[^"]*"/$1"A stale description"/' "$CASE/plugins/godplans/.claude-plugin/plugin.json"
perl -0pi -e 's/("source": "\.\/plugins\/godplans",\s*"description": )"[^"]*"/$1"A stale description"/' "$CASE/.claude-plugin/marketplace.json"
run description-parity
expect "description-parity flags both manifests and names the fix" 1 \
  "FAIL [description-parity] plugins/godplans/.claude-plugin/plugin.json description differs from the SKILL.md frontmatter description" \
  "FAIL [description-parity] .claude-plugin/marketplace.json godplans plugin entry description differs from the SKILL.md frontmatter description" \
  "copy the SKILL.md description into it verbatim"

fresh
perl -0pi -e 's/("plugins": \[\s*\{\s*"name": )"godplans"/$1"godplan"/' "$CASE/.claude-plugin/marketplace.json"
run description-parity
expect "description-parity needs the godplans marketplace entry" 1 "FAIL [description-parity] .claude-plugin/marketplace.json has 0 plugin entries named godplans; want exactly 1"

# ---- dir-name-match, references-exist, modules-complete -------------------
fresh
replace_once "$CASE/skills/godplans/SKILL.md" 'name: godplans' 'name: godplan'
run dir-name-match
expect "dir-name-match flags a renamed skill" 1 "FAIL [dir-name-match] frontmatter name (godplan) != directory name (godplans)"

fresh
printf '\nSee `references/missing-module.md`.\n' >> "$CASE/skills/godplans/SKILL.md"
run references-exist
expect "references-exist flags a missing module" 1 "FAIL [references-exist] SKILL.md names references/missing-module.md but it does not exist"

fresh
grep -v '^## Task seeds' "$CASE/skills/godplans/references/ux.md" > "$CASE/ux.tmp" && mv "$CASE/ux.tmp" "$CASE/skills/godplans/references/ux.md"
run modules-complete
expect "modules-complete flags a missing section" 1 "FAIL [modules-complete] ux.md missing section: ## Task seeds"

# ---- domain-parity -----------------------------------------------------------
# A complete new module that no list names passes modules-complete and fails
# domain-parity once per list.
fresh
printf '# Product ops\n\n## Lineage\n\n## Decisions to force\n\n## Plan requirements\n\n## Task seeds\n\n## Self-audit rubric\n\n## Anti-patterns refused\n' > "$CASE/skills/godplans/references/product-ops.md"
run modules-complete domain-parity
expect "a new module unknown to every list fails domain-parity" 1 \
  "ok   [modules-complete]" \
  "FAIL [domain-parity] skills/godplans/SKILL.md Phase 4 table lacks domain module product-ops" \
  "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh %known_domain lacks domain module product-ops" \
  "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh %module_prefix keys lacks domain module product-ops" \
  "FAIL [domain-parity] scripts/build-prompt.sh full REFERENCE_ORDER lacks domain module product-ops" \
  "FAIL [domain-parity] scripts/context-metrics.js coreModules + lazyModules lacks domain module product-ops" \
  "FAIL [domain-parity] tests/portable-prompt.test.sh expected_refs + lazy_refs lacks domain module product-ops"

# One list drifting fails only on that file: once as a missing module and
# once as a gap in its lazy list.
fresh
grep -vx 'ux' "$CASE/tests/portable-prompt.test.sh" > "$CASE/pp.tmp" && mv "$CASE/pp.tmp" "$CASE/tests/portable-prompt.test.sh"
run domain-parity
expect "one drifting list fails domain-parity" 1 \
  "FAIL [domain-parity] tests/portable-prompt.test.sh expected_refs + lazy_refs lacks domain module ux" \
  "FAIL [domain-parity] tests/portable-prompt.test.sh lazy_refs lacks ux, which scripts/context-metrics.js lazyModules names"
count_is "only the drifting file is named" 2 "FAIL [domain-parity]"
count_is "every message names the drifting file" 2 "FAIL [domain-parity] tests/portable-prompt.test.sh"

# The core and lazy split, the lazy module sentence, and the module count in
# build-prompt.sh are compared too, even when every union list is complete.
fresh
replace_once "$CASE/scripts/build-prompt.sh" 'all 19 domain modules' 'all 18 domain modules'
replace_once "$CASE/scripts/build-prompt.sh" 'The lazy modules are business, llm, ux, ui,' 'The lazy modules are business, llm, ui,'
perl -0pi -e 's/^product architecture stack database security\nexemplar plan-format$/product architecture stack database\nexemplar plan-format/m' "$CASE/scripts/build-prompt.sh"
perl -0pi -e 's/^ux\n//m; s/^security\n/security\nux\n/m' "$CASE/tests/portable-prompt.test.sh"
run domain-parity
expect "build-prompt prose and the core and lazy split are compared" 1 \
  "FAIL [domain-parity] scripts/build-prompt.sh full-mode header says all 18 domain modules, but skills/godplans/references has 19" \
  "FAIL [domain-parity] scripts/build-prompt.sh core-mode lazy module sentence lacks ux, which scripts/context-metrics.js lazyModules names" \
  "FAIL [domain-parity] scripts/build-prompt.sh core REFERENCE_ORDER lacks security, which scripts/context-metrics.js coreModules names" \
  "FAIL [domain-parity] tests/portable-prompt.test.sh expected_refs names ux, which scripts/context-metrics.js coreModules does not" \
  "FAIL [domain-parity] tests/portable-prompt.test.sh lazy_refs lacks ux, which scripts/context-metrics.js lazyModules names"
lacks "a complete union list is not reported" "expected_refs + lazy_refs lacks"

# Requirement prefixes: one per module, and each module defines its
# requirements under its own prefix.
fresh
perl -pi -e "s/'seo' => 'SEO'/'seo' => 'SEOX'/; s/'ux' => 'UX'/'ux' => 'UI'/" "$CASE/skills/godplans/scripts/validate-plan.sh"
run domain-parity
expect "requirement prefixes are compared with the modules" 1 \
  "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh %module_prefix gives the prefix UI to ux and ui" \
  "FAIL [domain-parity] skills/godplans/references/seo.md defines no R-SEOX-N requirement" \
  "FAIL [domain-parity] skills/godplans/references/seo.md defines R-SEO-N requirements, but %module_prefix gives seo the prefix SEOX"

# The validator derives the prefix-to-module map with reverse; a validator
# with neither that line nor a %requirement_domain table fails.
fresh
perl -0pi -e 's/^my %prefix_module = reverse %module_prefix;\n//m' "$CASE/skills/godplans/scripts/validate-plan.sh"
run domain-parity
expect "a validator with no prefix-to-module map fails" 1 "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh prefix-to-module map: cannot find %prefix_module = reverse %module_prefix or a %requirement_domain table"
perl -0pi -e 's/^(my %module_prefix = \(.*?\);\n)/$1my %prefix_module = reverse %module_prefix;\n/ms' "$CASE/skills/godplans/scripts/validate-plan.sh"
run domain-parity
expect "a prefix map derived with reverse passes" 0 "ok   [domain-parity]"

fresh
perl -0pi -e 's/(%known_domain = map \{ \$_ => 1 \} qw\()/$1\n    analytics/' "$CASE/skills/godplans/scripts/validate-plan.sh"
perl -0pi -e "s/'seo' => 'SEO',\\s*//" "$CASE/skills/godplans/scripts/validate-plan.sh"
run domain-parity
expect "validator domain tables are compared" 1 \
  "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh %known_domain names analytics, but skills/godplans/references/analytics.md does not exist" \
  "FAIL [domain-parity] skills/godplans/scripts/validate-plan.sh %module_prefix keys lacks domain module seo"

# ---- symlinks-valid ----------------------------------------------------------
fresh
rm "$CASE/.claude/skills/godplans"
printf '../../skills/godplans' > "$CASE/.claude/skills/godplans"
rm "$CASE/.agents/skills/godplans"
mkdir "$CASE/.agents/skills/godplans"
rm "$CASE/plugins/godplans/skills"
ln -s ../../skills/godplans "$CASE/plugins/godplans/skills"
run symlinks-valid
expect "symlinks-valid flags a link file, a copied directory, and a wrong target" 1 \
  "FAIL [symlinks-valid] .claude/skills/godplans is not a symlink to skills/godplans" \
  "FAIL [symlinks-valid] .agents/skills/godplans is not a symlink to skills/godplans" \
  "FAIL [symlinks-valid] plugins/godplans/skills resolves to" ", not skills"

fresh
rm "$CASE/plugins/godplans/skills"
run symlinks-valid
expect "symlinks-valid flags a missing plugin projection" 1 "FAIL [symlinks-valid] plugins/godplans/skills does not exist; it must be a symlink to skills"

# ---- json-valid --------------------------------------------------------------
fresh
printf '%s\n' '{ invalid json' > "$CASE/evals/cases/brownfield-cli/INPUT/package.json"
mkdir -p "$CASE/.godplans"
printf '{"truncated": ' > "$CASE/.godplans/PLAN.json"
run json-valid
expect "json-valid flags a tracked file" 1 "FAIL [json-valid] invalid JSON: evals/cases/brownfield-cli/INPUT/package.json"
lacks "json-valid skips git-ignored plan output" ".godplans/PLAN.json"

# ---- shell-syntax ------------------------------------------------------------
# The printf arguments keep this file's own lines from matching the bash 4
# pattern, since shell-syntax scans this file too.
fresh
printf 'if then\n' >> "$CASE/evals/outcomes/cases/tenant-notes-api/VERIFY.sh"
printf 'fi\n' >> "$CASE/install.sh"
printf '#!/usr/bin/env bash\nma%sfile -t lines < /dev/null\n' p > "$CASE/scripts/b4.sh"
printf '#!/usr/bin/env bash\necho "$%s{1,,}"\n' '' > "$CASE/scripts/b4c.sh"
printf '#!/usr/bin/env bash\n# a comment may say ma%sfile\nx=1\n' p > "$CASE/scripts/b3.sh"
run shell-syntax
expect "shell-syntax parses every script and flags bash 4 constructs" 1 \
  "FAIL [shell-syntax] evals/outcomes/cases/tenant-notes-api/VERIFY.sh does not parse as bash" \
  "FAIL [shell-syntax] install.sh does not parse as sh" \
  "FAIL [shell-syntax] scripts/b4.sh uses a bash 4 construct" \
  "FAIL [shell-syntax] scripts/b4c.sh uses a bash 4 construct"
lacks "shell-syntax skips comment lines" "scripts/b3.sh"

# One script per further bash 4 or later construct. Each line below carries a
# ~~ that is stripped when the script is written, so this file's own lines
# never match the pattern.
fresh
n=0
while IFS= read -r construct; do
  n=$((n + 1))
  printf '#!/usr/bin/env bash\n%s\n' "$construct" | sed 's/~~//g' > "$CASE/scripts/b4-$n.sh"
done <<'EOF'
declare -~~g x=1
echo "${x@~~Q}"
a=(1 2); echo "${a[-~~1]}"
sh~~opt -s globstar
wa~~it -n
ls |~~& cat
[[ -~~v x ]] && echo set
case x in a) echo a ;~~& b) echo b ;; esac
local -~~u y
EOF
run shell-syntax
i=0
while [ "$i" -lt "$n" ]; do
  i=$((i + 1))
  expect "shell-syntax flags bash 4 construct $i: $(sed -n 2p "$CASE/scripts/b4-$i.sh")" 1 "FAIL [shell-syntax] scripts/b4-$i.sh uses a bash 4 construct"
done

# ---- js-syntax and python-syntax --------------------------------------------
fresh
printf 'function (\n' >> "$CASE/scripts/summarize-matrix.js"
run js-syntax
expect "js-syntax flags a broken script" 1 "FAIL [js-syntax] scripts/summarize-matrix.js does not parse:"

fresh
printf 'def broken(:\n' >> "$CASE/skills/godplans/scripts/style-stats.py"
run python-syntax
if [ "$HAVE_PYTHON" = "1" ]; then
  expect "python-syntax flags a broken script" 1 "FAIL [python-syntax] skills/godplans/scripts/style-stats.py does not parse:"
  if [ -e "$CASE/skills/godplans/scripts/__pycache__" ]; then
    bad "python-syntax wrote __pycache__ into the skill directory"
  else
    ok
  fi
else
  expect "python-syntax skips visibly without python3" 0 "skip [python-syntax] python3 cannot run"
fi

# ---- eval-cases, product-surfaces, context-metrics ------------------------
fresh
printf 'bogus|x|y\n' >> "$CASE/evals/cases/greenfield-saas/EXPECTATIONS"
run eval-cases
expect "eval-cases flags an invalid manifest" 1 "FAIL [eval-cases] behavioral case contract failed"

fresh
chmod -x "$CASE/scripts/eval-matrix.sh"
run product-surfaces
expect "product-surfaces flags a non-executable entry point" 1 "FAIL [product-surfaces] missing executable: scripts/eval-matrix.sh"

fresh
printf '\nA sentence that changes the module size.\n' >> "$CASE/skills/godplans/references/compliance.md"
run context-metrics
expect "context-metrics flags stale metrics" 1 "FAIL [context-metrics] evals/metrics/context-cost.json is stale"

# ---- action-pins -------------------------------------------------------------
fresh
printf '      - uses: actions/checkout@v4\n' >> "$CASE/.github/workflows/lint.yml"
run action-pins
expect "action-pins flags the - uses: list-item form" 1 "FAIL [action-pins] floating GitHub Action reference in .github/workflows/lint.yml: actions/checkout@v4"

fresh
printf '      - uses: "actions/checkout@%s"\n' 0123456789abcdef0123456789abcdef01234567 >> "$CASE/.github/workflows/lint.yml"
printf "      - uses: './.github/actions/local'\n" >> "$CASE/.github/workflows/lint.yml"
run action-pins
expect "action-pins accepts a quoted SHA pin and a local action" 0 "ok   [action-pins]"

# ---- official-validator ------------------------------------------------------
fresh
VALIDATOR_BIN="$BIN/skills-ref-reject"
run official-validator
expect "a validator that rejects the skill fails" 1 "FAIL [official-validator] official skills-ref validator rejected skills/godplans (exit 1):" "Invalid skill: selftest rejection"
VALIDATOR_BIN="$TMP/no-such-dir/skills-ref"
run official-validator
expect "an explicit SKILLS_REF_BIN that does not exist fails" 1 "FAIL [official-validator] SKILLS_REF_BIN=$TMP/no-such-dir/skills-ref is not an executable file"
VALIDATOR_BIN="$BIN/skills-ref-broken"
run official-validator
expect "an explicit SKILLS_REF_BIN that cannot run fails" 1 "FAIL [official-validator] could not execute $BIN/skills-ref-broken"
lacks "a validator that cannot run is not reported as a rejection" "rejected"
# Found automatically, the repo venv comes before PATH, and a copy that cannot
# run is a visible skip rather than a rejection.
mkdir -p "$CASE/.venv-skills-ref/bin"
cp "$BIN/skills-ref-broken" "$CASE/.venv-skills-ref/bin/skills-ref"
VALIDATOR_BIN=""
run official-validator
expect "a broken venv validator is skipped visibly" 0 "skip [official-validator] $CASE/.venv-skills-ref/bin/skills-ref is installed but cannot run"
cp "$BIN/skills-ref-ok" "$CASE/.venv-skills-ref/bin/skills-ref"
run --verbose official-validator
expect "the repo venv validator is found without SKILLS_REF_BIN" 0 "skills-ref accepted skills/godplans ($CASE/.venv-skills-ref/bin/skills-ref)" "ok   [official-validator]"
VALIDATOR_BIN="$BIN/skills-ref-ok"

# No validator anywhere is a visible skip, never an ok. PATH keeps every
# directory except those holding a skills-ref.
fresh
NOREF_PATH=""
old_ifs=$IFS
IFS=:
for dir in $PATH; do
  if [ -n "$dir" ] && [ ! -x "$dir/skills-ref" ]; then
    NOREF_PATH="${NOREF_PATH:+$NOREF_PATH:}$dir"
  fi
done
IFS=$old_ifs
if PATH="$NOREF_PATH" command -v mktemp >/dev/null 2>&1; then
  RC=0
  OUT="$(cd "$CASE" && PATH="$NOREF_PATH" SKILLS_REF_BIN="" "${BASH:-bash}" scripts/lint.sh official-validator 2>&1)" || RC=$?
  expect "no installed validator is skipped visibly" 0 "skip [official-validator] skills-ref not installed"
  lacks "no installed validator is never reported ok" "ok   [official-validator]"
else
  printf 'lint-selftest: note: skills-ref shares a directory with mktemp; the no-validator case was not run\n'
fi

# ---- prompt-fresh ------------------------------------------------------------
fresh
printf '\nstale marker\n' >> "$CASE/PROMPT.md"
before=$(cksum < "$CASE/PROMPT.md")
run prompt-fresh
expect "prompt-fresh flags a stale prompt" 1 "FAIL [prompt-fresh] PROMPT.md is stale"
after=$(cksum < "$CASE/PROMPT.md")
if [ "$before" = "$after" ]; then ok; else bad "prompt-fresh mutated PROMPT.md"; fi

fresh
rm "$CASE/skills/godplans/references/security.md"
run prompt-fresh dir-name-match
expect "a failing prompt build is a failure and the next check runs" 1 "FAIL [prompt-fresh] scripts/build-prompt.sh failed" "ok   [dir-name-match]"
lacks "a failing prompt build is not a crash" "stopped early"

# ---- tag-release-parity (release-only; gh is a stand-in) -------------------
# tag.gpgSign=true in the user's config would turn the tag into a signed
# annotated tag that needs a message, so signing is off and the editor is a
# no-op.
fresh
(cd "$CASE" &&
  git -c user.name=selftest -c user.email=selftest@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m selftest &&
  GIT_EDITOR=true git -c tag.gpgSign=false tag v0.0.1) >/dev/null 2>&1
if git -C "$CASE" rev-parse -q --verify refs/tags/v0.0.1 >/dev/null 2>&1; then
  RC=0
  OUT="$(cd "$CASE" && PATH="$TMP/gh-bin:$PATH" "${BASH:-bash}" scripts/lint.sh tag-release-parity 2>&1)" || RC=$?
  expect "tag-release-parity flags a tag without a matching version or release" 1 \
    "FAIL [tag-release-parity] v0.0.1 package version ($PACKAGE_VERSION) does not match 0.0.1" \
    "FAIL [tag-release-parity] v0.0.1 has no matching published GitHub release"
else
  bad "tag-release-parity setup: could not create the tag v0.0.1 in the copy"
fi

# Without an authenticated gh the check is a visible skip, never an ok.
RC=0
OUT="$(cd "$CASE" && PATH="$TMP/gh-noauth:$PATH" "${BASH:-bash}" scripts/lint.sh tag-release-parity 2>&1)" || RC=$?
expect "tag-release-parity without an authenticated gh is skipped visibly" 0 "skip [tag-release-parity] authenticated gh CLI unavailable"
lacks "tag-release-parity without gh is never reported ok" "ok   [tag-release-parity]"

printf 'lint-selftest: %d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
echo "ok   [lint-selftest]"
