# Knowledge Management

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Disclaimer:** Content in this vault (financial, health, investment topics) is for educational purposes only. See [`docs/disclaimer.md`](docs/disclaimer.md).

Open-source knowledge OS for Obsidian users who live in Vim, Neovim, and the CLI — file-native, offline-first, continuously tested. Treats notes like code: plain Markdown, local files, terminal workflows, composable CLI. AI is optional and layered on top.

**Design principles:** instant startup; fresh local indexing; composable CLI (pipes, JSON, CI); non-destructive by default; no lock-in; small memorable command surface; editor/toolchain interop; local-first; lightweight; **ejectable** — every note readable with `cat`/`grep`/any CommonMark renderer, vault survives Obsidian disappearing (see [PVS](#portable-vault-specification-pvs-v10)).

---

## Stack

| Tool | Role | Installed by |
|---|---|---|
| Obsidian | GUI vault viewer, graph view | Flatpak (network revoked) |
| Neovim + obsidian.nvim | Terminal editor + vault integration | `bin/nvim` + lazy.nvim |
| lazygit | TUI git client | `bin/lazygit` via GitHub release |
| okm | Vault CLI | `bin/okm` (tracked in git) |
| yt-dlp / whisperX / spotdl | Media transcription | Python venv |
| ffmpeg / mpv | Audio/video processing | apt |
| ripgrep / fzf | Search and fuzzy picking | apt |

**Platform:** Debian/Ubuntu (apt + Flatpak), x86_64/arm64. macOS and other distros not yet supported.

---

## Setup

> **Fork first.** Fork and rename to `{your-github-handle}-knowledge-management`. Clone *your fork*, not upstream, so `okm sync` pushes to your private repo.

```bash
git clone --recurse-submodules <your-fork-url> ~/projects/knowledge-management
cd ~/projects/knowledge-management
export OBSIDIAN_VAULT="$HOME/my-vault"   # optional; default: sibling dir
bash scripts/setup-km.sh && source env.sh && bash scripts/verify-km.sh
bash tests/run_all.sh
```

Setup prompt: **Track notes in git?** (default: yes). Pre-set with `KM_TRACK_NOTES=true|false`. Logs at `~/.local/log/setup-km-*.log`.

**Manual steps:** SSH key (`ssh-keygen -t ed25519 -C km-vault`); git remote (`git -C "$(okm path)" remote add origin <url>`); optional git-crypt (see [git-crypt](#advanced-git-crypt)).

### Quickstart — verify editors

```bash
bash scripts/seed-demo.sh    # seed 11 demo-* files
okm files demo-              # confirm seeded files
bash scripts/seed-demo.sh --teardown   # clean up
```

**Obsidian:** `okm obs` → open `$(okm path)` as vault on first launch.
**Neovim:** `nvim public/daily/demo-$(date +%Y-%m-%d).md` — expect green `PUBLIC PARA · daily` winbar, TODO/FIXME/BUG highlights, `<leader>od/on/os/oo/ob` keymaps. If missing: `NVIM_APPNAME=km nvim --headless "+Lazy! sync" +qa`.
**Vim:** `EDITOR=vim okm open public/inbox/demo-meeting-notes.md` — expect green `PUBLIC PARA · inbox` statusline. (`bin/vim` wraps `vim -u config/vim/vimrc`; `bin/` is first on `$PATH` via `env.sh` so `vim` loads project config without touching `~/.vimrc`; wrapper used instead of `$VIMINIT` because nvim also honors it.)
**Private side test:** `nvim private/inbox/demo-private.md` → red `⚠ PRIVATE PARA` banner.

Seeded files:

| Folder | Files |
|---|---|
| `public/daily/` | `demo-YYYY-MM-DD.md` |
| `public/inbox/` | `demo-meeting-notes.md`, `demo-capture.md`, `demo-yt-example.md`, `demo-spotify-episode.md`, `demo-spotify-track.md`, `demo-podcast.md`, `demo-todo-summary-YYYY.md`, `demo-weekly-*.md` |
| `public/attachments/` | `demo-screenshot.png` (1×1 placeholder) |
| `public/archive/` | `demo-completed-project.md` |

---

## Workflow

| Editor | Launch | Notes |
|---|---|---|
| Obsidian | `okm obs` | First launch: open `$(okm path)` as vault |
| Neovim | `okm today` | Project config via `NVIM_APPNAME=km` |
| Vim | `EDITOR=vim okm today` | Project vimrc via `bin/vim`; sources `~/.vimrc` first |

- **Capture:** `okm today` (daily note) or `okm capture <text>` (timestamped)
- **Search:** `okm grep <pattern>` (content) or `okm files [pattern]` (paths)
- **Sync:** `okm sync [message]` — default commit message: `vault sync YYYY-MM-DD HH:MM:SS`
- **Test before merge:** `bash tests/run_all.sh`
- **Commit conventions:** one logical change per commit; ask before destructive ops or scope creep
- **Auto-activation:** `direnv allow .` (repo includes `.envrc`)

---

## Architecture

```
.
├── env.sh
├── bin/okm                         # vault CLI
├── config/nvim/                    # NVIM_APPNAME=km → ~/.config/km/
├── config/lazygit/ / config/mpv/
├── docs/ai-instructions.md         # AI assistant rules
├── docs/skills/                    # AI skills library
│   ├── README.md
│   ├── argumentation.md
│   ├── code-review.md
│   ├── debug.md
│   ├── delegation.md
│   ├── diagnostic.md
│   ├── distill-prompt.md
│   ├── research.md
│   ├── security.md
│   ├── software-engineering.md
│   └── transcripts.md
├── scripts/setup-km.sh             # install and configure
├── scripts/verify-km.sh            # post-install checks
├── scripts/todo-summary.sh         # PARA TODO scanner (cron)
├── scripts/weekly-tasks.sh         # weekly summary (cron)
├── scripts/compress-images.py      # PNG/JPG → WebP (cron)
├── tests/                          # BATS suite
└── venv/                           # Python venv (gitignored)

../knowledge-management/            # vault (override: $OBSIDIAN_VAULT)
├── public/
│   ├── daily/       # Areas — one file per day
│   ├── inbox/       # Projects — active notes and captures
│   ├── attachments/ # Resources — images, PDFs
│   └── archive/     # Archive — completed notes
└── private/         # Mirror of public/; AI-private; local-only
    ├── daily/
    ├── inbox/
    ├── attachments/
    └── archive/
```

Vault follows [PARA](https://fortelabs.com/blog/para/). `private/{daily,inbox,attachments,archive}/` mirror each public folder.

---

## Rules

- **Fork before sharing.** Work in your fork; `okm sync` pushes to whatever `origin` points at.
- **`private/` is local-only by default.** Excluded from git regardless of `KM_TRACK_NOTES`. Opt in with git-crypt.
- **Secrets never tracked.** `.gitignore` excludes `.env*`, `*.pem`, `*.key`, `*.crt`, `*credentials*`, `id_rsa*`, `id_ed25519*`.
- AI assistants don't read `private/` — see `docs/ai-instructions.md`.
- `okm grep/tags/files/tagged/recent` skip `private/` by default (`KM_INCLUDE_PRIVATE=1` to scan).
- Never touch user global configs (`~/.config/nvim`, `~/.zshrc`, etc.).
- **WSL2:** setup installs a Nerd Font to Windows fonts and may update Windows Terminal. Disable: `KM_INSTALL_FONT=0`.

---

## okm CLI

| Subcommand | What it does |
|---|---|
| `okm today` | Open/create today's daily note |
| `okm new <title>` | Create slugified note in `public/inbox/` with frontmatter |
| `okm capture [text]` | Timestamped quick-capture note |
| `okm spot <url>` | Create note from Spotify link (episode, track, album, playlist) |
| `okm open [path]` | Open a note or launch fzf picker |
| `okm grep <pattern>` | ripgrep across all `.md` files |
| `okm files [pattern]` | List `.md` paths, optionally filtered |
| `okm recent` | fzf picker over 200 recently modified notes |
| `okm sync [message]` | `git add -A` → commit → `pull --rebase` → push |
| `okm tags [note]` | List tags with counts, or tags for a note |
| `okm tag / untag` | Add/remove tags from frontmatter |
| `okm tagged <tag>` | List notes with a given tag |
| `okm audit` | Scan for PARA content, secrets, sensitive filenames |
| `okm obs` | Launch Obsidian GUI |
| `okm path` | Print vault path |

`okm new`, `capture`, `spot` accept `-t tag1,tag2`.

**Environment variables** (set by `source env.sh`):

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | `../knowledge-management` | Vault root |
| `OBSIDIAN_DAILY_DIR` | `public/daily` | Where `okm today` writes |
| `OBSIDIAN_NOTES_DIR` | `public/inbox` | Where `okm new`/`capture` write |
| `EDITOR` | `nvim` | Editor for note commands |
| `KM_TRACK_NOTES` | `true` | Track notes in git |

---

## Neovim

Config via `NVIM_APPNAME=km` → `~/.config/km/`. Global `~/.config/nvim` unaffected.

| Keymap | What it does |
|---|---|
| `<leader>od/on/os/oo` | Today / New / Search / Quick-switch |
| `<leader>ob/ot/op/og` | Backlinks / Template / Paste image / Open in Obsidian |

---

## Media Transcription

| Source | Command | Status |
|---|---|---|
| YouTube | `okm yt <URL>` | **Planned** |
| Spotify | `okm spot <URL>` | Shipped |
| Local audio | `okm pod <file> "Title"` | **Planned** |
| Summarise | `okm distill <note>` (Claude / Ollama) | **Planned** |

Tools: yt-dlp, spotdl, whisperX (large-v3-turbo), ffmpeg, mpv (`s` key → screenshot to `attachments/`).

---

## Templates

`public/inbox/templates/` — one canonical template per note type with a `<!-- Format Specification: -->` block.

| Template | Producer |
|---|---|
| `daily-template.md` | `okm today` |
| `note-template.md` | `okm new` |
| `capture-template.md` | `okm capture` |
| `yt-template.md` | `okm yt` (planned) |
| `spotify-episode-template.md` / `spotify-track-template.md` | `okm spot` |
| `podcast-template.md` | `okm pod` (planned) |
| `todo-summary-template.md` / `weekly-template.md` | cron scripts |
| `archive-template.md` | manual |

---

## Cron Jobs

| Schedule | Script | Output |
|---|---|---|
| 07:00, 12:00, 15:00 | `todo-summary.sh --output` | `public/inbox/todo-summary-YYYY.md` |
| 07:00, 12:00, 15:00 | `weekly-tasks.sh --output` | `public/inbox/weekly-DATE-to-DATE.md` |
| 17:00 | `compress-images.py` | PNG/JPG → WebP |

TODO → PARA: `TODO/FIXME/HACK/XXX` = Projects, `- [ ]` = Areas, `REVIEW:` = Resources.

```bash
# Replace $KM with project path
3 7 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 15 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
0 7,12,15 * * * /usr/bin/bash $KM/scripts/weekly-tasks.sh --output
0 17 * * *      $KM/venv/bin/python $KM/scripts/compress-images.py
```

---

## Git Sync

`okm sync [message]` — stages all, commits, rebases, pushes. Skips if no upstream.
Advanced: `lazygit -p "$(okm path)"` or `git -C "$(okm path)" <cmd>`.

---

## Advanced: git-crypt

Encrypts `public/daily/*.md` and `public/inbox/*.md` in the remote (AES-256-CTR). Plaintext locally, opaque on remote.

```bash
sudo apt install git-crypt && cd "$(okm path)" && git-crypt init
git-crypt export-key ~/git-crypt-km.key   # BACK THIS UP
printf 'public/daily/*.md filter=git-crypt diff=git-crypt\npublic/inbox/*.md filter=git-crypt diff=git-crypt\n' >> .gitattributes
git add .gitattributes && git commit -m "configure git-crypt"
# New machine: git clone <url> && git-crypt unlock ~/git-crypt-km.key
```

**Risks:** key loss = permanent data loss. Key exposure = all history compromised. Pre-init commits and filenames stay plaintext.

---

## Offline Mode

| Tool | Enforcement |
|---|---|
| Obsidian | Flatpak `--unshare=network` |
| lazygit | `update.method: never` |
| lazy.nvim | `checker = { enabled = false }` |

---

## Out of scope

`private/` bodies (AI-private) · `docs/skills/` (manually curated) · `okm link/backlinks/stats` (one-liner `rg`) · `okm archive/template` (Obsidian handles) · auto-sync cron (silent push risk)

---

## Roadmap

> Plan-of-record. Audit trail lives in git log. **v0 is the stable release — all v1+ work builds on top of it. Stabilise v0 fully before advancing.**

| Version | Status | Theme |
|---|---|---|
| **v0** | ✅ shipped | Core vault CLI, privacy boundary, hardened input |
| **v1** | 🟡 in design | Fork-safety, edge-case bugs, tagging gaps |
| **v2** | 🔵 planned | Media ingest, macOS, encryption, performance |
| **v3** | 🔵 planned | Portable Vault Specification (PVS) |

### v0 — shipped

| Cluster | Summary |
|---|---|
| **Tagging** | Boundary regex, injection-safe dedup, frontmatter-less handling, hierarchical tags via awk; block-style YAML read (B3); HR false-positive guard (N30); permission-preserving write (N31) |
| **Privacy** | Vault `.gitignore`; `private/` exclusion; `okm audit`; fork-safety docs |
| **Path safety** | `okm open`/`sync` vault-boundary checks; `list_notes` excludes `.git/` |
| **Input validation** | YAML escaping; slug fail-closed; Spotify ID validation; `validate_tag` on flags |
| **Templates** | Single-source placeholder substitution across all four producers |
| **Fuzz gate** | BATS property-test harness (Unicode/quotes/slashes/newlines/empty/long) |
| **Test/CI** | 280+ BATS tests isolated via `FAKE_VAULT_DIR`; CI green on main |
| **Skills** | PARA banners (nvim/vim); typed templates; `seed-demo.sh`; direnv; distill prompt |

**Don't regress in v1+:** 280+ BATS tests isolated via `FAKE_VAULT_DIR` + fake `$HOME` · `scripts/lib/scan.sh` shared library (not duplicated) · idempotent `scripts/setup-km.sh`/`okm new/today/spot` · `scripts/verify-km.sh` exit-code discipline (FAIL blocks, WARN doesn't) · `docs/skills/`/`private/` privacy boundary · minimal correct CI.

### v1 — in design

Full specs + reproduction steps: `tests/v1_spec.bats`.

| Item | Code |
|---|---|
| **Fork-safety** (`okm port`) | See [Fork-safety](#fork-safety-architecture) |
| **Contribution workflow** | See [Contributing Features](#contributing-features) |
| `okm sync` extension check | — |
| `okm private <subcmd>` | — |
| `okm audit --json` + pre-commit hook | — |
| `okm rename-tag` / `okm tags --json` | — |
| `-t` on `okm today` | — |
| `okm spot` metadata fetch + URL escape | N9 |
| `KM_TRACK_NOTES` default unification | F6 |
| macOS support | — |
| `okm crypt init` | — |
| README dual-mode diagram | N6 |
| `verify-km.sh` direnv check | N8 |
| Polish: log rotation, `sync -m`, `okm version`, decouple cron tests | N7, F7 |

### v2 — planned

| Item | Notes |
|---|---|
| `okm yt` / `okm pod` | YouTube transcript; local audio → whisperX |
| `okm distill` | AI summary (Claude + Ollama backends) |
| `okm online`/`offline` | Network-state toggle |
| HuggingFace token | pyannote speaker diarization |
| fzf tag picker / private PARA mirror | |
| `#inline-tags` scanning | **Defer to v3** — Tier-1 or Tier-2? |
| Tag aliasing | Name equivalence (orthogonal to `aliases:` field) |
| ~~Hierarchical tags~~ | **Superseded by PVS §2** (flat-only) |
| **Rust mirror** | Port slow utils after patterns stabilize |

### v3 — planned (PVS)

| Item | Notes |
|---|---|
| Standard markdown links | Migrate `[[wikilinks]]` → `[text](path.md)` in templates/`seed-demo.sh` |
| Frontmatter schema + `VAULT_SCHEMA.md` | Allowlist: `title date modified tags aliases status type source` |
| `okm audit` PVS rules | Wikilinks, undoc'd keys, query blocks without snapshots, Tier-2 without fallback |
| Tier-2 artifact policy | `.canvas`/`.base`/`.excalidraw.md` need Tier-1 export or fallback note |
| Query block snapshots | Static tables paired with queries; script regenerates on schedule |
| `#inline-tags` + hierarchical tags | Resolve v2 deferrals; PVS §2 currently flat-only |

**Crosswalk:** v0 templates Tier-1 compliant. v1 block YAML compatible with PVS §2. v2 hierarchical tags superseded by §2. Tag aliasing orthogonal.

---

## Fork-safety architecture

Goal: accidental pushes to upstream *structurally impossible*. Two topologies under evaluation.

### Approach A — asymmetric remotes

`origin` → private user repo · `upstream` → public OSS (fetch-only, push URL `DISABLED`) · pre-push hook blocklists upstream (override: `KM_ALLOW_UPSTREAM_PUSH=1`) · `okm sync` refuses if `origin` matches upstream. `okm sync` follows `@{u}` via bare `git push` (`bin/okm:639`) — safe once topology is set.

**`okm port <handle> [--public] [--no-push]`:** `gh` auth + `okm audit` → create private repo → rename/disable upstream → add new origin → install hook → push.

*Pro:* minimal delta from v0. *Con:* vault shares git history with app; PRs need throwaway fork. Full spec + hook content: `tests/v1_spec.bats`.

### Approach B — two-repo split

**B1 (submodule):** private repo contains public app as `app/` submodule; vault in `vault/`.
**B2 (side-by-side):** public repo for code; `OBSIDIAN_VAULT` env var (already at `bin/okm:5-16`) points to separate private vault.

*Pro:* no shared history; clean fork/PR; B2 is near-zero code change. *Con:* must extract vault dirs from public repo; `okm sync` semantics change.

### Defense-in-depth (both)

`.gitignore`: `vault/ data/ notes/ personal/ *.pem *.key *.db *.sqlite *.env` · Gitleaks pre-commit hook (`gitleaks v8.18.0`) · GitHub server-side push protection (Settings → Code security).

### Contributing back

```bash
git remote add myfork git@github.com:{handle}/knowledge-management.git
git checkout -b feature/foo && git push myfork feature/foo
# PR: myfork/feature/foo → upstream/main
```

### Decision

**A** if: minimal change acceptable, hooks sufficient. **B2** if: structural impossibility preferred, one-time vault extraction OK. **Pragmatic:** ship A first, evaluate B after real usage.

**Open questions:** Which approach? · `gh` as new dep (recommend: add to `setup-km.sh`) · `okm port --adopt` for existing forks · `verify-km.sh` post-port topology check · README "Privacy & Personal Data" section.

**Tests:** BATS with fake `gh` shim; integration against local bare repo; `okm sync` against misconfigured `origin` must refuse; B2 `$OBSIDIAN_VAULT` outside app repo with its own remote.

---

## Contributing Features

**Problem:** this repo is designed to be forked for personal vault use, which creates a tension with contributing features back — your fork holds private notes, but PRs should only carry code changes.

### Options

| Approach | How it works | Trade-offs |
|---|---|---|
| **A — Contribution fork** | Create a second, code-only fork at `{handle}-km-contrib`. Clone it without vault data. Push feature branches there; PR to upstream. | Clean separation. Requires managing two forks. |
| **B — Throwaway branch** | In your personal fork, create a feature branch from upstream's `main` (no vault commits in history). Push it to a `contrib/` remote pointing at upstream. | One repo, but branch discipline required. |
| **C — `okm port` topology** (v1) | After `okm port`, `origin` = private vault fork, `upstream` = public OSS. Feature branches go to a third throwaway fork and PR to `upstream/main`. | Cleanest long-term; requires `okm port` to ship first. |
| **D — Codespace / devcontainer** | Contribute entirely inside a GitHub Codespace or dev container that clones the public repo with no vault. `$OBSIDIAN_VAULT` points to an empty test vault. | No vault data ever leaves the machine. Requires Codespace setup. |

### Recommended workflow (today)

```bash
# In your personal fork — create a clean feature branch from upstream
git fetch upstream
git checkout -b feature/foo upstream/main

# Make changes, run tests
bash tests/run_all.sh

# Push to a separate contribution remote (not your private origin)
git remote add contrib git@github.com:{handle}-km-contrib/knowledge-management.git
git push contrib feature/foo
# Then open PR: contrib/feature/foo → upstream/main
```

**Invariant:** vault data (`public/daily/`, `public/inbox/`, `public/archive/`) must never appear in any commit on a PR branch. `okm audit --code-only` checks this.

**Open questions:** Should `setup-km.sh` create the contrib remote automatically? Should `okm port` set up a codespace config?

---

## Portable Vault Specification (PVS) v1.0

Every note readable with `cat`/`grep`/any CommonMark renderer without Obsidian. Ref: [thymer.com/ejectable](https://thymer.com/ejectable).

### §0. Artifact tiers

| Tier | Type | Examples | Portable? |
|---|---|---|---|
| **1 – Core** | Plain markdown + YAML frontmatter | `.md`, attachments | ✅ |
| **2 – Derived** | Obsidian-aware, reconstructable | `.canvas`, `.base`, `.excalidraw.md` | ⚠️ w/ fallback |
| **3 – Opaque** | App/plugin state | `.obsidian/`, live query output | ❌ |

Rule 0: Tier-3 never sole record. Tier-2 must have Tier-1 fallback. Tier-1 is source of truth.

### §1. Link format

**MUST** use `[Display](relative/path.md)` — no `[[wikilinks]]`. Relative paths only. Heading anchors OK.

### §2. YAML frontmatter

```yaml
---
title: string
date: YYYY-MM-DD
modified: YYYY-MM-DD
tags: [flat, list]       # no nested taxonomies
aliases: [list]
status: draft|active|archived
type: note|moc|log|ref|project
source: url-or-citation
---
```

Plugin keys allowed only if valid YAML strings + documented in `VAULT_SCHEMA.md`.

### §3. Query blocks

Every query block must include a static snapshot:

````markdown
```dataview
TABLE date, status FROM #project WHERE status = "active"
```
<!-- Static snapshot updated: 2026-05-01 -->
| Title | Date | Status |
````

### §4. Ejectability properties

| Property | Requirement |
|---|---|
| **Completeness** | Bundle: all notes, attachments, config, static fallbacks |
| **Self-hostability** | Fresh machine opens vault in neovim via `neovim/install.sh` |
| **Continuity** | Every Obsidian workflow has named fallback; degradation documented |
| **Reversibility** | Notes move Obsidian ↔ neovim without repair |
| **Link integrity (U1)** | Every relative link resolves — `scripts/link-integrity.sh` must exit 0 |
| **MVR compatibility (U2)** | Any app satisfying the MVR contract can open the vault |
| **Threat model (U3)** | `VAULT_SCHEMA.md` documents each dependency + mitigation |
| **Ejection runbook (U4)** | `EJECT.md`: neovim / any editor / read-only options + "What you will lose" |
| **Observability (U5)** | `scripts/ejectability-check.py` reports portability debt continuously |

**MVR contract** (Minimum Viable Reader — the bar any app must clear):

| Capability | Level |
|---|---|
| Render CommonMark; parse YAML 1.1; follow relative links; render code blocks + tables; list files | MUST |
| Full-text search; resolve backlinks | SHOULD |

**Threat model scenarios** (document each in `VAULT_SCHEMA.md`):

| Threat | Mitigation |
|---|---|
| App death (Obsidian shuts down) | All notes pass MVR; neovim distribution present |
| Plugin death (Dataview/Tasks/Excalidraw abandoned) | Static snapshots; SVG exports alongside `.excalidraw.md` |
| Format death (`.canvas`/`.base` schema change) | Companion `.md` for every Tier-2 artifact |

### Required vault files

```
VAULT_INDEX.md       — editor-agnostic entry point
VAULT_SCHEMA.md      — frontmatter allowlist, folder rules, threat model
VAULT_MANIFEST.json  — machine-readable spec version, workflow continuity map
EJECT.md             — ejection runbook (3 options + degraded features list)
neovim/              — pinned plugins, config, setup guide
Templates/plain/     — Obsidian template parity in plain text
scripts/             — smoke-test.sh, link-integrity.sh, snapshot.py, ejectability-check.py
```

### Compliance checklist

- Every Tier-1 note readable as plain Markdown
- Every Tier-2 artifact has a Tier-1 fallback
- No Tier-3 artifact is sole source of structure or knowledge
- Bundle validated: `scripts/smoke-test.sh && scripts/link-integrity.sh` exit 0
- neovim distribution reproducible on a fresh machine
- Every workflow has a declared fallback or is marked degraded
- Notes move Obsidian ↔ neovim without repair
- Portability debt visible via `ejectability-check.py`

**Minimum neovim stack:** `obsidian.nvim` + `markdown-oxide` (LSP backlinks) + Telescope + snippet support.

### Implementation status

**Compliant now:** Tier-1 plain markdown; inline-array YAML; near-PVS schema in templates.
**Needs v3 work:** migrate `[[wikilinks]]`; `okm audit` rule for undoc'd keys; hierarchical tag decision; query snapshot infra.

### Open questions

- Wikilink migration: one-shot script or `okm audit`-guided?
- `#inline-tags`: Tier-1 or Tier-2?
- `VAULT_SCHEMA.md` versioning/bump rule
- Per-note PVS opt-out (`pvs: ignore`)?

---

## Performance policy

Port slow Bash/Python utilities (fuzz harness, `okm audit`, large TODO scans) to Rust once patterns stabilize. **Mirror when:** >1s on typical vault, hot-loop, or iteration-bound. **Don't mirror:** one-off scripts, I/O-bound, or anything still under active design. v2 "Rust mirror" row tracks this; v0/v1 stay in Bash/Python.

---

## Open-sourcing checklist

- [x] **Personal notes stripped from history** — `public/daily/*.md` and `public/inbox/*.md` (non-template) purged via `git filter-repo`. Templates in `public/inbox/templates/` retained.
- [x] **Large binaries stripped from history** — `bin/nvim`, `bin/nvim.bin`, `bin/lazygit`, and `bin/nvim-runtime/` removed. `setup-km.sh` downloads them at install time.
- [x] **Hardcoded handle replaced** — `CONTRIBUTING.md` now uses `{your-handle}` placeholder.
- [x] **Release-readiness auditor** — `scripts/check-release-ready.sh` exits non-zero if binaries, personal notes, PII patterns, or secrets are detected.
- [ ] **Identity** — commits carry the author name. Intentional if open-sourcing under your own name; otherwise rewrite with `git filter-repo --name-callback` / `--email-callback`.
- [ ] **Force-push** — run `git remote add origin <url> && git push --force origin main` after confirming the remote is your fork, not the upstream.

---

## See Also

- [`docs/ai-instructions.md`](docs/ai-instructions.md) — AI assistant rules
- [`docs/skills/README.md`](docs/skills/README.md) — AI skills library
- [`scripts/README.md`](scripts/README.md) — cron job docs
- [`scripts/setup-km.sh`](scripts/setup-km.sh) — canonical source for versions and defaults
- 
https://www.kernel.sh/ we build crazy fast, open source infra for them to access the internet
