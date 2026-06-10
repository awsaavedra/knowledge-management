# Knowledge Management

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **Disclaimer:** Content in this vault (financial, health, investment topics) is for educational purposes only. See [`docs/disclaimer.md`](docs/disclaimer.md).

Open-source knowledge OS for Obsidian users who live in Vim, Neovim, and the CLI — file-native, offline-first, continuously tested. Treats notes like code: plain Markdown, local files, terminal workflows, composable CLI. AI is optional and layered on top.

**Design principles:** instant startup; fresh local indexing; composable CLI (pipes, JSON, CI); non-destructive by default; no lock-in; small memorable command surface; editor/toolchain interop; local-first; lightweight; **ejectable** — every note readable with `cat`/`grep`/any CommonMark renderer, vault survives Obsidian disappearing (see [PVS](docs/pvs.md)).

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

**Prerequisites:** `git`, `curl`, `flatpak`, `sudo` access, GitHub account. Debian/Ubuntu only.

> **Fork first.** On GitHub: fork this repo, then go to your fork's **Settings → General → Repository name** and rename it to `{your-github-handle}-knowledge-management`. Clone *your fork*, not this repo, so `okm sync` pushes to your private copy.

```bash
git clone --recurse-submodules <your-fork-url> ~/projects/knowledge-management
cd ~/projects/knowledge-management
export OBSIDIAN_VAULT="$HOME/my-vault"   # optional; default: repo root
bash scripts/setup-km.sh && source env.sh && bash scripts/verify-km.sh
bash tests/run_all.sh
```

> **Note:** Run `bash scripts/setup-km.sh` before `direnv allow .` — setup installs `direnv` itself.

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
**Vim:** `EDITOR=vim okm open public/inbox/demo-meeting-notes.md` — expect green `PUBLIC PARA · inbox` statusline. (`bin/vim` wraps `vim -u config/vim/vimrc`; `bin/` is first on `$PATH` via `env.sh` so `vim` loads project config without touching `~/.vimrc`.)
**Private side test:** `nvim private/inbox/demo-private.md` → red `⚠ PRIVATE PARA` banner.

Seeded files: `public/daily/demo-YYYY-MM-DD.md` · `public/inbox/demo-{meeting-notes,capture,yt-example,spotify-{episode,track},podcast,todo-summary-YYYY,weekly-*}.md` · `public/attachments/demo-screenshot.png` · `public/archive/demo-completed-project.md`

---

## Workflow

| Editor | Launch | Notes |
|---|---|---|
| Obsidian | `okm obs` | First launch: open `$(okm path)` as vault |
| Neovim | `okm today` | Project config via `NVIM_APPNAME=km` |
| Vim | `EDITOR=vim okm today` | Project vimrc via `bin/vim`; sources `~/.vimrc` first |

- **Capture:** `okm today` (daily note) or `okm capture <text>` (timestamped)
- **Save from a link:** `okm yt <youtube-url>` or `okm spot <spotify-url>` — writes a dated, searchable note (`public/inbox/YYYY-MM-DD-title.md`), prints its path, and opens it. With `yt-dlp`/`spotdl` installed, `okm yt` offers to pull the title + transcript; otherwise it's an offline scaffold you (or a loom agent) fill in.
- **Search:** `okm grep <pattern>` (content) or `okm files [pattern]` (paths)
- **Sync:** `okm sync [message]` — default commit message: `vault sync YYYY-MM-DD HH:MM:SS`
- **Test before merge:** `bash tests/run_all.sh`
- **Auto-activation:** `direnv allow .` (repo includes `.envrc`)

---

## Architecture

```
.
├── env.sh
├── bin/okm                         # vault CLI
├── config/nvim/                    # NVIM_APPNAME=km → ~/.config/km/
├── config/{lazygit,mpv,vim}/
├── docs/ai-instructions.md         # AI assistant rules
├── docs/skills/                    # AI skills (argumentation, debug, research, …)
├── docs/pvs.md                     # Portable Vault Specification
├── docs/design-notes.md            # N/B code index, fork-safety design
├── docs/CONTRIBUTING.md            # contributing features and fork workflow
├── docs/ORCHESTRATOR.md            # vault constitution for loom agents
├── scripts/setup-km.sh             # install and configure
├── scripts/verify-km.sh            # post-install checks
├── scripts/{todo-summary,weekly-tasks}.sh   # cron scanners
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
```

Vault follows [PARA](https://fortelabs.com/blog/para/). All agent/loom output belongs under `public/` in PARA. `private/` mirrors each public folder.

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
| `okm yt <url>` | Create dated note from a YouTube link; prints its path; offers `yt-dlp` title/transcript fetch |
| `okm pod <file> [title]` | Create dated note from a local audio/video file; transcribes via whisperX when installed |
| `okm distill <note>` | Write an AI bullet summary alongside a note (`--model claude\|ollama`) |
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

`okm new`, `capture`, `spot`, `yt` accept `-t tag1,tag2`.

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
| YouTube | `okm yt <URL>` | Shipped (transcript fetch needs `yt-dlp`) |
| Spotify | `okm spot <URL>` | Shipped |
| Local audio | `okm pod <file> "Title"` | Shipped (transcription needs whisperX; offline scaffold otherwise) |
| Summarise | `okm distill <note>` (Claude / Ollama) | Shipped (needs `claude` CLI or `ollama`) |

Tools: yt-dlp, spotdl, whisperX (large-v3-turbo), ffmpeg, mpv (`s` key → screenshot to `attachments/`).

---

## Templates

`public/inbox/templates/` — one canonical template per note type with a `<!-- Format Specification: -->` block.

| Template | Producer |
|---|---|
| `daily-template.md` | `okm today` |
| `note-template.md` | `okm new` |
| `capture-template.md` | `okm capture` |
| `yt-template.md` / `podcast-template.md` | `okm yt` / `okm pod` |
| `spotify-episode-template.md` / `spotify-track-template.md` | `okm spot` |
| `todo-summary-template.md` / `weekly-template.md` | cron scripts |
| `archive-template.md` | manual |

---

## Cron Jobs

TODO → PARA: `TODO/FIXME/HACK/XXX` = Projects, `- [ ]` = Areas, `REVIEW:` = Resources.

| Schedule | Script | Output |
|---|---|---|
| 07:00, 12:00, 15:00 | `todo-summary.sh --output` | `public/inbox/todo-summary-YYYY.md` |
| 07:00, 12:00, 15:00 | `weekly-tasks.sh --output` | `public/inbox/weekly-DATE-to-DATE.md` |
| 17:00 | `compress-images.py` | PNG/JPG → WebP |

Crontab entries: see [`scripts/README.md`](scripts/README.md).

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

| Version | Status | Theme |
|---|---|---|
| **v0** | ✅ shipped | Core vault CLI, privacy boundary, hardened input |
| **v1** | ✅ shipped (tagged `v1.0.0`) | Fork-safety, edge-case bugs, tagging gaps |
| **v2** | 🟡 in progress | Media ingest (`okm pod`, `okm distill` shipped), encryption, performance |
| **v3** | 🔵 planned | macOS support, Portable Vault Specification (PVS) |

Full item lists: [`docs/roadmap.md`](docs/roadmap.md). Project-structure simplification (root keeps `README.md` only; all other markdown lives in `docs/`) — rationale and rejected alternatives: [`docs/roadmap.md#project-structure-simplification`](docs/roadmap.md#project-structure-simplification). v1 specs + reproduction steps: `tests/v1_spec.bats`. v0 shipped clusters and regression guard: [`docs/design-notes.md`](docs/design-notes.md). Fork-safety architecture: [`docs/design-notes.md#fork-safety-architecture`](docs/design-notes.md#fork-safety-architecture).

---

## Performance policy

Port slow Bash/Python utilities to Rust once patterns stabilize. **Mirror when:** >1s on typical vault, hot-loop, or iteration-bound. **Don't mirror:** one-off scripts, I/O-bound, or anything still under active design. v2 "Rust mirror" row tracks this; v0/v1 stay in Bash/Python.

---

## See Also

- [`docs/ai-instructions.md`](docs/ai-instructions.md) — AI assistant rules
- [`docs/skills/README.md`](docs/skills/README.md) — AI skills library
- [`docs/design-notes.md`](docs/design-notes.md) — N/B code index, fork-safety design, v0 shipped detail
- [`docs/pvs.md`](docs/pvs.md) — Portable Vault Specification
- [`scripts/README.md`](scripts/README.md) — cron job docs and crontab entries
- [`scripts/setup-km.sh`](scripts/setup-km.sh) — canonical source for versions and defaults
- [`docs/CONTRIBUTING.md`](docs/CONTRIBUTING.md) — contributing features and fork workflow
