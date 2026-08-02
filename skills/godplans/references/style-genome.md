# Style genome (code DNA) planning module

Fixes the project's coding style genome (naming, comments, structure, control flow, error posture, idioms) in PLAN.mdx before the first commit exists. The orchestrator loads this module for every archetype that ships custom code (all of them except a zero-code content site), in the domain-pass order after seo and before agent-memory, because the quality-pillar wiring that agent-memory plans depends on the genome this module defines. In brownfield mode this module also governs the read-only fingerprint pass.

## Lineage

Descends from codedna (hannsxpeter/codedna), the skill that fingerprints a codebase's style so new or AI-written code is indistinguishable from the original author's. codedna works after the fact: Map extracts a CODEDNA.md profile from existing code, Match writes code that blends in, Check flags AI tells in diffs. godplans inverts the direction: for greenfield projects the genome is authored at plan time, so there is never anything to retro-extract. The discipline that carries over intact: layered evidence ordered cheapest and most authoritative first (tooling configs, then measured frequencies, then close-read voice), the specificity gate (a rule true of almost any repo gets sharpened or cut), the enforced-vs-observed split, the AI-tells catalog used as a pre-presentation self-check, and the rule that local file dialect wins over the global profile.

Two of those carry as artifacts rather than as advice. The AI-tells catalog is reproduced in full below, because a planner told to write an anti-tells appendix without the catalog is selecting from a list it does not have. And `scripts/style-stats.py`, vendored by copy from codedna, measures the frequencies R-DNA-5 and R-DNA-20 ask for, because a numeric function-size norm produced by eyeballing five files is an adjective with a number painted on it.

Ported by copy in both directions: godplans depends on nothing from codedna at runtime, codedna depends on nothing from godplans, and a fix travels between the repositories as an edit rather than a reference.

## Decisions to force

Ordered hardest to reverse first.

1. Error-handling strategy.
   - Question: exceptions, Result/Either, error-return, or let-it-throw, and where validation lives.
   - Why hard to reverse: the choice propagates through every function signature and call site; migrating a throwing codebase to Result touches everything.
   - Options: typed custom errors thrown at boundaries (default for TS and Python apps); Result everywhere (default for Rust, or TS teams already on neverthrow); error-return (Go).
   - Default: one strategy project-wide, validate at trust boundaries only, never re-validate internally.
2. Module shape and file organization.
   - Question: feature folders or layer folders, barrel files or direct imports, where helpers live.
   - Why hard to reverse: import paths fossilize into every file, and mass-moving them poisons git blame.
   - Options: feature folders (default for apps); layer folders (defensible for small API services); barrels only if the stack module's bundler tree-shakes them.
   - Default: feature folders, no barrel files, helpers co-located until shared by a second feature.
3. Naming genome and domain glossary.
   - Question: casing per identifier kind, one verb dialect (get vs fetch vs load per semantic), and the canonical domain nouns (user vs account vs member).
   - Why hard to reverse: names leak into public APIs, database columns, file paths, and URLs, each with its own migration cost.
   - Options: language-community casing norms (default) vs a house deviation, which must be recorded as observed and justified.
   - Default: community casing, get for synchronous access and fetch for network calls, glossary nouns fixed to match the data model section's entity names.
4. Enforced tooling layer.
   - Question: which formatter and linter, checked in at commit zero.
   - Why hard to reverse: adopting a formatter later means one giant unreviewable reformat commit.
   - Options: the stack's dominant formatter (Prettier or Biome, Black plus Ruff, gofmt, rustfmt); anything else needs a written reason.
   - Default: dominant formatter, configs committed before the first source file.
5. Test conventions.
   - Question: framework, co-located *.test.ts vs a tests/ tree, describe/it vs flat functions, case-naming style.
   - Why hard to reverse: location and naming get mirrored across every module; moving them later is a repo-wide rename.
   - Options: co-located (default for apps and libraries) vs tests/ tree (default for Python and Go, where the ecosystem expects it).
   - Default: co-located test files, framework taken from the stack module's pick.
6. Comment and documentation contract.
   - Question: density target, why-vs-what rule, doc-comment scope.
   - Why hard to reverse: reversible on paper but never actually reversed; drift compounds silently, and AI contributions default to over-commenting.
   - Options: sparse why-only comments (default); doc comments on public API only (default) vs everything (only for published libraries).
   - Default: sparse comments that explain why, doc comments on public API only.

## Plan requirements

- R-DNA-1 Enforced layer at commit zero. PLAN.mdx names the formatter and linter config files committed before any source file, and the exact format/lint commands recorded in package.json scripts, Makefile, or CI. The genome section never restates a rule those tools settle (indentation, quotes, semicolons); it says "run X".
  Criterion: WHEN the style genome section is emitted, THE PLAN SHALL list the enforced config files and their exact check commands, and SHALL contain no convention line that a named formatter already rewrites.
- R-DNA-2 Naming casing per identifier kind.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL state casing for functions, methods, types/classes, constants, variables, files, and (where applicable) CSS classes, with no kind left implicit.
- R-DNA-3 Word-choice genome. One verb dialect per semantic, boolean prefixes (is/has/should), plural collections, private-member marker, event-handler convention (onClick vs handleClick), an explicit abbreviation whitelist (cfg, ctx, res), and a target name length or terseness norm.
  Criterion: WHEN naming is planned, THE PLAN SHALL fix each of these as a single choice, not a menu.
- R-DNA-4 Comment and documentation contract. Density target stated as an expectation (for example "most functions carry no comment"), the why-not-what rule, register (terse lowercase fragments vs capitalized sentences, impersonal vs first person), doc-comment scope and format, TODO/FIXME convention, and an explicit ban or allowance on section banners and dividers.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL state density, register, doc scope, and the banner rule explicitly.
- R-DNA-5 Structural genome. Expected function size given as a number (for example "median under 10 lines"), the extraction threshold (when a helper is warranted vs inlined, and whether repetition is tolerated over premature abstraction), in-file ordering, module shape (feature vs layer, barrels yes or no), and paradigm (composition vs inheritance, functional vs OO).
  Criterion: WHEN structure is planned, THE PLAN SHALL include a numeric function-size norm and a stated extraction threshold, not adjectives.
- R-DNA-6 Control-flow posture. Early returns vs nesting, ternary tolerance, loops vs higher-order functions, switch vs lookup maps, async style (async/await vs .then, Promise.all usage).
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL fix each control-flow habit as a single project-wide choice.
- R-DNA-7 Error posture. The single error strategy chosen in Decisions, the defensiveness policy (validate at trust boundaries only, or stated otherwise), custom error types vs generic throws, error-message tone, and logging density and style on errors.
  Criterion: WHEN error handling is planned, THE PLAN SHALL name one strategy and one defensiveness policy and SHALL cross-reference the Decisions entry that committed them.
- R-DNA-8 Types conventions. Explicit vs inferred return types, interface vs type, any/unknown tolerance, non-null assertions, enums vs union literals, nullability convention.
  Criterion: IF the stack is statically typed, THE PLAN SHALL fix each of these; IF not, THE PLAN SHALL mark this dimension excluded with the stack as the reason.
- R-DNA-9 Import conventions. Default vs named exports, ordering and grouping (deferred to the linter config when enforced there), relative vs alias paths, barrel re-export policy.
  Criterion: WHEN imports are planned, THE PLAN SHALL either defer a rule to a named linter config or state it as an observed convention, never both.
- R-DNA-10 Test conventions. Framework, file location and naming, structure (describe/it vs flat), case-naming style, mocking and fixture posture.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL fix test location and naming so the first test file written matches every later one.
- R-DNA-11 Idiom registry. The canonical shared helpers the project will have (the cn(), the formatDate, the custom assert) named with their intended file paths, plus the parallel-utility ban: introducing a second utility with overlapping purpose fails review.
  Criterion: WHEN idioms are planned, THE PLAN SHALL name each canonical helper with a path and SHALL state the parallel-utility ban as a review-failing rule.
- R-DNA-12 Domain glossary. The nouns and verbs of the domain fixed so synonyms are never interchangeable (user vs account vs member; fetch vs load).
  Criterion: WHEN the glossary is emitted, THE PLAN SHALL list each canonical term with its banned synonyms, consistent with the data model's entity names.
- R-DNA-13 Reference shapes. The standard shape of the project's recurring units (a component, a handler, an endpoint, a CLI subcommand as applicable) described as a pattern the first instance will establish.
  Criterion: WHEN the archetype has a recurring unit, THE PLAN SHALL describe its standard shape in enough detail that two agents writing two instances produce structurally identical files.
- R-DNA-14 CODEDNA.md as a day-one artifact. A task emits CODEDNA.md at scaffold time: leads with a TL;DR of about 10 rules, marks every rule enforced or observed, is stamped with version and date, and carries the obligation to back-fill real 2-4 line snippets as the first modules land.
  Criterion: WHEN tasks are generated, THE PLAN SHALL contain a wave-one task that writes CODEDNA.md before the first feature task, with these properties in its acceptance lines.
- R-DNA-15 Specificity gate. Every genome rule passes the substitution test.
  Criterion: IF a genome line would read identically for a different project, THE PLAN SHALL sharpen it with a project-specific value or delete it; "uses descriptive names" and its relatives never ship.
- R-DNA-16 Agent instruction wiring. The genome contract ships as pillar content, never as loader additions: an idempotent marker block (codedna:start / codedna:end) is planned inside agents/quality.md (the pillar that bundles testing, errors, and style per the agent-memory module), pointing at CODEDNA.md and instructing agents to self-check against the AI-tells section before finishing. AGENTS.md stays pinned to its four canonical elements and CLAUDE.md stays a one-line redirect (agent-memory.md R-MEM-2 and R-MEM-15); the standard AGENTS.md loading protocol already routes agents to the quality pillar, so no extra wiring is needed there.
  Criterion: WHEN agent-memory files are planned, THE PLAN SHALL place the genome pointer block inside agents/quality.md, editable only between its markers, and SHALL NOT add genome content to AGENTS.md, CLAUDE.md, or other per-tool rule files.
- R-DNA-17 Anti-AI-tells appendix. The genome states where this project deliberately deviates from AI defaults: comment sparseness, name terseness, non-defensiveness, no docstring boilerplate, no explainer voice, no banners or decorative characters, no leftover scaffolding.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL include an anti-tells list containing only deviations this project actually makes, so checks never flag code that matches.
- R-DNA-18 Enforcement loop. A Check step against CODEDNA.md on every diff: a pre-commit hook or a review-time instruction, with findings rated by severity and rewritten in house style before merge.
  Criterion: WHEN tasks are generated, THE PLAN SHALL contain a task wiring the diff-check step, and the genome section SHALL name where the check runs.
- R-DNA-19 Freshness protocol. The genome document carries version and date; the plan names the refresh triggers (new linter, framework migration, convention-changing refactor) and mandates re-ratification after them; a known-inconsistencies ledger records real exceptions with the rule that local file dialect wins over the global profile.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL state the refresh triggers and the local-dialect-wins rule.
- R-DNA-20 Brownfield fingerprint before authorship.
  Criterion: WHEN mode is brownfield, THE PLAN SHALL derive the genome from layered evidence (configs as enforced ground truth, measured frequencies such as naming histograms and comment density, then a close-read sample quoted in 2-4 line snippets, skipping vendored and generated paths), and SHALL record the dominant pattern plus real exceptions rather than inventing conventions the code does not exhibit.
- R-DNA-21 Measured, not eyeballed. The numeric norms in this section come from `python3 scripts/style-stats.py <target>`, whose output the plan quotes: comment density per language, naming-casing histograms per identifier kind, median and p90 function length, median identifier length, quote and indentation habits, and documentation coverage. In brownfield the target is the existing tree, and the measured run is the second evidence layer between the configs and the close read. In greenfield there is nothing to measure, so the section states the target numbers as choices and names the run that will confirm them once the first modules land.
  Criterion: IF mode is brownfield, THE PLAN SHALL quote measured values from the stats run for at least comment density, function-length median, and the casing histogram of the two most common identifier kinds, and every numeric norm in the genome SHALL trace to one of them; IF mode is greenfield, THE PLAN SHALL state each numeric norm as a chosen target and SHALL name the confirming run and the wave it happens in.
- R-DNA-22 Config map before prose. The plan lists the enforced-layer config files it found or will commit, and next to each, the specific conventions that tool settles (line width, indentation, quotes, semicolons, trailing commas, import ordering, and any lint rule that rewrites rather than warns). That map is what makes R-DNA-1 checkable: a genome line covering a mapped convention is a duplicate with a second source of truth, and it is cut.
  Criterion: WHEN the genome section is emitted, THE PLAN SHALL contain a config map naming each enforced file and the conventions it settles, and no genome rule SHALL restate a convention the map assigns to a tool.
- R-DNA-23 Anti-tells selected from the catalog. The anti-tells appendix required by R-DNA-17 selects from the numbered catalog in this module and cites the catalog number for each entry, keeping only the tells this project actually deviates from, with the project-specific value that makes each one checkable ("comments: most functions carry none, not one per block").
  Criterion: WHEN the anti-tells appendix is emitted, THE PLAN SHALL cite a catalog number and a project-specific value for every entry, and SHALL omit every catalog entry the project does not actually deviate on, so no check can flag conforming code.
- R-DNA-24 The check runs as a command. The enforcement loop required by R-DNA-18 names an executable Verify command, not a prose instruction to review carefully. At minimum the formatter and linter check commands run in the hook and in CI; where a diff-level style check is available (a codedna Check invocation, a custom script, or a review-time checklist wired into the PR template with a machine-checked presence test), the plan names it and where it runs.
  Criterion: WHEN the enforcement task is emitted, THE PLAN SHALL give it a Verify command whose exit code proves the check is wired, and SHALL NOT satisfy R-DNA-18 with an instruction that no command can fail.

## AI tells catalog

The reference list R-DNA-17 and R-DNA-23 select from. Carried in full rather than cited, so the planner is choosing from the catalog rather than remembering it.

AI defaults to maximally explicit, maximally defensive, uniformly consistent, and eager to explain. Real authors are selectively terse, selectively defensive, characteristically inconsistent, and sparing with explanation. The appendix records where this project is deliberately the opposite of the default, and nothing else, because a tell that does not describe this project produces false positives, and a false tell costs as much trust as a missed one.

1. **Over-commenting**: a comment above nearly every block.
2. **Narrating the obvious**: a comment that restates the line below it.
3. **Names longer than the house norm**: `responseData` and `handleButtonClickEvent` where the author writes `res` and `onClick`.
4. **Defensive boilerplate**: try/catch blocks, null checks, and re-validation the author would not write.
5. **Over-abstraction, or under**: a one-line helper, or a factory the project does not warrant, against an author who inlines; the reverse for an author who extracts early.
6. **Uniform consistency**: every rule applied perfectly, flattening the characteristic local dialect of individual files.
7. **Docstrings on everything**: `@param` and `@returns` blocks that restate the signature.
8. **Explainer voice**: "Now we iterate", first-person plural, full sentences in a terse repository.
9. **Section banners and dividers** in a repository that has none.
10. **Emoji and decorative Unicode** in a repository that has none.
11. **Restating the prompt or the plan** in comments.
12. **Leftover scaffolding**: demo main blocks, debug logging, completed TODO markers.
13. **Parallel utilities and vocabulary drift**: a second `formatDate`, or `fetch` and `load` used interchangeably.
14. **Belt-and-suspenders typing**: explicit return types everywhere in an inferring codebase, redundant casts.
15. **Verbose logging and error messages** in a codebase that logs sparingly.

## Task seeds

- [ ] GP-xxx Commit enforced style layer
  - Files: .editorconfig, .prettierrc or biome.json or pyproject.toml, eslint.config.js, package.json, .github/workflows/ci.yml
  - Acceptance: formatter and linter configs exist at repo root; package.json scripts (or Makefile) define format and lint commands; CI runs the lint command
  - Verify: npx prettier --check . && npx eslint . (adapt to the stack's commands from R-DNA-1)
  - Requirements: R-DNA-1
- [ ] GP-xxx Author CODEDNA.md style genome
  - Files: CODEDNA.md
  - Acceptance: opens with a TL;DR of about 10 rules; every rule tagged enforced or observed; version and date stamp present; naming table covers all identifier kinds; anti-AI-tells section present
  - Verify: grep -q 'codedna' CODEDNA.md && grep -cE '(enforced|observed)' CODEDNA.md
  - Requirements: R-DNA-2, R-DNA-3, R-DNA-4, R-DNA-5, R-DNA-6, R-DNA-7, R-DNA-8, R-DNA-9, R-DNA-14, R-DNA-15, R-DNA-17
- [ ] GP-xxx Wire genome into the quality pillar
  - Files: agents/quality.md
  - Acceptance: agents/quality.md contains a codedna:start / codedna:end block pointing at CODEDNA.md; block instructs a self-check against the AI-tells section before finishing any change; AGENTS.md and CLAUDE.md carry no genome content
  - Verify: grep -q 'codedna:start' agents/quality.md && ! grep -qi 'codedna' AGENTS.md && ! grep -qi 'codedna' CLAUDE.md
  - Requirements: R-DNA-16
- [ ] GP-xxx Seed canonical helpers and domain glossary
  - Files: src/lib/cn.ts, src/lib/assert.ts (per idiom registry), CODEDNA.md glossary section
  - Acceptance: each registry helper exists at its planned path; glossary lists canonical terms with banned synonyms; no second utility duplicates a registry helper's purpose
  - Verify: test -f src/lib/cn.ts && ! grep -rl 'formatDate2\|classNames(' src/
  - Requirements: R-DNA-11, R-DNA-12, R-DNA-13
- [ ] GP-xxx Wire the diff-check enforcement loop
  - Files: .husky/pre-commit or .pre-commit-config.yaml, CONTRIBUTING.md
  - Acceptance: pre-commit runs the format check and the CODEDNA.md diff-check instruction; CONTRIBUTING.md documents the review-time check with severity ratings
  - Verify: grep -q 'CODEDNA' .husky/pre-commit CONTRIBUTING.md
  - Requirements: R-DNA-18, R-DNA-19
- [ ] GP-xxx Fingerprint existing codebase (brownfield only)
  - Files: CODEDNA.md
  - Acceptance: enforced layer read from existing configs, not re-derived; measured frequencies recorded from the stats run (casing histograms, comment density, function-length median and p90, quote style); each observed rule paired with a quoted 2-4 line snippet; known inconsistencies recorded with the local-dialect-wins rule
  - Verify: grep -c '```' CODEDNA.md (snippet fences present) && grep -q 'Known inconsistencies' CODEDNA.md
  - Requirements: R-DNA-20, R-DNA-21, R-DNA-19

- [ ] GP-xxx Record the measured style baseline
  - Files: CODEDNA.md, .godplans/style-stats.json
  - Acceptance: `python3 scripts/style-stats.py . --json` output is stored; CODEDNA.md quotes comment density, function-length median and p90, and the casing histogram for functions and variables; every numeric norm in the genome traces to one of those values
  - Verify: python3 scripts/style-stats.py . --json > .godplans/style-stats.json && grep -q 'median' CODEDNA.md
  - Requirements: R-DNA-21, R-DNA-5

- [ ] GP-xxx Publish the enforced-layer config map
  - Files: CODEDNA.md
  - Acceptance: each committed formatter and linter config is listed with the conventions it settles; no genome rule restates a mapped convention; the section says "run X" for each mapped tool
  - Verify: grep -q 'Enforced by tooling' CODEDNA.md && ! grep -niE '^- (indentation|semicolons|quote style):' CODEDNA.md
  - Requirements: R-DNA-22, R-DNA-1

## Self-audit rubric

Score the plan's style genome section 0-100.

- Enforced layer settled (11): configs and exact commands named at commit zero; the config map assigns each mapped convention to its tool; zero formatter-settled rules restated in prose.
- Measured evidence (10): brownfield numeric norms quoted from the stats run and traceable to it; greenfield norms stated as choices with a named confirming run and wave. Zero when a number appears with no measurement and no declared choice behind it.
- Naming genome complete (13): casing covers every identifier kind; verb dialect, boolean prefixes, private markers, handler convention, and abbreviation whitelist each fixed to one choice.
- Comment contract (7): density, register, doc scope, and banner rule all explicit; why-not-what stated.
- Structural genome (9): numeric function-size norm, stated extraction threshold, module shape, and paradigm all committed.
- Control flow and error posture (11): every control-flow habit fixed; one error strategy and one defensiveness policy, cross-referenced to Decisions.
- Types, imports, tests (9): each fixed or excluded with a stated reason; no rule both deferred to a linter and restated as prose.
- Idiom registry and glossary (9): helpers named with paths, parallel-utility ban stated, glossary terms consistent with the data model.
- Day-one CODEDNA.md and wiring (9): wave-one task emits the stamped profile before feature work; the marker block is planned inside agents/quality.md, with AGENTS.md and CLAUDE.md left untouched.
- Anti-AI-tells appendix (7): selects from the catalog with numbers cited; lists only real project deviations; would produce no false tells.
- Enforcement loop and freshness (5): the check has an executable Verify command rather than a review instruction; refresh triggers and local-dialect-wins rule stated.

Any dimension at zero, or a total under 85, sends the section back for revision before the plan is emitted.

## Anti-patterns refused

- Generic genome: rules like "uses descriptive names" that read identically for any repo. Refusal: apply the specificity gate; sharpen with a project value or delete the line.
- Formatter parroting: prose conventions restating what Prettier, Black, or gofmt already rewrite. Refusal: the genome says "run X" and spends its lines only on what no tool enforces.
- Retro-extraction deferral: "we will extract the style once there is code." Refusal: CODEDNA.md is a wave-one scaffold task; the genome exists before the first source file.
- Paper genome: a profile document nothing enforces. Refusal: the plan must wire the diff-check step (R-DNA-18) or the enforcement rubric dimension scores zero.
- Uniform-consistency enforcement: flattening characteristic inconsistencies into one rule, itself a catalogued AI tell. Refusal: plan a known-inconsistencies ledger and the local-dialect-wins rule instead.
- Vocabulary drift and parallel utilities: a second formatDate, user and account used interchangeably. Refusal: idiom registry with named paths plus a glossary with banned synonyms; duplicates fail review.
- Docstring-everything boilerplate: @param/@returns on every function by default. Refusal: doc scope is an explicit decision; the default is public API only.
- Brownfield invention: writing a genome from taste instead of evidence. Refusal: layered fingerprint first (configs, then measured frequencies, then close read with quoted snippets); numbers are evidence to interpret, and when they disagree with the code, trust the code.
- Stale genome: a profile whose date predates a deliberate style shift, silently mismatching new code. Refusal: stamp version and date, name refresh triggers, mandate re-ratification after them.
- False tells: an anti-tells list so generic that checks flag correct code. Refusal: the appendix contains only deviations this project actually makes, each citing its catalog number; a false tell is as unhelpful as a missed one.
- Eyeballed numbers: "median under 10 lines" produced by reading five files and estimating. Refusal: brownfield numbers come from the stats run and are quoted; greenfield numbers are declared as targets with the run that will confirm them.
- Unrunnable enforcement: an enforcement task whose Verify is a reminder to review the diff carefully. Refusal: the command's exit code proves the check is wired, or R-DNA-18 is not satisfied.
- Prose that duplicates the config map: a genome rule restating a convention the map already assigns to a formatter. Refusal: the map is the source of truth for enforced conventions and the genome spends its lines only on what no tool settles.
