# SEO and AI visibility planning module

Plans classic-search visibility and AI answer-engine citability before any template is written. The orchestrator loads this module for any archetype with a public web surface (marketing-site, blog/publisher, e-commerce, docs, saas-dashboard with public pages); it is excluded with a stated reason for cli, library, and api-service archetypes with no site.

## Lineage

Descends from seoauditor, the read-only audit of how a codebase makes a website visible to search engines and AI answer engines across 12 dimensions (CRAWL, RENDER, CONTENT, CANON, SCHEMA, AIVIS, URLARCH, PERF, SOCIAL, OBSV, I18N, FEEDS). The discipline that carries over: verify against what reaches the crawler, not against intent; hunt paper controls; distinguish AI training bots from citation bots; never score llms.txt as load-bearing; calibrate to site type so a monolingual site never gets hreflang recommendations. Audit checks that seoauditor runs after the fact become plan requirements here, reducing preventable visibility findings while leaving final verification to the shipped site audit.

## Decisions to force

1. Public URL architecture. Question: what is the canonical host, scheme, trailing-slash policy, slug scheme, and (if multilingual) locale URL scheme (subpath vs subdomain)? Why hard to reverse: public URLs are permanent identifiers; every later change costs a redirect map maintained forever and a re-indexation cycle. Options: apex vs www (default: pick one, enforce the other with a single-hop 301); no trailing slash (default) vs trailing slash; lowercase hyphenated slugs (default, non-negotiable); locale subpaths /en/ /de/ (default) vs subdomains.
2. Rendering strategy per route class. Question: which routes are SSG, ISR, SSR, and which (if any) are CSR? Why hard to reverse: retrofitting server rendering onto a CSR app is a rewrite, and GPTBot, ClaudeBot, PerplexityBot, and OAI-SearchBot execute no JavaScript, so CSR-only content is permanently invisible to AI answer engines. Options: SSG/ISR for all indexable content (default), SSR where personalization requires it, CSR only behind auth. Never CSR for indexable content; never prerender-for-bots middleware.
3. Site type and indexation split. Question: what site type is this (marketing, blog, e-commerce, docs, SPA app, local business) and which route classes are indexable vs deliberately noindexed? Why hard to reverse: the split drives robots.txt, sitemap scope, the env guard, and metadata templating; changing it later means auditing every route. Default: public content routes indexable; authenticated app routes, previews, and internal search results noindexed by design.
4. AI-crawler policy. Question: which AI bots are allowed, classified by purpose: training (GPTBot, Google-Extended, ClaudeBot, CCBot, Applebot-Extended, Bytespider) vs search/citation (OAI-SearchBot, PerplexityBot, Claude-SearchBot) vs user-fetch (ChatGPT-User, Perplexity-User, Claude-User)? Why hard to reverse: robots.txt changes propagate over weeks, and blocking citation bots while courting AI visibility is self-defeating from day one. Default: allow all citation and user-fetch bots; decide training bots on business grounds; know that blocking Google-Extended opts out of Gemini training but does NOT remove the site from AI Overviews (served via Googlebot).
5. Structured data model per template. Question: which JSON-LD types map to which page templates, and where does each required field come from in the content model? Why hard to reverse: missing fields (author, datePublished, price) must exist in the CMS/database schema; adding them later is a data migration. Default: Organization + WebSite sitewide, Article for posts (headline, image, datePublished, author, publisher), Product+Offer for commerce (price, priceCurrency, availability), BreadcrumbList on nested routes. Never plan FAQPage, HowTo, or SearchAction as SERP tactics: Google limited FAQ rich results to government and health sites (2023-08) and removed HowTo rich results (2023-09) and the sitelinks search box (2024-11).
6. SEO observability baseline. Question: which SEO invariants are asserted in CI from the first commit? Why hard to reverse: a regression safety net added after launch cannot catch the launch-day env leak that noindexes production. Default: snapshot tests on title/canonical/robots/JSON-LD for key templates plus a robots/sitemap build-integrity gate, wired in the Verification phase.

## Plan requirements

1. R-SEO-1 The plan declares the site type and a route-class indexation matrix: every route class marked indexable or noindexed with a reason (authed app routes noindexed by design is correct, not a defect).
    Criterion: WHEN the plan has a public web surface, THE PLAN SHALL contain a table mapping every route class to indexable or noindexed with a stated reason.
2. R-SEO-2 The plan fixes the rendering strategy per route so that body content, title, canonical, robots meta, and JSON-LD exist in the initial server HTML for every indexable route: SSR/SSG/ISR, never CSR-only, never injected by client JS, react-helmet without a server pass, or a tag manager, and no "use client" at a content route root.
    Criterion: WHEN a route is marked indexable, THE PLAN SHALL name its rendering mode and state that all SEO signals ship in server HTML, with no prerender-for-bots middleware anywhere in the plan.
3. R-SEO-3 The plan specifies crawlable navigation and honest status codes: real anchor elements with href (no hash routing, no onClick navigation), unknown routes return a real 404 (no SPA catch-all serving 200), no JS or meta-refresh redirects, and paginated URLs for any infinite-scroll surface.
    Criterion: WHEN the plan includes client-side routing or infinite scroll, THE PLAN SHALL include tasks for real-href navigation, a hard-404 handler, and paginated fallback URLs.
4. R-SEO-4 The plan defines the robots.txt generator: no Disallow:/ under User-agent:* in prod, no dead directives (noindex:, crawl-delay, host:), no blocking of render-critical assets (/_next/, /static/, *.js, *.css), an absolute Sitemap: line, and robots.txt never used as an index control (noindex meta for keep-out pages; Disallow plus noindex on the same URL means the noindex is never seen).
    Criterion: WHEN the plan emits a robots.txt task, THE PLAN SHALL list these five constraints in its acceptance criteria.
5. R-SEO-5 The plan includes an environment indexability guard that fails safe: staging/preview deploys emit noindex, production never does, guard polarity is explicit and an unset or unknown env resolves to noindex (a misconfiguration can hide staging but can never silently deindex prod, because the CI assertion below fails the prod build first), plus a CI assertion that production builds contain no noindex.
    Criterion: WHEN the plan has more than one deploy environment, THE PLAN SHALL contain both the guard task and the CI assertion task, cross-referenced.
6. R-SEO-6 The plan derives the sitemap generator from the content model: only canonical, indexable, 200-status URLs; real per-URL lastmod from content modification time (never a uniform build stamp); chunked index above 50,000 URLs; no priority or changefreq elements.
    Criterion: WHEN the plan emits a sitemap task, THE PLAN SHALL state the URL source query and exclude noindexed and redirected URLs by construction.
7. R-SEO-7 The plan controls crawl traps: faceted navigation, sort orders, and session parameters consolidate to the clean base URL via canonical or noindex; pagination is crawlable and never canonicalizes to page 1.
    Criterion: IF the plan includes faceted or parameterized listing pages, THE PLAN SHALL name the consolidation mechanism per parameter class.
8. R-SEO-8 The plan commits to one canonical model: one host, scheme, and slash policy enforced by exactly ONE redirect layer with single-hop 301/308s (no competing framework plus edge plus server layers, no chains, no loops), and every indexable page emits exactly one absolute self-referencing canonical (metadataBase set in Next.js so canonicals never resolve to localhost; never built from the raw request URL with query strings; never client-side-only).
    Criterion: WHEN the plan defines URL handling, THE PLAN SHALL name the single owning redirect layer and require an absolute self-referencing canonical in every page template task.
9. R-SEO-9 The plan fixes URL design and slug lifecycle: lowercase, hyphenated, shallow, stable slugs; a redirect map entry is mandatory for any slug change; redirect status codes are correct per framework (Next redirect() is 307, permanentRedirect() is 308, Express default is 302, so permanent moves must be explicit).
    Criterion: WHEN the plan defines content types with slugs, THE PLAN SHALL include the slug convention and the redirect-map mechanism as acceptance criteria on the routing task.
10. R-SEO-10 The plan templates per-route titles and meta descriptions (unique per page, never a root-layout-only title making every page identical, no "React App" defaults), exactly one meaningful h1 per page, logical heading nesting, and semantic landmarks (header, nav, main, article, footer).
    Criterion: WHEN the plan defines page templates, THE PLAN SHALL make unique title, unique description, single h1, and landmark elements grep-verifiable acceptance criteria on each template task.
11. R-SEO-11 The plan requires descriptive alt text on content images, empty alt on decorative images, descriptive anchor text (no "click here"), and a visible E-E-A-T surface: author bylines, publish and update dates, About and Contact pages as real text.
    Criterion: WHEN the plan includes content pages, THE PLAN SHALL contain tasks for the byline/date components and the About/Contact pages.
12. R-SEO-12 The plan specifies server-rendered JSON-LD per template with all required fields per type, ISO 8601 dates, ISO 4217 currency, schema.org enum URLs for availability, and entity grounding (Organization/Person sameAs to authoritative profiles, author as a linked Person, publisher with logo).
    Criterion: WHEN a template carries structured data, THE PLAN SHALL list the type, its required fields, and the content-model field each maps from.
13. R-SEO-13 The plan bans fabricated structured data: no AggregateRating or Review without visible reviews in the rendered HTML, no hardcoded sample values, no schema asserting facts absent from the page (a manual-action trigger), and no restricted or removed rich-result types (FAQPage, HowTo, SearchAction) planned as tactics.
    Criterion: WHEN the plan includes structured data tasks, THE PLAN SHALL state the content-match rule as an explicit acceptance criterion.
14. R-SEO-14 The plan states the AI-crawler policy using the three-way bot taxonomy (training vs search/citation vs user-fetch) and, if AI visibility is a goal, allows OAI-SearchBot, ChatGPT-User, PerplexityBot, Perplexity-User, Claude-SearchBot, and Claude-User, and does not block Applebot; llms.txt, if planned, is labeled aspirational (no major search or AI engine documents using it; seoauditor facts.md, reviewed 2026-09-26) and is never a substitute for server-rendered HTML; noai meta is labeled non-enforcing.
    Criterion: WHEN the plan targets AI visibility, THE PLAN SHALL contain an allow/block table by bot purpose and SHALL NOT place any load-bearing requirement on llms.txt.
15. R-SEO-15 The plan makes content answer-extractable: templates structured with h2/h3 sections, lists, and tables rather than undifferentiated paragraph blocks, plus machine-readable datePublished and dateModified via time elements with datetime and matching schema fields.
    Criterion: WHEN the plan defines article or docs templates, THE PLAN SHALL include heading-structured layout and machine-readable dates as acceptance criteria.
16. R-SEO-16 The plan sets a Core Web Vitals code budget: the LCP/hero image is never lazy-loaded and gets fetchpriority=high or preload; all images, video, iframes, and embeds carry width+height or aspect-ratio; font-display with preload for critical fonts; code-splitting with no "use client" high in the tree; AVIF/WebP with srcset via the framework image component; immutable Cache-Control on hashed assets; third-party scripts async/defer; viewport meta present without user-scalable=no.
    Criterion: WHEN the plan includes frontend tasks, THE PLAN SHALL attach these budget items as acceptance criteria on the relevant layout and asset tasks.
17. R-SEO-17 The plan templates per-route social metadata: og:title, og:type, og:url, og:image plus description/site_name/locale, twitter:card=summary_large_image with an intact OG fallback chain, absolute HTTPS image URLs (metadataBase set so relative paths never ship localhost), an approximately 1200x630 image with width/height/alt, a square favicon of at least 48px, and an apple-touch-icon; any dynamic OG image route exports size and contentType, uses PNG or JPEG, loads explicit fonts, and caches.
    Criterion: WHEN the plan includes shareable pages, THE PLAN SHALL contain a per-route social metadata task with absolute-URL verification.
18. R-SEO-18 IF the plan is multilingual, the plan centralizes hreflang generation from one locales list with reciprocity and self-reference (a missing return tag voids the cluster), x-default pointing at a genuine neutral page, valid ISO 639-1 plus ISO 3166-1 codes (en-GB not en-UK, hyphen not underscore), per-locale self-canonicals (never cross-language to the default), coverage on all eligible pages, html lang and og:locale matching the route, and no IP or Accept-Language hard auto-redirects (a banner or selector instead).
    Criterion: IF more than one locale is in scope, THE PLAN SHALL contain a central hreflang generation task with reciprocity as a tested acceptance criterion; otherwise THE PLAN SHALL drop R-SEO-18 in the module disposition (`dropped-by archetype`) with the reason.
19. R-SEO-19 IF the plan has a content stream, feeds are planned: autodiscovery link elements pointing at feeds actually generated at those URLs, valid RSS/Atom/JSON with stable GUIDs (not build-derived), correct RFC 822/3339 dates; IF IndexNow is planned, the key file is hosted (and Google's non-consumption of IndexNow is noted); IF installable, the manifest has name, short_name, in-scope start_url, and 192/512/maskable icons, with PWA never framed as a ranking factor.
    Criterion: IF a blog, changelog, or podcast is in scope, THE PLAN SHALL contain a feed task with validity checks; otherwise THE PLAN SHALL drop R-SEO-19 in the module disposition (`dropped-by archetype`) with the reason.
20. R-SEO-20 The plan wires SEO observability into the Verification phase: CI snapshot tests asserting title, canonical, robots meta, hreflang, and JSON-LD on key templates; robots and sitemap build-integrity assertions against env leakage; broken-link and redirect-chain CI; exactly one search-engine verification token (none for properties nobody owns); Consent Mode v2 default-then-update wiring if analytics consent applies; and an explicit no-cloaking rule (no user-agent or isBot content branching anywhere).
    Criterion: WHEN the plan reaches its Verification phase, THE PLAN SHALL list the SEO snapshot suite and the no-cloaking rule among the must-haves.
21. R-SEO-21 The plan makes edge configuration crawl-safe: CSP that does not block the site's own render-critical assets, HSTS paired with an HTTP-to-HTTPS 301 (HSTS alone is theater), WAF and rate-limit rules that never 403 or 429 legitimate search crawlers or allowed AI crawlers, and no mixed content.
    Criterion: WHEN the plan includes CDN, WAF, or security-header tasks, THE PLAN SHALL include crawler-safety acceptance criteria on each.
22. R-SEO-22 The plan contains zero paper controls: no noindex: lines in robots.txt, no priority/changefreq sitemap elements, no rel=next/prev planned as a fix, no hardcoded homepage canonical, no dead-URL redirects to the homepage, and no llms.txt-as-strategy.
    Criterion: WHEN the inversion pass distributes SEO requirements, THE PLAN SHALL NOT contain any task whose mechanism is on this banned list.

## Task seeds

- [ ] GP-xxx Implement indexation control layer (robots.txt plus env noindex guard)
  - Files: app/robots.ts, lib/seo/env-guard.ts, .github/workflows/ci.yml
  - Acceptance: prod robots output has no "Disallow: /" under "User-agent: *"; output contains an absolute "Sitemap:" line; guard emits noindex only when DEPLOY_ENV is not "production"; CI job fails when prod build output contains "noindex"
  - Verify: node scripts/check-robots.mjs && test -f .next/server/app/index.html && ! grep -q noindex .next/server/app/index.html
  - Requirements: R-SEO-4, R-SEO-5
- [ ] GP-xxx Build sitemap generator from the content model
  - Files: app/sitemap.ts, lib/seo/sitemap-source.ts
  - Acceptance: URL source query excludes noindexed and redirected entries; each entry has lastmod from the row's updated_at; no priority or changefreq keys; chunking activates above 50000 URLs
  - Verify: ! grep -Eq "priority|changefreq" app/sitemap.ts && node scripts/check-sitemap.mjs
  - Requirements: R-SEO-6, R-SEO-22
- [ ] GP-xxx Establish canonical model and single redirect layer
  - Files: next.config.js, lib/seo/metadata.ts, middleware.ts
  - Acceptance: metadataBase set to the canonical origin; exactly one redirect layer handles host/scheme/slash with 308; every template emits one absolute self-referencing canonical; no second canonical emitter exists
  - Verify: grep -q "metadataBase" lib/seo/metadata.ts && node scripts/check-canonicals.mjs
  - Requirements: R-SEO-8, R-SEO-9
- [ ] GP-xxx Template per-route metadata (title, description, OG, twitter)
  - Files: lib/seo/metadata.ts, app/(site)/*/page.tsx, app/og/route.tsx
  - Acceptance: every routable page exports unique title and description; og:title/type/url/image and twitter:card present per route; og:image URLs absolute HTTPS; OG route exports size and contentType with PNG output
  - Verify: node scripts/check-metadata.mjs --all-routes
  - Requirements: R-SEO-10, R-SEO-17
- [ ] GP-xxx Add server-rendered JSON-LD per template with content matching
  - Files: lib/seo/jsonld.ts, app/(site)/blog/[slug]/page.tsx
  - Acceptance: Article JSON-LD includes headline, image, datePublished, author (Person), publisher with logo; all dates ISO 8601; every schema fact maps to a rendered field; no AggregateRating anywhere; no FAQPage/HowTo/SearchAction types
  - Verify: ! grep -rEq "AggregateRating|FAQPage|HowTo|SearchAction" lib/seo/ app/ && node scripts/check-jsonld.mjs
  - Requirements: R-SEO-12, R-SEO-13
- [ ] GP-xxx Declare AI-crawler policy in robots.txt by bot purpose
  - Files: app/robots.ts, docs/seo-policy.md
  - Acceptance: policy table classifies training vs citation vs user-fetch bots; OAI-SearchBot, PerplexityBot, Claude-SearchBot and user-fetch bots allowed; any training-bot blocks are per-UA groups, not a blanket Disallow:/; no llms.txt requirement marked load-bearing
  - Verify: node scripts/check-robots.mjs --ai-policy
  - Requirements: R-SEO-14, R-SEO-22
- [ ] GP-xxx Wire SEO regression suite into CI
  - Files: tests/seo/snapshots.test.ts, scripts/check-links.mjs, .github/workflows/ci.yml
  - Acceptance: snapshot tests assert title, canonical, robots meta, and JSON-LD for each key template; build-integrity test fails on prod noindex or empty sitemap; broken-link check runs on internal links; no isBot or user-agent content branching in source
  - Verify: npm run test:seo && ! grep -rq "isBot(" app/ lib/
  - Requirements: R-SEO-20, R-SEO-5

## Self-audit rubric

Score the drafted SEO section 0-100. When I18N or FEEDS is dropped with a reason, redistribute its points proportionally across the remaining dimensions; never zero-and-keep.

- Crawlability and indexation control (14): full marks require the route-class indexation matrix, the five robots.txt constraints, the fail-safe env guard with its CI assertion, the content-model sitemap spec, and crawl-trap consolidation. (R-SEO-1, 4, 5, 6, 7)
- Rendering and content-in-HTML (13): full marks require a named rendering mode per indexable route, all signals in server HTML, real-href navigation, hard 404s, and no prerender-for-bots anywhere. (R-SEO-2, 3)
- On-page content and semantics (12): full marks require per-route title/description templating, single h1, landmarks, alt-text rules, and the E-E-A-T surface tasks. (R-SEO-10, 11)
- Canonicalization (11): full marks require the one-owner redirect layer, absolute self-referencing canonicals with metadataBase, and pagination never canonicalized to page 1. (R-SEO-8, 7)
- Structured data (10): full marks require per-template types with field-to-content-model mapping, entity grounding, the content-match ban, and zero restricted or removed rich-result types. (R-SEO-12, 13)
- AI and generative-engine visibility (9): full marks require the three-way bot policy table, the Google-Extended fact stated, llms.txt labeled aspirational, and answer-extractable template structure with machine-readable dates. (R-SEO-14, 15)
- URL architecture and edge config (8): full marks require the slug convention, redirect-map mechanism, correct framework status codes, and crawler-safe CSP/HSTS/WAF criteria. (R-SEO-9, 21)
- Core Web Vitals code budget (6): full marks require the never-lazy LCP rule, media dimensions, font strategy, and caching/splitting items attached to concrete tasks. (R-SEO-16)
- Social metadata (5): full marks require per-route OG/twitter tasks with absolute HTTPS images and the favicon/apple-touch-icon pair. (R-SEO-17)
- Internationalization (5, conditional): full marks require central hreflang generation with tested reciprocity, x-default, valid codes, and no IP auto-redirects; or a stated drop. (R-SEO-18)
- Feeds and installability (4, conditional): full marks require valid feeds with stable GUIDs and autodiscovery, hosted IndexNow key if planned; or a stated drop. (R-SEO-19)
- SEO observability (3): full marks require the CI snapshot suite, build-integrity assertions, single verification token, and the explicit no-cloaking rule in the Verification phase. (R-SEO-20)

Caps, stricter than the source auditor's visibility floor (one floor-dimension Critical holds seoauditor's overall at 69): if the drafted plan permits any of sitewide noindex reaching prod, CSR-only indexable content, user-agent content branching, a hardcoded homepage canonical, or blocking citation bots while targeting AI visibility, the section scores at most 59 regardless of the arithmetic. Below 85 total, revise before emission.

## Anti-patterns refused

- Sitewide deindexing shipped to prod: a Disallow:/ or inverted env guard noindexes the whole site at launch. Refusal: the guard task and its CI assertion are mandatory whenever environments split; the plan does not emit without them.
- CSR-only shell: primary content, title, and canonical exist only after client JS runs, invisible to every non-JS AI crawler. Refusal: no indexable route may be planned as CSR; the rendering mode column is required in the route matrix.
- Cloaking and prerender-for-bots: user-agent branching or rendertron-style middleware serving crawlers different HTML. Refusal: the no-cloaking rule is a named Verification must-have; any dynamic-rendering proposal is replaced with SSR/SSG.
- Canonical collapse: a hardcoded homepage canonical on every page, or a per-locale constant, folds the site into one URL. Refusal: canonicals are always self-referencing by construction in one shared metadata helper; a second emitter is a plan defect.
- Self-defeating AI invisibility: blocking OAI-SearchBot or Perplexity bots while shipping llms.txt and answer schema. Refusal: the bot policy table is checked for consistency with the stated AI-visibility goal before the section is accepted.
- llms.txt-as-strategy: treating llms.txt, an aspirational file that no major engine documents using, as the AI visibility plan. Refusal: llms.txt may appear only as an optional task explicitly labeled non-load-bearing; server-rendered HTML carries the requirement.
- Paper controls: noindex: robots lines, priority/changefreq, rel=next/prev, dead-URL redirects to the homepage, verification tokens for unowned properties. Refusal: R-SEO-22 bans them; the inversion pass drops any task built on one.
- Fabricated structured data: AggregateRating with no visible reviews, schema asserting facts absent from the page. Refusal: every schema field must name its content-model source; unmatchable fields are cut from the schema plan, not stubbed.
- Cargo-cult calibration: hreflang on a monolingual site, e-commerce schema on a docs site, indexation for an authed dashboard. Refusal: conditional dimensions activate only from project facts recorded in the plan, and an inactive one is dropped in the module disposition with its reason; noindexing private routes is recorded as correct.
- Platitude requirements: "improve SEO", "add meta tags", "optimize performance" as acceptance criteria. Refusal: every SEO acceptance criterion must name the exact artifact, the stack-specific mechanism, and a command that verifies served output; anything failing the substitution test is rewritten or removed.
