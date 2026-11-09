# Build-outcome evaluation

The behavioral matrix asks whether a plan has the intended structure. This
evaluation tests the product thesis: does building from a godplans plan leave
fewer expensive findings than building from a neutral control plan?

For each case the coordinator:

1. Generates a treatment plan and a no-skill control plan from matched briefs.
2. Gives each plan to the same fresh, no-skill builder model in an empty copy of
   the same fixture.
3. Runs the case verifier.
4. Runs the same fresh static godaudits pass against each built repository,
   with the input plan removed and arm names hidden from the auditor.
5. Compares active (open or accepted-risk) Critical and High findings,
   verifier status, and plan and build token cost, and refuses the comparison
   when the two audits report different godaudits engine or pack versions.

Example:

```bash
GODAUDITS_SKILL_DIR=/absolute/path/to/godaudits/skills/godaudits \
node scripts/eval-outcome.js \
  --case tenant-notes-api \
  --plan-runner evals/runners/codex.sh \
  --control-plan-runner evals/runners/codex-baseline.sh \
  --build-runner evals/runners/codex-builder.sh \
  --audit-runner evals/runners/codex-godaudits.sh \
  --output evals/outcomes/results/RUN
```

`GODPLANS_OUTCOME_BUILD_MODEL` and `GODPLANS_OUTCOME_BUILD_EFFORT` set the
builder's model and reasoning effort, and `GODPLANS_OUTCOME_AUDIT_MODEL` and
`GODPLANS_OUTCOME_AUDIT_EFFORT` set the auditor's. The model defaults to the
Codex configured default and the effort to `high`. `GODAUDITS_SKILL_DIR`
defaults to a sibling `../godaudits/skills/godaudits` checkout when one exists.

The output retains both plans, built repositories, verifier logs, complete
AUDIT.json and AUDIT.mdx artifacts, runner metadata, and generated
`SUMMARY.json` plus `SUMMARY.md`. The summary includes plan and build token
usage when the runners expose it. Regenerate an existing summary after runner
metadata changes with:

```bash
node scripts/outcome-summary.js --output evals/outcomes/results/RUN
```

A lower Critical or High count is evidence for the rewrite-prevention claim. A
tie or a loss must be published with equal prominence.

One case is directional evidence. Repeat across builders and product forms
before making a broad claim.

## Published directional result

The 2026-07-23 `tenant-notes-api` run measured the godplans 1.9.0 release
candidate with `gpt-5.6-sol` through an already authenticated Codex CLI. Both
arms passed the case verifier. Treatment had 0 Critical and 1 High finding;
control had 1 Critical and 4 High findings, for a -4 Critical plus High delta.
Treatment planning reported 11,236,025 cumulative input plus output tokens
versus 162,816 for control. No later godplans version has been re-measured, so
these numbers describe 1.9.0, not the current skill.

Read the method, cost, limits, and raw artifacts under
`results/2026-07-23-tenant-notes-api-codex/`.
