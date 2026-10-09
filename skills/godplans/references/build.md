# Application build planning module

Plans the build sections of PLAN.mdx: slices, wiring contracts, auth, states, tests, and hardening for any multi-page connected app. The orchestrator loads it for archetypes saas-dashboard, api-service, mobile-app, and any project with auth, navigation, and CRUD over domain data; it is excluded for marketing-site, library, and single-component work with a stated reason.

## Lineage

Descends from production-ready, the building-tier core of the aihxp ready-suite. Its target failure mode is the hollow dashboard: an app that looks finished but where buttons do not save, filters do not filter, charts render hardcoded JSON, sidebar links 404, and login accepts anything. The discipline that carries over is vertical-slice construction (one feature end-to-end before the next), the no-scaffold-no-placeholder rule (every visible element wired to a real backend), the CTA-completeness contract, the 30-second hollow-check grep protocol, and the deferred-CTA and open-questions lifecycles with hard closure gates. godplans inverts these from build-time enforcement into plan-time requirements: the plan is written so an executing agent cannot produce a hollow app without visibly failing a Verify line.

## Decisions to force

Ordered hardest-to-reverse first. Each must land in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default.

Cited, not restated. Domain data representation (money, soft delete) is database decisions 4 and 6 (R-DB-4); tenancy is architecture decision 2 and database decision 3; the persistence engine and ORM are stack decisions 1 and 8; auth, session strategy, and the password KDF are security decision 2 and stack decision 3 (R-SEC-6 names the KDF, argon2id by default). This module records how each slice applies them (R-BUILD-2, R-BUILD-3, R-BUILD-8) and forces only the build-shaped decisions below.

1. Route map. Question: the complete URL tree, every page, parent to child. Hard to reverse because URLs leak into bookmarks, nav components, tests, and (post-launch) search indexes. Default: enumerate the full map in the plan before any UI task exists; no task may add a nav link ahead of its registered route.
2. RBAC shape. Question: which roles (minimum 2) and the full resource-x-action permission matrix. Hard to reverse because permission checks thread through every mutation; adding a role later means re-auditing all of them. Default: write the matrix as a table in the plan; every mutation task cites the matrix cell it enforces.
3. Visual identity. Question: consume a project-root DESIGN.md (lint-clean, tokens wired) or derive an archetype plus 5 decisions (palette, typography, radius, density, signature element)? Hard to reverse because retheming after 30 components is a full sweep. Default: derive and record the 5 decisions if no DESIGN.md exists; no component task ships on an unmodified shadcn, Radix, or MUI default theme.
4. Slice order. Question: which feature is built first, second, third? Ordered most-used first, riskiest second, nice-to-haves last. Hard to reverse in effect: a mid-build stop leaves whatever was ordered first as the only complete feature. Default: order by user job frequency, then technical risk.
5. Target tier. Question: which completion tier does this plan aim for (1 Foundation, 2 Functional, 3 Polished, 4 Hardened)? Sets the scope of the final phases. Default: Tier 3 for anything user-facing; Tier 4 when the plan includes launch or hardening domains.

## Plan requirements

- R-BUILD-1: PLAN.mdx answers the 12 pre-flight questions in writing (who uses it and for what job, entities with attributes and relationships, the full stack as a set, where data lives, auth model, permission matrix, route map, definition of done for v1, exists-vs-to-build inventory, performance budgets, deploy target, responsive scope) as decisions or stated assumptions, never as gaps; the stack, where-data-lives, and auth answers cite the stack, database, and security decisions that own them and are never re-decided here.
  Criterion: WHEN the build sections are drafted, THE PLAN SHALL contain an answer or stated assumption for all 12 pre-flight questions, with unanswered ones appearing only in Open Questions with a recommended default.
- R-BUILD-2: PLAN.mdx names the domain and encodes its traps in the schema tasks (money per R-DB-4, double-entry where accounting applies, audit logging where regulation applies).
  Criterion: WHEN the project domain involves money, health, or regulated data, THE PLAN SHALL state the trap and place its mitigation in a schema task's Acceptance lines, not in prose.
- R-BUILD-3: PLAN.mdx commits to a real persistence layer whose data survives reload and is consistent across two browsers.
  Criterion: IF any task, note, or acceptance line proposes in-memory state, hardcoded JSON, or mock-now-wire-later persistence for user data, THE PLAN SHALL be revised before emission.
- R-BUILD-4: PLAN.mdx structures build phases as ordered vertical slices, each covering schema, seed, server CRUD with permission checks, client hooks, pages with all states, audit entry, and tests, ending at "an actual person can do an actual job with it".
  Criterion: WHEN build phases are laid out, THE PLAN SHALL define each slice end-to-end with a checkpoint stating the user job it completes.
- R-BUILD-5: PLAN.mdx never sequences tasks layer-by-layer (all schemas, then all APIs, then all UI), which yields 80 percent on every layer and zero working features.
  Criterion: IF a draft phase groups tasks by technical layer across features, THE PLAN SHALL be restructured into vertical slices before emission.
- R-BUILD-6: PLAN.mdx carries a CTA-completeness contract: every interactive element's full chain completes to a real user-visible outcome (page renders, record persists, toast confirms, list refreshes); a non-empty leaf onClick is not the gate. Blocked CTAs get exactly one of removed, disabled-with-visible-reason, or a deferred-cta.md entry with all five fields (Location, Intended chain, Blocker, Target slice, Status).
  Criterion: WHEN a slice's tasks are written, THE PLAN SHALL include a CTA-completeness audit task per slice whose Acceptance rejects half-wired chains and vague blockers such as "later".
- R-BUILD-7: PLAN.mdx contains the complete route map before any UI task, and no task introduces a nav link to an unregistered route.
  Criterion: WHEN UI tasks are enumerated, THE PLAN SHALL list every route in a route map and each nav task SHALL reference only routes registered by the same or an earlier task.
- R-BUILD-8: PLAN.mdx plans real auth: login rejects bad credentials, stores a session, gates every protected route server-side, and hashes passwords with the KDF R-SEC-6 names (argon2id by default).
  Criterion: WHEN the auth slice is planned, THE PLAN SHALL include acceptance lines for bad-credential rejection and server-side route gating, and SHALL make the slice depend on the R-SEC-6 task for the KDF rather than plan a second hashing task.
- R-BUILD-9: PLAN.mdx contains the RBAC resource-x-action matrix with at least 2 roles, and every mutation task cites its server-side permission check; UI hiding is courtesy, not security.
  Criterion: WHEN any mutation task is written, THE PLAN SHALL trace it to a cell in the permission matrix and require the check server-side.
- R-BUILD-10: PLAN.mdx traces each slice to the threat model instead of writing its own: every mutation task names the trust boundary it crosses (R-ARCH-13 when landed, otherwise the R-SEC-1 list) and any R-SEC-1 entry point it adds, and multi-tenant plans scope every query server-side by tenant.
  Criterion: WHEN a slice adds an entry point or a mutation, THE PLAN SHALL cite the trust boundary (R-ARCH-13 when landed, otherwise R-SEC-1) and the R-SEC-1 entry it touches and, IF multi-tenant, SHALL require tenant scoping in every query task's Acceptance.
- R-BUILD-11: PLAN.mdx commits the visual identity before any component task: a consumed DESIGN.md or a recorded archetype plus 5 token decisions; at least one rendered component visibly inherits from --color-primary; icons come from a real icon library, never emojis.
  Criterion: WHEN component tasks exist, THE PLAN SHALL place the visual-identity decision in a task that precedes them all and SHALL forbid unmodified library default themes.
- R-BUILD-12: PLAN.mdx requires loading, empty, and error states for every async surface (specific, not generic spinners), client plus server validation with inline field errors, a success or error toast after every mutation, and URL-preserved pagination, sorting, and filtering on any table over 25 rows.
  Criterion: WHEN a page task touches an async surface, table, or form, THE PLAN SHALL name the required states and feedback in that task's Acceptance lines.
- R-BUILD-13: PLAN.mdx plans tests inside each slice, not as a trailing phase: integration CRUD, permission-denial, axe accessibility, and a contract test for any cross-slice public signature (graduated rule: leaf features skip; mandatory the moment a second slice depends on the signature).
  Criterion: WHEN a slice is planned, THE PLAN SHALL include its test tasks in the same slice, and a slice without them SHALL NOT be marked complete by its checkpoint.
- R-BUILD-14: PLAN.mdx plans the supply-chain check into the bootstrap task: every unfamiliar dependency is verified to exist on the registry with a real publisher and non-trivial downloads before install (defense against the roughly 20 percent AI ghost-package rate).
  Criterion: WHEN the bootstrap task is written, THE PLAN SHALL include registry verification in its Acceptance for every dependency not already in a lockfile.
- R-BUILD-15: PLAN.mdx schedules a hardening pass before the verification phase that runs the security module's controls instead of restating them (the R-SEC-15 header set, the R-SEC-16 rate limits, the R-SEC-17 SCA gate) and adds the two build-owned checks: no secrets in the client bundle, and a bundle budget with code-splitting for heavy libraries.
  Criterion: WHEN phases are sequenced, THE PLAN SHALL place every landed R-SEC-15, R-SEC-16, and R-SEC-17 task before final verification, SHALL contain a build task whose acceptance lines check the client bundle for secrets and enforce the bundle budget, and SHALL NOT plan a second header, rate-limit, or audit task.
- R-BUILD-16: PLAN.mdx schedules the hollow-check grep after every slice and at every tier boundary, with the have-nots as acceptance criteria: no TODO or implement-later markers, no raw console.log in prod paths (one exclusion: logger calls in catch blocks), no hardcoded fake-data arrays in components, no Math.random() driving charts or KPIs, no alert() or prompt() for UI, no components named ExampleX, DemoY, or TestZ.
  Criterion: WHEN slice and tier boundaries are defined, THE PLAN SHALL attach a hollow-check task whose Verify is a grep command that must return zero hits.
- R-BUILD-17: PLAN.mdx plans session-state discipline: .godplans/STATE.md, scoped to build-tier facts not already tracked by PLAN.mdx (current tier, active build decisions, next slice; slice completion lives in the plan's checkboxes and open decisions live in its Open Questions section), updated at every tier boundary and session end. A non-obvious architectural choice made during build becomes a new ADR in the architecture module's ADR task (R-ARCH-14 owns `decide.adr` and its path); this module plans no ADR-writing task. On any conflict between STATE.md and PLAN.mdx, PLAN.mdx wins.
  Criterion: WHEN the build sections are drafted, THE PLAN SHALL include tasks that create and maintain STATE.md, SHALL route every build-time ADR to the R-ARCH-14 task, and open questions above 5 or deferred CTAs above 10 SHALL be flagged as drift.
- R-BUILD-18: PLAN.mdx declares the target tier (1 Foundation, 2 Functional, 3 Polished, 4 Hardened) and, when targeting Tier 4, encodes the closure gates as final-phase must-haves: zero TODOs, zero live deferred-cta entries, zero build-tier entries left in PLAN.mdx's Open Questions section, zero unshipped rewrite items.
  Criterion: WHEN the plan targets Tier 4, THE PLAN SHALL list each closure gate as a grep-verifiable must-have in the final build phase.
- R-BUILD-19: PLAN.mdx schedules the cross-cutting layer (search, exports, notifications, theme toggle, audit-log viewer, profile) as a Tier-3 pass after 2 to 3 slices are complete, never before the first slice works.
  Criterion: WHEN cross-cutting features appear, THE PLAN SHALL place them in a phase that depends on at least two completed slices.
- R-BUILD-20: In brownfield or replan mode, PLAN.mdx contains a keep-rewrite-discard inventory of existing code before any build task touches it, and consumed upstream artifacts (PRD, ARCH, ROADMAP) are treated as historical records, with current code winning on conflict.
  Criterion: IF mode is brownfield or replan, THE PLAN SHALL include the inventory as a table and every rewrite task SHALL reference its inventory row.

## Task seeds

Templates ready to instantiate. Replace path placeholders and the entity token with the project's real stack (paths below assume a TypeScript app; adapt Files and Verify to the committed stack). GP-xxx is the repeating slice template: instantiate it once per slice in the decided order.

- [ ] GP-xxx Bootstrap project with verified dependencies
  - Files: package.json, package-lock.json, .godplans/STATE.md
  - Acceptance: every dependency in package.json resolves on the registry with a real publisher; STATE.md exists with tier, stack, and next-slice fields; no dependency was installed without the registry check
  - Verify: npm ls --depth=0 && grep -q "Current tier" .godplans/STATE.md
  - Requirements: R-BUILD-14, R-BUILD-17
- [ ] GP-xxx Login slice: bad-credential rejection, session persistence, server-side route gating
  - Files: src/server/auth.ts, src/middleware.ts, src/app/login/page.tsx, tests/auth.test.ts
  - Depends on: GP-xxx security auth foundation (R-SEC-6, R-SEC-7)
  - Acceptance: login with bad credentials returns 401; session persists across reload; every route under /app redirects unauthenticated server-side
  - Verify: npm test -- tests/auth.test.ts
  - Requirements: R-BUILD-8, R-BUILD-9
- [ ] GP-xxx Vertical slice: <entity> end-to-end
  - Files: prisma/schema.prisma, src/server/<entity>.ts, src/hooks/use-<entity>.ts, src/app/<entity>/page.tsx, tests/<entity>.test.ts
  - Acceptance: list, detail, create, edit, delete all persist and survive reload; each mutation enforces its permission matrix cell server-side; loading, empty, and error states exist on every async surface; integration CRUD, permission-denial, and axe tests pass
  - Verify: npm test -- tests/<entity>.test.ts
  - Requirements: R-BUILD-3, R-BUILD-4, R-BUILD-9, R-BUILD-12, R-BUILD-13
- [ ] GP-xxx CTA-completeness audit for slice <n>
  - Files: .godplans/deferred-cta.md
  - Acceptance: every button, link, form, menu, and drawer on touched pages completes its chain to a user-visible outcome; blocked CTAs are removed, disabled-with-visible-reason, or logged with all five fields; no entry has a vague blocker
  - Verify: ! grep -riE "blocker: *(later|soon|tbd)" .godplans/deferred-cta.md
  - Requirements: R-BUILD-6, R-BUILD-7
- [ ] GP-xxx Hollow-check gate at tier boundary
  - Files: src/
  - Acceptance: zero TODO or implement-later markers in prod paths; zero hardcoded fake-data arrays in components; zero Math.random() driving charts or KPIs; zero alert() or prompt() for UI
  - Verify: ! grep -rnE "TODO|implement later|hook up to API|Math.random\(\)" src/ --include="*.tsx" --include="*.ts"
  - Requirements: R-BUILD-16, R-BUILD-18
- [ ] GP-xxx Cross-cutting Tier-3 pass
  - Files: src/app/search/, src/components/export-button.tsx, src/components/theme-toggle.tsx, src/app/audit-log/page.tsx
  - Acceptance: search queries the real persistence layer; exports produce a downloadable file from live data; audit-log viewer reads the audit table written by prior slices; all new CTAs pass the completeness contract
  - Verify: npm test -- tests/cross-cutting.test.ts
  - Requirements: R-BUILD-19, R-BUILD-6
- [ ] GP-xxx Client bundle hardening before verification
  - Files: next.config.js, .size-limit.json
  - Depends on: GP-xxx every landed R-SEC-15, R-SEC-16, and R-SEC-17 task
  - Acceptance: no secret matches (server-only env names, live key prefixes, private-key headers) in the client bundle output; a per-route bundle budget is set and enforced; heavy libraries load through dynamic import
  - Verify: npm run build && ! grep -rqE "sk_live_|PRIVATE KEY|DATABASE_URL" .next/static && npx size-limit
  - Requirements: R-BUILD-15

## Self-audit rubric

Score the drafted build sections 0-100. Below 85 total, revise before emission.

- Vertical-slice structure (20): every build phase is a vertical slice with the full per-slice recipe, ordered most-used then riskiest then nice-to-have; no layer-by-layer grouping anywhere; each slice checkpoint names the user job it completes.
- Real wiring and CTA completeness (20): persistence decision is real-and-persistent; per-slice CTA audit tasks exist; deferred-cta.md lifecycle with the five-field schema is planned; hollow-check grep tasks sit at every slice and tier boundary with exact Verify commands.
- Auth, RBAC, and threat model (15): auth slice has bad-credential, session, and server-gating acceptance lines citing the R-SEC-6 KDF; permission matrix present with at least 2 roles; every mutation traced to a trust boundary (R-ARCH-13 when landed, otherwise R-SEC-1); tenant scoping required per query if multi-tenant.
- States, feedback, and tests (15): loading, empty, and error states named per async surface; validation and toast requirements on every form and mutation task; per-slice test tasks cover integration CRUD, permission-denial, axe, and graduated contract tests.
- Visual identity (10): identity decision precedes all component tasks; DESIGN.md consumed or archetype plus 5 decisions recorded; default-theme prohibition and icon-library requirement stated.
- Supply chain and hardening (10): registry verification in the bootstrap task; landed R-SEC-15/16/17 tasks scheduled before verification plus the client-bundle secrets and bundle-budget task.
- Session state and closure (10): STATE.md task present and build-time ADRs routed to the R-ARCH-14 task; target tier declared; Tier-4 closure gates encoded as must-haves when applicable; drift thresholds (5 open questions, 10 deferred CTAs) stated.

## Anti-patterns refused

- Horizontal layering: phases grouped as all schemas, then all APIs, then all UI; 80 percent done on every layer, zero features work. The planner restructures into vertical slices before emission.
- The half-wired CTA: a button whose chain stalls before a user-visible outcome; a non-empty onClick passed as done. The planner requires per-slice CTA audit tasks whose acceptance is chain completion, not handler existence.
- Hollow scaffold: TODO markers, hardcoded fake-data arrays, Math.random() charts, alert() dialogs shipped as features. The planner encodes the have-nots as zero-hit grep Verify lines at every boundary.
- Coming-soon navigation: sidebar links to unregistered routes, disabled nav items, placeholder pages. The planner writes the full route map first and forbids nav tasks ahead of their routes.
- Login theater: a login page that accepts any credentials, or permission checks that live only in the client. The planner puts bad-credential rejection and server-side enforcement into acceptance lines, with UI hiding named as courtesy.
- Default-theme shipping: unmodified shadcn, Radix, or MUI theme visible to users. The planner forces the visual-identity decision into a task that precedes all component work.
- Slopsquatting: installing a hallucinated package that does not exist on the registry. The planner puts registry verification into the bootstrap task's acceptance.
- Mock-now-wire-later: in-memory or hardcoded persistence with a promise to wire it up later; there is no later. The planner refuses to emit any task whose data source is not the committed persistence layer.
- ADR-less decisions: a non-obvious architectural choice with no record. The planner adds the choice to the architecture module's ADR task (R-ARCH-14) instead of planning a second ADR writer.
- Vague deferral: a deferred CTA or open question whose blocker reads "later" or "soon". The planner requires the five-field entry schema and flags drift past the thresholds.
- Unconfirmed destruction: a task that runs rm -rf, DROP TABLE, git push --force, or a migrate reset without explicit confirmation and a known backup. The planner writes the confirmation requirement into the task itself.
