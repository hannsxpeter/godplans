# Discovery module: intake, archetype, applicability, interview

Loaded in Phase 2 and Phase 3. Turns a raw idea (or an existing codebase) into the facts the domain passes need: mode, archetype, scale, the applicability matrix, and the small set of answers only the user can give. Discovery is where godplans earns the single-command promise: one focused question batch, then decisions.

## Mode detection (Phase 0 recap)

- `.godplans/PLAN.mdx` exists -> replan. Follow the replan protocol in `plan-format.md`.
- Source manifests exist (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`, `mix.exs`, `Package.swift`) -> brownfield.
- Otherwise -> greenfield.

Brownfield fingerprint, read-only, before any planning: stack and versions from manifests; directory shape and module boundaries; entry points; test and CI setup; the style genome sample (naming, file organization, error-handling idiom, comment density) from 5 to 10 representative source files; anything under `agents/`, `AGENTS.md`, `CLAUDE.md`, or `.cursor/rules/` that records existing conventions. Record the current Git revision when available, a SHA-256 digest of the stable intake and source evidence, and a UTC validation timestamp. The plan extends what exists; a brownfield plan that reads like a greenfield plan has failed before it ships.

## Product-form routing

Pick product form before archetype and domain composition. Product form describes how a user operates and receives the software. It defines the vertical-slice shape, the build concerns, and the completion evidence. Do not default to web application because the request says product, platform, tool, or dashboard.

Every form ships a user-operable increment. Real-backend discipline applies when the product has a backend; it does not invent one for a local CLI, embedded SDK, offline desktop utility, notebook workflow, or declarative module.

| Product form | A vertical slice means | Build concerns | Completion evidence |
|---|---|---|---|
| web-application | persistence or external source -> service and permission boundary -> API or server action -> UI states -> tests | route and information architecture, loading/empty/error/success states, server-side authorization, accessibility, responsive behavior, user-journey telemetry | one roadmap job works from user action through real data and back; relevant UI states and permission checks exist; unit, integration, and browser tests pass |
| api-or-service | contract -> validation and authorization -> domain operation -> persistence or dependency -> telemetry -> tests | versioned contracts, idempotency, timeouts, retry budgets, dependency failures, migrations, health, consumer compatibility | a real consumer fixture completes one contract path; errors, bounded retries, health, telemetry, contract tests, and integration tests pass |
| cli-or-sdk | public command or API -> parsing and validation -> domain operation -> output or return contract -> consumer fixture -> cross-platform tests | stable public surface, exit codes or error types, configuration precedence, deterministic output, examples, compatibility, semantic versioning, distribution | a clean consumer installs the artifact, completes the primary job without repository internals, receives documented errors, executes examples, passes supported-platform checks, and reproduces the release artifact |
| mobile-or-desktop | native interaction -> local state -> sync or service boundary -> offline and recovery states -> device or platform tests | lifecycle behavior, local persistence, sync conflicts, offline states, permissions, secure storage, accessibility, crash reporting, signing, updates | a development or signed build runs on each platform class; the primary job survives lifecycle and connectivity transitions; secure storage, device tests, crash telemetry, and packaging pass |
| data-or-ml | versioned input -> validated transform or training step -> reproducible output -> quality evaluation -> lineage and operations | provenance, schemas, data quality, reproducible environments, experiment tracking, leakage and bias checks, registries, drift, cost | a clean environment reproduces an artifact from versioned inputs; quality thresholds pass; code, data, and config lineage is recorded; serving tests pass when serving is in scope |
| infrastructure-or-iac | versioned config -> static validation -> plan -> policy check -> isolated apply or simulation -> rollback or destroy proof | state, secrets, pinned tools and providers, policy as code, environment separation, least privilege, drift, disaster recovery, cost | formatting and validation pass; an isolated plan and policy check pass; sandbox apply or faithful simulation proves the main path; state, secrets, destructive guards, and rollback are verified |

Pick one primary form and write its slug to frontmatter as `product_form`. A secondary form is not a label for a supporting component. Add one only when it has its own user, public contract, distribution path, deliverable, and completion evidence. Keep primary-form sequencing authoritative and add a separate secondary-form slice rather than blending both gates into a web-shaped checklist.

## Archetype detection

Pick the closest archetype; hybrids name a primary and a secondary. The archetype drives the applicability matrix defaults.

| Archetype | Signals | Typical exclusions |
|---|---|---|
| cli-tool | runs in a terminal, no server, distributed as a binary or package | seo, ui (terminal output is ux, not ui), launch (often), llm |
| library | consumed by other code; the API is the product | seo, ui, observe (consumer-side), launch (registry release instead) |
| api-service | HTTP or RPC surface, no first-party frontend | seo, ui |
| saas-dashboard | authenticated web app over domain data | none by default |
| marketing-site | public content, conversion goals, little state | database (often), llm (often) |
| mobile-app | app-store distribution, native or cross-platform | seo (store listing replaces it) |
| ml-pipeline | batch or streaming data and model flows | seo, ui (unless it has an ops console) |
| extension | lives inside a host (browser, editor, platform) | seo, deploy becomes store publishing |
| game | real-time loop, assets, scenes | seo (store listing), database varies |

Signals beat labels: a "CLI tool" with a companion web dashboard is a hybrid and gets both matrices merged, dashboard rules winning conflicts.

## Scale calibration

State it in the plan; every module's requirements scale with it.

- **weekend**: throwaway or personal utility. Plan depth: decisions and a short task list. Weekend plans have at most 3 phases and 8 tasks. Sum task appetites to the user's stated capacity, combine related implementation and documentation work, and keep only requirements that materially alter behavior, public compatibility, security, or verification. Security still applies (secrets, injection), compliance still applies, and observability collapses to local error reporting or logs.
- **side-project**: real users possible, one maintainer. Deploy, backups, and error tracking are planned; SOC 2 is not.
- **funded-product**: paying users, a team, uptime matters. The full applicable matrix, honest SLOs, launch plan.
- **enterprise**: compliance regimes, multiple teams, audits. Everything, plus the compliance mapping the security module demands.

Calibration is a ceiling-setter, not an excuse: a weekend project with user passwords still hashes them with argon2id. It is also a scope ceiling: rubric coverage cannot manufacture work that exceeds the declared capacity. Cheap corners are cut openly, in the plan, as named decisions ("no staging environment: acceptable for side-project scale, revisit at 100 users"), never silently.

## The applicability matrix

Every domain gets a row with one of three statuses. Applicable means the domain pass runs now and its requirements bind. Excluded requires a reason specific to this project; "not needed" is banned by the substitution test. Deferred means the domain's decisions are reversible until a named trigger fires, so the pass is postponed rather than skipped: the row names the trigger (an observable event, never "later") and argues why waiting is safe. When the trigger fires, the plan returns to `planning` and the deferred domain pass runs as a replan.

Deferral is a privilege of the reversible. Only these domains may defer, and only with the trigger landing before the work gets expensive to redo:

- **seo**: trigger before the first public crawlable page ships; retrofitting metadata, semantic HTML, and sitemaps onto shipped pages is the expensive version.
- **launch**: trigger before public-activation planning begins; the prepublication gate consumes launch requirements, so the launch pass must land before that gate is drafted.
- **observe**: baseline error reporting and one alert are planned now at any scale; full SLOs, error budgets, and runbooks may defer with the trigger at the first real user or the first paid workload.
- **ui**: the visual system (tokens, primitives) may defer with the trigger before the component library task; ux journeys are never deferred because they shape the architecture.
- **deploy**: libraries and CLI tools may defer with the trigger before the first distribution task; services with a completion-evidence gate deploy early and never defer.

Never deferrable: product, architecture, stack, database, security, llm (when applicable), ux (when applicable), code-quality, style-genome, agent-memory, repo, build, roadmap. These decide hard-to-reverse shape or feed every other pass; deferring them is plan theater with a calendar.

```markdown
## Applicability matrix

| Domain | Status | Reason |
|---|---|---|
| product | applicable | |
| architecture | applicable | |
| stack | applicable | |
| database | applicable | |
| security | applicable | security is never excluded or deferred, only scaled |
| llm | excluded | no model calls anywhere in the product |
| ux | applicable | |
| ui | applicable | |
| seo | deferred | trigger: the first public marketing page task enters the roadmap; reversible until pages ship without metadata |
| code-quality | applicable | never excluded or deferred, only scaled |
| style-genome | applicable | |
| agent-memory | applicable | |
| repo | applicable | |
| build | applicable | |
| roadmap | applicable | |
| deploy | applicable | |
| observe | applicable | |
| launch | excluded | internal tool; adoption is an email, not a launch |
```

Hard rules: security, code-quality, style-genome, repo, roadmap are never excluded and never deferred (they scale down instead). seo requires a public crawlable surface. llm requires actual model integration; "we might add AI later" is a roadmap entry, not an llm pass and not a deferral. ui requires rendered pixels the project owns.

## The interview

One batch, 3 to 5 questions, only questions that change the plan. Rules:

1. **Spend questions on hard-to-reverse bets.** Data-model shape, multi-tenancy, auth boundary, public API commitments, pricing model when it constrains architecture. Never spend a question on something a module can decide with a stated default (formatter choice, test runner).
2. **Every question ships a recommended default**, so "defaults" is a complete answer. Format: the question, why it matters (one line), options, the recommendation marked.
3. **Batch, do not drip.** One message with all questions. Follow-ups only when an answer creates a genuine fork.
4. **Everything not asked becomes a stated assumption**, flagged in the plan as a hypothesis with a validation plan. The assumptions ledger goes into the Decisions section, labeled.
5. **Brownfield asks less.** The codebase already answered most questions; asking the user something the code answers is a discovery failure.
6. **Non-interactive fallback.** When no user is available to answer (CI, autonomous runs), take every default, mark all of them as hypotheses, and say so at the top of the plan.

Question quality bar, by example. Bad: "What database do you want?" (module decides with a default). Good: "Is a workspace's data ever visible across workspaces (shared boards, cross-org reporting)? Recommendation: no, hard tenant isolation; this decides the schema and every query." Bad: "Do you want tests?" (never a question). Good: "Is the public API versioned from day one? Recommendation: yes, `/v1/` prefix; unversioned public APIs are the most expensive reversal in this archetype."

## Output of discovery

By the end of Phase 3 the following exist, ready for the domain passes:

- Mode, primary product form, any independently justified secondary form, archetype (with hybrid note), and scale calibration.
- Plan provenance: source revision or `none`, evidence inventory, SHA-256 input digest, and UTC validation timestamp.
- The applicability matrix, complete.
- The user's answers, verbatim where load-bearing.
- The assumptions ledger: every default taken, each flagged as a hypothesis.
- The hard-to-reverse bets list, each either answered or queued for the Decisions section. An empty list is a finding, not a silence: it means wire formats, public identifiers, data-model shape, and auth and ownership boundaries were each examined and located in this project, so say where each one landed. A list that is empty because nobody looked is the mind-reader anti-pattern with better manners.
- Brownfield only: the fingerprint summary (stack, structure, style genome extract, existing conventions files).

## Anti-patterns refused

- **The interrogation**: ten questions before any value. Refused: one batch, defaults offered, move.
- **The mind-reader**: zero questions, silent guesses on hard-to-reverse bets. Refused: bets get asked or get flagged as hypotheses, never silently assumed.
- **The generic matrix**: applicability copied from the archetype table without looking at the project. Refused: reasons must survive the substitution test.
- **Brownfield amnesia**: planning as if the codebase were empty. Refused: the fingerprint runs first and the plan cites real files.
- **Web-shaped everything**: API, CLI, mobile, data, or IaC work forced through UI and backend assumptions. Refused: product form is selected before archetype and every slice uses the form-specific gate.
- **Decorative secondary form**: a supporting component labeled secondary without its own user or deliverable. Refused: secondary forms require an independent contract, distribution path, and completion evidence.
- **Scale theater**: enterprise ceremony on a weekend project, or weekend sloppiness on a funded product. Refused: calibration is stated and modules scale to it.
- **Deferral theater**: deferring a load-bearing domain to avoid deciding it, or deferring with a trigger that can never be observed. Refused: only the named deferrable set may defer, the trigger is an observable event with a reversibility argument, and the never-excluded set never defers.
