---
name: update-docs-on-significant-changes
description: >-
  After implementing user-visible or operational changes, updates project
  documentation (README, CHANGELOG, release notes, prompts) in the same
  workstream. Use when adding features, new scripts or flags, changing
  install/runtime behavior, security or contributor-facing updates, or when
  the user asks to keep docs in sync, refresh the changelog, or document a
  release.
---

# Keep documentation aligned with significant changes

## When to apply (triggers)

Apply this skill **before** finishing a task, or in the same commit/PR, when the change is **user-facing** or **operator-facing** in a way that a maintainer or user would reasonably expect the docs to mention.

**Update docs** when the change does any of the following:

- Adds, removes, or renames a script, subcommand, flag, env var, or file that users or contributors must know about
- Alters `install.bat` or launcher behavior (e.g. new step, new prompt, admin vs non-admin, resume/reboot flow)
- Changes the agent’s rules or startup instructions (`agent_prompt.md`, init text, or equivalent)
- Affects security, data handling, auth, or privacy
- Deprecates, breaks, or significantly changes a documented workflow

**You may skip doc updates** (or use a one-line code comment only) for:

- Refactors, renames, or test-only changes with no behavior change
- Typo/comment-only edits
- Internal formatting or dependency bumps that do not change how people run or use the app

If unsure, prefer a **short** CHANGELOG bullet under `[Unreleased]` over silence.

## Workflow (end of a significant change)

1. **Name the change** in one line (what a release note or user would care about).
2. **List doc surfaces** that are now wrong or empty (use the [Project doc map](#project-doc-map-pc-doctor) below as a checklist, not a mandatory edit every time).
3. **Edit** the minimum set of files so a new user or the next session’s agent is not misled. Prefer the same turn or PR; avoid leaving “docs TODO” without the user’s OK.
4. **CHANGELOG** (this repo): add items under `## [Unreleased]` in `CHANGELOG.md`—`### Added` / `### Changed` / `### Fixed` / `### Security` as appropriate, with concrete file or feature names.
5. **README**: update setup, “Running it,” file list, table of options, or troubleshooting if behavior or artifacts changed. Link to sections that already have detail; avoid duplicating the whole changelog.
6. **Release notes** (`RELEASE_NOTES_*.md` or similar) only when the user is cutting a version or explicitly maintaining those files; otherwise `CHANGELOG` + `README` is usually enough.

## Project doc map (PC Doctor)

| Surface | What to keep current |
|--------|----------------------|
| `README.md` | How to run, what gets installed, outputs folder, optional flows (e.g. post-restart resume), file tree for distribution |
| `CHANGELOG.md` | Notable `Added` / `Changed` / `Fixed` under `[Unreleased]` for anything release-worthy |
| `agent_prompt.md` | Behavior rules, safety, and user/agent instructions for new procedures |
| `install.bat` / `*.cmd` / `diagnose.ps1` | If user-facing messages or help text are part of the “contract,” align echo strings with README/prompts |
| `RELEASE_NOTES_v*.*.*.md` | Versioned highlights when the project ships a named release file |
| `SECURITY.md` / `CONTRIBUTING.md` | When the change affects reporting vulnerabilities or how to contribute |

If another markdown file is the “source of truth” for a feature, update that file instead of inventing a second long explanation elsewhere.

## Quality bar

- **Accurate**: match real flags, file names, and order of steps after the change
- **Minimal**: one sentence in CHANGELOG often beats a new README section; expand README when discoverability requires it
- **Consistent**: terminology matches existing docs (same name for the same button/script)
- **No policy drift**: if `agent_prompt` and `README` both describe a flow, they should agree; fix both in one go

## Examples (significant → doc action)

- **New** `register_reboot_resume.cmd` and `--post-restart` → `README` subsection + new bullets in `CHANGELOG` + `agent_prompt` if the agent must do something new; list new files in README file tree
- **Hostname check** in `install.bat` → `CHANGELOG` + `README` “portable / system report” sentence if it changes user-visible behavior
- **Bug fix** in diagnostics only, no new flags → `CHANGELOG` under `### Fixed` if it affects user-visible output; otherwise code comment is enough

## If the user explicitly says “no README”

Respect the project rule not to add unsolicited markdown, **except** when this skill applies: then update `CHANGELOG` at least for notable behavior changes, and ask in one line if a README note is also desired if there is a conflict with the user’s preferences.
