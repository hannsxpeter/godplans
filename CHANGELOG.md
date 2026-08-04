# Changelog

All notable changes to godplans are documented here. The format follows
Keep a Changelog; versioning follows SemVer.

## [1.12.3] - 2026-08-04

A documentation release. No skill, prompt, template, schema, validator, or
plan-format change; PROMPT.md is regenerated only because it carries the version
string.

The published documentation was written for readers who already accept the
premise. README.md opened with two paragraphs of positioning before showing the
command, described the plan format entirely in the abstract, and put the
applicability-matrix paragraph in the first screen. A founder evaluating whether
to spend a build on this could not reach the argument, and the argument is the
product: an audit is a building inspection after the walls are up, and the
inspector hands back a demolition estimate rather than a fix. That claim needs no
technical vocabulary, and nothing on the page made it in under a minute.

Nothing was cut to make room. The dense material moved into `<details>` blocks,
so the maintainer-facing detail is one click away rather than one scroll past the
pitch.

### Added

- `assets/hero.jpg`, a text-free isometric banner: a structure as a blueprint on
  the left, the same structure built on the right. It carries the plan-first
  argument the README opens with instead of decorating it. It lives outside the
  `files` array in package.json, so it does not enter the npm tarball, and the
  README references it by absolute raw URL so it renders on npm as well as on
  GitHub.
- A "Who this is for" table in README.md with a row for founders and product
  leads who do not code, and a FAQ entry answering whether a non-engineer can
  use godplans (they can read, question, and approve the output; running the
  command still needs a coding agent).
- A concrete `GP-101` task block in README.md. The plan format was previously
  described only in prose, so a reader could not tell what a task looks like
  without installing the skill.
- A "What godplans deliberately does not do" section in docs/ABOUT.md, naming
  four limits: it does not build, does not guarantee a clean audit, does not
  replace judgment, and does not run after the fact.
- A "Good first contributions" section and a five-minute orientation table in
  CONTRIBUTING.md, plus a worked example of the substitution test. The rule had
  been stated without an illustration of a passing and a failing sentence.

### Changed

- README.md restructured for a reader who does not yet accept the premise: the
  command appears above the fold, the plan-first argument is made through the
  inspection analogy before any domain vocabulary, and the evidence section
  leads with the head-to-head Critical and High counts as a table with the token
  cost stated immediately after. The complete plan contents, the evaluation
  method, and the repository map moved into `<details>` blocks verbatim.
- docs/ABOUT.md restructured: a one-paragraph summary at the top, the problem
  stated as four before-and-after pairs in a table, the eight-phase method drawn
  as a mermaid diagram rather than listed in a sentence, and every design
  decision given a plain-language summary line above its existing paragraph so
  the section can be skimmed and then entered.
- CONTRIBUTING.md now opens by naming what surprises new contributors: this is a
  prompt-engineering repository with no application to run and no build step.
  The scope refusal explains its reason (godplans that builds is a godplans
  whose plans stop surviving tool switches) rather than only stating the
  boundary.

### Fixed

- docs/ABOUT.md said godplans combines eleven skills. It is fifteen, as
  README.md has recorded since the ADHD lineage row landed, and the same
  paragraph omitted ADHD from the external sources it names.
- CONTRIBUTING.md instructed contributors to bump every version surface for a
  behavior change without naming `npm run version:sync`, which is the only
  supported way to do it; `scripts/version-sync.js` holds the authoritative
  surface list and a hand-edit misses whatever was added to it last.
- SECURITY.md offered `git clone --branch v1.1.0` as the reproducible-install
  example, eleven minor versions stale.

## [1.12.2] - 2026-08-04

A correctness patch on 1.12.0. That release moved cache policy and queue policy
upstream into R-ARCH-23 and R-ARCH-24, and updated database.md to defer to them
by name. It did not update code-quality.md, which had owned both subjects since
before the architecture module reached them. Two modules therefore forced the
same two decisions with different obligations, and the weaker pair won wherever
a plan satisfied it first: R-CODE-16 asked a cache for an invalidation rule
alone, which is one of the four fields R-ARCH-23 requires, so a plan could clear
code quality carrying a cache with no tier, no staleness budget, and no
stampede protection. Its queue clause was satisfied by a depth alone, where
R-ARCH-24 requires a depth bound and a named full policy. Its gate, caching
"only where obviously beneficial", also contradicted R-ARCH-23's arithmetic
gate, which asks whether the latency budget fails without the cache.

Found by an audit of every module against the 1.12.0 change rather than
reported from use. No plan-format, schema, validator, or task-grammar change.

### Fixed

- R-CODE-16 now defers to R-ARCH-23 and R-ARCH-24 by name and keeps only what
  this module owns in code: non-blocking I/O on request and hot paths, and a
  growth bound on every long-lived in-process structure. Its criterion requires
  the four R-ARCH-23 fields on a cached read path rather than an invalidation
  rule alone, and the R-ARCH-24 depth bound and full policy on a queue. This
  restores the module's own convention, already used by R-CODE-15 for index
  details and R-CODE-19 for observability depth, where a requirement names the
  owning module instead of re-deciding.
- The 1.12.0 entry described four new task seeds. Two shipped: the four were
  consolidated into two under the prompt-budget gate, which that same entry
  records twelve bullets later. The Added bullet described the draft rather than
  the release and contradicted its own Changed section.

## [1.12.1] - 2026-08-03

A CI patch. 1.12.0 landed the portable core at 329947 bytes against a
330000-byte gate, 53 bytes of headroom, which meant the next edit of any size
failed the build: a typo fix, a clarifying clause, a single added character.
That is not the gate doing its job. The invariant it was built to hold is that
headroom stays under one core module, so a module-sized addition trips it while
an ordinary edit does not. At 53 bytes it could no longer tell those apart, and
a gate that fires on everything measures nothing. No skill content, module,
validator, schema, or plan-format change; a plan valid under 1.12.0 is valid
here, and PROMPT.md differs only in its version line, at the same 329947 bytes.

### Changed

- The portable-core budget moves from 330000 to 337000, the second deliberate
  raise. 1.12.0 paid the gate's stated price before the number moved: the four
  new requirements were compressed and four task seeds consolidated into two,
  roughly 3 KB cut. 337000 leaves 7053 bytes against a 7070-byte smallest core
  module (compliance.md), so the invariant is restored rather than relaxed. The
  number is derived from that rule, not picked to fit.
- The gate's comment now states the invariant first and the number second,
  records both raises with what each one bought, and tells the next maintainer
  to read module sizes out of `evals/metrics/context-cost.json` via
  `npm run metrics:context` rather than guessing at the third raise.

## [1.12.0] - 2026-08-03

The architecture module planned the structural half of system design well and
the runtime half not at all. It forced system shape, bounded contexts, data
ownership, trust boundaries, integration idempotency, ADRs, and NFR arithmetic,
then stopped: a plan could carry an availability chain requiring 99.97 percent
per component without ever naming redundancy, cache a read path without ever
naming how stale is acceptable, state a throughput ceiling without ever saying
what happens above it, and settle single-writer ownership without ever settling
what a read is allowed to see. The pieces existed downstream as mechanics with
no upstream decision: caching as a stack slot pick and a database invalidation
rule, partitioning and read-your-writes routing as database mechanics, abuse
rate limiting as a security control that is not a capacity control. Four
requirements move those decisions to the pass that already holds the numbers
they depend on. No plan-format, schema, or task-grammar change; a plan valid
under 1.11.1 is valid here, and the validator's ARCH catalog max moves 20 to 24.

### Added

- R-ARCH-21 settles read consistency and horizontal partitioning per entity
  group, because R-ARCH-8 settles writes and leaves reads unstated. Each group
  declares a stance (strong, read-your-writes, bounded staleness with a number
  in seconds, or eventual), names the read paths pinned to the primary, and
  carries single-node capacity arithmetic against the 12-month ceiling already
  recorded under R-ARCH-3. Where the arithmetic fails, the partition key and its
  skew risk are named in the architecture section, because a partition key is a
  data-model decision that shapes every query rather than a database feature
  switched on later. Where it holds, the plan records the number and the
  threshold that would change the answer.
- R-ARCH-22 turns each availability number from R-ARCH-11 into a topology. Per
  critical-path component: the redundancy posture (single instance with an
  annual downtime budget, N instances behind a health-checked routing tier,
  active-passive with a failover time, or multi-zone with the zone-loss behavior
  named), whether request handling is stateless or sticky and where session
  state lives if it is, and the routing tier's health-check and removal rule.
  Remaining single points of failure are listed by name, each accepted with a
  downtime number or removed.
- R-ARCH-23 treats caching as a consistency change rather than a performance
  afterthought. Every cached read path carries a tier, a numeric staleness
  budget, an invalidation trigger, and stampede protection, and names the
  R-ARCH-11 budget it closes, so no cache enters a plan as a reflex. A path
  whose R-ARCH-21 stance is strong or read-your-writes is excluded from the
  cache or routed to the primary, on the record.
- R-ARCH-24 states the overload posture per entry surface, because R-ARCH-9
  covers a failing dependency and leaves a saturating system unstated. Every
  entry surface gets a behavior at and above the throughput ceiling (shed with a
  retryable status and Retry-After, queue with a bounded depth and maximum wait,
  or degrade to a named path), every queue gets a depth bound and a full policy,
  and every limiter is labeled capacity or abuse, because a threshold sized for
  fraud control is not a capacity control and reading it as one hides the
  saturation case entirely.
- Two task seeds carry these to build time: one publishes the capacity model and
  enforces it at every entry surface, with admission control and bounded queues
  (R-ARCH-22, R-ARCH-24); the other pins primary reads and caches only what the
  staleness budget allows, with single-flight protection and a read-your-writes
  test that proves the pinning holds (R-ARCH-21, R-ARCH-23).
- `design.capacity-model` joins the documentation set, owned by architecture,
  selected when an availability or throughput target binds or the plan caches,
  replicates, or partitions.
- Four anti-patterns refused by name: availability theater (an uptime number
  with no redundancy behind it), silent staleness (a cache that changes the
  consistency contract because nobody wrote down the tolerance), the
  infinite-capacity assumption (no stated behavior above the ceiling, so the
  untaken decision becomes unbounded queueing), and the deferred partition key
  (sharding postponed until the access patterns have calcified around one node).

### Changed

- Decisions to force grows from 7 to 11 and stays ordered hardest-to-reverse
  first: read consistency and partition key enter at position 4, next to
  tenancy and storage shape, because a partition key chosen late means re-keying
  live data while every query that assumed one node is rewritten. Runtime
  topology, cache tiering, and overload posture close the list as the more
  reversible bets, each forced anyway because the untaken decision has a bad
  default.
- The self-audit rubric adds a 15-point runtime topology, caching, and overload
  dimension and re-weights the existing eight to keep the total at 100.
  Components and data architecture absorbs the R-ARCH-21 consistency and ceiling
  arithmetic.
- R-ARCH-17 names the database pass as a consumer of the architecture section,
  so replication, partitioning, and read routing are implemented from stances
  already set rather than reopened downstream. R-ARCH-19's three-page prose cap
  excludes the new consistency, topology, cache, and overload tables, so the cap
  stays honest instead of penalizing tabular decisions.
- The post-build drift audit compares redundancy posture, cache staleness
  budgets, and entry-surface overload behavior against the plan, alongside the
  components, data owners, and boundaries it already compared.
- The portable core prompt lands at 329947 bytes against the 330000-byte gate,
  53 bytes of headroom. The budget was not raised. The four requirements were
  written tight and the four task seeds consolidated into two to fit beneath it,
  per the gate's own instruction to cut content rather than move the number a
  second time. The next core addition of any size fires the gate, which is the
  point of it.
- database.md R-DB-15 and R-DB-21 defer upstream by name: cache invalidation and
  stampede policy implement the tier, staleness budget, and trigger set by
  R-ARCH-23, and partitioning and read routing implement the key and stances set
  by R-ARCH-21. Both remain the owner of the physical mechanics; neither reopens
  the decision.

## [1.11.1] - 2026-08-02

A documentation patch. 1.11.0 gated scored archetypes, overlays, and cited
absence claims in the reference modules and the validator, but the README still
described archetype selection as a closest-match step and named neither of the
other two. The packaged README is the first thing a reader sees, so it shipped
describing behavior the release had replaced. No skill content, validator,
schema, or plan-format changes; a plan valid under 1.11.0 is valid here.

### Changed

- README documents scored archetype detection: weighted signals with vetoes, a
  recorded primary and runner-up, the margin between them, and what changes if
  the runner-up is right, priced in tasks and phases. The confidence label is
  recomputed by the validator from those numbers rather than asserted, and below
  the 0.45 floor the archetype is `unknown`, goes to Open Questions, and
  withholds every `assure`-stage document from being marked not-applicable.
- README documents overlays (`ai-system`, `public-ui`, `shipped-artifact`,
  `operated-by-others`, `regulated-data`, `agent-skill-package`) and the rule
  that separates them from archetypes: an archetype says what a project is, an
  overlay says what extra obligations it carries, and an overlay raises a
  domain's disposition without ever lowering it.
- README's brownfield mode names the two evidence rules it was missing: an
  `absent:` exclusion cites the search that came back empty, and a fresh
  `.godaudits/EVIDENCE.json` may be reused as `[recheck]` provenance while a
  stale one is refused, because a stale inventory reads exactly like a fresh
  one. godplans neither requires nor calls godaudits.

## [1.11.0] - 2026-08-02

This release ports two disciplines from sibling projects. From hannsxpeter/docdna,
the selection engine that decides which documents a repository owes and defends
every absence: plans now carry a documentation set, and every exclusion, of a
domain or a document, records the evidence state that licensed it and the
predicate that reverses it. From hannsxpeter/codedna, whose style fingerprinting
already backed the style-genome module: the AI-tells catalog and the measurement
script now ship rather than being cited. Both are ported by copy. godplans
depends on nothing from either repository at runtime, and neither depends on
godplans; fixes travel as edits, never as references.

Plans emitted by 1.10.0 do not validate under 1.11.0 without the new sections.
Add `## Documentation set`, add `### Module disposition` under the applicability
matrix, and give every excluded matrix row an evidence state and a tripwire.

### Added

- `references/doc-set.md`, the documentation-set contract: a 42-row catalog
  keyed by lifecycle stage, the durability split that keeps evidence artifacts
  from being edited in place, the verdict-by-state lattice that names `adopt`
  and `orphan` as real brownfield results, lifecycle frontmatter, the four
  independent staleness verdicts, and the system-of-record boundary.
- `## Documentation set` as a required plan section, with R-REPO-21 rewritten
  and R-REPO-22 through R-REPO-25 added for tripwires on excluded rows, single
  ownership per document, lifecycle frontmatter on every planned document, and
  the repository-boundary statement. The validator checks catalog ids, stages,
  verdicts, owners, task references, and exclusion grammar.
- Exclusion tripwires on the applicability matrix. An excluded row now carries
  an evidence state (`absent:` or `by-design:`), a project-specific reason, and
  a `revisit when:` predicate held to the same observability bar as a deferral
  trigger. `unknown:` and `hint:` are refused, because neither licenses an
  exclusion: they make the domain applicable or become an open question.
- `### Module disposition` as a machine-checked block. Each applicable module
  reports what it landed and what it dropped, and `dropped-by` names the layer
  that dropped it (`scale`, `archetype`, or `form`). A dropped requirement may
  not appear on any task, a landed one must be referenced somewhere, and the
  two sets may not overlap. Without the layer name, a requirement cut to fit an
  appetite is indistinguishable from one nobody considered.
- The blast-radius rule on the assumptions ledger. Every assumption is priced
  in tasks and phases, so "answer defaults" is an informed choice.
- `scripts/style-stats.py`, vendored from codedna, plus R-DNA-21 through
  R-DNA-24: measured naming histograms, comment density, and function-length
  medians instead of eyeballed numbers; a config map that makes R-DNA-1
  checkable; the 15-item AI-tells catalog carried in full so the anti-tells
  appendix selects from it; and an enforcement loop with an executable Verify
  command rather than an instruction no command can fail.
- R-OBS-22 and the plan-format claims-and-evidence contract: no invented
  availability targets, recovery objectives, retention periods, error budgets,
  or review cadences, and exhaustive or negative claims about existing code
  need a command rather than a file citation.
- Scored archetype detection with vetoes, replacing the closest-match table. A
  plan records primary and runner-up scores, a margin, the vetoes applied, and
  what changes if the runner-up is right, priced in tasks and phases. Margin and
  confidence are recomputed by the validator from those scores, so a confident
  label that does not follow from the plan's own arithmetic fails. Below the
  0.45 floor the archetype is `unknown`, goes to Open Questions, and withholds
  every `assure`-stage documentation row from being marked not-applicable,
  because a misread archetype deletes threat models silently.
- Overlays (`ai-system`, `public-ui`, `shipped-artifact`, `operated-by-others`,
  `regulated-data`, `agent-skill-package`) as an additive frontmatter list. An
  archetype says what a project is; an overlay says what extra obligations it
  carries. Overlays raise and never lower: a domain an overlay covers may be
  applicable or deferred, never excluded.
- A brownfield or replan `absent:` exclusion must carry a backticked command or
  evidence artifact. It is a negative claim about existing code, and the
  claims-and-evidence rule already refuses those without a search.
- Optional reuse of `.godaudits/EVIDENCE.json` when it is fresh for the revision
  being planned, cited as `[recheck]` provenance. godplans neither requires nor
  calls godaudits; a stale inventory is refused because it reads like a fresh one.
- `archetype_confidence`, `overlays`, `evidence_state`, `revisit_when`,
  `module_disposition`, and `documentation` in the generated PLAN.json sidecar,
  with matching schema entries.

### Changed

- Load-bearing domains (security, code-quality, style-genome, repo, roadmap)
  can no longer be excluded by the validator, only scaled down. The rule was
  already stated in `discovery.md`; now it is gated.
- ADR ownership is settled. `decide.adr` belongs to the architecture module
  (R-ARCH-14), which also fixes ADR immutability, and R-REPO-14 defers to it
  instead of adding a second ADR task at tier 4.
- Replan leads with tripwires that have become true, and reports drift as leads
  rather than findings: a moved digest establishes that something changed and
  never why, and presenting a rename and a regression as one verdict trains the
  reader to skip the section.
- The repo rubric adds a documentation-set dimension worth 15, and scores zero
  on it when any exclusion is unexplained. The style-genome rubric adds a
  measured-evidence dimension worth 10.
- The portable-core byte budget moves from 300000 to 330000, once and on the
  record. This release adds the archetype and overlay contract, the
  documentation-set grammar, and about 25 KB of machine checks the core inlines
  whole. The core now measures 320783 bytes, so the new ceiling leaves under
  9 KB of headroom, less than any single core module: the next addition of this
  size fires the gate rather than sliding past it.

## [1.10.0] - 2026-07-31

This release applies one discipline borrowed from mattpocock/skills wayfinder:
a fact lives in exactly one place, and the edge of what is safe to work on is
proved rather than asserted. Three places where godplans stated a rule but did
not gate it are now gated. No new plan sections, no new domains, and no change
to the scale ceilings.

### Fixed

- The validator accepted a plan whose `domains_applicable`, `domains_deferred`,
  and `domains_excluded` frontmatter flatly contradicted its own applicability
  matrix. A plan declaring `security` and `database` excluded while the matrix
  marked both applicable validated `ok` and exited 0, so the never-excluded-set
  check (which reads only the matrix) could be bypassed by the summary that was
  supposed to index it. The three lists are now recomputed from the matrix rows
  and any disagreement fails, the same parity already enforced between the
  `## Plan provenance` block and its frontmatter values.
- The frontmatter form documented in `references/plan-format.md` could not
  validate. The block-mapping shape for `domains_deferred` and
  `domains_excluded` (`- name:` / `trigger:` / `reason:`) failed with
  `frontmatter field is empty: domains_deferred`. The documentation now shows
  the single inline list every emitted plan actually uses, and the trigger and
  reversibility reason live only in the matrix row that decides them.
- `[P]` promised an executor that a task was safe to run beside its wave
  siblings, and nothing checked it. Two `[P]` tasks in one wave writing the
  same file validated `ok` and exited 0, despite the task grammar, R-ROAD-8,
  and the fictional-parallelism refusal all forbidding it. A `[P]` task whose
  Files list intersects another unchecked task in its wave now fails.
- `references/plan-format.md` told replans to cut completed phases into
  `.godplans/archive/PLAN-v<n>.mdx` while R-ROAD-18 requires completed phases to
  be archived in place and never overwritten. Cutting them out would delete the
  execution history the drift check and the supersession metric read. The
  archive path now holds whole superseded plan versions, and the live plan keeps
  its finished phases.
- The validator's own golden fixture declared two applicable domains while its
  matrix marked ten applicable and eight excluded. It passed because nothing
  compared them; it is now consistent and the new parity check covers it.

### Added

- A question grammar in `references/plan-format.md` and the PLAN template that
  carries the four fields R-PRD-10 already required and the format contract did
  not state: owner, blocking flag, decide-by, and recommended default. The
  contract also now says plainly that `## Open Questions` holds the residual
  unknowns a plan can execute past on a default, and that an unknown dependent
  work cannot start without is a flagged hypothesis whose R-ROAD-7 validation
  task carries a real `Depends on` edge.
- `parallel` on every task in the generated PLAN.json, so a runner can schedule
  a wave from the validated marker instead of re-deriving which tasks are safe
  to run at once. It is a required property in `schemas/PLAN.schema.json`;
  consumers pinned to the previous schema must regenerate their sidecar.
- Seven validator regression checks covering frontmatter-matrix drift in both
  directions, an invented deferral, an unknown domain name, the rejected
  block-mapping form, a `[P]` file collision, and a passing disjoint `[P]` pair.
- A presentation rule in Phase 7: name tasks, decisions, and questions by title
  with the ID in support. IDs are how the machine addresses the plan; a wall of
  them is how a human loses it.
- A disposition for an empty hard-to-reverse-bets list in `references/discovery.md`.
  Empty is a finding that each of the four bet categories was examined and
  located, not permission to skip the pass.

### Changed

- Lineage credits mattpocock/skills wayfinder for the two ideas taken: one fact
  in one place, and a frontier that is proved rather than asserted. No text,
  prompt, or code was copied, and godplans takes none of its issue-tracker map,
  ticket types, or session protocol.

## [1.9.0] - 2026-07-23

This release turns the evidence critique into product contracts and publishes
the first direct build-outcome result. The harnesses run through already
authenticated host tools; the skill and evaluation coordinator require no
provider credentials.

### Fixed

- The control arm (`scripts/eval.sh --baseline`, introduced in 1.8.0) was
  contaminated. It withheld the project-local skill but not the global one, so
  on a machine with godplans installed the control loaded the skill anyway and
  measured godplans against itself. Both Codex runners now isolate `HOME` and
  `CODEX_HOME`, so no globally installed skill leaks into either arm.
- The control was also handed the skill-phrased `REQUEST.md` ("Use godplans...
  produce the godplans artifact set"), which told a skill-less agent to use a
  tool it did not have; in practice it spent its turn searching for the format
  and wrote nothing. Each case now ships a de-branded `REQUEST.baseline.md`
  that the control runs instead, and `--check-cases` plus the harness
  regression reject a baseline request that leaks the skill.

### Added

- `evals/baselines/2026-07-22-gpt-5.6-sol-xhigh.md`: the first fair baseline.
  `gpt-5.6-sol` at xhigh across a three-case subset, skill 35/35, unaided
  control 12/35, delta +23, with the honest per-case breakdown.
- A full-matrix runner for all ten cases across three host-model profiles,
  including Codex, Claude, and Gemini adapters, with matched no-skill controls,
  raw artifact retention, CLI event logs, and actual token usage per plan. The
  adapters reuse normal host CLI authentication. The historical three-case
  baseline is retained but no longer meets the publication minimum.
- A blind external grading harness with six vendor-neutral criteria, at least
  five plan pairs, at least two isolated no-skill judges, arm unblinding only
  after grading, and a published mean absolute inter-rater gap.
- A build-outcome evaluation that gives treatment and control plans to the same
  fresh no-skill builder, removes plan and arm identity, runs the same static
  godaudits pass on both built repositories, and compares verifier status plus
  open Critical and High findings.
- The first retained build-outcome run, using `gpt-5.6-sol` on
  `tenant-notes-api`. Both arms passed the verifier. Treatment had 0 Critical
  and 1 High finding; control had 1 Critical and 4 High findings, for a -4
  Critical plus High delta. The same evidence publishes the cost:
  11,236,025 cumulative treatment planning tokens versus 162,816 for control,
  including cached input.
- Generated `.godplans/PLAN.json` sidecars with a PLAN.mdx content digest,
  applicability rows, structured decision falsifiers, active and superseded
  tasks, dependencies, requirement arrays, and cumulative supersession metrics.
- `scripts/plan-halflife.sh`, which publishes overall and per-domain task
  survival and supersession rates before a replan changes the evidence.
- `--drift-check N` on the portable validator. At each phase boundary it
  recomputes marked provenance files, reruns a deterministic sample of up to
  three completed task Verify commands, and reruns the phase checkpoint.

### Changed

- Planning depth is incremental. SEO, launch, observability, UI, and deployment
  may defer only with an observable trigger and a reversibility argument.
  Product shape, architecture, stack, data, security, UX, code quality, style,
  agent memory, repository, build, and roadmap never defer.
- Every `D<n>` decision now has a machine-checked falsifier block with Signal,
  Failure boundary, and Replan action fields. The action must explicitly return
  the plan to planning.
- `PROMPT.md` is a measured slim core containing discovery, plan format, five
  load-bearing modules, the exemplar, template, validator, and half-life script.
  Other domain modules stay lazy. `evals/metrics/context-cost.json` publishes
  core, generated-full, native-entry, and per-module byte and token estimates.

## [1.8.0] - 2026-07-22

Two defects fixed and one measurement gap closed, all prompted by reading
UditAkhourii/adhd (MIT), whose thesis is that mixing the generator and the
critic destroys output quality and that a menu of options is not a set of
alternatives. The technique is re-expressed here for planning; no ADHD text,
prompt, or code is copied, and nothing in this release adds a dependency,
a network call, or a harness-specific primitive.

### Changed

- **Phase 6 is now an independent audit gate, not a self-audit.** The author
  graded the author, and worse: ground rule 8 makes the author read the
  module (including its rubric) before authoring, so the generator saw the
  grading key. Phase 6 now splits into 6a score, 6b name every deduction, and
  6c revise and rescore. Scoring runs under critic posture in a separate turn,
  and in an isolated context where the harness offers one, given only the
  drafted plan and the rubric text. Each deduction must cite the section,
  quote the sentence that lost the points, and name the rubric line; a
  deduction with no quoted text is not a deduction. Every revision quotes the
  deduction it answers, and a rescore with no corresponding revision is
  discarded. The scorecard now records whether the critic ran isolated.
- **R-ARCH-4 admits an eighth system shape.** The requirement demanded exactly
  one of seven listed shapes, so a genuinely apt shape outside the list did
  not merely lose, it failed a requirement. The seven remain the presumptive
  set; an eighth is permitted only when the plan names the constraint no
  listed shape satisfies and carries the same flip point and blast radius.
- **Open Questions must escape their own framing.** When every listed option
  is a variant of one framing, the question now names the option from outside
  that framing or states which constraint eliminated it. Options that only
  vary a dial are a menu, not alternatives. `references/exemplar.md` shows the
  worked form, including one genuinely off-framing option and why it lost.

### Added

- **R-STACK-21 (named runner-up beyond the starting set).** The pre-combined
  bundles in Decisions to force are a starting set, not a ceiling. The plan
  names one viable alternative that was generated rather than selected from
  that set, with the single condition under which it would have won, or states
  that generation produced none and names the constraint that eliminated them.
  This records the alternative without promoting it: the incumbent bias in
  R-STACK-7 and R-STACK-12 is deliberate and stands. Scored inside the
  existing Candidate coverage dimension, so the stack rubric still totals 100.
- **A control arm for the evaluation harness (`scripts/eval.sh --baseline`).**
  Every case previously scored godplans against godplans' own expectations, so
  the matrix could prove conformance but never that the skill beats the same
  agent unaided. `--baseline` runs each case a second time through
  `GODPLANS_EVAL_BASELINE_RUNNER` with no skill loaded, scores it against the
  identical expectations, and reports a per-case and aggregate delta. The
  control arm is a measurement, never a gate: its misses cannot change the
  exit code and are not reported as failures.
- **`evals/runners/codex-baseline.sh`**, a deliberately fair control: same
  agent, model, reasoning effort, workspace, fixture, and request; a plain ask
  for a thorough plan so it has a real chance at every scored dimension; no
  skill link and no leaked format contract, requirement IDs, validator, or
  phase method; and a plan accepted at any plausible path. A control denied a
  fair attempt measures the rigging, not the skill.
- Harness regression tests covering the control arm: both misuse guards
  (missing baseline runner, and a control that is the skill runner), artifact
  retention, delta and aggregate reporting, and the invariant that control
  misses never surface as skill-arm misses or change the exit code.
- `evals/cases/greenfield-saas` asserts the stack domain is applicable and
  that R-STACK-21 lands.
- `evals/README.md` documents the control arm, its fairness rules, and two
  limits now stated rather than hidden: single-sample cases carry no variance,
  and one shipped runner cannot separate godplans' contribution from Codex's.

## [1.7.0] - 2026-07-16

### Added

- R-ARCH-20 (API contract), the plan-side mirror of godaudits A-ARCH-23 and
  A-SEC-33. When the system exposes an API or service surface, PLAN.mdx settles
  the API style (REST, GraphQL, or RPC), a consumer-safe versioning strategy, the
  machine-readable contract (an OpenAPI document or a GraphQL schema), a single
  error envelope (RFC 7807 Problem Details or a documented equivalent), and the
  interaction-safety postures: an idempotency key on retryable unsafe operations
  and connection authentication plus resource bounds on any real-time (WebSocket
  or SSE) surface. The architecture module's `%catalog_max` was regenerated from
  the reference (ARCH 19 to 20) with no hand-edit to the validator.

## [1.6.0] - 2026-07-16

### Changed

- Derive-not-duplicate refactor. The validator's `%catalog_max` block is now
  generated from the reference modules by `npm run catalog` instead of being
  hand-maintained, and `catalog:check` (gated in `npm run check`) verifies it,
  adding a requirement no longer desyncs the validator. The out-of-range
  regression fixture computes `max+1` from the catalog instead of hard-coding an
  id, so it never breaks on growth.

### Added

- `npm run version:sync` writes the single source of version truth (package.json)
  into every version surface and regenerates the prompt; `version:check` verifies
  and prints the fix command (gated in `check`). `npm run release:prepare --
  <bump>` bumps, syncs, and stubs a CHANGELOG entry in one command. This release
  was cut with release:prepare.

## [1.5.0] - 2026-07-16

### Added

- R-REPO-21: the plan derives a documentation manifest from its applicability
  matrix, product form, scale, and risk or regulatory profile, tagging each
  document required, recommended, or not-applicable with the signal that set it,
  and names the governance documents (initiation brief with charter, business
  case, and stakeholders/RACI; requirements-traceability matrix; closeout with
  lessons) required at funded-product-with-regulated-data or enterprise scale.
  Documentation is scaled to the project, not a fixed checklist.

## [1.4.0] - 2026-07-16

### Added

- Compliance plan-time requirements:
  - R-SEC-29: consent and regulated-data governance (consent/lawful-basis before
    non-essential trackers with a server-honored opt-out; ROPA, DPA/BAA,
    transfer basis, and regulated-data scope as plan artifacts).
  - R-SEC-30: applicable compliance frameworks identified by where users live and
    what data is handled (GDPR/CCPA/PIPEDA, WCAG 2.2 AA/AODA/Section 508, SOC 2/
    ISO 27001, PCI DSS/HIPAA), mapped to the controls that evidence each and
    framed as technical-readiness, not certification.
  - R-UI-21: WCAG 2.2 AA pointer target size (2.5.8) and focus appearance (2.4.11)
    with a named conformance target.
  - R-CODE-24: behavioral requirements (concurrency, gating flags, state
    transitions, non-primary caller paths, runtime consent/accessibility) verified
    against the running app by an end-to-end or browser harness, not only unit
    tests or static greps.

## [1.3.0] - 2026-07-16

### Added

- Behavioral plan-time requirements that force controls to be wired, not merely
  present, closing gaps a control-presence audit misses:
  - R-SEC-27: authorization parity across every caller path to a privileged
    operation (interactive session, API key or token, publicly exported
    function, action-in-query-context, agent or tool call), with suspension and
    step-up enforced at the data or function tier, not only at a page gate.
  - R-SEC-28: caller-supplied selectors (id, email, slug, hostname, model
    output) are ownership-bound to the authenticated principal before use, with
    proof-of-control required for email and hostname; public checkout,
    unauthenticated verification, and agent or tool arguments named as the
    highest-risk cases.
  - R-DB-23: money flows reconcile end to end across charge, invoice,
    settlement, refund, and payout or transfer, with provider status confirmed
    before a record is marked final and transfers reversed on refund.
  - R-CODE-23: control flags meant to gate behavior are read on the enforcement
    path, lifecycle transitions never release a still-committed resource early
    or out of order, and scheduling uses the entity timezone rather than UTC.
- Two security anti-patterns refused at plan time: primary-path-only
  authorization and the trusted-selector confused deputy.

## [1.2.0] - 2026-07-13

### Added

- Product-form routing before archetype and domain composition, with distinct
  vertical slices, build concerns, and completion evidence for web, API or
  service, CLI or SDK, mobile or desktop, data or ML, and infrastructure or
  IaC plans.
- Plan provenance fields for source revision, SHA-256 input digest, and UTC
  validation time, plus resume rules that return materially stale completed or
  imported evidence to planning.
- Conditional public-release gates bound to current hardening evidence, with
  complete, expiring Critical-risk acceptance records and invalidation after
  any later hardening change.
- Pinned official Agent Skills validation, a release-check entry point,
  immutable GitHub Action pin enforcement, and tag-to-release version parity.
- Behavioral cases and blocking gate invariants for product forms, Pillars 1.1
  nested scopes, stale source and prepublication evidence, and observability
  evidence labels.

### Changed

- Agent-memory planning now targets Pillars 1.1.0: 11 Core and 11 Common
  concerns, five evidence states, optional local absent catalogs, path-derived
  sub-pillar identities, deterministic ASCII token routing, nested-scope
  precedence, context budgets, recursive validation, and routing fixtures.
- Observability plans now separate `installation-ready` controlled-fire
  evidence from `operationally-mature` real-event evidence and forbid treating
  synthetic signals as incident history.
- The portable validator now checks provenance, product form, and conditional
  public-release gate structure while retaining Bash 3.2 and stock Perl
  portability on macOS and Linux.

## [1.1.0] - 2026-07-13

### Added

- A self-contained PLAN.mdx validator that checks lifecycle state, derived
  counters, phase and task grammar, ordered dependency and requirement
  references, banned characters, Open Questions uniqueness, and the final
  Verification phase.
- An explicit `planning -> approved -> executing -> done` lifecycle with an
  execution gate and fresh approval after a material replan.
- A behavioral evaluation matrix for greenfield, brownfield, replan,
  scale-calibration, and compliance-refusal behavior, plus a real Codex runner.
- Saved-artifact rescoring for behavioral evaluations without another model
  call, while preserving complete-artifact validation.
- Regression suites for installer ownership, validator failures, portable
  prompt completeness, linter non-mutation, and evaluation harness behavior.

### Changed

- PROMPT.md now includes the orchestrator, every reference module, the quality
  exemplar, the validator, and the PLAN template as a full-fidelity fallback.
- Product language now describes audit-aware prevention and independent final
  verification instead of promising an audit-clean first run.
- Version parity, JSON parsing, shell syntax, product surfaces, and evaluation
  case integrity are enforced by the repository linter and CI.
- Weekend calibration now enforces an 8-task, 3-phase ceiling and requires
  task appetites to fit the stated capacity.
- Repository and lineage links now use the hannsxpeter GitHub location.

### Fixed

- `install.sh` no longer overwrites or uninstalls unowned destinations, maps
  user-facing tool aliases correctly, and rejects unknown or no-op targets.
- Plan validation no longer relies on non-enforcing grep pipelines or the
  unsupported macOS `grep -P` flag.
- Local requirement references now resolve from either colon-form definitions
  or the first column of a Markdown requirements table.
- The emission gate now refuses a PLAN handoff without its executable,
  byte-identical validator companion.
- Plan evaluation fixtures no longer contradict the companion contract, and
  semantic wording checks tolerate capitalization differences.
- Portable prompt generation no longer leaves required local references
  unavailable to plain chat surfaces.

## [1.0.0] - 2026-07-02

Initial release.

### Added

- The godplans Agent Skill: one command that runs discovery, forces every
  hard-to-reverse decision, and emits a complete, agent-executable master
  plan at `.godplans/PLAN.mdx` before any code is written.
- 18 domain reference modules descending from aihxp arc-ready and
  ready-suite (product, architecture, roadmap, stack, repo, build, deploy,
  observe, launch), the seven hannsxpeter auditors inverted into plan-time
  requirements (security from secauditor and harden-ready, code-quality
  from codeauditor, database from dbauditor, llm from llmauditor, seo from
  seoauditor, ui from uiauditor, ux from uxauditor), hannsxpeter/pillars
  (agent-memory), and hannsxpeter/codedna (style-genome).
- Four core modules: plan-format (the PLAN.mdx contract), discovery
  (intake, archetype, applicability matrix, interview), compliance
  (Anthropic Usage Policy gate and account safety), exemplar (the quality
  bar, worked).
- PLAN.mdx template with GFM-safe MDX body, GP-numbered checkbox tasks,
  waves, must-haves, executor rules, and a session log.
- Cross-tool packaging: canonical skill under `skills/godplans/`,
  `.agents/skills` and `.claude/skills` projections, `install.sh` with a
  six-destination matrix, generated `PROMPT.md` fallback for T3 Chat,
  Aider, and plain chat surfaces.
- Meta-linter (`scripts/lint.sh`) enforcing unicode cleanliness, version
  parity, spec-bound description length, module contract completeness,
  and PROMPT.md freshness; wired into CI with an installer smoke test.
