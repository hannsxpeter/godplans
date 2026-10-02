# AGENTS.md

This repository ships the **godplans** Agent Skill: a planning superskill that
produces a comprehensive, audit-aware master plan (`.godplans/PLAN.mdx`) for a
software project before any code is written.

If you are an agent asked to plan a project: read
`skills/godplans/SKILL.md` and follow its method. The skill is also installed
via `.agents/skills/godplans` and `.claude/skills/godplans` projections in
consuming projects.

If you are an agent working on this repository itself:

- The canonical skill lives at `skills/godplans/`. It has three symlink
  projections: `.agents/skills/godplans` and `.claude/skills/godplans` point at
  it, and `plugins/godplans/skills` points at `skills/` for the Claude Code
  plugin. Edit the canonical files only; the `symlinks-valid` lint check
  covers all three links (run one check with `bash scripts/lint.sh <check>`).
- Three outputs are generated; never edit them by hand: `PROMPT.md`
  (`scripts/build-prompt.sh`), the `%catalog_max` and `%doc_catalog` tables in
  `skills/godplans/scripts/validate-plan.sh` (`scripts/build-catalog.js`), and
  `evals/metrics/context-cost.json` (`scripts/context-metrics.js`). After
  changing SKILL.md, a reference module, the PLAN template, the validator, or
  `plan-halflife.sh`, run `npm run generate`, which runs `npm run catalog`,
  `npm run build:prompt`, and `npm run metrics:context` in that order, then
  `npm run check`.
- Style and product contracts are mechanically enforced by `npm run check`:
  ASCII punctuation only, no em or en dashes,
  no Unicode arrows (write ASCII `->`), no emojis, no smart quotes, no
  box-drawing characters, in every authored file.
- Release-grade validation uses `npm run release:check` with the pinned
  official Agent Skills validator from `requirements/skills-ref.txt` and an
  authenticated GitHub CLI. Ordinary `npm run check` remains offline-friendly.
- The 19 domain modules under `skills/godplans/references/` follow a fixed
  six-section contract (Lineage, Decisions to force, Plan requirements,
  Task seeds, Self-audit rubric, Anti-patterns refused); the
  `modules-complete` lint check enforces it. The five contract modules
  (`plan-format`, `discovery`, `compliance`, `exemplar`, `doc-set`) are exempt.
  The `domain-parity` check confirms that every domain module appears in the
  SKILL.md Phase 4 table, the validator's domain and prefix tables, the prompt
  build, the context metrics, the portable-prompt test, the template and
  discovery matrices, and the schema's row count, with its own requirement
  prefix.
- The skill description lives in the SKILL.md frontmatter. Change it there
  first, then copy it verbatim into `plugins/godplans/.claude-plugin/plugin.json`
  and the godplans entry in `.claude-plugin/marketplace.json`; the
  `description-parity` lint check fails on any difference.
- Version appears in every published surface and must agree: SKILL.md
  frontmatter and body, the top CHANGELOG.md entry, package.json, marketplace
  and plugin metadata, the PLAN template, the README version badge, and the
  generated PROMPT.md. `npm run check` checks them together: `version:check`
  and the `version-parity` lint check compare the surfaces, and the
  `prompt-fresh` lint check catches a stale PROMPT.md. Never hand-edit a
  synced version string; bump package.json and run `npm run version:sync`,
  which writes every surface except the CHANGELOG.md heading
  (`npm run release:prepare -- <patch|minor|major|X.Y.Z>` does both and stubs
  that heading when it is missing).
- Never run `npm run eval`, `npm run eval:matrix`, `npm run eval:outcome`, or
  `npm run eval:external` without the maintainer's go-ahead. They invoke model
  CLIs and spend real model runs; the matrix alone runs every case, both arms,
  for at least three model families. `npm run check`, `npm run eval:check`, and
  `bash scripts/eval-matrix.sh --check` call no model.
- Maintainer rituals are in [MAINTAINING.md](MAINTAINING.md), the map of
  sources, generators, artifacts, and checks is in
  [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and the log of drift that
  reviews found is in [docs/DRIFT.md](docs/DRIFT.md).
