# Changelog

Notable changes to the knowledge-management tool. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags.

## Unreleased

### Added
- `okm pod <file> [title]` — dated note from a local audio/video file; transcribes via whisperX when installed, offline scaffold otherwise.
- `okm distill <note>` — AI bullet summary written alongside a note (`--model claude|ollama`).
- shellcheck lint gate in CI (`--severity=warning` across `bin/okm`, `scripts/`, `scripts/lib/`, and the pre-push hook).
- `docs/CHANGELOG.md` and `docs/SECURITY.md`.
- `tools/` — home (with charter README) for MCP servers and other vault tools/integrations.
- `setup-km.sh` first-run prompt for your editor (vim/nvim); the choice is saved to gitignored `.km-editor` and honored by `env.sh`.

### Changed
- `okm today` now opens **this week's** note — `YYYY-MM-DD-weekly.md` (Monday start, Mon–Sun) — instead of a per-day file.
- Default `EDITOR` is now `vim` (was `nvim`). The editor chosen at setup is saved to `.km-editor` and is authoritative in the project env — it overrides an `EDITOR` inherited from your shell rc (so a global `export EDITOR=nvim` won't beat your vim choice). Per-command override still works: `EDITOR=emacs okm today`.
- Neovim is now **opt-in**: `setup-km.sh` only downloads the nvim binary, links its config, and bootstraps plugins when `nvim` is chosen. `verify-km.sh` skips the nvim checks for vim users. vim is the lightweight default.
- Media ingest (`spot`, `yt`, `pod`, `distill`) extracted from `bin/okm` into `scripts/lib/media.sh`.
- Pre-push privacy guard now has a single tracked home — `scripts/hooks/pre-push`, activated via `core.hooksPath` by `okm port` — replacing the previous generated hook.
- Project structure simplified: root keeps `README.md` only; all other markdown lives under `docs/` (`CONTRIBUTING.md`, `ORCHESTRATOR.md`, `design.md`, `pvs.md`).

## v1.0.0 — 2026-06-09

Theme: fork-safety, edge-case bugs, tagging gaps. Specs and reproduction steps: `tests/v1_spec.bats`.

### Added
- `okm port <github-handle> [--no-push]` — fork topology setup: renames remotes so `okm sync` pushes to your private fork, and activates the pre-push privacy guard.
- Pre-push guard: refuses to push personal vault content (`public/`, `private/` notes and attachments) to the public tool repo or any public remote; private remotes are unrestricted.
- `okm crypt init` — opt-in git-crypt encryption for tracked notes.
- `okm rename-tag <old> <new>` — closes the tagging gap set, alongside exact-match `okm tagged`.

### Fixed
- Edge-case hardening across path safety (vault boundary via `realpath`), YAML escaping, and frontmatter handling — itemized as N/B codes in [`design.md`](design.md).

## v0 — 2026-03 through 2026-06 (untagged)

Initial system: core vault CLI (`today`, `new`, `capture`, `open`, `grep`, `files`, `recent`, `sync`, `tags`/`tag`/`untag`/`tagged`, `audit`, `obs`, `path`), PARA vault layout with a local-only `private/` mirror, media capture (`okm yt`, `okm spot`), Obsidian/Neovim/Vim integration, idempotent `setup-km.sh` + `verify-km.sh`, cron scanners, and the BATS regression suite.
