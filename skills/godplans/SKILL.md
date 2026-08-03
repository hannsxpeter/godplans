---
name: godplans
description: "Produce an audit-aware, agent-executable master plan (PLAN.mdx) for a software project before application code is written. One command runs discovery, forces hard-to-reverse decisions, and plans product, architecture, roadmap, stack, repo, build, deploy, observability, launch, security, code quality, style genome, database, LLM integration, SEO, UI, UX, and agent memory upfront. After-the-fact audit checks become plan-time acceptance criteria, and a self-contained validator enforces task structure and approval state. Use when the user says: plan this project, godplans, master plan, plan everything upfront, idea to plan, plan before code, audit-aware plan, replan, or starts a greenfield project or major feature. Refuses plan theater (sections filled, decisions absent), vague tasks without verification, unsupported quality guarantees, and projects whose core purpose violates the Anthropic Usage Policy."
license: MIT
metadata:
  version: "1.12.0"
  author: aihxp
  homepage: https://github.com/hannsxpeter/godplans
---

> Invocation: `/godplans` in Claude Code, Cursor, VS Code, Zed, and Factory; `$godplans` in Codex; `@godplans` in Windsurf; auto-triggered elsewhere. Treat any text after the command as the argument: an idea, a path, or a constraint. There are no sub-commands.

# godplans

Plan everything before anything. godplans is a planning superskill: it runs the decision arc of a software project upfront and emits one master plan, `.godplans/PLAN.mdx`, whose decisions, hypotheses, open questions, tasks, and verification commands are explicit enough for a coding agent to execute checkbox by checkbox.

The core move is inversion. Auditors run after the work exists and tell you what is wrong. godplans takes the dimensions those auditors check (code quality, security, database, LLM integration, SEO, UI, UX) and the disciplines the arc tiers enforce (PRD, architecture, roadmap, stack, repo, build, deploy, observability, launch, hardening) and converts applicable checks into plan-time requirements with acceptance criteria on concrete tasks. This is designed to prevent avoidable findings and rewrites; it does not replace runtime verification or an independent final audit.

godplans descends from: hannsxpeter/arc-ready and hannsxpeter/ready-suite (the tier disciplines), hannsxpeter/codeauditor, secauditor, dbauditor, llmauditor, seoauditor, uiauditor, and uxauditor (the inverted audit dimensions), hannsxpeter/pillars (agent memory), hannsxpeter/codedna (style genome), BuilderIO visual-plan (plan discipline and the visual layer), and mattpocock/skills wayfinder (one fact in one place, and a frontier that is proved rather than asserted).

## Ground rules (non-negotiable)

1. **Planning is read-only.** Make no source edits while building the plan. The only files godplans writes are under `.godplans/`.
2. **Every plan element is exactly one of three things**: a grounded decision with rationale, a flagged hypothesis with a validation plan, or a named open question with a recommended default. Anything that is none of the three is theater; rewrite or delete it.
3. **The substitution test.** For any sentence in the plan, substitute a near-equivalent (a competitor, another framework, another product). If it still reads plausibly, it decides nothing specific and fails. Cut it or make it specific.
4. **Standalone-plan rule.** No revision language, no chat-context dependencies. A reader who never saw this conversation must understand the plan completely.
5. **Decide the hard-to-reverse bets first.** Wire formats, public identifiers, data-model shape, auth and ownership boundaries come before anything scoped or cosmetic. Every hard-to-reverse decision carries a `Falsifier:` block with `Signal`, `Failure boundary`, and `Replan action` fields. The block names what is observed, the event or measurement that proves the decision wrong, and the concrete return-to-planning action. A bet you cannot lose is not a bet.
6. **Reuse-first.** Every task names what it reuses (existing schema, components, helpers, services) before what it adds.
7. **Never pad, never stub.** No single-step plans, no filler sections, no placeholder content. If a domain does not apply, exclude it with a stated reason; do not fill it with generic prose.
8. **Read the module before authoring.** Each domain has a reference module under `references/`. Read it at the moment you author that plan section. Do not author from memory; the modules carry the inverted audit checks, and memory drifts.
9. **Compliance is standing.** Follow `references/compliance.md` for the whole session: never coach a model past a refusal, never route subscription OAuth outside official clients, and screen the project itself against the Anthropic Usage Policy before planning it.
10. **Absence of a look is never absence of a thing.** Every exclusion, of a domain or a document, records the evidence state behind it: `absent` when something checked and the reason names what checked, or `by-design` when the plan itself settles it. `unknown` and `hint` never exclude; they make the thing applicable or become an open question with a default. And every exclusion carries a `revisit when` predicate, because an exclusion with no expiry is a silence with a reason attached.
11. **No invented numbers.** Availability targets, recovery objectives, retention periods, error budgets, review cadences, and thresholds quoted as existing behavior are commitments somebody owns. Cite the source, take the user's answer, make it a decision with a falsifier boundary, or put it in Open Questions with a recommended default. A number invented at plan time gets quoted back later as though somebody had committed to it.

## Method

Run the phases in order. Do not skip a phase; a phase that does not apply still gets a one-line disposition so the trail is complete.

### Phase 0: Orient

Detect what exists. Look for:

- `.godplans/PLAN.mdx` -> **replan mode** (see Modes below).
- Source code (manifests like `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`) -> **brownfield mode**.
- Neither -> **greenfield mode**.

Record the mode. Bind the plan to disk evidence before planning: record the current Git revision when available, list the source and intake evidence used, compute a SHA-256 input digest, and record the UTC validation timestamp. In brownfield mode, fingerprint before planning: read the manifests, entry points, and directory shape, run `python3 scripts/style-stats.py .` for the measured style baseline, then close-read enough representative source to interpret it. The plan must extend what exists, not fight it. This pass is read-only. Record what the fingerprint did not reach as explicitly as what it found; a pass that never ran is not a pass that came back empty.

### Phase 1: Compliance gate

Read `references/compliance.md` and screen the project idea against it before investing in discovery.

- **Hard stop**: the core purpose is prohibited (fake-review farms, engagement bots, phishing kits, scrapers that evade platform safeguards, undisclosed AI passing as human, malware). Say plainly why, cite the policy category, and stop. Do not produce a plan.
- **Mitigate**: the project is legitimate but has a risky component (consumer chatbot, high-risk consumer domain, web automation, scraping). Continue, and inject the module's mitigation requirements into the plan as mandatory tasks.
- **Pass**: note "Compliance gate: pass" and continue.

The result, one short section, goes into the plan.

For a mitigate or pass result, create `.godplans/` and copy this skill's
`scripts/validate-plan.sh` into it immediately, before discovery or plan
authoring. Make it executable and confirm it is byte-identical to the resolved
skill source. Create the validator companion before drafting the plan. A hard
stop creates neither artifact.

### Phase 2: Intake and applicability

Read `references/discovery.md`. Establish:

1. **Product form**: web application, API or service, CLI or SDK, mobile or desktop, data or ML, or infrastructure or IaC. Pick this before archetype and domain composition because it defines vertical slices and completion evidence. Record secondary forms only when they have independent users, contracts, distribution paths, and deliverables.
2. **Archetype and overlays**: score the nine archetypes on weighted signals with vetoes, record primary, runner-up, margin, and the confidence those numbers give, and price what changes if the runner-up is right. Below the 0.45 floor the archetype is `unknown` and takes a slot in the question batch. Then add the overlays that fire (`ai-system`, `public-ui`, `shipped-artifact`, `operated-by-others`, `regulated-data`, `agent-skill-package`). An archetype says what this is; an overlay says what extra obligations it carries, and an overlay raises a domain's disposition and never lowers it.
3. **Applicability matrix**: every planning domain in the table below is applicable, deferred, or excluded. A CLI tool excludes seo and ui; it does not get empty SEO sections. An excluded row carries three things: the evidence state (`absent:` or `by-design:`), the project-specific reason, and a `revisit when:` predicate that would make the domain applicable again. Deferral is reserved for the deferrable set in the discovery module (seo, launch, observe, ui, deploy): the row names the observable trigger that forces the domain pass and argues reversibility until then. The matrix goes into the plan verbatim.
4. **Scale calibration**: weekend project, side project, funded product, or enterprise system. Requirements scale with the calibration; a guestbook does not get a compliance program. Weekend plans have at most 3 phases and 8 tasks. Treat that as a hard ceiling, not a target, and fit the total task appetites inside the user's stated capacity.

### Phase 3: Discovery

Read `references/discovery.md` for the interview protocol. Ask at most one batch of 3 to 5 high-leverage questions, each with a recommended default so the user can answer "defaults" and proceed. Everything not asked becomes a stated assumption in the plan, flagged as a hypothesis. Surface the hard-to-reverse bets now; they are the questions worth spending the batch on.

### Phase 4: Domain passes

For each applicable domain, in this order, read its module and author that plan section:

| Order | Domain | Module | Descends from |
|---|---|---|---|
| 1 | Product (PRD) | `references/product.md` | prd-ready |
| 2 | Architecture | `references/architecture.md` | architecture-ready |
| 3 | Stack | `references/stack.md` | stack-ready |
| 4 | Database | `references/database.md` | dbauditor |
| 5 | Security | `references/security.md` | secauditor, harden-ready |
| 6 | LLM integration | `references/llm.md` | llmauditor |
| 7 | UX | `references/ux.md` | uxauditor |
| 8 | UI | `references/ui.md` | uiauditor |
| 9 | SEO and AI visibility | `references/seo.md` | seoauditor |
| 10 | Code quality | `references/code-quality.md` | codeauditor |
| 11 | Style genome | `references/style-genome.md` | codedna |
| 12 | Agent memory | `references/agent-memory.md` | pillars |
| 13 | Repository | `references/repo.md` | repo-ready |
| 14 | Application build | `references/build.md` | production-ready |
| 15 | Roadmap and tasks | `references/roadmap.md` | roadmap-ready, kickoff-ready |
| 16 | Deployment | `references/deploy.md` | deploy-ready |
| 17 | Observability | `references/observe.md` | observe-ready |
| 18 | Launch | `references/launch.md` | launch-ready |

Each module gives you: the decisions to force, plan requirements, task seeds, a self-audit rubric (used in Phase 6), and anti-patterns. Apply them at the selected scale. Satisfy load-bearing requirements and record a compact module-level disposition for requirements excluded by archetype or scale. Do not instantiate a task seed merely because it exists. Weekend plans select only requirements that materially change product behavior, public compatibility, security, or verification within the stated appetite.

Excluded domains get one line in the applicability matrix and nothing else. Deferred domains get a matrix row, a trigger, and a reversibility argument, but no domain section or tasks until the trigger fires.

### Phase 5: Inversion pass

Walk every applicable module's Plan requirements section and give it one of three dispositions: landed somewhere concrete, deferred with a named trigger (deferrable set only, with the reversibility argument), or excluded with a specific archetype or scale reason in the compact module disposition. A landed requirement appears as a decision, an acceptance criterion on a task, or an entry in Open Questions with a recommended default. Distribute landed requirement IDs (R-PRD-3, R-SEC-12, R-DB-4) onto tasks via their `Requirements:` lines so traceability is grep-able. An applicable requirement with none of the three dispositions is a hole; fix it before Phase 6. Recount phases, tasks, and total appetite against the scale ceiling before continuing.

### Phase 6: Independent audit gate

The author does not grade the author. Run this phase under critic posture, in a turn separate from Phase 4 authoring, and where the harness allows it in an isolated context (a Claude Code subagent, a fresh Codex run, a new Cursor chat) given only the drafted `.godplans/PLAN.mdx` and the rubric text, with nothing carried from the authoring conversation. When no isolated context is available, run it as a distinct turn and record that the critic was not isolated.

**6a. Score.** Read `references/exemplar.md` first; it is the calibration for what full marks mean. Then score the draft against the landed requirement set for every applicable module, 0 to 100 per domain. Score the drafted text only: authoring intent is not evidence, and no section is credited for what it meant to say. Excluded rubric items do not enter the denominator only when their module disposition names a specific archetype or scale reason. Repair nothing while scoring; a critic that edits has become an author again.

**6b. Name every deduction.** Each lost point cites the section, quotes the sentence that lost it, names the rubric line, and states the points. A deduction with no quoted text is not a deduction, and those points are restored. Produce the complete scorecard before any revision.

**6c. Revise and rescore.** Any scored domain below 85: revise that section and rescore. Every revision quotes the deduction it answers. A rescore that raises a domain with no corresponding revision is a self-report and is discarded. Do not raise a score by adding work that breaks the scale ceiling; cut or consolidate first.

Print the scorecard in chat when done, including whether the critic ran isolated. A plan that would not survive its own descendant auditors does not ship.

### Phase 7: Emit and hand off

1. Read `references/plan-format.md` and `templates/PLAN.template.mdx`. Assemble `.godplans/PLAN.mdx` per that contract: frontmatter machine state, mermaid visuals where they carry weight, one Documentation set section, phases and waves, GP-numbered checkbox tasks with Files, Depends on, Reuses, Acceptance, Verify, and Requirements lines, one Open Questions section at the bottom, executor rules, session log.
2. Complete the three-artifact emission gate before any response: re-copy `scripts/validate-plan.sh` from this skill byte-for-byte to the pre-created `.godplans/validate-plan.sh`, make the companion executable, use `cmp -s` against that same resolved source path, then run `bash .godplans/validate-plan.sh --allow-planning --emit-json .godplans/PLAN.json .godplans/PLAN.mdx`. The emission is incomplete if PLAN.mdx, its executable validator, or PLAN.json is missing. The validator embeds its requirement catalog, validates provenance and conditional public-release gate structure, and must work without access to the installed skill on stock macOS and Linux. It is the machine gate; do not recreate its checks with grep. Fix every failure before presenting. PLAN.json is a generated, derived view; it is never hand-edited, and its `plan_digest` lets consumers detect staleness.
3. Present in chat: the objective, the mode and archetype, the applicability matrix, the scorecard, task and phase counts, the open questions with recommended defaults, and the executor protocol in three lines. Name every task, decision, and question you mention by its title, with the ID in support: "GP-204 wire session middleware into the API router", never a bare "GP-204". IDs are how the machine addresses the plan; a wall of them is how a human loses it. Presenting the plan is the sign-off request; wait for approval before anyone builds.
4. After explicit user sign-off, change `status: planning` to `status: approved`, update the date, and run `bash .godplans/validate-plan.sh .godplans/PLAN.mdx`. Do not start application work as part of approval.

Final artifact check: `test -f .godplans/PLAN.mdx && test -x .godplans/validate-plan.sh && test -f .godplans/PLAN.json`. Never present a plan until this command and the structural validator both exit zero.

## Modes

- **Greenfield**: the full method above.
- **Brownfield**: Phase 0 fingerprints the existing codebase first. The style genome is extracted, not invented; the stack section records what is and plans only deliberate changes; tasks reference real existing files. The plan extends the codebase, never restarts it.
- **Replan**: `.godplans/PLAN.mdx` exists. Re-derive state from disk: count checked and unchecked tasks, read the session log, and recompute the recorded source and completed-or-imported evidence. If material evidence drifted, treat the plan as stale and return it to `planning` before reconciliation. Completed tasks are never renumbered, reworded, or unchecked. New and changed work gets new task IDs. Superseded unstarted tasks are struck through with a one-line reason, not deleted. Before patching, run `scripts/plan-halflife.sh .godplans/PLAN.mdx .godplans/PLAN.metrics.json` on the outgoing plan. The report measures cumulative task survival and per-domain supersession rate; a domain struck repeatedly was over-planned at that scale, so shrink its appetite instead of reseeding the same tasks. Refresh provenance, bump the plan version, record the delta in the session log, regenerate PLAN.json, and require fresh approval before execution resumes.

## After the plan: execution

godplans plans; it does not build. The status lifecycle is `planning -> approved -> executing -> done`. A material replan restarts at `planning` and requires fresh approval. The emitted PLAN.mdx and `.godplans/validate-plan.sh` companion are self-sufficient: the plan carries its own executor rules and machine gate, so any coding agent (this one, or another tool entirely) can execute it without godplans installed. When the user asks you to execute a godplans plan, refuse unless frontmatter status is `approved` or `executing`, run `bash .godplans/validate-plan.sh .godplans/PLAN.mdx`, then follow the "Rules for executing agents" section inside PLAN.mdx itself. The first executor changes `approved` to `executing`; only a successful final Verification phase changes `executing` to `done`. When execution drifts from the plan, return it to `planning` and patch it (replan mode), because the document, not the chat, is the source of truth.

## What godplans refuses

- **Plan theater**: sections filled, decisions absent. Every section either decides something specific or names the open question.
- **Invisible plans**: prose that substitutes cleanly into any other project. Specificity is the discipline.
- **Vague tasks**: any task without grep-verifiable acceptance criteria and an exact verify command does not ship.
- **Feature laundry lists**: features without prioritization and sequencing are not a roadmap.
- **Scope leak at plan time**: godplans does not write application code, scaffold repos, or run deploys. It plans them.
- **Policy-violating projects**: the Phase 1 gate is not advisory. Prohibited purposes get a refusal with the policy category named.
- **Silent domain skipping**: a domain is planned now, deferred with an observable trigger and reversibility argument, or excluded with an evidence state, a reason, and a tripwire. Never silently absent.
- **Laundered gaps**: an exclusion, of a domain or a document, that reads like a considered decision because nothing records whether anyone looked. The evidence state and the `revisit when` predicate are what separate a decision from a silence, and both are machine-checked.
- **Invented numbers**: an availability target, recovery objective, retention period, or review cadence the plan made up so a section would be complete. Cite it, decide it with a falsifier, or ask it.
- **Ungated promises**: a marker an executor acts on that nothing verifies. `[P]` promises a task is safe to run beside its wave siblings, and the frontmatter domain lists promise they say what the applicability matrix says. Both are machine-checked, because a promise the machine does not check is a claim the plan makes on the executor's behalf.

## File map

| File | Role |
|---|---|
| `SKILL.md` | This orchestrator |
| `references/plan-format.md` | The PLAN.mdx contract: structure, task format, MDX safety, executor rules |
| `references/discovery.md` | Intake, archetype detection, applicability matrix, interview protocol |
| `references/compliance.md` | Anthropic Usage Policy gate and account-safety rules |
| `references/exemplar.md` | Worked GOOD and BAD plan fragments; the quality bar |
| `references/doc-set.md` | The documentation-set contract: catalog, lifecycle stages, durability, selection and exclusion rules |
| `references/<domain>.md` | 18 domain modules (see Phase 4 table) |
| `templates/PLAN.template.mdx` | The skeleton PLAN.mdx |
| `scripts/validate-plan.sh` | Self-contained validator copied beside each emitted plan |
| `scripts/plan-halflife.sh` | Replan metric generator for cumulative and per-domain task supersession |
| `scripts/style-stats.py` | Measured style baseline for the style-genome pass (naming histograms, comment density, function length) |
| `schemas/PLAN.schema.json` | Published JSON Schema for the generated PLAN.json sidecar |

## Skill version: 1.12.0
