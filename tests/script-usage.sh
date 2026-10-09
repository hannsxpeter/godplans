#!/usr/bin/env bash
# Maintainer scripts answer --help with their usage and exit 0, and refuse an
# unknown argument with exit 2, before they read or write anything. Without
# this, --help reached npm version as a bump, rebuilt PROMPT.md, or created a
# directory named --help.

set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
failures=0

fail() {
  echo "FAIL [script-usage] $*" >&2
  failures=$((failures + 1))
}

for script in version-sync.js context-metrics.js build-catalog.js release-prepare.js summarize-eval.js summarize-matrix.js; do
  out=$(cd "$TMP" && node "$ROOT/scripts/$script" --help 2>&1)
  status=$?
  [ "$status" -eq 0 ] || fail "$script --help exited $status"
  case "$out" in
    Usage:*) ;;
    *) fail "$script --help printed no usage: $out" ;;
  esac

  (cd "$TMP" && node "$ROOT/scripts/$script" --bogus >/dev/null 2>&1)
  status=$?
  [ "$status" -eq 2 ] || fail "$script --bogus exited $status, expected 2"
done

[ -z "$(ls -A "$TMP")" ] || fail "a usage path wrote files: $(ls -A "$TMP" | tr '\n' ' ')"
[ ! -e "$ROOT/--help" ] || fail "a usage path created $ROOT/--help"

[ "$failures" -eq 0 ] || exit 1
echo "ok   [script-usage]"
