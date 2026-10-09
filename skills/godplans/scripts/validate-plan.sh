#!/usr/bin/env bash

# Portable structural validator for emitted PLAN.mdx files.
# Bash 3.2 and the Perl shipped with macOS are sufficient.

set -eu

ALLOW_PLANNING=0
PLAN_FILE=""
EMIT_JSON=""
DRIFT_PHASE=""

usage() {
  echo "Usage: $0 [--allow-planning] [--emit-json PATH] [--drift-check PHASE] [PLAN.mdx]" >&2
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --allow-planning)
      ALLOW_PLANNING=1
      ;;
    --emit-json)
      shift
      if [ "$#" -eq 0 ]; then
        usage
        echo "--emit-json needs an output path" >&2
        exit 2
      fi
      EMIT_JSON=$1
      ;;
    --drift-check)
      shift
      if [ "$#" -eq 0 ]; then
        usage
        echo "--drift-check needs a phase number" >&2
        exit 2
      fi
      DRIFT_PHASE=$1
      case "$DRIFT_PHASE" in
        ''|*[!0-9]*|0)
          usage
          echo "--drift-check phase must be a positive integer" >&2
          exit 2
          ;;
      esac
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      usage
      echo "Unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$PLAN_FILE" ]; then
        usage
        echo "Only one PLAN.mdx path may be supplied" >&2
        exit 2
      fi
      PLAN_FILE=$1
      ;;
  esac
  shift
done

[ -n "$PLAN_FILE" ] || PLAN_FILE=".godplans/PLAN.mdx"

if [ ! -f "$PLAN_FILE" ]; then
  echo "FAIL $PLAN_FILE: file not found" >&2
  exit 1
fi

if ! command -v perl >/dev/null 2>&1; then
  echo "FAIL $PLAN_FILE: perl not found; validation cannot fail open" >&2
  exit 1
fi

exec perl -CSD - "$PLAN_FILE" "$ALLOW_PLANNING" "$EMIT_JSON" "$DRIFT_PHASE" <<'PERL'
use strict;
use warnings;
use Digest::SHA qw(sha256_hex);
use Encode ();
use JSON::PP ();
use Time::Local qw(timegm);

my ($plan_file, $allow_planning, $emit_json, $drift_phase) = @ARGV;
my @errors;
my %inventory;
my %recheck_inventory;
my %domain_disposition;
my %domain_reason;
my @json_decisions;

sub fail {
    push @errors, $_[0];
}

sub trim {
    my ($value) = @_;
    $value = '' unless defined $value;
    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

# YAML allows one layer of quotes or a trailing comment; neither is the value.
sub yaml_value {
    my $value = trim($_[0]);
    $value =~ s/(?:^|\s+)#.*$// unless $value =~ s/^(["'])(.*)\1(?:\s+#.*)?$/$2/;
    return $value;
}

# One command in backticks with something to run; a manual step cannot be rerun.
sub not_command {
    return $_[0] !~ /^`[^`]*\S[^`]*`$/ || $_[0] =~ /^`\s*manual:/i;
}

sub task_has_requirement {
    my ($task, $requirement_id) = @_;
    return 0 unless exists $task->{fields}{Requirements};
    return 0 unless @{$task->{fields}{Requirements}} == 1;
    my @requirement_ids = split /\s*,\s*/, $task->{fields}{Requirements}[0], -1;
    return scalar grep { $_ eq $requirement_id } @requirement_ids;
}

sub dependency_ids {
    my $depends = $_[0]{fields}{'Depends on'};
    return () unless $depends && @$depends == 1 && $depends->[0] ne 'none';
    return split /\s*,\s*/, $depends->[0], -1;
}

sub task_depends_on {
    return scalar grep { $_ eq $_[1] } dependency_ids($_[0]);
}

open my $plan_fh, '<:raw', $plan_file
    or die "FAIL $plan_file: cannot read: $!\n";
my $plan_bytes = do { local $/; <$plan_fh> };
close $plan_fh;
# Decode strictly: a lenient read carries substituted text into the sidecar.
my $plan_text = eval { Encode::decode('UTF-8', $plan_bytes, Encode::FB_CROAK() | Encode::LEAVE_SRC()) };
if (!defined $plan_text) {
    fail('plan is not valid UTF-8');
    $plan_text = Encode::decode('UTF-8', $plan_bytes);
}
fail('plan starts with a UTF-8 byte order mark; save it without one')
    if $plan_text =~ s/^\x{FEFF}//;
my @lines = split /\n/, $plan_text;
# Markdown ignores trailing whitespace, so headings and labels do too.
s/[ \t\r]+$// for @lines;

for my $index (0 .. $#lines) {
    fail('banned Unicode on line ' . ($index + 1))
        if $lines[$index] =~ /[\x{200D}\x{2013}\x{2014}\x{2018}-\x{201F}\x{2026}\x{20E3}\x{2190}-\x{21FF}\x{231A}-\x{231B}\x{2328}\x{23CF}\x{23E9}-\x{23F3}\x{23F8}-\x{23FA}\x{2500}-\x{259F}\x{2600}-\x{27BF}\x{27F0}-\x{27FF}\x{2900}-\x{297F}\x{2B00}-\x{2BFF}\x{FE0F}\x{1F000}-\x{1FBFF}\x{E0020}-\x{E007F}]/;
}

my $frontmatter_end = -1;
if (!@lines || $lines[0] ne '---') {
    fail('frontmatter must begin on line 1 with ---');
} else {
    for my $index (1 .. $#lines) {
        if ($lines[$index] eq '---') {
            $frontmatter_end = $index;
            last;
        }
    }
    fail('frontmatter is missing its closing ---') if $frontmatter_end < 0;
}

# Fenced examples are quoted text: blank them for structural scans only.
my @raw_lines = @lines;
my ($fence, $fence_line) = ('', 0);
for my $index ($frontmatter_end + 1 .. $#lines) {
    my ($run) = $lines[$index] =~ /^\s*(`{3,}|~{3,})/;
    if ($fence eq '') {
        next unless defined $run;
        ($fence, $fence_line) = ($run, $index + 1);
    } elsif (defined $run && index($run, $fence) == 0 && $lines[$index] =~ /^\s*[`~]+\s*$/) {
        $fence = '';
    }
    $lines[$index] = '';
}
if ($fence ne '') {
    fail("code fence opened on line $fence_line is never closed");
    @lines[$fence_line .. $#lines] = @raw_lines[$fence_line .. $#lines];
}

# Line indexes under every $heading, up to the next heading of its level or above.
sub section {
    my ($heading) = @_;
    my $level = length(($heading =~ /^(#+)/)[0]);
    my ($inside, @body);
    for my $index (0 .. $#lines) {
        if ($lines[$index] =~ /^#{1,$level} /) {
            $inside = $lines[$index] eq $heading;
            next;
        }
        push @body, $index if $inside;
    }
    return @body;
}

# A skeleton section occurs exactly once; returns how often ## $_[0] does.
sub section_count {
    my $count = grep { $_ eq "## $_[0]" } @lines;
    fail("expected exactly one ## $_[0] section, found $count") if $count != 1;
    return $count;
}

my %frontmatter;
my %counter;
my %top_key_count;
my $has_progress = 0;
if ($frontmatter_end > 0) {
    for my $index (1 .. $frontmatter_end - 1) {
        my $line = $lines[$index];
        if ($line =~ /^([a-z_]+):(?:[ \t]*(.*))?$/) {
            my ($key, $value) = ($1, yaml_value($2));
            $top_key_count{$key}++;
            $frontmatter{$key} = $value;
            $has_progress = 1 if $key eq 'progress';
        } elsif ($line =~ /^  (phases_total|phases_done|tasks_total|tasks_done):[ \t]*(.*)$/) {
            my ($key, $value) = ($1, yaml_value($2));
            fail("duplicate progress counter: $key") if exists $counter{$key};
            $counter{$key} = $value;
        }
    }
}

for my $key (qw(name plan_version status created updated mode product_form archetype archetype_confidence overlays public_release source_revision input_digest validated_at domains_applicable domains_deferred domains_excluded)) {
    if (!exists $frontmatter{$key}) {
        fail("missing frontmatter field: $key");
    } elsif ($frontmatter{$key} eq '') {
        fail("frontmatter field is empty: $key");
    }
    fail("duplicate frontmatter field: $key")
        if ($top_key_count{$key} || 0) > 1;
}
fail('missing frontmatter field: progress') unless $has_progress;
fail('duplicate frontmatter field: progress')
    if ($top_key_count{progress} || 0) > 1;

if (exists $frontmatter{plan_version}
        && $frontmatter{plan_version} !~ /^[1-9][0-9]*$/) {
    fail("plan_version must be a positive integer, found '$frontmatter{plan_version}'");
}

my %allowed_status = map { $_ => 1 } qw(planning approved executing done);
if (exists $frontmatter{status} && !$allowed_status{$frontmatter{status}}) {
    fail("invalid status '$frontmatter{status}'; expected planning, approved, executing, or done");
} elsif (!$allow_planning
        && exists $frontmatter{status}
        && $frontmatter{status} ne 'approved'
        && $frontmatter{status} ne 'executing') {
    fail("execution requires status approved or executing, found '$frontmatter{status}'");
}

my %allowed_mode = map { $_ => 1 } qw(greenfield brownfield replan);
if (exists $frontmatter{mode} && !$allowed_mode{$frontmatter{mode}}) {
    fail("invalid mode '$frontmatter{mode}'; expected greenfield, brownfield, or replan");
}

my %allowed_product_form = map { $_ => 1 } qw(web-application api-or-service cli-or-sdk mobile-or-desktop data-or-ml infrastructure-or-iac);
if (exists $frontmatter{product_form} && !$allowed_product_form{$frontmatter{product_form}}) {
    fail("invalid product_form '$frontmatter{product_form}'; expected web-application, api-or-service, cli-or-sdk, mobile-or-desktop, data-or-ml, or infrastructure-or-iac");
}

# The nine archetypes discovery.md scores; a merged hybrid is not one of them.
my @archetypes = qw(cli-tool library api-service saas-dashboard marketing-site mobile-app ml-pipeline extension game);
my %allowed_archetype = map { $_ => 1 } @archetypes;
fail("invalid archetype '$frontmatter{archetype}'; expected unknown or one of " . join(', ', @archetypes))
    if ($frontmatter{archetype} || 'unknown') ne 'unknown' && !$allowed_archetype{$frontmatter{archetype}};

my %allowed_confidence = map { $_ => 1 } qw(high medium low);
if (exists $frontmatter{archetype_confidence}
        && !$allowed_confidence{$frontmatter{archetype_confidence}}) {
    fail("invalid archetype_confidence '$frontmatter{archetype_confidence}'; expected high, medium, or low");
}

# An overlay answers what extra obligations a project carries, never what it is.
# Overlays are additive: each one forbids excluding the domains it covers, so a
# list written to add obligations can never be read as a licence to trim.
my %overlay_domains = (
    'ai-system'           => ['llm'],
    'public-ui'           => ['ui', 'seo'],
    'shipped-artifact'    => ['deploy'],
    'operated-by-others'  => ['observe', 'deploy'],
    'regulated-data'      => ['database'],
    'agent-skill-package' => ['agent-memory'],
    'monetized'           => ['business'],
);
my @overlays;
my %overlay_declared;
if (exists $frontmatter{overlays}) {
    my $raw = trim($frontmatter{overlays});
    if ($raw !~ /^\[(.*)\]$/) {
        fail('frontmatter overlays must be a single inline list such as [ai-system] or []');
    } else {
        for my $overlay (split /\s*,\s*/, $1, -1) {
            $overlay = trim($overlay);
            next if $overlay eq '';
            if (!exists $overlay_domains{$overlay}) {
                fail("frontmatter overlays names unknown overlay $overlay; expected ai-system, public-ui, shipped-artifact, operated-by-others, regulated-data, agent-skill-package, or monetized");
                next;
            }
            fail("frontmatter overlays lists $overlay twice") if $overlay_declared{$overlay}++;
            push @overlays, $overlay;
        }
        @overlays = sort @overlays;
    }
}
my %overlay_protected;
for my $overlay (@overlays) {
    $overlay_protected{$_} = $overlay for @{$overlay_domains{$overlay}};
}

if (exists $frontmatter{public_release}
        && $frontmatter{public_release} ne 'true'
        && $frontmatter{public_release} ne 'false') {
    fail('public_release must be true or false');
}

if (exists $frontmatter{source_revision}
        && $frontmatter{source_revision} ne 'none'
        && $frontmatter{source_revision} !~ /^[0-9a-f]{40,64}$/) {
    fail('source_revision must be none or a full lowercase hexadecimal revision');
}

if (exists $frontmatter{input_digest}
        && $frontmatter{input_digest} !~ /^sha256:[0-9a-f]{64}$/) {
    fail('input_digest must be sha256 followed by 64 lowercase hexadecimal characters');
} elsif (exists $frontmatter{input_digest}
        && $frontmatter{input_digest} eq 'sha256:' . ('0' x 64)) {
    fail('input_digest must not use the all-zero placeholder');
}

if (exists $frontmatter{validated_at}
        && $frontmatter{validated_at} !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$/) {
    fail('validated_at must use UTC ISO-8601 form YYYY-MM-DDTHH:MM:SSZ');
}

for my $key (qw(created updated)) {
    if (exists $frontmatter{$key}
            && $frontmatter{$key} !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}$/) {
        fail("$key must use YYYY-MM-DD, found '$frontmatter{$key}'");
    }
}

# Well-formed is not enough: the sidecar promises a date on the calendar.
for my $key (qw(created updated validated_at)) {
    my ($y, $m, $d, $h, $min, $s) = ($frontmatter{$key} || '')
        =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})(?:T([0-9]{2}):([0-9]{2}):([0-9]{2})Z)?$/;
    fail("$key $frontmatter{$key} is not a real calendar date and time")
        if defined $y && !eval { timegm($s || 0, $min || 0, $h || 0, $d, $m - 1, $y); 1 };
}

for my $key (qw(phases_total phases_done tasks_total tasks_done)) {
    if (!exists $counter{$key}) {
        fail("missing progress counter: $key");
    } elsif ($counter{$key} !~ /^[0-9]+$/) {
        fail("progress counter $key must be a non-negative integer, found '$counter{$key}'");
    }
}

my %local_requirements;
for my $index (section('## Requirements')) {
    $local_requirements{$1} = 1
        if $lines[$index] =~ /^(R-[0-9]+\.[0-9]+):/ || $lines[$index] =~ /^\|\s*(R-[0-9]+\.[0-9]+)\s*\|/;
}

my %catalog_max = (
    ARCH => 24,
    BIZ => 26,
    BUILD => 20,
    CODE => 24,
    DB => 23,
    DEPLOY => 18,
    DNA => 24,
    LAUNCH => 22,
    LLM => 23,
    MEM => 22,
    OBS => 22,
    PRD => 17,
    REPO => 25,
    ROAD => 21,
    SEC => 30,
    SEO => 22,
    STACK => 21,
    UI => 21,
    UX => 20,
);
my %catalog_requirements;
for my $prefix (keys %catalog_max) {
    for my $number (1 .. $catalog_max{$prefix}) {
        $catalog_requirements{"R-$prefix-$number"} = 1;
    }
}

# Generated from references/doc-set.md by scripts/build-catalog.js. Values are
# '<owner module>|<durability>'. The id prefix is the lifecycle stage.
my %doc_catalog = (
    'assure.accessibility-inputs' => 'ui|evidence',
    'assure.dependency-inventory' => 'repo|evidence',
    'assure.privacy-record' => 'security|durable',
    'assure.scanning-index' => 'repo|evidence',
    'assure.threat-model' => 'security|durable',
    'build.agent-memory' => 'agent-memory|durable',
    'build.api-reference' => 'architecture|durable',
    'build.codebase-map' => 'agent-memory|durable',
    'build.config-reference' => 'stack|durable',
    'build.contributing' => 'repo|durable',
    'build.dev-setup' => 'repo|durable',
    'build.feature-flags' => 'deploy|durable',
    'build.llms-txt' => 'seo|durable',
    'build.readme' => 'repo|durable',
    'build.style-genome' => 'style-genome|durable',
    'decide.adr' => 'architecture|durable',
    'decide.design-proposal' => 'architecture|transient',
    'design.api-contract' => 'architecture|durable',
    'design.capacity-model' => 'architecture|durable',
    'design.data-model' => 'database|durable',
    'design.integration-map' => 'architecture|durable',
    'design.metrics-register' => 'business|durable',
    'design.ui-spec' => 'ui|durable',
    'frame.business-case' => 'business|durable',
    'frame.glossary' => 'style-genome|durable',
    'frame.objective' => 'product|durable',
    'frame.stakeholders' => 'repo|durable',
    'govern.changelog' => 'repo|durable',
    'govern.closeout' => 'roadmap|durable',
    'govern.manifest' => 'repo|durable',
    'govern.ownership' => 'repo|durable',
    'govern.security-policy' => 'repo|durable',
    'operate.oncall' => 'observe|durable',
    'operate.postmortem' => 'observe|evidence',
    'operate.readiness-review' => 'deploy|evidence',
    'operate.recovery' => 'deploy|durable',
    'operate.runbook' => 'observe|durable',
    'operate.slo' => 'observe|durable',
    'retire.archive-manifest' => 'roadmap|evidence',
    'retire.deprecation-notice' => 'business|evidence',
    'serve.release-notes' => 'business|durable',
    'serve.support-policy' => 'launch|durable',
    'serve.user-guide' => 'launch|durable',
    'verify.dod' => 'product|durable',
    'verify.test-strategy' => 'code-quality|durable',
    'verify.traceability' => 'roadmap|durable',
);

# Field lines; a 4-space line that is not a list item continues the field above.
sub task_fields {
    my ($start, $names) = @_;
    my (%fields, $last);
    for my $index ($start .. $#lines) {
        my $line = $lines[$index];
        last if $line =~ /^(?:~~\s*-?|-)\s*\[[^]]*\]\s*GP-/ || $line =~ /^## Phase [1-9][0-9]*:/;
        if ($line =~ /^  - ($names):[ \t]*(.*)$/) {
            push @{$fields{$1}}, trim($2);
            $last = $1;
        } elsif (defined $last && $line =~ /^ {4,}(?![-*+] )\S/) {
            $fields{$last}[-1] = trim($fields{$last}[-1] . ' ' . trim($line));
        } else {
            undef $last;
        }
    }
    return \%fields;
}

my @phases;
my @tasks;
my @superseded_tasks;
my %task_definitions;
my %all_task_definitions;
my $current_phase = -1;
for (my $index = 0; $index <= $#lines; $index++) {
    my $line = $lines[$index];
    if ($line =~ /^## Phase ([1-9][0-9]*):\s*(.+?)\s*$/) {
        push @phases, {
            number => $1,
            name => $2,
            tasks => [],
            line => $index + 1,
            wave => 0,
        };
        $current_phase = $#phases;
        next;
    }

    if ($line =~ /^- \[([ x])\] (GP-[1-9][0-9]{2,})\b/) {
        my ($box, $id) = ($1, $2);
        my ($wave_phase, $wave, $wave_tag, $parallel);
        if ($line =~ /^- \[[ x]\] \Q$id\E (\[P\] )?\[W([1-9][0-9]*)\.([1-9][0-9]*)\] \S/) {
            ($parallel, $wave_phase, $wave) = (defined $1 ? 1 : 0, $2, $3);
            $wave_tag = "W$2.$3";
        } else {
            fail("$id has malformed task heading");
        }
        my $task = {
            id => $id,
            done => $box eq 'x' ? 1 : 0,
            fields => task_fields($index + 1, 'Files|Depends on|Reuses|Acceptance|Verify|Requirements'),
            line => $index + 1,
            phase => $current_phase,
            wave => $wave_tag,
            parallel => $parallel ? 1 : 0,
        };
        push @tasks, $task;
        push @{$phases[$current_phase]{tasks}}, $#tasks if $current_phase >= 0;
        fail("$id is not inside a numbered phase") if $current_phase < 0;
        if (defined $wave_phase && $current_phase >= 0) {
            my $phase = $phases[$current_phase];
            fail("$id wave phase $wave_phase does not match Phase $phase->{number}")
                if $wave_phase != $phase->{number};
            # Executors take waves in order, so a lower wave written later runs late.
            fail("$id [$wave_tag] follows a W$phase->{number}.$phase->{wave} task; waves within a phase must not go backwards")
                if $wave < $phase->{wave};
            $phase->{wave} = $wave if $wave > $phase->{wave};
        }
        if (exists $task_definitions{$id}) {
            fail("duplicate task definition ID $id on lines $task_definitions{$id} and " . ($index + 1));
        } else {
            $task_definitions{$id} = $index + 1;
        }
        if (exists $all_task_definitions{$id}) {
            fail("task ID $id appears in active and superseded history on lines $all_task_definitions{$id} and " . ($index + 1));
        } else {
            $all_task_definitions{$id} = $index + 1;
        }
    } elsif ($line =~ /^~~- \[([ x])\] (GP-[1-9][0-9]{2,})\b.*~~$/) {
        my ($box, $id) = ($1, $2);
        my $task = {
            id => $id,
            fields => task_fields($index + 1, 'Superseded|Requirements'),
            line => $index + 1,
            phase => $current_phase,
        };
        $phases[$current_phase]{superseded}++ if $current_phase >= 0;
        fail("superseded task $id must remain unchecked") if $box eq 'x';
        if (exists $all_task_definitions{$id}) {
            fail("duplicate historical task ID $id on lines $all_task_definitions{$id} and " . ($index + 1));
        } else {
            $all_task_definitions{$id} = $index + 1;
        }
        for my $field ('Superseded', 'Requirements') {
            my $count = exists $task->{fields}{$field}
                ? scalar @{$task->{fields}{$field}} : 0;
            fail("superseded task $id missing required field: $field")
                if $count == 0;
            fail("superseded task $id has duplicate required field: $field")
                if $count > 1;
            fail("superseded task $id has empty required field: $field")
                if $count == 1 && $task->{fields}{$field}[0] eq '';
        }
        push @superseded_tasks, $task;
    } elsif ($line =~ /^~~\s*-?\s*\[[^]]*\]\s*GP-/) {
        fail('malformed superseded task on line ' . ($index + 1));
    } elsif ($line =~ /^-\s*\[[^]]*\]\s*GP-/) {
        fail('malformed task definition on line ' . ($index + 1));
    } elsif ($current_phase >= 0 && $line =~ /^Checkpoint:[ \t]*(\S.*)$/) {
        fail("Phase $phases[$current_phase]{number} has duplicate Checkpoint")
            if defined $phases[$current_phase]{checkpoint};
        $phases[$current_phase]{checkpoint} = $1;
    } elsif ($current_phase >= 0 && $line =~ /^Checkpoint verify:[ \t]*(.*?)[ \t]*$/) {
        my ($phase, $command) = ($phases[$current_phase], $1);
        fail("Phase $phase->{number} has duplicate Checkpoint verify")
            if defined $phase->{checkpoint_verify};
        fail("Phase $phase->{number} Checkpoint verify must be one executable command in backticks")
            if not_command($command);
        ($phase->{checkpoint_verify} = $command) =~ s/^`(.*)`$/$1/;
    }
}

for my $index (0 .. $#phases) {
    my $expected = $index + 1;
    my $found = $phases[$index]{number};
    fail("phase numbers must be sequential: expected Phase $expected, found Phase $found")
        if $found != $expected;
}

my @required_fields = ('Files', 'Depends on', 'Reuses', 'Acceptance', 'Verify', 'Requirements');
for my $task (@tasks) {
    for my $field (@required_fields) {
        my $count = exists $task->{fields}{$field} ? scalar @{$task->{fields}{$field}} : 0;
        if ($count == 0) {
            fail("$task->{id} missing required field: $field");
        } elsif ($count > 1) {
            fail("$task->{id} has duplicate required field: $field");
        } elsif ($task->{fields}{$field}[0] eq '') {
            fail("$task->{id} has empty required field: $field");
        }
    }

    if (exists $task->{fields}{'Depends on'} && @{$task->{fields}{'Depends on'}} == 1) {
        my $depends = $task->{fields}{'Depends on'}[0];
        if ($depends ne 'none') {
            my @dependencies = split /\s*,\s*/, $depends, -1;
            if (!@dependencies || grep { $_ !~ /^GP-[1-9][0-9]{2,}$/ } @dependencies) {
                fail("$task->{id} has malformed Depends on value '$depends'");
            } else {
                for my $dependency (@dependencies) {
                    if ($dependency eq $task->{id}) {
                        fail("$task->{id} depends on itself");
                    } elsif (!exists $task_definitions{$dependency}) {
                        fail("$task->{id} depends on undefined task $dependency");
                    } elsif ($task_definitions{$dependency} > $task->{line}) {
                        fail("$task->{id} depends on later task $dependency");
                    }
                }
            }
        }
    }

    if (exists $task->{fields}{Verify} && @{$task->{fields}{Verify}} == 1) {
        fail("$task->{id} Verify must be one executable command in backticks")
            if not_command($task->{fields}{Verify}[0]);
    }

    if (exists $task->{fields}{Requirements} && @{$task->{fields}{Requirements}} == 1) {
        my $requirements = $task->{fields}{Requirements}[0];
        my @requirement_ids = split /\s*,\s*/, $requirements, -1;
        if (!@requirement_ids
                || grep { $_ !~ /^R-(?:[0-9]+\.[0-9]+|[A-Z][A-Z0-9-]*-[0-9]+)$/ } @requirement_ids) {
            fail("$task->{id} has malformed Requirements value '$requirements'");
        } else {
            for my $requirement_id (@requirement_ids) {
                next if $local_requirements{$requirement_id};
                next if $catalog_requirements{$requirement_id};
                fail("$task->{id} cites undefined requirement $requirement_id");
            }
        }
    }
}

# [P] promises an executor it may run this task beside its wave siblings. Check
# the promise instead of trusting it: a shared path means two concurrent writers
# to one file, the fictional parallelism the roadmap module already refuses.
my %wave_members;
for my $task_index (0 .. $#tasks) {
    my $task = $tasks[$task_index];
    next if $task->{done};
    next unless defined $task->{wave};
    push @{$wave_members{$task->{wave}}}, $task_index;
}

# Compare paths, not spellings; a trailing slash names a directory.
my %task_files;
for my $task_index (0 .. $#tasks) {
    my $files = $tasks[$task_index]{fields}{Files};
    next unless $files && @$files == 1;
    my %paths;
    for my $entry (split /\s*,\s*(?![^()]*\))/, $files->[0]) {
        my ($path) = $entry =~ /`([^`]+)`/ ? ($1) : ($entry =~ /^\s*(\S+)/);
        next if !defined $path || lc $path eq 'none';
        $path =~ s{/+}{/}g;
        $path =~ s{^(?:\./)+}{};
        $paths{$path} = 1 if $path ne '';
    }
    $task_files{$task_index} = \%paths;
}

sub paths_overlap {
    my ($x, $y) = @_;
    return $x eq $y || ($x =~ m{/$} && index($y, $x) == 0) || ($y =~ m{/$} && index($x, $y) == 0);
}

my %ancestors;
for my $task (@tasks) {
    my %set;
    %set = (%set, $_ => 1, %{$ancestors{$_} || {}}) for dependency_ids($task);
    $ancestors{$task->{id}} = \%set;
}

for my $wave (sort keys %wave_members) {
    my @members = @{$wave_members{$wave}};
    for my $left (0 .. $#members) {
        for my $right ($left + 1 .. $#members) {
            my ($first, $second) = ($members[$left], $members[$right]);
            next unless $tasks[$first]{parallel} || $tasks[$second]{parallel};
            my ($one, $two) = ($tasks[$first]{id}, $tasks[$second]{id});
            fail("$one and $two are both in $wave and one is marked [P], but one depends on the other")
                if $ancestors{$two}{$one} || $ancestors{$one}{$two};
            next unless exists $task_files{$first} && exists $task_files{$second};
            my @shared = sort grep { my $path = $_; grep { paths_overlap($path, $_) } keys %{$task_files{$second}} }
                keys %{$task_files{$first}};
            fail("$one and $two are both in $wave and one is marked [P], but they share "
                . join(', ', @shared)) if @shared;
        }
    }
}

for my $task (@superseded_tasks) {
    next unless exists $task->{fields}{Requirements}
        && @{$task->{fields}{Requirements}} == 1;
    my $requirements = $task->{fields}{Requirements}[0];
    my @requirement_ids = split /\s*,\s*/, $requirements, -1;
    if (!@requirement_ids
            || grep { $_ !~ /^R-(?:[0-9]+\.[0-9]+|[A-Z][A-Z0-9-]*-[0-9]+)$/ } @requirement_ids) {
        fail("superseded task $task->{id} has malformed Requirements value '$requirements'");
        next;
    }
    for my $requirement_id (@requirement_ids) {
        next if $local_requirements{$requirement_id};
        next if $catalog_requirements{$requirement_id};
        fail("superseded task $task->{id} cites undefined requirement $requirement_id");
    }
}

if (exists $frontmatter{public_release} && $frontmatter{public_release} eq 'false') {
    for my $requirement_id (qw(R-SEC-26 R-ROAD-21 R-LAUNCH-22)) {
        fail("public_release false must not cite $requirement_id")
            if grep { task_has_requirement($_, $requirement_id) } @tasks;
    }
}

if (exists $frontmatter{public_release} && $frontmatter{public_release} eq 'true') {
    my @hardening_indexes = grep { task_has_requirement($tasks[$_], 'R-SEC-26') } 0 .. $#tasks;
    my @gate_indexes = grep { task_has_requirement($tasks[$_], 'R-ROAD-21') } 0 .. $#tasks;
    my @activation_indexes = grep { task_has_requirement($tasks[$_], 'R-LAUNCH-22') } 0 .. $#tasks;

    fail('public release requires at least one hardening task citing R-SEC-26')
        unless @hardening_indexes;
    if (!@gate_indexes) {
        fail('public release requires a prepublication gate task citing R-ROAD-21');
    } elsif (@gate_indexes != 1) {
        fail('public release requires exactly one prepublication gate task citing R-ROAD-21, found ' . scalar @gate_indexes);
    }
    fail('public release requires exactly one first activation task citing R-LAUNCH-22, found ' . scalar @activation_indexes)
        unless @activation_indexes == 1;

    if (@hardening_indexes && @gate_indexes == 1) {
        my $latest_hardening_index = $hardening_indexes[-1];
        my $gate_index = $gate_indexes[0];
        my $latest_hardening_id = $tasks[$latest_hardening_index]{id};
        my $gate_id = $tasks[$gate_index]{id};

        fail("prepublication gate must follow the latest hardening task $latest_hardening_id")
            unless $gate_index > $latest_hardening_index;
        fail("prepublication gate must depend on the latest hardening task $latest_hardening_id")
            unless task_depends_on($tasks[$gate_index], $latest_hardening_id);

        if (exists $tasks[$gate_index]{fields}{Acceptance}
                && @{$tasks[$gate_index]{fields}{Acceptance}} == 1) {
            my $acceptance = $tasks[$gate_index]{fields}{Acceptance}[0];
            for my $field (qw(checked_at hardening_revision finding_counts policy verdict owner justification accepted_at expires_at invalidates)) {
                fail("prepublication gate $gate_id Acceptance is missing $field")
                    if index($acceptance, $field) < 0;
            }
        }

        if (@activation_indexes == 1) {
            my $activation_index = $activation_indexes[0];
            my $activation_id = $tasks[$activation_index]{id};
            fail("public activation must immediately follow the prepublication gate $gate_id")
                unless $activation_index == $gate_index + 1;
            fail("public activation must depend on the prepublication gate $gate_id")
                unless task_depends_on($tasks[$activation_index], $gate_id);
        }
    }
}

my $tasks_total = scalar @tasks;
my $tasks_done = scalar grep { $_->{done} } @tasks;
my $phases_total = scalar @phases;
my $phases_done = 0;
for my $phase (@phases) {
    # A phase of only superseded tasks stays as history; removing it renumbers later phases.
    if (!@{$phase->{tasks}}) {
        if ($phase->{superseded}) {
            $phases_done++;
        } else {
            fail("Phase $phase->{number} has no task definitions");
        }
        next;
    }
    fail("Phase $phase->{number} is missing Checkpoint")
        unless defined $phase->{checkpoint};
    fail("Phase $phase->{number} is missing Checkpoint verify")
        unless defined $phase->{checkpoint_verify};
    my $all_done = 1;
    for my $task_index (@{$phase->{tasks}}) {
        $all_done = 0 unless $tasks[$task_index]{done};
    }
    $phases_done++ if $all_done;
}

my %derived_counter = (
    phases_total => $phases_total,
    phases_done => $phases_done,
    tasks_total => $tasks_total,
    tasks_done => $tasks_done,
);
for my $key (qw(phases_total phases_done tasks_total tasks_done)) {
    next unless exists $counter{$key} && $counter{$key} =~ /^[0-9]+$/;
    fail("$key is $counter{$key}, derived value is $derived_counter{$key}")
        if $counter{$key} != $derived_counter{$key};
}
fail("status done requires every task checked, found $tasks_done of $tasks_total")
    if ($frontmatter{status} || '') eq 'done' && $tasks_done != $tasks_total;

section_count('Open Questions');
my %open_question = map { $lines[$_] =~ /^### (Q[1-9][0-9]*):/ ? ($1 => $lines[$_]) : () }
    section('## Open Questions');

my $provenance_count = section_count('Plan provenance');
section_count('Product form');

# Archetype confidence is arithmetic, not a feeling. The plan states its own
# scores; everything downstream of them is recomputed here, so a confident
# label that does not follow from the plan's own numbers cannot ship.
my $archetype_low = '';
my %archetype_block;
my $archetype_count = scalar grep { $_ eq '### Archetype confidence' } @lines;
fail("expected exactly one ### Archetype confidence block, found $archetype_count")
    if $archetype_count != 1;
fail('### Archetype confidence must sit under ## Product form')
    if $archetype_count == 1 && !grep { $lines[$_] eq '### Archetype confidence' } section('## Product form');

if ($archetype_count == 1) {
    for my $index (section('### Archetype confidence')) {
        next unless $lines[$index] =~ /^-[ \t]+([A-Za-z][A-Za-z -]*?)[ \t]*:[ \t]*(\S.*)$/;
        my ($field, $value) = ($1, $2);
        fail("archetype confidence has duplicate field $field")
            if exists $archetype_block{$field};
        $archetype_block{$field} = $value;
    }

    for my $field ('Primary', 'Runner-up', 'Margin', 'Confidence', 'Vetoes applied', 'Overlays') {
        fail("archetype confidence is missing $field")
            unless exists $archetype_block{$field};
    }

    my ($primary_name, $primary_score);
    if (defined $archetype_block{Primary}) {
        if ($archetype_block{Primary} =~ /^([a-z0-9-]+)[ \t]*\(score[ \t]+([01]\.[0-9]{2})\)$/) {
            ($primary_name, $primary_score) = ($1, $2 + 0);
        } else {
            fail("archetype confidence Primary must read '<archetype> (score 0.NN)'");
        }
    }
    my ($runner_name, $runner_score);
    if (defined $archetype_block{'Runner-up'}) {
        if (lc $archetype_block{'Runner-up'} eq 'none') {
            $runner_score = 0;
        } elsif ($archetype_block{'Runner-up'} =~ /^([a-z0-9-]+)[ \t]*\(score[ \t]+([01]\.[0-9]{2})\)$/) {
            ($runner_name, $runner_score) = ($1, $2 + 0);
        } else {
            fail("archetype confidence Runner-up must read '<archetype> (score 0.NN)' or 'none'");
        }
    }
    for my $name (grep { defined $_ && !$allowed_archetype{$_} } $primary_name, $runner_name) {
        fail("archetype confidence names $name, which is not one of " . join(', ', @archetypes));
    }

    if (defined $primary_score) {
        fail("archetype confidence Primary score exceeds 1.00") if $primary_score > 1;
        if (exists $frontmatter{archetype} && defined $primary_name
                && ($frontmatter{archetype} ne 'unknown' || $primary_score >= 0.45)
                && $primary_name ne $frontmatter{archetype}) {
            fail("archetype confidence Primary is $primary_name but frontmatter archetype is $frontmatter{archetype}");
        }
        # Below the floor the archetype is not decided, and a named archetype
        # would license matrix defaults and a document set nothing supports.
        if ($primary_score < 0.45) {
            $archetype_low = 'the archetype Primary score is below the 0.45 floor';
            fail('archetype confidence Primary score ' . sprintf('%.2f', $primary_score) . ' is below the 0.45 floor, so frontmatter archetype must be unknown')
                if exists $frontmatter{archetype} && $frontmatter{archetype} ne 'unknown';
        }
    }

    if (defined $primary_score && defined $runner_score) {
        fail("archetype confidence Runner-up scores at or above Primary")
            if defined $runner_name && $runner_score >= $primary_score;
        fail("archetype confidence Runner-up repeats the Primary archetype")
            if defined $runner_name && defined $primary_name && $runner_name eq $primary_name;
        my $expected_margin = int(($primary_score - $runner_score) * 100 + 0.5);
        if (defined $archetype_block{Margin}) {
            if ($archetype_block{Margin} =~ /^(-?[0-9]+)[ \t]+points?$/) {
                fail("archetype confidence Margin is $1 but the scores give $expected_margin")
                    if $1 != $expected_margin;
            } else {
                fail("archetype confidence Margin must read '<n> points'");
            }
        }
        my $expected_confidence =
            ($expected_margin >= 15 && $primary_score >= 0.70) ? 'high'
            : ($expected_margin >= 15 || $primary_score >= 0.70) ? 'medium'
            : 'low';
        $archetype_low = 'archetype confidence is low' if $expected_confidence eq 'low';
        if (defined $archetype_block{Confidence}) {
            my $stated = lc $archetype_block{Confidence};
            if (!$allowed_confidence{$stated}) {
                fail("archetype confidence Confidence must be high, medium, or low");
            } elsif ($stated ne $expected_confidence) {
                fail("archetype confidence states $stated but a margin of $expected_margin with a primary score of $primary_score gives $expected_confidence");
            }
        }
        if (exists $frontmatter{archetype_confidence}
                && $allowed_confidence{$frontmatter{archetype_confidence}}
                && $frontmatter{archetype_confidence} ne $expected_confidence) {
            fail("frontmatter archetype_confidence is $frontmatter{archetype_confidence} but the block's scores give $expected_confidence");
        }
    }

    # A counterfactual priced in adjectives cannot be acted on. Tasks and
    # phases are the units the rest of the plan already trades in.
    if (defined $runner_name) {
        my $counterfactual = $archetype_block{'If the runner-up is right'};
        if (!defined $counterfactual) {
            fail("archetype confidence names a runner-up but no 'If the runner-up is right:' counterfactual");
        } elsif ($counterfactual !~ /[+-]?[0-9]+[ \t]+tasks?\b/
                || $counterfactual !~ /[+-]?[0-9]+[ \t]+phases?\b/) {
            fail("archetype confidence counterfactual must be priced in tasks and phases, not adjectives");
        }
    }

    if (defined $archetype_block{Overlays}) {
        my $stated = trim($archetype_block{Overlays});
        my @stated_overlays = lc($stated) eq 'none'
            ? ()
            : sort grep { $_ ne '' } map { trim($_) } split /\s*,\s*/, $stated, -1;
        my $stated_key = join ',', @stated_overlays;
        my $frontmatter_key = join ',', @overlays;
        fail("archetype confidence Overlays says '$stated' but frontmatter overlays is [$frontmatter_key]")
            if $stated_key ne $frontmatter_key;
    }
}

# Low confidence, or a Primary below the floor, is not a disclaimer. It withholds
# the archetype as a settled fact until a human confirms it, so the question has
# to be on the page.
fail("$archetype_low, so the archetype belongs in ## Open Questions as a ### Q<n>: entry naming it")
    if $archetype_low && !grep { /archetype/i } values %open_question;

if ($provenance_count == 1) {
    my @body = map { $lines[$_] } section('## Plan provenance');

    my %label_key = (
        'Source revision' => 'source_revision',
        'Input digest' => 'input_digest',
        'Validated at' => 'validated_at',
    );
    my %label_count;
    my %label_value;
    my $inventory_count = 0;
    my $inventory_started = 0;
    my $inventory_valid = 1;

    for my $line (@body) {
        next if $line eq '';
        if ($line =~ /^(Source revision|Input digest|Validated at):[ \t]*(.*)$/) {
            my ($label, $value) = ($1, trim($2));
            $label_count{$label}++;
            $label_value{$label} = $value;
            next;
        }
        if ($line =~ /^Evidence inventory:[ \t]*(.*)$/) {
            $label_count{'Evidence inventory'}++;
            $inventory_started = 1;
            if (trim($1) ne '') {
                fail('Plan provenance Evidence inventory label must not contain an inline value');
                $inventory_valid = 0;
            }
            next;
        }
        if ($inventory_started
                && $line =~ /^- (\[recheck\] )?`([A-Za-z0-9._][A-Za-z0-9._\/-]*)` = `sha256:([0-9a-f]{64})`$/) {
            my ($recheck, $label, $digest) = ($1, $2, $3);
            $inventory_count++;
            # A dotfile path is a repository-relative path; a .. segment is not.
            if ($label =~ m{(?:^|/)\.\.(?:/|$)}) {
                fail("Plan provenance inventory label $label must not contain a .. segment");
                $inventory_valid = 0;
            } elsif (exists $inventory{$label}) {
                fail("duplicate Plan provenance inventory label: $label");
                $inventory_valid = 0;
            } else {
                $inventory{$label} = $digest;
                $recheck_inventory{$label} = $digest if defined $recheck;
            }
            next;
        }
        if ($inventory_started) {
            fail("malformed Plan provenance inventory item: $line");
        } else {
            fail("malformed Plan provenance line: $line");
        }
        $inventory_valid = 0;
    }

    for my $label ('Source revision', 'Input digest', 'Validated at', 'Evidence inventory') {
        my $count = $label_count{$label} || 0;
        fail("Plan provenance is missing $label:") if $count == 0;
        fail("Plan provenance has duplicate $label label") if $count > 1;
    }

    for my $label ('Source revision', 'Input digest', 'Validated at') {
        next unless ($label_count{$label} || 0) == 1;
        my $key = $label_key{$label};
        next unless exists $frontmatter{$key};
        fail("Plan provenance $label does not match frontmatter $key")
            if $label_value{$label} ne $frontmatter{$key};
    }

    fail('Plan provenance Evidence inventory must contain at least one item')
        if $inventory_count == 0;
    my $intake_count = exists $inventory{intake} ? 1 : 0;
    fail('Plan provenance Evidence inventory must contain exactly one intake item')
        unless $intake_count == 1;

    if ($inventory_valid
            && $inventory_count > 0
            && $intake_count == 1
            && ($label_count{'Input digest'} || 0) == 1) {
        my $digest_input = join '', map { "$_\t$inventory{$_}\n" } sort keys %inventory;
        my $aggregate = 'sha256:' . sha256_hex($digest_input);
        fail('Plan provenance Input digest does not match the Evidence inventory aggregate')
            if $label_value{'Input digest'} ne $aggregate;
    }
}

my %known_domain = map { $_ => 1 } qw(
    product business architecture stack database security llm ux ui seo code-quality
    style-genome agent-memory repo build roadmap deploy observe launch
);
my %allowed_disposition = map { $_ => 1 } qw(applicable deferred excluded);
my %deferrable_domain = map { $_ => 1 } qw(seo launch observe ui deploy);
# These five scale down; they never leave the plan. A later layer may raise a
# domain's disposition and never lower it out of existence, so an exclusion here
# is a lowering the engine refuses rather than a judgement call.
my %never_excludable = map { $_ => 1 } qw(security code-quality style-genome repo roadmap);
my $vague_predicate = qr/^(?:later|eventually|when ready|post-mvp|future|tbd)\b/;
my %domain_evidence_state;
my %domain_revisit_when;
my $matrix_count = section_count('Applicability matrix');

if ($matrix_count == 1) {
    my %seen_domain;
    for my $line (map { $lines[$_] } section('## Applicability matrix')) {
        next unless $line =~ /^\|[ \t]*([a-z0-9-]+)[ \t]*\|[ \t]*([a-z0-9-]+)[ \t]*\|[ \t]*(.*?)[ \t]*\|[ \t]*$/;
        my ($domain, $disposition, $reason) = ($1, $2, $3);
        next unless $known_domain{$domain};
        fail("applicability matrix has a duplicate row for $domain")
            if $seen_domain{$domain}++;
        if (!$allowed_disposition{$disposition}) {
            fail("applicability matrix row for $domain has invalid status '$disposition'; expected applicable, deferred, or excluded");
            next;
        }
        # An exclusion with no evidence state and no expiry is a silence with a
        # reason attached: it reads exactly like a considered decision and
        # nothing ever reopens it. Demand the state that licensed it and the
        # predicate that would reverse it.
        if ($disposition eq 'excluded') {
            fail("applicability matrix cannot exclude load-bearing domain $domain; it scales down instead")
                if $never_excludable{$domain};
            fail("applicability matrix excludes $domain, which the $overlay_protected{$domain} overlay covers; overlays raise and never lower, so this row " . ($deferrable_domain{$domain} ? "may be applicable or deferred but not excluded" : "must be applicable"))
                if $overlay_protected{$domain};
            my ($state) = $reason =~ /^[ \t]*([A-Za-z-]+)[ \t]*:/;
            $state = defined $state ? lc $state : '';
            my ($predicate) = $reason =~ /revisit when[ \t]*:[ \t]*(.*)$/i;
            $predicate = defined $predicate ? $predicate : '';
            $predicate =~ s/[ \t]+$//;
            if ($reason eq '') {
                fail("applicability matrix excludes $domain without a reason");
            } elsif ($state eq 'unknown' || $state eq 'hint') {
                fail("applicability matrix excludes $domain on evidence state '$state'; only absent or by-design may exclude, so make the domain applicable or open a question");
            } elsif ($state ne 'absent' && $state ne 'by-design') {
                fail("applicability matrix excludes $domain without an evidence state; the reason must open with 'absent:' or 'by-design:'");
            }
            if ($reason ne '' && $predicate eq '') {
                fail("applicability matrix excludes $domain without a revisit when: tripwire");
            } elsif (lc($predicate) =~ $vague_predicate) {
                fail("applicability matrix excludes $domain with a vague revisit when: predicate");
            } elsif ($predicate ne '' && length($predicate) < 12) {
                fail("applicability matrix excludes $domain with a revisit when: predicate too short to observe");
            }
            # `absent:` against existing code is a negative claim, and the
            # claims-and-evidence rule refuses those without a search. Greenfield
            # has nothing to have looked at, so only `by-design:` applies there.
            if ($state eq 'absent'
                    && exists $frontmatter{mode}
                    && ($frontmatter{mode} eq 'brownfield' || $frontmatter{mode} eq 'replan')
                    && $reason !~ /`[^`]+`/) {
                fail("applicability matrix excludes $domain on an absent: claim with no backticked command or evidence artifact; a negative claim about existing code needs the search that came back empty");
            }
            $domain_evidence_state{$domain} = $state;
            $domain_revisit_when{$domain} = $predicate;
        }
        if ($disposition eq 'deferred') {
            fail("applicability matrix cannot defer load-bearing domain $domain")
                unless $deferrable_domain{$domain};
            fail("applicability matrix defers $domain without a trigger")
                if index(lc($reason), 'trigger:') < 0;
            fail("applicability matrix defers $domain without a reversibility argument")
                if index(lc($reason), 'reversib') < 0;
            fail("applicability matrix defers $domain with a vague trigger")
                if lc($reason) =~ /trigger:[ \t]*(?:later|eventually|when ready|post-mvp|future|tbd)\b/;
        }
        $domain_disposition{$domain} = $disposition;
        $domain_reason{$domain} = $reason;
    }
    for my $domain (sort keys %known_domain) {
        fail("applicability matrix is missing domain $domain")
            unless $seen_domain{$domain};
    }
}

# The rest of the skeleton. Architecture and Agent memory are owed only while
# their domain applies; extra ## sections are allowed.
section_count($_) for 'Scope and non-goals', 'Compliance gate', 'Requirements', 'Style genome',
    'Phases', 'Rules for executing agents', 'Session log',
    grep { ($domain_disposition{lc($_) =~ tr/ /-/r} || '') eq 'applicable' } 'Architecture', 'Agent memory';

# The module disposition is the only place a module requirement may leave the
# plan. Precedence alone does not save it: a later layer is not a more correct
# layer, only a later one, so the line names which layer dropped what. Without
# that name, a requirement cut to fit a weekend appetite is indistinguishable
# from one nobody ever considered, and only one of those is a decision.
my %module_prefix = (
    'product' => 'PRD', 'business' => 'BIZ', 'architecture' => 'ARCH', 'stack' => 'STACK',
    'database' => 'DB', 'security' => 'SEC', 'llm' => 'LLM', 'ux' => 'UX',
    'ui' => 'UI', 'seo' => 'SEO', 'code-quality' => 'CODE',
    'style-genome' => 'DNA', 'agent-memory' => 'MEM', 'repo' => 'REPO',
    'build' => 'BUILD', 'roadmap' => 'ROAD', 'deploy' => 'DEPLOY',
    'observe' => 'OBS', 'launch' => 'LAUNCH',
);
my %prefix_module = reverse %module_prefix;
my %dropped_layer = map { $_ => 1 } qw(scale archetype form);
my @json_disposition;
if (%domain_disposition) {
    my %task_requirement;
    for my $task (@tasks) {
        next unless exists $task->{fields}{Requirements}
            && @{$task->{fields}{Requirements}} == 1;
        for my $id (split /\s*,\s*/, $task->{fields}{Requirements}[0], -1) {
            $task_requirement{$id} = $task->{id};
        }
    }
    # A task may not trace to a module the matrix keeps out of this plan.
    for my $id (sort keys %task_requirement) {
        my ($module) = map { $prefix_module{$_} } $id =~ /^R-([A-Z][A-Z0-9-]*)-[0-9]+$/;
        my $status = $module ? $domain_disposition{$module} || '' : '';
        fail("$task_requirement{$id} cites $id, but the applicability matrix marks $module $status")
            if $status eq 'excluded' || $status eq 'deferred';
    }

    my $found = grep { $_ eq '### Module disposition' } @lines;
    my $inside = grep { $lines[$_] eq '### Module disposition' } section('## Applicability matrix');
    my %disposition_line = map { ($_ + 1 => $lines[$_]) }
        grep { $lines[$_] =~ /\S/ } section('### Module disposition');

    # Landed means used: a mention outside the frontmatter, session log, and disposition block.
    my (%reference_lines, $in_log);
    for my $index ($frontmatter_end + 1 .. $#lines) {
        $in_log = $lines[$index] eq '## Session log' if $lines[$index] =~ /^## /;
        next if $in_log || exists $disposition_line{$index + 1};
        my %seen = map { $_ => 1 } $raw_lines[$index] =~ /(R-[A-Z][A-Z0-9-]*-[0-9]+)/g;
        $reference_lines{$_}++ for keys %seen;
    }

    if ($found != 1 || $inside != 1) {
        fail("expected exactly one ### Module disposition block under ## Applicability matrix, found $inside"
            . ($found > $inside ? ' there and ' . ($found - $inside) . ' elsewhere' : ''));
    }

    my %seen_module;
    for my $line_number (sort { $a <=> $b } keys %disposition_line) {
        my $line = $disposition_line{$line_number};
        my ($module, $body) = $line =~ /^-[ \t]+([a-z0-9-]+)[ \t]*:[ \t]*(\S.*)$/;
        if (!defined $module) {
            fail("module disposition line $line_number must read '- <module>: landed <ids>[; dropped-by <layer> <ids> (<reason>)]'");
            next;
        }
        if (!exists $module_prefix{$module}) {
            fail("module disposition names unknown module $module on line $line_number");
            next;
        }
        fail("module disposition has a duplicate line for $module")
            if $seen_module{$module}++;
        my $status = $domain_disposition{$module} || 'absent';
        if ($status ne 'applicable') {
            fail("module disposition covers $module, which the applicability matrix marks $status; only applicable modules land or drop requirements");
            next;
        }
        my $prefix = $module_prefix{$module};
        my %landed;
        my %dropped;
        my @dropped_entries;
        my $malformed = 0;
        for my $clause (split /\s*;\s*(?![^()]*\))/, $body) {
            next if $clause eq '';
            if ($clause =~ /^landed[ \t]+(\S.*)$/i) {
                my $ids = $1;
                next if lc($ids) eq 'none';
                for my $id (split /\s*,\s*/, $ids, -1) {
                    $id =~ s/^\s+|\s+$//g;
                    next if $id eq '';
                    if ($id !~ /^R-\Q$prefix\E-[0-9]+$/) {
                        fail("module disposition for $module lists $id, which is not an R-$prefix requirement");
                        $malformed = 1;
                        next;
                    }
                    if (!$catalog_requirements{$id}) {
                        fail("module disposition for $module lands undefined requirement $id");
                        $malformed = 1;
                        next;
                    }
                    $landed{$id} = 1;
                }
            } elsif ($clause =~ /^dropped-by[ \t]+([a-z]+)[ \t]+(\S.*?)[ \t]*\((\S.*)\)$/i) {
                my ($layer, $ids, $reason) = (lc $1, $2, $3);
                if (!$dropped_layer{$layer}) {
                    fail("module disposition for $module drops by unknown layer '$layer'; use scale, archetype, or form");
                    $malformed = 1;
                    next;
                }
                my @ids;
                for my $id (split /\s*,\s*/, $ids, -1) {
                    $id =~ s/^\s+|\s+$//g;
                    next if $id eq '';
                    if ($id !~ /^R-\Q$prefix\E-[0-9]+$/) {
                        fail("module disposition for $module drops $id, which is not an R-$prefix requirement");
                        $malformed = 1;
                        next;
                    }
                    if (!$catalog_requirements{$id}) {
                        fail("module disposition for $module drops undefined requirement $id");
                        $malformed = 1;
                        next;
                    }
                    $dropped{$id} = 1;
                    push @ids, $id;
                }
                push @dropped_entries, { layer => $layer, reason => $reason, requirements => \@ids };
            } elsif ($clause =~ /^dropped-by\b/i) {
                fail("module disposition for $module has a dropped-by clause without a parenthesised reason");
                $malformed = 1;
            } else {
                fail("module disposition for $module has an unrecognised clause '$clause'");
                $malformed = 1;
            }
        }
        next if $malformed;
        for my $id (sort keys %dropped) {
            fail("module disposition for $module both lands and drops $id")
                if $landed{$id};
            fail("module disposition drops $id but $task_requirement{$id} still traces to it")
                if exists $task_requirement{$id};
        }
        for my $id (sort keys %landed) {
            fail("module disposition lands $id but nothing outside the frontmatter, session log, and disposition block references it")
                unless $reference_lines{$id};
        }
        push @json_disposition, {
            module => $module,
            landed => [sort keys %landed],
            dropped => \@dropped_entries,
        };
    }

    if ($found) {
        for my $domain (sort keys %domain_disposition) {
            next unless $domain_disposition{$domain} eq 'applicable';
            fail("module disposition is missing applicable module $domain")
                unless $seen_module{$domain};
        }
    }
}

# The three frontmatter lists index the matrix; the matrix decides. Recompute
# them from the rows and fail on drift, the same parity the provenance block
# gets, so a summary can never quietly contradict the section it summarizes.
if (%domain_disposition) {
    my %expected;
    for my $domain (sort keys %domain_disposition) {
        push @{$expected{$domain_disposition{$domain}}}, $domain;
    }
    my %list_key = (
        applicable => 'domains_applicable',
        deferred   => 'domains_deferred',
        excluded   => 'domains_excluded',
    );
    for my $status (qw(applicable deferred excluded)) {
        my $key = $list_key{$status};
        next unless exists $frontmatter{$key};
        my $raw = trim($frontmatter{$key});
        if ($raw !~ /^\[(.*)\]$/) {
            fail("frontmatter $key must be a single inline list such as [product, security]");
            next;
        }
        my %declared;
        my $malformed = 0;
        for my $domain (split /\s*,\s*/, $1, -1) {
            $domain = trim($domain);
            next if $domain eq '';
            if (!exists $known_domain{$domain}) {
                fail("frontmatter $key names unknown domain $domain");
                $malformed = 1;
                next;
            }
            fail("frontmatter $key lists $domain twice") if $declared{$domain}++;
        }
        next if $malformed;
        my %wanted = map { $_ => 1 } @{$expected{$status} || []};
        my @missing = sort grep { !$declared{$_} } keys %wanted;
        my @extra = sort grep { !$wanted{$_} } keys %declared;
        fail("frontmatter $key does not match the applicability matrix: missing "
            . join(', ', @missing)) if @missing;
        fail("frontmatter $key does not match the applicability matrix: $_ is "
            . ($domain_disposition{$_} || 'absent') . " in the matrix")
            for @extra;
    }
}

# The documentation set is where an absence gets defended. A not-applicable row
# with no evidence state and no tripwire launders a gap into a decision, which
# is the one outcome this section exists to make structurally hard.
my %doc_verdict = map { $_ => 1 } qw(required recommended optional not-applicable);
my @json_documents;
my $docset_count = section_count('Documentation set');

if ($docset_count == 1) {
    my $boundary = 0;
    my %seen_document;
    my $rows = 0;
    for my $index (section('## Documentation set')) {
        my $line = $lines[$index];
        $boundary = 1
            if index(lc($line), 'committed to this repository') >= 0;
        # Every row but the header and separator is read, so an unparsable row fails.
        next if $line !~ /^\|/ || $line =~ /^\|[ \t]*:?-/ || ($lines[$index + 1] || '') =~ /^\|[ \t]*:?-/;
        if ($line !~ /^\|[ \t]*`?([a-z]+\.[a-z0-9-]+)`?[ \t]*\|[ \t]*([a-z-]+)[ \t]*\|[ \t]*([a-z-]+)[ \t]*\|[ \t]*([a-z-]+)[ \t]*\|[ \t]*(.*?)[ \t]*\|[ \t]*$/) {
            fail("malformed documentation set row: $line");
            next;
        }
        my ($id, $stage, $verdict, $owner, $detail) = ($1, $2, $3, $4, $5);
        my ($state) = $detail =~ /^[ \t]*([A-Za-z-]+)[ \t]*:/;
        $state = defined $state ? lc $state : '';
        $rows++;
        if (!exists $doc_catalog{$id}) {
            fail("documentation set names $id, which is not a doc-set.md catalog id");
            next;
        }
        fail("documentation set has a duplicate row for $id")
            if $seen_document{$id}++;
        my ($catalog_owner, $durability) = split /\|/, $doc_catalog{$id};
        my ($catalog_stage) = $id =~ /^([a-z]+)\./;
        fail("documentation set row $id declares stage '$stage'; the catalog stage is $catalog_stage")
            if $stage ne $catalog_stage;
        fail("documentation set row $id records $state in a greenfield plan; only brownfield and replan find documents present")
            if ($frontmatter{mode} || '') eq 'greenfield' && $state =~ /^present-(?:current|drifted|stub)$/;
        if (!$doc_verdict{$verdict}) {
            fail("documentation set row $id has invalid verdict '$verdict'; expected required, recommended, optional, or not-applicable");
            next;
        }
        fail("documentation set row $id names owner '$owner'; the catalog owner is $catalog_owner, and exactly one module owns a document")
            if $owner ne $catalog_owner;
        if ($verdict eq 'required' || $verdict eq 'recommended') {
            my @task_refs = $detail =~ /(GP-[0-9]+)/g;
            # adopt and confirm (doc-set.md section 6) cost frontmatter, not a task.
            fail("documentation set row $id is $verdict but names no GP task that writes it")
                unless @task_refs || $state eq 'present-current' || $state eq 'present-elsewhere';
            for my $ref (@task_refs) {
                fail("documentation set row $id names "
                    . (exists $all_task_definitions{$ref} ? "superseded task $ref" : "$ref, which is not a task in this plan"))
                    unless exists $task_definitions{$ref};
            }
            my $owner_status = $domain_disposition{$owner};
            fail("documentation set row $id is $verdict but its owner module $owner is excluded in the applicability matrix")
                if defined $owner_status && $owner_status eq 'excluded';
        } elsif ($verdict eq 'not-applicable') {
            # A misread archetype deletes assure-stage rows silently, and those
            # are the threat models and compliance records. Withhold them until
            # the archetype is confirmed.
            fail("documentation set marks the assure-stage row $id not-applicable while $archetype_low; confirm the archetype first")
                if $archetype_low && $stage eq 'assure';
            my ($predicate) = $detail =~ /revisit when[ \t]*:[ \t]*(.*)$/i;
            $predicate = defined $predicate ? $predicate : '';
            $predicate =~ s/[ \t]+$//;
            # An orphan exists but nothing justifies it: it gets a question, never a deletion task.
            if ($state =~ /^present-(?:current|drifted|stub)$/) {
                fail("documentation set row $id is an orphan but cites no ### Q<n> from ## Open Questions")
                    unless grep { $open_question{$_} } $detail =~ /\b(Q[1-9][0-9]*)\b/g;
            } else {
                if ($state eq 'unknown' || $state eq 'hint') {
                    fail("documentation set excludes $id on evidence state '$state'; only absent, by-design, or present-elsewhere may exclude");
                } elsif ($state !~ /^(?:absent|by-design|present-elsewhere)$/) {
                    fail("documentation set excludes $id without an evidence state; the cell must open with 'absent:', 'by-design:', or 'present-elsewhere:'");
                }
                if ($predicate eq '') {
                    fail("documentation set excludes $id without a revisit when: tripwire");
                } elsif (lc($predicate) =~ $vague_predicate) {
                    fail("documentation set excludes $id with a vague revisit when: predicate");
                } elsif (length($predicate) < 12) {
                    fail("documentation set excludes $id with a revisit when: predicate too short to observe");
                }
            }
        } elsif ($detail eq '') {
            fail("documentation set row $id is optional but says nothing about why");
        }
        push @json_documents, {
            id => $id,
            stage => $stage,
            verdict => $verdict,
            owner => $owner,
            durability => $durability,
            detail => $detail,
        };
    }
    fail("documentation set contains no catalog rows") unless $rows;
    fail("documentation set must state its boundary: the sentence that the manifest covers documentation committed to this repository")
        unless $boundary;
}

my $decisions_count = section_count('Decisions');

if ($decisions_count == 1) {
    my $current_decision;
    my %decision_line;
    my %decision_title;
    my %decision_falsifier;
    my %falsifier_field;
    for my $index (section('## Decisions')) {
        my $line = $lines[$index];
        if ($line =~ /^### (D[1-9][0-9]*):[ \t]*(\S.*)$/) {
            $current_decision = $1;
            fail("duplicate decision heading $current_decision")
                if exists $decision_line{$current_decision};
            $decision_line{$current_decision} = $index + 1;
            $decision_title{$current_decision} = $2;
            next;
        }
        # Any other heading would carry a decision past the falsifier check.
        if ($line =~ /^### /) {
            fail('malformed decision heading on line ' . ($index + 1) . '; use ### D<n>: <title> or ### Assumptions ledger')
                unless $line =~ /^### Assumptions ledger$/i;
            $current_decision = undef;
            next;
        }
        if (defined $current_decision && $line eq 'Falsifier:') {
            $decision_falsifier{$current_decision}++;
            next;
        }
        if (defined $current_decision
                && $line =~ /^- (Signal|Failure boundary|Replan action):[ \t]*(\S.*)$/) {
            my ($field, $value) = ($1, $2);
            fail("decision $current_decision has duplicate falsifier field $field")
                if exists $falsifier_field{$current_decision}{$field};
            $falsifier_field{$current_decision}{$field} = $value;
        }
    }
    fail("Decisions must contain at least one ### D<n>: entry")
        unless keys %decision_line;
    for my $decision (sort { substr($a, 1) <=> substr($b, 1) } keys %decision_line) {
        my $falsifier_count = $decision_falsifier{$decision} || 0;
        fail("decision $decision (line $decision_line{$decision}) is missing a Falsifier: block")
            if $falsifier_count == 0;
        fail("decision $decision has duplicate Falsifier: blocks")
            if $falsifier_count > 1;
        for my $field ('Signal', 'Failure boundary', 'Replan action') {
            fail("decision $decision Falsifier is missing $field")
                unless exists $falsifier_field{$decision}{$field};
        }
        if (exists $falsifier_field{$decision}{Signal}) {
            (my $signal = lc $falsifier_field{$decision}{Signal}) =~ s/^[^a-z0-9]+//;
            fail("decision $decision Signal is too vague to observe")
                if length($signal) < 12
                    || $signal =~ /^(?:metric|event|signal|performance|usage|something|tbd)\b/;
        }
        if (exists $falsifier_field{$decision}{'Failure boundary'}) {
            my $boundary = lc $falsifier_field{$decision}{'Failure boundary'};
            # An id such as D1, R-1.1, R-SEC-4, or GP-101 is not a threshold.
            (my $scan = $boundary) =~ s/\b(?:[dqa][1-9][0-9]*|gp-[0-9]+|r-[a-z0-9.-]*[0-9])\b//g;
            fail("decision $decision Failure boundary lacks an observable event or numeric threshold")
                if length($boundary) < 12
                    || $scan !~ /(?:[0-9]|exceed|below|above|unavailable|removed|reject|prohibit|deprecat|ship|cannot|breach|change|timeout|error)/;
        }
        if (exists $falsifier_field{$decision}{'Replan action'}) {
            my $action = lc $falsifier_field{$decision}{'Replan action'};
            fail("decision $decision Replan action must explicitly return to planning")
                if index($action, 'planning') < 0;
            fail("decision $decision Replan action must name what changes")
                if $action !~ /\b(?:replace|migrate|switch|evaluate|reconsider|redesign|split|merge|remove|adopt)\b/;
        }
        push @json_decisions, {
            id => $decision,
            title => $decision_title{$decision},
            falsifier => {
                signal => $falsifier_field{$decision}{Signal},
                failure_boundary => $falsifier_field{$decision}{'Failure boundary'},
                replan_action => $falsifier_field{$decision}{'Replan action'},
            },
        } if $falsifier_count == 1
            && exists $falsifier_field{$decision}{Signal}
            && exists $falsifier_field{$decision}{'Failure boundary'}
            && exists $falsifier_field{$decision}{'Replan action'};
    }
}

if (!@phases || $phases[-1]{name} ne 'Verification') {
    my $found = @phases ? $phases[-1]{name} : 'none';
    fail("final phase must be Verification, found '$found'");
}

if (@errors) {
    for my $error (@errors) {
        print STDERR "FAIL $plan_file: $error\n";
    }
    exit 1;
}

# A drift failure exits 1 like every other FAIL; 2 stays the usage code.
sub drift_fail {
    print STDERR "FAIL $plan_file: $_[0]\n";
    exit 1;
}

# A signal, or a shell that never started, is not an exit status.
sub rerun {
    my ($what, $command) = @_;
    system('sh', '-c', $command);
    drift_fail("$what " . ($? == -1 ? "could not start: $!"
        : $? & 127 ? 'was killed by signal ' . ($? & 127) : 'exited ' . ($? >> 8))) if $?;
}

if ($drift_phase ne '') {
    my ($phase) = grep { $_->{number} == $drift_phase } @phases;
    drift_fail("drift phase $drift_phase does not exist") unless defined $phase;
    my @completed = grep { $tasks[$_]{done} } @{$phase->{tasks}};
    drift_fail("drift phase $drift_phase is not complete") if @completed != @{$phase->{tasks}};

    for my $label (sort keys %recheck_inventory) {
        drift_fail('recheck inventory label intake is not a file path') if $label eq 'intake';
        open my $evidence_fh, '<:raw', $label
            or drift_fail("recheck evidence $label cannot be read: $!");
        local $/;
        my $bytes = <$evidence_fh>;
        close $evidence_fh;
        drift_fail("recheck evidence drifted: $label")
            if sha256_hex($bytes) ne $recheck_inventory{$label};
        print "recheck evidence ok: $label\n";
    }

    my @sample_positions;
    if (@completed <= 3) {
        @sample_positions = 0 .. $#completed;
    } else {
        @sample_positions = (0, int($#completed / 2), $#completed);
    }
    for my $position (@sample_positions) {
        my $task = $tasks[$completed[$position]];
        my ($command) = $task->{fields}{Verify}[0] =~ /^`(.*)`$/;
        print "drift sample $task->{id}: $command\n";
        rerun("drift sample $task->{id}", $command);
    }

    # A phase of superseded tasks did no work, so it has no outcome to reprove.
    if (@completed) {
        my $checkpoint = $phase->{checkpoint_verify};
        print "checkpoint Phase $drift_phase: $checkpoint\n";
        rerun("Phase $drift_phase checkpoint", $checkpoint);
    }
}

if ($emit_json ne '') {
    my @json_phases = map {
        {
            number => $_->{number} + 0,
            name   => $_->{name},
            tasks  => [ map { $tasks[$_]{id} } @{$_->{tasks}} ],
        }
    } @phases;

    my @json_tasks = map {
        my $task = $_;
        my @depends_on = dependency_ids($task);
        my @requirements = split /\s*,\s*/, $task->{fields}{Requirements}[0], -1;
        {
            id           => $task->{id},
            phase        => $phases[$task->{phase}]{number} + 0,
            wave         => $task->{wave},
            done         => $task->{done} ? JSON::PP::true : JSON::PP::false,
            parallel     => $task->{parallel} ? JSON::PP::true : JSON::PP::false,
            files        => $task->{fields}{Files}[0],
            depends_on   => \@depends_on,
            reuses       => $task->{fields}{Reuses}[0],
            acceptance   => $task->{fields}{Acceptance}[0],
            verify       => $task->{fields}{Verify}[0],
            requirements => \@requirements,
        }
    } @tasks;

    my %domain_history;
    my $record_domains = sub {
        my ($task, $status) = @_;
        return unless exists $task->{fields}{Requirements};
        my %seen;
        for my $requirement (split /\s*,\s*/, $task->{fields}{Requirements}[0], -1) {
            next unless $requirement =~ /^R-([A-Z][A-Z0-9-]*)-[0-9]+$/;
            my $domain = $prefix_module{$1};
            next unless defined $domain;
            next if $seen{$domain}++;
            $domain_history{$domain}{$status}++;
        }
    };
    $record_domains->($_, 'active') for @tasks;
    $record_domains->($_, 'superseded') for @superseded_tasks;

    my @json_superseded = map {
        my $requirements = exists $_->{fields}{Requirements}
            ? $_->{fields}{Requirements}[0] : '';
        {
            id => $_->{id},
            phase => $_->{phase} >= 0 ? $phases[$_->{phase}]{number} + 0 : undef,
            reason => exists $_->{fields}{Superseded}
                ? $_->{fields}{Superseded}[0] : '',
            requirements => $requirements eq ''
                ? [] : [ split /\s*,\s*/, $requirements, -1 ],
        }
    } @superseded_tasks;

    my @domain_metrics = map {
        my $domain = $_;
        my $active = $domain_history{$domain}{active} || 0;
        my $superseded = $domain_history{$domain}{superseded} || 0;
        my $historical = $active + $superseded;
        {
            domain => $domain,
            active => $active,
            superseded => $superseded,
            historical => $historical,
            supersession_rate => $historical
                ? 0 + sprintf('%.4f', $superseded / $historical) : 0,
        }
    } sort keys %domain_history;

    my $historical_tasks = scalar(@tasks) + scalar(@superseded_tasks);
    my $supersession_rate = $historical_tasks
        ? 0 + sprintf('%.4f', scalar(@superseded_tasks) / $historical_tasks) : 0;

    my @json_applicability = map {
        {
            domain => $_,
            status => $domain_disposition{$_},
            reason => $domain_reason{$_},
            evidence_state => defined $domain_evidence_state{$_}
                ? $domain_evidence_state{$_} : undef,
            revisit_when => defined $domain_revisit_when{$_}
                ? $domain_revisit_when{$_} : undef,
        }
    } sort keys %domain_disposition;

    my %document = (
        format          => 'godplans/plan-json@2',
        plan_digest     => 'sha256:' . sha256_hex($plan_bytes),
        name            => $frontmatter{name},
        plan_version    => $frontmatter{plan_version} + 0,
        status          => $frontmatter{status},
        created         => $frontmatter{created},
        updated         => $frontmatter{updated},
        mode            => $frontmatter{mode},
        product_form    => $frontmatter{product_form},
        archetype       => $frontmatter{archetype},
        archetype_confidence => $frontmatter{archetype_confidence},
        overlays        => \@overlays,
        public_release  => $frontmatter{public_release} eq 'true'
            ? JSON::PP::true : JSON::PP::false,
        source_revision => $frontmatter{source_revision},
        input_digest    => $frontmatter{input_digest},
        validated_at    => $frontmatter{validated_at},
        progress        => {
            phases_total => $counter{phases_total} + 0,
            phases_done  => $counter{phases_done} + 0,
            tasks_total  => $counter{tasks_total} + 0,
            tasks_done   => $counter{tasks_done} + 0,
        },
        applicability   => \@json_applicability,
        module_disposition => \@json_disposition,
        documentation   => \@json_documents,
        decisions       => \@json_decisions,
        phases          => \@json_phases,
        tasks           => \@json_tasks,
        superseded_tasks => \@json_superseded,
        metrics         => {
            task_history => {
                active => scalar @tasks,
                superseded => scalar @superseded_tasks,
                historical => $historical_tasks,
                supersession_rate => $supersession_rate,
                survival_rate => 0 + sprintf('%.4f', 1 - $supersession_rate),
            },
            domains => \@domain_metrics,
        },
    );

    my $json = JSON::PP->new->utf8->canonical(1)->pretty->encode(\%document);
    my $json_tmp = "$emit_json.tmp.$$";
    open my $json_fh, '>:raw', $json_tmp
        or die "FAIL $json_tmp: cannot write: $!\n";
    print {$json_fh} $json;
    close $json_fh;
    rename $json_tmp, $emit_json
        or die "FAIL $emit_json: cannot replace atomically: $!\n";
}

print "ok   $plan_file\n";
exit 0;
PERL
