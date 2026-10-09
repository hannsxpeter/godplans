# Product (PRD) planning module

Loaded first in the domain-pass order for every archetype: every project needs a problem, a user, and a definition of done before architecture or stack decisions are legible. This module tells the orchestrator what the Product sections of PLAN.mdx must contain so a prd-ready audit run at the end passes on the first try.

## Lineage

Descends from aihxp prd-ready, the top of the ready-suite planning tier. prd-ready exists to refuse the AI-slop PRD (every section filled, nothing decided) and enforces one core discipline: every sentence is exactly one of three things, a decision with rationale, a flagged hypothesis with a validation plan, or a named open question with an owner and a due date. godplans inverts prd-ready's audit checks (substitution test, MoSCoW caps, sourced metrics, ten-dimension NFRs, separate risk registers, downstream handoff pre-fill) into plan-time obligations, so the product content of PLAN.mdx is born already passing them.

## Decisions to force

Hardest to reverse first. Each must land in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default.

1. Who the single primary user is. Question: which one role, in which workday moment, under which constraint, is this for? Why hard to reverse: architecture entities, permission models, UI flows, and launch positioning all key off this identity; changing it mid-build is a pivot, not an edit. Options: (a) one named primary user, secondary users demoted to non-goals; (b) two co-primary users with an explicit conflict-resolution rule. Default: (a). Refuse "everyone who X" as a user definition.
2. What the problem is, stated without the solution. Question: what do users do today manually, how long does it take, what does it cost? Why hard to reverse: the problem statement is the scope boundary every later cut decision appeals to; a solution-shaped problem locks in the first idea. Options: (a) friction stated in the user's vocabulary against a named workaround (usually a spreadsheet or Notion page, not a rival product); (b) friction stated against a named competitor product. Default: (a); either way it must survive the substitution test against two named competitors.
3. How success is measured and where the numbers come from. Question: which at-most-5 metrics, with what targets, deadlines, and named instrumentation sources? Why hard to reverse: instrumentation must ship in the first build wave; redefining a metric mid-flight destroys the baseline and makes the 30-day retro unanswerable. Options: (a) one leading plus one lagging indicator with named events; (b) a fuller set up to 5. Default: (a) minimum, (b) allowed. Vanity metrics (raw signups, pageviews, downloads) are refused as primary metrics.
4. Appetite as a duration, not an estimate. Question: how much time is this worth (e.g. 6 weeks), after which scope gets cut rather than time extended? Why hard to reverse: appetite is the axiom the roadmap's cut decisions derive from; converting it to an estimate later flips the whole plan from scope-flexes to deadline-slips. Options: fixed appetite with scope flex (Shape Up) vs estimated timeline. Default: fixed appetite; a >50% appetite delta later triggers a replan.
5. The Must cap. Question: which requirements are genuinely Must? Why hard to reverse: the Must set defines the first release gate; an inflated Must tier silently converts the plan into a laundry list nobody can cut from. Options: cap Must at 50% of ranked requirements (hard cap 7 Musts) vs no cap. Default: the cap, with Should and Could tiers populated and Won't cross-linked to out-of-scope.
6. Change control and the fork threshold. Question: which post-approval edits replan, where are they broadcast, and what forces a rewrite rather than a patch? Why hard to reverse: without a declared rule, the first silent post-approval edit creates a moving-target plan and every later dispute is unadjudicable. Options: broadcast every replan, or only threshold breaches. Default: broadcast every replan; new user, new problem, new metric, or >50% appetite delta rewrites the product decisions.
7. What the product explicitly refuses to own. Question: which adjacent problems, user groups, and integrations does this plan permanently not serve? Why hard to reverse: non-ownership statements are commitments that downstream architecture (trust boundaries, integration points) and launch positioning build on; retracting one later reopens every scope debate at once. Options: (a) a written non-ownership register with reconsider conditions; (b) implicit scope by omission. Default: (a); omission is not a decision, it is a future argument.

## Plan requirements

Consumed by the orchestrator's inversion pass; each becomes acceptance criteria on concrete tasks via Requirements: lines.

1. R-PRD-1 The product section opens with a mode declaration (greenfield product, greenfield feature, brownfield fix, iteration, pivot fork, or rescue) and all 7 pre-flight answers in writing: the problem, who has it, how they solve it today, why now, what it costs them in concrete numbers, what success looks like in 90 days as an outcome (not a ship event), and appetite as a duration. Missing answers appear as explicit assumptions or open questions, never fabricated.
   Criterion: WHEN the product section is emitted THE PLAN SHALL contain the declared mode and 7 written pre-flight answers, with any unknown recorded as an assumption or an owned open question.
2. R-PRD-2 Appetite is stated as a duration (e.g. "6 weeks"), never as an estimate, with the sentence "scope flexes, time does not" made operative by linking appetite to the roadmap's cut policy.
   Criterion: IF appetite appears anywhere in the plan THE PLAN SHALL express it as a fixed duration bound to a scope-cut rule, and SHALL NOT express it as an effort estimate.
3. R-PRD-3 The problem framing is exactly three paragraphs: the friction in the user's vocabulary, who has it (concrete role plus constraint), and the existing workaround. It passes the substitution test against two named competitors (a sentence that reads plausibly for a competitor decides nothing and fails) and contains zero sentences that name the solution; the shape is "users today do X manually, which takes Y and costs Z".
   Criterion: WHEN the problem statement is written THE PLAN SHALL name two competitors it was substitution-tested against and SHALL contain no sentence of the form "Our product", "The system", or "Users need a tool that".
4. R-PRD-4 One primary user is specified in five bullets: role, context (the specific workday moment), constraint, current workaround, and a real research citation or an explicitly flagged research-gap open question. No persona fiction, no decorative demographics (age, hobbies, beverage preferences).
   Criterion: WHEN the target user is defined THE PLAN SHALL cite research or flag a research gap as an owned open question, and SHALL NOT include narrative persona paragraphs.
5. R-PRD-5 Success is at most 5 metrics, each with a number, a deadline or window, an outcome frame, and the named instrumentation source (event, dashboard, or query) that will measure it; at least one leading and one lagging indicator; no vanity metrics, no feature-shipped checkboxes, no undefined "active". A build task exists that makes the instrumentation live on day 1.
   Criterion: WHEN success criteria are listed THE PLAN SHALL give every metric a number, deadline, outcome frame, and named source, and SHALL contain a task that ships the emitting instrumentation in the first build wave.
6. R-PRD-6 Every functional requirement is a user-observable behavior with a MoSCoW rank, Given/When/Then acceptance criteria QA can test, and an explicit dependency list; at most 50% ranked Must; Should and Could populated; Won't cross-linked to out-of-scope; no implementation details, screens, or marketing phrases inside requirements; anything not both user-observable and testable is split or merged.
   Criterion: WHEN functional requirements are enumerated THE PLAN SHALL rank each with MoSCoW under the 50% Must cap and attach Given/When/Then criteria and dependencies to each.
7. R-PRD-7 All ten NFR dimensions are addressed: performance, scale, availability, security, privacy, compliance, accessibility, internationalization, observability, data retention. Each gets a numbered threshold with a stated basis (SLA, industry baseline, customer commitment) or an owned open question. Security and compliance are never silent; at minimum the plan states which regulations do and do not apply. No invented numbers ("99.99%" with no basis fails).
   Criterion: WHEN NFRs are written THE PLAN SHALL address all ten dimensions and SHALL attach a basis citation to every numeric threshold or flag it as an owned open question.
8. R-PRD-8 The out-of-scope section contains at least three no-gos each with a reason and a reconsider condition, at least one deferral, at least one explicit non-ownership statement, and at least one rabbit hole named with what could go wrong, why over-building is tempting, and the smallest version that avoids it. The out-of-scope section is longer than the Won't tier and at least as long as the goals statement.
   Criterion: WHEN scope is bounded THE PLAN SHALL list 3+ reasoned no-gos, 1+ deferral, 1+ non-ownership entry, and 1+ rabbit hole with its smallest-version alternative.
9. R-PRD-9 Risks and assumptions live in two separate registers, never merged: every risk has a specific failure mode, an owner, a concrete mitigation, and a trigger signal; every assumption has the claim, the evidence (or "no evidence yet; hypothesis"), and a validation plan with a date.
   Criterion: WHEN risks or assumptions are recorded THE PLAN SHALL keep them in separate registers with all fields present per entry.
10. R-PRD-10 Every product open question is routed to the plan's single Open Questions section (bottom of PLAN.mdx) with an owner, a due date, a blocking flag (blocks build? blocks ship?), and a recommended default. Committed decisions never appear there.
    Criterion: IF a product decision is unresolved THE PLAN SHALL record it only in the Open Questions section with owner, due date, blocking flag, and recommended default.
11. R-PRD-11 Every sentence in the product section passes the three-label test (decision, hypothesis, or open question). Banned outright: TBD or TODO without owner and date, and the phrases industry-leading, enterprise-grade (undefined), seamlessly, AI-powered (for a non-AI product), best-in-class, world-class, cutting-edge, game-changing, revolutionary.
    Criterion: WHEN the product section is complete THE PLAN SHALL contain zero unowned TBD/TODO markers and zero banned marketing phrases.
12. R-PRD-12 A prior-art section lists 3 comparable products or internal projects with honest status (thriving, stagnant, dead, pivoted) and one line on what each teaches this plan.
    Criterion: WHEN prior art is documented THE PLAN SHALL name 3 comparables each with a status and a lesson.
13. R-PRD-13 The product section pre-fills the inputs the later domain passes consume, so decisions are never re-litigated: for architecture (entities, core flows with 2+ error paths per feature, NFRs, integration points, trust boundaries, deferrals), for roadmap (MoSCoW ordering, release gates, dependencies, rabbit holes, hard dates), for stack (the pre-flight constraints), for build (entities and CRUD surface, roles and permissions, audit-trail needs, error states, domain landmines).
    Criterion: WHEN the product pass finishes THE PLAN SHALL contain a handoff block per downstream pass with no empty sub-section; every gap says "deferred to <pass>" with a reason.
14. R-PRD-14 A sign-off roster is named with what each role attests to (PM: problem and scope; eng lead: feasibility and dependencies; design lead: user and flows; QA where present: acceptance criteria testability), never blanket "approved", and the attestations are scheduled as plan milestones. Solo builders name themselves per role explicitly.
    Criterion: WHEN sign-off is planned THE PLAN SHALL list each signer with a specific attestation and a milestone task for it.
15. R-PRD-15 Change control is declared upfront against the status lifecycle: a post-approval change to scope, users, or metrics returns status to planning and increments plan_version, broadcast on a named channel; past the fork threshold (new user, new problem, new metric, or >50% appetite delta) the replan rewrites the product decisions instead of patching them. Clarifications changing no commitment keep the status.
    Criterion: WHEN the plan is emitted THE PLAN SHALL state its change-control rule, broadcast channel, and fork threshold against the status lifecycle and SHALL NOT declare a second lifecycle state.
16. R-PRD-16 The visual-identity direction is named in one phrase (e.g. "fintech-serious", "playful-utilitarian") for the build and launch passes to inherit.
    Criterion: WHEN the product section is complete THE PLAN SHALL contain exactly one visual-identity direction phrase.
17. R-PRD-17 Post-launch closure is scheduled inside the plan: a 30-day retrospective task against the success criteria, a support runbook task covering the top 5 expected failure modes, and a one-paragraph rollback statement linking the R-DEPLOY-17 rollback doc when deploy lands.
    Criterion: WHEN phases are laid out THE PLAN SHALL contain tasks for the 30-day retro, the top-5 support runbook, and a rollback statement.

## Task seeds

- [ ] GP-xxx Wire day-1 success-metric instrumentation
  - Files: src/server/analytics.ts, docs/metrics.md
  - Acceptance: every metric in the plan's Success criteria has a named server-side emit call after the outcome commits; docs/metrics.md maps each metric to its event, dashboard, or query
  - Verify: grep -q "track(" src/server/analytics.ts && grep -q "<metric_event_name>" docs/metrics.md
  - Requirements: R-PRD-5
- [ ] GP-xxx Validate the riskiest assumption before the build wave depending on it
  - Files: docs/validation/<assumption-slug>.md
  - Acceptance: the file records the claim, the method (interviews, spike, or data pull), the result, and the go/pivot decision; the assumption register entry links to it
  - Verify: test -f docs/validation/<assumption-slug>.md && grep -q "Decision:" docs/validation/<assumption-slug>.md
  - Requirements: R-PRD-9
- [ ] GP-xxx Build the success-metric dashboard or saved queries
  - Files: analytics/queries/<metric>.sql, docs/metrics.md
  - Acceptance: one runnable query or dashboard link per success metric; leading and lagging indicators both covered
  - Verify: test "$(ls analytics/queries/*.sql | wc -l)" -eq <metric-count>
  - Requirements: R-PRD-5
- [ ] GP-xxx Write the support runbook for the top 5 failure modes
  - Files: docs/runbook.md
  - Acceptance: 5 failure modes, each with detection signal, user-facing symptom, and remediation steps; rollback statement included
  - Verify: test "$(grep -c "^## Failure:" docs/runbook.md)" -eq 5 && grep -q "Rollback" docs/runbook.md
  - Requirements: R-PRD-17
- [ ] GP-xxx Snapshot metric baselines and schedule the 30-day retrospective
  - Files: docs/retro-30d.md
  - Acceptance: baseline value recorded per success metric at launch; retro date set 30 days after launch; template sections for each success metric
  - Verify: grep -q "Baseline:" docs/retro-30d.md && grep -q "Retro date:" docs/retro-30d.md
  - Requirements: R-PRD-5, R-PRD-17
- [ ] GP-xxx Compile the prior-art dossier
  - Files: docs/prior-art.md
  - Acceptance: 3 comparable products or internal projects, each with an honest status (thriving, stagnant, dead, pivoted) and a one-line lesson this plan applies
  - Verify: test "$(grep -c "^## " docs/prior-art.md)" -eq 3 && grep -q "Status:" docs/prior-art.md
  - Requirements: R-PRD-12
- [ ] GP-xxx Turn Must-requirement acceptance criteria into executable test skeletons
  - Files: tests/acceptance/<feature>.spec.ts
  - Acceptance: one test file per Must requirement; each Given/When/Then criterion from the plan appears as a named test case, failing or pending until implemented
  - Verify: test "$(ls tests/acceptance/*.spec.ts | wc -l)" -eq <must-count> && grep -rq "describe(" tests/acceptance/
  - Requirements: R-PRD-6
- [ ] GP-xxx Audit the plan's product section for banned language and unowned questions
  - Files: .godplans/PLAN.mdx
  - Acceptance: zero banned marketing phrases; zero TBD/TODO without owner and date; every Open Questions entry has owner, due date, blocking flag, and default
  - Verify: ! awk '/^## /{s=1;p=/^## (Sc|Req|Op)/}p||!s' .godplans/PLAN.mdx | grep -iE "TBD|TODO|seamless|best-in-class|world-class|cutting-edge|game-chang|revolutionary|industry-leading|enterprise-grade|AI-powered" | grep -qvi owner
  - Requirements: R-PRD-11, R-PRD-10

## Self-audit rubric

100 points total. Below 85 total, revise before emission.

- Pre-flight and framing (10): mode declared; all 7 pre-flight answers written; appetite is a duration bound to a cut policy; unknowns are assumptions or owned questions, not gaps.
- Problem and user specificity (15): three-paragraph problem in the user's vocabulary; substitution test passed against two named competitors; no solution-naming sentences; one primary user in five bullets with citation or flagged gap; no persona fiction.
- Success metrics (15): at most 5, each with number, deadline, outcome frame, named source; leading plus lagging present; day-1 instrumentation task exists; zero vanity metrics.
- Functional requirements (15): every requirement user-observable and testable with Given/When/Then and dependencies; MoSCoW ranked; Must at or under 50% and at most 7; Won't cross-linked to out-of-scope.
- NFR coverage (10): all ten dimensions addressed; every number has a stated basis; security and compliance explicitly scoped, never silent.
- Scope negative space (10): 3+ reasoned no-gos with reconsider conditions; deferral and non-ownership entries present; rabbit hole named with smallest-version alternative; out-of-scope longer than the Won't tier.
- Registers and question hygiene (10): risks and assumptions in separate complete registers; every open question routed to the single Open Questions section with owner, due date, blocking flag, and default; three-label test holds sentence by sentence.
- Downstream pre-fill and traceability (10): handoff inputs for architecture, roadmap, stack, and build passes filled or explicitly deferred with reason; every R-PRD requirement traceable to at least one task's Requirements: line.
- Lifecycle and closure (5): change-control rule, broadcast channel, and fork threshold declared; sign-off attestations scheduled; retro, runbook, and rollback tasks present; prior art and visual-identity phrase included.

## Anti-patterns refused

- Invisible PRD: the problem or user section reads equally true for two competitors. Refusal: run the substitution test against two named competitors and rewrite until sentences decide something.
- Solution-first PRD: the Problem section names the product ("Users need a tool that..."). Refusal: rewrite as "users today do X manually, which takes Y and costs Z" before any requirement is written.
- Feature laundry list: more than 7 Must-ranked or more than 12 unranked requirements. Refusal: enforce the 50% Must cap; force Should/Could tiers and cross-link Won't to out-of-scope.
- Assumption soup: "users will love this" with no evidence and no validation plan. Refusal: every assumption gets claim, evidence or "no evidence yet; hypothesis", and a dated validation task.
- Hollow PRD: TBD, TODO, or "figure out later" without an owner and due date. Refusal: convert each to an owned open question with a recommended default or delete the section it hollows out.
- Fabricated personas: narrative fiction paragraphs, demographics with no research citation. Refusal: five bullets max, citation or a flagged research-gap question.
- Vanity-metric success: raw signups, pageviews, downloads, or "ship feature X" as success. Refusal: outcome-framed metrics with numbers, deadlines, and named sources only.
- Silent or invented NFRs: no security/compliance statement, or "99.99%" with no basis. Refusal: address all ten dimensions; every number cites its basis or becomes an owned question.
- Moving-target PRD: post-approval edits with no replan or broadcast. Refusal: declare the change-control rule and broadcast channel before approval; replan on every commitment change.
- Marketing-adjective creep: seamlessly, best-in-class, enterprise-grade, AI-powered on a non-AI product. Refusal: banned-phrase grep in the final Verification phase; the plan does not ship containing them.
- Rubber-stamp sign-off: signers listed with a blanket "approved" and no named attestation, or tiers left unsigned. Refusal: each signer attests to a specific thing (problem, feasibility, flows, testability) and each attestation is a scheduled milestone; an unsigned roster blocks the plan from status approved.
- One-prompt PRD: emitting a full product section from a single-sentence idea with no mode declaration or pre-flight. Refusal: run intake and discovery first; unanswered pre-flight questions become written assumptions, never invented answers.
