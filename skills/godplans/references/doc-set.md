# Documentation set contract

The binding contract for `## Documentation set`, the plan section that decides which documents this project owes, names which it does not owe and on what evidence, and puts an expiry tripwire on every one of those exclusions. Read this file when authoring that section (the repo module's R-REPO-21 through R-REPO-25 instantiate it) and when a replan re-derives the set. This is a contract file, not a domain module: it has no rubric of its own, because the repo module scores it.

## Lineage

Descends from docdna (hannsxpeter/docdna), the selection engine that decides which documents a repository owes, defends every absence, and writes only what the code can prove. docdna works after the fact: it scans a repository, derives signals from files, and selects from evidence on disk. godplans inverts the direction. At plan time there is no code to scan, so the selecting inputs are the plan itself: product form, archetype, scale calibration, `public_release`, the applicability matrix, the security and compliance profile, and, in brownfield mode, the Phase 0 fingerprint. The disciplines that carry over intact: lifecycle stage as the primary axis and the refusal to tier by audience; three-valued evidence where absence of a look is never recorded as absence of a thing; every selection naming what selected it; every exclusion carrying a reason and a `revisit when` predicate; the durability split that keeps evidence artifacts from being edited in place; and the rule that no number is invented.

Ported by copy. godplans depends on nothing from docdna at runtime, and docdna depends on nothing from godplans. Fixes travel between the two repositories as edits, never as references.

## 1. The failure this section exists to prevent

The failure mode of a documentation plan is not a missing document. A missing document is visible and arguable. The failure is **asserting that a document was unnecessary without ever deciding it was**, because an unexamined absence reads exactly like a considered decision, and only one of those survives a handover, an audit, or the maintainer leaving.

So the section is not a list of documents to write. It is a decision record with three parts: what this project owes, what it does not owe and why, and what would make that second answer wrong.

## 2. Lifecycle stage is the organizing axis

Ten stages. A document belongs to the stage at which it first becomes load-bearing, not the stage in which it is most often read. Each stage answers exactly one question; a stage needing two questions is two stages.

| Stage | The one question it answers |
|---|---|
| `frame` | Why does this exist, for whom, and what counts as success? |
| `decide` | What did we choose, and what did we reject? |
| `design` | What shape is it, and why that shape? |
| `build` | How do I work on it? |
| `verify` | How do we know it works? |
| `assure` | How do we prove to an outsider it is safe, lawful, and accessible? |
| `operate` | How do we run it and keep it alive? |
| `serve` | How does someone use it? |
| `govern` | How is the work itself managed? |
| `retire` | How does it end? |

The list is an ordering of first authorship, not a waterfall and not a maturity ladder. A brownfield project will own `build` and `operate` documents years before anything in `frame` exists, and that is the normal shape of a real repository. The manifest reports the set and orders it by consequence; it never scolds the user for the shape of their history.

## 3. Audience is not the axis

The obvious partition is by reader: an executive set, an engineering set, an operations set, a compliance set. Reject it. ISO/IEC/IEEE 42010:2022 settles the question: audience is stakeholder plus concern, the set is partitioned by viewpoint, and cross-audience consistency is a correspondence rule rather than a parallel tree. The architecture a director reads and the architecture an engineer reads are the same artifact at two zoom levels.

Tiering by reader guarantees N parallel document sets describing one system, and they drift inside a quarter. After that, the only interesting question, which of these is true, has no answer, because each set was written for a reader instead of from a system.

Every row still carries an audience so a projection is possible the day somebody asks for one. Planning a projection nobody asked for is the theater this section exists to prevent.

## 4. Durability, and why it has three values

| Value | Update contract | Plan posture |
|---|---|---|
| `durable` | Edited in place. The task that changes the code updates it in the same task. | Plan a task that writes it. |
| `evidence` | **Never edited.** A new run produces a new dated file. | Plan the task that produces a run, and the index that lists runs. Never a task that edits one. |
| `transient` | Written once, dated, abandoned. | Never planned as a deliverable. It is a byproduct of a decision, and the decision belongs in `## Decisions`. |

Collapsing `evidence` into `durable` is the failure this split prevents. A dependency inventory, an operational readiness review, a post-mortem, a scan result: each is a snapshot of a moment, and editing one in place destroys the only property that makes it evidence, which is that it says what was true on a date. Collapsing `evidence` into `transient` is the other half, because an evidence artifact carries a retention period that is a contractual or legal fact rather than a preference.

**Immutability is derived, not a fourth value.** Every `evidence` row is immutable, and so is `decide.adr` despite being durable. An immutable document is superseded, never rewritten: mint a new id, set `supersedes` on the new file and `superseded_by` plus `status: superseded` on the old, and leave the old file where it is. Numbers are never reused, because a citation written last year has to keep resolving to the same decision.

## 5. The catalog

Every row carries the module that owns it. **A document has exactly one owner module**, so two passes never both plan the same file. Where a row's natural owner is not the repo module, repo defers to the named owner and plans the manifest row only.

`Selected by` states the plan fact that makes the row required. `always` means every project owes it at every scale.

### frame

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `frame.objective` | durable | product | always (lives in PLAN.mdx, not a separate file) |
| `frame.business-case` | durable | product | scale is funded-product or enterprise |
| `frame.glossary` | durable | style-genome | always (R-DNA-12 domain glossary) |
| `frame.stakeholders` | durable | repo | an external authorizer exists, or scale is enterprise |

### decide

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `decide.adr` | durable | architecture | always (R-ARCH-14; repo defers). Immutable by section 4: superseded, never edited |
| `decide.design-proposal` | transient | architecture | two options survive the pass and the debate is worth keeping |

Never emit a folder named `rfc/`. In any shop with an ITSM process, RFC reads as Request for Change and the collision is expensive. The debate artifact is a design proposal.

### design

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `design.data-model` | durable | database | database is applicable |
| `design.api-contract` | durable | architecture | a public or cross-team interface exists |
| `design.ui-spec` | durable | ui | ui is applicable |
| `design.integration-map` | durable | architecture | a third-party dependency carries a failure mode |

### build

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `build.readme` | durable | repo | always (R-REPO-7) |
| `build.contributing` | durable | repo | tier 2 or above (R-REPO-8) |
| `build.dev-setup` | durable | build | always |
| `build.codebase-map` | durable | agent-memory | always (the repo pillar) |
| `build.config-reference` | durable | stack | the project reads configuration or environment variables |
| `build.api-reference` | durable | build | a public API surface exists |
| `build.feature-flags` | durable | build | the plan introduces a flag system |
| `build.style-genome` | durable | style-genome | always (R-DNA-14 CODEDNA.md) |
| `build.agent-memory` | durable | agent-memory | always (R-MEM-2 AGENTS.md and pillars) |
| `build.llms-txt` | durable | seo | a public documentation surface exists |

### verify

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `verify.dod` | durable | product | always |
| `verify.test-strategy` | durable | code-quality | always |
| `verify.traceability` | durable | roadmap | an external authorizer exists, or scale is enterprise |

### assure

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `assure.threat-model` | durable | security | an auth boundary, personal data, or a public surface exists |
| `assure.privacy-record` | durable | security | the system stores or processes personal data |
| `assure.dependency-inventory` | evidence | repo | `public_release` is true, or scale is enterprise |
| `assure.scanning-index` | evidence | repo | security automation runs in CI |
| `assure.accessibility-inputs` | evidence | ui | a public UI plus a stated accessibility obligation |

`assure` rows produce the inputs an assessor needs and name who must sign, empty. godplans does not certify, attest, sign, or draft a regulator-facing instrument, and it does not assert that a regime applies. It names the signal, names the regime that signal might trigger, and says to confirm with counsel. A dependency inventory is generated by a real resolver named in the task; a hand-written dependency list is a lie with a filename.

### operate

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `operate.runbook` | durable | observe | a deployed surface exists |
| `operate.slo` | durable | observe | observe is applicable at side-project scale or above |
| `operate.oncall` | durable | observe | somebody can be paged |
| `operate.recovery` | durable | deploy | the system holds durable user data |
| `operate.postmortem` | evidence | observe | an on-call rotation exists |
| `operate.readiness-review` | evidence | deploy | scale is enterprise |

### serve

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `serve.user-guide` | durable | launch | external users exist |
| `serve.support-policy` | durable | launch | paying users exist |

### govern

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `govern.manifest` | durable | repo | always (this section, rendered into the repo) |
| `govern.ownership` | durable | repo | more than one maintainer, or the repository is public |
| `govern.security-policy` | durable | repo | tier 2 or above (R-REPO-8 SECURITY.md) |
| `govern.changelog` | durable | repo | tier 2 or above (R-REPO-8) |
| `govern.closeout` | durable | roadmap | scale is enterprise |

### retire

| Document | Durability | Owner module | Selected by |
|---|---|---|---|
| `retire.archive-manifest` | evidence | roadmap | a stated sunset date or a data-retention obligation |

## 6. Verdict times state equals action

The verdict describes need. The state describes what exists. The action is a lookup, not a judgment. Greenfield plans are `absent` in every row and only use the first column; brownfield and replan use the whole table.

| | absent | present-current | present-drifted | present-stub | present-elsewhere |
|---|---|---|---|---|---|
| **required** | `plan-task` | `adopt` | `refresh-task` | `complete-task` | `confirm` |
| **recommended** | `offer` | `adopt` | `refresh-task` | `complete-task` | `confirm` |
| **optional** | `note` | `adopt` | `note` | `note` | `note` |
| **not-applicable** | `skip` | `orphan` | `orphan` | `orphan` | `skip` |

- `adopt` is the cheap win and the most common brownfield result. The document is fine and only lacks lifecycle metadata. Adopting costs a frontmatter block, not a task.
- `orphan` is a real result rather than an error: a document the repository carries that nothing in the profile justifies. That is where documentation rot starts, and nothing else reports it. An orphan gets one line and a question, never a deletion task; deleting is a records decision.
- `confirm` exists because documentation often lives somewhere this plan cannot see. See section 8.

## 7. Three-valued evidence, and the states that may justify an exclusion

A row's exclusion is a claim about the world, so it carries the state of the evidence behind it.

| State | What the plan is saying | May it exclude a row? |
|---|---|---|
| `present` | this project has the thing | no, it selects the row |
| `absent` | this was checked and the thing is not there | yes |
| `by-design` | the plan decides this project will not have the thing | yes |
| `unknown` | nobody looked, or the answer is not derivable here | **no** |
| `hint` | something matched and it is not enough | **no** |

`unknown` is not `absent`, and conflating the two is the whole point. In greenfield the honest state for anything the plan decides is `by-design`, because there is nothing to look at and the plan is the decision. In brownfield `absent` requires that something actually looked, and the reason names what looked. A row whose state is `unknown` or `hint` is not excluded: it becomes required, or it becomes an entry in `## Open Questions` with a recommended default. A single confidently false exclusion costs more trust than ten honest unknowns.

## 8. System of record, and stating the boundary

Every row carries `system-of-record: repo | product | org | external`. A row whose documentation lives in a wiki, a ticket system, or a compliance platform is not absent; it is somewhere this plan cannot see, and the honest action is `confirm`.

State the boundary in the section itself, whether or not anything prompted it:

> This manifest covers documentation committed to this repository. Documents that live in a wiki, an intranet, or a compliance platform are marked `present-elsewhere` and are not planned here.

One false "absent" for a document that already exists somewhere else discredits every other row on the page.

## 9. Lifecycle metadata on every planned document

A document with no owner and no review contract rots silently, and missing metadata kills document sets more often than missing document types. Every row the plan requires carries these fields, and the task that writes the document writes them into its frontmatter:

```yaml
id: operate.runbook
stage: operate
durability: durable
owner: <role, never a person's name in a public repository>
system_of_record: repo
status: draft
review_cadence: on-change | on-release | none
covers: [src/api/health.ts, ops/alerts.yaml]
valid_until: <date, evidence rows only>
```

- `status` starts at `draft` on everything a task generates. Promotion to `active` is a human act.
- `review_cadence` is copied from the catalog posture, never invented. When it is `none`, the next review is a sentence and not a date, because a date implies a calendar obligation that does not exist.
- `covers` lists the paths whose change should force a re-read. An empty `covers` is honest for most `frame` and `govern` rows, and it is not a failure.

**Staleness is four independent verdicts and never one red light**: calendar-stale (cadence elapsed), drift-stale (a `covers` path changed), expiry-stale (`valid_until` passed), and unverifiable (`covers` is empty). A business case has no files to hash, so reporting it as drift-stale is theater, and a reader shown one piece of theater discounts the rest of the page.

## 10. No invented numbers

A review cadence, a retention period, a recovery time objective, a recovery point objective, an availability target, a support-window end date, and an error budget are decisions a human owns. None of them is derivable from a plan. Each is either taken from a source the plan cites, or it is an entry in `## Open Questions` with an owner, a decide-by moment, and a recommended default. A number invented at plan time becomes a commitment nobody made, and it is quoted back later as though somebody had.

## 11. The traceability spine

The plan already carries the spine; the manifest names it rather than duplicating it. Objective (`## Scope and non-goals`) to requirement (`R-<n>.<n>` and module IDs) to task (`GP-<n>`, via its `Requirements:` line) to verification (the task `Verify` command) to phase evidence (`Checkpoint verify`) to release (`govern.changelog`). `verify.traceability` is required only when an outside body needs the spine rendered as its own artifact; every other project already has it, in the plan, and rendering a second copy guarantees the two disagree.

## 12. Anti-patterns refused

- **Laundered exclusion**: a row marked not-applicable with no reason, no evidence state, and no tripwire. Refusal: all three are mandatory, and an exclusion without them is worse than a missing document because it converts a gap into a decision nobody made.
- **Unknown as absent**: excluding a row because nothing looked. Refusal: `unknown` and `hint` cannot exclude; they escalate to required or to an open question.
- **Paper theater**: planning eighty documents because a taxonomy lists eighty. Refusal: every row names the plan fact that selected it, and a row nothing selects is not planned.
- **Checkbox headings**: a task that creates a file with the right headings and no content. Refusal: the task's acceptance names the specific content the document must carry, and an empty file that exists is worse than a missing document that is tracked, because the empty one stops anyone from noticing.
- **Audience tiering**: parallel document sets per reader. Refusal: one set partitioned by stage, with audience as a field.
- **Regime cosplay**: naming a compliance regime the project has not established applies to it. Refusal: name the signal, name the regime the signal might trigger, say to confirm with counsel, and never plan a task that drafts a regulator-facing instrument.
- **Evidence edited in place**: a task that updates last quarter's scan result or post-mortem. Refusal: evidence rows get a task that produces a new dated run plus an index that lists runs.
- **Transient artifacts as deliverables**: planning a document whose whole value expires with the debate. Refusal: the decision lands in `## Decisions` with its falsifier; the debate document is optional and never required.
- **Invented lifecycle numbers**: a review cadence or retention period the plan made up. Refusal: cite it or open a question.
- **Hand-written dependency inventory**: a dependency list typed by an agent. Refusal: the task names a real resolver command and records its output as evidence.
