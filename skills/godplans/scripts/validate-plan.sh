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
use JSON::PP ();

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

sub task_has_requirement {
    my ($task, $requirement_id) = @_;
    return 0 unless exists $task->{fields}{Requirements};
    return 0 unless @{$task->{fields}{Requirements}} == 1;
    my @requirement_ids = split /\s*,\s*/, $task->{fields}{Requirements}[0], -1;
    return scalar grep { $_ eq $requirement_id } @requirement_ids;
}

sub task_depends_on {
    my ($task, $task_id) = @_;
    return 0 unless exists $task->{fields}{'Depends on'};
    return 0 unless @{$task->{fields}{'Depends on'}} == 1;
    my @dependencies = split /\s*,\s*/, $task->{fields}{'Depends on'}[0], -1;
    return scalar grep { $_ eq $task_id } @dependencies;
}

open my $plan_fh, '<:encoding(UTF-8)', $plan_file
    or die "FAIL $plan_file: cannot read: $!\n";
my @lines = <$plan_fh>;
close $plan_fh;
chomp @lines;
for (@lines) {
    s/\r$//;
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

my %frontmatter;
my %counter;
my %top_key_count;
my $has_progress = 0;
if ($frontmatter_end > 0) {
    for my $index (1 .. $frontmatter_end - 1) {
        my $line = $lines[$index];
        if ($line =~ /^([a-z_]+):(?:[ \t]*(.*))?$/) {
            my ($key, $value) = ($1, trim($2));
            $top_key_count{$key}++;
            $frontmatter{$key} = $value;
            $has_progress = 1 if $key eq 'progress';
        } elsif ($line =~ /^  (phases_total|phases_done|tasks_total|tasks_done):[ \t]*(.*)$/) {
            my ($key, $value) = ($1, trim($2));
            fail("duplicate progress counter: $key") if exists $counter{$key};
            $counter{$key} = $value;
        }
    }
}

for my $key (qw(name plan_version status created updated mode product_form archetype public_release source_revision input_digest validated_at domains_applicable domains_deferred domains_excluded)) {
    if (!exists $frontmatter{$key}) {
        fail("missing frontmatter field: $key");
    } elsif ($frontmatter{$key} eq '' && $key ne 'domains_excluded') {
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

for my $key (qw(phases_total phases_done tasks_total tasks_done)) {
    if (!exists $counter{$key}) {
        fail("missing progress counter: $key");
    } elsif ($counter{$key} !~ /^[0-9]+$/) {
        fail("progress counter $key must be a non-negative integer, found '$counter{$key}'");
    }
}

my $in_requirements = 0;
my %local_requirements;
for my $line (@lines) {
    if ($line eq '## Requirements') {
        $in_requirements = 1;
        next;
    }
    if ($in_requirements && $line =~ /^## /) {
        $in_requirements = 0;
    }
    if ($in_requirements && $line =~ /^(R-[0-9]+\.[0-9]+):/) {
        $local_requirements{$1} = 1;
    } elsif ($in_requirements && $line =~ /^\|\s*(R-[0-9]+\.[0-9]+)\s*\|/) {
        $local_requirements{$1} = 1;
    }
}

my %catalog_max = (
    ARCH => 20,
    BUILD => 20,
    CODE => 24,
    DB => 23,
    DEPLOY => 18,
    DNA => 20,
    LAUNCH => 22,
    LLM => 23,
    MEM => 22,
    OBS => 21,
    PRD => 17,
    REPO => 21,
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
            checkpoint => undef,
            checkpoint_verify => undef,
        };
        $current_phase = $#phases;
        next;
    }

    if ($line =~ /^- \[([ x])\] (GP-[1-9][0-9]{2,})\b/) {
        my ($box, $id) = ($1, $2);
        my ($wave_phase, $wave_tag, $parallel);
        if ($line =~ /^- \[[ x]\] \Q$id\E (\[P\] )?\[W([1-9][0-9]*)\.([1-9][0-9]*)\] \S/) {
            $parallel = defined $1 ? 1 : 0;
            $wave_phase = $2;
            $wave_tag = "W$2.$3";
        } else {
            fail("$id has malformed task heading");
        }
        my $task = {
            id => $id,
            done => $box eq 'x' ? 1 : 0,
            fields => {},
            line => $index + 1,
            phase => $current_phase,
            wave => $wave_tag,
            parallel => $parallel ? 1 : 0,
        };
        push @tasks, $task;
        push @{$phases[$current_phase]{tasks}}, $#tasks if $current_phase >= 0;
        fail("$id is not inside a numbered phase") if $current_phase < 0;
        if (defined $wave_phase && $current_phase >= 0
                && $wave_phase != $phases[$current_phase]{number}) {
            fail("$id wave phase $wave_phase does not match Phase $phases[$current_phase]{number}");
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

        for (my $field_index = $index + 1; $field_index <= $#lines; $field_index++) {
            my $field_line = $lines[$field_index];
            last if $field_line =~ /^(?:~~)?- \[[ x]\] GP-/;
            last if $field_line =~ /^## Phase [1-9][0-9]*:/;
            if ($field_line =~ /^  - (Files|Depends on|Reuses|Acceptance|Verify|Requirements):[ \t]*(.*)$/) {
                push @{$task->{fields}{$1}}, trim($2);
            }
        }
    } elsif ($line =~ /^~~- \[([ x])\] (GP-[1-9][0-9]{2,})\b.*~~$/) {
        my ($box, $id) = ($1, $2);
        my $task = {
            id => $id,
            done => $box eq 'x' ? 1 : 0,
            fields => {},
            line => $index + 1,
            phase => $current_phase,
        };
        fail("superseded task $id must remain unchecked") if $box eq 'x';
        if (exists $all_task_definitions{$id}) {
            fail("duplicate historical task ID $id on lines $all_task_definitions{$id} and " . ($index + 1));
        } else {
            $all_task_definitions{$id} = $index + 1;
        }
        for (my $field_index = $index + 1; $field_index <= $#lines; $field_index++) {
            my $field_line = $lines[$field_index];
            last if $field_line =~ /^(?:~~)?- \[[ x]\] GP-/;
            last if $field_line =~ /^## Phase [1-9][0-9]*:/;
            if ($field_line =~ /^  - (Superseded|Requirements):[ \t]*(.*)$/) {
                push @{$task->{fields}{$1}}, trim($2);
            }
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
    } elsif ($line =~ /^- \[[^]]*\] GP-/) {
        fail('malformed task definition on line ' . ($index + 1));
    } elsif ($current_phase >= 0 && $line =~ /^Checkpoint:[ \t]*(\S.*)$/) {
        fail("Phase $phases[$current_phase]{number} has duplicate Checkpoint")
            if defined $phases[$current_phase]{checkpoint};
        $phases[$current_phase]{checkpoint} = $1;
    } elsif ($current_phase >= 0 && $line =~ /^Checkpoint verify:[ \t]*`([^`]+)`[ \t]*$/) {
        fail("Phase $phases[$current_phase]{number} has duplicate Checkpoint verify")
            if defined $phases[$current_phase]{checkpoint_verify};
        $phases[$current_phase]{checkpoint_verify} = $1;
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
        my $verify = $task->{fields}{Verify}[0];
        fail("$task->{id} Verify must be one executable command in backticks")
            if $verify !~ /^`[^`]+`$/ || $verify =~ /^`[Mm]anual:/;
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

my %task_files;
for my $task_index (0 .. $#tasks) {
    my $task = $tasks[$task_index];
    next unless exists $task->{fields}{Files} && @{$task->{fields}{Files}} == 1;
    my %paths;
    for my $path (split /\s*,\s*/, $task->{fields}{Files}[0], -1) {
        $path = trim($path);
        next if $path eq '' || $path =~ /^none\b/i;
        $path =~ s{^\./}{};
        $paths{$path} = 1;
    }
    $task_files{$task_index} = \%paths;
}

for my $wave (sort keys %wave_members) {
    my @members = @{$wave_members{$wave}};
    for my $left (0 .. $#members) {
        for my $right ($left + 1 .. $#members) {
            my ($first, $second) = ($members[$left], $members[$right]);
            next unless $tasks[$first]{parallel} || $tasks[$second]{parallel};
            next unless exists $task_files{$first} && exists $task_files{$second};
            my @shared = sort grep { exists $task_files{$second}{$_} }
                keys %{$task_files{$first}};
            next unless @shared;
            fail("$tasks[$first]{id} and $tasks[$second]{id} are both in $wave"
                . " and one is marked [P], but they share "
                . join(', ', @shared));
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
    if (!@{$phase->{tasks}}) {
        fail("Phase $phase->{number} has no task definitions");
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

my $open_questions_count = scalar grep { $_ eq '## Open Questions' } @lines;
fail("expected exactly one ## Open Questions section, found $open_questions_count")
    if $open_questions_count != 1;

my $provenance_count = scalar grep { $_ eq '## Plan provenance' } @lines;
fail("expected exactly one ## Plan provenance section, found $provenance_count")
    if $provenance_count != 1;

my $product_form_count = scalar grep { $_ eq '## Product form' } @lines;
fail("expected exactly one ## Product form section, found $product_form_count")
    if $product_form_count != 1;

if ($provenance_count == 1) {
    my $inside = 0;
    my @body;
    for my $line (@lines) {
        if ($line eq '## Plan provenance') {
            $inside = 1;
            next;
        }
        last if $inside && $line =~ /^## /;
        push @body, $line if $inside;
    }

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
                && $line =~ /^- (\[recheck\] )?`([A-Za-z0-9][A-Za-z0-9._\/-]*)` = `sha256:([0-9a-f]{64})`$/) {
            my ($recheck, $label, $digest) = ($1, $2, $3);
            $inventory_count++;
            if (exists $inventory{$label}) {
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
    product architecture stack database security llm ux ui seo code-quality
    style-genome agent-memory repo build roadmap deploy observe launch
);
my %allowed_disposition = map { $_ => 1 } qw(applicable deferred excluded);
my %deferrable_domain = map { $_ => 1 } qw(seo launch observe ui deploy);
my $matrix_count = scalar grep { $_ eq '## Applicability matrix' } @lines;
fail("expected exactly one ## Applicability matrix section, found $matrix_count")
    if $matrix_count != 1;

if ($matrix_count == 1) {
    my $inside = 0;
    my %seen_domain;
    for my $line (@lines) {
        if ($line eq '## Applicability matrix') {
            $inside = 1;
            next;
        }
        last if $inside && $line =~ /^## /;
        next unless $inside;
        next unless $line =~ /^\|[ \t]*([a-z0-9-]+)[ \t]*\|[ \t]*([a-z0-9-]+)[ \t]*\|[ \t]*(.*?)[ \t]*\|[ \t]*$/;
        my ($domain, $disposition, $reason) = ($1, $2, $3);
        next unless $known_domain{$domain};
        fail("applicability matrix has a duplicate row for $domain")
            if $seen_domain{$domain}++;
        if (!$allowed_disposition{$disposition}) {
            fail("applicability matrix row for $domain has invalid status '$disposition'; expected applicable, deferred, or excluded");
            next;
        }
        if ($disposition eq 'excluded' && $reason eq '') {
            fail("applicability matrix excludes $domain without a reason");
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

my $decisions_count = scalar grep { $_ eq '## Decisions' } @lines;
fail("expected exactly one ## Decisions section, found $decisions_count")
    if $decisions_count != 1;

if ($decisions_count == 1) {
    my $inside = 0;
    my $current_decision;
    my %decision_line;
    my %decision_title;
    my %decision_falsifier;
    my %falsifier_field;
    for (my $index = 0; $index <= $#lines; $index++) {
        my $line = $lines[$index];
        if ($line eq '## Decisions') {
            $inside = 1;
            next;
        }
        last if $inside && $line =~ /^## /;
        next unless $inside;
        if ($line =~ /^### (D[1-9][0-9]*):[ \t]*(\S.*)$/) {
            $current_decision = $1;
            fail("duplicate decision heading $current_decision")
                if exists $decision_line{$current_decision};
            $decision_line{$current_decision} = $index + 1;
            $decision_title{$current_decision} = $2;
            next;
        }
        if ($line =~ /^### D[1-9][0-9]*/) {
            fail("malformed decision heading on line " . ($index + 1));
            $current_decision = undef;
            next;
        }
        if ($line =~ /^### /) {
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
    for my $decision (sort keys %decision_line) {
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
            my $signal = lc $falsifier_field{$decision}{Signal};
            fail("decision $decision Signal is too vague to observe")
                if length($signal) < 12
                    || $signal =~ /^(?:metric|event|signal|performance|usage|something|tbd)\b/;
        }
        if (exists $falsifier_field{$decision}{'Failure boundary'}) {
            my $boundary = lc $falsifier_field{$decision}{'Failure boundary'};
            fail("decision $decision Failure boundary lacks an observable event or numeric threshold")
                if length($boundary) < 12
                    || $boundary !~ /(?:[0-9]|exceed|below|above|unavailable|removed|reject|prohibit|deprecat|ship|cannot|breach|change|timeout|error)/;
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

for my $index (0 .. $#lines) {
    if ($lines[$index] =~ /[\x{2013}\x{2014}\x{2018}-\x{201F}\x{2026}\x{2190}-\x{21FF}\x{2500}-\x{257F}\x{FE0F}\x{1F000}-\x{1FAFF}]/) {
        fail('banned Unicode on line ' . ($index + 1));
    }
}

if (@errors) {
    for my $error (@errors) {
        print STDERR "FAIL $plan_file: $error\n";
    }
    exit 1;
}

if ($drift_phase ne '') {
    my ($phase) = grep { $_->{number} == $drift_phase } @phases;
    if (!defined $phase) {
        die "FAIL $plan_file: drift phase $drift_phase does not exist\n";
    }
    my @completed = grep { $tasks[$_]{done} } @{$phase->{tasks}};
    if (@completed != @{$phase->{tasks}}) {
        die "FAIL $plan_file: drift phase $drift_phase is not complete\n";
    }

    for my $label (sort keys %recheck_inventory) {
        if ($label eq 'intake') {
            die "FAIL $plan_file: recheck inventory label intake is not a file path\n";
        }
        open my $evidence_fh, '<:raw', $label
            or die "FAIL $plan_file: recheck evidence $label cannot be read: $!\n";
        local $/;
        my $bytes = <$evidence_fh>;
        close $evidence_fh;
        my $actual = sha256_hex($bytes);
        if ($actual ne $recheck_inventory{$label}) {
            die "FAIL $plan_file: recheck evidence drifted: $label\n";
        }
        print "recheck evidence ok: $label\n";
    }

    my @sample_positions;
    if (@completed <= 3) {
        @sample_positions = 0 .. $#completed;
    } else {
        @sample_positions = (0, int($#completed / 2), $#completed);
    }
    my %sample_seen;
    for my $position (@sample_positions) {
        my $task = $tasks[$completed[$position]];
        next if $sample_seen{$task->{id}}++;
        my $verify = $task->{fields}{Verify}[0];
        if ($verify !~ /^`([^`]+)`$/) {
            die "FAIL $plan_file: drift sample $task->{id} Verify must be one executable command in backticks\n";
        }
        my $command = $1;
        print "drift sample $task->{id}: $command\n";
        system('sh', '-c', $command);
        if ($? != 0) {
            my $status = $? >> 8;
            die "FAIL $plan_file: drift sample $task->{id} exited $status\n";
        }
    }

    my $checkpoint = $phase->{checkpoint_verify};
    print "checkpoint Phase $drift_phase: $checkpoint\n";
    system('sh', '-c', $checkpoint);
    if ($? != 0) {
        my $status = $? >> 8;
        die "FAIL $plan_file: Phase $drift_phase checkpoint exited $status\n";
    }
}

if ($emit_json ne '') {
    open my $raw_fh, '<:raw', $plan_file
        or die "FAIL $plan_file: cannot read for digest: $!\n";
    local $/;
    my $raw_bytes = <$raw_fh>;
    close $raw_fh;

    my @json_phases = map {
        {
            number => $_->{number} + 0,
            name   => $_->{name},
            tasks  => [ map { $tasks[$_]{id} } @{$_->{tasks}} ],
        }
    } @phases;

    my @json_tasks = map {
        my $task = $_;
        my $depends = $task->{fields}{'Depends on'}[0];
        my @depends_on = $depends eq 'none' ? () : split /\s*,\s*/, $depends, -1;
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

    my %requirement_domain = (
        PRD => 'product',
        ARCH => 'architecture',
        STACK => 'stack',
        DB => 'database',
        SEC => 'security',
        LLM => 'llm',
        UX => 'ux',
        UI => 'ui',
        SEO => 'seo',
        CODE => 'code-quality',
        DNA => 'style-genome',
        MEM => 'agent-memory',
        REPO => 'repo',
        BUILD => 'build',
        ROAD => 'roadmap',
        DEPLOY => 'deploy',
        OBS => 'observe',
        LAUNCH => 'launch',
    );
    my %domain_history;
    my $record_domains = sub {
        my ($task, $status) = @_;
        return unless exists $task->{fields}{Requirements};
        my %seen;
        for my $requirement (split /\s*,\s*/, $task->{fields}{Requirements}[0], -1) {
            next unless $requirement =~ /^R-([A-Z][A-Z0-9-]*)-[0-9]+$/;
            my $domain = $requirement_domain{$1};
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
        }
    } sort keys %domain_disposition;

    my %document = (
        format          => 'godplans/plan-json@1',
        plan_digest     => 'sha256:' . sha256_hex($raw_bytes),
        name            => $frontmatter{name},
        plan_version    => $frontmatter{plan_version} + 0,
        status          => $frontmatter{status},
        created         => $frontmatter{created},
        updated         => $frontmatter{updated},
        mode            => $frontmatter{mode},
        product_form    => $frontmatter{product_form},
        archetype       => $frontmatter{archetype},
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

    my $json = JSON::PP->new->canonical(1)->pretty->encode(\%document);
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
