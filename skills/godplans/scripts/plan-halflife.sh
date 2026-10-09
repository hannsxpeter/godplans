#!/usr/bin/env bash

# Emit cumulative task-survival metrics from a validated PLAN.mdx.
# Bash 3.2, Perl, and a copy of validate-plan.sh are sufficient.

set -eu

usage() {
  echo "Usage: $0 [PLAN.mdx] [OUTPUT.json]" >&2
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    -*) usage; echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if [ "$#" -gt 2 ]; then
  usage
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLAN_FILE="${1:-.godplans/PLAN.mdx}"
OUTPUT_FILE="${2:-${PLAN_FILE%.mdx}.metrics.json}"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/godplans-halflife.XXXXXX")"
SIDE_CAR="$TMP_DIR/PLAN.json"

trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

# Measure with the plan's own validator: override, then companion, then sibling.
VALIDATOR="${GODPLANS_VALIDATOR:-}"
if [ -z "$VALIDATOR" ]; then
  VALIDATOR="$(dirname "$PLAN_FILE")/validate-plan.sh"
  [ -f "$VALIDATOR" ] || VALIDATOR="$SCRIPT_DIR/validate-plan.sh"
fi

[ -f "$VALIDATOR" ] || {
  echo "FAIL $PLAN_FILE: validator $VALIDATOR is missing" >&2
  exit 1
}

bash "$VALIDATOR" --allow-planning --emit-json "$SIDE_CAR" "$PLAN_FILE" >/dev/null || {
  echo "FAIL $PLAN_FILE: $VALIDATOR rejects it; set GODPLANS_VALIDATOR to the validator it was written against" >&2
  exit 1
}

perl -MJSON::PP - "$SIDE_CAR" "$OUTPUT_FILE" <<'PERL'
use strict;
use warnings;

my ($sidecar, $output) = @ARGV;
open my $input_fh, '<:raw', $sidecar
    or die "FAIL $sidecar: cannot read: $!\n";
local $/;
my $document = JSON::PP->new->decode(<$input_fh>);
close $input_fh;

my $result = {
    format => 'godplans/plan-half-life@1',
    plan_digest => $document->{plan_digest},
    plan_version => $document->{plan_version},
    metrics => $document->{metrics},
};

my $json = JSON::PP->new->canonical(1)->pretty->encode($result);
my $tmp = "$output.tmp.$$";
open my $output_fh, '>:raw', $tmp
    or die "FAIL $tmp: cannot write: $!\n";
print {$output_fh} $json;
close $output_fh;
rename $tmp, $output
    or die "FAIL $output: cannot replace atomically: $!\n";
PERL

echo "ok   $OUTPUT_FILE"
