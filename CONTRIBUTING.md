# Contributing to PC Doctor

Thanks for your interest in improving `PC Doctor - AI IT Support Agent`.

## Before You Start

- Be respectful and constructive in discussions.
- Open an issue first for major changes.
- Keep security and user safety as the top priority.
- Do not submit secrets, API keys, or personal data.

## Development Guidelines

- Keep changes focused and small when possible.
- Preserve supervised execution behavior (`YES`, `SKIP`, `ABORT`).
- For risky operations, require explicit confirmation.
- Add or update documentation when behavior changes.

## Documentation

- For **user-facing or significant** changes, update `README.md` and add bullets under `## [Unreleased]` in `CHANGELOG.md` (and `agent_prompt.md` if agent rules or procedures change).
- Contributors using **Cursor** can enable the project skill at `.cursor/skills/update-docs-on-significant-changes/SKILL.md` for a consistent checklist of what to sync (README, CHANGELOG, prompts, launcher messages).

## Pull Request Checklist

- [ ] Code builds/runs locally
- [ ] Existing behavior is not broken
- [ ] README or relevant docs are updated
- [ ] No secrets or sensitive data are included
- [ ] PR description explains what changed and why

## Security Issues

If you discover a security issue, please do not post full exploit details publicly.
Open an issue with minimal reproducible details and mark it as security-related.

## License

By contributing, you agree that your contributions are licensed under the
project license: GNU Affero General Public License v3.0 (AGPL-3.0).
