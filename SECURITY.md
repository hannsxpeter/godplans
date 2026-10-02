# Security Policy

## What this project is

godplans is a prompt-engineering package: markdown instructions, a POSIX sh
installer, Bash and Node.js maintenance and validation scripts, a vendored
stdlib-only Python helper (`skills/godplans/scripts/style-stats.py`), and
optional behavioral evaluation runners. The skill, installer, linter,
validator, and prompt builder make no network calls of their own and collect
no data. The exceptions are explicit: the release gate (`npm run release:check`
and the release-only `tag-release-parity` lint check) queries GitHub through
the authenticated `gh` CLI, and the validator's drift mode runs commands taken
from the plan (see below). The skill itself instructs agents to treat planning
as read-only.

The evaluation runners under `evals/runners/` invoke a model CLI only when a
maintainer explicitly runs a model-backed evaluation, and each reuses the
authentication its host CLI already has:

- Codex CLI: `codex.sh`, `codex-baseline.sh`, `codex-builder.sh`, and
  `codex-godaudits.sh`.
- Claude Code and Gemini CLI planning arms: `claude.sh`, `claude-baseline.sh`,
  `gemini.sh`, and `gemini-baseline.sh`, all through `vendor-cli.sh`.
- Claude Code and Gemini CLI blind judges: `claude-grade.sh` and
  `gemini-grade.sh`, through `vendor-grade.sh`.

## Threat model relevant to users

- **Skill-content injection.** A skill's text becomes standing instructions
  for your agent session. Review `skills/godplans/SKILL.md` before
  installing, as you should for any skill; this repository never asks the
  agent to bypass safety, exfiltrate data, or edit source during planning.
- **Installer.** `install.sh` writes only into the skill directories it
  targets (`~/.agents/skills`, `~/.claude/skills`, `~/.factory/skills`,
  `~/.cline/skills`, and `~/.codeium/windsurf/skills` globally, with
  `AGENTS_SKILLS_DIR` and `CLAUDE_SKILLS_DIR` overriding the first two, or a
  project's `.agents/skills`, `.claude/skills`, and `.github/skills` with
  `--project`), marks what it created, and refuses to replace or remove an
  unowned destination unless the user supplies `--force`. It never writes into the
  source checkout, so it leaves the tracked `PROMPT.md` alone, and a `--copy`
  install strips Python bytecode from the copy. It never elevates, curls, or
  evaluates remote content.
- **Drift mode executes plan commands.** `validate-plan.sh --drift-check PHASE`
  runs, with `sh -c`, the `Verify` commands of a sample of the phase's
  completed tasks and the phase checkpoint command, all taken from PLAN.mdx.
  A tampered plan therefore runs arbitrary commands on the executor's machine.
  Review plan diffs before running drift mode, as you would review a Makefile.
  Likewise, `plan-halflife.sh` runs the `validate-plan.sh` beside the plan
  (the plan's own `.godplans/validate-plan.sh`) when one exists, unless
  `GODPLANS_VALIDATOR` names another validator.
- **Evaluation runners.** The Codex runners run Codex with
  `--sandbox workspace-write` under a throwaway `HOME` and `CODEX_HOME`. The
  Claude and Gemini planning runners skip every permission prompt
  (`--dangerously-skip-permissions` and `--approval-mode yolo`) and are not
  confined to their temporary workspace, which is only their starting
  directory. Run them only on a disposable machine or account. The blind
  judges run Claude with no tools and Gemini in plan approval mode.
- **Supply chain.** Install from a pinned release tag or commit if your
  environment requires reproducibility:
  `git clone --branch vX.Y.Z https://github.com/hannsxpeter/godplans`, with
  `vX.Y.Z` replaced by a tag from the
  [releases page](https://github.com/hannsxpeter/godplans/releases).

## Reporting a vulnerability

If you find a way this skill's content or scripts could cause an agent to
take unsafe action, open a GitHub Security Advisory on this repository
(preferred) or a private report to the maintainer via GitHub. Please include
the harness (Claude Code, Codex, Cursor, other), the exact file and lines,
and a reproduction. Expect an acknowledgment within 72 hours.

Please do not open public issues for exploitable findings before a fix
lands.
