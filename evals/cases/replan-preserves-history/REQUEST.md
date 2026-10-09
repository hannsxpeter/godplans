# Replan history evaluation

Use godplans in replan mode against the repository in this workspace.
The user now wants `--format json` as an alias for the already planned `--json`
flag. Reconcile the plan without changing, renumbering, or unchecking completed
GP-101. Add new work with a fresh task ID, bump `plan_version`, and record the
delta in the session log. Do not implement the feature.

Produce the complete updated godplans artifact set under `.godplans/`,
including `PLAN.mdx` and its executable validator companion.
