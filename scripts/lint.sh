#!/usr/bin/env bash
# scripts/lint.sh: meta-linter for godplans.
#
# Mechanically enforces the discipline rules. Replaces "the rule says X"
# with "CI fails if X is violated."
#
# Checks run by --all (the default):
#
#   unicode-clean        no byte above 0x7F (so no em or en dashes, Unicode
#                        arrows, box-drawing characters, smart quotes,
#                        ellipsis characters, or emojis) in any authored text
#                        file: every tracked file and every untracked file git
#                        does not ignore, minus binary assets and frozen eval
#                        results. Without git, a name allowlist stands in.
#   version-parity       every published version surface agrees; a missing
#                        surface fails by name.
#   description-length   the SKILL.md frontmatter description is one
#                        double-quoted line of 1-1024 characters (Agent
#                        Skills spec bound); a folded, literal, plain, or
#                        continued description fails.
#   description-parity   plugin.json and the godplans entry in the marketplace
#                        carry the SKILL.md frontmatter description exactly.
#   dir-name-match       skill directory name matches frontmatter name.
#   references-exist     every references/<file>.md named in SKILL.md exists.
#   modules-complete     every domain module has the six contract sections.
#   domain-parity        the same domain modules appear in references/ (minus
#                        the contract modules), the SKILL.md Phase 4 table,
#                        the validator's %known_domain keys, %module_prefix
#                        keys, and %requirement_domain values (when present),
#                        the full reference order in build-prompt.sh, the
#                        module lists in context-metrics.js, and the module
#                        lists in tests/portable-prompt.test.sh. The core and
#                        lazy split, the lazy module sentence, and the "all N
#                        domain modules" count in build-prompt.sh agree with
#                        them; each module has its own requirement prefix, the
#                        prefix map back to modules is its exact inverse, and
#                        each module defines its requirements under its prefix.
#   symlinks-valid       .agents/skills/godplans and .claude/skills/godplans
#                        are symlinks to skills/godplans, and
#                        plugins/godplans/skills is a symlink to skills.
#   json-valid           every authored JSON file parses.
#   shell-syntax         every authored *.sh parses in its declared shell (sh
#                        or bash) and uses no bash 4 or later construct that
#                        stock macOS /bin/bash 3.2 cannot run.
#   js-syntax            every authored *.js, *.mjs, and *.cjs passes
#                        node --check.
#   python-syntax        every authored *.py parses with ast.parse, which
#                        writes no bytecode; skipped visibly when python3
#                        cannot run.
#   eval-cases           behavioral case manifests are complete and valid.
#   product-surfaces     shipped validator and evaluation entry points exist.
#   action-pins          every third-party GitHub Action (`uses:` or
#                        `- uses:`, quoted or not) uses a full commit SHA.
#   official-validator   runs skills-ref, found in SKILLS_REF_BIN, then
#                        .venv-skills-ref/bin/skills-ref, then PATH. Skips
#                        visibly (a "skip" line, not "ok") when none is
#                        installed or when one found automatically cannot
#                        execute; fails when the validator rejects the skill
#                        or an explicit SKILLS_REF_BIN cannot execute.
#   prompt-fresh         PROMPT.md matches build-prompt.sh without mutation.
#   context-metrics      published prompt and module cost metrics are current.
#
# Release-only (never part of --all; scripts/release-check.sh runs it by name
# because it needs an authenticated gh CLI and the network):
#
#   tag-release-parity   verifies published tags against package versions and
#                        releases; skips visibly without an authenticated gh.
#
# Usage: bash scripts/lint.sh [--verbose] [--all | check-name ...]
#
# Several check names run each named check in the order given. An unknown,
# empty, or blank name fails before any check runs. --verbose is only a flag
# and may appear anywhere. Each check runs in a subshell with errexit on, so a
# command that crashes inside a check counts as a failure, and every later
# check still runs. The exit status is 1 when any check failed.
#
# Bash 3.2 compatible (macOS default). Nested bash runs use the bash running
# this script ($BASH), so /bin/bash scripts/lint.sh tests 3.2.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILL_DIR="$REPO_DIR/skills/godplans"
BASH_BIN="${BASH:-bash}"
TAB="$(printf '\t')"
# Reference files that are contracts rather than planning domains. They skip
# the six-section module contract and are left out of domain-parity.
CONTRACT_MODULES="plan-format discovery compliance exemplar doc-set"
ALL_CHECKS="unicode-clean version-parity description-length description-parity dir-name-match references-exist modules-complete domain-parity symlinks-valid json-valid shell-syntax js-syntax python-syntax eval-cases product-surfaces action-pins official-validator prompt-fresh context-metrics"
RELEASE_CHECKS="tag-release-parity"
VERBOSE=0
TARGETS=""
CHECK=lint
CHECK_BAD=0
CHECK_SKIPPED=0

usage() {
  cat <<EOF
Usage: bash scripts/lint.sh [--verbose] [--all | check-name ...]

With no check names (or --all), runs every check below. Several names run
each named check. One failing check never stops the others; a check that
stops on an error counts as a failure. Exit status 1 when any check failed.

Checks: $ALL_CHECKS
Release-only: $RELEASE_CHECKS
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --verbose) VERBOSE=1 ;;
    --all) TARGETS="$TARGETS $ALL_CHECKS" ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    # An empty name (lint.sh "$UNSET") would otherwise run nothing and pass.
    ''|*[[:space:]]*) echo "Empty or blank check name: '$1'" >&2; usage >&2; exit 1 ;;
    *) TARGETS="$TARGETS $1" ;;
  esac
  shift
done
[ -n "$TARGETS" ] || TARGETS=$ALL_CHECKS

check_function() {
  case "$1" in
    unicode-clean) echo check_unicode_clean ;;
    version-parity|frontmatter-version) echo check_version_parity ;;
    description-length) echo check_description_length ;;
    description-parity) echo check_description_parity ;;
    dir-name-match) echo check_dir_name_match ;;
    references-exist) echo check_references_exist ;;
    modules-complete) echo check_modules_complete ;;
    domain-parity) echo check_domain_parity ;;
    symlinks-valid) echo check_symlinks_valid ;;
    json-valid) echo check_json_valid ;;
    shell-syntax) echo check_shell_syntax ;;
    js-syntax) echo check_js_syntax ;;
    python-syntax) echo check_python_syntax ;;
    eval-cases) echo check_eval_cases ;;
    product-surfaces) echo check_product_surfaces ;;
    action-pins) echo check_action_pins ;;
    official-validator) echo check_official_validator ;;
    tag-release-parity) echo check_tag_release_parity ;;
    prompt-fresh) echo check_prompt_fresh ;;
    context-metrics) echo check_context_metrics ;;
    *) return 1 ;;
  esac
}

# Reject every unknown name before any check runs.
unknown=0
for name in $TARGETS; do
  if ! check_function "$name" >/dev/null; then
    echo "Unknown check: $name" >&2
    unknown=1
  fi
done
if [ "$unknown" = "1" ]; then
  usage >&2
  exit 1
fi

# Scratch space for state that must outlive a check's subshell: one line per
# failure in FAIL_LOG, and the cached authored-file list.
LINT_TMP="$(mktemp -d "${TMPDIR:-/tmp}/godplans-lint.XXXXXX")"
trap 'rm -rf "$LINT_TMP"' EXIT
FAIL_LOG="$LINT_TMP/failures"
: > "$FAIL_LOG"

note() { [ "$VERBOSE" = "1" ] && echo "  $*" || true; }
fail() { echo "FAIL [$CHECK] $*" >&2; CHECK_BAD=1; printf '%s\n' "$CHECK" >> "$FAIL_LOG"; }
skip() { echo "skip [$CHECK] $*"; CHECK_SKIPPED=1; }
pass() {
  if [ "$CHECK_BAD" = "0" ] && [ "$CHECK_SKIPPED" = "0" ]; then
    echo "ok   [$CHECK]"
  fi
}

# in_git_checkout: true when REPO_DIR is the top level of a git work tree (not
# merely a directory inside some other repository, such as an unpacked npm
# tarball under a checkout).
in_git_checkout() {
  command -v git >/dev/null 2>&1 || return 1
  top=$(git -C "$REPO_DIR" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ -n "$top" ] || return 1
  [ "$(cd "$top" && pwd -P)" = "$(cd "$REPO_DIR" && pwd -P)" ]
}

# authored_files: print every authored text file as a repo-relative path, one
# per line. In a git checkout that is every tracked file plus every untracked
# file git does not ignore, so ignored local state (.godplans/, the validator
# venv, editor settings) is never scanned. Without git it falls back to a name
# allowlist. Frozen eval results, symlinks, deleted paths, and binary assets are
# left out. The list is built once per run and cached in LINT_TMP.
authored_files() {
  cache="$LINT_TMP/authored-files"
  if [ ! -f "$cache" ]; then
    raw="$LINT_TMP/authored-files.raw"
    if in_git_checkout; then
      (cd "$REPO_DIR" && git ls-files -z --cached --others --exclude-standard -- . \
        ':(exclude)evals/output' \
        ':(exclude)evals/results' \
        ':(exclude)evals/external/results' \
        ':(exclude)evals/outcomes/results') > "$raw.z"
      tr '\0' '\n' < "$raw.z" > "$raw"
    else
      (cd "$REPO_DIR" && find . \
        \( -path ./.git -o -path ./node_modules -o -path ./.venv-skills-ref \
           -o -path ./.godplans -o -path ./.claude/worktrees \
           -o -path ./.claude/settings.local.json \
           -o -path ./evals/output -o -path ./evals/results \
           -o -path ./evals/external/results -o -path ./evals/outcomes/results \) -prune -o \
        -type f \( -name '*.md' -o -name '*.mdx' -o -name '*.sh' -o -name '*.js' \
           -o -name '*.mjs' -o -name '*.cjs' -o -name '*.json' -o -name '*.yml' \
           -o -name '*.yaml' -o -name '*.py' -o -name '*.txt' -o -name 'EXPECTATIONS' \
           -o -name '.gitignore' -o -name '.gitattributes' -o -name '.editorconfig' \
           -o -name 'CODEOWNERS' -o -name 'LICENSE' \) -print) > "$raw.find"
      sed 's|^\./||' "$raw.find" > "$raw"
    fi
    : > "$cache.tmp"
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      if [ -L "$REPO_DIR/$f" ] || [ ! -f "$REPO_DIR/$f" ]; then
        continue
      fi
      case "$f" in
        *.jpg|*.jpeg|*.png|*.gif|*.webp|*.ico|*.pdf|*.zip|*.gz|*.tgz|*.woff|*.woff2|*.ttf|*.otf) continue ;;
      esac
      printf '%s\n' "$f" >> "$cache.tmp"
    done < "$raw"
    mv "$cache.tmp" "$cache"
  fi
  cat "$cache"
}

# authored_matching ERE: the authored files whose path matches ERE.
authored_matching() {
  authored_files > "$LINT_TMP/authored-all"
  grep -E -e "$1" "$LINT_TMP/authored-all" || true
}

# parity MODE [ARG]: run scripts/lint-parity.js, which reads the SKILL.md
# description and the domain module lists and prints what it finds. A read
# error exits 2 with the reason on stderr.
parity() {
  node "$SCRIPT_DIR/lint-parity.js" "$@"
}

check_unicode_clean() {
  CHECK=unicode-clean
  # perl, not grep -P: BSD grep on stock macOS has no -P and would silently
  # skip the scan. The rule is stricter than the ban list: authored files are
  # pure ASCII, so any byte above 0x7F fails.
  command -v perl >/dev/null 2>&1 || { fail "perl not found; cannot scan"; return 0; }
  files="$LINT_TMP/unicode-files"
  authored_files > "$files"
  if [ ! -s "$files" ]; then
    fail "no authored files found to scan"
    return 0
  fi
  note "$(wc -l < "$files" | tr -d ' ') authored files scanned"
  hits="$LINT_TMP/unicode-hits"
  (cd "$REPO_DIR" && perl -e '
    while (my $f = <STDIN>) {
      chomp $f;
      open(my $fh, "<", $f) or die "cannot read $f: $!\n";
      my $n = 0;
      while (my $line = <$fh>) {
        next unless $line =~ /[^\x00-\x7F]/;
        print "FILE $f\n" if $n == 0;
        $line .= "\n" unless $line =~ /\n\z/;
        print "$.:$line";
        last if ++$n == 5;
      }
      close $fh;
    }' < "$files") > "$hits"
  while IFS= read -r line; do
    case "$line" in
      "FILE "*) fail "non-ASCII character in ${line#FILE }:" ;;
      *) printf '%s\n' "$line" >&2 ;;
    esac
  done < "$hits"
  pass
}

check_version_parity() {
  CHECK=version-parity
  missing=0
  for rel in \
    skills/godplans/SKILL.md \
    CHANGELOG.md \
    package.json \
    .claude-plugin/marketplace.json \
    plugins/godplans/.claude-plugin/plugin.json \
    skills/godplans/templates/PLAN.template.mdx
  do
    if [ ! -f "$REPO_DIR/$rel" ]; then
      fail "missing version surface: $rel"
      missing=1
    fi
  done
  [ "$missing" = "0" ] || return 0
  fm=$(awk -F'"' '/^  version:/ { print $2; exit }' "$SKILL_DIR/SKILL.md")
  ch=$(grep -m1 '^## \[' "$REPO_DIR/CHANGELOG.md" | sed 's/^## \[\([^]]*\)\].*/\1/' || true)
  body=$(grep -m1 '^## Skill version:' "$SKILL_DIR/SKILL.md" | sed 's/^## Skill version: //' || true)
  package=$(awk -F'"' '/"version":/ { print $4; exit }' "$REPO_DIR/package.json")
  marketplace=$(awk -F'"' '/"version":/ { print $4; exit }' "$REPO_DIR/.claude-plugin/marketplace.json")
  plugin=$(awk -F'"' '/"version":/ { print $4; exit }' "$REPO_DIR/plugins/godplans/.claude-plugin/plugin.json")
  template=$(grep -m1 'plan created (godplans v' "$SKILL_DIR/templates/PLAN.template.mdx" | sed 's/.*godplans v\([^)]*\).*/\1/' || true)
  if [ -z "$fm" ]; then
    fail "SKILL.md frontmatter has no metadata version"
    return 0
  fi
  for pair in \
    "CHANGELOG:$ch" \
    "SKILL-body:$body" \
    "package:$package" \
    "marketplace:$marketplace" \
    "plugin:$plugin" \
    "template:$template"
  do
    label=${pair%%:*}
    value=${pair#*:}
    if [ "$fm" != "$value" ]; then
      fail "$label version ($value) != SKILL.md version ($fm)"
    fi
  done
  pass
}

check_description_length() {
  CHECK=description-length
  command -v node >/dev/null 2>&1 || { fail "node not found; cannot parse the SKILL.md frontmatter"; return 0; }
  if ! len=$(parity description-length 2>"$LINT_TMP/description.err"); then
    fail "cannot read the SKILL.md description: $(cat "$LINT_TMP/description.err")"
    return 0
  fi
  if [ "$len" -lt 1 ] || [ "$len" -gt 1024 ]; then
    fail "description is $len characters; Agent Skills spec bound is 1-1024"
  else
    note "description length: $len"
  fi
  pass
}

check_description_parity() {
  CHECK=description-parity
  command -v node >/dev/null 2>&1 || { fail "node not found; cannot compare descriptions"; return 0; }
  out="$LINT_TMP/description-parity"
  if ! parity description-parity > "$out" 2>"$LINT_TMP/description.err"; then
    fail "cannot compare descriptions: $(cat "$LINT_TMP/description.err")"
    return 0
  fi
  while IFS= read -r line; do
    if [ -n "$line" ]; then
      fail "$line"
    fi
  done < "$out"
  pass
}

check_dir_name_match() {
  CHECK=dir-name-match
  fm_name=$(awk '/^name:/ {print $2; exit}' "$SKILL_DIR/SKILL.md")
  dir_name=$(basename "$SKILL_DIR")
  if [ "$fm_name" != "$dir_name" ]; then
    fail "frontmatter name ($fm_name) != directory name ($dir_name)"
  fi
  pass
}

check_references_exist() {
  CHECK=references-exist
  for ref in $(grep -o 'references/[a-z-]*\.md' "$SKILL_DIR/SKILL.md" | sort -u); do
    if [ ! -f "$SKILL_DIR/$ref" ]; then
      fail "SKILL.md names $ref but it does not exist"
    else
      note "$ref exists"
    fi
  done
  pass
}

check_modules_complete() {
  CHECK=modules-complete
  for f in "$SKILL_DIR"/references/*.md; do
    base=$(basename "$f" .md)
    case " $CONTRACT_MODULES " in
      *" $base "*) continue ;;
    esac
    for section in "## Lineage" "## Decisions to force" "## Plan requirements" "## Task seeds" "## Self-audit rubric" "## Anti-patterns refused"; do
      if ! grep -q "^$section" "$f"; then
        fail "$base.md missing section: $section"
      fi
    done
  done
  pass
}

check_domain_parity() {
  CHECK=domain-parity
  command -v node >/dev/null 2>&1 || { fail "node not found; cannot compare the domain lists"; return 0; }
  out="$LINT_TMP/domain-parity"
  if ! parity domain-parity "$CONTRACT_MODULES" > "$out" 2>"$LINT_TMP/domain-parity.err"; then
    fail "cannot compare the domain lists: $(cat "$LINT_TMP/domain-parity.err")"
    return 0
  fi
  while IFS= read -r line; do
    case "$line" in
      "domains "*)
        set -- $line
        note "$2 domain modules compared against $3 lists"
        ;;
      "problem "*) fail "${line#problem }" ;;
    esac
  done < "$out"
  pass
}

check_symlinks_valid() {
  CHECK=symlinks-valid
  for pair in \
    ".agents/skills/godplans:skills/godplans" \
    ".claude/skills/godplans:skills/godplans" \
    "plugins/godplans/skills:skills"
  do
    rel=${pair%%:*}
    target=${pair#*:}
    link="$REPO_DIR/$rel"
    if [ ! -L "$link" ]; then
      if [ -e "$link" ]; then
        fail "$rel is not a symlink to $target (a copy or a checked-out link file drifts from the canonical skill)"
      else
        fail "$rel does not exist; it must be a symlink to $target"
      fi
    elif [ ! -d "$link" ]; then
      fail "$rel does not resolve to a directory; it must be a symlink to $target"
    else
      resolved=$(cd "$link" && pwd -P)
      expected=$(cd "$REPO_DIR/$target" && pwd -P)
      if [ "$resolved" != "$expected" ]; then
        fail "$rel resolves to $resolved, not $target"
      else
        note "$rel -> $target"
      fi
    fi
  done
  pass
}

check_json_valid() {
  CHECK=json-valid
  command -v node >/dev/null 2>&1 || { fail "node not found; cannot parse JSON"; return 0; }
  files="$LINT_TMP/json-files"
  authored_matching '\.json$' > "$files"
  bad="$LINT_TMP/json-bad"
  (cd "$REPO_DIR" && node -e '
    const fs = require("fs");
    const files = fs.readFileSync(0, "utf8").split("\n").filter(Boolean);
    for (const f of files) {
      try {
        JSON.parse(fs.readFileSync(f, "utf8"));
      } catch (error) {
        process.stdout.write(f + "\t" + String(error.message).split("\n")[0] + "\n");
      }
    }' < "$files") > "$bad"
  while IFS="$TAB" read -r f message; do
    fail "invalid JSON: $f ($message)"
  done < "$bad"
  note "$(wc -l < "$files" | tr -d ' ') JSON files parsed"
  pass
}

check_shell_syntax() {
  CHECK=shell-syntax
  files="$LINT_TMP/shell-files"
  authored_matching '\.sh$' > "$files"
  if [ ! -s "$files" ]; then
    fail "no shell scripts found"
    return 0
  fi
  # Bash 4 and later constructs that stock macOS /bin/bash 3.2 cannot run.
  # Some pass bash -n even under 3.2 and fail only when the line runs; all of
  # them pass bash -n under Ubuntu's bash 5. Covered: declare, local, or
  # typeset with -A, -n, -g, -l, or -u; mapfile, readarray, and coproc;
  # case-changing expansions (${x,,}) and transformations (${x@Q}); negative
  # array subscripts (${a[-1]}); &>>, |&, ;&, and ;;&; [[ -v ]] and [[ -R ]];
  # any wait option (wait -n); and shopt with a bash 4 option (globstar,
  # lastpipe, inherit_errexit, and the like). Comment lines are skipped. The
  # brackets keep these patterns from matching their own lines.
  b4='(^|[^[:alnum:]_])(declare|local|typeset)[[:space:]]+-[[:alpha:]]*[Angul]'
  b4="$b4"'|(^|[^[:alnum:]_-])(ma[p]file|read[a]rray|co[p]roc)([^[:alnum:]_-]|$)'
  b4="$b4"'|[$][{]([[:alpha:]_][[:alnum:]_]*([[][^]]*[]])?|[0-9@*])[,^]'
  b4="$b4"'|[$][{][^}]*@[QEPAaKkUuL][}]'
  b4="$b4"'|[$][{][[:alpha:]_][[:alnum:]_]*[[][[:space:]]*-[0-9]'
  b4="$b4"'|[&]>>|;[&]([[:space:]]|$)|(^|[^|])[|][&]([[:space:]]|$)'
  b4="$b4"'|[[][[][[:space:]]+-[vR][[:space:]]'
  b4="$b4"'|(^|[^[:alnum:]_-])wa[i]t[[:space:]]+-[[:alpha:]]'
  b4="$b4"'|sh[o]pt[[:space:]].*(glob[s]tar|last[p]ipe|inherit_[e]rrexit|auto[c]d|check[j]obs|dir[s]pell|dir[e]xpand|globascii[r]anges|localvar_[i]nherit)'
  err="$LINT_TMP/shell-err"
  while IFS= read -r rel; do
    f="$REPO_DIR/$rel"
    shebang=$(sed -n '1p' "$f")
    case "$shebang" in
      '#!/bin/sh'|'#!/bin/sh '*|'#!/usr/bin/env sh'|'#!/usr/bin/env sh '*) shell=sh ;;
      *) shell=$BASH_BIN ;;
    esac
    if ! "$shell" -n "$f" 2>"$err"; then
      fail "$rel does not parse as $(basename "$shell"):"
      sed -n '1,5p' "$err" | sed 's/^/  /' >&2
    fi
    hits=$(grep -n -E -e "$b4" "$f" | grep -v -E '^[0-9]+:[[:space:]]*#' | head -3 || true)
    if [ -n "$hits" ]; then
      fail "$rel uses a bash 4 construct that bash 3.2 cannot run:"
      printf '%s\n' "$hits" | sed 's/^/  /' >&2
    fi
  done < "$files"
  note "$(wc -l < "$files" | tr -d ' ') shell scripts parsed"
  pass
}

check_js_syntax() {
  CHECK=js-syntax
  command -v node >/dev/null 2>&1 || { fail "node not found; cannot check JavaScript syntax"; return 0; }
  files="$LINT_TMP/js-files"
  authored_matching '\.(js|mjs|cjs)$' > "$files"
  err="$LINT_TMP/js-err"
  while IFS= read -r rel; do
    if ! node --check "$REPO_DIR/$rel" 2>"$err"; then
      fail "$rel does not parse:"
      sed -n '1,5p' "$err" | sed 's/^/  /' >&2
    fi
  done < "$files"
  note "$(wc -l < "$files" | tr -d ' ') JavaScript files checked"
  pass
}

check_python_syntax() {
  CHECK=python-syntax
  files="$LINT_TMP/python-files"
  authored_matching '\.py$' > "$files"
  if [ ! -s "$files" ]; then
    pass
    return 0
  fi
  count=$(wc -l < "$files" | tr -d ' ')
  if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import ast' >/dev/null 2>&1; then
    skip "python3 cannot run; $count Python file(s) not parsed"
    return 0
  fi
  err="$LINT_TMP/python-err"
  # ast.parse compiles nothing to disk, unlike py_compile, so no __pycache__
  # lands in the skill directory that install.sh copies.
  while IFS= read -r rel; do
    if ! PYTHONDONTWRITEBYTECODE=1 python3 -c 'import ast, sys; ast.parse(open(sys.argv[1], "rb").read(), sys.argv[1])' "$REPO_DIR/$rel" 2>"$err"; then
      fail "$rel does not parse:"
      tail -n 4 "$err" | sed 's/^/  /' >&2
    fi
  done < "$files"
  note "$count Python files parsed"
  pass
}

check_eval_cases() {
  CHECK=eval-cases
  if ! "$BASH_BIN" "$REPO_DIR/scripts/eval.sh" --check-cases >/dev/null; then
    fail "behavioral case contract failed"
  fi
  pass
}

check_product_surfaces() {
  CHECK=product-surfaces
  for f in \
    "$SKILL_DIR/scripts/validate-plan.sh" \
    "$SKILL_DIR/scripts/plan-halflife.sh" \
    "$REPO_DIR/scripts/eval.sh" \
    "$REPO_DIR/scripts/eval-matrix.sh" \
    "$REPO_DIR/scripts/eval-external.js" \
    "$REPO_DIR/scripts/eval-outcome.js" \
    "$REPO_DIR/scripts/outcome-summary.js" \
    "$REPO_DIR/scripts/release-check.sh" \
    "$REPO_DIR/evals/runners/codex.sh" \
    "$REPO_DIR/tests/run.sh"
  do
    if [ ! -x "$f" ]; then
      fail "missing executable: ${f#$REPO_DIR/}"
    fi
  done
  pass
}

check_context_metrics() {
  CHECK=context-metrics
  if ! node "$REPO_DIR/scripts/context-metrics.js" --check >/dev/null; then
    fail "evals/metrics/context-cost.json is stale"
  fi
  pass
}

check_action_pins() {
  CHECK=action-pins
  for workflow in "$REPO_DIR"/.github/workflows/*.yml "$REPO_DIR"/.github/workflows/*.yaml; do
    [ -f "$workflow" ] || continue
    while IFS= read -r line; do
      # Accept `uses:` on its own line and the `- uses:` list-item form, and
      # drop the quotes YAML allows around the reference.
      ref=$(printf '%s\n' "$line" | sed -n 's/^[[:space:]]*-\{0,1\}[[:space:]]*uses:[[:space:]]*\([^#[:space:]]*\).*/\1/p' | tr -d '\042\047')
      [ -n "$ref" ] || continue
      case "$ref" in
        ./*) continue ;;
      esac
      if ! printf '%s\n' "$ref" | grep -Eq '@[0-9a-f]{40}$'; then
        fail "floating GitHub Action reference in ${workflow#$REPO_DIR/}: $ref"
      fi
    done < "$workflow"
  done
  pass
}

check_official_validator() {
  CHECK=official-validator
  explicit=0
  if [ -n "${SKILLS_REF_BIN:-}" ]; then
    validator=$SKILLS_REF_BIN
    explicit=1
  elif [ -x "$REPO_DIR/.venv-skills-ref/bin/skills-ref" ]; then
    validator="$REPO_DIR/.venv-skills-ref/bin/skills-ref"
  elif command -v skills-ref >/dev/null 2>&1; then
    validator=$(command -v skills-ref)
  else
    skip "skills-ref not installed; scripts/release-check.sh requires it"
    return 0
  fi
  # A validator that cannot start (a stale pipx shim whose interpreter was
  # deleted, a wrong path) is not a validator that rejected the skill.
  rc=0
  "$validator" --version >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "0" ]; then
    out="$LINT_TMP/skills-ref.out"
    "$validator" validate "$SKILL_DIR" > "$out" 2>&1 || rc=$?
    if [ "$rc" = "0" ]; then
      note "skills-ref accepted skills/godplans ($validator)"
      pass
      return 0
    fi
    if [ "$rc" != "126" ] && [ "$rc" != "127" ]; then
      fail "official skills-ref validator rejected skills/godplans (exit $rc):"
      sed -n '1,20p' "$out" | sed 's/^/  /' >&2
      return 0
    fi
  fi
  if [ "$explicit" = "1" ]; then
    case "$validator" in
      */*) [ -x "$validator" ] || { fail "SKILLS_REF_BIN=$validator is not an executable file"; return 0; } ;;
    esac
    fail "could not execute $validator (exit $rc); fix SKILLS_REF_BIN"
  else
    skip "$validator is installed but cannot run (exit $rc); reinstall it or set SKILLS_REF_BIN"
  fi
  return 0
}

check_tag_release_parity() {
  CHECK=tag-release-parity
  if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
    skip "authenticated gh CLI unavailable; scripts/release-check.sh requires it"
    return 0
  fi
  # A clone made with --no-tags or --depth has nothing to compare, and an empty
  # loop must not read as parity.
  if [ "$(git -C "$REPO_DIR" rev-parse --is-shallow-repository 2>/dev/null)" = "true" ] ||
      [ -z "$(git -C "$REPO_DIR" tag --list 'v*')" ]; then
    fail "no v* tags in a full-history checkout; run git fetch --tags --unshallow (or git fetch --tags) first"
    return 0
  fi
  for tag in $(git -C "$REPO_DIR" tag --list 'v*' --sort=version:refname); do
    version=${tag#v}
    tagged_version=$(git -C "$REPO_DIR" show "$tag:package.json" 2>/dev/null | awk -F'"' '/"version":/ { print $4; exit }' || true)
    if [ "$tagged_version" != "$version" ]; then
      fail "$tag package version ($tagged_version) does not match $version"
    fi
    release_record=$(gh release view "$tag" --repo hannsxpeter/godplans --json tagName,isDraft --jq '[.tagName, (.isDraft | tostring)] | @tsv' 2>/dev/null || true)
    expected_record=$(printf '%s\tfalse' "$tag")
    if [ "$release_record" != "$expected_record" ]; then
      fail "$tag has no matching published GitHub release"
    fi
  done
  pass
}

check_prompt_fresh() {
  CHECK=prompt-fresh
  if [ ! -f "$REPO_DIR/PROMPT.md" ]; then
    fail "PROMPT.md missing; run scripts/build-prompt.sh"
    return 0
  fi
  generated="$LINT_TMP/PROMPT.generated"
  err="$LINT_TMP/prompt-err"
  if ! GODPLANS_PROMPT_OUT="$generated" "$BASH_BIN" "$SCRIPT_DIR/build-prompt.sh" >/dev/null 2>"$err"; then
    fail "scripts/build-prompt.sh failed, so PROMPT.md freshness is unknown:"
    sed -n '1,10p' "$err" | sed 's/^/  /' >&2
    return 0
  fi
  if ! cmp -s "$generated" "$REPO_DIR/PROMPT.md"; then
    fail "PROMPT.md is stale; run scripts/build-prompt.sh and commit the diff"
  fi
  pass
}

# Each check runs in a subshell with errexit on, so a command that crashes
# inside it (an awk error, an unset variable) stops that check and is counted
# instead of being ignored. The subshell must not sit in an if, ||, &&, or !
# list: bash turns errexit off inside those, which would hide the crash. fail()
# appends to FAIL_LOG, so the failure survives the subshell.
for name in $TARGETS; do
  fn=$(check_function "$name")
  set +e
  ( set -e; CHECK=$name; CHECK_BAD=0; CHECK_SKIPPED=0; "$fn" )
  rc=$?
  set -e
  if [ "$rc" -ne 0 ]; then
    CHECK=$name
    fail "the check stopped early (exit $rc); a command inside it failed, see the error above"
  fi
done

if [ -s "$FAIL_LOG" ]; then
  failed=$(awk '!seen[$0]++' "$FAIL_LOG" | tr '\n' ' ' | sed 's/ $//')
  echo "FAIL [lint] failing checks: $failed" >&2
  exit 1
fi
exit 0
