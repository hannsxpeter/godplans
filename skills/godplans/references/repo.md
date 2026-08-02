# Repository and CI planning module

Plans the Repository and CI sections of PLAN.mdx: file inventory, documentation set, CI pipeline, quality tooling, security automation, release machinery, and agent-safety layer. The orchestrator loads this module for every archetype; only the target tier and file set vary. A marketing-site or library plan still needs a repo; nothing excludes this domain except a no-repo constraint stated by the user.

## Lineage

Descends from repo-ready, the building-tier ready-suite skill that sets up production-grade repository structure across any stack (Node, Python, Go, Rust, Java, Ruby, Swift, C#, PHP, Elixir, C++, Dart) and any platform (GitHub, GitLab, Bitbucket, Azure, Gitea, SourceHut). repo-ready exists to kill one failure mode: repositories that look set up but are not (README with only a title, CONTRIBUTING full of TODOs, SECURITY.md pointing at security@example.com, CI running echo, LICENSE with {{author}}). The disciplines that carry over into plan time: the no-placeholder rule becomes a plan-time obligation to collect real values before any file is listed; the relevant-files-not-maximum-files rule (project type x stage x audience) becomes a mandatory tier declaration; the 42-point Mode C audit becomes the acceptance bar the emitted plan must pass by construction.

## Decisions to force

Hardest to reverse first. Each must land in the Decisions section of PLAN.mdx as a grounded decision, a flagged hypothesis, or exactly one Open Questions entry with a recommended default.

1. Monorepo vs polyrepo vs multi-repo suite. Hard to reverse because directory layout, workspace tooling, CI matrix shape, import paths, and cross-repo invariants all derive from it; splitting or merging repos later rewrites every path and pipeline. Options: single repo (default for one deployable plus its docs), monorepo with workspaces (multiple deployables sharing types), multi-repo suite (independent release cadences, separate access control). Default: single repo unless the architecture section names two or more independently deployed units. If .architecture-ready/ARCH.md or the plan's architecture section exists, read it; do not re-decide.
2. License and copyright identity. Hard to reverse because relicensing needs consent from every contributor once outside code lands. Options: MIT (default for OSS), Apache-2.0 (patent grant matters), proprietary (internal or commercial). The plan must record real SPDX identifier, real year, real author; {{author}} is a refusal.
3. Project type x stage x audience triple, pinned to a target tier. Hard to reverse in effort terms: the triple determines the entire file inventory, and re-tiering means regenerating or deleting files that other files cross-reference. Type from the 11-type matrix (library, CLI, web app, API, mobile, desktop, DevOps-IaC, data-ML, monorepo, docs site, framework). Stage sets file count: MVP 5-8 files, Growth 12-18, Enterprise 20-30+. Audience (OSS community, internal team, enterprise) sets tone. Tier: 1 Essentials, 2 Team Ready, 3 Mature, 4 Hardened. Default: Tier 1 for a solo MVP, Tier 2 once a second contributor is expected.
4. Branching model, commit convention, tag scheme. Hard to reverse because CONTRIBUTING, PR templates, release automation, and changelog generation all parse the convention; changing it mid-history breaks release tooling. Default: trunk-based with short-lived branches, Conventional Commits, vX.Y.Z SemVer tags. Alternatives (GitFlow, calver) only with a stated reason.
5. Folder structure to stack convention. Hard to reverse because every import, CI path filter, and doc link encodes it. Go: cmd/, internal/, pkg/. Python: src/package_name/. Next.js: app/. Plus source/tests/docs separation. Default: the detected or chosen stack's idiomatic layout, named explicitly in the plan; never a generic src/ for a stack with a stronger convention.
6. One tool per job. Moderately hard to reverse; dual tools produce conflicting diffs on every commit until one is ripped out. Exactly one linter (Biome or ESLint, Ruff, golangci-lint, clippy), one formatter, one dependency bot (Dependabot or Renovate, never both), one release tool (release-please, semantic-release, or changesets). Default per stack: Biome for new Node, Ruff for Python, the built-in for Go and Rust; Dependabot with grouping; release-please.
7. Platform and CI provider. Reversible with pain: workflow syntax, branch protection, and badges are provider-specific. Default: GitHub plus GitHub Actions unless the user names another platform.
8. Agent-safety layer (for repos that agents will execute against, which every godplans output is). Cheap to add at scaffold, embarrassing to retrofit after an agent force-pushes. Components: .claude/settings.json denylist for destructive git ops, .githooks/pre-push blocking force-push to main, .gitleaks.toml wired into pre-commit and CI. Default: all three, planned as one task.

## Plan requirements

The orchestrator's inversion pass distributes these onto tasks. Every requirement states what PLAN.mdx must contain, then its acceptance criterion.

R-REPO-1. The plan pins the project type x stage x audience triple and the target tier (1-4) in the Repository section, and the planned file inventory is derived from that triple: 5-8 files at MVP, 12-18 at Growth, 20-30+ at Enterprise.
Criterion: WHEN the Repository section is read, THE PLAN SHALL state type, stage, audience, and tier on named lines, and the file count in the repo scaffold task SHALL fall inside the stage's band.

R-REPO-2. The plan declares mode (greenfield, enhancement, audit, multi-repo suite) and, for enhancement of an existing repo, includes the rollback protocol: on low-confidence stack detection or a config conflict (existing Biome vs planned ESLint), the executing agent stops, describes the conflict, and proposes re-detect or leave-alone; no existing config file is ever overwritten silently, and an existing Pillars standard (AGENTS.md plus agents/*.md with pillar: frontmatter) is preserved.
Criterion: IF mode is brownfield, THE PLAN SHALL contain an additive-only constraint and the stop-describe-propose conflict protocol as task acceptance criteria on every task that writes a config file.

R-REPO-3. The plan forbids destructive git operations on the user working tree: no task, Verify command, or executor rule may run git reset, git checkout --, git clean, or rm against tracked files.
Criterion: WHEN any task's Verify or acceptance lines are scanned, THE PLAN SHALL contain no destructive git command, and the Rules section SHALL name the prohibition.

R-REPO-4. The plan names the stack and platform explicitly (or cites the plan's stack section), and every repo artifact derives from it: .gitignore entries match the stack (node_modules/, __pycache__/, target/, .next/), linter and formatter are stack-native, folder structure follows stack convention, and no file for an uninstalled tool is planned.
Criterion: WHEN the repo scaffold tasks are read, THE PLAN SHALL name the stack once and every tooling file SHALL be justified by that stack; an ESLint config in a Python plan is a failed criterion.

R-REPO-5. For polyglot repos, the plan names the primary and secondary languages, layers tooling per language without unifying it, gives the CI matrix one job per language, and generates shared types from one source of truth.
Criterion: IF more than one language appears in the stack, THE PLAN SHALL contain a primary-language declaration and a per-language CI job list.

R-REPO-6. The plan carries real values for everything a placeholder would otherwise fill: license SPDX id, copyright year, author name, security disclosure contact and response timeline, and the actual lint, type-check, test, and build commands. These are collected at discovery or defaulted from the user's identity; {{var}}, TODO, TBD, example.com, and INSERT-style markers are banned from planned file content.
Criterion: WHEN the plan is grepped for {{, TODO, TBD, PLACEHOLDER, or example.com inside planned repo file content, THE PLAN SHALL return zero matches, and the discovery assumptions SHALL list the real values used.

R-REPO-7. The plan specifies a README task whose acceptance requires description, install steps, usage example, license reference, and a Quick Start of 5 or fewer commands that a fresh clone can execute.
Criterion: WHEN the README task is read, THE PLAN SHALL list those five elements as grep-verifiable acceptance conditions including the 5-command Quick Start cap.

R-REPO-8. The plan specifies the documentation set appropriate to tier: CONTRIBUTING describing the real branch model, real setup, and real test command; SECURITY.md with the real contact and timeline; CHANGELOG in Keep a Changelog format with an Unreleased section; CODE_OF_CONDUCT only at tiers whose audience warrants it.
Criterion: IF tier is 2 or above, THE PLAN SHALL include tasks for CONTRIBUTING, SECURITY.md, and CHANGELOG whose acceptance lines name the real workflow, real contact, and Keep a Changelog headings; IF tier is 1, THE PLAN SHALL exclude them with a stated reason rather than silently.

R-REPO-9. The plan's CI task triggers on pull_request and on push to the default branch, and runs the project's real lint, type-check, test, and build commands, named verbatim in the task's acceptance lines. A CI job that runs echo or a no-op is a planning failure, not an execution detail.
Criterion: WHEN the CI task is read, THE PLAN SHALL name both triggers and all four real commands, and no acceptance line SHALL permit a stub step.

R-REPO-10. The plan configures quality tooling as a set: one linter, one formatter, one git-hook manager per stack (Husky plus lint-staged for Node; pre-commit or Lefthook otherwise), plus .editorconfig and .gitattributes with * text=auto.
Criterion: WHEN quality tooling tasks are read, THE PLAN SHALL name exactly one tool per job and SHALL include .editorconfig and .gitattributes in the file list.

R-REPO-11. The plan enforces one tool per job across the whole repo: no ESLint plus Biome, no Dependabot plus Renovate, no two formatters. Where the stack section already picked a tool, the repo section reuses it rather than re-deciding.
Criterion: IF two planned tools serve the same job, THE PLAN SHALL fail its self-audit and the orchestrator SHALL remove one before emission.

R-REPO-12. The plan wires security automation at tier 2 and above: exactly one dependency bot with update grouping to reduce PR noise, SAST (CodeQL or Semgrep), secret scanning, and branch protection requiring PR review plus CI pass before merge.
Criterion: IF tier is 2 or above, THE PLAN SHALL contain tasks for the bot config, the SAST workflow, and a branch protection step with its exact settings listed.

R-REPO-13. The plan specifies release machinery consistent with the commit convention: one release tool (release-please, semantic-release, or changesets), SemVer vX.Y.Z tags, and platform Releases with generated notes. CONTRIBUTING, the PR template, and the release tool must all cite the same commit convention.
Criterion: WHEN release and contributing tasks are read, THE PLAN SHALL name one release tool and one commit convention, and both tasks SHALL reference the same convention string.

R-REPO-14. At tier 4 (Hardened), the plan adds signed commits, a dependency inventory (CycloneDX or SPDX, generated by a named resolver and recorded as dated evidence, never hand-written), and provenance or artifact signing; at lower tiers it explicitly stops, declaring the completed tier at the boundary rather than half-starting the next. ADRs and runbooks are not repo-owned at any tier: `decide.adr` belongs to the architecture module (R-ARCH-14) and `operate.runbook` to the observe module, and this module records their documentation-set rows without planning a second task for either.
Criterion: IF tier is 4, THE PLAN SHALL include tasks for each hardened artifact and SHALL NOT contain a repo task that writes an ADR or a runbook; IF tier is below 4, THE PLAN SHALL contain a tier-boundary line stating where repo work stops and why.

R-REPO-15. The plan includes the agent-safety layer as a first-class task: .claude/settings.json denylist for destructive commands, .githooks/pre-push blocking force-push to protected branches, and .gitleaks.toml wired into both pre-commit and CI. These are the AGENT-01/02/03 checks and every godplans repo is agent-run by definition.
Criterion: WHEN the agent-safety task is read, THE PLAN SHALL list all three files with grep-verifiable content conditions (denylist entries, hook exit-nonzero-on-force-push, gitleaks CI step).

R-REPO-16. The plan's cross-references are closed under the tier: every file a planned file links to is itself planned at that tier. README linking CONTRIBUTING requires CONTRIBUTING in the inventory; badges are planned only for services the plan actually configures, so no badge can render 404 or unknown.
Criterion: WHEN the planned file inventory is checked, THE PLAN SHALL contain every cross-reference target, and every planned badge SHALL map to a planned, configured service.

R-REPO-17. The plan applies the single-naming rule: the same concept carries the same name in directory, test file, endpoint, table, and README section, and the repo section names the canonical spelling for each core concept it introduces.
Criterion: WHEN core concept names appear across repo tasks, THE PLAN SHALL use one spelling per concept with no synonyms across file paths and doc headings.

R-REPO-18. The plan bans empty ceremony: no directories containing only .gitkeep, no generated .env (only .env.example), no GOVERNANCE.md or full community pack on a solo project, no uncustomized issue templates carrying stock text like "A clear and concise description of the bug".
Criterion: IF the audience is solo or internal-MVP, THE PLAN SHALL exclude governance and community-pack files with a stated reason, and every planned template task SHALL require project-specific content.

R-REPO-19. The plan defines its own finish line in audit terms: the Repository section states the target Mode C score band (out of 42 across Essentials 7, Community 7, Quality 7, Security 6, DX 6, Release 6, Agent-Safety 3) that the completed repo must reach, matched to the pinned tier, so a post-build audit has a defined pass threshold.
Criterion: WHEN the Repository section is read, THE PLAN SHALL state a numeric target score and its tier band (0-13 Needs work, 14-22 Basic, 23-30 Good, 31-35 Excellent, 36-42 Exemplary).

R-REPO-20. The plan consumes upstream sections instead of re-deriving: stack from the stack section, repo topology from architecture, product name and audience from product. On drift between an upstream artifact and existing code (brownfield), the plan trusts the code and records the discrepancy.
Criterion: WHEN repo decisions overlap upstream sections, THE PLAN SHALL cite the upstream decision rather than restate a new one, and any brownfield drift SHALL appear as a noted assumption.

R-REPO-21. The plan emits `## Documentation set`, the manifest selected from `doc-set.md` against the applicability matrix, product form, scale, `public_release`, and the security and compliance profile. Every row carries a catalog id, its lifecycle stage, a verdict of required, recommended, optional, or not-applicable, the owning module, and what selected it; a small project may fold several documents into one file, but a required document is never silently dropped. Documentation scales to the project: a prototype does not get a business-continuity plan, and a regulated platform does not ship without a threat model and a traceability record.
Criterion: WHEN the plan sets its applicability matrix, THE PLAN SHALL emit exactly one `## Documentation set` section whose rows use catalog ids and stages from `doc-set.md`, and SHALL tag every row required, recommended, optional, or not-applicable.

R-REPO-22. Every not-applicable row in the documentation set carries the same three parts an excluded applicability row carries: an evidence state of `absent:` or `by-design:`, a project-specific reason, and an observable `revisit when:` predicate. `unknown:` and `hint:` are refused, because a document skipped by an unexamined absence is a laundered gap, and it reads exactly like a considered decision a year later when nobody remembers which it was.
Criterion: WHEN a documentation-set row is not-applicable, THE PLAN SHALL state an accepted evidence state, a reason, and a revisit-when predicate that names an observable event and is not "later", "eventually", "post-MVP", "future", "when ready", or "TBD".

R-REPO-23. Each documentation-set row names exactly one owning module, taken from the catalog, and the repo pass plans only the rows it owns. Where another module owns the artifact (architecture owns `decide.adr`, database owns `design.data-model`, observe owns `operate.runbook`, style-genome owns `build.style-genome`, agent-memory owns `build.agent-memory`), the repo pass records the row and defers the writing task to that module rather than planning a second task for the same file.
Criterion: WHEN the documentation set is emitted, THE PLAN SHALL give every row exactly one owner module, and no two tasks in the plan SHALL write the same document path.

R-REPO-24. Every required and recommended row names the GP task that writes it, and every planned document carries lifecycle frontmatter (id, stage, durability, owner role, system of record, status, review cadence, and the paths it covers) as an acceptance condition of that task. Durability governs the task shape: a `durable` row gets a task that writes and later edits the document in place, an `evidence` row gets a task that produces a new dated artifact plus an index that lists runs and never a task that edits an existing one, and a `transient` row is never planned as a deliverable because its decision belongs in `## Decisions`.
Criterion: WHEN a documentation-set row is required or recommended, THE PLAN SHALL name the GP task that writes it, that task's acceptance SHALL require the lifecycle frontmatter fields, and no task SHALL edit an artifact whose row is durability `evidence`.

R-REPO-25. The documentation set states its boundary and its system of record. It says in the section itself that the manifest covers documentation committed to this repository, and every row whose documentation lives in a wiki, an intranet, or a compliance platform is marked present-elsewhere rather than absent. Review cadences, retention periods, and support windows are cited to a source or raised as open questions; none is invented. In brownfield and replan mode the manifest also records document state, so an existing current document is adopted with frontmatter rather than rewritten by a task, a drifted one gets a refresh task, and a document the profile does not justify is recorded as an orphan with a question rather than a deletion task.
Criterion: WHEN the documentation set is emitted, THE PLAN SHALL contain the repository-boundary statement, SHALL mark externally held documents present-elsewhere, and SHALL contain no invented review cadence, retention period, or support window; IF mode is brownfield or replan, THE PLAN SHALL record adopt, refresh, complete, confirm, or orphan for every document the repository already carries.

## Task seeds

- [ ] GP-xxx Scaffold tier-scoped repo file inventory
  - Files: README.md, LICENSE, .gitignore, .gitattributes, .editorconfig
  - Acceptance: README contains install, usage, and a Quick Start of 5 or fewer commands; LICENSE contains the real SPDX text, current year, and real author; .gitignore contains the stack's canonical ignore entries; grep for "{{", "TODO", "example.com" across all five files returns nothing
  - Verify: grep -rEn '\{\{|TODO|TBD|example\.com' README.md LICENSE .gitignore .gitattributes .editorconfig; test $? -eq 1
  - Requirements: R-REPO-1, R-REPO-4, R-REPO-6, R-REPO-7

- [ ] GP-xxx Write contributor and security docs
  - Files: CONTRIBUTING.md, SECURITY.md, CHANGELOG.md, CODE_OF_CONDUCT.md
  - Acceptance: CONTRIBUTING names the real branch model, setup commands, and test command; SECURITY.md contains a real contact and a response timeline; CHANGELOG has Keep a Changelog headings with an Unreleased section
  - Verify: grep -q 'Unreleased' CHANGELOG.md && ! grep -q 'example.com' SECURITY.md && grep -qE 'npm test|pytest|go test|cargo test' CONTRIBUTING.md
  - Requirements: R-REPO-8, R-REPO-13, R-REPO-6

- [ ] GP-xxx Wire CI pipeline with real commands
  - Files: .github/workflows/ci.yml
  - Acceptance: workflow triggers on pull_request and push to main; jobs run the project's actual lint, type-check, test, and build commands; no step is echo or a placeholder; polyglot repos get one job per language
  - Verify: grep -q 'pull_request' .github/workflows/ci.yml && ! grep -qE 'run: *echo' .github/workflows/ci.yml
  - Requirements: R-REPO-9, R-REPO-5, R-REPO-4

- [ ] GP-xxx Configure quality tooling, one tool per job
  - Files: biome.json (or stack equivalent), .editorconfig, lefthook.yml (or .husky/), .gitattributes
  - Acceptance: exactly one linter and one formatter configured for the stack; a git-hook manager runs them pre-commit; no config file exists for an uninstalled tool; no second tool shares a job
  - Verify: test -f biome.json && ! test -f .eslintrc.json
  - Requirements: R-REPO-10, R-REPO-11, R-REPO-4

- [ ] GP-xxx Wire security automation and branch protection
  - Files: .github/dependabot.yml, .github/workflows/codeql.yml
  - Acceptance: exactly one dependency bot configured with update grouping; SAST workflow present and stack-correct; branch protection settings listed for the default branch requiring PR review plus CI pass
  - Verify: test -f .github/dependabot.yml && ! ls renovate.json 2>/dev/null
  - Requirements: R-REPO-12, R-REPO-11

- [ ] GP-xxx Install agent-safety layer
  - Files: .claude/settings.json, .githooks/pre-push, .gitleaks.toml, .github/workflows/ci.yml
  - Acceptance: settings.json denies destructive git commands; pre-push hook exits nonzero on force-push to main; .gitleaks.toml exists and a gitleaks step runs in pre-commit and CI
  - Verify: grep -q 'force' .githooks/pre-push && grep -q 'gitleaks' .github/workflows/ci.yml
  - Requirements: R-REPO-15, R-REPO-3

- [ ] GP-xxx Configure release automation
  - Files: .github/workflows/release.yml, CONTRIBUTING.md
  - Acceptance: one release tool configured; tags follow vX.Y.Z SemVer; release notes generated from Conventional Commits; CONTRIBUTING cites the same commit convention the release tool parses
  - Verify: grep -q 'release-please' .github/workflows/release.yml && grep -qi 'conventional commits' CONTRIBUTING.md
  - Requirements: R-REPO-13, R-REPO-6

- [ ] GP-xxx Render the documentation manifest into the repository
  - Files: docs/DOCUMENTATION.md
  - Acceptance: one row per catalog id in the plan's `## Documentation set`, each with stage, verdict, owner, status, and either its writing task or its revisit-when predicate; the repository-boundary sentence is present; no row invents a review cadence or retention period
  - Verify: grep -q 'covers documentation committed to this repository' docs/DOCUMENTATION.md && ! grep -nE 'revisit when:[ ]*(later|eventually|post-MVP|future|when ready|TBD)' docs/DOCUMENTATION.md
  - Requirements: R-REPO-21, R-REPO-22, R-REPO-25

- [ ] GP-xxx Stamp lifecycle frontmatter on repo-owned documents
  - Files: README.md, CONTRIBUTING.md, SECURITY.md, docs/DOCUMENTATION.md
  - Acceptance: every repo-owned document opens with id, stage, durability, owner role, system_of_record, status, and review_cadence; status is draft on generated documents; review_cadence is copied from the catalog and never invented
  - Verify: grep -lE '^review_cadence: (on-change|on-release|none)$' README.md CONTRIBUTING.md SECURITY.md docs/DOCUMENTATION.md | wc -l | grep -q 4
  - Requirements: R-REPO-24, R-REPO-23

## Self-audit rubric

Score the drafted Repository and CI sections of PLAN.mdx out of 100. Below 85 total, revise before emission.

- Tier and profile discipline (18): full marks when type x stage x audience and target tier are pinned, the file inventory falls inside the stage band, tier boundaries are declared, and no file exists that the tier does not justify.
- No-placeholder readiness (17): full marks when every value a template would stub (license identity, security contact, CI commands, author, year) appears as a real value or a discovery default in the plan, and the ban on {{var}}, TODO, and example.com is an acceptance condition on every doc task.
- CI and quality tooling correctness (18): full marks when CI names both triggers and all four real commands, one tool per job holds across linter, formatter, bot, and release tool, and every tooling file is stack-justified.
- Security, release, and agent-safety coverage (17): full marks when the tier-appropriate security automation, branch protection, release machinery, and all three agent-safety files (AGENT-01/02/03) are planned as tasks with grep-verifiable acceptance.
- Documentation set selection and defensibility (15): full marks when every row uses a catalog id and stage, every required and recommended row names its writing task and its lifecycle frontmatter, every not-applicable row carries an accepted evidence state plus a reason plus an observable revisit-when predicate, ownership is single per document with no second task writing the same path, the boundary statement is present, and no cadence, retention period, or support window is invented. Zero for this dimension if any exclusion is unexplained, because an unexplained exclusion is worse than a missing document.
- Cross-reference and audit closure (15): full marks when every planned cross-reference target is in-inventory, badges map to configured services, the target 42-point score band is stated, and every R-REPO requirement traces to at least one task's Requirements line.

## Anti-patterns refused

- Placeholder repo: README with only a title, {{author}} in LICENSE, security@example.com, TODO in CONTRIBUTING. Refusal: the planner collects real values at discovery or states defaults as assumptions; a plan task may not be emitted until its content values are real.
- Echo CI: a workflow whose steps run echo or true so the badge turns green. Refusal: the CI task's acceptance lines name the real lint, type-check, test, and build commands verbatim; a stub step fails the self-audit.
- Stack-mismatched files: ESLint config in a Python project, .npmrc without Node, .gitignore missing the stack's build dir, configs for uninstalled tools. Refusal: every tooling file in the plan cites the stack decision that justifies it; unjustified files are cut.
- Two tools, one job: ESLint plus Biome, Dependabot plus Renovate, dueling formatters. Refusal: the planner picks one per job at plan time and records the loser as a rejected option, not a second task.
- Uncustomized ceremony: stock issue-template text, CONTRIBUTING describing a workflow the project does not use, CHANGELOG containing only a heading. Refusal: template tasks carry project-specific acceptance strings; generic stock phrases are named banned strings in acceptance lines.
- Dead badges: badges pointing at wrong repos, wrong branches, or unconfigured services. Refusal: a badge is planned only when the service behind it is a planned, configured task in the same plan.
- Bureaucracy without users: GOVERNANCE.md and a full community pack on a solo side project. Refusal: audience gating; governance files require an audience declaration that justifies them, otherwise they are excluded with a reason in the applicability matrix.
- Ghost structure: empty directories holding only .gitkeep, or a generated .env with live-looking values. Refusal: directories enter the plan only with real planned content; only .env.example is ever a planned file.
- Half-done tier: starting tier 3 files while tier 2 checks still fail, or forcing tier 4 on an MVP. Refusal: the planner matches tier to project, finishes tiers whole, and writes the explicit stop line at the boundary.
- Silent overwrite (brownfield): regenerating a config the repo already has, or clobbering an existing Pillars standard. Refusal: enhancement mode is additive-only with the stop-describe-propose rollback protocol baked into every config-writing task.
- Laundered documentation gap: a not-applicable row with no evidence state, no reason, or no tripwire. Refusal: all three are mandatory, because "not applicable" with nothing behind it is indistinguishable from "we forgot", and only one of those is defensible in a year.
- Doc-set theater: planning every document a taxonomy lists so the manifest looks thorough. Refusal: every row names the plan fact that selected it, and a row nothing selects is not planned.
- Double ownership: the repo pass planning an ADR, a runbook, a data model, or a style genome that another module already owns. Refusal: one owner per document from the catalog; the repo pass records the row and defers the task.
- Rewritten evidence: a task that updates last quarter's dependency inventory or scan output in place. Refusal: evidence artifacts are dated runs plus an index, and editing one destroys the only property that made it evidence.
- Invented lifecycle numbers: a review cadence, retention period, or support window the plan made up so the frontmatter would be complete. Refusal: cite it, take it from the user's answer, or open a question with a recommended default.
