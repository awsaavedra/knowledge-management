# Changelog

Notable changes to the knowledge-management tool. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); versions are git tags.

## Unreleased

### Added
- `okm pod <link|file>` — podcast capture that resolves a Spotify/Apple/RSS link (or generic episode page) to the show's RSS feed for title, show, `itunes:episode`, and `pubDate`, and embeds an existing transcript when the feed publishes `<podcast:transcript>` (VTT/SRT/Podcast-Index-JSON). Local `.srt`/`.vtt`/`.txt` files import verbatim; raw media → metadata scaffold.
- `okm video <link|file>` — video/lecture capture; YouTube metadata via `yt-dlp`, captions via `youtube-transcript-api`. Replaces `okm yt`.
- Media notes use the convention `{format}-{Channel}-{Title}[-{episode}]-{YYYY-MM-DD}.md` (PascalCase fields, ISO publish date), e.g. `podcast-DanielleNewnhamPodcast-RivaTezOnGeniusManiaAndTheImpactOfCancelCulture-99-2024-01-01.md`.
- `docs/test.md` — manual test plan for `okm today` (weekly note), `okm pod`, and `okm video`.
- `okm distill <note>` — AI bullet summary written alongside a note (`--model claude|ollama`).
- shellcheck lint gate in CI (`--severity=warning` across `bin/okm`, `scripts/`, `scripts/lib/`, and the pre-push hook).
- `docs/CHANGELOG.md` and `docs/SECURITY.md`.
- `tools/` — home (with charter README) for MCP servers and other vault tools/integrations.
- `setup-km.sh` first-run prompt for your editor (vim/nvim); the choice is saved to gitignored `.km-editor` and honored by `env.sh`.

### Changed
- `okm today` now opens **this week's** note — `YYYY-MM-DD-weekly.md` (Monday start, Mon–Sun) — instead of a per-day file.
- Default `EDITOR` is now `vim` (was `nvim`). The editor chosen at setup is saved to `.km-editor` and is authoritative in the project env — it overrides an `EDITOR` inherited from your shell rc (so a global `export EDITOR=nvim` won't beat your vim choice). Per-command override still works: `EDITOR=emacs okm today`.
- Neovim is now **opt-in**: `setup-km.sh` only downloads the nvim binary, links its config, and bootstraps plugins when `nvim` is chosen. `verify-km.sh` skips the nvim checks for vim users. vim is the lightweight default.
- Media ingest (`pod`, `video`, `distill`) lives in `scripts/lib/media.sh`.

### Removed
- `okm spot` (Spotify capture, incl. music track/album/playlist notes) and `okm yt` — superseded by `okm pod` and `okm video`. Templates `spotify-episode-template.md`/`spotify-track-template.md` removed; `yt-template.md` → `video-template.md`.
- whisperX / any self-transcription path. **okm pulls transcripts that already exist at the source; it never transcribes audio itself.** Sources without a published transcript get a scaffold.
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
