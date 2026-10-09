# Maintaining godplans

Maintainer rituals. Contributors should read [CONTRIBUTING.md](CONTRIBUTING.md) first. How the pieces fit, and which check catches which stale file, is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). The release checklist is in [docs/RELEASING.md](docs/RELEASING.md), and this file does not repeat it. Drift found in past reviews, and the check that now prevents each case, is in [docs/DRIFT.md](docs/DRIFT.md).

## The version model

The `version` field in `package.json` is the source. A release sets it with one command:

```bash
npm run release:prepare -- <patch|minor|major|X.Y.Z>
```

`scripts/release-prepare.js` runs `npm version` without a Git tag, then `scripts/version-sync.js`. When CHANGELOG.md has no section for the new version yet, it also stubs a `## [X.Y.Z] - YYYY-MM-DD` section at the top with a placeholder line. `npm run version:sync` alone rewrites every surface from whatever `package.json` says.

The surface list in `scripts/version-sync.js` is authoritative. When a new file starts carrying the version, add it to that list; a checklist entry alone leaves the file unchecked. Today the list is:

- the SKILL.md frontmatter `metadata.version`
- the SKILL.md `## Skill version:` line
- `plugins/godplans/.claude-plugin/plugin.json`
- `.claude-plugin/marketplace.json`
- the README version badge (`version-X.Y.Z-blue`)
- the PLAN template's `godplans vX.Y.Z` line

After writing them, `version-sync.js` rebuilds PROMPT.md, which inlines SKILL.md and the template, and then the context metrics, which hash PROMPT.md and SKILL.md. The top CHANGELOG heading is the one surface `version-sync.js` does not write. `release:prepare` stubs it, lint `version-parity` compares it with SKILL.md, and `scripts/release-check.sh` refuses to ship while the exact stub line `- TODO: describe this release.` is still in that section.

Two checks hold the surfaces together:

- `npm run version:check` covers every surface in the list, the README badge included.
- lint `version-parity` compares SKILL.md, the top CHANGELOG heading, package.json, both manifests, and the template. It does not read the README badge.

Never hand-edit a version string, including the badge. `install.sh` reads the version from SKILL.md when it runs, so it needs no edit.

Semver, as practiced so far: patch releases carry documentation, CI, or correctness fixes (1.11.1, 1.12.1, 1.12.2, 1.12.3). Minor releases add requirements, phases, domains, or validator checks (1.12.0, 1.13.0, 1.14.0). There has been no major release since 1.0.0.

## Ritual: adding a domain module

1.14.0 added `business` as the nineteenth domain. Commit a4f353d touched 32 files to do it, and this checklist comes from that change. `bash scripts/lint.sh modules-complete domain-parity` fails until the module appears in every list domain-parity reads. Each step below names the check that catches a miss. A step marked "no check" is hand-kept: nothing fails if you skip it.

1. **The module.** Write `skills/godplans/references/<name>.md` with the six sections: Lineage, Decisions to force, Plan requirements, Task seeds, Self-audit rubric, Anti-patterns refused. Choose a prefix no other module uses. Define `R-<PREFIX>-1` through `R-<PREFIX>-N` at the start of lines in `## Plan requirements`, with no gap in the numbering. Checks: `modules-complete`, `domain-parity`, and `npm run catalog`, which refuses a gap.
2. **Decide its rules before wiring it.** Decide whether the module is core (inlined in PROMPT.md) or lazy. Decide whether it is deferrable, never excludable, or neither; business is excludable and never deferrable. Decide whether an overlay forbids excluding it.
3. **Validator tables** in `skills/godplans/scripts/validate-plan.sh`:
   - `%known_domain`: add the name (`domain-parity`).
   - `%module_prefix`: add `'<name>' => '<PREFIX>'`. `%prefix_module` is derived from it with `reverse` (`domain-parity`).
   - `%deferrable_domain` or `%never_excludable`, when step 2 says so (no check compares them with discovery.md).
   - `%overlay_domains` when an overlay protects the domain, and the unknown-overlay message that lists every overlay (no check).
   - Then run `npm run catalog`. It adds the prefix to `%catalog_max` and any new documentation-set rows to `%doc_catalog` (`npm run catalog:check`). It refuses a document owner missing from `%known_domain`, so edit that table first.
4. **Schema**, `skills/godplans/schemas/PLAN.schema.json`. Raise the applicability `minItems` and `maxItems` (`domain-parity`, and the sidecar schema check in `tests/validate-plan.sh`). A new row count is a new sidecar format: bump the `format` tag in the schema, in validate-plan.sh, and in the pinned test literals, and keep the previous schema as `PLAN.v<n>.schema.json` for sidecars that plans on an older companion keep emitting, as 1.14.0 did with `PLAN.v1.schema.json`. Add a new overlay to the `overlays` enum. That one fails only if some test emits a sidecar declaring the overlay.
5. **Template**, `skills/godplans/templates/PLAN.template.mdx`: add the applicability-matrix row in Phase 4 order (`domain-parity`).
6. **SKILL.md**:
   - the Phase 4 table row, renumbering the rows after it (`domain-parity` reads the module names, not the numbers);
   - the domain list in the frontmatter description, which must stay within 1024 characters (`description-length`; `bash scripts/lint.sh description-length --verbose` prints the current length). When the new name does not fit, cut elsewhere first: 1.14.0 dropped "for a software project", the "idea to plan" trigger, and the gloss after "plan theater" in the same change that added business;
   - the "core move" sentence and the lineage paragraph, when the module inverts an auditor or descends from a new source (no check);
   - the File map count, "N domain modules" (no check);
   - the Phase 2 overlay list, when you add an overlay (no check).
7. **Plugin metadata.** Copy the new SKILL.md description verbatim into `plugins/godplans/.claude-plugin/plugin.json` and the godplans entry of `.claude-plugin/marketplace.json` (`description-parity`). Change SKILL.md first, then copy. The marketplace tagline, `metadata.description`, copies the package.json `description` instead, so it changes only when that does (`description-parity` too).
8. **Discovery and plan format** (no check). In `references/discovery.md`, update:
   - the deferrable set or the "Never deferrable" list;
   - the "Hard rules" line, when the domain has its own applicability rule;
   - the example applicability matrix (`domain-parity` reads it);
   - the overlay table, when an overlay protects the domain.

   In `references/plan-format.md`, update the overlay list in the frontmatter rules when you add an overlay.
9. **Sibling boundaries** (no check). State each shared subject once and cite it from the other module. For business, 1.14.0 edited deploy, launch, llm, observe, product, repo, roadmap, security, and ux, and moved `frame.business-case` in `doc-set.md` from product to business. A moved document owner causes an owner mismatch in existing plans at their next replan. Say so in the CHANGELOG.
10. **Portable prompt**, `scripts/build-prompt.sh`:
    - Add the name to the full `REFERENCE_ORDER` and raise "all N domain modules" (`domain-parity`).
    - For a lazy module, add it to the sentence "The lazy modules are ..." (`domain-parity`).
    - For a core module, add it to the core `REFERENCE_ORDER` (`domain-parity`). Also add it to the core header's module list and give it a `portable_text_core` rewrite for its `references/<name>.md` path (no check).
11. **Context metrics**, `scripts/context-metrics.js`: add the name to `coreModules` or `lazyModules` (`domain-parity`).
12. **Portable-prompt test**, `tests/portable-prompt.test.sh`: add the name to `expected_refs` or `lazy_refs` (`domain-parity`). A lazy module still grows the core through its wiring: business added about 1.5 KB. Read "The portable-core budget" below before touching the number.
13. **Validator regression suite**, `tests/validate-plan.sh`:
    - add a row to the base fixture's matrix and the domain to the matching `domains_*` frontmatter list (the suite fails without both);
    - raise the `applicability.length` count in the sidecar check;
    - add cases for the domain's rules. 1.14.0 added five: a plan written before the domain, a refused deferral, the monetized overlay, a passing plan that lands a requirement, and an id outside the catalog.
14. **Lint self-test**, `tests/lint-selftest.sh`: update the literals it rewrites in `build-prompt.sh` ("all N domain modules" and the start of the lazy-module sentence) and the expected message that names the module count. The self-test fails until they match.
15. **Behavioral evaluation**:
    - Add a case under `evals/cases/<case>/`, with `REQUEST.md`, `REQUEST.baseline.md`, and an `EXPECTATIONS` file that includes `domain|<name>|applicable`.
    - Add one line for it to `evals/cases-roster.txt` (`scripts/eval-matrix.sh --check`, run by `npm test`).
    - Add expectations to existing cases whose disposition is certain. 1.14.0 expects business applicable in greenfield-saas and excluded in weekend-library.
    - Add the case to the table in `evals/README.md` (no check).

    Leave `evals/cases/replan-preserves-history/INPUT/.godplans/PLAN.mdx` alone. It is an old-format plan whose matrix lists only security and database, so a replan run has to add every missing row, business included, as a delta. It ships no companion and predates `--emit-json`, so it also exercises the Phase 0 path where the half-life measurement cannot run.
16. **Replan.** A plan written before the domain fails the new validator with "applicability matrix is missing domain <name>". SKILL.md (Modes, Replan) already tells the agent to add the matrix row, the frontmatter entry, and (when applicable) the disposition line, to re-point any documentation row whose catalog owner moved, and to treat an applicable new domain as material. Confirm the message still matches that rule, and say in the CHANGELOG that existing plans need a replan.
17. **Counts and lists in prose** (no check). Update:
    - in README.md: the "planning domains" badge, the domain-pass node in the How it works diagram and the sentence that lists the passes, the slim-core paragraph (its core list for a core module, or "The other fourteen domain modules" for a lazy one), the repository map's module count, and the lineage table and source count when the module inverts a new source;
    - the counts in docs/ABOUT.md;
    - the "N domain modules" ground rule in CONTRIBUTING.md and the "N domain modules" bullet in AGENTS.md;
    - in docs/ARCHITECTURE.md: the "Domain modules (N)" row, the core and lazy lists and, for a core module, the "five load-bearing domains" count under "Core and lazy modules", and the `%deferrable_domain`, `%never_excludable`, and `%overlay_domains` rows when step 2 changed them.
18. **Generate and check.** Run `npm run generate`, then `npm run check`. Release it as a minor version, as 1.14.0 was.

## The portable-core budget

`tests/portable-prompt.test.sh` fails when PROMPT.md exceeds a byte budget. The comment above that line is the rule, quoted here rather than restated:

```text
# The budget exists to make growth visible, not to be raised whenever it fires.
# The invariant it encodes: headroom stays under one core module, so a
# module-sized addition trips the gate instead of sliding past it, while an
# ordinary edit does not. The number is derived from that rule, not chosen.
```

```text
# Before moving it a fourth time: cut content or drop a module first, then set
# the number so headroom lands just under the smallest core module again. Print
# the module sizes with `npm run metrics:context` and read them out of
# evals/metrics/context-cost.json rather than guessing.
```

The comment also records each past raise and, from 1.12.1 on, what was cut first. Keep that history going when you move the number. To read the two values the rule compares:

```bash
npm run metrics:context
node -e 'const m=require("./evals/metrics/context-cost.json"); const [name, s]=Object.entries(m.core_modules).sort((a,b)=>a[1].bytes-b[1].bytes)[0]; console.log("portable core:", m.portable_core.bytes, "bytes; smallest core module:", name, s.bytes, "bytes")'
```

The headroom is the budget minus the portable core. It must stay below the smallest core module (compliance today), so a module-sized addition trips the gate. `tests/portable-prompt.test.sh` enforces both bounds, reading module sizes from the source files, and names the highest budget that keeps the lower bound.

## Ritual: refresh dated facts

Some modules cite facts that expire. Review them at least every six months, and whenever the source they came from changes. Today they live here:

- `references/business.md`, the "Dated sources" paragraph in its Lineage section: consumer-law and provider facts (ROSCA, the California Automatic Renewal Law as amended by AB 2863, the vacated FTC Negative Option Rule, the New York City subscription-cancellation rule, the EU Data Act's switching chapter), plus the switching windows R-BIZ-18 quotes from the same dated source. They were taken from productauditor's `references/facts.md` in hannsxpeter/auditor-suite and reviewed 2026-10-01. The paragraph tells planners to recheck any fact older than six months before a plan cites it, so the next review is due by 2027-04-01.
- `references/ux.md`, decision 7 (consent and cancellation symmetry): the FTC click-to-cancel rule was vacated on 8 July 2025 and is not cited as law.
- `references/compliance.md`: the Anthropic Usage Policy version it names (effective 2025-09-15), the Consumer Terms, and the support article it cites. The module itself tells planners to re-check those URLs on compliance-sensitive projects.
- `references/security.md`, its Lineage: the standards editions secauditor anchors to (OWASP 2025 and 2021, the API Top 10 2023).
- `references/agent-memory.md`: the Pillars release it pins (1.2.2, released 2026-08-04) in its Lineage, R-MEM-2, R-MEM-16, two task seeds, and the rubric. Compare with https://github.com/hannsxpeter/pillars/releases and the newest tag's canonical AGENTS.md; from 1.1.0 to 1.2.2 only its version references changed.
- `references/seo.md`, decisions 2, 4, and 5, R-SEO-13, R-SEO-14, and the score caps: AI crawler names and purposes, the llms.txt status, the FAQ, HowTo, and sitelinks search box changes, and seoauditor's floor of 69, taken from seoauditor's `references/facts.md` and SKILL.md in hannsxpeter/auditor-suite (facts reviewed 2026-09-26).

To refresh: check each fact against its source, then update the review date where the module records one: the business.md Lineage and seo.md's R-SEO-14 (agent-memory.md pins a version, not a date). When productauditor's or seoauditor's `facts.md` has a newer "Last reviewed" date, compare it with the module first. Then run `npm run generate`. business.md, ux.md, seo.md, and agent-memory.md are lazy, so editing them changes only the context metrics. compliance.md and security.md are inlined in the portable core, so editing them also changes PROMPT.md and counts against the budget. Record the review in the CHANGELOG.

In the same pass, confirm that the lineage links resolve: the README Lineage table, the "descends from" paragraph in SKILL.md, docs/ABOUT.md, and each module's Lineage section. No check follows links. The seven standalone auditor repositories were deleted on 2026-07-14, when they were folded into hannsxpeter/auditor-suite, and their links went dead without any failure.

## Ritual: when lint or the self-test fails

1. **Reproduce.** `npm run lint` (`bash scripts/lint.sh --all --verbose`) runs every check, even after one fails, and ends with `FAIL [lint] failing checks: ...`. Rerun only the failing ones by name, for example `bash scripts/lint.sh prompt-fresh context-metrics`. `npm run check` stops at its first failing step, and `tests/run.sh` stops at its first failing suite, so run the rest of the suites by name after a fix.
2. **A generated file is stale** (`prompt-fresh`, `context-metrics`, `catalog:check`). Run `npm run generate` and commit what it rewrites. For a version failure (`version:check`, `version-parity`), run `npm run version:sync`, or `release:prepare` for a release. Never hand-edit PROMPT.md, `evals/metrics/context-cost.json`, or the validator's generated blocks.
3. **`official-validator` prints `skip`.** No skills-ref was found, or the one found automatically cannot run. That is not a failure locally, and the release gate will not accept it. Install the pinned validator as `docs/RELEASING.md` shows, or point `SKILLS_REF_BIN` at a working one.
4. **A platform-only failure.** CI runs the suite and the full lint on stock macOS with `/bin/bash` 3.2 and BSD awk, grep, sed, and find first on PATH. To reproduce it on a Mac, build the same shim the macOS job in `.github/workflows/lint.yml` builds: links to `/bin/bash` and the `/usr/bin` tools, placed first on PATH. Then run `bash tests/run.sh` and `bash scripts/lint.sh --all`.
5. **The lint itself is wrong.** If a check fails when it should not, fix the check in `scripts/lint.sh` or `scripts/lint-parity.js`, and say so in the commit body. A check that fails to fail is worse than one that is too strict, so never loosen a check to make a bad tree pass. Add a case to `tests/lint-selftest.sh` for every check you add or fix.
6. **The self-test fails.** `bash tests/lint-selftest.sh` copies the repository (tracked files plus untracked files git does not ignore) into a temporary directory and first proves that every `--all` check passes on the copy. If that baseline fails, it prints `lint-selftest: the unmodified copy already fails`. Fix the tree, often a non-ASCII byte in a new untracked file, before reading the cases. A case can also fail because the text it injects into has moved: `'seo' => 'SEO'` in the validator, the `ux` line in `lazy_refs`, the "all N domain modules" literal, and others. Update the case to the new text. Never delete the case.
7. **Fix forward** with one repair commit. Do not stack unrelated changes on a red branch.

## Ritual: evaluation evidence

Never run a model-backed evaluation without the maintainer's go-ahead. That covers `npm run eval`, `eval:matrix`, `eval:external`, and `eval:outcome`, and the scripts behind them. They call model CLIs on the host's authenticated account and spend its quota. The Claude and Gemini planning runners also skip permission prompts and are not confined to their temporary workspace, so run them only on a disposable machine or account. These steps are offline and free, and CI runs the first two:

- `npm run eval:check` (`scripts/eval.sh --check-cases`)
- `bash scripts/eval-matrix.sh --check`
- `bash scripts/eval.sh --score-only --output DIR`, which rescores retained artifacts

`evals/README.md` owns the publication rules. In short:

- Release evidence is every case in `evals/cases-roster.txt`, both arms, across at least three model families.
- Commit the summaries together with every raw artifact: plans, sidecars, control plans, runner metadata, and CLI event logs. A summary without raw artifacts is not publishable evidence. `.gitignore` keeps `*.log` files trackable under the results trees for this reason.
- Never publish a skill score without the control score beside it.
- Each case is one sample: repeat runs and report the spread before treating a delta as stable.
- External grading needs at least five plan pairs and two judges from outside the planning family, and publishes the inter-rater gap.

The README's head-to-head build-outcome result measured godplans 1.9.0 on 2026-07-23. Any claim about a later version needs a new run.

## Vendored code

`skills/godplans/scripts/style-stats.py` is vendored by copy from hannsxpeter/codedna (`skill/scripts/codedna_stats.py`, MIT). The base is codedna v1.0.4 (tag commit `645ea5a`; the file last changed upstream in `4f75a6a`), and the script's docstring records the base and the local fixes. Neither repository depends on the other at run time. A fix travels between them as an edit to the file, never as a reference. When either copy changes, diff the two files and port fixes in both directions, then run `bash tests/style-stats.sh`, which covers the copy here.

Where the copies stand against codedna v1.1.1 (`f2953c8`):

- Local fixes codedna lacks: bodyless declarations and `.d.ts` files are not measured as functions, the boolean-prefix share counts distinct names, and a Python comparison is not an assignment (1.14.0); wrapped Python signatures, the docstring after one, and arrow functions whose parameters wrap are measured; languages with equal file counts sort by name. codedna fixes identifiers counted under two kinds its own way.
- Taken from codedna v1.1.1: sorted file paths, sampled evenly above the 800-file per-language cap.
- Not taken from codedna: the git-aware file listing, the `.mts`, `.cts`, `.cc`, `.cxx`, `.hpp`, and `.kts` extensions, quote counts that skip comments, docstrings, and regex literals, and the v1.1.0 comment-voice and error-message-voice statistics.
