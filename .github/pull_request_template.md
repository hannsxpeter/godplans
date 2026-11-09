## Planning failure this prevents

<!-- Name the failure, not the improvement: what plan did godplans emit, what did it lack or get wrong, and what would an executing agent have done because of it? Or name the audit dimension this strengthens. "Makes it better" fails the substitution test (CONTRIBUTING.md). -->

## Eval case touched

<!-- The case under evals/cases/ (or evals/outcomes/cases/) that this adds or tightens, or the tests/*.sh regression test for installer, prompt, validator, lint, or harness behavior. If none, say why the change needs no regression evidence. -->

## Checklist

- [ ] Edited the canonical files under `skills/godplans/`, not the `.agents/skills/godplans`, `.claude/skills/godplans`, or `plugins/godplans/skills` symlinks.
- [ ] After changing SKILL.md, any reference module, the PLAN template, `validate-plan.sh`, or `plan-halflife.sh`: ran `npm run generate` (catalog, prompt, then context metrics), then `npm run check`, and committed what it rewrote.
- [ ] For a behavior change: a CHANGELOG entry under a new version heading, and `npm run version:sync` after bumping `package.json`.

## npm run check output

<!-- Paste the tail of `npm run check`, ending with the ok [test-suite] line. -->

```text

```
