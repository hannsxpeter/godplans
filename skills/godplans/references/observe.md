# Observability planning module

Plans the observability sections of PLAN.mdx so the shipped system is monitorable by promise, not by chart count. The orchestrator loads this module for any archetype that runs a deployed service with users depending on it (saas-dashboard, api-service, ml-pipeline, mobile-app backend, cli with a hosted component). Excluded for pure libraries and static marketing sites without uptime promises; the exclusion reason goes in the applicability matrix.

## Lineage

Descends from observe-ready, the shipping-tier skill that keeps a deployed app healthy once real users are on it. Its core discipline carries over intact: every charted, alerted, or SLO-ed number is bound to a promise or it is demoted; alerts derive from SLO burn rate, not resource thresholds; every page links a runbook that has actually been executed; and the whole observability surface must survive the incident it describes (the Slack Jan 2021, Roblox 73-hour, Datadog Mar 2023, Facebook 2021 circular-dependency pattern). godplans inverts these end-of-project audit checks into plan-time requirements: the plan names the journeys, SLOs, policies, and independence rows before a single metric is emitted.

## Decisions to force

Ordered hardest to reverse first.

1. Metrics backend pricing model and cardinality strategy. Question: per-time-series priced backend (Prometheus-style, Datadog custom metrics) or wide-event backend (Honeycomb-style, ClickHouse)? Hard to reverse because label choices ossify into every dashboard, alert query, and instrumentation call; a high-cardinality label (user_id, tenant_id) on a per-series backend produces a cost blowup that gets the pipeline disabled. Options: per-series backend with an explicit label exclusion list; wide-event backend accepting high cardinality; hybrid (metrics low-cardinality, events wide). Default: per-series backend plus a written cardinality budget listing which dimensions are excluded and where they live instead.

2. Structured log schema and PII scrub point. Question: what is the one JSON log format, and is PII scrubbed at the collector or in each app? Hard to reverse because every service emits the schema and every saved query, alert, and runbook depends on field names; logs already written with PII cannot be retro-scrubbed. Options: app-level scrubbing per service; collector-level scrubbing (one chokepoint). Default: one JSON format with trace_id, service, level, timestamp, event as mandatory fields, PII scrubbed at the collector (GDPR-shaped default), retention aligned to purpose.

3. Trace propagation and sampling strategy. Question: how does trace context cross every boundary in the dependency graph (sync HTTP, gRPC, async queues, serverless cold starts, fan-out), and is sampling head-based or tail-based? Hard to reverse because retrofitting propagation through async boundaries touches every producer and consumer, and trace data not kept at the time is gone forever. Options: OTel with head sampling; OTel with tail-based or error-biased sampling. Default: OTel context propagation across all boundary types named in the dependency graph, tail-based or error-biased sampling for any service backing a production SLO (head 1% is refused for those), trace retention at least as long as the SLO window.

4. User journeys and SLO targets. Question: which named user journeys get promises, and what number does each promise? Hard to reverse because SLOs become external commitments and the entire alert tree derives from them; changing a target invalidates burn-rate math, budgets, and policies downstream. Options are the target tiers themselves (99.0, 99.5, 99.9), each validated against the dependency-chain ceiling: the product of upstream availabilities caps the downstream promise. Default: one SLI, one SLO number, one window, one computed error budget per journey, with feasibility math shown in the plan.

5. Out-of-band hosting for the observability surface. Question: where do dashboards, alert routing, runbooks, status page, trace store, and on-call schedule live relative to the observed system? Hard to reverse because infrastructure sharing (same cluster, same SSO, same region, same Slack workspace tied to the app's identity provider) is baked in at provisioning time and only discovered during the outage. Options: fully separate provider; separate account and region of the same provider; documented exceptions with remediation. Default: each of the six surface rows reachable when the observed service is down, recorded in an independence table.

## Plan requirements

R-OBS-1: PLAN.mdx must enumerate every service with its topology type (request-response, worker, batch, edge, scheduled, pipeline), the dependency graph between them, and the named user journeys, before any dashboard, alert, or SLO content.
Criterion: WHEN the observability section is emitted THE PLAN SHALL contain a service table with topology types, a dependency graph (mermaid), and a named user-journey list that all later SLO content references by name.

R-OBS-2: PLAN.mdx must classify every planned metric into exactly one of three lanes: SLI with a documented SLO, supporting diagnostic explicitly marked non-alerting, or removed. No unclassified metric may appear in any dashboard or alert task.
Criterion: IF a metric appears in a planned chart or alert THE PLAN SHALL show its lane, and WHEN the lane is diagnostic THE PLAN SHALL mark it non-alerting.

R-OBS-3: PLAN.mdx must define, for every named user journey, exactly one SLI with its measurement query shape, one SLO number, one window, and one computed error budget.
Criterion: WHEN a user journey is named THE PLAN SHALL contain a row with SLI, SLO target, window, and computed budget; IF any of the four is missing THE PLAN SHALL NOT mark the journey as promised.

R-OBS-4: PLAN.mdx must attach a written error-budget policy to every SLO, naming the trigger, the action, the stakeholder, and the exit criterion. An SLO without a policy is a paper SLO and the plan refuses to emit it.
Criterion: WHEN an SLO is stated THE PLAN SHALL include a policy with all four named fields; IF the policy is absent THE PLAN SHALL list the SLO on the paper-SLO watchlist instead of the promised table.

R-OBS-5: PLAN.mdx must show dependency-chain feasibility math for every SLO: the product of upstream availabilities is the ceiling, and no journey may promise above it.
Criterion: WHEN an SLO target is set THE PLAN SHALL state the upstream availability product and SHALL NOT set a target exceeding that ceiling without a named mitigation (redundancy, degradation path).

R-OBS-6: PLAN.mdx must declare the low-traffic exception for any journey with fewer requests than 10x the error budget per window: extended windows, synthetic traffic, or aggregation, chosen and stated.
Criterion: IF a journey's traffic is below 10x its error budget per window THE PLAN SHALL name which of the three low-traffic strategies applies.

R-OBS-7: PLAN.mdx must derive all pages from SLI burn rate using multi-window multi-burn-rate tiers (fast, medium, slow, drift). Cause-based signals (CPU, memory, disk, raw error count) are planned as diagnostics only and never page.
Criterion: WHEN an alert is planned at PAGE severity THE PLAN SHALL bind it to an SLI burn rate with at least two windows; IF an alert condition is cause-based THE PLAN SHALL route it to TICKET or LOG-ONLY.

R-OBS-8: PLAN.mdx must define the three-tier severity ladder (PAGE, TICKET, LOG-ONLY) and require every PAGE to carry a specific runbook URL (not a directory) and a named owner.
Criterion: WHEN a PAGE-tier alert is planned THE PLAN SHALL list its runbook URL and owner in the same table row; IF either is missing THE PLAN SHALL demote the alert to TICKET.

R-OBS-9: PLAN.mdx must plan deadman switches for every silent or heartbeat path (scheduled jobs, queue consumers, pipelines) and route alerts out-of-band so paging does not depend on the paged service.
Criterion: WHEN a service has topology type worker, batch, scheduled, or pipeline THE PLAN SHALL include a deadman switch task, and WHEN alert routing is planned THE PLAN SHALL name a delivery path independent of the observed system.

R-OBS-10: PLAN.mdx must plan one JSON log format across all services with trace_id, service, level, timestamp, and event fields, correlation-ID propagation across every call type in the dependency graph, PII scrubbing at the collector, and retention aligned to a stated purpose.
Criterion: WHEN logging tasks are emitted THE PLAN SHALL name the shared schema fields, the scrub point, and the retention period per log class; IF any call type in the graph lacks a propagation mechanism THE PLAN SHALL flag it as an open gap task.

R-OBS-11: PLAN.mdx must plan OTel trace propagation across every boundary type present in the dependency graph, including async queues and serverless cold starts, with tail-based or error-biased sampling for SLO-backed services and trace retention covering the SLO window. Span names are planned low-cardinality with no PII.
Criterion: WHEN a service backs a production SLO THE PLAN SHALL specify tail-based or error-biased sampling and SHALL NOT specify head-only 1% sampling; WHEN retention is stated THE PLAN SHALL set it at or above the longest SLO window.

R-OBS-12: PLAN.mdx must plan error tracking per service with release tagging tied to the deploy identifier, a PII scrubber, and a quarterly grouping-tuning pass on the top-20 signatures, so "did this error start with vX.Y.Z" is answerable.
Criterion: WHEN error-tracking setup is planned THE PLAN SHALL include a release-tag wiring task referencing the deploy release id and a recurring grouping-tuning entry.

R-OBS-13: PLAN.mdx must state a cardinality budget: which high-cardinality dimensions (user_id, request_id, tenant_id) are excluded from the metrics backend or moved to a wide-event store, matched to the backend's pricing model.
Criterion: IF the chosen metrics backend prices per time series THE PLAN SHALL list excluded high-cardinality labels and where each dimension lives instead.

R-OBS-14: PLAN.mdx must plan the primary dashboard so its first screen answers "is this service meeting its SLOs": at most 7 charts above the fold, the first chart is the burn-rate gauge, every chart bound to an SLO, SLI, or named diagnostic, golden signals (latency p50/p95/p99, traffic, errors, saturation) per journey are the only metrics above the fold.
Criterion: WHEN a dashboard is planned THE PLAN SHALL enumerate its above-the-fold charts with their bindings, SHALL cap them at 7, and SHALL place the burn-rate gauge first.

R-OBS-15: PLAN.mdx must attach owner and last_reviewed metadata to every planned dashboard and alert, and cap dashboards at 3 per service. Unowned artifacts are pruned from the plan, not muted.
Criterion: WHEN dashboards or alerts are planned THE PLAN SHALL list owner and review metadata per artifact and SHALL NOT plan more than 3 dashboards for one service without a stated reason.

R-OBS-16: PLAN.mdx must plan the observability-surface independence test as a first-class deliverable: a 6-row table (dashboards, alert routing, runbooks, status page, trace store, on-call schedule), each row reachable when the observed service is down, with remediation tasks or a justified exception for any failing row.
Criterion: WHEN the observability phase is emitted THE PLAN SHALL contain the 6-row independence table and one task per failing row.

R-OBS-17: PLAN.mdx must plan one executable runbook per PAGE (real commands with exact flags, not "check the logs"), hosted out-of-band, linked from the alert, with a last_executed field kept within 90 days via a quarterly tabletop cadence on the calendar.
Criterion: WHEN a runbook task is planned THE PLAN SHALL require executable commands and an out-of-band host in its acceptance criteria, and THE PLAN SHALL schedule a recurring tabletop task.

R-OBS-18: PLAN.mdx must plan the incident-response loop: a SEV-1/2/3 ladder with response expectations, a named incident-commander rotation, a status-page update cadence, and templated customer comms.
Criterion: WHEN the incident section is emitted THE PLAN SHALL define all four elements; IF the team is a solo builder THE PLAN SHALL still name the single responder and the status-page cadence.

R-OBS-19: PLAN.mdx must plan the learning loop: a blameless post-mortem template, a rule that every post-mortem emits at least one observability-gap action item with a sprint-bounded due date, and a quarterly alert-pruning cadence covering dead alerts, never-fired alerts, and alerts dismissed more than 3 times without action.
Criterion: WHEN post-mortem process is planned THE PLAN SHALL bind action items to sprint-bounded due dates and SHALL schedule the pruning cadence as a recurring task.

R-OBS-20: PLAN.mdx must scope observability at the bright line against product analytics: "are signups failing more than the SLO allows" is in scope, "did signup conversion go up" is not, and must carry the paper-SLO watchlist forward so any SLO missing its policy or measurement query stays visible until fixed.
Criterion: IF a planned metric measures business conversion rather than promise compliance THE PLAN SHALL exclude it from the observability section, and WHEN any SLO lacks a policy or query THE PLAN SHALL list it on the paper-SLO watchlist in the Open Questions section.

R-OBS-21: PLAN.mdx must separate `installation-ready` from `operationally-mature`. Installation requires telemetry, SLOs, policies, dashboards, routes, and runbooks plus one controlled production-equivalent signal labeled synthetic. Operational maturity requires evidence from a real recent service event and tuning outcome, or remains `not-yet-evidenced`. A controlled fire is never rewritten as real incident history.
Criterion: WHEN observability completion evidence is planned THE PLAN SHALL record the two states independently, SHALL allow a synthetic controlled fire to prove installation only, and SHALL require real-event evidence before claiming operational maturity.

R-OBS-22: PLAN.mdx never invents an operational number. Availability targets, latency objectives, error budgets, recovery time and recovery point objectives, retention periods, and support windows are commitments a human owns, and none of them is derivable from a plan. Each is taken from a source the plan cites (an existing contract, a stated user answer, a measured baseline with its measurement named), or it goes to `## Open Questions` with an owner, a decide-by moment, and a recommended default that the plan executes on. A number the plan chooses on the user's behalf is legitimate only as a `### D<n>` decision whose falsifier boundary is that same number, so the commitment is visible and falsifiable rather than assumed.
Criterion: WHEN an SLO, error budget, recovery objective, retention period, or support window appears, THE PLAN SHALL attach a cited source, a user answer, or a Decisions entry with a falsifier; ELSE THE PLAN SHALL move it to Open Questions with an owner, a decide-by moment, and a recommended default, and SHALL NOT state it as a settled target.

## Task seeds

- [ ] GP-xxx Define user journeys, service topology, and SLO table
  - Files: observability/SLOS.md, docs/topology.md
  - Acceptance: every journey row has SLI query, target, window, computed budget; service table lists topology type per service; dependency graph present as a mermaid fence
  - Verify: grep -q '| SLI' observability/SLOS.md && grep -q 'graph TD' docs/topology.md
  - Requirements: R-OBS-1, R-OBS-3, R-OBS-5

- [ ] GP-xxx Write error-budget policies per SLO
  - Files: observability/SLOS.md
  - Acceptance: each SLO section contains Trigger, Action, Stakeholder, Exit lines; no SLO row without a policy block
  - Verify: test $(grep -c '^Trigger:' observability/SLOS.md) -eq $(grep -c '| SLO' observability/SLOS.md)
  - Requirements: R-OBS-4, R-OBS-20

- [ ] GP-xxx Implement structured logging baseline
  - Files: src/lib/logger.ts, infra/collector/pipeline.yaml
  - Acceptance: logger emits JSON with trace_id, service, level, timestamp, event; collector config contains a PII scrub processor; retention period stated per log class
  - Verify: grep -q 'trace_id' src/lib/logger.ts && grep -q 'scrub' infra/collector/pipeline.yaml
  - Requirements: R-OBS-10

- [ ] GP-xxx Wire burn-rate alert rules with runbook links
  - Files: infra/alerts/burn-rates.yaml, observability/ALERTS.md
  - Acceptance: every PAGE rule references an SLI burn rate with at least two windows; every PAGE rule carries runbook_url and owner; cause-based rules routed to TICKET or LOG-ONLY only
  - Verify: test $(grep -c 'runbook_url' infra/alerts/burn-rates.yaml) -ge $(grep -c 'severity: page' infra/alerts/burn-rates.yaml)
  - Requirements: R-OBS-7, R-OBS-8, R-OBS-9

- [ ] GP-xxx Build the primary SLO dashboard spec
  - Files: observability/DASHBOARDS.md, infra/dashboards/primary.json
  - Acceptance: at most 7 above-the-fold charts each bound to an SLO, SLI, or named diagnostic; first chart is the burn-rate gauge; owner and last_reviewed present per dashboard
  - Verify: test $(grep -c 'above_fold: true' observability/DASHBOARDS.md) -le 7 && grep -q 'owner:' observability/DASHBOARDS.md
  - Requirements: R-OBS-2, R-OBS-14, R-OBS-15

- [ ] GP-xxx Run the observability-surface independence test
  - Files: observability/INDEPENDENCE.md
  - Acceptance: 6 rows (dashboards, alert routing, runbooks, status page, trace store, on-call schedule) each marked reachable-when-down or linked to a remediation task or justified exception
  - Verify: test $(grep -cE '^\| (dashboards|alert routing|runbooks|status page|trace store|on-call)' observability/INDEPENDENCE.md) -eq 6
  - Requirements: R-OBS-16

- [ ] GP-xxx Author executable runbooks and schedule tabletops
  - Files: runbooks/<alert-slug>.md, observability/RUNBOOKS.md
  - Acceptance: one runbook per PAGE alert; each contains fenced command blocks with exact flags; each carries last_executed; quarterly tabletop entry on the calendar file
  - Verify: test "$(grep -rL 'last_executed:' runbooks/ | wc -l)" -eq 0
  - Requirements: R-OBS-17

- [ ] GP-xxx Establish incident response and learning loop
  - Files: observability/INCIDENTS.md, observability/templates/post-mortem.md
  - Acceptance: SEV-1/2/3 ladder with response expectations; incident-commander rotation named; post-mortem template contains an observability-gap action-item section with a due-date field; quarterly alert-pruning cadence listed
  - Verify: grep -q 'SEV-1' observability/INCIDENTS.md && grep -q 'due_date' observability/templates/post-mortem.md
  - Requirements: R-OBS-18, R-OBS-19

- [ ] GP-xxx Prove installation readiness without fabricating maturity
  - Files: observability/STATE.md, observability/CONTROLLED-FIRE.md
  - Acceptance: STATE.md records installation-ready with a controlled production-equivalent signal labeled synthetic; operational maturity is not-yet-evidenced unless a real recent service event and tuning result are cited; controlled-fire evidence is never listed as incident history
  - Verify: grep -q '^installation_status: installation-ready$' observability/STATE.md && grep -q '^signal_type: synthetic$' observability/CONTROLLED-FIRE.md && ! grep -q 'operational_maturity: operationally-mature' observability/STATE.md
  - Requirements: R-OBS-17, R-OBS-21

## Self-audit rubric

Derived from observe-ready's 4-tier model (Instrumented, Promised, Traceable, Rehearsed) with its have-nots list applied as deductions. 100 points total.

- Promise binding and SLO design (25): full marks when every journey is named with one SLI, one SLO, one window, one computed budget, a four-field error-budget policy, dependency-chain feasibility math, and the low-traffic exception declared where it applies; every planned metric sits in one of the three lanes; and every operational number carries a cited source, a user answer, a falsifiable Decisions entry, or an Open Questions ticket with a recommended default. An invented target caps this dimension at half regardless of the rest.
- Alert derivation and severity (20): full marks when all PAGE alerts are multi-window burn-rate on SLIs, the three-tier ladder is defined, every PAGE has a runbook URL and owner, deadman switches cover silent paths, routing is out-of-band, and a prune cadence exists.
- Logging, tracing, and error tracking (20): full marks when one JSON schema with the five mandatory fields spans all services, correlation IDs propagate across every call type in the graph, PII is scrubbed at the collector, SLO services get tail-based or error-biased sampling with retention covering the SLO window, and error tracking carries release tags.
- Dashboard discipline and independence (15): full marks when the primary dashboard has at most 7 bound charts led by the burn-rate gauge, every artifact carries owner and last_reviewed, the 3-dashboard cap holds, and the 6-row independence table is complete with remediations.
- Runbook and incident loop (15): full marks when every PAGE has an executable out-of-band runbook, controlled production-equivalent evidence proves installation and stays labeled synthetic, operational maturity is backed only by real-event tuning evidence, and the post-mortem loop is scheduled.
- Cost and cardinality (5): full marks when the cardinality budget names excluded labels matched to the backend pricing model and states retention and sampling costs.

Any gate hit (paper SLO, blind dashboard chart, PAGE without runbook, single-window burn alert, in-band surface row without remediation) caps the domain score at 84 regardless of points, forcing revision.

## Anti-patterns refused

- Paper SLO: an SLO with no error-budget policy or no measurement query. The planner moves it to the paper-SLO watchlist and refuses to count the journey as promised.
- Blind dashboard: 40 charts and a dozen alerts with no statement of which is the SLO for which journey. The planner refuses the dump and plans only lane-classified metrics.
- Paper runbook: no last_executed within 90 days, or prose like "check the logs" instead of commands. The planner requires executable blocks and schedules the tabletop that keeps the date fresh.
- Cause-based paging: CPU over 80 percent or error count over zero wired to the pager. The planner routes cause signals to diagnostics and pages only on burn rate.
- Single-window burn alert: one window, one threshold. The planner emits multi-window multi-burn-rate tiers or nothing.
- Circular observability surface: dashboards, routing, or runbooks hosted on the system they observe (the Slack, Roblox, Datadog, Facebook pattern). The planner fails the independence row and emits a remediation task.
- Sprawl at birth: an "add monitoring" pass emitting 20+ monitors or 5+ dashboards with no ownership, SLO mapping, or pruning policy. The planner caps dashboards at 3 per service and requires owner metadata before any artifact enters the plan.
- Alert fatigue: an alert dismissed more than 3 times without tuning, or never-fired alerts kept alive. The planner schedules the quarterly prune and the post-incident tuning pass.
- Head-only 1% sampling on an SLO service: cheap sampling that misses the errors the SLO cares about. The planner specifies tail-based or error-biased sampling for any SLO-backed service.
- Orphan artifacts: dashboards or alerts with no owner or last_reviewed. The planner prunes them from the plan rather than muting them.
- PII in logs: user.email, phone, authorization headers, card data, or full request bodies emitted without the scrubber. The planner places the scrub at the collector and lists banned fields.
- Cardinality blowup: user_id or request_id as a metric label on a per-series priced backend. The planner requires the exclusion rule or a wide-event store before the label is planned.
- Untagged errors: error-tracking config with no release tag, making "did vX.Y.Z cause this" unanswerable. The planner wires release tagging to the deploy identifier.
- Silent heartbeat: a scheduled job or queue consumer with no deadman switch, failing silently. The planner adds a deadman task for every worker, batch, scheduled, or pipeline service.
- Analytics scope creep: conversion and engagement metrics smuggled into the observability section. The planner applies the bright line and moves them out; only promise compliance stays.
- Synthetic incident laundering: a controlled fire is presented as real incident history or operational maturity. The planner labels it synthetic, uses it only for installation-ready evidence, and leaves maturity not-yet-evidenced until a real event produces tuning evidence.
- Invented target: "99.9 percent availability" or "RTO 4 hours" written because the section needed a number. The planner cites the source, records it as a falsifiable decision, or opens a question with a recommended default; an invented threshold gets quoted back later as though somebody had committed to it.
