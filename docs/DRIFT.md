# Drift log

This log records the inconsistencies found in the 2026-10-01 review of godplans 1.13.0, and how 1.14.0 resolved each one or why it is still open. The review covered four areas: the docs against the code, the maintainer scripts against their documented behavior, the shipped plan scripts against `plan-format.md`, and repository hygiene, GitHub settings included. Drift costs more here than in most repositories, for two reasons. A planning agent follows whichever instruction it read last, so two files that disagree produce two behaviors. And an executor trusts whatever the validator lets through.

How drift is prevented from 1.14.0 on:

- **`domain-parity`** (lint) reads the domain list from `references/` and requires the same modules in the SKILL.md Phase 4 table, the validator's `%known_domain` and `%module_prefix`, the prompt build, the context metrics, the portable-prompt test, the template's applicability matrix, discovery's worked matrix, and the schema's applicability count. It also requires each module to define its requirements under its own prefix.
- **`description-parity`** (lint) requires `plugin.json` and the godplans entry in `marketplace.json` to carry the SKILL.md description exactly.
- **The lint self-test**, `tests/lint-selftest.sh`, runs in `npm test`. It proves that every check fails on an injected violation: it copies the tracked files and the untracked files git does not ignore, checks that the clean copy passes, then breaks one thing at a time.
- **Schema conformance.** `tests/validate-plan.sh` checks every PLAN.json sidecar it emits against `PLAN.schema.json`.
- **The roster-checked eval matrix.** `scripts/eval-matrix.sh --check`, run by `npm test`, refuses any difference between `evals/cases/` and `evals/cases-roster.txt`.
- **The macOS CI job** runs the test suite and every lint check with `/bin/bash` 3.2 and BSD awk, grep, sed, and find first on PATH.

Behind those: `scripts/lint.sh --all` now runs every check and reports every failure, and the files it scans come from git.

What stays hand-kept: counts in prose (README, ABOUT, CONTRIBUTING), lineage links, the GitHub About text, topics, and branch settings, and discovery's deferral lists. [MAINTAINING.md](../MAINTAINING.md) lists the in-repository ones where a change has to touch them, and step 10 of [RELEASING.md](RELEASING.md) checks the About text and topics.

## Contents

1. Contract and docs counts
2. Lineage links
3. Packaging and metadata
4. Tooling that failed to fail
5. Validator gaps
6. Budget

## 1. Contract and docs counts

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| README repository map vs SKILL.md | Called it "the 8-phase method"; SKILL.md has nine phases (Phase 0 to 7 plus 5b), and the 1.13.0 CHANGELOG said README documented nine stages. | The map says "the nine-phase method (Phase 0 to 7 plus 5b)", and ABOUT maps its nine numbered stages onto the phase numbers. No check reads prose counts. |
| README domain sentence and badge | Named 15 distinct areas, some as outcomes ("monitored", "hardened"), instead of the eighteen domains; the domains badge linked to Lineage. | The sentence lists the nineteen passes in Phase 4 order, and the badge links to How it works. No check; add-a-domain step 17 in MAINTAINING.md names both. |
| README slim-core list, `build-prompt.sh` core header | Both omitted compliance, which PROMPT.md inlines first. | Both now list compliance. `tests/portable-prompt.test.sh` asserts that the core header says "This slim core includes compliance,". |
| AGENTS.md, CONTRIBUTING.md vs lint | Said every reference module follows the six-section contract; the lint exempts the five contract modules. | Both say the 19 domain modules follow it and name the five exempt contract modules. `modules-complete` enforces it, and `domain-parity` uses the same contract list. |
| AGENTS.md, CONTRIBUTING.md vs `version-sync.js` | Left the README badge out of the version surfaces and said the linter checks them all; the badge is checked only by `version:check`. | AGENTS.md lists every surface and names `version:check`, `version-parity`, and `prompt-fresh`. MAINTAINING.md points at the surface list in `version-sync.js` as authoritative. |
| `evals/README.md`, README vs `eval-matrix.sh` | Said the matrix "rejects fewer than ten cases" while the script required exactly eleven, and prose said "eleven cases". Adding a twelfth case would have failed `npm test`. | The case set is `evals/cases-roster.txt`. `eval-matrix.sh` refuses any difference from the case directories in either direction, and the prose says "every case in `evals/cases-roster.txt`". `tests/eval-harness.sh` runs `eval-matrix.sh --check` and covers an extra, a dropped, and a duplicate case. |
| `evals/README.md` vs the runners | Said the Claude and Gemini runners require provider API keys; the runners and the same file say they reuse the host CLI's authentication. | The file states host-CLI authentication and the isolation mode each runner records in RUNNER.txt. No check reads it. |
| docs/ABOUT.md evaluation paragraph | Named five behaviors while the matrix had eleven cases. | The paragraph names the modes and the risks the cases cover, without a fixed count. |
| docs/ABOUT.md siblings section | Promised the auditors' reports "should come back clean", which contradicts its own section on what audit-aware does not mean. | It now says to expect fewer preventable findings, not zero. |
| CONTRIBUTING.md change steps | Ran `npm run check` before rebuilding the prompt, so the check failed on `prompt-fresh`. It also listed too few rebuild triggers and no metrics step. | `npm run generate` (catalog, prompt, metrics) runs before `npm run check`, and the trigger list covers the template, the validator, and `plan-halflife.sh`. |
| docs/RELEASING.md | The steps disagreed on who writes the CHANGELOG entry, and nothing refused the `release:prepare` placeholder line. | Step 1 runs `release:prepare`, and the next step replaces the stub body. `release-check.sh` refuses the exact stub line, and `tests/release-tooling.sh` covers it. |
| README, docs/ABOUT.md head-to-head evidence | Presented the build-outcome result without the godplans version it measured. | Both name godplans 1.9.0, gpt-5.6-sol, the Codex CLI, and 2026-07-23, and say that no later version has been re-measured. |
| `install.sh --help`, README vs the parser | Neither documented `--global`, and the README never said that Kilo and Goose are covered (the `--help` text already listed them under `agents`). | The README documents `--global` and says Kilo and Goose use `~/.agents/skills`. The `--help` usage block still omits `--global`, which matters only to override an earlier `--project`. |
| SECURITY.md vs the runners and validator | Named one runner, claimed no network calls, and omitted that drift mode runs commands taken from the plan. | It lists every runner. It says the Claude and Gemini planning runners skip permission prompts, are not confined to their workspace, and belong on a disposable machine or account. It says drift mode runs plan commands with `sh -c`, and that the release gate queries GitHub. |

## 2. Lineage links

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| README Lineage table, SKILL.md, docs/ABOUT.md, `references/ui.md` | Linked or named seven standalone auditor repositories that were folded into hannsxpeter/auditor-suite and deleted on 2026-07-14; every link returned 404. | README links to `auditor-suite/tree/main/skills/<name>`, and SKILL.md and ABOUT name auditor-suite. Since SKILL.md is inlined, PROMPT.md was regenerated (`prompt-fresh`). Open: `references/ui.md` still names `github.com/hannsxpeter/uiauditor` in its Lineage. No check follows links. |
| SKILL.md "descends from" | Omitted docdna and ADHD, which README and `doc-set.md` credit. | It names hannsxpeter/docdna (the documentation set) and UditAkhourii/adhd (the critic is not the author). |
| README, docs/ABOUT.md, `plugin.json` | Said "seven auditors" after auditor-suite shipped an eighth, productauditor, and no module inverted it. The skill count drifted with it: ABOUT said fifteen where README said sixteen. | `references/business.md` inverts productauditor as the nineteenth domain. README and ABOUT say eight auditors and seventeen source skills. `plugin.json` now carries the SKILL.md description (`description-parity`). No check reads the counts. |
| docs/ABOUT.md, README | The sibling-composition notes named neither godaudits nor auditor-suite, though the outcome evaluation depends on godaudits, and ABOUT said "All three siblings". | ABOUT links both and counts six siblings. README links auditor-suite in its Lineage section and still names godaudits without a link. |

## 3. Packaging and metadata

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| GitHub About (repository metadata) | Says "audit-proof", which the README FAQ and ABOUT explicitly deny. | Open. Changing public repository metadata needs the maintainer. No check compares it with `package.json`. |
| GitHub topics, homepage, wiki, branch settings | No gemini-cli or audit-aware topic, an empty homepage, an empty wiki left enabled, and head branches kept after merge. | Open; repository settings. |
| GitHub branch protection | `main` has no protection or ruleset, so the RELEASING.md step that merges without bypassing a failed required check is a convention, not an enforced rule. | Open; a repository setting. Both CI jobs ("release quality" and "stock macOS tools") are candidates for required checks. |
| `plugin.json`, `marketplace.json` vs SKILL.md | Five descriptions diverged. The plugin manifest's lineage stopped at 1.9-era sources and named the deleted repositories, and the marketplace entry claimed "every after-the-fact audit inverted". | Both now carry the SKILL.md description verbatim. `description-parity` fails on any difference, with a message saying to copy SKILL.md. The shorter `package.json` and marketplace `metadata` taglines still differ, and no check compares them. |
| SECURITY.md pinned-install example | Pinned `v1.12.2` while the release was 1.13.0, and was not a synced version surface, so it went stale twice. | The example is version-neutral (`vX.Y.Z`, with a link to the releases page), so it cannot go stale. |
| `package.json` and the npm tarball | Not marked private though never published. The tarball shipped self-checks that fail outside a checkout, and could ship untracked Python bytecode. | `"private": true`, and the `files` list excludes `__pycache__` and `*.pyc`. `tests/package-contents.sh` fails on a packed file git ignores (`npm test`) or does not track (`--tracked-only`, in `release-check.sh`). |
| `skills/godplans/scripts/build-catalog.js` | A maintainer-only generator shipped inside the skill. | Moved to `scripts/build-catalog.js`; `tests/build-catalog.sh` covers it. |
| `.gitattributes` (absent) | The validator's byte-identity check (`cmp -s`) depended on each contributor's `core.autocrlf`, and frozen evidence skewed the language stats. | `.gitattributes` sets `* text=auto eol=lf`, marks frozen evidence vendored, and marks PROMPT.md and the context metrics generated. `.editorconfig` added. |
| `.gitignore` | `*.log` silently dropped the raw eval logs that publication requires. Bytecode, editor state, `.claude/settings.local.json`, and `.claude/worktrees/` were not ignored. | Negations keep `*.log` under the three results trees. The missing patterns are added, with `.claude/` itself still tracked for its symlink. |

## 4. Tooling that failed to fail

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| lint `official-validator`, `release-check.sh` | Reported a skills-ref whose interpreter was deleted as "rejected skills/godplans", and looked on PATH before the documented repository venv. | Both resolve `SKILLS_REF_BIN`, then `.venv-skills-ref/bin/skills-ref`, then PATH, and probe `--version` first. Lint prints a visible `skip` when no validator is installed or an automatically found one cannot run. It fails when an explicit `SKILLS_REF_BIN` cannot run, or on a real rejection. The release gate fails in every case where the validator does not run. Covered by the lint self-test (stand-in validators) and `tests/release-tooling.sh`. |
| `scripts/lint.sh --all` | Under `set -e`, the first failing check stopped the run, so later checks never reported. | Each check runs in its own errexit subshell. A crash counts as that check's failure, every later check still runs, and the run ends with the list of failing checks. Self-test: a stand-in perl that crashes. |
| `scripts/lint.sh` arguments | Ran only its first check name and silently ignored the rest, unknown names included, and ran every check when `--verbose` came first. | It runs every named check and rejects an unknown, empty, or blank name before any check runs. `--verbose` is only a flag. Self-test cases pin each behavior. |
| lint `unicode-clean`, `json-valid` | Scanned ignored local state (`.godplans/`, `.claude/settings.local.json`), skipped `.py` and `.txt` files, and nothing checked JavaScript or Python syntax. | The file list is every tracked file plus every untracked file git does not ignore, with a name allowlist only when there is no `.git`. Any byte above 0x7F fails. `js-syntax` (`node --check`) and `python-syntax` (`ast.parse`, no bytecode) are new. The self-test covers ignored files and the no-git fallback. |
| lint `action-pins` | Missed the `- uses:` list-item form, so a floating action reference passed. | Accepts both forms and quoted references. Self-test case. |
| lint `symlinks-valid` | Passed when a projection was a regular file or a copied directory, and never checked `plugins/godplans/skills`. | Each projection must be a symlink that resolves to its target, including the plugin link. Self-test cases. |
| lint `description-length` | Read only the first line, so a folded YAML description measured 2 characters. | The description must be one double-quoted line, read with `JSON.parse` in `scripts/lint-parity.js`; folded, literal, plain, and continued forms fail. Self-test cases. |
| `tests/lint-regression.sh` | Its ignored-venv guard used a file name the lint never scanned, so it could not fail, and no test injected a violation per check. | The fixture is a name the lint scans. `tests/lint-selftest.sh` injects one violation for every check, including the release-only `tag-release-parity`. |
| CI, lint `shell-syntax` | CI ran only on Ubuntu, and `bash -n` under bash 5 accepts bash 4 constructs that stock macOS `/bin/bash` 3.2 cannot run. | The "stock macOS tools" job runs the suite and the full lint under bash 3.2 and BSD tools. `shell-syntax` greps for bash 4 constructs. |
| CI checkout and action pins | Checkout persisted credentials, pin comments named major tags that had since moved past the pinned commits, and nothing updated pins. | `persist-credentials: false`, exact version comments, and a weekly Dependabot update for GitHub Actions. `action-pins` still requires full SHAs. |
| Module and case lists | Kept by hand in several files with no registry check, so a new module could be wired into the prompt and still be impossible to mark applicable. | `domain-parity` for modules and the roster check for cases (see the top of this file). |
| `scripts/eval-matrix.sh` | One profile with a failing case aborted the whole matrix. | Each family records its own status, the summary is always attempted, and the command exits non-zero when any family failed. `tests/eval-harness.sh` covers it. |
| `scripts/eval.sh` | Dropped the last EXPECTATIONS line when it had no trailing newline, and printed a negative delta as `+-N`. | Reads the last line, and signs the delta explicitly. Covered by the harness tests. |
| `scripts/eval-outcome.js` | Reported a VERIFY.sh that could not run as the build failing verification. | A missing exec bit, a start error, or a signal is a harness error, and any other non-zero exit is a failed verification. A stale SUMMARY.json is removed before a rerun. `tests/evidence-harnesses.sh` covers it. |
| `release:prepare`, `version:sync` | Left the context metrics stale after every bump, and the CHANGELOG placeholder could ship. | `version-sync.js` rebuilds the metrics after the prompt, and `release-check.sh` refuses the exact stub line. `tests/release-tooling.sh` covers both. |
| `tests/portable-prompt.test.sh` | Rewrote the tracked PROMPT.md and left `PROMPT.full.test.md` in the repository. | Builds only into temporary paths and fails if it rewrote PROMPT.md. Lint `prompt-fresh` owns the comparison with the committed file. |
| `install.sh` | Rewrote the tracked PROMPT.md in the source checkout and swallowed errors, contradicting SECURITY.md's write scope. | The rebuild is gone. `tests/install-regression.sh` asserts that an install leaves the source PROMPT.md untouched and that a copy install strips bytecode. |

## 5. Validator gaps

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| Sidecar encoding, plan decoding | PLAN.json was written as Latin-1 when every non-ASCII character fell in U+0080 to U+00FF. Invalid UTF-8 in PLAN.mdx was accepted, and a BOM caused a cascade of errors. | PLAN.json is always UTF-8. Invalid UTF-8 or a BOM fails with one message. The schema checker decodes every sidecar as strict UTF-8. |
| `status: done` | Passed with unchecked tasks, and a regression test locked that in. | `done` requires every task and phase checked; the test now expects failure. |
| `[P]` tasks and waves | A `[P]` task could depend on a wave sibling. Disjointness compared raw strings, so backticks, notes, and directory paths slipped past. Wave order was never checked against dependencies. | All three fail: the sibling dependency, the shared file after path normalization, and a dependency in a later wave or a wave tag that goes backwards. |
| Documentation-set rows | The documented brownfield states (adopt, confirm, orphan) could not be written in a plan that validates. Malformed rows were skipped silently, and a required row could name a superseded task. | `present-current`, `present-elsewhere`, `present-drifted`, and `present-stub` are accepted states, and greenfield plans may claim only `present-elsewhere`. Malformed rows and superseded writers fail. |
| Module disposition | A semicolon inside a `dropped-by` reason broke parsing, so discovery.md's own example was rejected. A task could cite an excluded module's requirement, and "landed" accepted a mention in the frontmatter or the session log. | Clauses split only outside parentheses. A task citing a requirement of an excluded or deferred module fails, and a landed requirement must appear in the plan body outside the frontmatter, the session log, and the disposition block. Still not enforced: that landed plus dropped covers a module's whole catalog. |
| Task fields | A field wrapped onto continuation lines was truncated in validation and in PLAN.json, though the exemplar wraps fields. | A line indented four spaces continues its field unless it starts a list item, and executor Note lines are indented two spaces. |
| Banned Unicode | The class missed whole emoji and arrow blocks that `plan-format.md` bans. | The class covers those blocks. In U+2300 to U+23FF only the emoji code points are banned, so keyboard symbols such as U+2318 still pass. |
| Verify and Checkpoint verify | Blank, whitespace-only, or "Manual:" commands were accepted, and drift mode then passed on them. | All three fail. |
| Decision headings | A heading under `## Decisions` not in `D<n>` form skipped falsifier validation, and the exemplar's model decision used one. | Only `### D<n>: ...` and `### Assumptions ledger` are accepted; the exemplar is retitled. |
| Archetype confidence | `archetype: unknown` passed while the block named a Primary above the 0.45 floor. | At or above the floor, the frontmatter must name the Primary. |
| Template and plan-format vs validator | The template's own provenance paragraph, and the "digest algorithm" line plan-format.md asked for, both failed validation. | The paragraph is gone from the section, and plan-format.md no longer asks for the line. |
| Superseded tasks | Malformed superseded headings were ignored, and a phase whose tasks were all superseded was rejected. | Malformed headings fail. A fully superseded phase is valid, and the schema allows its empty task list. |
| Schema vs validator | Dates were checked by pattern only (`2026-13-45` passed), the schema was weaker than the validator, and no test compared a sidecar with the schema. | Dates must be real calendar dates. The schema has patterns for dates, revisions, and ids. `tests/validate-plan.sh` checks every emitted sidecar with `tests/lib/plan-schema-check.js`. The schema still has no enum of domain names. |
| Fenced code | Section, task, and row scans read inside code fences. | Fenced code is not structure. An unclosed fence is reported once, and the rest of the file is still checked. |
| Frontmatter | Values were read as raw text, so quoted values failed or kept their quotes. | One layer of matching quotes and a trailing comment are stripped. |
| Dead branches, decision order | Unreachable branches sat in the validator and `build-catalog.js`, and PLAN.json sorted decisions as strings (D1, D10, D2). | The dead code is removed, and `build-catalog.js` checks each document owner against `%known_domain`. Decisions sort numerically. |
| `style-stats.py` | Counted bodyless declarations as functions that ran into the next block, counted some identifiers twice, and counted Python comparisons as assignments. | Fixed; `tests/style-stats.sh` covers each case. |
| `references/style-genome.md` task seed | Tells executors to run `python3 scripts/style-stats.py`, a path that exists in the skill but not in the planned project or the portable prompt. | Open. |
| PROMPT.md, `plan-halflife.sh` | The prompt still pointed at `scripts/plan-halflife.sh`, and the inlined script required an executable sibling validator. | Both prompt modes rewrite the command to `bash .godplans/plan-halflife.sh ...`, and their headers say to save the script beside the validator companion. The script checks the file exists and runs it with `bash`. `tests/portable-prompt.test.sh` asserts both prompts. |
| SKILL.md phase order vs `plan-halflife.sh` (found while fixing the validator) | Phase 1 replaced the companion before the replan's half-life step ran, so a newer validator measured an older plan and rejected it. | The half-life measurement runs in Phase 0. The script uses `GODPLANS_VALIDATOR`, else the plan's own `.godplans/validate-plan.sh`, else its sibling, and names `GODPLANS_VALIDATOR` when its validator rejects the plan. |

## 6. Budget

| Where | Drift | Resolution and the check that now prevents it |
|---|---|---|
| SKILL.md description | 987 of the 1024 characters the Agent Skills spec allows, too little room to add a domain to its enumeration. | To add "business (pricing, entitlements, billing, metrics, feedback)" and the "product plan" trigger, 1.14.0 dropped "for a software project", the "idea to plan" trigger, and the gloss after "plan theater". The description is 990 characters. `description-length` fails above 1024, and MAINTAINING.md step 6 says to cut elsewhere first. |
| `tests/portable-prompt.test.sh` vs PROMPT.md | 1.12.1 set the gate at 337000 bytes. The 1.14.0 validator fixes (about 3.6 KB of inlined checks) and the business wiring (about 1.5 KB) pushed the core past it. | About 2.2 KB was cut first: the Phase 5b list became a pointer to the exemplar gate it duplicated, and the plan-format checks summary was regrouped. The gate then moved to 347923 bytes, which left 7053 bytes of headroom at the raise, under the smallest core module (compliance, 7070); later 1.14.0 review fixes used part of it, and headroom still stays under that module. The test fails above the budget, and its comment records each raise and, from 1.12.1 on, what was cut first. |
