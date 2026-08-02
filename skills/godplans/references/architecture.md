# Architecture planning module

Turns audit-time architecture discipline into plan-time obligations: the orchestrator loads this module during the architecture domain pass for every archetype except pure marketing-site plans with a single static deployable, where the load-bearing check below usually excludes it with a stated reason.

## Lineage

Descends from architecture-ready (aihxp ready-suite, consolidated in arc-ready), the planning-tier skill that produces system shape and why before any code or tool choice. What carries over: every box, arrow, and decision must have a named flip point and blast radius or it is decoration and gets deleted; storage shape precedes database name; NFR claims are arithmetic, not adjectives; trust boundaries are written to be copied verbatim into the threat model; and the skill refuses itself when architecture is not load-bearing. godplans inverts the audit: instead of scoring an ARCH.md after the fact, PLAN.mdx must satisfy every check before a line of code exists.

## Decisions to force

Ordered hardest-to-reverse first. Each must land in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default. "It depends" is not an answer.

1. System shape. Which of the seven: single-service monolith, modular monolith, service-oriented (3-7 services), microservices (20+), serverless/FaaS, event-driven, edge-native. Hard to reverse because every component boundary, deploy pipeline, and data-ownership rule downstream assumes it; consolidating a premature microservices split rewrites the whole repo (the Prime Video and Segment lesson). Default: modular monolith unless a specific constraint rules it out. Microservices require one named forcing function: independent deploy cadence at team scale, genuinely different scale or availability curves per part, or regulatory/security separation.
2. Data ownership and tenancy. Per entity: one writer, tenancy model (shared-schema, per-tenant-schema, per-tenant-DB), lifecycle (immutable, append-only, mutable, soft-delete), retention. Hard to reverse because tenancy migration means live data migration under uptime pressure. Default: shared-schema with a tenant_id column and single-writer components, unless compliance demands isolation.
3. Storage shape per entity group. Relational, document, key-value, time-series, event log, search, graph, object store; chosen before any product name. Hard to reverse because access patterns calcify around the shape. Naming Postgres at this stage is stackitecture; the pick belongs to the stack pass. Default: relational for entities with cross-entity invariants, object store for blobs.
4. Trust boundary placement. Where network edge, authentication, authorization, and tenant isolation sit, and how each is enforced. Hard to reverse because retrofitting a boundary means auditing every existing call path. Default: authn at the edge, authz in the domain layer, tenant isolation enforced in both query layer and schema (two independent layers).
5. Integration posture per external dependency. Sync vs async, transport, idempotency key and retry policy, failure blast radius. Hard to reverse because callers grow to depend on the timing and delivery semantics. Default: sync for request-path reads, async with at-least-once delivery plus idempotent receivers for mutations; exactly-once is never assumed.
6. Distributed-transaction stance. Adopt cross-service transactions (almost never) or plan the outbox pattern with reconciliation. Hard to reverse because invariant enforcement points spread through the codebase. Default: single-writer boundaries plus outbox; reject two-phase commit.
7. Wire formats and public interface style. What crosses component boundaries and how it versions. Hard to reverse because external consumers freeze it on first use. Default: JSON over HTTP for sync, versioned event payloads for async, with an explicit compatibility rule.

## Plan requirements

Consumed by the orchestrator's inversion pass; each becomes acceptance criteria on concrete tasks.

R-ARCH-1 PLAN.mdx grounds architecture in the product section: the architecture pass runs after product, and every architecture claim traces to a stated entity, NFR, or appetite. If no PRD-equivalent exists, the plan states entities, NFRs, and appetite as explicit assumptions before any shape talk.
Criterion: WHEN the architecture section makes a claim, THE PLAN SHALL trace it to a product requirement or a labeled assumption, and SHALL NOT contain architecture invented without either.

R-ARCH-2 PLAN.mdx records the load-bearing check verbatim: more than one persistence layer, more than one deployable, a load-bearing third-party integration, an NFR that constrains shape, team over 2 and growing, or lifespan over 12 months maintained by others. If none hold, the architecture section is a one-page shape statement (one service, one database, sync calls, one trust boundary) and stops.
Criterion: IF no load-bearing trigger holds, THE PLAN SHALL cap the architecture section at one page and SHALL NOT add ADRs beyond ADR-001.

R-ARCH-3 PLAN.mdx answers the 8 pre-flight questions in writing: purpose, appetite, honest 12-month scale ceiling, binding NFRs, team shape, incumbent stack, external integrations with their failure modes, and the product section's explicit deferrals to architecture.
Criterion: WHEN the architecture section opens, THE PLAN SHALL contain all 8 answers, including a numeric 12-month scale ceiling and at least one named failure mode per external integration.

R-ARCH-4 PLAN.mdx picks exactly one system shape with ADR-001 semantics: alternatives rejected with reasons, the flip point that would reverse the choice, and the blast radius if wrong. The seven listed shapes are the presumptive set; an eighth shape is permitted only when the plan names the constraint that no listed shape satisfies and carries the same flip point and blast radius under the same rigor. Modular monolith is the default; any microservices choice names one of the three forcing functions.
Criterion: WHEN a system shape is stated, THE PLAN SHALL name at least two rejected alternatives, one flip point, and one blast radius; IF the shape is microservices, THE PLAN SHALL name the forcing function or change the shape.

R-ARCH-5 PLAN.mdx enumerates components as domain bounded contexts (Ordering, Billing; never UserService or CoreAPI), each with six fields: bounded context, one-sentence responsibility without compounds, interface (sync/async, wire format, idempotency posture), data ownership with one writer per entity, dependencies, failure posture. No anemic services (thin wrapper over one table) and no god services (owns half the domain).
Criterion: WHEN a component is listed, THE PLAN SHALL populate all six fields; IF a component's responsibility sentence contains "and", THE PLAN SHALL split or rename it.

R-ARCH-6 The component dependency lists in PLAN.mdx form a cycle-free DAG, because the roadmap pass topologically sorts it into waves.
Criterion: WHEN component dependencies are declared, THE PLAN SHALL contain no dependency cycle, and the phase ordering SHALL place load-bearing components before their dependents.

R-ARCH-7 PLAN.mdx specifies data architecture per entity before any tool name: key attributes, cardinality, tenancy model, lifecycle, retention, and a storage shape per entity group. Database product names are banned from the architecture section; they belong to the stack section.
Criterion: WHEN an entity is defined, THE PLAN SHALL state tenancy, lifecycle, retention, and storage shape; IF the architecture section names a database product, THE PLAN SHALL move the name to the stack section and keep only the shape.

R-ARCH-8 PLAN.mdx names cross-entity invariants with their enforcement points and takes an explicit distributed-transaction stance (adopt with justification or reject in favor of the outbox pattern), recorded with ADR-002 semantics for non-obvious storage shapes.
Criterion: WHEN two entities share an invariant, THE PLAN SHALL name the component that enforces it; IF an invariant spans components, THE PLAN SHALL specify outbox or an equivalent pattern rather than a cross-service transaction.

R-ARCH-9 For every integration, PLAN.mdx records four decisions: sync vs async; transport shape and its failure mode; idempotency posture (key, retry policy, dedup window; exactly-once treated as at-least-once plus idempotent receivers); failure blast radius handling (circuit breaker, backoff with jitter, DLQ, or degradation path).
Criterion: WHEN a network mutation appears in any task, THE PLAN SHALL give it an idempotency key and retry policy; WHEN an integration is listed, THE PLAN SHALL state what users experience while it is down.

R-ARCH-10 PLAN.mdx justifies or rejects each heavy pattern by name: event sourcing, CQRS, service mesh, API gateway, Kubernetes, Kafka. Adoption requires a product-grounded ADR; rejection requires one stated reason.
Criterion: IF any heavy pattern appears in the plan, THE PLAN SHALL cite the product constraint that forces it; IF none exists, THE PLAN SHALL record the rejection with a reason.

R-ARCH-11 PLAN.mdx does the NFR math: latency budget decomposed across the request path with p50/p95/p99; throughput per component at the scale ceiling with the bottleneck named; availability chain arithmetic (a 99.9 percent end-to-end target over 3 critical-path components requires roughly 99.97 percent each); per-component scale ceilings; monthly cost envelope at launch and at 12 months. Infeasible math forces a shape or target change, and the plan names which.
Criterion: WHEN an NFR target is stated, THE PLAN SHALL show the decomposition arithmetic; IF the arithmetic fails the target, THE PLAN SHALL change the shape or the target and say so.

R-ARCH-12 PLAN.mdx contains no bare quality adjectives: scalable, resilient, performant, reliable, observable, cloud-native, future-proof. Each instance is replaced with a number or moved to Open Questions with an owner and a recommended default.
Criterion: WHEN the plan is emitted, a grep for the banned adjective list in the architecture section SHALL return only lines that also contain a number or an Open Questions reference.

R-ARCH-13 PLAN.mdx names the four trust boundaries (network edge, authentication, authorization, tenant/data isolation), each with location, what it protects, what an attacker gains if it falls, and enforcement (two independent layers for load-bearing boundaries, or an acknowledged single-layer risk). It also lists the highest-blast-radius mutations: cross-tenant delete, admin impersonation, billing modification, password reset, API key rotation, export-all endpoints. This section is written to be consumed verbatim by the security module's threat model.
Criterion: WHEN trust boundaries are declared, THE PLAN SHALL cover all four with all four attributes each, and the security section SHALL reference this list rather than restate it.

R-ARCH-14 PLAN.mdx commits to ADR discipline as tasks: at minimum ADR-001 (shape), ADR-002 (storage), ADR-003 (trust boundaries), plus one per non-obvious decision; every ADR includes flip point and blast radius fields; ADRs live in-repo at a stated path. This module owns `decide.adr` in the documentation set, so no other pass plans an ADR-writing task; the repo module records the row and defers here (repo.md R-REPO-14 and R-REPO-23). ADRs are immutable: a superseded ADR is never deleted and never edited, a new number supersedes it with `supersedes` on the new file and `superseded_by` plus a superseded status on the old, and numbers are never reused, because a citation written last year has to keep resolving to the same decision.
Criterion: WHEN the plan lists decisions, THE PLAN SHALL contain tasks that write ADR files with flip point and blast radius fields, the task Acceptance lines SHALL be grep-verifiable against those fields, no task outside this module SHALL write a file under the ADR path, and any task that replaces an accepted ADR SHALL mint a new number carrying supersedes and superseded_by rather than editing the original.

R-ARCH-15 PLAN.mdx plans version-controlled text diagrams: a mermaid component diagram with trust boundaries (C4 Level 1 equivalent) in the plan itself, and a Level 2 container diagram task with every arrow labeled with protocol and purpose before build starts; maximum 15 boxes per diagram; every element backed by a decision; no image exports, no cloud-vendor icon diagrams.
Criterion: WHEN a diagram appears, every arrow SHALL carry a protocol and purpose label, and every box SHALL correspond to a component or decision in the plan; IF an element has no backing decision, THE PLAN SHALL delete it.

R-ARCH-16 PLAN.mdx names at least three architecture fitness functions with tooling and CI enforcement points: dependency conformance (dependency-cruiser, ArchUnit, or equivalent), data-ownership conformance, and an NFR probe; at least one is wired as a build-phase task, not an aspiration.
Criterion: WHEN fitness functions are named, THE PLAN SHALL bind each to a tool and a CI step, and at least one SHALL appear as a task with a Verify command.

R-ARCH-17 PLAN.mdx makes the architecture section self-sufficient for downstream passes: the stack section can pick tools from the stated storage, compute, and integration shapes plus NFR constraints; the roadmap section can order phases from the component DAG; the build tasks can copy trust boundaries and idempotency postures without re-deriving them.
Criterion: WHEN the stack, roadmap, or build pass runs, THE PLAN SHALL already contain the shapes, constraints, and DAG it needs, without a new user interview.

R-ARCH-18 PLAN.mdx schedules architecture lifecycle work: a sign-off checkpoint where presenting the plan is the attestation request, and a post-build drift audit task in the final Verification phase comparing built system to planned shape (the ghost-architecture catch), scheduled within 30-90 days of build completion.
Criterion: WHEN the final phase is written, THE PLAN SHALL contain a drift-audit task whose Acceptance compares running components, data owners, and boundaries against the plan's declarations.

R-ARCH-19 The architecture section of PLAN.mdx stays under three pages of prose (tables, diagrams, and ADR tasks excluded) and survives the substitution test: swap the domain nouns (orders for tickets) or the storage shape and the text must become false, or it is decoration and gets cut.
Criterion: WHEN the architecture section is drafted, THE PLAN SHALL contain no paragraph that reads equally true for an unrelated product; any such paragraph SHALL be deleted or made specific.

R-ARCH-20 When the system exposes an API or service surface, PLAN.mdx settles the API contract: the API style (REST, GraphQL, or RPC) and why; a versioning strategy that does not break existing consumers; a machine-readable contract (an OpenAPI document or a GraphQL schema) as a planned artifact; consistent resource and URI modeling for REST; a single error envelope (RFC 7807 Problem Details or a documented equivalent); and the interaction-safety postures, an idempotency key on retryable unsafe operations and connection authentication plus resource bounds on any real-time (WebSocket or SSE) surface.
Criterion: WHEN an API surface is planned THE PLAN SHALL name the API style, the versioning strategy, the contract artifact, and the error envelope, and SHALL require an idempotency key on retryable create-or-charge endpoints and authenticated, bounded real-time connections, each with a Verify line.

## Task seeds

- [ ] GP-xxx Write ADR corpus for shape, storage, and trust boundaries
  - Files: docs/adr/001-system-shape.md, docs/adr/002-storage-shapes.md, docs/adr/003-trust-boundaries.md
  - Acceptance: each file contains the strings "Flip point:" and "Blast radius:" and an "Alternatives rejected" section with at least two entries
  - Verify: grep -l "Flip point:" docs/adr/00*.md | wc -l | grep -q 3
  - Requirements: R-ARCH-4, R-ARCH-8, R-ARCH-14

- [ ] GP-xxx Author C4 Level 2 container diagram with labeled arrows
  - Files: docs/architecture/containers.mmd
  - Acceptance: mermaid source; every edge label contains a protocol token (HTTP, gRPC, queue, or event); box count 15 or fewer
  - Verify: grep -q -- "-->" docs/architecture/containers.mmd && test "$(grep -c -- "-->" docs/architecture/containers.mmd)" -eq "$(grep -cE -- "-->\|[^|]*(HTTP|gRPC|queue|event)" docs/architecture/containers.mmd)"
  - Requirements: R-ARCH-15

- [ ] GP-xxx Wire dependency-conformance fitness function into CI
  - Files: .dependency-cruiser.cjs, .github/workflows/ci.yml
  - Acceptance: rule set forbids imports that cross bounded-context directories except through each context's public index; CI workflow runs the check on every push
  - Verify: npx dependency-cruiser --config .dependency-cruiser.cjs src && grep -q "dependency-cruiser" .github/workflows/ci.yml
  - Requirements: R-ARCH-16

- [ ] GP-xxx Implement outbox pattern for cross-context mutations
  - Files: src/shared/outbox/outbox.ts, migrations/NNN_create_outbox.sql, src/shared/outbox/dispatcher.ts
  - Acceptance: outbox table written in the same transaction as the domain mutation; dispatcher retries with backoff and jitter; consumer handlers deduplicate on an idempotency key column
  - Verify: grep -q "idempotency_key" migrations/*outbox*.sql && grep -rq "outbox" src/shared/outbox/dispatcher.ts
  - Requirements: R-ARCH-8, R-ARCH-9

- [ ] GP-xxx Enforce tenant isolation at two independent layers
  - Files: src/shared/db/scoped-client.ts, migrations/NNN_row_level_security.sql
  - Acceptance: query layer requires a tenant id on every accessor (no raw-client export); schema layer enforces row-level policies on every tenant-owned table
  - Verify: grep -q "tenant_id" src/shared/db/scoped-client.ts && grep -qi "row level security" migrations/*row_level*.sql
  - Requirements: R-ARCH-13

- [ ] GP-xxx Run NFR probe against the latency and availability budget
  - Files: tests/nfr/latency-probe.test.ts, docs/architecture/nfr-budget.md
  - Acceptance: probe asserts the planned p95 budget per request-path hop; budget doc contains the availability chain arithmetic with per-component targets
  - Verify: npx vitest run tests/nfr/latency-probe.test.ts && grep -q "p95" docs/architecture/nfr-budget.md
  - Requirements: R-ARCH-11, R-ARCH-16

- [ ] GP-xxx Post-build architecture drift audit
  - Files: docs/architecture/drift-audit.md
  - Acceptance: audit compares deployed components, single-writer ownership, and trust-boundary enforcement against PLAN.mdx declarations; every mismatch gets a superseding ADR or a fix task, never a silent edit
  - Verify: grep -q "drift" docs/architecture/drift-audit.md && grep -qc "PLAN.mdx" docs/architecture/drift-audit.md
  - Requirements: R-ARCH-18

## Self-audit rubric

100 points total. Score the drafted architecture section before emission; below 85 forces a revision pass.

- Grounding and load-bearing check (10): product-traced claims or labeled assumptions; load-bearing check recorded; all 8 pre-flight answers present with a numeric scale ceiling. Full marks require zero ungrounded claims.
- System shape decision (15): exactly one shape, ADR-001 semantics complete, default honored or overridden with a named constraint, microservices forcing function named if applicable.
- Components and data architecture (20): all six fields per component, cycle-free DAG, single writer per entity, tenancy/lifecycle/retention per entity, storage shapes with zero database product names in the section.
- Integrations and idempotency (10): four decisions per integration, idempotency key and retry policy on every network mutation, heavy patterns each justified or rejected.
- NFR arithmetic (15): latency decomposition, throughput at ceiling, availability chain math, cost envelope at launch and 12 months, zero unresolved banned adjectives.
- Trust boundaries (15): four boundaries with four attributes each, dual-layer enforcement or acknowledged risk, highest-blast-radius mutation list present and referenced by the security section.
- ADR, diagram, and fitness discipline (10): three or more ADR tasks with flip point and blast radius, labeled-arrow diagrams within the box cap, three named fitness functions with one wired as a task.
- Handoff and lifecycle (5): stack/roadmap/build passes need no re-interview; drift audit scheduled in the final phase.

## Anti-patterns refused

- Architecture theater: boxes and arrows no one can name a flip point for. The planner deletes any element without a reversing condition.
- Paper-tiger architecture: shape claims with no latency, throughput, or availability arithmetic. The planner refuses to emit NFR targets without the decomposition math.
- Cargo-cult cloud-native: Kubernetes, Kafka, mesh, event sourcing, CQRS, or a gateway without a product-grounded constraint. The planner records a rejection with a reason instead.
- Stackitecture: a tool list posing as architecture, or a data section that jumps to a database name. The planner strips product names from the architecture section and keeps only shapes; the pick moves to the stack pass.
- Resume-driven architecture: novelty chosen for the builder, not the product. The planner applies the default (modular monolith, relational, sync-first) unless a constraint overrides it.
- Invisible/horoscope architecture: prose that reads the same for any product. The planner runs the substitution test and cuts every paragraph that survives a noun swap.
- Ghost architecture: the plan describes one system and the build produces another. The planner schedules the drift audit task in the final phase so the mismatch is caught, not assumed away.
- Distributed monolith: multiple services writing one table, or sync chains across services on every request. The planner enforces single-writer ownership and flags request-path sync fan-out as a shape error.
- Anemic and god services: a component wrapping one table, or one owning half the domain. The planner merges or splits at bounded-context lines before tasks are cut.
- Silent NFR numbers and silent trust boundaries: targets or boundaries implied but never written. The planner blocks emission until both sections carry explicit values.
- Unlabeled diagram arrows: an edge with no protocol and purpose. The planner labels or deletes it.
- Prose bloat: architecture narrative past three pages. The planner moves detail into ADR tasks and tables and caps the prose.
- Bare-adjective claims: scalable, resilient, future-proof as assertions. The planner replaces each with a number or an owned open question with a recommended default.
