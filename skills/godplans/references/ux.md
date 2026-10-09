# UX and user journeys planning module

Plans the experience layer of PLAN.mdx: actors, journeys, states, workflows, and the standards that make them auditable. The orchestrator loads this module for every archetype with a human-facing, developer-facing, or workflow surface (saas-dashboard, marketing-site, mobile-app, cli, api-service DX, internal tools); it is excluded only when no such surface exists, with the reason stated in the applicability matrix.

## Lineage

Descends from uxauditor, the read-only end-to-end experience auditor that scores 11 dimensions (Nielsen's 10 heuristics, WCAG 2.2 AA, journeys, Lean process analysis, IA, interaction design, UX writing, Baymard forms research, AARRR activation, RAIL/Doherty performance, deceptive.design trust) and writes a severity-ranked uxaudit.md. The discipline that carries over: experience is defined beyond UI (CLIs, APIs, and back-office workflows count), every claim needs file-level evidence and must pass the substitution test, journeys trace to one named actor, and process flows get Lean manufacturing treatment (TIMWOODS waste, Theory of Constraints bottlenecks, multi-actor integrity). This module inverts every check uxauditor would run after the fact into a plan-time obligation, so the emitted plan pre-answers the audit.

## Decisions to force

Hardest to reverse first. Each must land in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default.

1. Primary actor and jobs-to-be-done.
   - Question: who is the one primary actor, what are their functional, emotional, and social jobs, and what is the context of use (ISO 9241-11)?
   - Hard to reverse because every journey, label, default, and step budget derives from this; swapping personas later invalidates the journey maps and the IA.
   - Options: single named actor with all three job types stated (default); multiple actors only when the product is genuinely multi-sided, each journey still tracing to exactly one. "Users" as an actor is refused.
2. Workflow state machine for multi-actor processes.
   - Question: for every approval, queue, or handoff, what are the states, transitions, roles per transition, and exception paths?
   - Hard to reverse because state machines accumulate live data; adding a join or exception path after items exist means migrations and stranded records.
   - Options: explicit state machine with start/end states, a join for every branch, exception paths, and server-side role checks per transition (default); a plain status field only for single-actor products with no handoffs.
3. Domain vocabulary.
   - Question: what is the one term per concept and one label per action, product-wide?
   - Hard to reverse because terms leak into URLs, API fields, database columns, docs, and user memory; renaming later touches all of them.
   - Options: a vocabulary table committed in the plan (default); deferring naming to build time (refused, this is how "Sign in" and "Log in" ship in the same product).
4. Accessibility conformance target.
   - Question: which WCAG level, and which constraints does it impose on tokens and components?
   - Hard to reverse because contrast ratios live in design tokens and focus behavior lives in every component; retrofitting AA across a shipped component set is a rewrite.
   - Options: WCAG 2.2 AA (default); AAA for public-sector or accessibility-critical products; below AA only with a stated legal-risk acceptance.
5. Activation event and value-wall policy.
   - Question: what single event means the user first experienced core value, and which walls (account, email verification, credit card, sales call) stand before it?
   - Hard to reverse because auth architecture, pricing pages, and funnel instrumentation are built around it.
   - Options: value before account where feasible (default for tools and content); account-first only when data ownership demands it, stated as a decision with rationale.
6. Navigation and IA model.
   - Question: does the structure match the user's mental model, and what are the global, local, and utility navigation surfaces?
   - Hard to reverse because IA shapes routing, deep links, and breadcrumbs; reorganizing after launch breaks bookmarks and muscle memory.
   - Options: task-based IA in user vocabulary (default); org-chart mirroring (refused as a named anti-pattern).
7. Consent and cancellation symmetry.
   - Question: is cancel as easy as signup, is "Reject all" symmetric with "Accept all", and is all pricing shown before commitment?
   - Hard to reverse because billing flows, consent storage, and legal exposure (GDPR, ROSCA and state automatic-renewal laws, EU DSA Art. 25; the FTC click-to-cancel rule was vacated on 8 July 2025 and is not cited as law) harden around the first implementation.
   - Options: symmetry written into the plan as grep-verifiable requirements (default); anything less is a compliance and trust finding waiting to happen.

## Plan requirements

1. R-UX-1: PLAN.mdx names one primary actor per journey with their functional, emotional, and social jobs-to-be-done and a context-of-use statement (device, environment, frequency, expertise).
   Criterion: WHEN the plan is emitted THE PLAN SHALL contain a named primary actor with all three job types and a context-of-use line, and every journey SHALL reference exactly one named actor.
2. R-UX-2: PLAN.mdx maps 2-4 primary journeys end to end (signup to first value, the main recurring task, a recovery or upgrade path, checkout or conversion where applicable), each with a numbered step list and a step budget.
   Criterion: WHEN a core goal is planned THE PLAN SHALL enumerate its steps with a maximum step count and SHALL flag any step that re-enters data the system already holds.
3. R-UX-3: PLAN.mdx specifies the full state matrix: every async action gets loading, pending, disabled, and success states; every screen gets an empty state answering what this is, why it is empty, what to do next, and what it looks like full; every error, expired, and zero-result state names a forward action.
   Criterion: IF a screen or async action is listed in the plan THE PLAN SHALL enumerate its states, and no error or empty state SHALL lack a forward action.
4. R-UX-4: PLAN.mdx sets feedback budgets: input acknowledged within ~100ms, completion or visible progress within ~400ms (RAIL/Doherty), skeletons or optimistic UI for unavoidable waits, and progress position shown in every multi-step flow.
   Criterion: WHEN an async or multi-step interaction is planned THE PLAN SHALL state the 100ms/400ms budgets and the wait treatment for each flow that can exceed them.
5. R-UX-5: PLAN.mdx defines the destructive-action policy: undo for destructive actions, a clearly marked exit from every state, no modal or wizard traps, and confirmations reserved for genuinely costly irreversible actions only.
   Criterion: IF an action is destructive THE PLAN SHALL specify its undo or recovery path, and IF a confirmation is planned THE PLAN SHALL name the irreversible cost it guards.
6. R-UX-6: PLAN.mdx commits a vocabulary table: one term per concept, one label per action product-wide, buttons naming the action or outcome (never "Submit", "OK", "Click here"), labels in user language not internal jargon, plus a documented voice with context-adaptive tone.
   Criterion: WHEN the plan is emitted THE PLAN SHALL contain a vocabulary table and a voice-and-tone note, and no planned label SHALL use a banned generic term.
7. R-UX-7: PLAN.mdx writes the error-message standard: plain language stating what happened, why, how to fix it, and what happens next; shown at the field; never raw codes or stack traces; user input always preserved.
   Criterion: WHEN error handling is planned THE PLAN SHALL include this standard as acceptance criteria on every task that renders errors.
8. R-UX-8: PLAN.mdx declares the conformance target from decision 4 (WCAG 2.2 AA by default) with its concrete consequences: contrast tokens at >=4.5:1 text and >=3:1 UI, full keyboard operability with no traps, visible focus indicators on everything focusable (no outline removal without replacement), focus order following visual order, targets >=24x24px (44-48px primary), reduced-motion respected, 200% zoom reflow without horizontal scroll, no blocking of paste or autofill in auth, no redundant entry of provided information.
   Criterion: WHEN the plan is emitted THE PLAN SHALL state the conformance target and SHALL attach these constraints to the design-token and component tasks.
9. R-UX-9: PLAN.mdx specifies the form standard per Baymard: persistent visible labels above fields (never placeholder-as-label), inline validation on blur with errors adjacent to the field, minimal field count with nothing the system holds or can derive, correct type and inputmode per field, standard autocomplete tokens, format-tolerant normalization (Postel's Law), explicit optional/required marking, double-submit guards, and never clearing a form on error.
   Criterion: IF any form is planned THE PLAN SHALL apply this standard as acceptance criteria on the form task.
10. R-UX-10: For every multi-actor process, PLAN.mdx models the explicit state machine: start and end states, a join for every branch, exception paths, and no unreachable states.
    Criterion: WHEN a workflow with approvals, queues, or handoffs is planned THE PLAN SHALL include its state diagram (mermaid) with every transition labeled with the role allowed to perform it.
11. R-UX-11: PLAN.mdx plans workflow integrity mechanics: server-side role checks on every transition, timeout/escalation/SLA for stalled items, optimistic locking or a conflict path for concurrent edits, status visibility for waiting parties (where the item is, who holds it, what happens next), and in-product reassignment, recall, and rollback, never database surgery.
    Criterion: IF two or more actors touch the same item THE PLAN SHALL specify all five mechanics as task acceptance criteria.
12. R-UX-12: PLAN.mdx classifies every workflow step as value-added, necessary-non-value, or waste (TIMWOODS); removes or parallelizes serial approvals; automates deterministic rule-based human steps; and names the expected bottleneck with the design that relieves it.
    Criterion: WHEN a process is planned THE PLAN SHALL contain the step classification table and SHALL name one expected bottleneck with its mitigation.
13. R-UX-13: PLAN.mdx plans the IA around the actor's mental model: navigation labels with information scent in user vocabulary, breadcrumbs on deep pages, a current-location indicator, and, where content volume warrants, typo- and synonym-tolerant search with a useful zero-results state.
    Criterion: WHEN navigation is planned THE PLAN SHALL show the nav structure and SHALL trace at least two realistic "find X" tasks through it.
14. R-UX-14: PLAN.mdx defines the activation event (first hands-on core value), counts planned steps from signup to it, and removes non-essential walls (forced account, email verification, credit card, sales call) before value; first-run drives the core action with templates or sample data, never a feature tour or a blank canvas.
    Criterion: WHEN onboarding is planned THE PLAN SHALL name the activation event, state the signup-to-activation step count, and justify every wall that remains.
15. R-UX-15: PLAN.mdx plans the retention loop: saved state as a reason to return, a trigger-action-reward-investment habit loop where the product warrants one, and value-driven (not spammy) re-engagement.
    Criterion: IF the product expects repeat use THE PLAN SHALL name the return trigger and the saved state that makes returning worthwhile.
16. R-UX-16: PLAN.mdx sets performance and responsiveness budgets: LCP <=2.5s, INP <=200ms, CLS <=0.1 at p75 as field targets measured after launch (CrUX or RUM), with a pre-launch Lighthouse CI gate on LCP, CLS, and Total Blocking Time as the INP proxy (never asserted from static code); explicit dimensions or aspect-ratio on all media; viewport meta with zoom enabled; no horizontal scroll at 320px; touch targets sized for thumbs; a loading state for every async action.
    Criterion: WHEN the plan is emitted THE PLAN SHALL state these budgets, SHALL route the lab gate to the final Verification phase with the exact command, and SHALL name the field source that measures p75 after launch.
17. R-UX-17: PLAN.mdx writes an anti-deceptive-design policy covering the deceptive.design taxonomy: cancellation as easy as signup, "Reject all" as prominent and as few clicks as "Accept all", total pricing and fees shown before commitment, no pre-checked opt-ins or upsells, no fake scarcity or manufactured social proof, granular revocable consent, privacy-favoring defaults with collection explained at the point of collection, and real organization and contact credibility signals.
    Criterion: IF the product has billing, consent, or subscription flows THE PLAN SHALL include this policy as acceptance criteria on those tasks.
18. R-UX-18: PLAN.mdx plans component-state completeness and hierarchy: hover, focus, active, disabled, loading, empty, and error states designed for every interactive element; interactive elements look interactive and non-interactive elements never masquerade as buttons; exactly one dominant primary action per screen; expert accelerators (keyboard shortcuts, bulk actions, saved defaults) that never block novices.
    Criterion: WHEN a component library or screen inventory is planned THE PLAN SHALL require the seven states per interactive component and one primary action per screen.
19. R-UX-19: PLAN.mdx plans cross-channel continuity and endings: state and context survive channel and device switches (web to email to app), multi-step flows show remaining progress (Zeigarnik), and each journey ends on a designed satisfying note (Peak-End).
    Criterion: IF a journey crosses channels or devices THE PLAN SHALL state how context survives the handoff, and every mapped journey SHALL name its designed ending.
20. R-UX-20: For non-GUI surfaces (CLI, API, SDK), PLAN.mdx applies the same discipline calibrated to the surface: exit codes and error messages follow the error standard, help output teaches the next step, destructive commands get confirmation or a dry-run flag, and API errors are specific and recovery-oriented.
    Criterion: IF the product has a developer-facing surface THE PLAN SHALL define its experience requirements rather than exempting it from UX planning.

## Task seeds

- [ ] GP-xxx Implement shared async-state primitives (loading, empty, error, success)
  - Files: src/components/states/AsyncBoundary.tsx, src/components/states/EmptyState.tsx, src/components/states/ErrorState.tsx
  - Acceptance: EmptyState requires title, reason, and action props; ErrorState requires a forward action prop; no component renders bare "No data" text
  - Verify: ! grep -rn 'No data' src/components && grep -q action src/components/states/EmptyState.tsx
  - Requirements: R-UX-3, R-UX-7
- [ ] GP-xxx Build the signup-to-activation journey within its step budget
  - Files: src/routes/signup/, src/routes/onboarding/, src/lib/activation.ts
  - Acceptance: activation event emitted once, server-side after the outcome commits, from one named function (through the R-BIZ-20 tracking wrapper when that requirement lands); no credit-card or email-verification gate before the activation route; first-run seeds sample data
  - Verify: grep -q "trackActivation" src/lib/activation.ts && ! grep -rn "verifyEmailBefore" src/routes/onboarding/
  - Requirements: R-UX-2, R-UX-14
- [ ] GP-xxx Implement the form standard on all input surfaces
  - Files: src/components/forms/Field.tsx, src/components/forms/Form.tsx
  - Acceptance: every Field renders a visible label element; autocomplete tokens set for name, email, tel, and address fields; validation fires on blur; submit handler guards double submission
  - Verify: grep -q '<label' src/components/forms/Field.tsx && test -z "$(grep -rl 'placeholder=' src/components/forms | xargs -r grep -L '<label')"
  - Requirements: R-UX-9, R-UX-8
- [ ] GP-xxx Implement the workflow state machine with server-side role checks
  - Files: src/server/workflow/machine.ts, src/server/workflow/transitions.ts
  - Acceptance: every transition names allowed roles and is checked server-side; stalled items have a timeout escalation; concurrent edits hit optimistic-lock version checks; reassign and recall exposed as endpoints
  - Verify: grep -q "assertRole" src/server/workflow/transitions.ts && grep -q "version" src/server/workflow/machine.ts
  - Requirements: R-UX-10, R-UX-11
- [ ] GP-xxx Apply the accessibility token and focus contract
  - Files: src/styles/tokens.css, src/components/
  - Acceptance: no outline:none without a replacement focus style; contrast tokens documented at >=4.5:1; prefers-reduced-motion media query present; no user-scalable=no anywhere
  - Verify: ! grep -rn "user-scalable=no" src/ && grep -q "prefers-reduced-motion" src/styles/tokens.css
  - Requirements: R-UX-8, R-UX-18
- [ ] GP-xxx Implement the error-message catalog
  - Files: src/lib/errors/catalog.ts, src/lib/errors/render.tsx
  - Acceptance: every user-facing error maps a code to what/why/fix/next copy; raw codes never rendered; form state preserved on error
  - Verify: grep -q "whatHappened" src/lib/errors/catalog.ts && ! grep -rn "err.code}" src/components
  - Requirements: R-UX-7, R-UX-3
- [ ] GP-xxx Verify cancellation symmetry and pricing transparency
  - Files: src/routes/billing/, src/routes/settings/subscription/
  - Acceptance: cancel reachable in no more clicks than subscribe; total price with fees rendered before payment; no defaultChecked on upsell inputs
  - Verify: ! grep -rn "defaultChecked" src/routes/billing/ && grep -q "totalWithFees" src/routes/billing/
  - Requirements: R-UX-17

## Self-audit rubric

Score the UX sections of the draft plan 0-100. Below 85 total, revise before emission.

- Actor, jobs, and context of use (10): full marks require one named primary actor with functional, emotional, and social jobs, a context-of-use statement, and every journey tracing to one actor.
- Journeys and step budgets (14): 2-4 journeys mapped end to end with numbered steps, a budget per goal, no re-entry of held data, cross-channel handoffs and designed endings stated.
- State matrix and error standard (14): every async action and screen has enumerated states, every dead end has a forward action, the error-message standard and 100ms/400ms budgets appear as task acceptance criteria.
- Accessibility plan (13): the decision 4 conformance target (WCAG 2.2 AA by default) declared with contrast, keyboard, focus, target, motion, zoom, and redundant-entry constraints attached to concrete token and component tasks.
- Process and workflow integrity (13): state machines drawn with roles per transition, all five integrity mechanics specified, steps classified Lean with a named bottleneck.
- Forms and input (8): the full Baymard standard applied as acceptance criteria on every form task.
- IA and navigation (8): nav structure shown, labels in user vocabulary, two find-X traces recorded, search and zero-results planned where warranted.
- Onboarding and activation (8): activation event named, signup-to-value step count stated, every remaining wall justified, retention loop planned.
- Performance budgets (6): CWV targets stated with the lab gate routed to the Verification phase by exact command and the p75 field source named; layout-stability and responsive rules on tasks.
- Trust and anti-deception (6): the anti-deceptive-design policy present and bound to billing, consent, and subscription tasks.

## Anti-patterns refused

- UX theater: a spinner tied to nothing, a confirmation guarding nothing costly, a progress bar that does not reflect progress. Refusal: every state element in the plan names the real condition it reflects; interstitials that add a step without preventing irreversible harm are cut.
- Platitude planning: "improve usability", "make it intuitive", "enhance onboarding" as plan lines. Refusal: apply the substitution test; any line that fits every project is replaced with a file-level, criterion-bearing requirement or deleted.
- Persona-free planning: journeys for "users" in general. Refusal: no journey enters the plan without exactly one named actor and job; missing actors become discovery questions, not assumptions.
- Placeholder-as-label forms: labels that vanish on input, whole forms clearing on error. Refusal: the Baymard standard is non-negotiable acceptance criteria on every form task.
- Roach motel: easy in, hard out; asymmetric consent; hidden costs. Refusal: cancellation symmetry, pricing transparency, and Reject-all parity are written as grep-verifiable acceptance criteria, not values statements.
- Feature-tour onboarding: first-run walks the interface instead of driving the core action. Refusal: onboarding tasks must reach the activation event; tours, blank canvases, and premature data collection are rejected at plan time.
- Wall-before-value: account, verification, or card gates with no stated justification. Refusal: every wall before activation is either justified in the Decisions section or removed from the flow.
- Database-surgery recovery: workflows where stuck items need an engineer and a SQL console. Refusal: reassignment, recall, and rollback are planned as product features on every multi-actor workflow.
- Prediction-as-verdict: asserting CWV numbers, real contrast, or runtime focus order from static plans. Refusal: numeric claims are budgets with a named post-build verification command in the final Verification phase, never facts.
- Leaf-scattering: duplicating micro-rules across dozens of tasks instead of shared standards. Refusal: standards (errors, forms, states, vocabulary) are defined once and referenced by Requirements: lines, mirroring the auditor's systemic-root-cause clustering.
- Surface denial: skipping UX planning because the product is a CLI or API. Refusal: the experience lens calibrates to the actual surface; only a product with no human-facing, developer-facing, or workflow surface excludes this module, with the reason recorded.
