#!/usr/bin/env bash
# tests/agent-memory-guidance.sh: guard the agent-memory module against wording
# that reverses its always-load rules. Context and repo are a mandatory floor
# inside one always-loaded scope total; other always-loaded pillars are allowed
# when justified, so the module must never limit always-load to the floor.
#
# Reads the canonical module in place and writes nothing.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$ROOT/skills/godplans/references/agent-memory.md"

fail() {
  echo "FAIL [agent-memory-guidance] $*" >&2
  exit 1
}

[ -f "$MODULE" ] || fail "missing ${MODULE#"$ROOT"/}"

if grep -Fq 'only for context and repo' "$MODULE"; then
  fail "agent-memory guidance forbids justified additional always-loaded pillars"
fi
if grep -Fq 'scope floor total' "$MODULE"; then
  fail "agent-memory guidance uses the contradictory scope floor total name"
fi
grep -Fq 'agents/context.md and agents/repo.md at status: present with always_load: true' "$MODULE" ||
  fail "agent-memory guidance lost the mandatory context and repo floor"
grep -Fq 'always-loaded scope total' "$MODULE" ||
  fail "agent-memory guidance lost the total always-load budget"

echo "ok   [agent-memory-guidance]"
