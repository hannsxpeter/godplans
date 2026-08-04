# Security Policy

## What this project is

godplans is a prompt-engineering package: markdown instructions, a POSIX sh
installer, Bash maintenance and validation scripts, and an optional behavioral
evaluation runner. The skill, installer, linter, validator, and prompt builder
make no network calls and collect no data. `evals/runners/codex.sh` invokes the
user's authenticated Codex CLI only when the user explicitly runs a model-backed
evaluation. The skill itself instructs agents to treat planning as read-only.

## Threat model relevant to users

- **Skill-content injection.** A skill's text becomes standing instructions
  for your agent session. Review `skills/godplans/SKILL.md` before
  installing, as you should for any skill; this repository never asks the
  agent to bypass safety, exfiltrate data, or edit source during planning.
- **Installer.** `install.sh` writes only into skill directories
  (`~/.agents/skills`, `~/.claude/skills`, and equivalents), marks what it
  created, and refuses to replace or remove an unowned destination unless the
  user supplies `--force`. It never elevates, curls, or evaluates remote content.
- **Supply chain.** Install from a pinned release tag or commit if your
  environment requires reproducibility: `git clone --branch v1.12.2`.

## Reporting a vulnerability

If you find a way this skill's content or scripts could cause an agent to
take unsafe action, open a GitHub Security Advisory on this repository
(preferred) or a private report to the maintainer via GitHub. Please include
the harness (Claude Code, Codex, Cursor, other), the exact file and lines,
and a reproduction. Expect an acknowledgment within 72 hours.

Please do not open public issues for exploitable findings before a fix
lands.
