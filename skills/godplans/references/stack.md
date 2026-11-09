# Stack selection planning module

Turns tool choice into a constraint-filtered, weight-scored, dated decision inside PLAN.mdx. The orchestrator loads this module for every archetype whenever the stack domain is applicable: in greenfield mode it plans a fresh pick, in brownfield mode it plans from an inventory of the code that already exists, in replan mode it re-verifies the prior decision against flip-point signals before preserving it.

## Lineage

Descends from stack-ready, the planning-tier skill that chooses a technology bundle for a specific job and refuses generic, undated, unaccountable recommendations. The discipline that carries over: hard constraints eliminate candidates before any scoring ranks them; every score sits under a published weight vector a reviewer can re-derive; and every recommendation ships with the three honesty fields (the failure mode that flips it, the scale ceiling as a metric, the switching cost in engineer-weeks). stack-ready stops at .stack-ready/DECISION.md; this module inverts its audit checks into obligations the plan satisfies before a single dependency is installed.

## Decisions to force

Ordered by reversal cost. Each is answered in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default. Candidate generation starts from the domain profile plus the three pre-combined bundles: Safe Default (consensus tools, 12+ months of dominance, boring on purpose), Fast-to-Ship (managed everything, accepts vendor coupling to hit the time-to-ship answer), and Enterprise (SSO, audit logs, residency controls, self-host escape hatches). A bundle is a starting point, not an answer; every component still passes the constraint filter individually. In brownfield mode these same eight decisions are answered as keep, adjust, or replace verdicts against the inventory scan, and only replace verdicts trigger the migration requirements.

1. **Database engine and data model shape.** Question: relational, document, or specialized store, and which engine? Hard to reverse because data outlives code: switching engines means dual-write, backfill, reconciliation, and a cutover window measured in engineer-weeks, and every query in the codebase is written against the old shape. Options: Postgres (default for anything with relations or future analytics), SQLite/libSQL (single-node tools, local-first), a document store only when the access pattern is genuinely key-shaped. Default: Postgres unless a hard constraint (offline, embedded, edge) rules it out.
2. **Language and runtime.** Question: which language does the team write every file in? Hard to reverse because it touches 100 percent of the code and the hiring pool. Options: match the team's deepest language competence from pre-flight; a language the team does not know is a hypothesis, not a decision. Default: the team's strongest language with an actively maintained runtime.
3. **Auth provider and identity ownership.** Question: managed auth, framework-native auth, or self-rolled sessions, and who owns the user table? Hard to reverse because user identities, password hashes, and sessions migrate poorly; an auth swap forces every user through re-verification or a risky hash import. Options: managed (Clerk, Auth0, Supabase Auth, WorkOS for enterprise SSO), library (Better Auth, Lucia-style), platform-native. Default: managed for SaaS with compliance needs, library when the user table must live in the app database.
4. **Hosting posture and residency.** Question: managed platform, containers on a cloud, or self-host, and in which region? Hard to reverse because deploy pipelines, networking, secrets, and data residency contracts all bind to it. Options: managed PaaS (fastest to ship), containerized cloud (portable, more ops), self-host (only with named ops capacity). Default: managed PaaS unless a residency, self-host, or cost hard constraint eliminates it.
5. **Framework.** Question: which application framework carries routing, rendering, and the request lifecycle? Hard to reverse because component and handler idioms permeate the codebase, though less deeply than language or data. Default: the consensus framework for the domain profile with 12+ months of dominance, not the newest entrant.
6. **Payments provider.** Recorded from business decision 4 (billing system of record, merchant of record, tax) with its open merchant-of-record question; never re-decided here. When business is excluded or its decision 2 is no charge, R-STACK-4 records payments as not needed, citing that row or decision, whose revisit when: predicate reopens it.
7. **Background jobs and queues.** Question: where does async work run? Semi-reversible, but job semantics (retries, idempotency, scheduling) leak into application code. Default: the queue native to the chosen hosting posture; exactly one.
8. **ORM and client data layer.** Question: which single ORM and which single client cache/fetching layer? The most reversible of the forced bets, forced anyway because duplicates here are the most common coherence failure. Default: one ORM matched to the database, one client data layer matched to the framework.

## Plan requirements

Each requirement is one plan-time obligation inverted from a stack-ready audit check. The orchestrator's inversion pass distributes these onto concrete tasks via Requirements: lines; a requirement with no task carrying it is an unmet requirement.

1. **R-STACK-1 Mode declaration.** PLAN.mdx names the stack mode (greenfield pick, brownfield assessment, audit verdict, or migration) and, for brownfield or audit, records the stack inventory scan of the actual code before proposing anything. Criterion: WHEN the project has existing code, THE PLAN SHALL contain an inventory of the current stack per dimension before any recommendation, and IF the plan proposes changes THE PLAN SHALL label each dimension keep, adjust, or replace.
2. **R-STACK-2 Pre-flight answers.** The stack section opens with the six pre-flight answers in writing: domain profile, team (size, language depth, on-call reality), a named budget posture (not a dollar figure), time-to-ship, an honest 12-month scale ceiling, and an explicit regulatory and data-residency statement, with "none apply" stated affirmatively rather than by silence. Criterion: WHEN the stack section is emitted, THE PLAN SHALL contain all six answers, and IF the user gave no answer for one, THE PLAN SHALL state a plausible default as an assumption rather than leave the field blank.
3. **R-STACK-3 Constraint map before tools.** Every pre-flight answer is converted into either a hard constraint (rules candidates out: no-BAA in HIPAA paths, EU residency, self-host mandate, offline, cost ceiling, team language, SLA, vendor independence) or a weighted preference, and the map appears before any tool is named. Criterion: WHEN any candidate tool is listed, THE PLAN SHALL already contain the constraint map, and IF a candidate violates a hard constraint THE PLAN SHALL drop it unscored with the violated constraint named.
4. **R-STACK-4 Twelve-dimension coverage.** The plan covers all 12 stack dimensions: framework, language/runtime, database, ORM, auth, UI library, client state/data fetching, hosting, observability, payments, email/notifications, background jobs. Criterion: WHEN the stack table is emitted, THE PLAN SHALL name a choice or an explicit "not needed because X" for each of the 12 dimensions.
5. **R-STACK-5 Named alternatives with losers recorded.** Each decided dimension shows 2-4 post-filter candidates and records why each loser lost. Criterion: WHEN a dimension is decided, THE PLAN SHALL list at least one named rejected alternative with a one-line reason, and IF only one candidate survives filtering THE PLAN SHALL say which constraint eliminated the rest.
6. **R-STACK-6 Published weight vector.** The weight vector used to rank candidates (DX, scale ceiling, ecosystem, cost, ops burden, compliance fit, or a stated override) is printed so a reviewer can re-derive the ranking. Criterion: WHEN scores are aggregated, THE PLAN SHALL state the weights, and IF the user overrode defaults THE PLAN SHALL show the override.
7. **R-STACK-7 Score discipline.** Every scored candidate carries a 1-10 score with a one-line rationale naming what was scored; no score above 9 without consensus domain leadership of 12+ months, none below 3 without a documented failure mode in this domain. Criterion: IF any score is above 9 or below 3, THE PLAN SHALL attach the required special justification next to that score.
8. **R-STACK-8 Pairing coherence.** The bundle passes the anti-pairing walk: exactly one ORM, one auth provider, one design system, one client cache layer, one job queue; no known-bad pairs (Convex+Prisma, Supabase+Firebase, Vercel+Lambda stacking, two of anything). Criterion: WHEN the bundle is finalized, THE PLAN SHALL state the coherence check passed, and IF a temporary dual-run is intentional (migration) THE PLAN SHALL name it and its end condition explicitly.
9. **R-STACK-9 Flip point.** The chosen bundle carries a concrete failure-mode paragraph: the specific signal that would flip the decision. Criterion: WHEN the bundle is chosen, THE PLAN SHALL contain a flip-point paragraph that is neither "none" nor "unknown", specific enough that a reader six months later can tell whether it has been hit.
10. **R-STACK-10 Scale ceiling as a metric.** The ceiling is a number or a named boundary: user count, data volume, query-pattern shift, or feature boundary. Criterion: WHEN the bundle is chosen, THE PLAN SHALL state the scale ceiling as a measurable quantity, not an adjective.
11. **R-STACK-11 Switching cost.** The honest rebuild bill for leaving the bundle, in engineer-weeks or engineer-months, per hard-to-reverse component. Criterion: WHEN the bundle is chosen, THE PLAN SHALL state the switching cost as a time estimate with the dominant cost driver named.
12. **R-STACK-12 Prior art.** Three real deployments running a comparable stack at comparable scale, each with status and date. Criterion: IF fewer than 3 comparable deployments can be named, THE PLAN SHALL flag the pick as more novel than claimed and downgrade it to a hypothesis with a validation task.
13. **R-STACK-13 Compliance and ops fit.** Any managed service on a regulated path shows its BAA, SOC 2, or PCI documentation status; anything self-hosted names the ops cost for the actual team size from pre-flight. Criterion: IF the regulatory statement names a regime, THE PLAN SHALL record compliance documentation per managed service in that path, and IF any component is self-hosted THE PLAN SHALL name who operates it and at what recurring cost.
14. **R-STACK-14 Version and maintenance hygiene.** Only released versions are pinned; no dependency whose repository is archived or whose last commit is older than 18 months. Criterion: WHEN the stack table pins versions, THE PLAN SHALL pin versions that exist at plan date, and IF a candidate fails the liveness check THE PLAN SHALL reject it with the last-commit date recorded.
15. **R-STACK-15 True cost model.** Cost analysis includes egress, seat pricing, and the free-tier cliff, checked against the named budget posture. Criterion: WHEN hosting or managed services are chosen, THE PLAN SHALL state the expected monthly cost at the 12-month scale ceiling including egress and seats, and IF the choice sits on a free tier THE PLAN SHALL name the cliff and the cost after it.
16. **R-STACK-16 Date stamp and staleness trigger.** The stack decision is dated and carries a re-check trigger at roughly 6 months or on flip-point signals, whichever comes first; auth, AI tooling, and hosting pricing churn fastest. Criterion: WHEN the stack section is emitted, THE PLAN SHALL carry the decision date and a named re-check condition.
17. **R-STACK-17 Decision persistence and handoff.** The plan schedules a task that writes .stack-ready/DECISION.md at scaffold time so build, repo, and deploy phases consume the decision without re-litigating it, complete enough that a memory-less agent can start building without asking another stack question. Criterion: WHEN phases are laid out, THE PLAN SHALL contain a task emitting DECISION.md with pre-flight, constraints, weights, scored bundle, runner-up, flip point, ceiling, switching cost, and rejected bundles.
18. **R-STACK-18 Open questions with owners.** Remaining stack unknowns appear only in the plan's single Open Questions section, each with an owner, a due date, and a recommended default. Criterion: IF any stack question remains open, THE PLAN SHALL list it in Open Questions with owner and due date, and THE PLAN SHALL NOT restate committed stack decisions there.
19. **R-STACK-19 Migration path.** A stack migration includes all five components: blast radius, sequenced steps with dual-write/dual-read parallels and cutover points, a rollback checkpoint per phase, a data migration strategy (transforms, backfills, reconciliation, validation), and an honest engineer-week timeline. Criterion: IF the plan replaces any existing stack component that holds data, THE PLAN SHALL contain all five migration components with a rollback checkpoint in every migration phase.
20. **R-STACK-20 Skip-the-rigor guard.** An experience-backed, reversible, low-stakes repeat pick gets a compact constraint check instead of the full scoring pass; formal scoring there is itself the paralysis failure mode. Criterion: IF the team has shipped this exact bundle before and every component is reversible under the stated constraints, THE PLAN SHALL record a compact constraint check with the prior deployment named instead of a full scoring table.
21. **R-STACK-21 Named runner-up beyond the starting set.** The pre-combined bundles in Decisions to force are a starting set, not a ceiling. The plan names one viable alternative that was generated rather than selected from that set, together with the single condition under which it would have won, so a reader can tell a bundle that was chosen from one that was merely defaulted into. This records the alternative; it does not promote it, and the incumbent bias in R-STACK-7 and R-STACK-12 stands. Criterion: WHEN the bundle is chosen, THE PLAN SHALL name one runner-up that was not on the pre-combined bundle list together with the condition that would flip the decision to it, or SHALL state that generation produced no viable off-list candidate and name the constraint that eliminated them.

## Task seeds

Instantiate with real paths, real tool names, and wave/parallel markers; replace the placeholder-shaped Verify commands with ones that name the chosen tools, and replace count placeholders like `<regulated-vendor-count>` with the real numbers from the plan.

- [ ] GP-xxx Run the brownfield stack inventory scan (brownfield and audit modes only)
  - Files: docs/stack/inventory.md
  - Acceptance: one row per stack dimension listing the tool actually in the code (from manifests and imports, not from memory), its installed version, its last-commit liveness, and the plan's keep/adjust/replace verdict; no dimension row is blank
  - Verify: test $(grep -cE '^\| (framework|language|database|orm|auth|ui|client-data|hosting|observability|payments|email|jobs) ' docs/stack/inventory.md) -eq 12
  - Requirements: R-STACK-1, R-STACK-4
- [ ] GP-xxx Scaffold the project with the pinned stack manifest
  - Files: package.json (or the runtime's manifest), .tool-versions, scripts/check-stack.mjs
  - Acceptance: every dependency in the plan's stack table appears at its exact pinned version; no dependency introduces a second ORM, auth provider, design system, client cache, or job queue; runtime version matches the plan; the check script exits 1 on drift or a duplicate
  - Verify: node scripts/check-stack.mjs
  - Requirements: R-STACK-4, R-STACK-8, R-STACK-14
- [ ] GP-xxx Emit .stack-ready/DECISION.md from the plan's stack section
  - Files: .stack-ready/DECISION.md
  - Acceptance: file contains decision date, six pre-flight answers, hard constraints, weight vector, scored bundle table, runner-up, flip point, scale ceiling, switching cost, prior art with dates, rejected bundles, open questions with owner and due date
  - Verify: grep -q 'Flip point' .stack-ready/DECISION.md && grep -q 'Scale ceiling' .stack-ready/DECISION.md && grep -q 'Switching cost' .stack-ready/DECISION.md
  - Requirements: R-STACK-16, R-STACK-17
- [ ] GP-xxx Verify dependency liveness and version existence
  - Files: scripts/check-liveness.sh
  - Acceptance: every pinned version resolves in the registry; no direct dependency's source repo is archived or silent for over 18 months; script exits nonzero on violation
  - Verify: bash scripts/check-liveness.sh
  - Requirements: R-STACK-14
- [ ] GP-xxx Record compliance documentation for regulated-path services
  - Files: docs/compliance/vendors.md
  - Acceptance: each managed service touching regulated data has a row with BAA/SOC 2/PCI status, document link or ticket, and review date; no regulated-path service has an empty status
  - Verify: test "$(grep -cE 'BAA|SOC 2|PCI' docs/compliance/vendors.md)" -ge <regulated-vendor-count>
  - Requirements: R-STACK-13
- [ ] GP-xxx Enforce pairing coherence in CI
  - Files: scripts/check-pairing.sh, .github/workflows/lint.yml
  - Acceptance: CI fails if the manifest matches more than one entry per category list (ORMs, auth providers, design systems, client caches, job queues); intentional dual-run entries are allowlisted with an expiry date
  - Verify: bash scripts/check-pairing.sh
  - Requirements: R-STACK-8
- [ ] GP-xxx Stand up migration dual-run with rollback checkpoint (migration plans only)
  - Files: src/data/dual-write.ts, docs/migration/rollback-checkpoints.md
  - Acceptance: writes go to old and new stores behind a flag; a reconciliation job compares row counts and checksums; each migration phase in the docs names its rollback checkpoint and cutover condition
  - Verify: test "$(grep -c 'Rollback checkpoint' docs/migration/rollback-checkpoints.md)" -eq <migration-phase-count>
  - Requirements: R-STACK-19

## Self-audit rubric

Score the plan's stack section 0-100. Below 85 total, revise before emission. The dimensions mirror stack-ready's four completion tiers: Shortlist (constraint-filtered survivors each with a why), Scored (a reader can see why A beat B in the numbers), Justified (the honesty triple plus rejected-bundle reasons), Decided (a memory-less agent can start building without asking another stack question).

- **Pre-flight and constraint map (15).**
  Full marks: all six pre-flight answers in writing with silence stated affirmatively, every answer converted to a hard constraint or weighted preference, the map appearing before any tool name, violators dropped unscored.
  Typical losses: regulatory field answered by omission (-5), constraints listed after the recommendation they were supposed to filter (-5).
- **Candidate coverage (15).**
  Full marks: all 12 dimensions decided or excluded with a stated reason, 2-4 named candidates per decided dimension, every loser's reason recorded, and one named runner-up generated outside the pre-combined bundle list with its flip condition (or the constraint that eliminated all off-list candidates).
  Typical losses: observability, email, or background jobs skipped without an exclusion reason (-3 each), a dimension with one candidate and no eliminating constraint named (-3), every candidate traceable to the starting bundles with no off-list alternative named or excluded (-3).
- **Scoring discipline (15).**
  Full marks: weight vector printed and re-derivable, every score carrying a rationale that names what was scored, 9+/3- caps respected with justification, top bundle ranked by the weighted aggregate.
  Typical losses: scores with no rationale (-5), an unexplained 10 (-5), aggregate that does not follow from the printed weights (-5).
- **Pairing coherence (10).**
  Full marks: exactly one of each single-slot category (ORM, auth, design system, client cache, job queue), the anti-pairing table walked, any intentional dual-run named with an end condition.
  Typical losses: a second auth provider smuggled in via a starter template (-5), dual-run with no expiry (-3).
- **Honesty triple (15).**
  Full marks: a flip point concrete enough to test in six months, a scale ceiling stated as a metric, a switching cost in engineer-weeks with the dominant driver named; none of the three reads "none" or "unknown".
  Typical losses: flip point that is really a restated benefit (-5), ceiling given as an adjective (-5).
- **Prior art and hygiene (10).**
  Full marks: 3 real deployments with status and dates, only released versions pinned, no dependency archived or silent for over 18 months.
  Typical losses: prior art younger or smaller than the stated ceiling (-3), an unreleased version pinned (-5).
- **Cost and compliance fit (10).**
  Full marks: monthly cost modeled at the 12-month ceiling including egress, seats, and the free-tier cliff; compliance documentation recorded for every regulated-path managed service; ops cost named for anything self-hosted.
  Typical losses: free-tier pricing quoted at ceiling scale (-5), regulated-path vendor with blank compliance status (-5).
- **Handoff and staleness (10).**
  Full marks: decision dated with a re-check trigger, the DECISION.md emission task scheduled with full contents, open questions carrying owner and due date, migration plans (when present) containing all five components with per-phase rollback.
  Typical losses: undated decision (-5), open question with no owner (-2), migration phase missing its rollback checkpoint (-3).

## Anti-patterns refused

- **Fake objectivity.** Scores with no stated weighting. Refusal: no score is written until the weight vector is printed.
- **Horoscope recommendation.** A pick with no flip-point paragraph, true no matter what happens. Refusal: the bundle is not committed until the flip point, ceiling, and switching cost are written.
- **"It depends" as a final answer.** Refusal: state the variable it depends on, assume a stated value, and decide; the assumption goes in the plan.
- **Trend chasing.** "Popular" or "new" as a rationale. Refusal: rationale must name domain fit; novelty without 3 prior deployments becomes a flagged hypothesis.
- **Dead-library pick.** Archived repo or last commit over 18 months old. Refusal: rejected with the last-commit date recorded next to the rejection.
- **Phantom versions.** Pinning a version that does not exist at plan date. Refusal: only released versions enter the stack table; the liveness task verifies.
- **Compliance blind spot.** A managed service in a regulated path with no BAA/SOC 2/PCI evidence. Refusal: the service is ineligible until documentation status is recorded.
- **Ops-cost amnesia.** Self-host recommended without naming who operates it. Refusal: self-host options are dropped unless the pre-flight team can absorb the named ops cost.
- **Free-tier mirage.** Cost analysis ignoring egress, seat pricing, or the cliff after the free tier. Refusal: cost is modeled at the 12-month ceiling or the choice is not costed at all, which fails R-STACK-15.
- **Anti-pairing incoherence.** Two ORMs, two auth providers, Convex+Prisma-class conflicts. Refusal: the bundle fails the coherence walk and is repaired before scoring output is kept.
- **Rollback-free migration.** A migration phase without a checkpoint. Refusal: the migration section is incomplete until every phase names its rollback point.
- **Microservices for two.** Distributed architecture for a team of 2 without a forcing function. Refusal: the plan defaults to the simplest topology the constraints allow and records the forcing function if one exists.
- **Undated recommendation.** A stack decision with no date and no staleness trigger. Refusal: the section is not emitted without both.
- **Undisclosed commercial ties.** Scoring shaded by an unstated affiliation. Refusal: any tie is disclosed next to the score or the candidate is scored by constraints alone.
- **Analysis paralysis.** Running the full scoring pass on an experience-backed, reversible repeat pick. Refusal: the skip-the-rigor guard applies; a compact constraint check with the prior deployment named replaces the ceremony.
