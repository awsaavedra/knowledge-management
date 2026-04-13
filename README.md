> **Disclaimer:** Content in this vault (especially financial, health, and investment topics) is for educational purposes only. See [`disclaimer.md`](disclaimer.md) for full terms.

# Knowledge Management

## What This Is

An offline-first personal knowledge system for notes, daily logs, and captured ideas. 
Content lives as plain Markdown files managed by the `okm` CLI, visualised in 
Obsidian, and edited in Neovim or Vim. Git handles version control and sync. 
Everything runs locally — no cloud dependencies after initial setup.

**Design principles:**
- Plain Markdown as the source of truth — no proprietary format lock-in
- Offline by default — Obsidian's network is revoked at the container level
- Privacy-first — AI assistants follow strict rules in `ai-instructions.md`
- Project-scoped — `source env.sh` activates the environment; no global configs are modified
- One script bootstraps everything — `setup-kms.sh` is idempotent and safe to re-run

---

## Quickstart

```bash
bash setup-kms.sh        # install everything: Obsidian, Neovim, vim, okm, lazygit
source env.sh            # activate the project environment
bash verify-kms.sh       # confirm all tools installed correctly
```

> **Project-scoped:** `source env.sh` sets PATH, EDITOR, and vault variables for the current shell only. Your `~/.zshrc`, `~/.config/nvim`, and `~/.config/lazygit` are never modified. Neovim uses `NVIM_APPNAME=km` so the project config lives at `~/.config/km/`, isolated from your global nvim setup.

Then pick your editor:

| Editor | How to start | Notes |
|---|---|---|
| **Obsidian** | `obs` | First launch: open `$(okm path)` as vault |
| **Neovim** | `okm today` | Uses project config via `NVIM_APPNAME=km`. `:Lazy sync` if needed |
| **Vim** | `EDITOR=vim okm today` | No plugins — plain Markdown editing |

**Core `okm` commands:**

```bash
okm today                # open/create today's daily note
okm new "my note title"  # create a new named note in inbox/
okm capture "quick idea" # timestamped quick-capture note
okm grep "search term"   # ripgrep across all notes
okm recent               # fzf picker over recent notes
okm sync "message"       # git add + commit + pull --rebase + push
```

### Manual steps (not automated by setup)

- **SSH key** — `ssh-keygen -t ed25519 -C kms-vault` then add public key to git host
- **Git remote** — `git -C "$(okm path)" remote add origin <url>`
- **git-crypt** — initialise before first remote push (see [git-crypt](#git-crypt))

---

## Fork & Use

This repo is portable. No hardcoded paths — everything derives from the project root.

```bash
# 1. Fork or clone
git clone <your-fork-url> ~/projects/knowledge-management
cd ~/projects/knowledge-management

# 2. (Optional) Set a custom vault location. Default: sibling directory.
export OBSIDIAN_VAULT="$HOME/my-vault"

# 3. (Optional) Track notes in git. Default: false (notes gitignored for privacy).
#    Set to true if you want full git history of notes (e.g. with git-crypt).
export KM_TRACK_NOTES=true

# 4. Run setup (installs tools, creates vault dirs, bootstraps plugins)
bash setup-kms.sh

# 5. Activate
source env.sh

# 6. Verify
bash verify-kms.sh
```

**What you get:** `okm` CLI, Obsidian (offline), Neovim + obsidian.nvim, lazygit, transcription tools (yt-dlp, whisperX, spotdl, ffmpeg, mpv), and image compression — all project-scoped.

**What you configure:**
- `OBSIDIAN_VAULT` — override vault location (default: `../knowledge-management-system`)
- `KM_TRACK_NOTES` — `true` to track notes in git, `false` (default) to gitignore them
- `EDITOR` — override editor (default: `nvim`)
- Git remote — `git -C "$(okm path)" remote add origin <url>`
- SSH key — `ssh-keygen -t ed25519 -C km-vault`
- Cron jobs — see [Automated TODO Summary](#automated-todo-summary-cron)

**Platform support:** Linux (apt + Flatpak) and macOS. Binary downloads auto-detect architecture (x86_64 / arm64).

**Python dependencies** are installed into a project-local `venv/` by `setup-kms.sh`.

---

## Project Structure

```
.
├── env.sh                          # source to activate
├── setup-kms.sh                    # idempotent bootstrap
├── verify-kms.sh                   # post-install checks
├── ai-instructions.md              # AI privacy rules
├── bin/
│   ├── okm                         # vault CLI
│   ├── nvim                        # neovim (gitignored, setup creates)
│   └── lazygit                     # lazygit (gitignored, setup creates)
├── config/
│   ├── nvim/                       # NVIM_APPNAME=km → ~/.config/km/
│   ├── lazygit/                    # LG_CONFIG_FILE → no global symlink
│   └── mpv/                        # MPV_HOME → screenshot config (generated)
├── scripts/
│   ├── todo-summary.sh             # PARA TODO scanner (cron: 07/12/15:00)
│   └── compress-images.py          # PNG/JPG → WebP (cron: 17:00)
├── _skills/                        # privacy framework docs
├── tests/                          # BATS test suite (151 tests)
└── venv/                           # Python venv (gitignored, setup creates)

../knowledge-management-system/     # vault (sibling directory, override with $OBSIDIAN_VAULT)
├── daily/                          # Areas — one file per day (YYYY-MM-DD.md)
├── inbox/                          # Projects — named notes, quick captures, active work
├── attachments/                    # Resources — images, PDFs, screenshots
└── archive/                        # Archive — completed/inactive notes (manual move)
```

The vault follows [Tiago Forte's PARA method](https://fortelabs.com/blog/para/):

| PARA bucket | Vault folder | What goes here |
|---|---|---|
| **Projects** | `inbox/` | Active notes with a clear end goal — new ideas, drafts, research |
| **Areas** | `daily/` | Ongoing responsibilities — daily logs, recurring reviews |
| **Resources** | `attachments/` | Reference material — images, PDFs, screenshots, diagrams |
| **Archive** | `archive/` | Completed or inactive notes — moved here during review |

`okm new` and `okm capture` write to `inbox/`. `okm today` writes to `daily/`. The TODO scanner maps code markers to PARA buckets (see [Automated TODO Summary](#automated-todo-summary-cron)).

No global config files are modified. `source env.sh` activates; closing the shell deactivates.

---

## Stack

| Tool | Role | Installed by |
|---|---|---|
| Obsidian | GUI vault viewer, graph view | Flatpak (network revoked) |
| Neovim | Primary terminal editor | `bin/nvim` (project-local) via GitHub release |
| obsidian.nvim | Vault integration in Neovim (nav, backlinks, search) | lazy.nvim auto-bootstrap |
| lazygit | TUI git client | `bin/lazygit` (project-local) via GitHub release |
| okm | Vault CLI (notes, search, sync) | `bin/okm` written by setup |
| ripgrep / fzf | Search and fuzzy picking | apt |
| git / SSH | Version control and sync | apt |
| xclip / wl-clipboard | Clipboard bridge (terminal ↔ GUI) | apt |

---

## okm CLI Reference

| Subcommand | Syntax | What it does |
|---|---|---|
| `open` | `okm open [path]` | Open a note or launch fzf picker |
| `new` | `okm new <title>` | Create slugified note in `inbox/` with frontmatter |
| `capture` | `okm capture [text]` | Timestamped quick-capture note |
| `today` | `okm today` | Open/create today's daily note at `daily/YYYY-MM-DD.md` |
| `spot` | `okm spot <spotify-url>` | Create note from Spotify link (episode, track, album, playlist) |
| `grep` | `okm grep <pattern>` | ripgrep across all `.md` files |
| `files` | `okm files [pattern]` | List all `.md` paths, optionally filtered |
| `recent` | `okm recent` | fzf picker over 200 most recently modified notes |
| `sync` | `okm sync [message]` | Stage all → commit → pull --rebase → push |
| `obs` | `okm obs` | Launch Obsidian GUI |
| `path` | `okm path` | Print vault path |

**Environment variables** (set by `source env.sh`):

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | `../knowledge-management-system` (sibling dir) | Vault root |
| `OBSIDIAN_DAILY_DIR` | `daily` | Where `okm today` writes |
| `OBSIDIAN_NOTES_DIR` | `inbox` | Where `okm new` / `okm capture` write |
| `EDITOR` | `nvim` | Editor for all note commands |
| `KM_TRACK_NOTES` | `true` | Track notes in git (`true` = full history, `false` = gitignored) |

---

## Neovim Commands

| Command | What it does |
|---|---|
| `:ObsidianToday` | Open today's daily note |
| `:ObsidianNew <title>` | Create a new note in `inbox/` |
| `:ObsidianSearch` | Full-text search (ripgrep + fzf) |
| `:ObsidianOpen` | Open current note in Obsidian GUI |
| `:ObsidianFollowLink` | Follow `[[wikilink]]` under cursor |
| `:ObsidianBacklinks` | Show notes linking to current note |

Config: `config/nvim/lua/plugins/obsidian.lua` (available via `NVIM_APPNAME=km` → `~/.config/km/`). Your global `~/.config/nvim` is not affected.

---

## Automated TODO Summary (Cron)

`scripts/todo-summary.sh` scans the project and vault for open work items and generates a PARA-structured checklist.

**Schedule:** runs at 07:00, 12:00, and 15:00 daily.

**PARA mapping:**

| Marker | PARA bucket |
|---|---|
| `TODO:` `FIXME:` `HACK:` `XXX:` | **Projects** — active work to close out |
| `- [ ]` unchecked tasks | **Areas** — ongoing responsibilities |
| `REVIEW:` | **Resources** — items to evaluate |

```bash
bash scripts/todo-summary.sh              # print to stdout
bash scripts/todo-summary.sh --output     # write to inbox/todo-summary-YYYY.md (yearly living doc)
```

**System crontab (persistent):** replace `$KM` with your project path.
```bash
# KM=/path/to/knowledge-management && crontab -e
3 7 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 15 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
0 17 * * * $KM/venv/bin/python $KM/scripts/compress-images.py
```

See `scripts/README.md` for full details.

---

## Setup Details

### What `setup-kms.sh` does

1. Installs apt packages: vim, git, ripgrep, fzf, curl, xclip, wl-clipboard, flatpak
2. Installs Obsidian via Flatpak; revokes its network permission
3. Downloads Neovim and lazygit binaries to `bin/` (project-local, gitignored)
4. Creates vault directories (`daily/`, `inbox/`, `attachments/`)
5. Verifies `bin/okm` CLI (project-local, tracked in git)
6. Symlinks `~/.config/km/` → `config/nvim/` for `NVIM_APPNAME=km` isolation
7. Bootstraps Neovim plugins under `~/.local/share/km/` (isolated from global nvim)
8. Initialises git repo, optionally sets remote
9. Enforces offline mode as the final step

**What it does NOT do:** modify `~/.zshrc`, `~/.bashrc`, `~/.config/nvim`, or `~/.config/lazygit`.

Safe to re-run — every step is guarded (checks `dpkg -s`, SHA-256 hashes, existing dirs/files).

Logs: `~/.local/log/setup-km-YYYYMMDD-HHMMSS.log`

### Activation

```bash
source env.sh    # sets PATH, EDITOR, NVIM_APPNAME, LG_CONFIG_FILE, vault vars
```

For auto-activation with [direnv](https://direnv.net/), create `.envrc`:
```bash
source_env env.sh
```

---

## Git Sync

`okm sync [message]` runs: `git add -A` → `git commit` → `git pull --rebase --autostash` → `git push`. Skips push if no upstream is configured.

For advanced git operations: `lazygit -p "$(okm path)"` or `git -C "$(okm path)" <command>`.

### SSH

SSH is recommended over HTTPS (no stored passwords, key-based auth).

```bash
ssh-keygen -t ed25519 -C "kms-vault" -f ~/.ssh/id_ed25519
# Add public key to git host, then:
git -C "$(okm path)" remote add origin git@github.com:user/repo.git
```

Auto-load agent in `~/.zshrc`:
```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

---

## git-crypt

Encrypts `daily/*.md` and `inbox/*.md` in the remote repository using AES-256-CTR. Files are plaintext locally and opaque blobs on the remote. Symmetric key mode — single key, no GPG required.

### Setup

```bash
sudo apt install git-crypt
cd "$(okm path)"
git-crypt init
git-crypt export-key ~/git-crypt-kms.key    # back this up — it's the only way to decrypt

cat >> .gitattributes <<'EOF'
daily/*.md filter=git-crypt diff=git-crypt
inbox/*.md filter=git-crypt diff=git-crypt
EOF

git add .gitattributes && git commit -m "configure git-crypt"
```

### Unlock on a new machine

```bash
git clone <url> && cd knowledge-management-system
git-crypt unlock ~/git-crypt-kms.key
```

### Key risks

- **Key loss = permanent data loss** — no recovery mechanism. Store the key in a password manager AND an offline backup.
- **Key exposure** — compromises all encrypted history. No forward secrecy.
- **Pre-setup history** — files committed before `git-crypt init` remain plaintext in git history.
- **Metadata not encrypted** — filenames, commit timestamps, directory structure are visible.

---

## Offline Mode

All tools run offline during normal use. Network access is only for explicit `git push/pull` via SSH.

| Tool | Enforcement |
|---|---|
| Obsidian | Flatpak sandbox: `--unshare=network` (hard container boundary) |
| lazygit | `update.method: never` in config |
| lazy.nvim | `checker = { enabled = false }` |
| ripgrep, fzf, okm, vim | No network capability |

For transcription workflows that need internet, toggle with `okm online` / `okm offline` (session-scoped).

---

## Audio & Video Transcription

Transcribe podcasts, YouTube videos, and audio into searchable notes. All tools are free.

### Toolchain

| Tool | Role |
|---|---|
| yt-dlp / youtube-transcript-api | YouTube transcript extraction + audio download |
| spotdl | Spotify metadata extraction + audio download |
| whisperX (large-v3-turbo model) | Local transcription with speaker diarization |
| ffmpeg | Audio format conversion |
| mpv | Video playback with screenshot capture |
| Claude Code / Ollama | Summarisation and citation extraction |

### Workflow

| Source | Command | Network? |
|---|---|---|
| YouTube (has captions) | `okm yt <URL>` | One-time fetch |
| YouTube (no captions) | `okm yt <URL>` → downloads audio → whisperX | Fetch, then local |
| Spotify episode | `okm spot <URL>` → note + embed + optional audio download | One-time fetch |
| Spotify track/album/playlist | `okm spot <URL>` → note + embed | One-time fetch |
| Podcast (known show) | Check [Happy Scribe](https://podcasts.happyscribe.com) first | One-time fetch |
| Local audio/podcast file | `okm pod <file> "Title"` | Fully offline |
| Distillation | `okm distill <note>` (Claude) or `okm distill --local <note>` (Ollama) | Claude: yes / Ollama: no |

### Note format

```yaml
---
title: "Episode Title"
source_type: podcast | youtube | audio | spotify-episode | spotify-track
source_url: "https://..."
author: "Host / Channel"
tags: [source/podcast, topic/machine-learning]
---
```

### YouTube note anatomy (target format)

The example note `inbox/top-10-stocks-to-get-rich-in-2026.md` is the reference. A finished YouTube summary note has these sections:

| Section | Purpose | How it's produced |
|---|---|---|
| **Frontmatter** | source_type, source_url, author, tags | `okm yt` (auto-generated) |
| **Thumbnail** | `![[filename.png]]` Obsidian embed | `okm yt` saves thumbnail |
| **Summary** | 3-5 caveman-speech bullets — key takeaways only | `okm distill` or manual |
| **Structured data table** | e.g. stocks mentioned with ticker symbols, frameworks | `okm distill` or manual |
| **Key quotes** | Timestamped quotes `> [MM:SS] "..."` | `okm distill` or manual |
| **Screenshots** | `![[screenshot-HHMMSS.png]]` of key visuals (charts, diagrams) | mpv screenshot during playback |
| **Timestamps** | Chapter markers from video | `okm yt` (auto-extracted) |
| **Transcript** | Full text with timestamps | `okm yt` (fetched or whisperX) |

**Caveman speech rules for summaries:** Short sentences. No filler. Bullets over paragraphs. Lead with the fact, not the context. Numbers and tickers over prose. Tables over lists when there's structured data (tickers, comparisons, frameworks).

### Spotify note anatomy (target format)

`okm spot <URL>` creates notes from Spotify links. Supports episodes, tracks, albums, and playlists.

| Section | Purpose | How it's produced |
|---|---|---|
| **Frontmatter** | source_type, source_url, author, tags | `okm spot` (auto-generated) |
| **Player** | Spotify embed iframe + direct link | `okm spot` (auto-generated) |
| **Summary** | 3-5 caveman-speech bullets (episodes/podcasts) | `okm distill` or manual |
| **Key quotes** | Timestamped quotes `> [MM:SS] "..."` (episodes) | `okm distill` or manual |
| **Transcript** | Full text (episodes) | whisperX after `spotdl` audio download |

**Episode vs track notes:** Episodes get the full podcast template (summary, quotes, transcript). Tracks/albums/playlists get a lighter template (player embed + notes section).

**Transcription workflow for Spotify episodes:**
```bash
okm spot <episode-url>           # create note skeleton with embed
spotdl <episode-url>             # download audio
okm pod <downloaded-file> "Title"  # transcribe with whisperX
```

### Screenshots via mpv

During video playback, press `s` in mpv to capture screenshots of key visuals (charts, tables, diagrams). Screenshots save to `attachments/` and get embedded as `![[screenshot-name.png]]` in the note.

```bash
# mpv config (generated by setup-kms.sh, loaded via MPV_HOME in env.sh)
screenshot-directory=$(okm path)/attachments
screenshot-format=png
screenshot-template=%F-%wH%wM%wS
```

### Implementation status

- **Phase 1** (core pipeline): install yt-dlp, whisperX, ffmpeg, mpv, spotdl. Add `okm yt`, `okm pod`, `okm spot`. Configure mpv screenshot directory.
- **Phase 2** (online toggle): add `okm online` / `okm offline`.
- **Phase 3** (summarisation): add `okm distill` with Claude and Ollama backends. Output: caveman summary + structured data tables + timestamped quotes.

---

## Privacy & Security

See `ai-instructions.md` for AI-specific rules. This covers system-level controls.

**Threat model:** accidental disclosure via AI indexing, remote repo exposure, git history leakage, clipboard sniffing, unencrypted local storage.

**Controls in place:**

| Control | Mechanism |
|---|---|
| AI note privacy | `ai-instructions.md` — note bodies private by default |
| Offline enforcement | Obsidian (Flatpak sandbox), lazygit + lazy.nvim (config) |
| Binary file exclusion | `.gitignore` excludes attachments, OS noise, swap files |
| Generic commit messages | `okm sync` defaults to `vault sync YYYY-MM-DD HH:MM:SS` |
| SSH transport | Key auth, no stored credentials |

**Gaps:** git-crypt not yet initialised, SSH key setup not automated, `.obsidian/` plugin configs not audited, clipboard not auto-cleared.

---

## Roadmap

Single prioritized list. Open Items and Feature Roadmap consolidated here.

### High — YouTube/audio pipeline

| Item | Status |
|---|---|
| Install yt-dlp + whisperX + ffmpeg + mpv | Done |
| Configure mpv screenshot directory → `attachments/` | Done |
| Get HuggingFace token for pyannote (speaker diarization) | Not started |
| Add `okm yt` subcommand (fetch transcript + metadata + thumbnail → note skeleton) | Not started |
| Add `okm pod` subcommand (local audio → whisperX → note) | Not started |
| Add `okm distill` subcommand (caveman summary + structured tables + key quotes) | Not started |

### High — Security

| Item | Status |
|---|---|
| Initialise git-crypt | Not started |
| SSH key generation | Not started |

### Medium

| Item | Status |
|---|---|
| Add `okm online` / `okm offline` toggle | Not started |
| Install Ollama + `llm` CLI (local distill backend) | Not started |
| `okm move <src> <dst>` — rename note + update all `[[wikilinks]]` across vault | Not started |

### Deferred / Won't do

These looked useful but add complexity without proportional value:

| Item | Reason to skip |
|---|---|
| `okm link`, `okm backlinks` | One-liner `rg` commands — document as recipes, don't add subcommands |
| `okm tags`, `okm stats` | Same — `rg` + `awk` one-liners, not worth code in `bin/okm` |
| `okm archive` | Daily notes are small; archiving adds folder churn |
| `okm template` | Obsidian `:ObsidianTemplate` already does this |
| Auto-sync cron | Silent pushes are risky; `okm sync` is explicit and intentional |
| Shared logging lib (R2) | `setup-kms.sh` and `verify-kms.sh` logging functions differ more than they overlap |
| Audit `.obsidian/` plugin configs | Low risk — Obsidian is sandboxed offline |

### Completed refactors

| ID | Refactor |
|---|---|
| R1 | Removed self-copy blocks in `setup-kms.sh` |
| R3 | Fixed BATS test boilerplate (`common_setup()`) |
| R4 | Consolidated `find` pipelines into `list_notes()` |
| R5 | Single source for vault path (`$OBSIDIAN_VAULT` with fallback) |
| R7 | PATH dedup guard in `env.sh` |
| R8 | Removed dead `bin/obs` references — `okm obs` handles launch directly |
| R9 | Removed `obs` verification block from `setup-kms.sh` and `verify-kms.sh` |

---

## See Also

- `ai-instructions.md` — rules for AI assistants in this vault
- `_skills/README.md` — privacy skills library
- `setup-kms.sh` — canonical source for installed versions, paths, and defaults
- `verify-kms.sh` — post-install verification
- `scripts/README.md` — automated TODO summary cron documentation
