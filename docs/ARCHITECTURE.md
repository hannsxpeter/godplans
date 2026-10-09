# Architecture

How godplans is put together: which files are sources, which are generated from them, and which check fails when a generated file falls behind its source. For maintainer rituals (the version model, adding a domain module, the prompt budget, dated facts), see [MAINTAINING.md](../MAINTAINING.md). For the inconsistencies these checks were built to stop, see [DRIFT.md](DRIFT.md).

## Contents

1. The shape of the product
2. The pieces
3. How a planning run uses them
4. The validator and its embedded catalogs
5. Two ways to ship the same skill
6. Derived artifacts and the checks that catch staleness
7. Evaluation layers
8. The platform contract

## 1. The shape of the product

godplans ships instructions, not an application. An agent reads an orchestrator and reference modules, fills a template, and runs a few scripts. One script carries most of the weight: the validator. It is copied beside every plan, and it must keep working after the plan leaves the skill behind, with no access to the installed skill, on stock macOS and Linux.

The rest of the repository does one of two jobs. Generators build derived views of the sources: the portable prompt, the context metrics, and the catalogs embedded in the validator. Checks confirm that those views, and the lists maintainers keep by hand, still agree with their sources.

## 2. The pieces

| Piece | Where | Loaded or run | What it does |
|---|---|---|---|
| Orchestrator | `skills/godplans/SKILL.md` | loaded when the skill activates | ground rules, the nine-phase method, the greenfield, brownfield, and replan modes, refusals, and the file map |
| Domain modules (19) | `skills/godplans/references/<domain>.md` | read at that domain's Phase 4 pass, and only when the applicability matrix marks the domain applicable | six sections each: Lineage, Decisions to force, Plan requirements (`R-<PREFIX>-N`), Task seeds, Self-audit rubric, Anti-patterns refused |
| Contract modules (5) | `references/plan-format.md`, `discovery.md`, `compliance.md`, `exemplar.md`, `doc-set.md` | read at the phase that names them | the PLAN.mdx contract, intake and the applicability matrix, the usage-policy gate, the quality bar and prose-integrity gate, and the documentation-set catalog; exempt from the six-section contract |
| PLAN template | `skills/godplans/templates/PLAN.template.mdx` | read in Phase 7 | the PLAN.mdx skeleton, including one applicability-matrix row per domain |
| Validator | `skills/godplans/scripts/validate-plan.sh` | copied to `.godplans/validate-plan.sh` in Phase 1, re-copied and run in Phase 7, then run by executors | the structural and execution gate; emits the PLAN.json sidecar |
| Plan half-life | `skills/godplans/scripts/plan-halflife.sh` | run in Phase 0 of a replan | writes `.godplans/PLAN.metrics.json`: cumulative task survival and per-domain supersession, measured with `GODPLANS_VALIDATOR`, else the plan's own `.godplans/validate-plan.sh`, else the copy beside the script |
| Style statistics | `skills/godplans/scripts/style-stats.py` | run during a brownfield Phase 0 fingerprint; copied in Phase 7 to `.godplans/style-stats.py` when a planned task runs it (the R-DNA-21 confirming run) | naming histograms, comment density, and function length for the style-genome pass; standard-library Python vendored by copy from hannsxpeter/codedna |
| Sidecar schema | `skills/godplans/schemas/PLAN.schema.json` | read by PLAN.json consumers and by the test suite | the published JSON Schema for the generated PLAN.json (`format: godplans/plan-json@2`); `PLAN.v1.schema.json` beside it covers the `@1` sidecars that 1.13.0 and earlier emitted |
| Portable core | `PROMPT.md` (generated, committed) | pasted or attached in tools with no Agent Skills support | SKILL.md plus the core modules, the template, the validator, and the half-life script in one file; it names the lazy modules to attach on demand |
| Full prompt | `PROMPT.full.md` (generated, gitignored) | a one-off build | every module inlined |
| Installer | `install.sh` | run by a user | links or copies the skill into six destinations |
| Projections | `.agents/skills/godplans`, `.claude/skills/godplans`, `plugins/godplans/skills` | symlinks | the first two point at `skills/godplans`, the plugin one at `skills` |
| Plugin metadata | `plugins/godplans/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` | read by the Claude Code plugin system | `plugin.json` and the marketplace's godplans entry carry the SKILL.md description verbatim; the marketplace tagline (`metadata.description`) carries the package.json description |

### The nine phases

SKILL.md runs Phase 0 (Orient), 1 (Compliance gate), 2 (Intake and applicability), 3 (Discovery), 4 (Domain passes), 5 (Inversion pass), 5b (Prose integrity pass), 6 (Independent audit gate), and 7 (Emit and hand off), in that order. A phase that does not apply still gets a one-line disposition.

### Core and lazy modules

The split exists only for the portable prompt. A native install reads every module from disk at the phase that needs it.

- **Core, inlined in PROMPT.md in this order:** compliance, discovery, product, architecture, stack, database, security, exemplar, plan-format.
- **Lazy, attached only when needed:** doc-set (a contract the repo pass needs), plus fourteen domain modules: business, llm, ux, ui, seo, code-quality, style-genome, agent-memory, repo, build, roadmap, deploy, observe, launch.

The core holds the contracts every run needs and the five load-bearing domains that decide hard-to-reverse shape. A lazy module waits until the applicability matrix says it applies. Inlining every module would charge its full context cost before applicability is known (see the header of `scripts/build-prompt.sh`).

## 3. How a planning run uses them

1. **Phase 0** detects the mode. A replan measures the outgoing plan with `plan-halflife.sh` here, while `.godplans/validate-plan.sh` is still that plan's own validator. A brownfield run runs `style-stats.py` and close-reads the source. Every run binds the plan to disk evidence: the Git revision, an evidence inventory, and a SHA-256 input digest.
2. **Phase 1** screens the project against `compliance.md`. A hard stop writes nothing. Otherwise it creates `.godplans/` and copies the validator there byte for byte, before any plan text exists.
3. **Phases 2 and 3** read `discovery.md`. They fix the product form, the scored archetype, the overlays, an applicability matrix with one row per domain, and the scale, then ask one batch of three to five questions, each with a default.
4. **Phases 4 to 6** author each applicable domain from its module, give every requirement a disposition, run the prose-integrity gate from `exemplar.md`, and score the draft under critic posture against each module's rubric.
5. **Phase 7** assembles PLAN.mdx from `plan-format.md` and the template. It re-copies the validator, compares the copy with `cmp -s`, and runs it with `--allow-planning --emit-json`. Emission is complete only when PLAN.mdx, the executable companion, and PLAN.json all exist. When a planned task runs `.godplans/style-stats.py`, Phase 7 also copies `style-stats.py` there, outside that gate.

After approval, the plan, its companion, and any `.godplans/style-stats.py` copy are self-sufficient. An executor needs neither godplans nor this repository.

## 4. The validator and its embedded catalogs

`validate-plan.sh` is one Bash file that runs an embedded Perl program. Bash 3.2 and the Perl that ships with macOS are enough. It reads no skill file at run time, so everything it checks against lives inside it:

| Table | Kept by | Holds |
|---|---|---|
| `%catalog_max` | `scripts/build-catalog.js` | the highest requirement number per prefix; with `BIZ => 26`, a task citing `R-BIZ-27` fails |
| `%doc_catalog` | `scripts/build-catalog.js` | every documentation-set id with its owner module and durability |
| `%known_domain` | hand | the domains the applicability matrix must list, each exactly once |
| `%module_prefix` | hand | each domain's requirement prefix; `%prefix_module` is derived from it with `reverse` |
| `%deferrable_domain` | hand | the domains that may defer: seo, launch, observe, ui, deploy |
| `%never_excludable` | hand | the domains that scale down and never leave the plan: security, code-quality, style-genome, repo, roadmap |
| `%overlay_domains` | hand | the seven overlays and the domains each one forbids excluding |
| `@archetypes`, `%allowed_archetype` | hand | the nine archetypes `discovery.md` scores; the frontmatter `archetype` may also be `unknown`. The `plan-format.md` frontmatter rules and the `PLAN.schema.json` enum repeat the list, and `tests/validate-plan.sh` ("archetype list matches discovery.md") fails when any of the four copies differs |

Modes:

- `--allow-planning` validates a draft or closed plan. Without it, the validator is also an execution gate and accepts only `approved` or `executing`.
- `--emit-json PATH` writes the PLAN.json sidecar as UTF-8. The sidecar is derived and never hand-edited, and its `plan_digest` lets a consumer detect that the plan changed after the sidecar was written.
- `--drift-check N` rechecks the digests of evidence marked `[recheck]`, then reruns up to three sampled Verify commands from completed phase N and that phase's Checkpoint verify, each through `sh -c`. Those commands come from PLAN.mdx, so drift mode runs whatever the plan says. Review a plan diff before running it.

A plan written before a domain existed fails with "applicability matrix is missing domain <name>". Replan mode treats that failure as a delta to add, not as an error in the plan.

`tests/validate-plan.sh` is the regression suite. It also checks every sidecar it emits against `PLAN.schema.json` with `tests/lib/plan-schema-check.js`, a dependency-free checker that refuses any schema keyword it does not implement. It walks the whole schema before reading any document, so a keyword under an optional property counts too, and it also checks `PLAN.v1.schema.json` against the retained 1.9.0 evaluation sidecar and a real 1.13.0 sidecar in `tests/fixtures/`. A schema change that relies on an unchecked keyword therefore fails the suite instead of passing unchecked.

## 5. Two ways to ship the same skill

**Native.** `install.sh` installs into six destinations: agents (`~/.agents/skills` or `<project>/.agents/skills`), claude, factory, cline, windsurf, and copilot-cloud. Tool names such as codex, cursor, gemini, kilo, and goose map onto the agents path. It symlinks by default. `--copy` copies instead and strips Python bytecode from the copy. A marker records each destination the installer created, so `--uninstall` removes only those, and an unowned destination is never replaced or removed without `--force`. `npx skills add hannsxpeter/godplans` and the Claude Code plugin (`plugins/godplans`, whose `skills` entry is the projection symlink) reach the same canonical directory.

**Portable.** `scripts/build-prompt.sh` writes PROMPT.md. It strips the SKILL.md frontmatter and the File map section, rewrites repository paths that point at inlined content (for example, to "the inlined validator"), and rewrites the half-life command to `bash .godplans/plan-halflife.sh ...`. The header tells the reader to write the inlined validator to `.godplans/validate-plan.sh` and to save that script beside it. Neither the core nor the full prompt inlines `style-stats.py`, so both rewrite the SKILL.md and discovery.md sentences that run it to record the measured style baseline as not run, and the Phase 7 sentence that copies it to make the copy only when a native install is reachable. Project paths such as `.godplans/PLAN.mdx` stay literal, because the planning agent can reach them. `--full` writes the all-module prompt to PROMPT.full.md for one-off use.

`package.json` is `"private": true`. godplans is not published to npm, and the repository uses `npm pack` only in `tests/package-contents.sh`. `npm test` runs that test against the working tree, where a packed file git ignores fails. The release gate runs it with `--tracked-only`, where a packed file git does not track fails.

## 6. Derived artifacts and the checks that catch staleness

| Source | Generator | Generated artifact | Check that catches staleness |
|---|---|---|---|
| Every `R-<PREFIX>-<N>` id that starts a line (after an optional list marker and `**`) inside the `## Plan requirements` section of each `references/*.md`, and the catalog rows in `references/doc-set.md` | `scripts/build-catalog.js` (`npm run catalog`); it refuses a gap in a prefix's numbering and a document owner missing from `%known_domain` | the `%catalog_max` and `%doc_catalog` blocks in `validate-plan.sh` | `npm run catalog:check`; `tests/validate-plan.sh` also recomputes the requirement catalog ("embedded requirement catalog is current") |
| SKILL.md, the nine core references, the PLAN template, `validate-plan.sh`, `plan-halflife.sh` | `scripts/build-prompt.sh` (`npm run build:prompt`) | `PROMPT.md` | lint `prompt-fresh` (rebuilds into a temporary path and compares with `cmp`); `tests/portable-prompt.test.sh` (marker order, routing to every lazy module including the doc-set contract, the sentence naming where to write the validator companion, no unresolved bare or backticked path to the template, validator, half-life script, a core module, or the plan-format reference, none to `style-stats.py`, deterministic output in any flag order, and both bounds of the byte budget) |
| The same sources plus every lazy module | `scripts/build-prompt.sh --full` | `PROMPT.full.md`, never committed | none for the file; `tests/portable-prompt.test.sh` builds one into a temporary directory and checks that every module is inlined and that the same paths are resolved, `style-stats.py` included; only the inlined style-genome module's vendoring note and R-DNA-21 may still name that script, as the skill's own |
| `PROMPT.md`, SKILL.md, every module named in `coreModules` and `lazyModules`, and a full prompt built into a temporary directory | `scripts/context-metrics.js` (`npm run metrics:context`) | `evals/metrics/context-cost.json` (bytes, estimated tokens, and SHA-256 per file) | `npm run metrics:check` and lint `context-metrics` |
| The `version` field in `package.json` | `scripts/version-sync.js` (`npm run version:sync`; `npm run release:prepare` runs it), which then rebuilds PROMPT.md and the context metrics | the SKILL.md frontmatter `metadata.version` and its `## Skill version:` line, `plugin.json`, `marketplace.json`, the README version badge, and the template's `godplans vX.Y.Z` line | `npm run version:check` (all six surfaces) and lint `version-parity` (SKILL.md, the top CHANGELOG heading, package.json, both manifests, and the template; it does not read the README badge) |
| The SKILL.md frontmatter description | copied by hand | the `description` in `plugin.json` and in the godplans entry of `marketplace.json` | lint `description-parity` (exact equality); lint `description-length` (one double-quoted line of 1 to 1024 characters) |
| The `description` in `package.json` | copied by hand | the GitHub About text and `metadata.description` in `.claude-plugin/marketplace.json` | `scripts/release-check.sh` (About text); lint `description-parity` (marketplace tagline, exact equality) |
| The executor-rules block in `references/plan-format.md` | copied by hand | the `## Rules for executing agents` block in `templates/PLAN.template.mdx` | `tests/validate-plan.sh` (line-for-line equality of the `>` lines) |
| The domain list: `references/*.md` minus the five contract modules | kept by hand in several files | the SKILL.md Phase 4 table; `%known_domain` and `%module_prefix`; the full and core `REFERENCE_ORDER`, the "all N domain modules" count, and the lazy-module sentence in `build-prompt.sh`; `coreModules` and `lazyModules` in `context-metrics.js`; `expected_refs` and `lazy_refs` in `tests/portable-prompt.test.sh`; the template's applicability matrix; discovery's worked matrix; the schema's applicability `minItems` and `maxItems` | lint `domain-parity`, which also requires one prefix per module, defined at the start of a line in that module's own `## Plan requirements` section |
| The canonical skill directory | symlinks | `.agents/skills/godplans`, `.claude/skills/godplans`, `plugins/godplans/skills` | lint `symlinks-valid` (each must be a symlink that resolves to its target, never a copy) |
| The case directories under `evals/cases/` | kept by hand | `evals/cases-roster.txt` | `scripts/eval-matrix.sh --check`, run by `tests/eval-harness.sh` in `npm test`, refuses any difference in either direction |
| A plan's PLAN.mdx | `validate-plan.sh --emit-json` | `.godplans/PLAN.json` in the planned project | `tests/validate-plan.sh` checks every sidecar it emits against `PLAN.schema.json`; consumers compare `plan_digest` |

**One command runs the generators in dependency order:** `npm run generate`, which is `npm run catalog && npm run build:prompt && npm run metrics:context`. The catalog runs first because it rewrites the validator, which the prompt inlines. The metrics run last because they hash PROMPT.md and build the full prompt. After editing SKILL.md, any reference module (the context metrics hash lazy modules too), the template, the validator, or `plan-halflife.sh`, run `npm run generate`, then `npm run check`. `npm run check` runs `version:check`, `catalog:check`, `metrics:check`, the full lint, and `npm test`, in that order.

**What `domain-parity` does not read.** The domain list also appears in discovery's deferral lists, the SKILL.md description and its file-map count, the base fixture in `tests/validate-plan.sh`, and the counts and lists in README, ABOUT, CONTRIBUTING, AGENTS.md, and this file. The validator rejects the base fixture when its matrix lacks a known domain. The rest are hand-kept, and MAINTAINING.md lists them in its add-a-domain checklist.

## 7. Evaluation layers

The lint proves the package is internally consistent. The evaluation layers ask whether an agent using godplans plans better. The included runners call model CLIs on the maintainer's authenticated account, so no model-backed layer runs in CI. CI runs only the offline parts: lint `eval-cases` (`scripts/eval.sh --check-cases`), `scripts/eval-matrix.sh --check`, and the harness regression tests (`tests/eval-harness.sh`, `tests/evidence-harnesses.sh`, `tests/codex-runner.sh`, `tests/vendor-runner.sh`).

| Layer | Entry point | What it measures |
|---|---|---|
| Behavioral cases | `scripts/eval.sh` with `GODPLANS_EVAL_RUNNER`; cases under `evals/cases/<case>/` (`REQUEST.md`, `REQUEST.baseline.md`, `EXPECTATIONS`, optional `INPUT/`) | whether one plan meets the case's deterministic expectations; the harness also requires the validator companion to be byte-identical and the sidecar digest to match |
| Control arm | `scripts/eval.sh --baseline` with `GODPLANS_EVAL_BASELINE_RUNNER` | the same agent, model, and effort with no skill, given the de-branded `REQUEST.baseline.md`, which the control runner reads beside the `REQUEST.md` path the harness passes; `--check-cases` rejects a baseline request that names the skill; the control is a measurement and never a gate |
| Release matrix | `scripts/eval-matrix.sh` | every case in `evals/cases-roster.txt`, both arms, across at least three model-family profiles (default codex, claude, gemini); `summarize-matrix.js` writes MATRIX.md and MATRIX.json |
| External blind grading | `scripts/eval-external.js` | plan pairs under blinded A and B labels (plan content is not redacted) graded by judges from outside the planning family against `evals/external/RUBRIC.md`, whose criteria cite no godplans requirement; grades follow `GRADE.schema.json` and are unblinded only after every grade exists |
| Build outcome | `scripts/eval-outcome.js`, case under `evals/outcomes/cases/tenant-notes-api/` | treatment and control plans built by the same fresh no-skill builder, verified by the case's `VERIFY.sh`, then audited blind by a static godaudits pass; `outcome-summary.js` writes SUMMARY.json |
| Context cost | `evals/metrics/context-cost.json` | the byte and estimated-token cost of the native entry, the portable core, the full prompt, and each module |

The published head-to-head build-outcome result measured godplans 1.9.0 on 2026-07-23 (`evals/outcomes/results/2026-07-23-tenant-notes-api-codex/`). No later version has been re-measured. The rules for publishing evidence are in `evals/README.md` and summarized in MAINTAINING.md.

## 8. The platform contract

Everything a user runs (the validator, the half-life script, `style-stats.py`, and the POSIX sh installer), and every maintainer shell script, must run on stock macOS (`/bin/bash` 3.2 and BSD awk, grep, sed, and find) and on Linux (bash 5 and GNU tools). The validator and the half-life script use only core Perl modules (`JSON::PP`, `Digest::SHA`, `Encode`, and `Time::Local`), which the Perl that ships with macOS includes, and `style-stats.py` uses only the Python standard library. Node.js is maintainer tooling only: the generators, the lint parity checks, and the evaluation coordinators. The shipped skill never runs it.

Lint `shell-syntax` parses each script in its declared shell and rejects bash 4 constructs that `bash -n` under bash 5 accepts. `python-syntax` parses with `ast.parse`, which writes no bytecode into the skill directory that `install.sh` copies. CI runs two jobs. The Ubuntu "release quality" job runs `npm run release:check`: `npm run check` plus the pinned official skills-ref validator, tag-to-release parity and GitHub About parity through `gh` (About drift warns on pull requests and fails on `main` and locally), and the package dry run. The "stock macOS tools" job puts `/bin/bash` and the BSD tools first on PATH and runs `tests/run.sh` and `scripts/lint.sh --all`.
