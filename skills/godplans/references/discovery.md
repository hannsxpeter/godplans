# Discovery module: intake, archetype, applicability, interview

Loaded in Phase 2 and Phase 3. Turns a raw idea (or an existing codebase) into the facts the domain passes need: mode, archetype, scale, the applicability matrix, and the small set of answers only the user can give. Discovery is where godplans earns the single-command promise: one focused question batch, then decisions.

## Mode detection (Phase 0 recap)

- `.godplans/PLAN.mdx` exists -> replan. Follow the replan protocol in `plan-format.md`.
- Source manifests exist (`package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `Gemfile`, `pom.xml`, `mix.exs`, `Package.swift`) -> brownfield.
- Otherwise -> greenfield.

Brownfield fingerprint, read-only, before any planning: stack and versions from manifests; directory shape and module boundaries; entry points; test and CI setup; the style genome measured with `scripts/style-stats.py` and then close-read across 5 to 10 representative source files; anything under `agents/`, `AGENTS.md`, `CLAUDE.md`, or `.cursor/rules/` that records existing conventions. Record the current Git revision when available, a SHA-256 digest of the stable intake and source evidence, and a UTC validation timestamp. The plan extends what exists; a brownfield plan that reads like a greenfield plan has failed before it ships.

Record what the fingerprint did **not** reach as explicitly as what it found. A pass that was never run is not a pass that came back empty, and the applicability matrix below refuses to treat the two the same way.

### Reuse an existing inventory before re-deriving one

If `.godaudits/EVIDENCE.json` exists, read it before scanning. godaudits already inventories manifests, lockfiles, languages, file hashes, high-signal source locations, and, most useful here, **absence evidence**: the things it looked for and did not find, with what it searched. That is the expensive half of a brownfield fingerprint and the half an agent is worst at doing honestly from memory.

- **Fresh** means its recorded revision matches the revision this plan is binding to. A fresh inventory is cited: add it to the provenance evidence inventory as a `[recheck]` entry so a later phase-boundary drift check recomputes it.
- **Stale or absent** means the fingerprint runs normally, and the plan says which of the two happened. Reusing a stale inventory is worse than not having one, because it reads exactly like a fresh one.

godplans does not require godaudits and does not call it. This is a read of an artifact that may happen to be there, never a dependency: the plan must be authorable, and the validator must pass, on a machine that has never installed it.

### An `absent:` reason names what looked

In brownfield mode, `absent:` is a negative claim about a codebase, and the claims-and-evidence contract in `plan-format.md` already says a negative claim needs a command rather than a file citation. Excluded rows are where that rule is broken most often, because the sentence is short and sounds checked.

So a brownfield `absent:` reason carries a backticked citation: the search that came back empty, or the evidence artifact that recorded the absence.

```
| seo | excluded | absent: no HTML template, route table, or static site config under src/ (`rg -l "<html|<!DOCTYPE|createServer" src/` returns nothing); revisit when: any task adds a server-rendered route or a static site config |
```

`by-design:` needs no command. It is the plan deciding, not the plan reporting, and there is nothing to have looked at. This is why greenfield exclusions are almost always `by-design:` and brownfield exclusions are usually not.

## Evidence states

Every claim the matrix and the documentation set make about this project carries one of five states. The state is what licenses the disposition, so it is recorded before the disposition is chosen.

| State | What the plan is saying | May it exclude a domain or document? |
|---|---|---|
| `present` | this project has the thing, and here is where | no, it selects |
| `absent` | this was checked and the thing is not there; the reason names what checked | yes |
| `by-design` | the plan decides this project will not have the thing | yes |
| `unknown` | nobody looked, or the answer is not derivable from what the plan has | **no** |
| `hint` | something matched and it is not enough to decide on | **no** |

`unknown` is not `absent`, and conflating them is the failure this table exists to prevent. Reporting "we did not look" as "we decided this does not apply" produces two sentences that read identically and have opposite consequences a year later.

- **Greenfield**: the honest state for anything the plan settles is `by-design`. There is nothing to inspect, and the plan is the decision. `llm | excluded | by-design: the product answers from indexed text with no model call` is a decision. `llm | excluded | no model calls` is a claim about a codebase that does not exist yet.
- **Brownfield**: `absent` requires that something actually looked, and the reason names it with a backticked command or evidence artifact. `absent: no HTML template, route table, or static site config under src/ (`rg -l "<html|<!DOCTYPE" src/` returns nothing)` is checkable. A bare "no public pages" is not.
- **`unknown` and `hint` never exclude.** A domain whose state is either becomes applicable, or its question goes to `## Open Questions` with a recommended default. One confidently false exclusion costs more trust than ten honest unknowns, because the unknowns advertise themselves and the false exclusion does not.

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

The archetype drives the applicability matrix defaults and, through it, the documentation set. A wrong archetype therefore mis-selects two downstream artifacts at once, silently, so it is scored rather than eyeballed and the score is written into the plan.

Signals beat labels. What the user calls the project is one input; what the project does is the evidence.

| Archetype | Positive signals (weight) | Veto: score is zero if present |
|---|---|---|
| cli-tool | terminal entry point (3), no listening socket (2), distributed as a binary or package (2) | a first-party HTTP surface end users reach |
| library | consumed as an API by other code (3), published package manifest (2), no entry point of its own (2) | a first-party HTTP surface, an app-store target |
| api-service | HTTP or RPC surface (3), service deploy target (2), no first-party frontend (2) | an app-store target |
| saas-dashboard | authenticated session (3), first-party frontend over domain data (3), per-user or per-tenant data (2) | none |
| marketing-site | public crawlable pages (3), a conversion goal (2), little or no persisted domain state (2) | an authenticated session over domain data |
| mobile-app | app-store or device target (3), native or cross-platform UI SDK (3) | none |
| ml-pipeline | batch or streaming data flow (3), a training or inference step (3), a dataset or feature store (2) | an app-store target |
| extension | host extension manifest (3), runs inside a host surface (2) | a deploy target of its own |
| game | real-time loop (3), a scene or asset pipeline (2) | none |

### Scoring

A weighted sum, not a decision tree. A tree returns one answer, no runner-up, and nothing to show when it is wrong. A sum returns a second place and a distance, which is what the confidence and the counterfactual need.

1. **Score** each archetype as matched weight over that archetype's total positive weight, to two decimals. A veto signal zeroes the score outright; it is not a penalty, because a published package that also serves HTTP is not a library and no amount of matched weight should make it one.
2. **Primary** is the highest score. **Runner-up** is the second highest above zero, or `none` when nothing else scored.
3. **Margin** is `(primary - runner-up) * 100`, rounded to the nearest integer, in points. With no runner-up the margin is the primary score times 100.
4. **Floor is 0.45.** Below it the archetype is `unknown`, the archetype question takes a slot in the interview batch, and no default may be taken for it.
5. **Confidence** is `high` only at a margin of 15 points or more **and** a primary score of 0.70 or more. Exactly one of the two gives `medium`. Neither gives `low`.

Confidence is arithmetic, not a feeling. The validator recomputes the margin from the two scores and the confidence from the margin and the primary score, and refuses a plan whose stated confidence does not follow from its own numbers.

### What low confidence costs

`low` confidence is not a disclaimer, it withholds two things until a human confirms the archetype:

- The archetype goes into `## Open Questions` as a decision ticket with a recommended default.
- No `assure`-stage documentation-set row may be marked `not-applicable`. The assure stage is where threat models and compliance records live, and those are exactly the rows a misread archetype deletes without anyone noticing.

`medium` confidence carries the counterfactual and nothing else. `high` confidence carries it too, because the cheapest moment to price a wrong archetype is before any task is written.

### The archetype counterfactual

Every plan records what changes if the runner-up is right, priced in the same units as the blast radius rule: tasks and phases. This is the archetype-level version of that rule, and it exists for the same reason. A number next to the alternative converts "are you sure" into a decision the user can make in one sentence.

```markdown
### Archetype confidence

- Primary: saas-dashboard (score 0.88)
- Runner-up: api-service (score 0.57)
- Margin: 31 points
- Confidence: high
- Vetoes applied: none
- If the runner-up is right: +2 tasks and +0 phases; the ui and seo rows flip to excluded, GP-210 through GP-212 drop, and the contract-test task in Phase 3 grows a consumer fixture
```

Hybrids are not a merge. A project that scores close on two archetypes has one primary and, where the second thing is real, an overlay. Merging two matrices and letting one win conflicts forces a false choice at the top of the tree and produces the wrong set for exactly the project that is both.

## Overlays

An archetype answers what this thing is. An overlay answers what extra obligations it carries. Overlays are additive and orthogonal: a project has exactly one archetype and zero or more overlays.

| Overlay | Fires when | Forbids excluding |
|---|---|---|
| `ai-system` | the product calls a model at runtime, or ships one | llm |
| `public-ui` | the project owns rendered pixels somebody outside the team reaches | ui, seo |
| `shipped-artifact` | users install, download, or depend on a versioned artifact | deploy |
| `operated-by-others` | somebody other than the author runs it in production | observe, deploy |
| `regulated-data` | personal, health, payment, or otherwise regulated data is stored | database, llm when `ai-system` also fires |
| `agent-skill-package` | the deliverable is instructions an AI agent consumes | agent-memory |

**Overlays raise and never lower.** An overlay moves its domains up the lattice `excluded < deferred < applicable`; nothing an overlay does may push a domain down it. Concretely, an overlay forbids `excluded` for its domains. Deferral stays available wherever the deferrable set already allows it, so `public-ui` on a project whose visual system genuinely comes later still defers `ui` with its trigger. What it cannot do is deny that `ui` exists.

This is the same monotonic rule the module disposition enforces one level down, applied to the matrix itself. Without it, an overlay written to add obligations could be read as a license to trim, which is the failure mode that makes a selection engine worse than no engine.

Record overlays in frontmatter as `overlays: [ai-system, regulated-data]`, or `overlays: []` when none fire. An empty list is a finding like an empty hard-to-reverse-bets list: it says each overlay was considered and none applied, not that nobody looked.

## Scale calibration

State it in the plan; every module's requirements scale with it.

- **weekend**: throwaway or personal utility. Plan depth: decisions and a short task list. Weekend plans have at most 3 phases and 8 tasks. Sum task appetites to the user's stated capacity, combine related implementation and documentation work, and keep only requirements that materially alter behavior, public compatibility, security, or verification. Security still applies (secrets, injection), compliance still applies, and observability collapses to local error reporting or logs.
- **side-project**: real users possible, one maintainer. Deploy, backups, and error tracking are planned; SOC 2 is not.
- **funded-product**: paying users, a team, uptime matters. The full applicable matrix, honest SLOs, launch plan.
- **enterprise**: compliance regimes, multiple teams, audits. Everything, plus the compliance mapping the security module demands.

Calibration is a ceiling-setter, not an excuse: a weekend project with user passwords still hashes them with argon2id. It is also a scope ceiling: rubric coverage cannot manufacture work that exceeds the declared capacity. Cheap corners are cut openly, in the plan, as named decisions ("no staging environment: acceptable for side-project scale, revisit at 100 users"), never silently.

## The applicability matrix

Every domain gets a row with one of three statuses. Applicable means the domain pass runs now and its requirements bind. Excluded requires an evidence state, a reason specific to this project, and a tripwire; "not needed" is banned by the substitution test. Deferred means the domain's decisions are reversible until a named trigger fires, so the pass is postponed rather than skipped: the row names the trigger (an observable event, never "later") and argues why waiting is safe. When the trigger fires, the plan returns to `planning` and the deferred domain pass runs as a replan.

### Excluded rows carry a tripwire

A deferred row already names the event that forces its pass. An excluded row used to name only a reason, which made it permanent: true the day it was written and silently wrong the week the project changed. Every excluded row now carries all three parts, in this cell order:

```
| llm | excluded | by-design: the product ranks indexed text with BM25 and makes no model call; revisit when: any task adds a model SDK dependency, an inference endpoint, or a prompt template |
```

- **Evidence state**: `absent:` or `by-design:` opens the cell. `unknown:` and `hint:` are refused, because neither licenses an exclusion.
- **Reason**: specific enough to fail the substitution test against another project.
- **`revisit when:`**: an observable predicate that would make the domain applicable again. Same bar as a deferral trigger: an event somebody could notice, never "later", "eventually", "post-MVP", or "if needed". An executor that trips the predicate returns the plan to `planning` and runs the domain pass, exactly as a deferral trigger does.

An exclusion with no tripwire is not a decision with an expiry, it is a silence with a reason attached, and it is the row an auditor pulls first.

The five never-excludable domains (security, code-quality, style-genome, repo, roadmap) scale down instead, so they never carry a tripwire; they carry a scale note.

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
| llm | excluded | by-design: expense splitting is arithmetic, so no model call is planned; revisit when: any task adds a model SDK dependency, an inference endpoint, or a prompt template |
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
| launch | excluded | by-design: internal tool, adoption is an email; revisit when: the plan adds a sign-up route reachable without an invite, or `public_release` flips to true |
```

Hard rules: security, code-quality, style-genome, repo, roadmap are never excluded and never deferred (they scale down instead). seo requires a public crawlable surface. llm requires actual model integration; "we might add AI later" is a roadmap entry, not an llm pass and not a deferral. ui requires rendered pixels the project owns.

### Module disposition and monotonic escalation

After the table, the compact module disposition records what each applicable module's requirements did. Its grammar is one line per module:

```
- security: landed R-SEC-1, R-SEC-4, R-SEC-12; dropped-by scale R-SEC-22, R-SEC-27 (side-project: no SOC 2 program and no dedicated security review board)
- ui: landed R-UI-2, R-UI-9; dropped-by archetype R-UI-14 (no design system to publish; the app uses stock primitives)
```

Three layers may drop a requirement, and the line names which one did: `scale`, `archetype`, or `form`. That naming is the whole point. Precedence alone does not save a plan, because a later layer is not a more correct layer, it is only a later one. Without a recorded dropper, a requirement cut to fit a weekend appetite looks identical to a requirement nobody ever considered, and only one of those is a decision.

Two rules ride on top:

- **A dropped requirement may not appear on any task's `Requirements:` line.** Claiming a requirement was cut while a task still traces to it means one of the two is lying, and the validator refuses both.
- **A landed requirement appears somewhere concrete**: a decision, a task acceptance line, or an open question. Landed is a claim about the document, not about intent.

## The interview

One batch, 3 to 5 questions, only questions that change the plan. Rules:

1. **Spend questions on hard-to-reverse bets.** Data-model shape, multi-tenancy, auth boundary, public API commitments, pricing model when it constrains architecture. Never spend a question on something a module can decide with a stated default (formatter choice, test runner).
2. **Every question ships a recommended default**, so "defaults" is a complete answer. Format: the question, why it matters (one line), options, the recommendation marked.
3. **Batch, do not drip.** One message with all questions. Follow-ups only when an answer creates a genuine fork.
4. **Everything not asked becomes a stated assumption**, flagged in the plan as a hypothesis with a validation plan. The assumptions ledger goes into the Decisions section, labeled.
5. **Every assumption is priced.** See the blast radius rule below. An unpriced assumption asks the user to audit the plan for free.
6. **Brownfield asks less.** The codebase already answered most questions; asking the user something the code answers is a discovery failure.
7. **Non-interactive fallback.** When no user is available to answer (CI, autonomous runs), take every default, mark all of them as hypotheses, and say so at the top of the plan.
8. **Ask where the documentation lives** whenever the project is brownfield or has more than one maintainer. A repository cannot see a wiki, and a documentation set that reports "absent" for something already written in Confluence discredits every other row. When the question is not worth a slot in the batch, take `repo` as the default, price it, and state the boundary in the documentation set section either way (`doc-set.md` section 8).

### The blast radius rule

Every entry in the assumptions ledger carries what changes if it is wrong, measured in plan units:

```markdown
- A3: a workspace's data is never visible across workspaces (assumed; no cross-org reporting was described)
  - Blast radius: wrong costs +6 tasks and +1 phase; per-object ACLs replace workspace-scoped RLS, rewriting GP-201 and every Phase 4 query
  - Validated by: GP-108
```

Two properties make this worth the line it costs. It converts a formless worry into something the user can act on in one sentence, and it is the artifact a lead forwards upward, because it prices a product decision in units of work. It is also what makes "answer defaults" an informed choice rather than a shrug: a wrong assumption is cheap when its cost is printed next to it.

The prices are counts of tasks and phases the plan would gain or lose, not adjectives. "Significant rework" is refused; "+6 tasks and +1 phase" is not. Where the honest answer is that the plan barely moves, say `+0 tasks; the token table is additive`, because a cheap assumption is exactly the one the user should stop worrying about.

Question quality bar, by example. Bad: "What database do you want?" (module decides with a default). Good: "Is a workspace's data ever visible across workspaces (shared boards, cross-org reporting)? Recommendation: no, hard tenant isolation; this decides the schema and every query." Bad: "Do you want tests?" (never a question). Good: "Is the public API versioned from day one? Recommendation: yes, `/v1/` prefix; unversioned public APIs are the most expensive reversal in this archetype."

## Output of discovery

By the end of Phase 3 the following exist, ready for the domain passes:

- Mode, primary product form, any independently justified secondary form, and scale calibration.
- The archetype with its score, its runner-up, the margin, the derived confidence, any veto applied, and the counterfactual priced in tasks and phases. A `low` confidence archetype additionally appears in Open Questions.
- The overlay list, or an explicit empty list meaning each was considered and none fired.
- Plan provenance: source revision or `none`, evidence inventory, SHA-256 input digest, and UTC validation timestamp.
- The applicability matrix, complete: every excluded row carrying its evidence state, reason, and `revisit when` predicate.
- The user's answers, verbatim where load-bearing.
- The assumptions ledger: every default taken, each flagged as a hypothesis and priced with its blast radius in tasks and phases.
- The documentation-set inputs: system of record, external authorizer, maintainer count, and whether the repository is public, so the repo pass can select the document set without a second interview.
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
- **Exclusion theater**: an excluded row whose reason is true today and unfalsifiable forever, so nothing ever reopens it. Refused: every exclusion carries an observable `revisit when` predicate, which is what makes it a decision with an expiry rather than a silence.
- **Unknown as absent**: excluding a domain because nothing looked at it, phrased as though something had. Refused: `unknown` and `hint` cannot exclude; the domain becomes applicable or its question goes to Open Questions with a default.
- **The unpriced assumption**: a ledger entry that flags a hypothesis without saying what it costs to be wrong. Refused: blast radius in tasks and phases, or the entry is a disclaimer rather than a decision aid.
- **Anonymous requirement drop**: a module requirement missing from the plan with no record of which layer removed it. Refused: `dropped-by scale`, `archetype`, or `form`, with a reason, so a cut is distinguishable from an oversight.
- **The confident archetype**: one label picked from the user's phrasing, with no runner-up, no margin, and no record of what the alternative would have cost. Refused: score it, name the second place, and price the counterfactual; an archetype nobody can argue with is an archetype nobody checked.
- **Confidence as a mood**: a stated confidence that does not follow from the recorded scores, usually `high` on a 4-point margin. Refused: confidence is recomputed from the margin and the primary score, and the validator fails the mismatch.
- **The merged hybrid**: two archetypes blended into one matrix with a tie-break rule, which produces the wrong set for precisely the project that is both. Refused: one primary archetype plus overlays.
- **The subtractive overlay**: an overlay read as permission to trim a domain, so a project that carries more obligations ends up planning fewer. Refused: overlays raise and never lower; an overlay domain is never excluded.
- **Borrowed staleness**: reusing a `.godaudits/EVIDENCE.json` from an older revision because it was there. Refused: fresh means the revision matches; anything else is re-derived, and the plan says which happened.
- **The unlooked absence**: a brownfield `absent:` reason with no command behind it, which is the negative claim that reads most checked and is checked least. Refused: cite the search that came back empty, or use `by-design:` and own the decision.
