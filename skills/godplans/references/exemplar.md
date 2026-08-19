# Exemplar module: the quality bar, worked

Loaded before the Phase 5b prose-integrity pass and again before Phase 6 scoring. Five plan elements are shown twice: the version that fails and the version that ships. The difference is always the same difference: the bad version survives substitution into any other project; the good version could only belong to this one.

The prose-integrity gate in section 6 adapts ideas from [cursor/pstack unslop](https://github.com/cursor/plugins/blob/main/pstack/skills/unslop/SKILL.md) (MIT, Lauren Tan): preserve meaning while removing model-like filler, then check the result again. The wording and project-specific gate below are original to godplans; no source text or catalog is copied.

## 1. A decision entry

**Never produce this:**

```markdown
### Database choice

We will use PostgreSQL because it is a robust, battle-tested relational
database with a rich ecosystem and strong community support. It scales
well and supports our needs.
```

Every clause substitutes cleanly ("We will use MySQL because it is a robust, battle-tested..."). Nothing was decided; a vibe was transcribed. It also carries no falsifier: nothing in it could ever be wrong, so nothing in it could ever be a bet.

**This is the bar:**

```markdown
### Database: Postgres 16 via Neon, one schema per tenant deferred

Decision: single Postgres database, shared tables with `workspace_id` on
every tenant-owned row, enforced by row-level security policies.
Rejected: schema-per-tenant (migration fan-out at 200+ workspaces kills
the weekend deploy budget), SQLite (two-region read replicas are a
stated requirement, R-1.4).
Hard-to-reverse because: every query, index, and the RLS policy set
assume the tenancy column; reversing at scale is a full data migration.
Falsifier:
- Signal: p95 read latency on the largest workspace and active workspace count
- Failure boundary: p95 exceeds 250 ms for seven days, or active workspaces exceed 5,000 before Phase 5
- Replan action: return to planning and evaluate the rejected schema-per-tenant migration
Hypothesis flagged: Neon cold-start latency under 500ms on the free
tier is acceptable for the beta. Validation: GP-105 measures p95
connect latency; if over 500ms, move to a warm instance before Phase 3.
```

## 2. A task

**Never produce this:**

```markdown
- [ ] GP-301 Implement authentication
  - Acceptance: authentication works correctly and securely
  - Verify: test the login flow
```

No files, no dependency, unfalsifiable acceptance, a verify step that names nothing. An executor holding only this task must invent the plan it was supposed to receive.

**This is the bar:**

```markdown
- [ ] GP-301 [W3.1] Wire session middleware into the API router
  - Files: src/api/middleware/session.ts, src/api/router.ts
  - Depends on: GP-202
  - Reuses: cookie config from src/config/cookies.ts; do not redefine
  - Acceptance: unauthenticated request to /api/boards returns 401 with
    body `{"error":"unauthorized"}`; authenticated request passes through;
    session cookie is httpOnly, secure, sameSite=lax
  - Verify: `npm test -- session.test.ts && curl -sf -o /dev/null -w "%{http_code}" localhost:3000/api/boards | grep -q 401`
  - Requirements: R-2.3, R-SEC-4, R-SEC-9
```

## 3. An open question

**Never produce this:**

```markdown
- Should we support teams? TBD
- What about billing? To be decided later
```

No options, no default, no owner of the consequence. "Later" is where plans go to rot.

**This is the bar:**

```markdown
### Q2: Can a board be shared outside its workspace?
- Owner: product lead; the answer is theirs to give and the plan must not invent it
- Blocks: nothing, because (b) is additive; it would block build from Phase 4 if the default were structural
- Decide by: 2026-08-14, the Phase 4 wave boundary
- Why it matters: a yes turns the permission model from workspace-scoped
  RLS into per-object ACLs, which changes GP-201 and every query in Phase 4.
- Options:
  (a) No; boards live and die inside one workspace.
  (b) Read-only public links with unguessable tokens.
  (c) Full cross-workspace membership.
  (d) No sharing primitive at all; export a read-only snapshot, which
      moves the question out of the permission model entirely.
- Recommended default: (b). It satisfies the stated sharing story (R-1.6)
  without per-object ACLs; the token table is additive, not structural, so
  building it before the answer lands wastes nothing if the answer is (a).
- Outside the framing: (a) through (c) only vary how much sharing the
  permission model allows. (d) was generated and rejected; it wins only if
  sharing stays read-only permanently, which R-1.6 does not promise.
```

The four fields R-PRD-10 demands (owner, decide-by, blocking flag, recommended
default) are what make the difference. The bad version cannot be scheduled, cannot
be chased, and cannot be executed past. This one can be all three.

An unknown whose answer the plan **cannot** proceed past does not belong here at
all: it is a hypothesis in `## Decisions` whose R-ROAD-7 validation task is
scheduled before every task that assumes it, so the ordering is a real
`Depends on` edge rather than a note at the bottom of the document.

## 4. A requirement with acceptance criteria

**Never produce this:**

```markdown
R-3: The app should be fast and responsive, with good performance
across devices.
```

**This is the bar:**

```markdown
R-3.1: WHEN a board with up to 500 cards loads on a mid-tier device
THE SYSTEM SHALL render first meaningful content within 1.5s (LCP)
and respond to drag input within 100ms.
R-3.2: IF the network is offline WHEN a card is edited THE SYSTEM
SHALL queue the mutation locally and reconcile on reconnect without
data loss.
Traceability: enforced by GP-412 (virtualized card list, LCP budget in
CI via Lighthouse assert) and GP-508 (mutation queue with idempotency
keys).
```

## 5. A defended absence

An absence is the hardest thing in a plan to score, because a bad one and a good one read the same at a glance. The difference is whether anything could ever prove it wrong.

**Never produce this:**

```markdown
| llm | excluded | not needed |
| serve.support-policy | serve | not-applicable | launch | no paying users |
```

Both are true today, unfalsifiable forever, and indistinguishable from nobody having looked. "Not needed" also survives the substitution test against every project ever planned.

**This is the bar:**

```markdown
| llm | excluded | by-design: splitting an expense is arithmetic over the ledger table, and the receipt parser is a regex over merchant strings; revisit when: any task adds a model SDK dependency, an inference endpoint, or a prompt template |

| serve.support-policy | serve | not-applicable | launch | absent: intake named no paying user and no billing surface exists in the data model; revisit when: the plan adds a billing route, a paid tier, or an external support address |
```

Three parts, each doing work the other two cannot. The **evidence state** says whether anybody looked: `by-design` means the plan settles it, `absent` means something checked and the reason names what checked. `unknown` is refused outright, because "we did not look" and "we decided this does not apply" read identically and have opposite consequences a year later. The **reason** is specific enough to become false. The **`revisit when` predicate** is what makes the row a decision with an expiry rather than a silence, and an executor that trips it returns the plan to `planning`.

## 6. Prose integrity

Structural validity does not rescue empty prose. The Phase 5b pass rewrites language after requirements and traceability are fixed, but before the independent critic scores the result. It may make a sentence clearer or shorter. It may not change a commitment, uncertainty label, source, task edge, or verification condition.

**Never produce this:**

```markdown
Industry reports suggest webhook reliability is increasingly crucial,
highlighting the need for a robust retry strategy that ensures seamless
delivery across a wide range of failure scenarios.
```

The attribution names no report. "Crucial", "robust", and "seamless" hide the actual behavior. The range has no endpoints, and the trailing clauses never say who retries what.

**This is the bar:**

```markdown
User constraint: the relay accepts at most 50 GitHub events per minute.
Decision: the delivery worker makes three attempts to the one configured
internal endpoint, waiting 1 second and then 5 seconds between retries.
After the third failure, it stores the event in `failed_deliveries` and
increments `webhook_delivery_failures_total`.
```

The source, actor, limit, retry schedule, terminal state, and observable signal are explicit. A reader can disagree with the decision and an executor can prove it.

**Never produce this:**

```markdown
The relay, platform, and service will be thoughtfully designed in order to
facilitate reliable processing, with events being validated and efficiently
handled.
```

Three nouns refer to one component. The actor disappears into passive voice. The adverbs and indirect verbs replace behavior.

**This is the bar:**

```markdown
The relay verifies `X-Hub-Signature-256` before enqueueing an event. The
worker posts the stored body to the configured endpoint and records the
response code on every attempt.
```

### Prose-integrity gate

Apply these checks to plan prose, never to literal code, commands, paths, identifiers, protocol fields, quotations needed as evidence, or wording imposed by an external contract.

1. A factual attribution names its source. If the source is missing, classify the statement as a hypothesis with a validation task or delete it.
2. A quality claim names its mechanism, observable behavior, threshold, file, or command. A feeling about the system does not count as a requirement.
3. A causal claim states the cause and result. A trailing `-ing` phrase does not stand in for either one.
4. The sentence uses the plain verb unless a domain term is more exact. Filler, promotional adjectives, empty intensifiers, and generic conclusions are cut.
5. Lists, contrasts, pairs, and ranges express a real relationship. Do not force symmetry for rhythm. Preserve field counts and ordered sets required by the plan grammar.
6. One domain concept keeps one canonical noun. Repeat it instead of cycling through near-synonyms.
7. A planned action names the actor. Passive voice is allowed only when the actor is unknown or does not affect execution.
8. A dense sentence is split when a reader must backtrack to find the operative claim. Keep tightly coupled conditions together.
9. Hedging matches uncertainty already recorded by the plan. Do not weaken a decision or make a hypothesis sound decided.
10. The paragraph adds a decision, source, consequence, or check. If it only restates its heading, neighboring table, prompt, or task field, delete it.

The gate fails when any unquoted sentence could move unchanged into an unrelated plan because it contains no project fact, decision, uncertainty, consequence, or verification condition. Attach the deduction to the domain containing the sentence. Repeated failures across domains block emission even if each domain would otherwise clear 85.

## The pattern under all six

1. Name the thing (real files, real numbers, real commands), never the category of the thing.
2. Show the rejected alternatives; a decision without a loser is a description.
3. Make failure detectable: every claim carries the check that would catch its violation, and every hard-to-reverse bet carries the falsifier that would kill it.
4. Flag what is guessed, and attach the task that turns the guess into knowledge.
5. Defend every absence: what state licensed it, and what would reverse it.

Score any plan fragment against these five. A fragment that names nothing, rejects nothing, checks nothing, and flags nothing scores zero, no matter how professional it reads. A hard-to-reverse decision with no falsifier has decided nothing either: a bet you cannot lose is not a bet, it is a posture. And an exclusion with no tripwire has not decided anything either; it has only stopped the conversation.
