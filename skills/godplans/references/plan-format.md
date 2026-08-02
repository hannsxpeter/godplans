# PLAN.mdx format contract

The canonical output of godplans is `.godplans/PLAN.mdx`. Every emission also copies the self-contained validator to `.godplans/validate-plan.sh`, so a standalone plan carries its machine gate without requiring godplans to remain installed. A PLAN without that executable, byte-identical companion is an incomplete emission and must not be presented. This module is the binding contract for the plan: structure, task grammar, visual layer, MDX safety, and the executor rules embedded in every plan. Read this whole file before assembling a plan; do not author the plan from memory of it.

## Why MDX, and the GFM-safe rule

The plan ships as `.mdx` so it drops straight into MDX pipelines (Docusaurus, Nextra, Fumadocs) and MDX-native plan viewers. But the body is written **GFM-safe**: plain GitHub-flavored markdown that is simultaneously valid MDX. No JSX components, no ESM imports, no expressions. The same bytes parse as `.mdx` and render as `.md`. A user who wants GitHub's rich rendering renames the file to `PLAN.md` and loses nothing.

GFM-safe means these MDX hazards are banned in prose:

- No bare `<` followed by a letter (MDX reads it as a JSX tag and fails). Write `less than`, or put the expression in backticks.
- No bare `{` or `}` in prose (MDX reads them as expressions). Put anything with braces in backticks or fenced code.
- No capitalized tag-like tokens such as writing a generic type without backticks. All code fragments, generics, paths, and shell snippets go in backticks or fences, where MDX leaves them alone.
- HTML comments do not survive MDX. Do not use them; the plan has no hidden content.

Also banned everywhere in the plan, matching godplans house style: em dashes, en dashes, Unicode arrows (ASCII `->` only), box-drawing characters, emojis, smart quotes, and the ellipsis character.

## Claims and evidence

A plan makes two kinds of statement, and they are held to different bars.

**A decision** is the plan's own choice. It needs a rationale, rejected alternatives, and a falsifier. Nothing outside the plan has to support it, because the plan is where it becomes true.

**A claim about the world** is a statement about the existing codebase, the user's constraints, the platform, or a regime. It carries its source in the sentence: a repository-relative path with a symbol name or a verbatim anchor (never a bare line number, which does not survive a reformat), a command with its output, an external reference, or an explicit attribution to what the user said. A claim about the world with no source is a guess wearing a plan's clothes, and brownfield plans are made almost entirely of them.

Two rules follow, and both are violated more often than the ban on vague acceptance criteria:

- **An exhaustive or negative claim needs a command, not a file.** "Every handler validates its input", "no route bypasses the session middleware", "there are no other callers": a path citation resolves one symbol in one file and cannot carry any of those. Run the search and cite the command, narrow the claim to the set actually inspected, or mark it as an assumption with a validation task. This is the one class of claim that reads most confident and is checked least.
- **No number is invented.** Availability targets, recovery objectives, retention periods, error budgets, review cadences, latency thresholds quoted as existing behavior, and user counts are decisions somebody owns. A number is cited to a source, taken from the user's answer, or it belongs in `## Open Questions` with a recommended default. A threshold invented at plan time is quoted back six months later as though somebody had committed to it. A number the plan *chooses* is different and legitimate: it lands in `## Decisions` as a decision with a falsifier whose failure boundary is that same number.

## Frontmatter (machine state)

```yaml
---
name: <project-slug>
plan_version: 1
status: planning
created: YYYY-MM-DD
updated: YYYY-MM-DD
mode: greenfield
product_form: web-application
archetype: saas-dashboard
public_release: true
source_revision: 0123456789abcdef0123456789abcdef01234567
input_digest: sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
validated_at: 2026-07-13T12:00:00Z
domains_applicable: [product, architecture, stack, database, security, ...]
domains_deferred: [observe]
domains_excluded: [seo, llm]
progress:
  phases_total: 0
  phases_done: 0
  tasks_total: 0
  tasks_done: 0
---
```

Allowed modes are `greenfield`, `brownfield`, and `replan`. Frontmatter is the digest, not the truth. The truth is the checkboxes; `progress` counters are derived from them and updated in the same edit that flips a box. `tasks_total` and `tasks_done` count active task definition header lines. `phases_total` counts numbered phase headings, and a phase contributes to `phases_done` only when every active task in it is checked. If counters disagree, recount from the task definitions. The three domain lists are an index into the applicability matrix, so each carries bare domain names in a single inline list and nothing else: the trigger and the reversibility reason live in the matrix row, which is the one place a domain's disposition is decided. The validator recomputes all three lists from the matrix and fails on any disagreement, the same parity it already enforces between the provenance block and its frontmatter values. A summary that can drift from the row it summarizes is a second source of truth waiting to contradict the first.

Allowed product forms are `web-application`, `api-or-service`, `cli-or-sdk`, `mobile-or-desktop`, `data-or-ml`, and `infrastructure-or-iac`. `public_release` is `true` only when execution can activate a public site, service, package, store artifact, model, or infrastructure surface. Internal and local-only projects set it to `false`; they do not inherit a public-activation gate.

`source_revision` is the full Git commit used for planning, or `none` when no revision exists. `validated_at` is a UTC ISO-8601 timestamp. The `## Plan provenance` values repeat those frontmatter values exactly, with no trailing punctuation. Its machine-readable inventory contains one or more lines shaped ``- `<label>` = `sha256:<64-lowercase-hex>` ``. Prefix a stable file artifact with `[recheck]` when phase-boundary drift checks must recompute it: ``- [recheck] `path/to/artifact` = `sha256:<64-lowercase-hex>` ``. A recheck label is a repository-relative file path, not an alias. Labels use only ASCII letters, digits, `.`, `_`, `/`, and `-`; labels are unique; and exactly one label is `intake`. Hash normalized intake text for `intake`, and hash raw file bytes for file entries. To derive `input_digest`, sort entries lexicographically by label, concatenate each as `<label><TAB><64-lowercase-hex><LF>`, hash the UTF-8 bytes with SHA-256, and prefix the result with `sha256:`. The `[recheck]` marker does not enter the digest. Inventory display order does not affect the aggregate. These values bind the plan to its inputs; they are not claims that later execution leaves the repository unchanged.

The status lifecycle is `planning -> approved -> executing -> done`:

1. A new or materially replanned document has `status: planning`. Validate it with `--allow-planning`, present it, and wait.
2. Only explicit user sign-off changes `planning` to `approved`. Update the date in the same edit.
3. The first executor runs `.godplans/validate-plan.sh` without `--allow-planning`, then changes `approved` to `executing` before starting GP work. An already `executing` plan may resume.
4. Change `executing` to `done` only after every task is checked and the final Verification phase passes. Use `--allow-planning` for the final structural validation because default mode is an execution gate.

A material replan restarts this lifecycle at `planning`, increments `plan_version`, and requires fresh sign-off. No executor may work from a `planning` or `done` plan.

## Document skeleton, in order

1. `# <Project> master plan` and a one-paragraph objective ending with an observable definition of done.
2. `## Scope and non-goals`. Non-goals are named, not implied. State the scale calibration, available capacity, phase and task ceiling, and the sum of task appetites. A weekend plan has at most 3 phases and 8 tasks.
3. `## Plan provenance`. Record the source revision, stable evidence inventory, digest algorithm and SHA-256 input digest, validation timestamp, and the completed or imported evidence that must be rechecked on resume.
4. `## Product form`. Name the primary form, its vertical-slice definition, form-specific completion evidence, and any secondary form that passes the independent-deliverable rule.
5. `## Compliance gate`. One short section: pass, or the mitigations injected (with task IDs).
6. `## Applicability matrix`. The full table: every domain marked applicable, deferred, or excluded. Deferred is reserved for the deferrable set named in `discovery.md` (seo, launch, observe, ui, deploy): the row names the trigger, an observable event that forces the domain pass, and argues why the decision is reversible until the trigger fires. Excluded rows carry three things in one cell, in this order: an evidence state (`absent:` for something checked, `by-design:` for something the plan settles; `unknown:` and `hint:` are refused because neither licenses an exclusion), a project-specific reason, and a `revisit when:` predicate that is observable on the same bar as a deferral trigger. An exclusion without a tripwire is permanent by accident. After the table, add the compact module disposition described below.

   ```markdown
   | llm | excluded | by-design: expense splitting is arithmetic, so no model call is planned; revisit when: any task adds a model SDK dependency, an inference endpoint, or a prompt template |
   ```

   The module disposition follows the table, one line per applicable module, naming which layer dropped anything it dropped:

   ```markdown
   ### Module disposition
   - security: landed R-SEC-1, R-SEC-4, R-SEC-12; dropped-by scale R-SEC-22 (side-project: no SOC 2 program)
   - ui: landed R-UI-2, R-UI-9; dropped-by archetype R-UI-14 (stock primitives, no design system to publish)
   ```

   `dropped-by` takes exactly one of `scale`, `archetype`, or `form`, and carries a parenthetical reason. A requirement listed as dropped may not appear on any task's `Requirements:` line, and the two lists in one module line may not overlap. Naming the dropping layer is what separates a decision from an oversight: without it, a requirement cut to fit a weekend appetite is indistinguishable from one nobody considered.
7. `## Decisions`. Hard-to-reverse bets first: wire formats, public identifiers, data-model shape, auth and ownership boundaries. Each entry is a decision with rationale, a hypothesis with a validation plan, or a pointer to Open Questions. Where options were weighed, show the comparison in a small table. Every `### D<n>` decision entry carries this structured falsifier:

   ```markdown
   Falsifier:
   - Signal: p99 read latency for the largest tenant from the production query span
   - Failure boundary: p99 exceeds 250 ms for seven consecutive days
   - Replan action: return to planning and evaluate schema-per-tenant against the rejected shared-table design
   ```

   `Signal` names observable evidence, `Failure boundary` states the event or numeric threshold that kills the decision, and `Replan action` names what is reconsidered after returning to planning. A falsifier that can never fire is decoration. Hypotheses in the assumptions ledger need no falsifier block; their validation task already is one. Each ledger entry does carry its price:

   ```markdown
   ### Assumptions ledger
   - A1: a workspace's data is never visible across workspaces (assumed; no cross-org reporting was described)
     - Blast radius: wrong costs +6 tasks and +1 phase; per-object ACLs replace workspace-scoped RLS, rewriting GP-201 and every Phase 4 query
     - Validated by: GP-108
   ```

   `Blast radius` is counted in tasks and phases the plan would gain or lose, never in adjectives. "Significant rework" is refused. `+0 tasks` is a legitimate and useful answer: it tells the user which assumptions to stop worrying about.
8. `## Requirements`. Numbered user stories with EARS acceptance criteria: `R-1.1: WHEN <trigger> THE SYSTEM SHALL <observable behavior>`. A compact table is also valid when the requirement ID is the first cell of each row. Task `Requirements:` lines point here and at module IDs (R-SEC-4 style).
9. `## Architecture`. The mermaid visuals (see Visual layer) plus the prose that the diagrams support.
10. `## Style genome`. Naming, idioms, structure conventions the first commit must already follow.
11. `## Agent memory`. The AGENTS.md and pillar files the scaffold phase will emit.
12. `## Documentation set`. Exactly one such section. The manifest of documents this project owes, what it does not owe, and what would reverse each of those answers. See Documentation set grammar below and `doc-set.md` for the catalog and the selection rules.
13. `## Phases`. The task body; see Task grammar.
14. `## Open Questions`. Exactly one such section, at the bottom, the only enumeration of open decisions. Committed decisions never appear here. A complex plan with zero open questions is acceptable only when every meaningful decision has been explicitly made above; the legal empty form is a body of exactly `None.`. Otherwise every entry is a decision ticket in the grammar below. When every listed option is a variant of one framing, the question also names the option from outside that framing, or states that none survived and which constraint eliminated it; options that only vary a dial are a menu, not a set of alternatives.
15. `## Rules for executing agents`. Copied verbatim from this module (below).
16. `## Session log`. Append-only, one line per session.

## Documentation set grammar

One table, one boundary statement, and nothing else. Read `doc-set.md` before authoring it; that file carries the catalog, the ten lifecycle stages, the durability contract, and the selection rules this grammar renders.

```markdown
## Documentation set

This manifest covers documentation committed to this repository. Documents that live in a wiki, an intranet, or a compliance platform are marked present-elsewhere and are not planned here.

| Document | Stage | Verdict | Owner | Selected by, or reason and revisit when |
|---|---|---|---|---|
| decide.adr | decide | required | architecture | always; ADR-001 through ADR-003 land in GP-104 |
| build.config-reference | build | required | stack | the service reads 11 environment variables; written by GP-207 |
| assure.threat-model | assure | required | security | session auth plus stored personal data; written by GP-306 |
| operate.recovery | operate | recommended | deploy | durable user data exists; offered as GP-402 |
| serve.support-policy | serve | not-applicable | launch | by-design: no paying users at side-project scale; revisit when: the plan adds a billing route or a paid tier |
| verify.traceability | verify | not-applicable | roadmap | absent: no external authorizer was named in discovery; revisit when: a customer contract or a regulator requires an audit trail |
```

Grammar rules:

- **Document**: a catalog id from `doc-set.md` section 5. An id outside that catalog is refused; extend the catalog instead of inventing a row, because an id nobody else uses cannot be cross-referenced.
- **Stage**: one of the ten in `doc-set.md` section 2.
- **Verdict**: `required`, `recommended`, `optional`, or `not-applicable`.
- **Owner**: the module that plans the artifact, from the catalog. Exactly one module owns a document, so two passes never both plan the same file. A repo-pass task that writes an architecture-owned document is a boundary violation, not a convenience.
- **Last cell**: for a selected row, what selected it plus the GP task that writes it, so the manifest is checkable against the phases. For a `not-applicable` row, an evidence state (`absent:` or `by-design:`), a reason, and a `revisit when:` predicate, on the same bar as an excluded applicability row. `unknown:` and `hint:` are refused here for the same reason they are refused there.
- **Every required row names a task.** A required document with no GP number is a promise the plan does not keep.
- **Brownfield and replan** additionally record state, so the action is a lookup rather than a judgment: an existing and current document is `adopt` (frontmatter only, no task), a drifted one is a refresh task, and a document the profile does not justify is an `orphan` row with a question, never a deletion task. The full lattice is `doc-set.md` section 6.
- **No invented numbers.** Review cadence, retention, recovery objectives, availability targets, and support windows are cited or they are open questions. A number invented at plan time becomes a commitment nobody made.

## Task grammar

Tasks live under phase headings, grouped into waves. The format is fixed; executors parse it.

```markdown
## Phase 2: Auth and accounts

Goal: a user can sign up, log in, and own their data. Blocks Phase 3.

### Wave 2.1

- [ ] GP-201 [W2.1] Create user model and migration
  - Files: src/db/schema/users.ts, migrations/0002_users.sql
  - Depends on: GP-104
  - Reuses: drizzle client from src/db/client.ts
  - Acceptance: schema exports `users` table; migration applies cleanly on empty db; email column has unique index
  - Verify: `npm run db:migrate && npm run db:check`
  - Requirements: R-2.1, R-DB-3, R-SEC-12

- [ ] GP-202 [P] [W2.1] Add password hashing helper
  - Files: src/auth/hash.ts, src/auth/hash.test.ts
  - Depends on: none
  - Reuses: shared error types from src/errors.ts
  - Acceptance: uses argon2id; test vector passes; no plaintext ever logged
  - Verify: `npm test -- hash.test.ts`
  - Requirements: R-SEC-6

Checkpoint: signup flow works end to end against a local db.
Checkpoint verify: `npm run test:e2e -- signup`

Must-haves:
- Truth: a new user row appears after signup (manual: `curl -X POST /api/signup`)
- Artifact: src/auth/hash.ts exports `hashPassword` and `verifyPassword`
- Link: signup route imports from src/auth/hash.ts, not an inline hash
```

Grammar rules:

- **IDs**: `GP-<phase><two digits>`, zero-padded, unique, stable forever. Never renumber. Uniqueness applies to checkbox task definition headers; dependency references do not create duplicate definitions.
- **`[P]`**: parallel-safe. Only when the task touches files disjoint from every other unchecked task in the same wave. The validator enforces this: a `[P]` task sharing a path with another unchecked task in its wave fails, because the marker is a promise an executor acts on by running the two at once. R-ROAD-8 and the fictional-parallelism refusal in `roadmap.md` state the same rule; this is where it is gated.
- **`[W<phase>.<wave>]`**: the wave tag. Waves within a phase run in order; tasks within a wave marked `[P]` may run concurrently.
- **Files**: exact paths. Brownfield plans name real existing files.
- **Depends on**: task IDs or `none`. No reflexive chains; a dependency exists because the work cannot start without it, not because the tasks are neighbors.
- **Acceptance**: 2 to 4 grep-verifiable or observable conditions. "Works correctly" is banned; "returns 401 without a session cookie" ships.
- **Verify**: one exact executable command whose exit code proves the task, in backticks. It must be safe and idempotent when rerun at a phase boundary; deployment, publication, destructive migration, or activation actions are task work, not verification. Manual-only Verify values are refused; wrap browser or device evidence in an executable harness.
- **Requirements**: comma-separated IDs from the Requirements section and domain modules. Every task traces to at least one requirement; a task tracing to nothing is scope creep.
- **Checkpoint**: every phase ends with one independently observable outcome and one `Checkpoint verify:` command whose exit status reproves it at the next phase boundary.
- **Must-haves**: goal-backward proof: observable truths, required artifacts, and key links showing the pieces are wired, because a checked box alone cannot distinguish a real implementation from a placeholder.
- The final phase of every plan is **Verification**: run the full test suite, lint, build, and at least one end-to-end smoke that names the real command or the exact manual path.

## Question grammar

R-PRD-10 requires every open question to carry an owner, a due date, a blocking
flag, and a recommended default. This is the shape those four fields take in the
document, so a reader can tell at a glance who has to answer, what stalls until
they do, and what happens if nobody does.

```markdown
## Open Questions

### Q1: Can a board be shared outside its workspace?
- Owner: product lead (the answer is theirs to give; the plan must not invent it)
- Blocks: build, from the start of Phase 4
- Decide by: 2026-08-14, the Phase 4 wave boundary
- Why it matters: a yes replaces workspace-scoped RLS with per-object ACLs, rewriting GP-201 and every Phase 4 query.
- Options: (a) no sharing outside the workspace; (b) read-only links with unguessable tokens; (c) full cross-workspace membership; (d) export a read-only snapshot, which moves sharing out of the permission model entirely.
- Recommended default: (b), which satisfies R-1.6 without per-object ACLs; the token table is additive, not structural, so taking it early costs nothing if the answer lands later.
```

Grammar rules:

- **IDs**: `### Q<n>: <the question>`, numbered from 1, unique, ascending. The heading is the question itself, phrased so its answer is a decision. The legal empty form for the whole section is a body of exactly `None.`.
- **Owner**: the role that answers. When the answer is not the agent's to give, say so on this line; an agent that answers a question owned by the user has not resolved it, it has guessed and hidden the guess.
- **Blocks**: `build`, `ship`, or `nothing`, with the boundary it blocks at. A question that blocks nothing still ships its default.
- **Decide by**: the exact moment the default fires: a date, a phase start, or a wave boundary. "Later" is refused.
- **Why it matters**: one line naming what changes on each answer.
- **Options**: at least two named alternatives. Where all options vary one dial, name the option from outside that framing or state which constraint eliminated it.
- **Recommended default**: the option the plan executes on if nobody answers, plus why taking it early is safe. This is what makes the plan executable without the answer.
- An unknown that **must** be settled before dependent work is not an open question. It is a flagged hypothesis in `## Decisions` whose R-ROAD-7 validation task is scheduled ahead of every task that assumes it, so the ordering is a real `Depends on` edge the validator checks. `## Open Questions` holds the residual: unknowns the plan can proceed past on a stated default.
- Resolving a question **deletes it from this section** and lands it in `## Decisions` as a `### D<n>` entry with a falsifier. A decision lives in exactly one place; a question that survives its own answer is duplication.

## Conditional public-release gate

When `public_release: true`, mark the latest hardening evidence task with `R-SEC-26`, exactly one prepublication gate task with `R-ROAD-21`, and exactly one first public activation task with `R-LAUNCH-22`. Keep those role markers on distinct tasks. The gate follows and depends on the latest hardening task. The activation task follows the gate immediately and depends on it. The gate records `checked_at`, `hardening_revision` (a content hash or immutable revision), `finding_counts`, `policy`, and `verdict`. `checked_at` must be later than the latest hardening evidence. Its acceptance states that a later hardening change `invalidates` the pass and forces the task to run again.

Every permitted Critical risk acceptance names `owner`, `justification`, `accepted_at`, and `expires_at`. Missing or expired fields block public activation. Projects with `public_release: false` state why no public surface exists and do not receive this task.

## Visual layer

Diagrams are mermaid in fenced blocks, GitHub-native. Use them where they carry decisions, next to the prose they support:

- `graph TD` for components and trust boundaries (annotate the boundary edges).
- `erDiagram` for the data model.
- `sequenceDiagram` for the one or two load-bearing flows.
- `gantt` for phase and wave sequencing when the plan has calendar pressure; otherwise skip it.

The visual-surface gate, inherited from visual-plan: backend-only and library plans get no decorative top diagram; visuals appear inline, local to the claims they support. UI-bearing plans may lead with a screen-flow diagram. Never render a default left-to-right box chain to look busy; a diagram that decides nothing is deleted prose.

Chat surfaces often show mermaid as a code block, so the surrounding text must stand alone; tables and dependency lists carry the same facts.

## Rules for executing agents

This block is copied verbatim into every emitted plan, under `## Rules for executing agents`, wrapped in a GFM alert:

```markdown
> [!IMPORTANT]
> This plan is the source of truth. The chat is not.
>
> 1. Before any work: read the frontmatter and `## Plan provenance`, then re-derive state from disk. Recheck recorded completed or imported evidence; if material evidence drifted, change status to `planning`, record the stale evidence, and stop for replan. Otherwise refuse unless `status` is `approved` or `executing`. `planning` awaits sign-off; `done` is closed. Run `bash .godplans/validate-plan.sh .godplans/PLAN.mdx`. If status is `approved`, change it to `executing` and update the date before the first task.
> 2. Find the first unchecked task in wave order. Re-derive state from checkboxes; trust nothing remembered.
> 3. One task at a time. Respect Depends on. Tasks marked [P] may run concurrently; the validator has already proved their Files lists are disjoint from every other unchecked task in the wave, so treat [P] as the schedulable set and never widen it by hand.
> 4. Run the task's Verify command. Only after it passes, flip [ ] to [x] and update the frontmatter counters and `updated:` date in the same edit. Never batch check-offs. Regenerate the sidecar in the same batch: `bash .godplans/validate-plan.sh --allow-planning --emit-json .godplans/PLAN.json .godplans/PLAN.mdx`.
> 5. If Verify fails: the box stays unchecked. Append an indented `- Note (YYYY-MM-DD):` line under the task saying what happened.
> 6. Phase-boundary gate: before the first task of a new phase, run `bash .godplans/validate-plan.sh --drift-check N .godplans/PLAN.mdx`, replacing N with the completed phase. The command recomputes `[recheck]` provenance files, reruns a deterministic sample of up to three completed task Verify commands, and reruns the phase's Checkpoint verify command. Any failure returns status to `planning` and stops execution for replan.
> 7. If a deferred domain's trigger fires mid-execution (its named event occurs), return status to `planning` and run that domain's pass before continuing.
> 8. Scope changes are not improvised. Return status to `planning`, patch the plan (new task IDs, struck-through superseded tasks with a reason), increment `plan_version`, and obtain fresh approval before more execution.
> 9. Never renumber, reword, or uncheck a completed task.
> 10. At session end: append one line to `## Session log`: date, tasks completed, where you stopped, what is next.
> 11. Re-read the current phase before starting it; re-read Decisions before touching anything they govern.
> 12. After every task is checked and the final Verification phase passes, change status from `executing` to `done`, update the date, and run `bash .godplans/validate-plan.sh --allow-planning .godplans/PLAN.mdx` for a final structural check.
```

## Machine checks

The emitted companion is the only machine-check entry point. Copy it byte-for-byte from the skill before the first validation, then run:

```bash
bash .godplans/validate-plan.sh --allow-planning .godplans/PLAN.mdx
```

The companion embeds the domain requirement catalog and reads no skill files at runtime. Before this command, verify `test -x .godplans/validate-plan.sh` and compare the companion byte-for-byte with the installed source. `--allow-planning` performs structural validation for a draft or closed plan. Without it, the validator is also an execution gate and accepts only `approved` or `executing`. It checks essential frontmatter, provenance parity and aggregate input digest, product form, conditional public-release gate structure, and lifecycle values; derived task and phase counters; sequential phase numbers and matching wave tags; unique IDs on task definition headers; all required task fields; earlier dependency targets; local and module-catalog requirement references; every applicability-matrix domain exactly once, deferral only for the reversible set, deferred triggers and reversibility reasons, and excluded rows carrying an accepted evidence state, a reason, and an observable `revisit when` predicate; the module disposition grammar, including the `dropped-by` layer name and the rule that a dropped requirement appears on no task; parity between the three frontmatter domain lists and the matrix rows they index; disjoint file sets for `[P]` tasks against every other unchecked task in their wave; the three-field `Falsifier:` block on every `### D<n>` decision entry; documentation-set rows for catalog ids, known stages and verdicts, a task reference on every required row, and the same tripwire grammar on every not-applicable row; phase Checkpoint and Checkpoint verify lines; banned Unicode through portable Perl; exactly one Plan provenance section; exactly one Applicability matrix section; exactly one Decisions section; exactly one Documentation set section; exactly one Open Questions section; and a final Verification phase. `--drift-check N` adds the explicit execution-time recheck for a completed phase. Its Bash 3.2 and portable Perl implementation runs on stock macOS and Linux. Any failure blocks emission. Do not replace this command with ad hoc grep pipelines.

## Machine-readable sidecar

`--emit-json PATH` writes a generated JSON view of the plan after a successful validation:

```bash
bash .godplans/validate-plan.sh --allow-planning --emit-json .godplans/PLAN.json .godplans/PLAN.mdx
```

PLAN.json carries the frontmatter, applicability rows, decision falsifiers, progress counters, phases, active tasks, superseded tasks, and cumulative supersession metrics (with `depends_on` and `requirements` as arrays, and `parallel` carrying the validated `[P]` marker so a runner can schedule a wave without re-deriving which tasks are safe to run at once) so executing agents and tooling never parse MDX checkboxes. It is generated atomically and never hand-edited: any plan edit regenerates it with the same command. Its `plan_digest` field is the SHA-256 of the PLAN.mdx bytes at generation time; a consumer recomputes the digest before trusting the sidecar and regenerates on mismatch. The plan remains the only source of truth; the sidecar is a derived view, and the validator regenerates it only from a plan that passes every structural check.

The published schema is `schemas/PLAN.schema.json`. Consumers validate the sidecar against it before scheduling work, then verify `plan_digest` against the PLAN.mdx bytes.

## Size discipline

The plan is re-read every session; bloat is a tax on every future turn. Budgets: objective under 150 words; no phase over 12 tasks (split it); no more than 7 phases before considering a second milestone plan; Open Questions under 10 entries (more means discovery is not done); Session log lines under 140 characters. When a plan outgrows these budgets, open a second milestone plan instead of growing this one. Completed phases stay in the live plan, archived in place and never overwritten, as R-ROAD-18 requires; what goes to `.godplans/archive/PLAN-v<n>.mdx` is a whole superseded plan version, snapshotted on replan and never edited down. Cutting finished phases out of the live plan would delete the execution history the drift check and the supersession metric read.

## Replan protocol

When PLAN.mdx already exists: read it fully, recount progress from checkboxes, read the session log, and recompute the source evidence recorded under `## Plan provenance`. Recheck every artifact recorded as completed or imported. If its content, revision, or existence changed materially, mark the plan stale by returning `status` to `planning` before applying the delta; do not trust the chat or old validation timestamp. Completed work is history and never altered. New work gets fresh IDs continuing the sequence. Superseded unstarted tasks are not deleted. Strike only the heading (`~~- [ ] GP-310 [W3.1] Old work~~`), then retain `  - Superseded: <one-line reason>` and `  - Requirements: <original ids>` so the audit trail and domain metric survive. Refresh the evidence inventory, `input_digest`, and `validated_at`; bump `plan_version`; log the delta in the session log; and re-run the Phase 6 audit on any section that changed.

Measure the outgoing plan before patching it: run `scripts/plan-halflife.sh .godplans/PLAN.mdx .godplans/PLAN.metrics.json`. The report records active, superseded, and historical tasks, plus cumulative supersession and survival rates overall and per requirement domain. A domain whose tasks are struck repeatedly was over-planned at that scale; shrink its appetite on the next pass instead of reseeding the same tasks.

Re-evaluate every tripwire on the way in, before anything else. An excluded domain whose `revisit when` predicate has become true, and a not-applicable documentation row whose predicate has become true, are the reason to replan at all, so they lead the delta rather than trailing it. A predicate that is true now is reported; one that is merely being watched is not.

Report drift as leads, not as findings. `--drift-check` recomputes digests and reruns sampled commands, which establishes that something changed and never why. A recorded artifact whose hash moved may be a real regression, a reformat, or a rename, and presenting the three as one verdict trains the reader to skip the section. Name what changed, name what it might mean, and leave the judgment where the evidence is.
