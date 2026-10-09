# UI implementation planning module

Plans how the user interface gets built as code so that a post-hoc UI implementation audit scores top marks by construction. The orchestrator loads this module during the domain pass for any archetype that renders a UI (saas-dashboard, marketing-site, mobile-app, component library); headless api-service, cli, and ml-pipeline archetypes exclude it with a stated reason. Boundaries: experience design, journey heuristics, and copy tone belong to ux.md; generic code quality belongs to code-quality.md and the bundle budget to build.md (R-BUILD-15); all security sinks (dangerouslySetInnerHTML, v-html, innerHTML, CSP) belong to security.md and may only be cross-referenced here, never planned here.

## Lineage

This module inverts uiauditor (github.com/hannsxpeter/auditor-suite/tree/main/skills/uiauditor), the read-only UI implementation auditor grounded in WCAG 2.2, WAI-ARIA APG, Core Web Vitals, MDN, and ECMA-402. What carries over: its ten dimensions and their weights (accessibility highest under every combination), its accessibility floor (any A11Y Critical drops the whole audit one band below any other Critical), its eight enumerated always-Critical conditions, its paper-control hunt (declared-but-unwired protections are findings, not credit), its calibrate-to-paradigm rule (Tailwind config IS the token source; React Native is judged on native primitives, not semantic HTML), and its ban on platitudes. Where the auditor finds keyboard lockouts after the fact, this module makes the plan specify native elements, wired states, and zero-count verification greps before the first component exists.

## Decisions to force

Hardest to reverse first. Each must land in the plan's Decisions section as a grounded decision, a flagged hypothesis with a validation plan, or a named open question with a recommended default.

1. Rendering model: SPA, SSR, RSC, islands, or static? Hard to reverse because hydration strategy, data fetching, LCP shape, and every client/server component boundary descend from it; migrating models rewrites the routing and data layer. Options: static or islands for content-led sites, SSR/RSC for data-led apps, SPA only when an app shell genuinely needs it. Default: server-first (SSR/RSC or islands), client interactivity opted in per component, never at a route root.
2. Styling model and token source of truth: Tailwind config, tokens.json, theme.ts, or CSS custom properties? Hard to reverse because the token source defines what "on scale" means for every color, space, and size ever written; switching models touches every component file. Options as listed; exactly one source wins. Default: the framework-native choice (Tailwind config if Tailwind, CSS custom properties otherwise), with a written no-raw-literals rule.
3. Design system: consume an existing one or author primitives? Hard to reverse because component API surface propagates into every feature; swapping later is a full-UI migration. Options: consume (Radix, shadcn/ui, Material, platform-native), author a thin primitive layer, or hybrid. Default: consume headless primitives and own the styling, unless the archetype is a component library.
4. Localization: in scope from day one or explicitly excluded? Hard to reverse because retrofitting string externalization touches every user-facing string including alt and aria-label, and layouts sized for English clip German. Options: full i18n now, catalog-only now (externalize strings, single locale), or excluded with reason. Default: catalog-only now if any multi-locale future is plausible; excluded with reason otherwise.
5. Native or cross-platform surface: web only, React Native/Expo, or react-native-web shared code? Hard to reverse because primitives differ at the root (Pressable vs button, FlatList vs ul); web assumptions baked into shared components are a rewrite. Default: web only unless the product requirement names a native surface; if shared, plan platform branches explicitly.
6. Web Components and shadow DOM: used or not? Hard to reverse because token plumbing, slot semantics, and focus delegation across the shadow boundary must be designed in, not patched on. Default: no shadow DOM unless embedding into foreign pages is a requirement.
7. Theming and dark mode: shipped, planned-for, or excluded? Hard to reverse because a retrofit means auditing every color in the codebase; half-hardcoded themes are the named decorative-token failure. Default: if any theming is plausible, route all colors through tokens now and set color-scheme, even if only one theme ships.
8. Overlay primitive: one shared dialog/drawer/popover component or per-feature implementations? Hard to reverse in practice because focus management bugs multiply per copy and converge only through a painful consolidation. Default: one shared primitive built on native dialog with showModal(), portal-rendered, before any feature needs it.

## Plan requirements

R-UI-1. PLAN.mdx must declare the UI stack contract as decisions: framework, rendering model, styling model, the single design-token source, the design system consumed or authored, whether Web Components/shadow DOM are used, and the UI paradigm and maturity target.
Criterion: WHEN the UI domain is applicable, THE PLAN SHALL record all seven stack-contract facts in the Decisions section before the first UI task is defined.

R-UI-2. PLAN.mdx must state the native-element-first rule: buttons are button, links are a[href] (navigation vs action decides which), inputs are native, disclosure is details/summary, modals are dialog opened with showModal(); div/span reconstructions of interactive controls are banned.
Criterion: WHEN any task creates interactive controls, THE PLAN SHALL include the native-element-first rule and a Verification task whose acceptance is a zero count of onClick handlers on div/span elements.

R-UI-3. PLAN.mdx must define the accessible-name and labeling contract: every control class has a named accessible-name source (visible text, aria-label, aria-labelledby, or wrapping label); form fields get programmatic labels (never placeholder-only or tooltip-only); images get an alt policy (informative alt text, decorative aria-hidden, image SVGs role=img with a name); load-bearing media gets captions or transcripts.
Criterion: WHEN forms or media appear in scope, THE PLAN SHALL specify the name source per control class and the alt/captions policy, each tied to a task with a grep-verifiable acceptance such as "count of input elements without an associated label is zero".

R-UI-4. PLAN.mdx must set the ARIA and keyboard discipline: ARIA only where a native element does not suffice, widget roles always carrying their mandatory states (tab with aria-selected, checkbox with aria-checked), all ID references resolving, no aria-hidden on or wrapping focusables, APG keyboard models (arrows, Home/End, Escape) named for every planned custom widget, no positive tabindex anywhere, and a skip link first in the tab order.
Criterion: WHEN a custom widget is planned, THE PLAN SHALL name its APG pattern and keyboard model in the task acceptance, and a Verification task SHALL assert a zero count of positive tabindex values.

R-UI-5. PLAN.mdx must plan overlay focus management as one shared primitive: initial focus set on open, focus trapped while open, focus restored to the trigger on close, native dialog with showModal() or role=dialog plus aria-modal, Escape dismisses, rendered through a portal; SPA route changes move focus to the new content.
Criterion: WHEN any dialog, drawer, popover, or menu is in scope, THE PLAN SHALL contain a shared-overlay-primitive task that every later overlay task depends on, and SHALL ban dialog.show() for modal use.

R-UI-6. PLAN.mdx must plan focus visibility globally: a :focus-visible style in the design system, a ban on outline:none or box-shadow:none on :focus without a visible replacement, and a check that no reset or later cascade rule strips it.
Criterion: WHEN global styles are planned, THE PLAN SHALL include a :focus-visible baseline task with acceptance "no outline:none without adjacent replacement styling".

R-UI-7. PLAN.mdx must plan motion preferences: all animation gated by prefers-reduced-motion, animating transform and opacity only (never width, top, or margin), and pause/stop/extend controls on any auto-advancing content (carousels, tickers, auto-dismiss toasts).
Criterion: IF the plan includes any animation or auto-advancing content, THE PLAN SHALL gate it behind prefers-reduced-motion in a task acceptance and SHALL give auto-advancing surfaces an explicit pause control.

R-UI-8. PLAN.mdx must plan status messaging and shell basics: form errors surfaced via aria-describedby plus aria-invalid, aria-live or role=status regions wired to the exact code paths that update status text, semantic input types with autocomplete tokens and inputmode, html lang set, and a viewport meta that never blocks zoom.
Criterion: WHEN forms or async status exist, THE PLAN SHALL wire error and status surfaces to real state in task acceptances, and a Verification task SHALL assert a zero count of user-scalable=no and maximum-scale=1.

R-UI-9. PLAN.mdx must define document and heading structure per route: one h1, no skipped heading levels, a single main with header/nav/footer landmarks and no content stranded outside a landmark, valid nesting (no interactive-in-interactive, no duplicate ids), per-route descriptive titles, and charset/viewport/lang/favicon/manifest in the shell.
Criterion: WHEN routes are enumerated, THE PLAN SHALL assign each route an h1 and title in its task acceptance and SHALL define the landmark skeleton once in a shell task.

R-UI-10. PLAN.mdx must choose the styling architecture: the cascade strategy (@layer, CSS modules, or scoped styles), !important banned as a mechanism, a z-index scale instead of magic numbers, logical properties (margin-inline, inset-inline-start) for RTL safety, Flexbox/Grid as the layout primitives (no float or absolute-position scaffolding), and print styles when document/report/invoice surfaces exist.
Criterion: WHEN the styling model is declared, THE PLAN SHALL name the cascade strategy and z-index scale as decisions, and IF report-like surfaces exist THE PLAN SHALL include an @media print task.

R-UI-11. PLAN.mdx must mandate the component state-matrix convention: every data-fetching or mutating view designs loading, empty, error, AND success branches wired to real state (no declared-but-never-rendered branches); controlled inputs always paired with onChange; stable non-index keys on reorderable/filterable lists; overlays through portals; error boundaries around data-driven trees; hydration directives chosen deliberately (client:visible or client:idle below the fold; use client never at a route root).
Criterion: WHEN a view fetches or mutates data, THE PLAN SHALL list all four state branches in that task's acceptance, and a Verification task SHALL assert a zero count of key={index} on mutable lists.

R-UI-12. PLAN.mdx must set the responsive contract: mobile-first, reflow to one column at 320 CSS px with no horizontal scroll (WCAG 1.4.10), fluid max-width containers instead of fixed pixel widths, breakpoints coherent and above content min-widths, width/height or aspect-ratio reserved on all images, iframes, embeds, and late-injected slots, touch targets at least 24x24 CSS px, no hover-only affordances, click/keyboard alternatives to drag, rem/em for resizable text, and safe-area insets on notched devices.
Criterion: WHEN layout tasks are planned, THE PLAN SHALL state the 320px reflow requirement and dimension-reservation rule as task acceptances, not as aspirations in prose.

R-UI-13. PLAN.mdx must set the render-path performance plan: the likely LCP element identified per key route and prioritized (fetchpriority=high or the framework priority prop, never lazy-loaded above the fold), critical fonts preloaded with font-display, heavy below-fold work code-split, below-fold images loading=lazy, long lists virtualized, and heavy synchronous work kept off event handlers. The plan states that CWV numbers remain Suspected until measured in a real environment; it plans the risk away, it does not claim the metric.
Criterion: WHEN key routes are enumerated, THE PLAN SHALL name each route's expected LCP element and its prioritization in a task acceptance, and SHALL NOT assert numeric CWV outcomes as facts.

R-UI-14. PLAN.mdx must establish token discipline: one design-token source of truth, a no-raw-literals rule (no raw hex/rgb, no arbitrary pixel spacing, no arbitrary Tailwind values like w-[327px] off the configured scale), and a reuse-the-primitive rule (no hand-rolled duplicates of an existing component; no importing the DS Button then restyling it inline per use).
Criterion: WHEN the token source is declared, THE PLAN SHALL include a Verification task grepping for raw hex literals and arbitrary-value utilities outside the token source, with an expected count of zero.

R-UI-15. PLAN.mdx must plan theming end to end when theming or dark mode is in scope: every color routed through tokens that fully swap under the theme, color-scheme set, no subtree bypassing the theme provider; IF shadow DOM is used, the plan states how tokens cross the shadow boundary (custom properties inherited through :host, ::part surfaces named).
Criterion: IF theming is planned, THE PLAN SHALL require the dark theme to swap every color token in a task acceptance, refusing half-hardcoded themes by construction.

R-UI-16. PLAN.mdx must plan the asset pipeline: modern image formats with srcset/sizes decided at authoring time, per-icon imports or a sprite (never whole-library icon imports), SVGs optimized (no editor cruft, no embedded rasters), fonts subset and preloaded with font-display, a complete favicon/app-icon/manifest set, and iframes carrying title, sandbox, and loading=lazy.
Criterion: WHEN assets are in scope, THE PLAN SHALL state the image format and icon import strategy as decisions and give the shell task a favicon/manifest acceptance.

R-UI-17. PLAN.mdx must plan localization before strings are written when i18n is applicable: all user-facing strings including alt and aria-label in a message catalog from day one, ICU or Intl.PluralRules pluralization (never if n === 1), Intl.DateTimeFormat/NumberFormat for dates/numbers/currency, dir derived from locale with directional icons mirrored, layouts sized for 30 percent text expansion, no text baked into images.
Criterion: IF i18n is applicable, THE PLAN SHALL include a message-catalog task that precedes all feature UI tasks; IF not applicable, THE PLAN SHALL drop R-UI-17 in the module disposition (`dropped-by archetype`) with the reason.

R-UI-18. PLAN.mdx must plan native primitives when a native or cross-platform surface exists: Pressable/Button/TextInput over tap-handler Views, accessibilityLabel/Role/State on every custom control, FlatList or SectionList with a stable keyExtractor (never .map() inside ScrollView), safe-area insets, explicit Platform.select branches where behavior differs, and a ban on web-only assumptions (div, CSS hover, px literals) in shared code.
Criterion: IF a native toolkit is in scope, THE PLAN SHALL carry these as task acceptances including "zero .map() renders inside ScrollView"; IF not, THE PLAN SHALL drop R-UI-18 in the module disposition (`dropped-by form`) with the reason.

R-UI-19. PLAN.mdx must ban paper controls in its own text: no declared-but-unwired protections anywhere in the plan (a spinner not tied to a pending state, an aria-live region nothing writes to, tokens declared while components hardcode literals, a skip link to a missing id, a dark theme half-hardcoded). Every planned protection names its wiring and a mechanical check.
Criterion: WHEN any protection is planned, THE PLAN SHALL pair it with a wiring acceptance phrased as a countable condition (for example "count of unlabeled inputs is zero"), never as an intention.

R-UI-20. PLAN.mdx must trace the eight always-Critical audit conditions to tasks: keyboard lockout on a load-bearing control, core control with no accessible name, focus trap with no escape, zoom disabled, load-bearing media without captions/transcript, accessibility theater on a load-bearing surface, no reflow at 320px, and a load-bearing form broken at implementation level (frozen controlled input, submit losing input). Each maps to at least one task acceptance, and the final Verification phase includes a UI sweep task running the zero-count greps.
Criterion: WHEN the Verification phase is written, THE PLAN SHALL contain a UI sweep task whose acceptance enumerates zero-count checks covering all eight always-Critical conditions applicable to the project.

R-UI-21. PLAN.mdx plans WCAG 2.2 Level AA pointer and focus criteria: interactive targets meet the 24 by 24 CSS px minimum with adequate spacing (2.5.8 Target Size Minimum) and the stated mobile target contract; the focused element is never fully hidden by sticky headers or overlays (2.4.11 Focus Not Obscured, Minimum), and the focus indicator is never removed without an equivalent, with sufficient area and contrast (2.4.13 Focus Appearance as the AAA reference); and the conformance target (from ux.md decision 4, WCAG 2.2 AA by default, plus AODA or Section 508 where the audience requires it) is named.
Criterion: WHEN interactive UI is planned THE PLAN SHALL carry the conformance target ux.md decision 4 sets (WCAG 2.2 AA by default) and require target-size, focus-not-obscured, and focus-appearance acceptances with a Verify line (a grep or test for undersized targets, focus hidden under sticky elements, and removed or too-faint focus styles).

## Task seeds

- [ ] GP-xxx Declare the UI stack contract and build the document shell
  - Files: .godplans/PLAN.mdx, src/app/layout.tsx (or src/index.html)
  - Acceptance: html lang set; charset, viewport, per-route title wired; favicon and manifest referenced; zero occurrences of user-scalable=no or maximum-scale=1; single main landmark with header/nav/footer
  - Verify: grep -q 'lang=' src/app/layout.tsx && ! grep -rEn 'user-scalable=no|maximum-scale=1' src/
  - Requirements: R-UI-1, R-UI-8, R-UI-9
- [ ] GP-xxx Build the shared overlay primitive
  - Files: src/components/ui/overlay.tsx
  - Acceptance: native dialog opened with showModal() (or role=dialog plus aria-modal); focus set on open, trapped while open, restored to trigger on close; Escape dismisses; rendered via portal; zero uses of dialog.show() for modal surfaces
  - Verify: grep -En 'showModal|aria-modal' src/components/ui/overlay.tsx && ! grep -rn '\.show()' src/components/ui/
  - Requirements: R-UI-5, R-UI-11
- [ ] GP-xxx Establish global focus, motion, and token baseline
  - Files: src/styles/globals.css, tailwind.config.ts (or tokens source)
  - Acceptance: :focus-visible style defined; zero outline:none declarations without adjacent replacement; prefers-reduced-motion gate present; z-index scale defined as tokens; color-scheme declared
  - Verify: grep -n 'focus-visible' src/styles/globals.css && grep -n 'prefers-reduced-motion' src/styles/globals.css
  - Requirements: R-UI-6, R-UI-7, R-UI-10, R-UI-14
- [ ] GP-xxx Build the form field primitive with the full labeling contract
  - Files: src/components/ui/field.tsx
  - Acceptance: label associated via for/id or wrapping label; errors wired through aria-describedby plus aria-invalid to real validation state; type, autocomplete, and inputmode accepted and forwarded; no placeholder-only labeling path exists
  - Verify: grep -En 'aria-describedby|aria-invalid|autocomplete' src/components/ui/field.tsx
  - Requirements: R-UI-3, R-UI-8
- [ ] GP-xxx Scaffold the state matrix for data views
  - Files: src/components/views/*.tsx
  - Acceptance: every data-fetching view renders loading, empty, error, and success branches tied to real state; zero key={index} on mutable lists; error boundary wraps each data-driven tree; controlled inputs paired with onChange
  - Verify: ! grep -rEn 'key=\{(index|i)\}' src/components/
  - Requirements: R-UI-11, R-UI-19
- [ ] GP-xxx Wire the LCP and asset baseline per key route
  - Files: src/app/(routes)/*, public/
  - Acceptance: named LCP element per key route carries fetchpriority=high or the framework priority prop; zero loading=lazy above the fold; all img/iframe/embed carry width/height or aspect-ratio; critical fonts preloaded with font-display set
  - Verify: grep -rEn 'fetchpriority|priority' src/app/ && grep -rn 'font-display' src/styles/
  - Requirements: R-UI-12, R-UI-13, R-UI-16
- [ ] GP-xxx Run the UI verification sweep (final Verification phase)
  - Files: .godplans/PLAN.mdx
  - Acceptance: zero onClick on div/span; zero positive tabindex; zero unlabeled inputs; zero raw hex literals outside the token source; zero aria-hidden on focusable ancestors; sweep results recorded under the task
  - Verify: ! grep -rEn '<(div|span)[^>]*onClick' src/ && ! grep -rEn 'tabindex="[1-9]' src/
  - Requirements: R-UI-2, R-UI-4, R-UI-14, R-UI-19, R-UI-20

## Self-audit rubric

Score the plan's UI sections 0-100. A section below 85 gets revised before emission.

| Dimension | Points | Full marks require |
| --- | --- | --- |
| Stack contract and calibration | 8 | All seven stack-contract facts decided; requirements phrased in the project's own framework and styling model, not a generic ideal |
| Accessibility contract | 22 | R-UI-3 through R-UI-8 all present as task acceptances; all eight always-Critical conditions traced to tasks; no accessibility item left as prose intention |
| Semantic document structure | 12 | Native-element-first rule stated; per-route h1/title/landmark assignments; shell task with lang/charset/viewport/favicon/manifest |
| Styling architecture | 10 | Cascade strategy and z-index scale decided; logical properties mandated; print styles planned when report surfaces exist |
| Component state and correctness | 12 | Four-branch state matrix on every data view; keys, portals, error boundaries, and hydration directives in acceptances |
| Responsive contract | 10 | 320px reflow, fluid containers, dimension reservation, 24px targets, and pointer alternatives as countable acceptances |
| Render-path performance | 9 | LCP element named and prioritized per key route; fonts, code-splitting, lazy-loading, and virtualization planned; no CWV numbers asserted as fact |
| Design system and theming | 8 | One token source, no-raw-literals and reuse-the-primitive rules, full-swap theming when planned, shadow-boundary plumbing when applicable |
| Asset pipeline | 5 | Image format and icon import strategy decided; fonts subset and preloaded; favicon/manifest complete; iframe attributes planned |
| Conditional coverage | 4 | I18N and NATIVE each either planned per R-UI-17/R-UI-18 or dropped with a stated reason in the module disposition |

## Anti-patterns refused

- Paper controls: a protection declared but never wired (aria-live nothing writes to, spinner with no pending state, skip link to a missing id). Refusal: every planned protection carries a countable wiring acceptance or it does not enter the plan.
- ARIA over the wrong element: role=button patched onto a div instead of using button. Refusal: the plan fixes accessibility at the markup; native element plus real label, ARIA only where native does not suffice.
- The prop's promise: trusting a component named AccessibleModal to be accessible. Refusal: acceptances test behavior (focus moved, trap wired, Escape works), never the component's name.
- Happy-path-only views: data views planned with success branches only. Refusal: no data view task passes review without loading, empty, error, and success in its acceptance.
- Decorative tokens: a token file declared while components hardcode the literal next to it. Refusal: token adoption is verified by a zero-count grep for raw literals, not by the file's existence.
- Framework-blind calibration: holding Tailwind to a tokens.json bar or React Native to semantic HTML. Refusal: requirements are instantiated in the declared stack contract's own idiom.
- Platitude requirements: "improve accessibility", "make it responsive", "optimize performance" as plan lines. Refusal: every requirement names the exact change, the safe pattern, and the check that confirms it; platitudes fail the substitution test and are cut.
- Self-defeating performance: loading=lazy on the LCP hero, use client at a route root, a lazy route still statically imported. Refusal: the LCP element is named per route and its task acceptance forbids these patterns explicitly.
- Display-none responsive: a mobile experience that is only the desktop nav hidden. Refusal: the responsive contract demands reflow and adapted interaction at 320px, verified as an acceptance, not a hidden element.
- Suspected-as-fact: the plan promising CWV numbers, real pixel contrast, or screen-reader behavior it cannot verify statically. Refusal: runtime facts stay labeled as risks to plan away and measure later; the plan never claims a measurement it has not made.
