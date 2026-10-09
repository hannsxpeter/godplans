# godplans behavioral evaluations

The repository linter proves that the skill package is internally consistent.
These cases test the separate product question: does an agent using godplans
produce the right kind of plan for a concrete request?

## Case matrix

| Case | Mode | Archetype | Primary risk tested |
|---|---|---|---|
| greenfield-saas | greenfield | saas-dashboard | tenancy, money, security, UX, operations |
| weekend-library | greenfield | library | scale calibration and domain exclusion |
| brownfield-cli | brownfield | cli-tool | real-file fingerprinting and reuse |
| replan-preserves-history | replan | cli-tool | stable completed work and new task IDs |
| compliance-refusal | hard stop | prohibited product | refusal before discovery or planning |
| product-form-routing | greenfield | ml-pipeline | primary data or ML form plus independent API form |
| nested-pillars | greenfield | not asserted (monorepo) | Pillars nested scopes, local catalog, and precedence |
| stale-source-evidence | brownfield | api-service | provenance binding and stale resume handling |
| stale-prepublication | greenfield | saas-dashboard | late Critical invalidates public-release authorization |
| observability-evidence | greenfield | api-service | installation evidence separated from real-event maturity |
| prose-integrity | greenfield | api-service | unsupported draft copy removed without losing concrete commitments |
| product-business | greenfield | saas-dashboard | pricing, entitlements, billing lifecycle, metric register, and the bet's kill criterion |

`evals/cases-roster.txt` lists every case. Adding a case means adding its
directory and one line in the roster; `scripts/eval-matrix.sh` refuses to run
when the two disagree, and `tests/eval-harness.sh` runs that check offline.

Every case contains:

- `REQUEST.md`: the user request and any case-specific setup, phrased for the
  skill arm (it names godplans and, for a plan case, asks for the
  `.godplans/` artifact set).
- `REQUEST.baseline.md`: the same task and constraints de-branded for the
  control arm, with no skill name, no `.godplans/` path, and no format demands.
- `EXPECTATIONS`: deterministic assertions over the response or PLAN.mdx.
- Optional `INPUT/`: a repository state the runner must copy into its isolated
  workspace before invoking the skill.

## Runner contract

Set `GODPLANS_EVAL_RUNNER` to an executable and run:

```bash
GODPLANS_EVAL_RUNNER=/absolute/path/to/runner bash scripts/eval.sh
```

Runners for the Codex CLI (`codex.sh`), Claude Code (`claude.sh`), and the
Gemini CLI (`gemini.sh`) are included, each with a `-baseline.sh` control
twin. Each reuses the authentication its host CLI already has; no provider API
keys are required. For example:

```bash
GODPLANS_EVAL_RUNNER="$PWD/evals/runners/codex.sh" bash scripts/eval.sh
```

Set `GODPLANS_EVAL_MODEL` or `GODPLANS_EVAL_REASONING_EFFORT` to override
the local Codex defaults (`GODPLANS_CLAUDE_MODEL`, `GODPLANS_CLAUDE_EFFORT`, and
`GODPLANS_GEMINI_MODEL` do the same for the other runners). Each runner
records the model, reasoning effort, CLI version, and the input, cached-input,
output, and total tokens its CLI reports in `RUNNER.txt`. `total_tokens` is
`input_tokens` plus `output_tokens`, and each family counts them differently.
Codex reports cached input inside `input_tokens`. The Claude runner adds
`cache_read_input_tokens` and `cache_creation_input_tokens` to Anthropic's
`input_tokens`, which excludes them, so its total compares with Codex. The
Gemini runner sums each model's `prompt` and `candidates` counts and does not
add the CLI's separate `thoughts` or `tool` counts.

The runner receives two arguments:

1. Absolute path to the case `REQUEST.md`. A control-arm runner
   (`GODPLANS_EVAL_BASELINE_RUNNER`, a profile's `<profile>-baseline.sh`, or
   `--control-plan-runner` in `scripts/eval-outcome.js`) receives the same path
   and must read the sibling `REQUEST.baseline.md` in its place when present,
   warning when it is absent, as `codex-baseline.sh` and `vendor-cli.sh` do.
2. Absolute output path. It ends in `PLAN.mdx` for plan cases and
   `RESPONSE.md` for refusal cases.

The runner is responsible for creating an isolated workspace, copying a
sibling `INPUT/` directory when present, invoking the target agent with the
request, and copying the resulting artifact to argument 2. For a plan case,
the runner retains the executable validator and generated `PLAN.json` beside
the plan. The harness requires the companion to be byte-identical to
`GODPLANS_VALIDATOR` and the sidecar digest to match PLAN.mdx. The runner
returns nonzero when the agent fails or an expected artifact is absent.

The runner must also isolate the agent from any globally installed skills.
Codex discovers skills in `$CODEX_HOME/skills` and `$HOME/.agents/skills`
independent of the workspace, so on a maintainer's machine (where godplans is
almost always installed globally) an unisolated runner loads the skill no
matter what, and the control arm ends up measuring godplans against itself.
`codex.sh` and `codex-baseline.sh` handle this by running Codex with a
throwaway `HOME` and a throwaway `CODEX_HOME` that carries only the copied
`auth.json` and `config.toml`, never a `skills/` directory. The skill arm then
links the project-local skill into its workspace; the control arm never does.
That single link is the only intended isolation difference between the two
arms (the request each arm reads differs as described under Control arm), and
the `tests/eval-harness.sh` regression asserts it.

The Claude and Gemini runners isolate differently and keep the host CLI's
existing authentication. The Claude runner uses `--safe-mode` (its skill arm
loads godplans through `--plugin-dir plugins/godplans`). The Gemini runner uses
workspace-scoped skill and hook settings: its skill arm copies the skill into
the workspace's `.agents/skills`, and its control arm writes a workspace
`.gemini/settings.json` that disables skills and hooks. Every planning runner
records its isolation mode in `RUNNER.txt` (`global_skills=isolated` for Codex,
`customization_mode` for Claude and Gemini). `tests/vendor-runner.sh` drives
the Claude and Gemini planning and judge runners with stand-in CLIs, so no
model is called, and asserts these flags and settings.

The Claude and Gemini runners also skip permission prompts
(`--dangerously-skip-permissions` and `--approval-mode yolo`) and are not
confined to the temporary workspace, which is only their starting directory.
Run them on a disposable machine or account. The Codex runners run with
`--sandbox workspace-write`.

`scripts/eval.sh` validates plan structure with the shipped plan validator,
then applies every semantic expectation. Outputs are retained under
`evals/output/<case>/` by default for inspection. CI runs `--check-cases` and
the harness regression tests without calling a model.

Rescore retained artifacts after expectation changes without another model
call:

```bash
bash scripts/eval.sh --score-only --output "$PWD/evals/output"
```

Score-only mode still rejects missing, non-executable, or drifted validator
companions, missing sidecars, and sidecar digest drift. Every run writes
`METRICS.json` with actual tokens per plan when the runner exposes usage. Use
`bash scripts/eval.sh --help` for case selection and output options.

## Control arm

Without a control, the matrix proves conformance and nothing more: every case
scores godplans against godplans' own expectations, so a pass shows the skill
did what it promised, not that the promise was worth loading. `--baseline`
adds the missing arm by running each case a second time through the same
agent, model, and reasoning effort with no skill available, then scoring that
output against the identical expectations.

```bash
GODPLANS_EVAL_RUNNER="$PWD/evals/runners/codex.sh" \
GODPLANS_EVAL_BASELINE_RUNNER="$PWD/evals/runners/codex-baseline.sh" \
bash scripts/eval.sh --baseline
```

Each case prints a `BASE` row with the control score and the delta, and the run
ends with an `AGGREGATE` row totaling both arms. The control arm is a
measurement and never a gate: its misses are the point, so they are not
reported as failures and cannot change the exit code. The release matrix still
requires every control run to produce a score (see Publishing a baseline).

A control arm only means something if it is fair, and the case `REQUEST.md`
files are not fair to it: they are written for the skill arm and say "Use
godplans" and "produce the godplans artifact set under `.godplans/`". Handing
that to a skill-less agent tells it to use a tool it does not have; in
practice the agent spends its whole turn searching for the skill's format and
writes nothing, so the delta measures "skill installed vs skill named but
absent" rather than the skill's value. Each case therefore ships a
`REQUEST.baseline.md`: the same task and constraints, de-branded, asking for a
plan at a neutral path. The control runners (`codex-baseline.sh`, and
`vendor-cli.sh` behind `claude-baseline.sh` and `gemini-baseline.sh`) read it
in place of `REQUEST.md`, hold the agent, model, reasoning effort, workspace,
and `INPUT/` fixture identical to the skill arm, and leak nothing from the
skill (no godplans name, no `.godplans` path, no format contract, requirement
IDs, validator, or phase method; a replan case's `INPUT/` fixture is the prior
plan both arms must reconcile, so it is the one exception).
`scripts/eval.sh --check-cases` rejects a `REQUEST.baseline.md` that names
godplans, `SKILL.md`, `PLAN.mdx`, or the validator companion, and `RUNNER.txt`
records `prompt=neutral-baseline-request` so a published run proves the
control was fair. If a case lacks a baseline request the runner warns, falls
back to the skill-phrased `REQUEST.md`, and records
`prompt=fallback-skill-phrased-request-UNFAIR`; that run is explicitly not a
fair comparison. The control runners take the `PLAN.md` the neutral request
names before any other plan path, and never take an `INPUT/` file the control
left unchanged as its plan. When the control produces no plan at all, its
final response is scored instead and the assertions fail honestly rather than
being hidden as a runner error.

Expect the control to win some assertions outright. Any case where it scores
near the skill arm is a case whose expectations test formatting rather than
planning quality, and it should be tightened.

## Expectation grammar

Each non-comment line is pipe-delimited:

```text
outcome|plan|
frontmatter|mode|greenfield
domain|database|applicable
contains|workspace_id|
contains-ci|usage policy|
not-contains|PLACEHOLDER|
max-count|## Open Questions|1
gate|prepublication|hardening_revision
```

Supported operations are `outcome`, `frontmatter`, `domain`, `contains`,
`contains-ci`, `not-contains`, `max-count`, and `gate`. `outcome|plan|` runs
the shipped validator with `--allow-planning`; `outcome|refusal|` credits any
non-empty response, and the harness separately fails a refusal case that left
a `PLAN.mdx`. `frontmatter|KEY|VALUE` matches a whole `KEY: VALUE` line and
`domain|NAME|STATUS` the start of an applicability-matrix row; both read their
second and third fields as extended regular expressions, so
`frontmatter|domains_deferred|\[[^]]*\]` accepts any inline list. `contains`,
`contains-ci`, `not-contains`, `max-count`, and `gate` compare fixed strings.
`contains-ci` performs a case-insensitive fixed-string check, and `max-count`
passes when at most the given number of lines contain its string. `gate` names
a release-blocking invariant in its second field and requires the fixed string
in its third field. A case passes only when every line passes, so a missing
gate fails the case like any other miss; the gate name records which invariant
broke. An empty or missing artifact passes only its `not-contains` lines.
Every case declares exactly one outcome.

## Publishing a baseline

Release evidence requires the full matrix, every case in
`evals/cases-roster.txt`, across at least three model families, with both arms
for every case. This is optional maintainer tooling, not part of skill
execution:

```bash
bash scripts/eval-matrix.sh --output "$PWD/evals/results/RUN-ID"
```

The default profiles are Codex, Claude, and Gemini. Each adapter uses the
normal authentication already managed by its host CLI. Neither godplans nor
the coordinator requires, reads, or prescribes provider credentials. A host that
does not have all three CLIs can supply three alternative runner profiles
through the same runner contract (set `GODPLANS_MATRIX_PROFILES`; each profile
needs `evals/runners/<profile>.sh` and `evals/runners/<profile>-baseline.sh`).
The command refuses to run when the case directories under `evals/cases/` and
`evals/cases-roster.txt` differ in either direction, when a listed case lacks
`REQUEST.md`, `REQUEST.baseline.md`, or `EXPECTATIONS`, or when fewer than
three profiles are given; `bash scripts/eval-matrix.sh --check` runs those
checks without calling a model. After the run, a family that lacks a scored
skill or control arm for any case (a runner error, missing artifacts, or a
`BASE runner-error` row) fails the matrix and leaves no `MATRIX.md` or
`MATRIX.json`; the other families still run. Commit `MATRIX.md`,
`MATRIX.json`, every family's `EVAL.tsv` and `METRICS.json`, all generated
plans and sidecars, all control plans, runner metadata, and CLI event logs
together. A summary without raw artifacts is not publishable evidence.

Never publish a skill score without the control score beside it. Each case is
still one sample, so repeat runs and report spread before treating a delta as
a stable measurement. The historical 1.8.0 three-case Codex baseline remains
under `evals/baselines/` as provenance, but it does not meet the current
publication minimum.

## External anchor

Internal expectations still descend from the product's own contracts. The
blind external grader uses six criteria that contain no sibling-skill ids:
decision completeness, falsifiability, execution actionability, risk targeting,
proportionality, and internal consistency. Run at least five plan pairs through
at least two isolated judges and publish the inter-rater gap:

```bash
node scripts/eval-external.js \
  --matrix evals/results/RUN-ID \
  --source-profile codex \
  --judge claude=evals/runners/claude-grade.sh \
  --judge gemini=evals/runners/gemini-grade.sh \
  --output evals/external/results/RUN-ID
```

See `evals/external/README.md`. Judges receive arm labels A and B only, run
with skills disabled by the host adapter, and are unblinded after every raw
grade exists.

## Build outcome

Plan conformance is not the marketing thesis. `evals/outcomes/` adds the causal
test: matched treatment and control plans go to the same fresh no-skill builder,
then the input plan and arm identity are removed and the same fresh static
godaudits pass audits both repositories. `SUMMARY.json` compares verifier
status, active (open or accepted-risk) Critical plus High findings, and
runner-reported plan and build tokens. The first published directional run,
which measured godplans 1.9.0 on 2026-07-23, found a -4 Critical plus High
delta for treatment on `tenant-notes-api`, with both verifiers passing. It also
found a 69.01 times planning-token cost versus control. No later version has
been re-measured, so these numbers are historical, not a measurement of the
current skill. See
`evals/outcomes/README.md` and the retained result under
`evals/outcomes/results/2026-07-23-tenant-notes-api-codex/`.

## Context cost

`evals/metrics/context-cost.json` publishes the native entry, portable core,
generated full prompt, and per-module byte and estimated-token costs. The
estimate is explicitly a byte-based approximation. Model-backed runs publish
actual token usage in their `RUNNER.txt` and aggregate `METRICS.json`; actual
tokens per plan are the release metric.
