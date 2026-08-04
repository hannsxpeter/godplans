# Code quality planning module

Plans the code quality sections of PLAN.mdx: quality budgets, testing discipline, error handling, performance rules, dependency hygiene, docs, and observability hooks. The orchestrator loads this module for every archetype that ships code; only pure marketing-site plans with zero application code may exclude it, with the reason stated in the applicability matrix.

## Lineage

Descends from codeauditor, the read-only end-of-project audit that scores a codebase 0-100 across nine weighted dimensions (SEC 20, ARC 15, QUAL 15, TEST 15, ERR 10, PERF 8, DEP 7, DOC 5, OBS 5) and hunts paper constructs: uncalled validators, assertion-free tests, unconditional-200 health checks. This module inverts every one of those checks into a plan-time obligation. What carries over is the discipline, not the report format: evidence over assertion, the substitution test (a line that reads equally true for any project is filler), named failure modes, one-change-one-verification, and the hard-cap rule that a single Critical never averages away. Security-dimension checks (SEC) are owned by security.md; this module owns the other eight dimensions and cross-references SEC where the audit lenses overlap.

## Decisions to force

1. Typing strictness. Question: does the project run with the strictest type checking the language offers, or with escape hatches allowed? Hard to reverse because retrofitting strict mode onto a lax codebase means touching every file, and every untyped any that ships becomes load-bearing. Options: (a) strict from commit one, escape hatches require a recorded reason inline; (b) gradual strictness with a ratchet (new files strict, legacy grandfathered); (c) dynamic, no checker. Default: (a) for greenfield, (b) for brownfield. Never (c) where the language supports checking.

2. Test determinism architecture. Question: are clock, randomness, and network injected as dependencies, or reached for globally? Hard to reverse because code that calls the wall clock or live network directly cannot be made deterministic without rewriting call sites; flakiness is designed in on day one. Options: (a) injected clock, seeded RNG, no live network in tests, order-independent suites; (b) ad hoc, mock later. Default: (a); (b) is refused.

3. Error propagation policy. Question: do errors propagate with cause preserved to a boundary that can act, or get caught and logged where they occur? Hard to reverse because a swallow-and-continue idiom, once copied across handlers, is a systemic pattern the audit clusters as one root-cause finding with dozens of members. Options: (a) rethrow-with-cause to a named boundary layer, empty catches banned by lint rule; (b) per-module discretion. Default: (a).

4. Quality budget numbers. Question: what are the maximum function length, file length, nesting depth, and parameter count, and which lint config enforces them? Hard to reverse because budgets adopted after growth require mass refactors; budgets adopted first shape every function written. Options: (a) concrete numbers in the plan wired to lint rules in CI; (b) team judgment. Default: (a) with starting values of 50-line functions, 400-line files, nesting depth 4, 5 parameters, adjusted per language idiom and recorded in the plan.

5. Data-access discipline on hot paths. Question: which queries are on hot paths, and what pagination, batching, and index rules govern them? Hard to reverse because N+1 shapes and unpaginated list endpoints work fine at demo scale and fail at real scale, after clients depend on the response shape. Options: (a) hot paths named in the plan with per-path rules (eager load or batch, pagination on every list, index plan matching query shapes); (b) optimize when it hurts. Default: (a). Coordinates with database.md for the index plan itself.

6. Dependency intake bar. Question: what must be true before a package is added? Hard to reverse because removing an entrenched dependency is a project; a floating version that breaks reproducibility poisons every future bisect. Options: (a) committed lockfile with pinned versions from the first commit, plus selection criteria (maintained, minimal transitive surface, one package per job, license fits distribution model) and an advisory-audit tool in CI; (b) install as needed. Default: (a).

7. Docs-with-code coupling. Question: do docs update in the same change as the feature, or on a separate track? Hard to reverse because drift is cumulative and invisible: once README instructions stop matching the scripts, no single change is to blame and nobody owns the fix. Options: (a) same-change rule, stated in the plan and checked at review; (b) periodic docs sprints. Default: (a).

## Plan requirements

R-CODE-1: PLAN.mdx declares project maturity, ambition, and deployment context (prototype, internal tool, or production service) in one sentence near the objective, because every quality bar in this module scales to that declaration and the end-of-project audit calibrates its grading to it.
Criterion: WHEN the plan is emitted, THE PLAN SHALL contain an explicit maturity declaration that names the deployment context, and every quality requirement that scales with maturity SHALL reference it rather than assume production defaults.

R-CODE-2: PLAN.mdx contains a layer diagram (mermaid graph TD) with the allowed dependency direction stated as a rule (which layer may import which), so the audit finding "presentation reaches straight into the database" is impossible by construction.
Criterion: WHEN architecture is planned, THE PLAN SHALL name each layer, state the one allowed dependency direction, and forbid layer-skipping imports as a lintable or reviewable rule.

R-CODE-3: PLAN.mdx assigns module boundaries and single responsibilities, and names one canonical pattern per feature kind (e.g. "new endpoints copy the shape of the first endpoint task") so similar features are built the same way instead of each reinventing the wheel.
Criterion: WHEN two or more tasks build features of the same kind, THE PLAN SHALL name the canonical exemplar task the later ones copy, and the later tasks SHALL reference it in their descriptions.

R-CODE-4: PLAN.mdx states where state and config live and the abstraction policy: repeated logic gets a shared helper, and no speculative indirection is built for problems the project does not have (over-engineering and under-abstraction are both audit findings).
Criterion: IF a task introduces an abstraction layer, THE PLAN SHALL record the concrete duplication or variation it resolves; IF none exists yet, THE PLAN SHALL defer the abstraction to an open question with a default of "inline until the second use."

R-CODE-5: PLAN.mdx sets numeric quality budgets (max function length, max file length, max nesting depth, max parameter count), bans magic values in favor of named constants, bans dead code, and names the single lint and format config that enforces all of it in CI.
Criterion: WHEN quality budgets are planned, THE PLAN SHALL state each budget as a number wired to a named lint rule, and the CI task SHALL list the lint command whose exit code enforces them.

R-CODE-6: PLAN.mdx defines the typing policy per decision 1: no untyped any, no unchecked casts, no disabled checks without a recorded inline reason, with the checker's strict flags named.
Criterion: WHEN the language supports static checking, THE PLAN SHALL name the checker, its strict configuration, and the escape-hatch rule; IF the project is brownfield, THE PLAN SHALL state the ratchet mechanism for legacy files.

R-CODE-7: PLAN.mdx defines the TODO/FIXME/HACK marker policy: every marker references a tracked issue, and a CI or review check prevents silent accumulation.
Criterion: IF a task's code may legitimately carry a deferred-work marker, THE PLAN SHALL require the marker to embed an issue reference, and SHALL name the grep or lint check that fails on bare markers.

R-CODE-8: PLAN.mdx enumerates the critical paths by name (authentication, authorization, payments, data mutations, anything irreversible) and requires tests for each critical path before the owning feature task can be checked off.
Criterion: WHEN critical paths exist, THE PLAN SHALL list them in the requirements section, and every task touching one SHALL carry a test acceptance criterion naming that path.

R-CODE-9: PLAN.mdx specifies test types per layer (unit, integration, e2e) and a test-quality bar: no assertion-free tests, no unreviewed snapshot-only tests, no over-mocked tests that test the mock; edge and error cases are planned alongside happy paths.
Criterion: WHEN testing is planned, THE PLAN SHALL map each layer to a test type with at least one named example per type, and SHALL state the assertion-quality rules as review criteria, not aspirations.

R-CODE-10: PLAN.mdx requires deterministic tests by design per decision 2: injected clocks, seeded randomness, no live network calls in tests, order independence; and wires the full suite into CI from the first commit so tests run automatically rather than existing unrun.
Criterion: WHEN the first test task is planned, THE PLAN SHALL already contain a CI task that runs the suite on every push, ordered before or in the same wave, and the determinism rules SHALL appear as acceptance criteria on the test scaffolding task.

R-CODE-11: PLAN.mdx never plans a coverage claim (badge, threshold, percentage) it does not also plan the machinery to maintain, because coverage drift between claim and reality is an audit finding.
Criterion: IF the plan includes any coverage number or badge, THE PLAN SHALL include the CI step that computes and enforces it; otherwise THE PLAN SHALL make no coverage claim.

R-CODE-12: PLAN.mdx defines the error-handling policy per decision 3: no swallowed errors, no empty catch blocks, no catch-log-and-continue where continuing is wrong, rethrow with cause preserved, errors surfaced at a named boundary where someone can act.
Criterion: WHEN error handling is planned, THE PLAN SHALL name the boundary layer that renders or reports errors, and SHALL state the lint rule or review check that bans empty catches and ignored error returns.

R-CODE-13: PLAN.mdx states an I/O policy: every network and disk call has a timeout, retries use backoff (no retry storms), and the policy names the helper or client configuration that applies it uniformly.
Criterion: WHEN any task performs network or disk I/O, THE PLAN SHALL require timeout and backoff values via the shared client or helper, not per-call-site improvisation.

R-CODE-14: PLAN.mdx identifies multi-step operations and specifies their transactional boundaries and rollback behavior, so partial completion cannot leave inconsistent state; and specifies resource cleanup patterns (finally, defer, context managers) for files, connections, locks, and threads including error paths.
Criterion: IF a planned operation mutates more than one record, file, or external system, THE PLAN SHALL state its transaction or compensation boundary, and the owning task SHALL carry a cleanup-on-error acceptance criterion.

R-CODE-15: PLAN.mdx names the hot paths and sets data-access rules per decision 5: no N+1 (eager load or batch), no queries inside loops, pagination on every list query, and an index plan matching intended query shapes (index details delegated to the database section).
Criterion: WHEN a task implements a list endpoint or a per-item lookup inside iteration, THE PLAN SHALL require pagination or batching respectively as a grep-verifiable acceptance criterion on that task.

R-CODE-16: PLAN.mdx carries the cache and queue decisions made upstream into code obligations rather than settling them a second time: a cached read path carries the tier, staleness budget, invalidation trigger, and stampede protection set by R-ARCH-23, and a queue carries the bounded depth and full policy set by R-ARCH-24 (whether a cache is warranted at all is R-ARCH-23's arithmetic, not a judgement made here). This module owns what those decisions imply in code: non-blocking I/O on request and hot paths, and a growth bound on every long-lived in-process structure (caches, queues, buffers get a max size or eviction rule).
Criterion: IF the plan introduces a cache, THE PLAN SHALL carry the four R-ARCH-23 fields on that read path rather than an invalidation rule alone; IF the plan introduces a queue, THE PLAN SHALL carry its R-ARCH-24 depth bound and full policy; IF the plan introduces any long-lived in-process collection, THE PLAN SHALL state its growth bound.

R-CODE-17: PLAN.mdx requires a committed lockfile with pinned versions and reproducible installs from the first commit, and states the dependency selection criteria and update cadence per decision 6, with an advisory-audit tool named in the CI task.
Criterion: WHEN the scaffold task is planned, THE PLAN SHALL include committing the lockfile in its acceptance criteria, and the CI task SHALL name the audit command (e.g. the ecosystem's advisory scanner) that runs on every push.

R-CODE-18: PLAN.mdx plans the README to contain setup, build, and run instructions that will be verified by following them, states the docs-update-with-feature rule per decision 7, and requires every shipped endpoint, flag, and env var to be documented, so no phantom or missing docs exist at audit time.
Criterion: WHEN the docs task is planned, THE PLAN SHALL include an acceptance criterion that a fresh clone reaches a running state using only the README, and every task that adds an endpoint, flag, or env var SHALL carry a docs line in its acceptance criteria.

R-CODE-19: PLAN.mdx specifies structured logging at boundaries with secret and PII redaction, metrics or tracing for critical operations, and health and readiness checks that verify real dependencies, never returning 200 unconditionally (the paper health check is a named audit refusal). Depth of the observability stack is owned by observe.md; this requirement guarantees the code-level hooks exist.
Criterion: WHEN a service archetype is planned, THE PLAN SHALL contain a task whose acceptance criteria include a health check that exercises at least one real dependency, and the logging task SHALL name the redaction rule.

R-CODE-20: PLAN.mdx specifies config separated from code with per-environment settings, a reproducible build, a documented run procedure, and a schema or data migration story, all scaled to the declared maturity from R-CODE-1.
Criterion: WHEN operability is planned, THE PLAN SHALL place config in environment or a config layer with per-env values, and IF the project has a schema, THE PLAN SHALL name the migration mechanism before the first schema task.

R-CODE-21: PLAN.mdx structures every deliverable as a small, atomic, independently verifiable task with a stated Verify command, mirroring the audit protocol of one finding, one change, verified; no task bundles unrelated changes.
Criterion: WHEN tasks are emitted, EVERY task SHALL have 2-4 grep-verifiable acceptance conditions and one Verify command whose exit code proves completion; IF a task cannot state such a command, THE PLAN SHALL split or respecify it.

R-CODE-22: PLAN.mdx contains no banned vague obligations: "improve error handling", "add more tests", "refactor for clarity", or any line failing the substitution test. Every quality obligation says what to change, where, and how to confirm it worked.
Criterion: WHEN the self-audit gate runs, THE PLAN SHALL contain zero recommendations of the banned forms, verifiable by grep for the banned phrases and by spot-checking that each quality line names a file, rule, or command.

R-CODE-23: PLAN.mdx keeps controls live and state machines lawful and time-correct: every operator-configurable or stored flag meant to gate behavior is planned with the code path that READS it (not only writes and displays it); every lifecycle state machine names its legal transitions and a rule that no transition frees a still-committed resource (inventory slot, access grant, credit hold) before its end or runs out of lifecycle order; and all scheduling and availability arithmetic uses the entity's configured timezone with daylight-saving handling, never server UTC.
Criterion: WHEN a control flag, a state machine, or a scheduling or availability feature is planned THE PLAN SHALL name the read site for each gating flag, the transition table with its resource-release guard, and the timezone source, each with a test (a flag set on that changes behavior, an illegal or early-release transition that is rejected, a non-UTC-timezone slot that lands on the local wall clock).

R-CODE-24: PLAN.mdx verifies behavioral requirements against the running app, not only by static reading or unit tests. The class of requirement that static inspection can state but not prove (race conditions and TOCTOU, dead controls that are stored but never read, lifecycle transitions that free a resource early, authorization on non-primary caller paths, and consent or accessibility behavior that appears only at runtime) is confirmed in the Verification phase by an end-to-end or browser harness driving the real flow.
Criterion: WHEN a requirement is behavioral (concurrency, a gating flag, a state transition, a non-primary caller path, or runtime consent or accessibility) THE PLAN SHALL include an end-to-end or browser test that drives the real flow and asserts the expected outcome, not only a unit test or static grep.

## Task seeds

- [ ] GP-xxx Wire lint, format, and type checking into CI with quality budgets
  - Files: .github/workflows/ci.yml, eslint.config.js (or ruff.toml, .golangci.yml per stack), tsconfig.json
  - Acceptance: lint config sets max function length, max nesting, and no-magic-numbers rules with the numbers from the Decisions section; type checker runs in strict mode with zero suppressions; CI fails on any lint or type error
  - Verify: npx eslint . && npx tsc --noEmit (or the stack's equivalent lint and check commands)
  - Requirements: R-CODE-5, R-CODE-6, R-CODE-7

- [ ] GP-xxx Scaffold deterministic test harness and run it in CI
  - Files: tests/helpers/clock.ts, tests/helpers/seed.ts, tests/setup.ts, .github/workflows/ci.yml
  - Acceptance: test setup injects a fake clock and seeded RNG; network access in tests fails fast by default; CI workflow runs the full suite on every push; at least one example test per layer (unit, integration) exists with real assertions
  - Verify: npm test -- --run && ! grep -rLE 'expect\(' tests/ --include='*.test.ts'
  - Requirements: R-CODE-9, R-CODE-10, R-CODE-11

- [ ] GP-xxx Establish error boundary and I/O policy helpers
  - Files: src/lib/errors.ts, src/lib/http-client.ts, src/middleware/error-handler.ts
  - Acceptance: shared HTTP client sets a default timeout and backoff retry; error handler is the single boundary that logs with cause chain and returns generic client-facing messages; lint rule banning empty catch blocks is enabled
  - Verify: grep -rn "catch {}" src/ returns nothing and grep -n "timeout" src/lib/http-client.ts returns a match
  - Requirements: R-CODE-12, R-CODE-13

- [ ] GP-xxx Write critical-path tests for auth and data mutations
  - Files: tests/integration/auth.test.ts, tests/integration/mutations.test.ts
  - Acceptance: every critical path named in the Requirements section has at least one test asserting both the success case and one failure case; no test relies on wall-clock time or live network; tests pass in CI
  - Verify: npm test -- --run tests/integration/
  - Requirements: R-CODE-8, R-CODE-9, R-CODE-10

- [ ] GP-xxx Pin dependencies and add advisory audit to CI
  - Files: package-lock.json (or the ecosystem lockfile), .github/workflows/ci.yml
  - Acceptance: lockfile committed; no floating major versions in the manifest; CI runs the ecosystem advisory scanner and fails on known-vulnerable versions; no two packages doing the same job in the manifest
  - Verify: npm ci && npm audit --audit-level=high
  - Requirements: R-CODE-17

- [ ] GP-xxx Implement real health check and structured logging hooks
  - Files: src/routes/health.ts, src/lib/logger.ts
  - Acceptance: health endpoint queries at least one real dependency (database ping or equivalent) and returns non-200 when it fails; logger emits structured output with a redaction list covering secrets and PII fields; no console.log calls outside the logger module
  - Verify: grep -rn "console.log" src/ --include="*.ts" | grep -v lib/logger returns nothing
  - Requirements: R-CODE-19, R-CODE-20

- [ ] GP-xxx Verify README from a clean clone
  - Files: README.md, scripts/dev.sh
  - Acceptance: README setup, build, and run sections name the exact commands from package scripts; following them from a fresh clone reaches a running state; every shipped env var appears in the configuration section
  - Verify: bash -n scripts/dev.sh and diff of documented commands against the scripts block in package.json shows no drift
  - Requirements: R-CODE-18

## Self-audit rubric

Score the emitted code quality sections 0-100. Any dimension below its full-marks bar drags the module score; below 85 total, revise before emission.

- Budgets and typing (20): full marks when every quality budget is a number wired to a named lint rule, the typing policy names the checker and strict flags, the marker policy names its enforcement check, and all of it appears in a CI task's Verify line.
- Testing discipline (20): full marks when critical paths are enumerated by name, each has a test obligation on its owning task, test types map to layers with examples, determinism rules are acceptance criteria on the harness task, and CI runs the suite from the first wave.
- Error handling and resilience (15): full marks when the error boundary is named, empty catches are lint-banned, every I/O call inherits timeout and backoff from a shared helper, multi-step operations have stated transaction boundaries, and cleanup-on-error is an acceptance criterion where resources are held.
- Architecture conventions (15): full marks when the layer diagram exists with a stated dependency direction, canonical exemplar tasks are named for repeated feature kinds, and every abstraction in the plan cites the concrete duplication it resolves.
- Performance rules (10): full marks when hot paths are named, list queries carry pagination criteria, iteration-plus-query shapes carry batching criteria, and every cache or long-lived collection states its invalidation or growth bound.
- Dependencies (8): full marks when the lockfile commitment is in the scaffold task, selection criteria and update cadence are stated, and the advisory scanner is named in CI.
- Docs and drift (6): full marks when the README verification criterion exists, the docs-update-with-feature rule is stated, and endpoint, flag, and env var tasks carry docs lines.
- Operability hooks (6): full marks when the health check exercises a real dependency, logging is structured with a named redaction rule, and config, build, run, and migration stories match the declared maturity.

## Anti-patterns refused

- Paper constructs: middleware defined but never mounted, validators never called, health checks returning 200 unconditionally, rate limiters that do not limit. The planner writes wiring proof into acceptance criteria (the grep that shows the middleware is applied), never just the artifact's existence.
- Assertion-free testing: tests that run without asserting, snapshot-only suites nobody reviews, mocks testing themselves. The planner refuses any test task whose acceptance criteria do not name what is asserted.
- Vague obligations: "improve error handling", "add more tests", "refactor for clarity". Refused outright; every obligation names the file, rule, or command and how to confirm it worked.
- Coverage theater: a badge or threshold claim with no CI machinery behind it. The planner either plans the enforcement step or plans no claim.
- Swallow-and-continue: empty catches and ignored error returns copied as an idiom. Refused by lint-banning the shape in the plan rather than hoping reviewers catch each instance.
- Averaging away risk: treating one Critical-grade gap as acceptable because other sections are strong. The source auditor caps the dimension at 69 and the overall at 79; the planner mirrors this by refusing to emit while any known Critical-class gap (untested critical path, no lockfile, no error boundary) remains unplanned.
- Substitution-test failures: quality prose that would read equally true for any project. Cut during the self-audit gate; only lines naming this project's paths, budgets, and commands survive.
- Silent scope widening: bundling unrelated cleanups into one task. Refused by the one-task-one-verifiable-change rule from R-CODE-21; extra work becomes its own task with its own Verify line.
