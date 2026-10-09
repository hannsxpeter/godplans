# Agent memory (pillars) planning module

Plans the AGENTS.md loader plus the agents/ pillar tree the project ships at scaffold time, so executing agents load correct project memory from the first commit. The orchestrator loads this module for every archetype: the pillar SET varies by archetype, but the loader, the floor pillars, and the exclusion discipline are universal. The style genome arrives as pillar content inside agents/quality.md (see style-genome.md R-DNA-16), never as additions to the AGENTS.md loader or the CLAUDE.md redirect.

## Lineage

Descends from the Pillars standard (github.com/hannsxpeter/pillars, spec v1.2.2) and its three operational skills: pillars-init (archetype detection, AGENTS.md drop, local catalog, stub creation, exclusion defaults), pillars-author (evidence-based drafting of one pillar with approval gates and a no-fabrication rule), and pillars-verify (read-only drift audit of pillar claims against actual code). The discipline that carries over: agent memory is a thin constant-size loader plus per-domain files whose frontmatter routes loading; each concern is present, stubbed, excluded, locally cataloged as absent, or unknown; prescriptive content must earn its keep by being non-inferable from code; nested scopes inherit outer guidance with nearest-scope precedence; and every claim a pillar makes is checkable against the tree, so a plan that states facts the build will not produce creates drift at birth. godplans inverts the verify pass: instead of auditing pillars after the fact, the plan specifies pillars whose claims are true by construction while preserving Pillars 1.0 single-scope behavior.

## Decisions to force

1. Archetype declaration. Question: which of the eight standard archetypes is this project (CLI tool, internal API service, SaaS dashboard/web app, marketing site, mobile app, ML pipeline, OSS library, greenfield/custom)? Hard to reverse because the archetype fixes the Core-pillar applicability matrix, the starter exclusion list, and the primary Tier 3 pillar; changing it later invalidates the whole inventory. Options: pick one archetype and cite the file signals that will exist after scaffolding; or declare custom and skip exclusion defaults. Default: pick the single closest archetype; if two fit (Next.js as dashboard vs marketing site), resolve it as a discovery question, never guess.

2. Pillar inventory and exclusion set. Question: for each of the 11 Core pillars (stack, arch, data, api, ui, auth, quality, development, release, deploy, observe) and 11 Common pillars (config, security, privacy, compliance, i18n, a11y, analytics, integrations, async, cache, notifications), is it present, stubbed, excluded, cataloged absent, or unknown, and which Domain pillars join them? Hard to reverse because pillars-verify flags code appearing in an excluded area as a finding, and conflating absence with unknown creates false project claims. Options: full authoring at birth, stubs with Gaps questions, local `agents/catalog.yaml` entries for known absences, structured exclusions, or no Pillars-specific claim for unknown concerns. Default: author what the plan decides, stub what needs the user, catalog known absences that must remain discoverable, exclude inapplicable concerns with concrete reasons, and leave truly unknown concerns unknown.

3. Boundary assignments. Question: which pillar owns each piece of content (secrets in config not auth; product analytics separate from system observe; file layout in repo vs module shape in arch; transactional notifications vs marketing email; web UI in ui.md, CLI UX in cli.md; testing, errors, style bundled in quality)? Hard to reverse because content migrates poorly once agents have learned where to look, and wrong boundaries breed cross-pillar duplication. Options: follow the standard's tiebreakers or document a deviation. Default: follow the tiebreakers; deviations require a stated reason in the plan.

4. Coupling graph shape. Question: which pillars hard-couple via must_read_with (depth 1 only, max 3 per pillar) and what graduates to always_load? Hard to reverse because agents rely on frontmatter for predictable loading; hidden transitive deps or a fat always_load set are structural, not editorial, fixes. Options: keep the mandatory floor (context, repo) as the full always_load set and use sparse must_read_with; or promote a widely shared dependency after documenting the repeated dependency and confirming the total always-load budget still holds. Default: floor-only always_load; if 3 or more planned pillars would list the same dependency, promote it only when the budget has room, otherwise restructure the boundary.

5. Instruction-file topology and scopes. Question: which directories are real Pillars scopes, each containing both AGENTS.md and agents/, and which tool-native files redirect to the applicable loader? Hard to reverse because parallel instruction documents fork memory while an accidental nested scope changes precedence. Options: one root scope for a single project; root plus independently governed package scopes in a monorepo; or tool-native files as primary (non-compliant). Default: one root scope with redirects, adding a nested package scope only when it needs local routing or overrides. Outer guidance applies first and nearest-scope guidance wins conflicts.

6. Floor authoring depth. Question: are context.md and repo.md born as status: present or as stubs? Hard to reverse only in cost: stubs force every early agent session to pause and ask. Options: present at birth from plan content, or stubs. Default: present at birth; a greenfield plan already knows the domain vocabulary, invariants, and intended layout.

7. Portable discovery and budget. Question: which task phrases must route deterministically, and how much context may each scope load? Hard to reverse because fuzzy-only routing and oversized always-loaded files make behavior depend on the host and tax every task. Options: the Pillars ASCII token matcher plus routing fixtures and standard budgets; semantic matching only as an optional superset. Default: deterministic token matching, fixtures for representative tasks, always-loaded files at most 1,000 words and 8 KiB each, and task-routed files at most 2,000 words and 16 KiB each unless a documented exception earns the cost.

## Plan requirements

1. R-MEM-1: PLAN.mdx declares the project archetype from the standard 8-archetype table and cites the concrete signals (manifest fields, framework dependencies, directory shape) that will exist once scaffolded. Mapping from the godplans archetype set (discovery.md, Archetype detection): cli-tool -> CLI tool, api-service -> internal API service, saas-dashboard -> SaaS dashboard/web app, marketing-site -> marketing site, mobile-app -> mobile app, ml-pipeline -> ML pipeline, library -> OSS library; extension and game map to greenfield/custom, and an `unknown` archetype (below the 0.45 floor) maps to greenfield/custom until the archetype question resolves.
   Criterion: WHEN the archetype is declared, THE PLAN SHALL cite at least two file signals such that pillars-init detection on the finished repo would agree without asking.

2. R-MEM-2: PLAN.mdx schedules AGENTS.md at the repo root in the first commit, containing exactly the canonical elements: reference to Pillars 1.2.2, the 6-step loading protocol, the 5-state missing-pillar table, a structured excluded: yaml block, and nested-scope precedence when nested scopes exist.
   Criterion: WHEN the AGENTS.md task is specified, THE PLAN SHALL require the first four elements, SHALL add nested-scope precedence when nested scopes exist, and SHALL forbid enumerating pillar names inside AGENTS.md.

3. R-MEM-3: PLAN.mdx resolves all 11 Core and 11 Common identities as present, stubbed, excluded, locally cataloged absent, or unknown; it never silently promotes unknown to absent.
   Criterion: WHEN the inventory is emitted THE PLAN SHALL include development, release, and privacy, SHALL distinguish cataloged absence from unknown, and SHALL never claim a missing local catalog knows an absent concern.

4. R-MEM-4: PLAN.mdx specifies the excluded: list in structured {name, reason} form with project-specific reasons derived from the actual stack, not generic archetype boilerplate.
   Criterion: WHEN an exclusion is stated, THE PLAN SHALL give a concrete reason (e.g. "Vercel Analytics covers monitoring"), not a bare archetype default.

5. R-MEM-5: PLAN.mdx creates agents/context.md and agents/repo.md at status: present with always_load: true, authored from the plan's own objective, domain glossary, invariants, and repo layout section.
   Criterion: WHEN the scaffold phase is planned, THE PLAN SHALL include a task authoring both floor pillars at status: present, and SHALL NOT leave either as a stub.

6. R-MEM-6: PLAN.mdx enumerates the exact pillar inventory: every Core and applicable Common concern resolved, the archetype's primary Domain pillars included (cli.md for CLI tools, ml.md for ML pipelines, seo.md for marketing sites, payments.md for e-commerce, realtime.md for collab apps), and one-level sub-pillars planned where stable subdomains are known upfront. A sub-pillar at `agents/<parent>/<name>.md` has path-derived identity `<parent>/<name>` while frontmatter `pillar` remains the leaf `<name>`.
   Criterion: WHEN the inventory is listed, THE PLAN SHALL show a table of every planned pillar with tier, status at birth, and owning task.

7. R-MEM-7: PLAN.mdx specifies complete frontmatter for every planned pillar: pillar equal to the leaf filename (lowercase noun, never a verb), path-derived canonical identity, status, always_load true for the mandatory context and repo floor and false by default for every other pillar, a covers list, a triggers list authored for recall with synonyms starting from the standard's per-pillar trigger tables, must_read_with capped at 3, and see_also. An additional pillar may set always_load true only when the plan documents the repeated dependency under R-MEM-13 and keeps the always-loaded scope inside the R-MEM-22 total budget. Sub-pillar references are path-qualified; bare names resolve top-level pillars only.
   Criterion: WHEN a pillar file task is specified, THE PLAN SHALL state its full frontmatter, and every must_read_with reference SHALL resolve to a planned-present pillar or an excluded name.

8. R-MEM-8: PLAN.mdx mandates the exact 8-section body in every pillar (Scope, Context, Decisions, Rules, Workflows, Watchouts, Touchpoints, Gaps, in that order), unearned sections marked (none), no custom sections, Touchpoints mirroring frontmatter in plain English.
   Criterion: IF a pillar body is planned, THE PLAN SHALL require the 8 headings in order and SHALL reject any custom section.

9. R-MEM-9: PLAN.mdx records decision rationale (why this ORM, why this auth provider, why this deploy target) in its own Decisions section so each pillar's Decisions can be written truthfully at birth; anything genuinely undecided is planned as a Gaps entry, not fabricated.
   Criterion: WHEN a pillar's Decisions content is planned, THE PLAN SHALL trace each entry to a decision recorded in the plan; IF rationale is absent, THE PLAN SHALL route it to that pillar's Gaps as an ask-the-human item.

10. R-MEM-10: PLAN.mdx writes pillar Rules only for constraints not inferable from code and Context (the earn-your-keep test), such as a single allowed raw-SQL location or tenant_id required on tenant-scoped tables; Watchouts are (none) at birth with a Gaps note that they accumulate after incidents.
    Criterion: IF a planned Rule restates a fact an agent could infer from the tree ("we use Drizzle"), THE PLAN SHALL drop it; WHEN Watchouts are planned, THE PLAN SHALL set them to (none) at birth.

11. R-MEM-11: PLAN.mdx makes pillar Context sections the binding spec: declared stack versions, file locations, naming conventions, and service topology are identical to what the plan's build tasks produce, because pillars-verify checks manifests, paths, and 3-5 file convention samples.
    Criterion: IF a pillar claims a fact (path, dependency, convention), THE PLAN SHALL contain a build task whose Files or Acceptance lines produce exactly that fact.

12. R-MEM-12: PLAN.mdx assigns content to pillars per the standard's boundary tiebreakers: secrets and env vars in config.md not auth.md; product analytics separate from system observe; file layout in repo.md, module shape in arch.md; transactional notifications separate from marketing email; ui.md web-only with CLI UX in cli.md; quality bundled until depth justifies sub-pillars.
    Criterion: WHEN content is assigned across pillars, THE PLAN SHALL follow the tiebreakers or state a reasoned deviation; cross-boundary references SHALL go through Touchpoints, not duplicated prose.

13. R-MEM-13: PLAN.mdx keeps the coupling graph clean by design: no pillar exceeds 3 must_read_with entries, a dependency shared by 3 or more planned pillars is promoted to always_load only when the repeated dependency is documented and the R-MEM-22 total budget still holds, otherwise the boundary is restructured. Sub-pillars explicitly declare must_read_with: [parent] when the parent is required (it is never auto-loaded). References resolve inside their declaring scope and dependencies remain depth 1.
    Criterion: IF a planned pillar would need more than 3 must_read_with entries THE PLAN SHALL restructure the boundary before emission; IF a shared dependency is promoted THE PLAN SHALL record the dependent pillars and prove the always-loaded scope remains inside the total budget.

14. R-MEM-14: PLAN.mdx schedules the exclusion lifecycle against the roadmap: any milestone that introduces code into a currently excluded area also removes that exclusion and authors the pillar in the same milestone.
    Criterion: WHEN a phase adds code to an excluded area (e.g. a web UI in milestone 3), THE PLAN SHALL include, in that same phase, a task updating AGENTS.md excluded: and authoring the pillar.

15. R-MEM-15: PLAN.mdx specifies any CLAUDE.md, .cursorrules, or similar tool file as a one-line redirect to the applicable AGENTS.md and agents/, never a parallel instruction document, and records every root or nested scope. A descendant exclusion suppresses the inherited task-routed identity in that scope; non-conflicting ancestor guidance remains active.
    Criterion: IF a tool-native instruction file is planned, THE PLAN SHALL specify its entire content as a redirect line.

16. R-MEM-16: PLAN.mdx bakes Pillars 1.2.2 conformance into CI from day one: the current validator checks path-derived identities, portable selector collisions, list types and duplicates, hard and soft references, self-references, dependency fan-out, floors, exclusions, optional catalogs, context budgets, and nested scopes; routing fixtures prove deterministic load sets.
    Criterion: WHEN CI is planned, THE PLAN SHALL include the pinned Pillars 1.2.2 validator with recursive-scope discovery and representative routing fixtures, and SHALL fail on any ERROR or fixture mismatch.

17. R-MEM-17: PLAN.mdx defines pillar maintenance as part of the delivery workflow: new decisions land in the owning pillar's Decisions, new hard constraints in Rules, incidents produce Watchouts, resolved Gaps entries are removed, and pillars-verify runs are scheduled after each major refactor or milestone with a target of zero drift, zero rule violations, no stale exclusions.
    Criterion: WHEN phases are laid out, THE PLAN SHALL name the pillar-update step in each phase's Must-haves and SHALL schedule a pillars-verify run in the final Verification phase.

18. R-MEM-18: PLAN.mdx states the executing-agent contract: agents follow the 6-step loading protocol and the 5-state table (present: comply; stub: ask before deciding; excluded: treat as not applicable; absent: infer from code, state the assumption, recommend the pillar; unknown: make no Pillars-specific claim), and pause on a missing non-excluded floor pillar rather than degrading silently.
    Criterion: WHEN the Agent memory section is emitted, THE PLAN SHALL state there that the AGENTS.md protocol is binding for all build tasks; the Rules for executing agents block stays verbatim per plan-format.md and receives no additions.

19. R-MEM-19: PLAN.mdx treats `agents/catalog.yaml` as an optional local index of known absences. Present and excluded identities never appear in it; `context` and `repo` can never be cataloged absent; when the file is missing, unknown concerns remain unknown.
    Criterion: WHEN a known absent concern must remain discoverable THE PLAN SHALL add its identity and deterministic triggers to the local catalog, and WHEN that concern becomes present or excluded THE PLAN SHALL remove the catalog entry in the same task.

20. R-MEM-20: PLAN.mdx resolves applicable scopes from repository root to each target path. Non-conflicting guidance accumulates outer to inner, nearest-scope guidance wins conflicts, and unrelated targets keep separately labeled scope chains.
    Criterion: IF nested scopes exist THE PLAN SHALL name each scope root, its local floor, exclusions, catalog, and override behavior, and SHALL include a fixture proving one inherited rule, one nearest-scope override, and one descendant exclusion.

21. R-MEM-21: PLAN.mdx requires the portable minimum matcher for primary triggers, catalog triggers, and conditional see_also routing: ASCII lowercase, non-alphanumeric runs collapsed to spaces, trim, split, and contiguous complete-token-sequence matching. Semantic matching may only add recall.
    Criterion: WHEN routing fixtures are planned THE PLAN SHALL prove that `schema-change` matches `Schema change` and that `api` does not match `capital`, with identical baseline results across hosts.

22. R-MEM-22: PLAN.mdx applies Pillars context budgets: always-loaded files target at most 1,000 words and 8 KiB each with a 2,000-word and 16-KiB always-loaded scope total; task-routed files target at most 2,000 words and 16 KiB each. Context and repo remain mandatory inside that total. Exceeding a budget is a warning that requires a documented exception.
    Criterion: WHEN pillar validation runs THE PLAN SHALL report budget warnings and SHALL split or trim content unless the plan records why the additional context is load-bearing.

## Task seeds

- [ ] GP-xxx Write AGENTS.md loader at repo root
  - Files: AGENTS.md
  - Acceptance: contains Pillars 1.2.2 reference, 6-step loading protocol, 5-state missing-pillar table, structured excluded: yaml block with {name, reason} entries, and nested-scope precedence when applicable; contains no enumeration of present pillar names
  - Verify: grep -q 'excluded:' AGENTS.md && grep -qi 'always_load' AGENTS.md && test -d agents
  - Requirements: R-MEM-2, R-MEM-3, R-MEM-4

- [ ] GP-xxx Author floor pillars context.md and repo.md at status present
  - Files: agents/context.md, agents/repo.md
  - Acceptance: both files have YAML frontmatter with pillar matching filename, status: present, always_load: true, covers list; both bodies have the 8 headings in order; context.md carries the domain glossary and product invariants from the plan; repo.md carries the planned file layout and naming conventions
  - Verify: grep -q 'always_load: true' agents/context.md && grep -q 'always_load: true' agents/repo.md && grep -q 'status: present' agents/context.md && grep -q 'status: present' agents/repo.md
  - Requirements: R-MEM-5, R-MEM-8, R-MEM-11

- [ ] GP-xxx Author Core pillar set per inventory table
  - Files: agents/stack.md, agents/arch.md, agents/quality.md, agents/development.md, agents/release.md (plus data/api/ui/auth/deploy/observe and applicable Common pillars such as privacy per inventory)
  - Acceptance: all 11 Core and 11 Common identities have one of the five states; every planned-present pillar has full frontmatter and the 8-section body; path-derived sub-pillar identities are used in references; Decisions trace to plan decisions; Watchouts are (none)
  - Verify: grep -L 'triggers:' agents/*.md | grep -v -e context.md -e repo.md | wc -l | grep -q '^ *0$'
  - Requirements: R-MEM-6, R-MEM-7, R-MEM-8, R-MEM-9, R-MEM-10

- [ ] GP-xxx Author primary Tier 3 domain pillar
  - Files: agents/<domain>.md (cli.md, ml.md, seo.md, payments.md, or realtime.md per archetype)
  - Acceptance: frontmatter and 8-section body conform; content covers the concern that defines the product; boundary tiebreakers respected with Touchpoints cross-references instead of duplicated prose
  - Verify: test -f agents/<domain>.md && grep -q 'pillar: <domain>' agents/<domain>.md
  - Requirements: R-MEM-6, R-MEM-8, R-MEM-12

- [ ] GP-xxx Add Pillars structural validation to CI
  - Files: scripts/validate_pillars.py, tests/pillars-routing.yaml, .github/workflows/ci.yml
  - Acceptance: validator pinned from Pillars v1.2.2; CI enables recursive scopes, catalogs, budgets, and routing fixtures; fixtures cover nested inheritance, nearest-scope override, descendant exclusion, schema-change normalization, and api versus capital
  - Verify: python3 scripts/validate_pillars.py --recursive-scopes . && grep -q 'pillars-routing' .github/workflows/ci.yml
  - Requirements: R-MEM-16, R-MEM-20, R-MEM-21, R-MEM-22

- [ ] GP-xxx Maintain the local absent catalog
  - Files: agents/catalog.yaml
  - Acceptance: file is optional; every entry is absent locally with deterministic triggers; no present, excluded, context, or repo identity appears; entries are removed in the task that creates or excludes the concern
  - Verify: python3 scripts/validate_pillars.py --recursive-scopes .
  - Requirements: R-MEM-3, R-MEM-19, R-MEM-21

- [ ] GP-xxx Reduce tool-native instruction files to redirects
  - Files: CLAUDE.md
  - Acceptance: file body is a single redirect line pointing at AGENTS.md and ./agents/; no parallel rules content
  - Verify: test "$(grep -vc '^$' CLAUDE.md)" -le 2 && grep -q 'AGENTS.md' CLAUDE.md
  - Requirements: R-MEM-15

- [ ] GP-xxx Run drift audit in final verification phase
  - Files: none (read-only audit)
  - Acceptance: pillars-verify (or the equivalent prompt) run against the finished tree reports zero drift, zero rule violations, and no code in excluded areas
  - Verify: python3 scripts/validate_pillars.py && git ls-files 'src/components/*' | wc -l | grep -q '^ *0$' # sample stale-exclusion probe when ui is excluded
  - Requirements: R-MEM-14, R-MEM-17

## Self-audit rubric

- Archetype and applicability (15): archetype declared with two or more concrete file signals; all 11 Core and 11 Common identities receive one of the five states without conflating unknown with absent; primary Domain pillar included.
- Loader conformance (15): AGENTS.md task specifies the Pillars 1.2.2 protocol, five states, local exclusions, and nested precedence where applicable, with no present-pillar enumeration.
- Floor pillars (10): context.md and repo.md planned at status: present, always_load: true, authored from the plan's own glossary, invariants, and layout.
- Frontmatter and body format (15): every planned pillar has complete frontmatter (leaf name = filename, path-derived identity, covers, recall-oriented triggers, must_read_with <= 3 resolvable in its scope), 8 sections in order, (none) markers, Touchpoints mirroring.
- Truthfulness discipline (15): Decisions trace to recorded plan rationale, no fabrication; Rules pass earn-your-keep; Watchouts (none) at birth; undecided items in Gaps as ask-the-human entries.
- Drift-proofing (15): every pillar claim is produced by a named build task; boundaries and nested precedence hold; catalog entries leave when concerns become present or excluded; coupling graph stays depth 1 and local to scope.
- Lifecycle and CI (15): exclusion and catalog removals are scheduled with the code; pinned current validator, recursive scopes, budget warnings, and routing fixtures run in CI; maintenance workflow and final verification are named.

## Anti-patterns refused

- Silent pillar absence: a Core or Common concern with no explicit state, or an unknown concern mislabeled absent. Refusal: the plan forces the five-state protocol and uses the optional local catalog only for known absences.
- Fabricated rationale: Decisions or Watchouts invented to fill sections. Refusal: unknown rationale is planned into Gaps as an explicit question; Watchouts start at (none).
- Loader bloat: AGENTS.md enumerating pillars or accumulating rules, growing with the project. Refusal: the plan pins AGENTS.md to the constant-size canonical text, with one conditional nested-scope rule; routing lives in per-file frontmatter.
- Born drifted: the plan's pillar claims describe a stack, path, or convention no build task produces. Refusal: every claim maps to a task's Files or Acceptance line; unmapped claims are cut or converted to Gaps.
- Boundary creep: auth content written into data.md, secrets into auth.md, marketing email into notifications. Refusal: content is reassigned per the tiebreakers and linked via Touchpoints.
- Coupling smell: a pillar with more than 3 must_read_with entries, or several pillars sharing the same hidden dependency. Refusal: restructure the boundary or document the repeated dependency and promote it to always_load only when the total budget still holds.
- Scope flattening: a monorepo package override copied to root or an ancestor rule discarded wholesale. Refusal: compute scope chains outer to inner and apply nearest-scope precedence only to conflicts.
- Leaf-name collision: a sub-pillar referenced by bare leaf name. Refusal: use its path-derived `<parent>/<name>` identity; bare names resolve top-level pillars only.
- Fuzzy-only routing: task selection that differs by model because no portable baseline exists. Refusal: deterministic ASCII token matching and routing fixtures are required; semantic matching may only add recall.
- Context-budget drift: always-loaded prose grows without bound. Refusal: report budget warnings, trim the always-loaded set without dropping the mandatory floor, and document any exception that remains load-bearing.
- Stale exclusion by schedule: a roadmap phase adds code to an excluded area with no exclusion removal planned. Refusal: the exclusion update and pillar authoring task land in the same phase.
- Rules as rails: Rules restating inferable facts, putting the agent on rails instead of preventing drift. Refusal: each Rule must fail the inference test or it is deleted; (none) is the honest default.
- Parallel instruction forks: a hand-built CLAUDE.md or .cursorrules carrying its own rules alongside AGENTS.md. Refusal: tool-native files are planned as one-line redirects; existing ones are reduced, never deleted.
- Guessed archetype: ambiguous detection (dashboard vs marketing site) resolved by assumption. Refusal: the ambiguity becomes a discovery question or a named open question with a recommended default; the exclusion set is never guessed.
