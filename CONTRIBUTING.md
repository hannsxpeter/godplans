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
| What are `.agents/` and `.claude/`? | Symlinks to the canonical skill. Never edit through them. |
| How do I know my change is valid? | `npm run check` |
| What gets rejected most often? | Prose that would read equally true for any other project |

## Ground rules

1. **The canonical skill lives at `skills/godplans/`.** The `.agents/` and
   `.claude/` directories are symlink projections; never edit through them.
2. **PROMPT.md is generated.** Change `skills/godplans/SKILL.md` or the
   inlined references, then run `bash scripts/build-prompt.sh` and commit
   the regenerated file. The published file is the slim core; use `--full`
   only for a one-off all-module artifact.
3. **Style and product contracts are mechanically enforced.** Run
   `npm run check` before pushing. ASCII punctuation only: no em or en dashes, no Unicode
   arrows (write `->`), no emojis, no smart quotes, no box-drawing
   characters. CI fails on violations.
4. **Reference modules follow the six-section contract**: Lineage,
   Decisions to force, Plan requirements, Task seeds, Self-audit rubric,
   Anti-patterns refused. The linter checks presence; reviewers check
   substance.
5. **Every plan requirement must be checkable.** A requirement whose
   violation cannot be detected by reading a plan is opinion, not a
   requirement; it will be asked to change.
6. **The substitution test applies to contributions too.** Prose that reads
   equally true for any skill (or any project) is filler and gets cut.
7. **Behavior changes need regression evidence.** Installer, prompt, validator,
   and evaluation-harness behavior gets a shell regression test. Planning
   behavior changes add or tighten a case under `evals/cases/`.

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
3. `npm run check` until green. Release changes also run the pinned official
   validator through `npm run release:check`; see [docs/RELEASING.md](docs/RELEASING.md).
4. If SKILL.md or an inlined reference changed: `bash scripts/build-prompt.sh`.
5. If behavior changed: add a CHANGELOG entry under a new version heading and
   bump every published version surface. The linter enforces parity across
   SKILL.md frontmatter and body, CHANGELOG.md, package.json, marketplace and
   plugin metadata, and the PLAN template. Do not edit those by hand: bump
   `package.json`, then run `npm run version:sync` to propagate it everywhere.
6. Open a PR describing what planning failure the change prevents or what
   audit dimension it strengthens. "Makes it better" is a substitution-test
   failure.

Maintainers follow [docs/RELEASING.md](docs/RELEASING.md) for versioned releases.

## Good first contributions

If you want to help but do not have a specific fix in mind, these are the most useful
places to start:

- **A domain module that missed a check.** Read a reference module under
  `skills/godplans/references/`, compare it against the auditor it descends from, and
  name a check that never made it across.
- **A validator gap.** Write a `PLAN.mdx` fragment that is obviously wrong and watch
  `validate-plan.sh` pass it. That is a bug, and the fix comes with a regression case.
- **A behavioral case.** Add a request under `evals/cases/` whose plan output you can
  assert on deterministically.
- **Clarity in the docs.** The [README](README.md) and [docs/ABOUT.md](docs/ABOUT.md)
  should be readable by someone who does not write code. If a paragraph lost you,
  saying so is a real contribution.

## Reporting issues

Best issues name a concrete failure: "planned X, the emitted plan lacked Y,
the executing agent then did Z wrong." Attach the PLAN.mdx fragment when
possible (redact anything private).

Vague reports are still welcome, they just take longer to act on. "The plan felt
generic for my project type" is worth filing even without a diagnosis.

## Scope

godplans plans; it does not build, deploy, or audit after the fact. Features
that make godplans execute plans, scaffold repos, or edit source will be
declined; that work belongs to the executing agent or to the sibling skills
godplans descends from.

This is not a judgment about the idea. It is a boundary that keeps the plan portable:
the moment godplans builds, plans stop surviving tool switches, which is the only
reason the plan is worth writing.
