# External grading

This evaluation breaks the sibling-rubric loop. Judges receive one neutral
brief, two plans under arm labels A and B, and `RUBRIC.md`. Plan content is
passed verbatim, so a godplans plan still carries its own format (frontmatter,
task and requirement ids, `.godplans/` paths); `RUBRIC.md` tells judges not to
reward a tool name or file format. The criteria contain no godplans
requirement ids and do not descend from its domain modules.

Run at least five plan pairs through at least two judges from outside the
planning model family:

```bash
node scripts/eval-external.js \
  --matrix evals/results/RUN \
  --source-profile codex \
  --judge claude=evals/runners/claude-grade.sh \
  --judge gemini=evals/runners/gemini-grade.sh \
  --output evals/external/results/RUN
```

The runner receives a packet path (`packets/<case>.md`, which carries the
rubric and the `GRADE.schema.json` shape) and an output grade path
(`grades/<judge>/<case>.json`). It must disable godplans and sibling skills
for the judging turn. A judge label must be unique, ignoring case, and one
path segment (letters, digits, `.`, `_`, `-`), and the runner path may be
relative or absolute. The included adapters use their host CLI's existing
authentication and record the available customization-isolation mode.
`GODPLANS_GRADE_CLAUDE_MODEL` (default `sonnet`) and
`GODPLANS_GRADE_GEMINI_MODEL` (default `gemini-2.5-pro`) choose the judge
models, and each grade's `<case>.RUNNER.txt` records the model used. The
coordinator validates totals, unblinds only after every grade exists, and
publishes treatment and control means, preference counts, raw grades, and mean
absolute inter-rater score gap.

No provider credential is required by this repository. Maintainers may replace
the included adapters with any host runner that satisfies the two-argument
contract.

Five pairs and two raters are minimum evidence, not a statistical guarantee.
Publish the packets, blinding map, raw JSON grades, runner metadata, and summary
together.
