#!/usr/bin/env bash

# Regression cases for skills/godplans/scripts/style-stats.py, the measurement
# behind the R-DNA-5 function-size norm and the R-DNA-20 frequencies.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATS="$ROOT_DIR/skills/godplans/scripts/style-stats.py"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/godplans-style-stats.XXXXXX")"
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

fail() {
  echo "FAIL [style-stats] $*" >&2
  exit 1
}

command -v python3 >/dev/null 2>&1 || fail "python3 not found"

# -B keeps the run from writing __pycache__ beside the vendored script.
stats() {
  python3 -B "$STATS" "$1" --json
}

field() {
  python3 -B -c '
import json, sys
results = {entry["language"]: entry for entry in json.load(open(sys.argv[1]))}
value = results[sys.argv[2]]
for key in sys.argv[3].split("."):
    value = value.get(key) if isinstance(value, dict) else None
print(json.dumps(value, sort_keys=True))
' "$1" "$2" "$3"
}

expect() {
  actual=$(field "$1" "$2" "$3")
  [ "$actual" = "$4" ] || fail "$5: $2 $3 is $actual, expected $4"
}

# Bodyless declarations are not functions: a .d.ts file is skipped and a
# signature ending in `;` never runs into the next brace block.
mkdir "$TMP_DIR/ts"
cat > "$TMP_DIR/ts/types.d.ts" <<'EOF'
export declare function parse(input: string): number;
export declare function format(n: number): string;
export interface Options {
  strict: boolean;
  radix: number;
  locale: string;
}
EOF
cat > "$TMP_DIR/ts/impl.ts" <<'EOF'
export function parse(input: string): number;
export function parse(input: string | number): number {
  return Number(input);
}
EOF
stats "$TMP_DIR/ts" > "$TMP_DIR/ts.json"
expect "$TMP_DIR/ts.json" ts function_lengths '{"count": 1, "median": 3, "p90": 3}' "declarations inflate function lengths"

mkdir "$TMP_DIR/rs"
cat > "$TMP_DIR/rs/shape.rs" <<'EOF'
trait Shape {
    fn area(&self) -> f64;
    fn name(&self) -> String;
}

impl Shape for Square {
    fn area(&self) -> f64 {
        self.side * self.side
    }
    fn name(&self) -> String {
        String::from("square")
    }
}
EOF
stats "$TMP_DIR/rs" > "$TMP_DIR/rs.json"
expect "$TMP_DIR/rs.json" rs function_lengths '{"count": 2, "median": 3.0, "p90": 3}' "trait items inflate function lengths"

# One identifier counts once, under the first kind that claims it, and the
# boolean-prefix share is over distinct names.
mkdir "$TMP_DIR/js"
cat > "$TMP_DIR/js/app.js" <<'EOF'
const isReady = () => true;
function loadThing(a) {
  return a;
}
EOF
stats "$TMP_DIR/js" > "$TMP_DIR/js.json"
expect "$TMP_DIR/js.json" js naming.function '{"camelCase": 2}' "an arrow function counted twice"
expect "$TMP_DIR/js.json" js naming.variable 'null' "an arrow function counted as a variable"
expect "$TMP_DIR/js.json" js boolean_prefix_share '{"count": 2, "percent": 50.0, "prefixed": 1}' "boolean share over duplicate names"

# A comparison that starts a line is not an assignment.
mkdir "$TMP_DIR/py"
cat > "$TMP_DIR/py/check.py" <<'EOF'
def check(value):
    if (
        value == 2
    ):
        return True
    return False
EOF
stats "$TMP_DIR/py" > "$TMP_DIR/py.json"
expect "$TMP_DIR/py.json" py naming.variable 'null' "a comparison counted as a variable"

echo "ok   [style-stats]"
