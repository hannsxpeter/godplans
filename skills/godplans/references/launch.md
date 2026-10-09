# Launch planning module

Plans the launch surface of PLAN.mdx: positioning, landing page, SEO and OG cards, waitlist funnel, channel posts, telemetry, and the D-7 to D+7 runbook. The orchestrator loads this module for any archetype with a public audience (saas-dashboard, marketing-site, mobile-app, library, api-service with public signup); internal tools and private services exclude it with a stated reason in the applicability matrix.

## Lineage

Descends from launch-ready, the shipping-tier ready-suite skill that puts a deployed app in front of real users without shipping AI-slop. What carries over: the substitution test as a sentence-by-sentence discipline, the banned-word audit, the five-channel OG preview rule, per-channel etiquette encoded as venue-specific have-nots, the paper-waitlist and silent-launch gates, and the runbook-as-calendar mechanic. launch-ready audits a launch after the surfaces exist; this module forces every one of its pass/fail gates into plan requirements so the surfaces are built correct the first time.

## Decisions to force

1. The four positioning sentences.
   - Question: who is it for, what does it replace, what does it do differently, what is the differentiator test?
   - Why hard to reverse: every downstream surface (hero, feature grid, OG card, meta description, every channel post, the first email line) derives from these sentences. Rewriting positioning after surfaces ship means rewriting all of them, and LinkedIn caches the OG card for 7 days.
   - Options: write and substitution-test all four against >=2 named competitors now (default), or launch on generic copy and rebrand later (refused: that is Mode B rescue work by construction).
2. Launch mode and target tier.
   - Question: which of the five modes (A pre-launch, B fix-AI-slop-landing, C re-launch, D rescue-no-traction, E quiet-B2B) and which target tier (1 Positioned, 2 Landed, 3 Captured, 4 Launched)?
   - Why hard to reverse: mode determines which sections and tasks exist at all. Discovering mid-execution that the project is Mode E wastes every broad-channel task already planned.
   - Options: Mode A tier 4 for greenfield public products (default); Mode E tier 3 for B2B without a broad-channel audience; Modes B, C, D only in replan with a prior launch on record.
3. Sending domain and email authentication.
   - Question: which domain sends waitlist email, and when do SPF, DKIM, and DMARC get configured?
   - Why hard to reverse: DNS propagation and domain reputation take days, and a launch-day drop from an unauthenticated domain lands in spam with no retry.
   - Options: authenticate the product domain in the first phase (default), use a transactional subdomain such as mail.example.com (also fine), or configure at launch week (refused: no lead time).
4. Brand identity tokens.
   - Question: does the landing page inherit brand tokens from the build section, or does the plan define a minimum viable identity (one brand color, two grays, one or two typefaces, a real icon library)?
   - Why hard to reverse: the OG card bakes the brand color into a cached image, and a landing page on library defaults reads as template output on every channel at once.
   - Options: inherit from the build section's visual identity (default when it exists); otherwise define the minimum viable identity in this section before any surface task.
5. Launch date and channel calendar.
   - Question: which day, and which channels at which hour?
   - Why hard to reverse: Product Hunt requires a confirmed hunter more than 48 hours out, amplification asks go out more than 48 hours in advance, and PH posts land at 12:01 AM PT Tuesday through Thursday. Moving the date invalidates every commitment already made.
   - Options: a Tuesday or Wednesday at least 7 days after the final build task, with the runbook counting D-7 backward from it (default); a soft launch date for Mode E that skips PH and HN entirely.
6. UTM taxonomy.
   - Question: what are the campaign, source, medium, and content values for every link that will ever be shared?
   - Why hard to reverse: a link shared without UTM params is permanently unattributable; traffic that already arrived cannot be retro-tagged.
   - Options: one campaign slug per launch, source per venue, medium fixed (social, email, referral), content per asset, recorded in a utm-registry file (default); ad-hoc tagging per post (refused: guarantees collisions and a blind D+1 waterfall).
7. Status page hosting.
   - Question: where does the status page live?
   - Why hard to reverse: a status page on the same infra as the app is discovered to be useless exactly once, during the first outage, which for many products is launch day.
   - Options: out-of-band hosted status page cross-referenced with the observability section (default); same-infra page (refused).

## Plan requirements

1. R-LAUNCH-1: PLAN.mdx contains the four positioning sentences (who it is for, what it replaces, what it does differently, the differentiator test; the first names the R-BIZ-2 segment when business is applicable), each annotated with the >=2 named competitors it was substitution-tested against. Criterion: WHEN the launch section is present THE PLAN SHALL state four positioning sentences each naming at least two competitors whose substitution into the sentence makes it false.
2. R-LAUNCH-2: PLAN.mdx defines tone of voice as three adjectives plus three anti-adjectives, and mandates founder voice (first person, named founder, one founder-story line) on the hero with no company-we voice. Criterion: WHEN landing copy tasks are planned THE PLAN SHALL include the six tone words and a founder-voice acceptance condition on the hero task.
3. R-LAUNCH-3: PLAN.mdx declares the launch mode (A through E) and target tier (1 through 4), and Mode C or D plans name the dominant failure cause from the prior launch before any remediation task. Criterion: IF the mode is C or D THE PLAN SHALL name the dominant prior-launch failure cause; WHEN any mode is set THE PLAN SHALL scope channel tasks to that mode.
4. R-LAUNCH-4: PLAN.mdx specifies the five-section landing anatomy in order (hero, social proof, feature grid, pricing if applicable and rendered from the R-BIZ-7 plan catalog, CTA), a single above-the-fold primary CTA, and a hero that fits the 1366x768 fold. Criterion: WHEN the landing page task is planned THE PLAN SHALL enumerate the five sections in order and set exactly one above-the-fold CTA as an acceptance condition.
5. R-LAUNCH-5: PLAN.mdx constrains the feature grid to 3-6 tiles, each a product-specific capability traced to a shipped or planned build task, with no category-label tiles (Fast, Secure, Scalable) and no feature the build section does not deliver. Criterion: WHEN the feature grid is planned THE PLAN SHALL map every tile to a named GP-task or existing feature; IF a tile has no source THE PLAN SHALL delete the tile, not the traceability.
6. R-LAUNCH-6: PLAN.mdx bakes the banned-word audit into copy acceptance: no instance of seamless, powerful, revolutionary, effortless, intelligent, cutting-edge, game-changing, unlock, supercharge, streamline, empower, elevate, robust, best-in-class, leading, enterprise-grade, or world-class above the fold, each replaced with the concrete claim it hides. Criterion: WHEN copy tasks are planned THE PLAN SHALL include a grep-verifiable banned-word check as an acceptance condition on every copy surface.
7. R-LAUNCH-7: PLAN.mdx enforces copy voice rules: active voice, second person, named subjects, concrete over abstract, and no AI self-reference in the hero unless the product is an AI product and the AI is the differentiator. Criterion: IF the product is not an AI product THE PLAN SHALL forbid AI self-reference in hero acceptance conditions.
8. R-LAUNCH-8: PLAN.mdx resolves brand tokens: either it references the build section's visual identity or it defines the minimum viable identity (one brand color, two grays, one or two typefaces, a real icon library), so no launch surface ships on library defaults. Criterion: WHEN the landing or OG tasks are planned THE PLAN SHALL name the brand color hex and typefaces they consume.
9. R-LAUNCH-9: PLAN.mdx plans the 12-item launch-day SEO checklist as verifiable acceptance conditions: exactly one h1, title under 60 characters, meta description under 160, canonical URL, robots.txt, sitemap.xml, complete OG tags, complete Twitter tags, schema.org JSON-LD, HTTPS, Core Web Vitals green, and a grep for leftover template noindex on every route the R-SEO-1 matrix marks indexable (the R-SEO-5 environment guard and routes noindexed by design are not leftovers). Criterion: WHEN the SEO task is planned THE PLAN SHALL list all 12 items with a command-checkable condition each, including the noindex grep.
10. R-LAUNCH-10: PLAN.mdx specifies the OG card to spec: exactly 1200x630, under 300KB, legible at 600x315 half size, brand color plus product name plus a 6-10 word value prop, nothing critical in the outer 40px. Criterion: WHEN the OG card task is planned THE PLAN SHALL state all five spec conditions as acceptance criteria with an image-dimension verify command.
11. R-LAUNCH-11: PLAN.mdx schedules the five-channel OG preview (X, LinkedIn via Post Inspector, Slack, iMessage, Discord) with screenshots before D-1 and before any link ships, because LinkedIn caches the card for 7 days. Criterion: WHEN the runbook is planned THE PLAN SHALL place the five-channel preview task at or before D-1 and gate all link-sharing tasks on it.
12. R-LAUNCH-12: PLAN.mdx plans the waitlist as double opt-in: a two-field-max capture form, an inline thank-you state naming the confirmation email, only confirmed addresses on the list, and a welcome email within 5 minutes of confirmation. Criterion: WHEN the waitlist task is planned THE PLAN SHALL require double opt-in and the 5-minute welcome as acceptance conditions.
13. R-LAUNCH-13: PLAN.mdx plans the full email sequence: 2-4 pre-launch emails each with a stated purpose, a scheduled launch-day drop, and D+1, D+3, D+7 post-launch emails. Criterion: WHEN the funnel is planned THE PLAN SHALL enumerate every email with its purpose and send trigger; IF an email has no purpose THE PLAN SHALL cut it.
14. R-LAUNCH-14: PLAN.mdx schedules SPF, DKIM, and DMARC on the sending domain in an early phase (lead time), plus a working list-level unsubscribe and a GDPR consent checkbox if EU or UK users are in scope. Criterion: WHEN email tasks exist THE PLAN SHALL place domain authentication before any send task in wave order and include a DNS verify command.
15. R-LAUNCH-15: PLAN.mdx contains a per-channel post plan with all seven fields (venue, timing with timezone, title per etiquette, body per native format, hunter or submitter, amplification plan, response plan) and encodes venue etiquette: PH at 12:01 AM PT Tuesday through Thursday with a hunter confirmed more than 48 hours out, Show HN 7-10am ET weekday with no launch or all-caps in the title, Reddit only into subs with real prior comment history at a 9:1 participation ratio, LinkedIn in founder voice not press-release voice. Criterion: WHEN a channel is in scope THE PLAN SHALL state all seven fields and that venue's etiquette rules as acceptance conditions.
16. R-LAUNCH-16: PLAN.mdx defines the UTM taxonomy (source, medium, campaign, content) applied to every shared link and a utm-registry file preventing value collisions. Criterion: WHEN any link-bearing asset is planned THE PLAN SHALL require UTM params on it and register the values; IF a shared link has no UTM params THE PLAN SHALL treat it as a blocking defect, not a nice-to-have.
17. R-LAUNCH-17: PLAN.mdx instruments the five-event conversion waterfall (visit, CTA click, form submit, confirmation, activation), each named in the R-BIZ-20 event catalog when that requirement lands, with analytics live and the waterfall tested in staging before launch day. Criterion: WHEN telemetry is planned THE PLAN SHALL name the five events and include a staging test task that fires and verifies each one.
18. R-LAUNCH-18: PLAN.mdx plans the amplification list of >=5 named humans with specific asks sent more than 48 hours in advance, and blocks the founder's calendar as primary responder for the 8-hour window after each post. Criterion: WHEN channel posts are planned THE PLAN SHALL list the amplifiers by name or named role and set the founder as first responder in the response plan.
19. R-LAUNCH-19: PLAN.mdx contains the D-7 to D+7 runbook as a timezone-aware calendar with an owner and a pass criterion per item, a launch-day hour-by-hour schedule, and a retrospective task with targets set before launch so results are measured against a baseline. Criterion: WHEN the runbook is planned THE PLAN SHALL give every row a date, owner, and pass criterion, and the retrospective SHALL reference pre-set numeric targets.
20. R-LAUNCH-20: PLAN.mdx couples launch to its siblings: the status page is hosted out-of-band from the app infra, no launch date lands atop an in-progress schema migration from the deploy section, and any at-risk SLO from the observability section gets an SLO-watch row in the runbook. Criterion: IF the deploy section schedules a migration THE PLAN SHALL sequence the launch after its contract phase completes; WHEN a status page is planned THE PLAN SHALL host it off the app's infrastructure.
21. R-LAUNCH-21: PLAN.mdx ends the launch phase with the cold proof test: a stranger on an unfamiliar device describes the product in under 15 seconds, clicks the CTA into a working waitlist, receives confirmation within 5 minutes, sees a correct OG preview from any of the five channels, and appears in analytics under the right UTM source. Criterion: WHEN the launch phase is planned THE PLAN SHALL include the cold proof test as its checkpoint with all five observations as must-haves.
22. R-LAUNCH-22: For a public release, exactly one task cites this requirement to mark the first public activation action. It immediately follows and depends on the prepublication gate task citing R-ROAD-21, which in turn follows and depends on the latest hardening evidence task citing R-SEC-26. The gate records checked_at, hardening_revision, finding_counts, policy, verdict, and validates owner, justification, accepted_at, and expires_at for permitted Critical risks. Any hardening change invalidates it. Criterion: WHEN a link, package, store artifact, service, model, or infrastructure surface will become public THE PLAN SHALL cite R-LAUNCH-22 only on the first activation task and place the R-ROAD-21 gate immediately before it; IF no public surface exists THE PLAN SHALL record `public_release: false` and omit both tasks.

Banned-word replacement table for R-LAUNCH-6. Each slop word is replaced with the concrete claim it hides, not deleted:

| Banned word | Replace with |
| --- | --- |
| seamless | the actual step count ("in one step", "no config file") |
| powerful | the specific capability ("queries 10M rows", "runs offline") |
| robust | the threshold survived ("handles 500 rps", "retries for 24h") |
| effortless, streamline | the time saved, with a number |
| intelligent, cutting-edge | what the feature actually does, named |
| revolutionary, game-changing | the before/after difference, stated plainly |
| unlock, supercharge, empower, elevate | the verb for what the user actually does |
| best-in-class, leading, enterprise-grade, world-class | the evidence (benchmark, customer count, cert) or nothing |

## Task seeds

Replace each `<...>` placeholder with the plan's real domain or URL; one left in makes its Verify a shell syntax error.

- [ ] GP-xxx Write positioning document with substitution-tested sentences
  - Files: docs/launch/POSITIONING.md
  - Acceptance: four sentences present; each lists >=2 named competitors that fail substitution; three adjectives and three anti-adjectives; founder named
  - Verify: grep -cE '^(Who|Replaces|Differently|Differentiator):' docs/launch/POSITIONING.md | grep -qx 4
  - Requirements: R-LAUNCH-1, R-LAUNCH-2, R-LAUNCH-3
- [ ] GP-xxx Build five-section landing page with single above-the-fold CTA
  - Files: site/index.html, site/styles.css
  - Acceptance: sections hero, social-proof, features, pricing, cta in order; exactly one h1; feature grid has 3-6 tiles each naming a shipped capability; any pricing section is generated from the R-BIZ-7 catalog with no hand-typed price
  - Verify: grep -c '<h1' site/index.html | grep -qx 1 && grep -oc 'data-section=' site/index.html | grep -qx 5
  - Requirements: R-LAUNCH-4, R-LAUNCH-5, R-LAUNCH-8
- [ ] GP-xxx Run banned-word and voice audit on all launch copy
  - Files: site/index.html, docs/launch/emails/
  - Acceptance: zero banned-word hits above the fold; no AI self-reference in hero; second person and active voice on hero
  - Verify: test -f site/index.html && ! grep -riE 'seamless|powerful|revolutionary|effortless|\bintelligent\b|cutting-edge|game-changing|\bunlock\b|supercharge|streamline|empower|elevate|robust|best-in-class|\bleading\b|world-class|enterprise-grade' site/index.html
  - Requirements: R-LAUNCH-6, R-LAUNCH-7
- [ ] GP-xxx Ship launch-day SEO head and OG card to spec
  - Files: site/index.html, site/public/og.png, site/public/robots.txt, site/public/sitemap.xml
  - Acceptance: title <60 chars; meta description <160; canonical, OG, Twitter, JSON-LD tags present; no noindex on the indexable landing page (only the R-SEO-5 environment guard and routes noindexed by design emit it); og.png is 1200x630 and under 300KB
  - Verify: grep -q 'rel="canonical"' site/index.html && ! grep -qi noindex site/index.html && identify -format '%wx%h' site/public/og.png | grep -qx 1200x630
  - Requirements: R-LAUNCH-9, R-LAUNCH-10
- [ ] GP-xxx Wire double opt-in waitlist and email sequence
  - Files: site/waitlist.html, api/subscribe.ts, docs/launch/emails/sequence.md
  - Acceptance: form has <=2 fields; confirmation email sent before list entry; welcome within 5 min; sequence.md enumerates pre-launch, launch-day, and D+1/D+3/D+7 emails each with a purpose line
  - Verify: grep -c '^## Email' docs/launch/emails/sequence.md | grep -qE '^[6-9]$' && grep -q 'double opt-in' api/subscribe.ts
  - Requirements: R-LAUNCH-12, R-LAUNCH-13
- [ ] GP-xxx Authenticate sending domain
  - Files: docs/launch/dns-email-auth.md
  - Acceptance: SPF, DKIM, DMARC records documented with values; unsubscribe mechanism named; GDPR consent noted if applicable
  - Verify: dig +short TXT _dmarc.<domain> | grep -q 'v=DMARC1'
  - Requirements: R-LAUNCH-14
- [ ] GP-xxx Write per-channel post plans and UTM registry
  - Files: docs/launch/channels.md, docs/launch/utm-registry.md
  - Acceptance: each in-scope channel has all seven fields; PH/HN/Reddit/LinkedIn etiquette rules stated per channel; every planned link carries registered UTM values
  - Verify: grep -c '^| utm_' docs/launch/utm-registry.md | grep -qE '[1-9]' && grep -q 'hunter' docs/launch/channels.md
  - Requirements: R-LAUNCH-15, R-LAUNCH-16, R-LAUNCH-18
- [ ] GP-xxx Build D-7 to D+7 runbook with telemetry checkpoint
  - Files: docs/launch/RUNBOOK.md
  - Acceptance: every row has date, timezone, owner, pass criterion; five-event waterfall staging test row before D-1; five-channel OG preview row at or before D-1; retrospective row with pre-set targets; cold proof test as final checkpoint
  - Verify: grep -c 'pass:' docs/launch/RUNBOOK.md | grep -qE '^[1-9][0-9]*$' && grep -q 'cold proof' docs/launch/RUNBOOK.md
  - Requirements: R-LAUNCH-11, R-LAUNCH-17, R-LAUNCH-19, R-LAUNCH-20, R-LAUNCH-21
- [ ] GP-xxx Run fresh prepublication gate before public activation
  - Files: docs/release/PREPUBLICATION.md
  - Depends on: GP-HARDENING
  - Acceptance: records checked_at later than current hardening evidence, matching hardening_revision, finding_counts, policy, and verdict; validates owner, justification, accepted_at, and expires_at for permitted Critical risks; any later hardening change invalidates the pass
  - Verify: test -f docs/security/HARDENING.md && test "$(git hash-object docs/security/HARDENING.md)" = "$(awk '/^hardening_revision:/ {print $2}' docs/release/PREPUBLICATION.md)" && grep -q '^verdict: pass$' docs/release/PREPUBLICATION.md
  - Requirements: R-ROAD-21

- [ ] GP-xxx Perform the first public activation
  - Files: deployment or publication target for the selected product form
  - Depends on: GP-PREPUBLICATION
  - Acceptance: the selected link, package, store artifact, service, model, or infrastructure surface becomes public only after the immediately preceding prepublication gate passes; a package, store artifact, or model replaces the Verify probe with its registry or store availability query
  - Verify: curl -fsS -o /dev/null <public-url>
  - Requirements: R-LAUNCH-22

## Self-audit rubric

- Positioning discipline (20): four sentences present, each substitution-tested against >=2 named competitors with the failing swaps recorded; tone words and founder voice specified; mode and tier declared and scoping the section.
- Landing page and copy (20): five sections in order with a single above-the-fold CTA; feature grid 3-6 tiles all traced to shipped or planned features; banned-word audit and voice rules wired into task acceptance as grep-verifiable conditions; brand tokens named, not defaulted.
- SEO and OG cards (15): all 12 SEO checklist items present as command-checkable acceptance conditions including the noindex grep; OG card spec complete with dimension and size verify; five-channel preview scheduled before D-1 and gating link-sharing tasks.
- Waitlist and email funnel (15): double opt-in with 5-minute welcome; every sequence email enumerated with a purpose; SPF/DKIM/DMARC scheduled early in wave order with a DNS verify command; unsubscribe and consent handled.
- Channels and etiquette (10): every in-scope channel has all seven post-plan fields; venue etiquette (PH timing and hunter, Show HN title rules, Reddit 9:1, LinkedIn founder voice) encoded as acceptance conditions, not advice.
- Telemetry and attribution (10): UTM taxonomy defined with a registry; five-event waterfall named and staging-tested before launch; amplification list named with founder as primary responder.
- Runbook and sibling coupling (10): D-7 to D+7 calendar with owners and pass criteria; public activation follows a fresh matching hardening revision and complete risk checks; status page is out-of-band; no launch sits atop a migration; cold proof closes the phase.

Total: 100. Below 85, revise the launch section before emission.

## Anti-patterns refused

- AI-slop landing: banned words above the fold, gradient hero, stock illustrations of abstract people pointing at charts. The planner writes the banned-word grep into copy acceptance and maps each slop word to its concrete replacement.
- Hero fatigue: a hero sentence that stays plausible when a competitor's name swaps in. The planner runs the substitution test at plan time and rewrites until the swap makes the sentence false.
- Spec-sheet positioning: feature tiles that are category labels (Fast, Secure, Scalable) or a grid over 6 tiles. The planner caps the grid at 6 and requires every tile to name a product-specific capability.
- Vapor landing: the page promises features the build section does not deliver. The planner traces every tile to a GP-task or shipped feature and deletes untraceable tiles.
- Paper waitlist: a capture form with no double opt-in, no welcome email, no sequence. The planner refuses to plan a form without the full funnel behind it.
- Unrendered OG card: wrong dimensions, over 300KB, illegible at half size, or never previewed. The planner schedules the five-channel preview before D-1 because LinkedIn's 7-day cache makes a wrong card wrong for the whole window.
- Silent launch: a shared link without UTM params, so signups cannot be attributed. The planner treats a UTM-less link as a blocking defect and registers all values upfront.
- Attribution blind: analytics installed but no conversion-waterfall events. The planner names the five events and requires a staging test that fires each one.
- Channel etiquette violation: a Show HN title containing launch or all-caps, a PH post on Friday through Sunday or without a confirmed hunter, a Reddit post into a sub with zero comment history, a LinkedIn post in press-release voice. The planner encodes each venue's have-nots as acceptance conditions on the post task.
- Silent fade: no D+1 through D+7 follow-up and no retrospective, so the launch teaches nothing. The planner puts the follow-up emails and the retrospective with pre-set targets on the runbook calendar before launch day.
- Same-infra status page: a status page that goes down with the app. The planner hosts it out-of-band and cross-references the observability section.
- Launch atop a migration: a launch date landing mid expand/contract. The planner reads the deploy section's schedule and sequences the launch after the contract phase completes.
- Stale release authorization: a prepared launch trusts a prepublication pass older than hardening. The planner invalidates the pass on any hardening change and schedules the fresh revision-bound check immediately before public activation.
