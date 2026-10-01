# Deployment planning module

Plans the shipping mechanics of PLAN.mdx: how a known-green build reaches real user-facing environments safely, repeatably, and reversibly. The orchestrator loads this module for any archetype that runs a service users hit (saas-dashboard, api-service, marketing-site with a server, ml-pipeline serving, mobile-app backend). Excluded for library and local-only cli archetypes with the reason "distribution is packaging and release, not deployment". Tool choice belongs to stack.md, monitoring wiring to observe.md, secret vault selection to security.md.

## Lineage

Descends from deploy-ready, the shipping-tier ready-suite skill built on the principle that what rolls back is code, not data. The disciplines that carry over: same-artifact promotion (one hermetic build, one content hash, never rebuilt per environment), the reversible-vs-data-forward change classification, expand/contract as a multi-deploy calendar rather than a migration, the paper-canary four-field rule, the Mode-A first-deploy cold-start gates, and the eight-gate pipeline with an enforced approval. godplans inverts these from ship-time enforcement into plan-time requirements: the plan is written so that a deploy-ready audit run after the project ships finds every gate already satisfied by construction.

## Decisions to force

1. Artifact identity: one hermetic build promoted unchanged, or rebuild per environment?
Why hard to reverse: once per-environment rebuilds exist, environment-specific build flags, caches, and baked config accrete around them; artifact drift becomes invisible and no promotion is ever again a promotion. Options: (a) single content-hashed artifact promoted dev -> staging -> prod, hash verified at the final promote (default); (b) platform-native per-region rebuild with the source commit and build config pinned and recorded as the artifact identity. Never an unpinned rebuild.

2. Migration policy: expand/contract calendar as the standing rule, or single-deploy migrations?
Why hard to reverse: a single-deploy migration habit bakes ACCESS EXCLUSIVE lock risk into every future schema change, and every expand left uncontracted compounds debt a later session must rediscover before it can ship anything. Options: (a) every data-forward change decomposed into expand, migrate, cutover, and contract, each its own deploy at a distinct calendar point (default); (b) expand-only-by-design with a one-line reason recorded per change. Never contract bundled with expand.

3. Promotion ladder: which rungs exist (build -> preview -> staging -> canary -> prod) and what parity gap each accepts?
Why hard to reverse: each rung accretes DNS, TLS, IAM, data, and cost; adding a rung later means a fresh cold-start deploy, and removing one silently deletes a gate. Options: full ladder (default when real users or money are on the line); compact build -> staging -> prod with the parity gap of every rung written down (default for a solo pre-launch project). Never a silent parity gap.

4. Approval gate mechanism: what makes shipping a choice rather than a side effect of committing?
Why hard to reverse: once tooling and habit assume auto-deploy-on-push, unwinding it is a workflow migration, and the first bad push to main is a prod incident. Options: (a) environment protection rule requiring review (default for teams); (b) solo-builder distinct second action: signed tag, explicit deploy command, or deploy-marker commit (default solo). Never a Slack-ping convention.

5. Rollout strategy default: canary, or all-at-once with a named blast radius?
Why hard to reverse: a canary needs a metric path that observability planning must budget now; claiming canary without one manufactures paper canaries on every future change. Options: (a) canary with all four fields, when observe.md is applicable (default in that case); (b) all-at-once with a named blast-radius justification (default otherwise). Never "we will watch Grafana for a bit".

6. Secrets and identity split: how does config reach the runtime, and is the deploy identity distinct from the runtime identity?
Why hard to reverse: a secret baked into an image layer or git history cannot be unbaked; rotation, audit, and incident forensics all inherit the mistake. Options: platform environment injection at runtime (default); vault-sourced injection (vault choice routes to security.md). Always: least-privileged runtime identity, distinct from the identity that deploys.

## Plan requirements

R-DEPLOY-1. The plan states build provenance: one deterministic hermetic build producing one content-hashed artifact, promoted unchanged across every environment; platform-native per-region rebuilds record the source commit and build config pin as the artifact identity.
Criterion: WHEN the plan describes the pipeline THE PLAN SHALL name the single build step, the hash check at the final promote, and contain no per-environment rebuild step.

R-DEPLOY-2. The plan separates artifact from configuration: config and secrets inject at runtime, never at build time.
Criterion: WHEN the plan defines the artifact THE PLAN SHALL state that the image contains no environment-specific values and no build-time secrets.

R-DEPLOY-3. Every change the plan ships is classified: reversible (code-only), data-forward (schema or data mutation), mixed, or side-effectful (emails sent, payments captured).
Criterion: WHEN a phase contains tasks that alter production behavior THE PLAN SHALL assign each task one of the four change classes.

R-DEPLOY-4. Each change class carries its required rollback artifact: reversible gets the exact revert command plus a time-to-revert estimate; data-forward gets a compensating-forward plan plus a pre-migration restore point; side-effectful gets an idempotency guard plus an explicit acknowledgement that rollback does not recall sent effects.
Criterion: WHEN a change is classified THE PLAN SHALL attach the class-matched artifact and SHALL NOT pair "rollback: redeploy previous image" with any schema or data migration.

R-DEPLOY-5. Every data-forward change is decomposed into an expand/contract calendar: expand (additive), migrate (dual-write or backfill), cutover, and contract phases, each its own deploy, with contract in a later wave than expand.
Criterion: WHEN any schema or data mutation appears THE PLAN SHALL schedule the four phases as separate deploys at distinct calendar points, or mark the change expand-only-by-design with a one-line reason.

R-DEPLOY-6. Migrations against populated tables follow the guardrail forms: add-nullable plus backfill plus CHECK NOT VALID plus validate plus SET NOT NULL instead of single-step NOT NULL; CREATE INDEX CONCURRENTLY; explicit lock_timeout and statement_timeout; backfills outside transactions; no rename of a column still read by running code; destructive DDL only with a restore point and a one-cycle read gap.
Criterion: IF a planned migration touches a populated table THE PLAN SHALL specify the guardrail form for it and SHALL NOT contain any step that takes an ACCESS EXCLUSIVE lock on that table.

R-DEPLOY-7. The plan names the full promotion ladder and the parity gap at every rung: traffic source, data source, scale, feature-flag defaults, observability reach.
Criterion: WHEN the plan names environments THE PLAN SHALL list each rung with its five parity properties; a compact ladder is allowed, a silent parity gap is not.

R-DEPLOY-8. The pipeline is planned as eight named gates in order: build, test, security scan on the artifact, promote-to-non-prod, promote-to-staging, approval, promote-to-prod, post-deploy verification.
Criterion: WHEN the plan defines the pipeline THE PLAN SHALL name all eight gates in that order and SHALL NOT plan a single job that builds, tests, and deploys on push to main.

R-DEPLOY-9. The approval gate is enforced by mechanism, not convention: an environment protection rule, or for a solo builder a distinct second action (signed tag, deploy command, deploy-marker commit).
Criterion: WHEN the approval gate is planned THE PLAN SHALL name the enforcing mechanism, and auto-deploy-on-push to production SHALL NOT appear anywhere in the plan.

R-DEPLOY-10. The secrets path is planned upfront: runtime-only injection; zero secrets in image layers, git history, or workflow literals; no pull_request_target checkout of untrusted fork code with secret access; least-privileged runtime identity distinct from the deploy identity.
Criterion: WHEN the plan covers deploy credentials THE PLAN SHALL specify all four properties and SHALL NOT rely on a personal access token on an individual account.

R-DEPLOY-11. Rollout strategy is chosen per change (all-at-once, rolling, blue-green, canary, ring). A canary requires all four fields: named success metric, numeric threshold, time-or-request-bounded window, automated rollback trigger. No change reaches 100 percent of traffic in one uniform step untested in that environment.
Criterion: WHEN a rollout is planned THE PLAN SHALL name the strategy per change; IF the strategy is canary THE PLAN SHALL state all four fields or refuse the canary and record all-at-once with a named blast-radius justification instead.

R-DEPLOY-12. The first deploy to any environment carries the cold-start checklist as hard blocks: environment reachable, DNS propagated, TLS provisioned with more than 30 days validity, database provisioned with migrations through expand, env vars set in the platform, IAM role existing and least-privileged, image in the registry with valid pull credentials, truthful healthcheck, log aggregation reaching the environment, rollback dry-run completed in non-prod.
Criterion: WHEN a deploy is the first to its environment THE PLAN SHALL include the ten-gate checklist as a blocking task and SHALL label every deploy task as first or subsequent.

R-DEPLOY-13. The readiness probe is truthful: it returns healthy only when the service can serve a real request, exercising at least one critical dependency, never on socket bind.
Criterion: WHEN health checking is planned THE PLAN SHALL require the probe to fail while a critical dependency is down and SHALL NOT accept a 200-on-bind probe.

R-DEPLOY-14. Feature-flag lineage is audited: no flag name is reused from a prior deploy until the old code path behind it is confirmed removed. The flag mechanism, its fallback, owners and expiry, and runtime kill switches are R-BIZ-23's when business is applicable; this requirement owns name reuse.
Criterion: IF the plan introduces or reuses feature flags THE PLAN SHALL include a lineage-audit step before any name reuse.

R-DEPLOY-15. Every production deploy is followed by planned verification: healthcheck healthy, p99 latency and error rate within the canary threshold for at least 15 minutes, critical-path smoke run, and the contract phase scheduled if an expand shipped.
Criterion: WHEN a production deploy task is planned THE PLAN SHALL schedule a post-deploy verification task naming those four checks.

R-DEPLOY-16. Rollback is rehearsed and incidents are logged: the revert command runs against a non-prod copy within 90 days of first deploy, and every rollback or close call writes an incident file regardless of blast radius.
Criterion: WHEN rollback paths exist THE PLAN SHALL schedule the dry-run cadence and name the incident-log location and template.

R-DEPLOY-17. The plan emits deploy handoff artifacts: a topology doc (consumed by observability planning for what to monitor and by launch planning for public URLs), a healthcheck inventory, a per-service rollback doc, and a migration calendar tracking in-progress expand/contract cycles so a resuming session neither ships a contract phase early nor forgets it.
Criterion: WHEN the deployment section is complete THE PLAN SHALL contain tasks producing all four artifacts with exact file paths.

R-DEPLOY-18. Destructive deploy-time commands (terraform destroy, kubectl delete, prisma migrate reset, rm -rf) never run against production without explicit confirmation and a named, verified backup.
Criterion: IF any planned task runs a destructive command against a production resource THE PLAN SHALL gate it behind a confirmation step and a named restore point.

## Task seeds

- [ ] GP-xxx Define the deploy pipeline with eight named gates
  - Files: .github/workflows/deploy.yml, docs/deploy/pipeline.md
  - Acceptance: exactly one build job produces a content-hashed artifact; promote jobs contain no build step; approval mechanism documented; a post-deploy verification job exists
  - Verify: test "$(grep -c 'docker build\|run build' .github/workflows/deploy.yml)" -eq 1
  - Requirements: R-DEPLOY-1, R-DEPLOY-8, R-DEPLOY-9
- [ ] GP-xxx Write the promotion ladder and parity map
  - Files: docs/deploy/topology.md
  - Acceptance: every rung listed with traffic source, data source, scale, flag defaults, and observability reach; parity gap stated per rung; public URLs listed for launch handoff
  - Verify: grep -c "parity" docs/deploy/topology.md
  - Requirements: R-DEPLOY-7, R-DEPLOY-17
- [ ] GP-xxx Ship the expand phase migration for the target table
  - Files: migrations/NNN_expand_table.sql
  - Acceptance: additive-only DDL (nullable column, CHECK NOT VALID); lock_timeout and statement_timeout set; no single-step NOT NULL, no non-CONCURRENT index, no backfill in transaction
  - Verify: grep -q "lock_timeout" migrations/NNN_expand_table.sql && ! grep -qiE "(alter column|add column)[^;]*not null|set not null" migrations/NNN_expand_table.sql
  - Requirements: R-DEPLOY-5, R-DEPLOY-6
- [ ] GP-xxx Schedule the cutover and contract deploys on the migration calendar
  - Files: docs/deploy/migration-calendar.md
  - Acceptance: cutover and contract are separate calendar entries in later waves than expand; the rollback target between phases is named; expand-only entries carry a one-line reason
  - Verify: grep -c "contract" docs/deploy/migration-calendar.md
  - Requirements: R-DEPLOY-5, R-DEPLOY-17
- [ ] GP-xxx Implement the truthful readiness probe
  - Files: src/health/readiness.ext
  - Acceptance: probe checks database connectivity and one critical dependency before returning healthy; returns 503 during warmup; no bare 200-on-bind path exists
  - Verify: Manual: stop the database, then run `curl -sf localhost:PORT/ready`; expect nonzero exit
  - Requirements: R-DEPLOY-13, R-DEPLOY-15
- [ ] GP-xxx Execute the first-deploy cold-start checklist for the target environment
  - Files: docs/deploy/cold-start-env.md
  - Acceptance: all ten Mode-A gates checked with evidence lines (dig output, cert expiry date, IAM role name, registry pull test, observed log line, rollback dry-run timestamp)
  - Verify: test "$(grep -c '^- \[x\]' docs/deploy/cold-start-env.md)" -eq 10
  - Requirements: R-DEPLOY-12, R-DEPLOY-16
- [ ] GP-xxx Write and rehearse the rollback doc per service
  - Files: docs/deploy/rollback.md
  - Acceptance: exact revert command per service; time-to-revert measured against a non-prod copy; compensating-forward plan present for every data-forward change; incident-log template linked
  - Verify: grep -c "time-to-revert" docs/deploy/rollback.md
  - Requirements: R-DEPLOY-4, R-DEPLOY-16

## Self-audit rubric

- Artifact and promotion integrity (20): single hermetic build named, content hash verified at the final promote, no per-environment rebuild anywhere in the plan, runtime-only config injection stated.
- Rollback truth per change class (20): every shipped change classified into one of the four classes, class-matched rollback artifact attached, no "redeploy previous image" adjacent to a schema migration, side effects acknowledged as non-recallable.
- Migration calendar and guardrails (20): every data-forward change decomposed into expand/contract phases as separate deploys, guardrail forms specified per migration, the calendar itself planned as an artifact with in-progress cycles tracked.
- Rollout rigor (15): strategy named per change, every canary carries all four fields or is correctly refused, no untested uniform 0-to-100 step.
- Pipeline gates and secrets (15): eight gates named in order, approval enforced by mechanism, secrets path clean on all four properties, runtime identity split from deploy identity.
- First-deploy and post-deploy discipline (10): cold-start checklist planned as hard blocks with first-vs-subsequent labeling, truthful probe required, post-deploy verification scheduled, rollback rehearsal cadence and incident log named.

## Anti-patterns refused

- Paper canary: a canary with no metric, threshold, window, or automated trigger; "we will watch Grafana for a bit". Refusal: delete the canary claim; plan all-at-once with a named blast radius, or budget the metric path in the observability section first.
- Rollback theater: "rollback: redeploy previous image" written next to a schema migration. Refusal: replace with a compensating-forward plan plus a pre-migration restore point.
- Per-environment rebuild: the pipeline builds a fresh artifact for each environment. Refusal: plan one build plus promotes, or record the source and config pin as artifact identity.
- Slack-ping approval: the prod gate is a convention, not a mechanism. Refusal: plan an environment protection rule or a solo-builder distinct second action.
- Baked secrets: secrets in image layers, git history, workflow literals, or exposed to untrusted forks via pull_request_target. Refusal: plan runtime injection and the deploy-vs-runtime identity split.
- Table-locking migration: ALTER COLUMN type change, single-step NOT NULL, or non-CONCURRENT index on a populated table. Refusal: decompose into the guardrail form before the task is written.
- Expand-only trap: expand ships and contract is never scheduled. Refusal: the contract entry lands on the migration calendar in the same planning pass, or the change is marked expand-only-by-design with a reason.
- Flag necromancy: a reused flag name wakes dormant code (the Knight Capital shape). Refusal: a lineage-audit task precedes any flag name reuse.
- 200-on-bind probe: the healthcheck passes the moment the socket opens. Refusal: the probe must exercise a real dependency before reporting healthy.
- Assumed cold start: a first deploy that assumes DNS, TLS, IAM, env vars, and registry access exist. Refusal: the ten-gate Mode-A checklist is a blocking task, never skipped because "it is just like the other env".
- Uniform 0-to-100: an untested change reaches all traffic in one step (the CrowdStrike shape). Refusal: require a prior-rung exercise or a named blast-radius justification.
- Untested rollback: a revert path that has never been run. Refusal: schedule the non-prod dry-run within 90 days of first deploy.
- Destructive deploy command: terraform destroy or migrate reset pointed at prod without a backup. Refusal: gate behind explicit confirmation and a named, verified restore point.
