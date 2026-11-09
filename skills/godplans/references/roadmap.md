# Roadmap and sequencing planning module

Turns the plan's work list into a capacity-honest, dependency-sorted, gate-driven schedule. The orchestrator loads this module during the domain pass when writing the Phases, waves, and tasks sections of PLAN.mdx. Applicable to every archetype and every mode (greenfield, brownfield, replan); sequencing is never excluded from the applicability matrix.

## Lineage

Descends from roadmap-ready (the ready-suite planning-tier sequencer) with kickoff-ready's orchestration ledger folded in. From roadmap-ready it inherits the three-label row test (grounded commitment, outcome-framed direction, or named open question), the capacity corollary (no dates without engineer-week math), the precision gradient across horizons, the 8-field milestone anatomy with binary gates, topological sequencing over the architecture DAG, the gated launch sub-tree with its D-calendar, and the downstream handoff discipline that lets build, deploy, observe, and launch work start without follow-up questions. From kickoff-ready it inherits filesystem-as-truth completion (done means the artifact exists on disk, non-empty, postdating the work), the seven-status ledger vocabulary, the ghost-handoff and rubber-stamp guards, the skip cascade, and the critical-finding gate that blocks launch past an open Critical security finding.

## Decisions to force

1. Phase chain and dependency spine. Question: what ordered chain of phases and component DAG fixes task order? Hard to reverse because every task's Depends on line and wave assignment derives from it; resequencing after execution starts orphans completed work and invalidates the progress counters. Options: full greenfield chain (requirements -> architecture -> stack -> scaffold -> build slices in topological component order -> deploy -> observe -> hardening -> launch (every launch task depends on the hardening checkpoint, R-ROAD-13) -> verification), or a brownfield gap-fill chain starting at the first missing artifact. Default: full chain for greenfield, gap-fill for brownfield.
2. Cadence model. Question: which named cadence governs wave size, appetites, and checkpoint rhythm? Hard to reverse because switching cadence mid-plan re-buckets every task and invalidates every appetite. Options: Shape Up 6+2, quarterly themes, SAFe PI, continuous delivery with a rollout calendar, milestone-based, or a declared hybrid; record the choice as an ADR-shaped paragraph with two rejected alternatives and a re-evaluation trigger. Default: Shape Up 6+2 for product builds; milestone-based for libraries and CLIs.
3. Capacity and parallelism ceiling. Question: how many concurrent tracks may one wave hold? Hard to reverse because [P] markers and wave packing assume the ceiling; overcommitting yields half-done slices in every phase, the worst position to recover from. Options: tracks equal to executing agents or engineers minus the non-project rotation share, with a serial-fraction estimate for reviews and coordination. Default: one track for a solo builder plus one [P] lane restricted to disjoint-file tasks.
4. Slip protocol. Question: when a phase overruns its appetite, cut scope or extend time? Hard to reverse because extend-by-default silently converts every later estimate to fiction; the rule must exist before the first overrun. Options: Shape Up circuit-breaker (re-shape smaller, never carry at full scope), hold-the-date only for named external commitments, extend-with-signoff. Default: cut scope.
5. Launch sequencing. Question: where does the launch block sit in the phase chain? Whether launch is planned at all is the applicability matrix's launch row (applicable, deferred with the discovery trigger, or excluded with an evidence state and a revisit when: predicate), and launch.md owns mode, tier, and the D-7 to D+7 runbook (R-LAUNCH-3, R-LAUNCH-19). Hard to reverse because readiness gates (observability-live, rollback-tested, runbooks-reviewed, support-briefed) must be scheduled as dated tasks weeks before D-0; bolting them on later either slips the date or ships a paper gate. Default: when launch is applicable, its readiness gates are dated tasks ahead of D-7; when it is deferred or excluded, the roadmap ends at deploy and carries the trigger as a re-plan trigger (R-ROAD-18).
6. Audience and public derivative. Question: who reads this plan, and does a redacted public roadmap exist from day one? Hard to reverse because capacity math, owners, and rabbit-hole notes cannot be unleaked. Options: internal-only, or mixed audience with a planned public derivative (no capacity math, no owner names, confidence bands softened, "won't" becomes "not planned"). Default: internal-only unless discovery says otherwise.

## Plan requirements

R-ROAD-1. PLAN.mdx records capacity before any dated commitment: executor count (engineers or agents), engineer-weeks per cycle, non-project rotation share, and a serial-fraction estimate for coordination overhead.
Criterion: WHEN any phase or task carries a calendar date, THE PLAN SHALL contain a capacity block whose math covers that date, and IF the capacity block is absent THE PLAN SHALL contain appetites and confidence bands only, with zero calendar dates.

R-ROAD-2. PLAN.mdx declares its cadence model by name as an ADR-shaped paragraph: the chosen model, two rejected alternatives with reasons, and a re-evaluation trigger.
Criterion: WHEN the Phases section is written, THE PLAN SHALL name one cadence model and two rejected alternatives, and IF no trigger for revisiting the cadence is stated THE PLAN SHALL not pass self-audit.

R-ROAD-3. Every scheduled item passes the three-label test: a grounded commitment (date, scope, named reason, sign-off), an outcome-framed direction (target outcome plus appetite or confidence band), or a named open question with owner and review date. Bare feature names ("SSO", "dark mode") are banned as roadmap rows.
Criterion: WHEN an item appears in any phase, THE PLAN SHALL label it as exactly one of commitment, direction, or open question, and IF an item is a bare feature name with no outcome or appetite THE PLAN SHALL rewrite or delete it.

R-ROAD-4. Every phase and task anchors to an upstream artifact: a Requirements line (R-x.y), a named architecture component, or a named external constraint. Anchor-less items are speculative.
Criterion: WHEN a task is emitted, THE PLAN SHALL include a Requirements line or component reference on it, and IF no anchor exists THE PLAN SHALL cut the task or route it to Open Questions.

R-ROAD-5. PLAN.mdx sets its precision ceiling from upstream quality: full task decomposition only where requirements and architecture sections are complete; thin upstream caps the schedule at directional themes labeled as such.
Criterion: IF the requirements or architecture sections are absent or sketch-level, THE PLAN SHALL label its schedule directional, defer commitments, and state which upstream section must mature first.

R-ROAD-6. The task queue is topologically sorted over the dependency DAG and cycle-free: no task is scheduled before a task it depends on, and every Depends on line names an earlier GP id or none.
Criterion: WHEN tasks are ordered into waves, THE PLAN SHALL place every task after all of its dependencies, and IF a dependency cycle exists THE PLAN SHALL split a task to break it rather than emit an unsortable queue.

R-ROAD-7. Highest-risk unknowns come first: every hypothesis flagged in the Decisions section gets a validation task (spike, prototype, or measurement) scheduled in the earliest wave that its dependencies allow, before work that assumes the hypothesis.
Criterion: WHEN the Decisions section flags a hypothesis, THE PLAN SHALL schedule its validation task before any task that depends on the hypothesis holding.

R-ROAD-8. Parallelism never exceeds capacity: concurrent tracks per wave stay at or below the executor count from R-ROAD-1; [P] tasks within a wave touch disjoint file sets; an Amdahl note records the serial fraction and any shared-service bottleneck.
Criterion: WHEN a wave contains multiple tracks, THE PLAN SHALL keep tracks at or below capacity and mark parallel-safe tasks [P] only when their Files lines are disjoint.

R-ROAD-9. Items are fitted to appetites using a named prioritization framework (RICE, ICE, WSJF, MoSCoW, Kano, opportunity scoring, or appetite-first); oversized items are shrunk or deferred, never carried at full scope.
Criterion: WHEN items are ranked within a phase, THE PLAN SHALL name the framework used, and IF an item exceeds its appetite THE PLAN SHALL record the smaller version chosen or the deferral.

R-ROAD-10. Every phase carries full anatomy: a concrete name, a binary yes/no completion gate on its Checkpoint line ("improve X" is not a gate), a goal-backward Must-haves block (observable truths, required artifacts, key wiring links), enumerated in-scope items with anchors, a non-empty out-of-scope list with reasons, rabbit holes with smallest-version alternatives, and upstream phase dependencies.
Criterion: WHEN a phase is written, THE PLAN SHALL include all anatomy fields, and IF the out-of-scope list is empty or the gate is non-binary THE PLAN SHALL revise the phase before emission.

R-ROAD-11. The precision gradient holds across phases: the current cycle is fully decomposed into owned tasks with Files, Acceptance, and Verify lines; the next horizon holds directional themes with confidence bands; later horizons hold thematic outcomes only; when R-BIZ-3 lands, each theme and outcome names the register metric it targets. No day-level dates beyond the current cycle. Target dates carry a confidence band, range, or appetite, never a bare single-point date.
Criterion: WHEN phases beyond the current cycle are written, THE PLAN SHALL express them as themes or outcomes without day-level dates, and IF a later item carries a date or an early item carries only 30 percent confidence THE PLAN SHALL move it one horizon over.

R-ROAD-12. If the plan includes a launch, the launch block specifies: the R-LAUNCH-3 mode and tier, a confidence-banded target date, readiness gates each scheduled as a dated task (observability-live, rollback-tested, runbooks-reviewed, support-briefed), pre-launch dependencies, the R-LAUNCH-19 D-7 to D+7 calendar, external commitments, and a slip protocol defaulting to cut-scope with any hold-the-date exception named.
Criterion: WHEN a launch date appears anywhere in the plan, THE PLAN SHALL contain the full launch block with all readiness gates as tasks, and IF any gate task is missing THE PLAN SHALL remove the date until the gate is scheduled.

R-ROAD-13. Launch is gated on hardening: the first launch task depends on the security phase's findings check, and an open Critical finding blocks launch unless the plan records a risk acceptance that is dated, named, justified, and time-bounded. Regulated projects may tighten the gate to High findings.
Criterion: WHEN launch tasks are scheduled, THE PLAN SHALL make them depend on the hardening checkpoint, and IF a Critical finding is expected to remain open THE PLAN SHALL contain a complete risk-acceptance entry or hold the launch tasks.

R-ROAD-14. The task list doubles as the downstream handoff: each build task carries owner (or agent lane), appetite, requirement anchor, component anchor, Depends on, and phase; the deploy phase states cutover cadence and rollback posture; each phase's Must-haves name the SLOs the observability section will watch and, when R-BIZ-3 lands, the register metrics the phase is expected to move.
Criterion: WHEN the plan is emitted, THE PLAN SHALL let build, deploy, and observe work start from the task list alone without follow-up questions.

R-ROAD-15. Phase completion is artifact verification, never self-report: every Must-haves block names files that must exist on disk, every task's Verify line is an exact command whose exit code proves the acceptance, and the final phase is always Verification, running the full check suite and an end-to-end smoke test by its real command.
Criterion: WHEN a Checkpoint is declared passed, THE PLAN SHALL require the named artifacts to exist non-empty and the Verify commands to exit zero, and THE PLAN SHALL end with a Verification phase naming the real commands.

R-ROAD-16. Upstream prerequisites guard every phase: no phase starts before the artifacts of its upstream phases exist and verify; when an upstream section or artifact changes after downstream work began, affected downstream tasks are flagged for re-run with the choice of full cascade, selective re-run, or manual reconciliation recorded.
Criterion: WHEN a phase begins, THE PLAN SHALL have listed its upstream artifacts as dependencies, and IF an upstream artifact changes THE PLAN SHALL mark dependent unchecked-or-checked tasks for reconciliation instead of silently proceeding.

R-ROAD-17. The plan is a complete ledger: every planning domain appears as applicable, deferred with its trigger and reversibility argument, or excluded with an evidence state, a reason, and a revisit when: predicate (silence is not a status); every task failure path is defined (verification fails: box stays unchecked plus a dated note under the task; a retry budget, then human escalation); skipped work carries reasons and imported work carries source paths.
Criterion: WHEN any domain or task is not executed, THE PLAN SHALL show an explicit deferred, excluded, skipped, or failed record with reason, and IF a Verify command fails THE PLAN SHALL keep the checkbox unchecked and require a note.

R-ROAD-18. Governance is written down: a declared review cadence; an authority map stating who may change the current cycle (standing authority), the next horizon (at review, with broadcast), later horizons (with sign-off), and launch dates (escalation only), plus the commercial rows when R-BIZ-4 lands; named re-plan triggers and freeze conditions; per-session updated: bumps in frontmatter; completed phases archived in place, never overwritten.
Criterion: WHEN the plan is emitted, THE PLAN SHALL state review cadence, authority map, re-plan triggers, and the archive rule, and IF the updated: stamp is older than one cadence cycle at review time THE PLAN SHALL be flagged stale.

R-ROAD-19. The plan states its audience; if mixed (customers, partners, public), it schedules a redacted public derivative from day one with a mechanical redaction checklist: no capacity math, no owner names, no rabbit-hole specifics, confidence bands softened, "won't" phrased as "not planned", customer-value framing added.
Criterion: IF the audience is mixed, THE PLAN SHALL include a task producing the public derivative with the redaction checklist as its acceptance criteria, and THE PLAN SHALL never designate the internal file as the public one.

R-ROAD-20. Sign-off and retrospective are scheduled work: stakeholder attestations (product owner, eng lead, design if applicable, exec sponsor for launches, legal if regulated) appear as tasks before commitments harden, and a post-cycle retrospective task closes each cycle.
Criterion: WHEN a grounded commitment appears, THE PLAN SHALL schedule the sign-off attestation before it, and WHEN a cycle ends THE PLAN SHALL contain its retrospective task.

R-ROAD-21. If `public_release: true`, exactly one prepublication gate task cites this requirement. It follows and depends on the latest hardening task citing R-SEC-26, and the first public activation task citing R-LAUNCH-22 follows it immediately and depends on it. The gate records `checked_at`, a matching `hardening_revision` content hash or immutable revision, `finding_counts`, policy, and verdict; every permitted Critical risk carries owner, justification, accepted_at, and expires_at. A later hardening change invalidates the pass. Projects with `public_release: false` state the absence of a public surface and do not receive this gate.
Criterion: WHEN public activation is scheduled THE PLAN SHALL use distinct R-SEC-26, R-ROAD-21, and R-LAUNCH-22 task markers for hardening evidence, the prepublication gate, and first activation; SHALL place and link them in that order with no task between the last two; and SHALL block if the gate timestamp is not later than hardening, its revision does not match disk, a Critical is unresolved without a complete unexpired acceptance, or hardening changed after the check.

## Task seeds

- [ ] GP-xxx [W1.1] Validate riskiest hypothesis H-1 with a timeboxed spike
  - Files: spikes/h1-riskiest-assumption/README.md
  - Acceptance: README states the hypothesis, the method, and a line matching "Verdict: confirmed" or "Verdict: refuted"; Decisions section of PLAN.mdx updated with the outcome
  - Verify: grep -E '^Verdict: (confirmed|refuted)$' spikes/h1-riskiest-assumption/README.md
  - Requirements: R-ROAD-7

- [ ] GP-xxx Phase 1 checkpoint: verify must-haves on disk
  - Files: none (verification only)
  - Acceptance: every Phase 1 task checkbox is [x]; every artifact named in the phase Must-haves block exists non-empty
  - Verify: ! grep -q '^- \[ \] GP-xxx' .godplans/PLAN.mdx && test -s src/app/entry-point
  - Requirements: R-ROAD-10, R-ROAD-15

- [ ] GP-xxx Launch gate: confirm the rollback drill is dated inside the launch window
  - Files: none (verification only)
  - Acceptance: the deploy rollback doc (R-DEPLOY-16, R-DEPLOY-17) records the exact revert command and a drill date within the launch window (when deploy is deferred, the gate reads the R-PRD-17 rollback statement instead)
  - Verify: grep -E '^Last drilled: 20[0-9]{2}-[0-9]{2}-[0-9]{2}$' docs/deploy/rollback.md
  - Requirements: R-ROAD-12

- [ ] GP-xxx Fresh prepublication check against current hardening evidence
  - Files: docs/release/PREPUBLICATION.md
  - Depends on: GP-HARDENING
  - Acceptance: records checked_at later than hardening, hardening_revision matching current content, finding_counts, policy, and verdict; validates owner, justification, accepted_at, and expires_at for every permitted Critical risk; states that any later hardening change invalidates the pass
  - Verify: test "$(git hash-object docs/security/HARDENING.md)" = "$(awk '/^hardening_revision:/ {print $2}' docs/release/PREPUBLICATION.md)" && test "$(awk '/^verdict:/ {print $2}' docs/release/PREPUBLICATION.md)" = pass
  - Requirements: R-ROAD-13, R-ROAD-21

- [ ] GP-xxx Produce redacted public roadmap derivative
  - Files: docs/ROADMAP-PUBLIC.md
  - Acceptance: file contains no capacity numbers, no owner names, no rabbit-hole notes; contains "Not planned" section; internal file is not referenced
  - Verify: test -s docs/ROADMAP-PUBLIC.md && ! grep -qi 'engineer-weeks' docs/ROADMAP-PUBLIC.md
  - Requirements: R-ROAD-19

- [ ] GP-xxx Verification phase: full check suite plus e2e smoke
  - Files: none (runs checks)
  - Acceptance: lint, typecheck, unit tests, and the end-to-end smoke command all exit zero; results noted in Session log
  - Verify: npm run lint && npm run typecheck && npm test && npm run e2e:smoke
  - Requirements: R-ROAD-15

- [ ] GP-xxx Cycle retrospective and plan refresh
  - Files: docs/retrospectives/cycle-01.md
  - Acceptance: retro records what shipped versus planned, appetite overruns and the cut-scope decisions taken, and one sequencing change for the next cycle; PLAN.mdx updated: stamp bumped
  - Verify: test -s docs/retrospectives/cycle-01.md && grep -q 'updated:' .godplans/PLAN.mdx
  - Requirements: R-ROAD-18, R-ROAD-20

## Self-audit rubric

| Dimension | Points | Full marks require |
| --- | --- | --- |
| Grounding and classification | 15 | Every scheduled item passes the three-label test and carries a requirement, component, or external anchor; zero bare feature names |
| Capacity and cadence honesty | 15 | Capacity block with real numbers; cadence ADR with two rejected alternatives and a re-evaluation trigger; no date outside the capacity math |
| Sequencing correctness | 20 | Task queue topologically sorted and cycle-free; hypothesis validations in the earliest legal wave; [P] tasks file-disjoint; tracks within capacity; Amdahl note present |
| Phase anatomy and gates | 15 | Every phase has a binary Checkpoint, Must-haves block, anchored in-scope list, non-empty out-of-scope with reasons, rabbit holes, and dependencies |
| Precision gradient and ceiling | 10 | Current cycle fully decomposed; later horizons decay to themes then outcomes; ceiling matches upstream section quality; no day-level dates beyond cycle one |
| Launch and hardening gates | 10 | Public release has a fresh revision-bound prepublication task after hardening with complete risk-acceptance checks; non-public work records the exemption; launch block otherwise has its D-calendar and slip protocol |
| Executor handoff | 10 | An agent can start from the first unchecked task with no questions; every Verify line is an exact runnable command; final phase is Verification naming the real e2e command |
| Governance and freshness | 5 | Review cadence, authority map, re-plan triggers, freeze conditions, archive rule, and audience declared with the public-derivative decision |

## Anti-patterns refused

- Fictional precision: day-level dates beyond the current cycle or bare single-point dates. Refusal: replace with a confidence band or appetite and move the item out one horizon.
- Dates without capacity: calendar commitments while the capacity block is empty. Refusal: strip the dates, emit appetites, and add capacity to Open Questions with a default.
- Fictional parallelism: more concurrent tracks than executors, or [P] tasks sharing files. Refusal: repack waves to the capacity ceiling and serialize the overlap.
- Quarter-stuffing: every horizon filled to identical density and precision. Refusal: decompose only the current cycle; later phases decay to themes, then outcomes.
- Speculative items: rows with no requirement, component, or external anchor. Refusal: cut the row or route it back to the product section as an open question.
- Feature-factory rows: bare feature names with no outcome, appetite, or commitment label. Refusal: rewrite under the three-label test or delete.
- Dependency cycles: A depends on B depends on A anywhere in the task queue. Refusal: split a task to break the cycle; never emit an unsortable queue.
- Paper launch gate: a launch date with no observability-live, rollback-tested, or runbooks-reviewed tasks behind it. Refusal: schedule the gate tasks or remove the date.
- Stale prepublication pass: public activation trusts a check that predates or does not match current hardening evidence. Refusal: invalidate the pass and rerun the revision-bound gate immediately before activation.
- Ghost handoff: a phase scheduled before its upstream artifacts exist and verify. Refusal: add the upstream dependency line and a verification task ahead of the phase.
- Rubber-stamp done: a checkbox flipped without its Verify command run. Refusal: the executor rules bind check-off to a zero exit code in the same edit as the updated: bump.
- Phantom resume: a session acting on chat memory instead of the plan file. Refusal: executor rules require re-reading frontmatter and the first unchecked task before acting.
- Happy-path ledger: no policy for failed, skipped, or re-run work. Refusal: retry budgets, skip reasons, and the unchecked-box-plus-note convention are mandatory plan content.
- Shelf roadmap: no review cadence and no freshness stamps. Refusal: review cadence, updated: bumps, and re-plan triggers ship in the plan or the rubric fails it.
- Polish-indefinitely: extending past an appetite with no explicit decision. Refusal: the slip protocol defaults to cut-scope; any extension requires a named sign-off.
- Perpetual-now: the entire plan decomposed into the current phase with nothing beyond it, or its inverse, an all-Later plan with no executable first wave. Refusal: enforce the precision gradient in both directions before emission.
