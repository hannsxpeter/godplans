# Contributing to godplans

Thanks for wanting to improve godplans.

One thing to know before you start: **this is a prompt-engineering repository, not a
normal codebase.** The product is markdown that steers AI coding agents. There is no
application to run, no framework to learn, and no build step to fight. If you can write
carefully and read a shell script, you can contribute here.

That also means the review bar is about discipline rather than tooling. A change lands
when it makes an agent produce a better plan, and when a script can prove it.

## The five-minute orientation

| Question | Answer |
|---|---|
| Where does the actual product live? | `skills/godplans/SKILL.md` and `skills/godplans/references/` |
| What is `PROMPT.md`? | Generated output. Never hand-edit it. |
| What are `.agents/`, `.claude/`, and `plugins/godplans/skills`? | Symlinks to the canonical skill. Never edit through them. |
| What do I need installed? | Bash, Perl, Python 3, git, and Node.js with npm (CI uses Node.js 24 and Python 3.13). `npm run release:check` also needs an authenticated `gh` and the pinned skills-ref validator. |
| How do I know my change is valid? | `npm run generate`, then `npm run check` |
| What gets rejected most often? | Prose that would read equally true for any other project |

## Ground rules

1. **The canonical skill lives at `skills/godplans/`.** `.agents/skills/godplans`,
   `.claude/skills/godplans`, and `plugins/godplans/skills` (which points at
   `skills/`) are symlink projections; never edit through them.
2. **PROMPT.md is generated, and so are two other files.** `npm run generate`
   rebuilds, in dependency order, the validator's requirement and
   documentation catalog tables (`npm run catalog`), PROMPT.md
   (`npm run build:prompt`), and `evals/metrics/context-cost.json`
   (`npm run metrics:context`). Run it and commit what it rewrites after you
   change `skills/godplans/SKILL.md`, a core (inlined) reference, the PLAN
   template, `validate-plan.sh`, `plan-halflife.sh`, a plan requirement in any
   module, a `doc-set.md` catalog row, or any other reference module (the
   context metrics hash every module). The published PROMPT.md is the slim
   core; use `bash scripts/build-prompt.sh --full` only for a one-off
   all-module artifact.
3. **Style and product contracts are mechanically enforced.** Run
   `npm run check` before pushing. ASCII punctuation only: no em or en dashes, no Unicode
   arrows (write `->`), no emojis, no smart quotes, no box-drawing
   characters. CI fails on violations.
4. **The 19 domain modules follow the six-section contract**: Lineage,
   Decisions to force, Plan requirements, Task seeds, Self-audit rubric,
   Anti-patterns refused. The five contract modules (`plan-format`,
   `discovery`, `compliance`, `exemplar`, `doc-set`) are exempt. The linter
   checks presence (`modules-complete`) and that every domain module is wired
   into the SKILL.md Phase 4 table, the validator tables, the prompt build,
   the context metrics, the template and discovery matrices, and the schema's
   row count (`domain-parity`); reviewers check substance.
5. **Every plan requirement must be checkable.** A requirement whose
   violation cannot be detected by reading a plan is opinion, not a
   requirement; it will be asked to change.
6. **The substitution test applies to contributions too.** Prose that reads
   equally true for any skill (or any project) is filler and gets cut.
7. **Behavior changes need regression evidence.** Installer, prompt, validator,
   and evaluation-harness behavior gets a shell regression test. Planning
   behavior changes add or tighten a case under `evals/cases/`. A new case is
   its directory (`REQUEST.md`, `REQUEST.baseline.md`, `EXPECTATIONS`) plus one
   line in `evals/cases-roster.txt`; `npm run check` fails when the two
   disagree, and the release matrix refuses to run.
8. **The skill description has one source.** Change the `description` in the
   SKILL.md frontmatter first (one double-quoted line, at most 1024
   characters), then copy it verbatim into
   `plugins/godplans/.claude-plugin/plugin.json` and the godplans entry in
   `.claude-plugin/marketplace.json`. The `description-parity` lint check
   fails on any difference.

### What the substitution test means in practice

Swap the project name into your sentence. If it stays true, the sentence says nothing.

- Rejected: "This makes the security module more robust and comprehensive."
- Accepted: "The security module accepted `rate limiting: yes` with no limit, window,
  or scope, so a plan could satisfy it without deciding anything. It now requires all
  three."

The second sentence names the failure, so a reviewer can check whether the fix
addresses it. That is the whole test.

## Making a change

1. Fork, branch from `main`.
2. Make the change in the canonical files.
3. If you changed anything ground rule 2 lists: `npm run generate`.
4. `npm run check` until green. It runs `version:check`, `catalog:check`,
   `metrics:check`, every lint check except the release-only
   `tag-release-parity`, and the test suite, which includes the lint self-test
   (`tests/lint-selftest.sh` injects a violation for every lint check, one case
   at a time, and expects each to fail). Release changes also run the pinned
   official validator through `npm run release:check`; see
   [docs/RELEASING.md](docs/RELEASING.md).
5. If behavior changed: add a CHANGELOG entry under a new version heading and
   bump every published version surface: SKILL.md frontmatter and body, the
   top CHANGELOG.md entry, package.json, marketplace and plugin metadata, the
   PLAN template, the README version badge, and the generated PROMPT.md.
   `npm run check` catches any disagreement: `version:check` and the
   `version-parity` lint check compare the surfaces, and the `prompt-fresh`
   lint check catches a PROMPT.md that was not regenerated. Do not edit those
   by hand: bump `package.json`, then run `npm run version:sync`, which writes
   the version into every surface except CHANGELOG.md and regenerates
   PROMPT.md and the context metrics.
   `npm run release:prepare -- <patch|minor|major|X.Y.Z>` does the bump and the
   sync in one command and, when CHANGELOG.md has no heading for that version,
   stubs an entry for you to fill in.
6. Open a PR describing what planning failure the change prevents or what
   audit dimension it strengthens. "Makes it better" is a substitution-test
   failure.

Maintainers follow [docs/RELEASING.md](docs/RELEASING.md) for versioned releases
and [MAINTAINING.md](MAINTAINING.md) for recurring maintenance.
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) maps the pieces and how each
source flows through a generator to the artifacts and checks that depend on it,
and [docs/DRIFT.md](docs/DRIFT.md) is the log of drift that reviews found.

## Good first contributions

If you want to help but do not have a specific fix in mind, these are the most useful
places to start:

- **A domain module that missed a check.** Read a reference module under
  `skills/godplans/references/`, compare it against the auditor it descends from, and
  name a check that never made it across.
- **A validator gap.** Write a `PLAN.mdx` fragment that is obviously wrong and watch
  `validate-plan.sh` pass it. That is a bug, and the fix comes with a regression case.
- **A behavioral case.** Add a request under `evals/cases/` whose plan output you can
  assert on deterministically, and list it in `evals/cases-roster.txt`.
- **Clarity in the docs.** The [README](README.md) and [docs/ABOUT.md](docs/ABOUT.md)
  should be readable by someone who does not write code. If a paragraph lost you,
  saying so is a real contribution.

## Reporting issues

Best issues name a concrete failure: "planned X, the emitted plan lacked Y,
the executing agent then did Z wrong." Attach the PLAN.mdx fragment when
possible (redact anything private).

Vague reports are still welcome, they just take longer to act on. "The plan felt
generic for my project type" is worth filing even without a diagnosis.

## Conduct and security

Issues, pull requests, and discussions follow the
[Code of Conduct](CODE_OF_CONDUCT.md); report conduct problems privately as the
Code of Conduct describes. If you find a way the skill's content or scripts could make an
agent take unsafe action, do not open a public issue: report it privately as
[SECURITY.md](SECURITY.md) describes.

## Scope

godplans plans; it does not build, deploy, or audit after the fact. Features
that make godplans execute plans, scaffold repos, or edit source will be
declined; that work belongs to the executing agent or to the sibling skills
godplans descends from.

This is not a judgment about the idea. It is a boundary that keeps the plan portable:
the moment godplans builds, plans stop surviving tool switches, which is the only
reason the plan is worth writing.
