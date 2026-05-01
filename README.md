# Objective of this project
The open-source knowledge OS for Obsidian users who live in Vim, Neovim, and CLI-powered interactions, file-native, and continuously tested.

> **Disclaimer:** Content in this vault (especially financial, health, and investment topics) is for educational purposes only. See [`disclaimer.md`](disclaimer.md) for full terms.

# Knowledge Management

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Project

Offline-first personal knowledge system. Plain Markdown notes managed by the `okm` CLI, visualised in Obsidian, edited in Neovim or Vim. Git handles sync. No cloud dependencies after initial setup.

- **Plain Markdown** — no proprietary format lock-in
- **Offline by default** — Obsidian's network is revoked at the container level
- **Privacy-first** — `private-*/` folders are off-limits to AI assistants (see `ai-instructions.md`)
- **Project-scoped** — `source env.sh` activates; no global configs modified
- **One script** — `setup-km.sh` is idempotent and safe to re-run

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

**Platform support:** Linux (apt + Flatpak) and macOS. Auto-detects x86_64 / arm64.

---

## Commands

```bash
git clone --recurse-submodules <your-fork-url> ~/projects/knowledge-management
cd ~/projects/knowledge-management

# (Optional) Custom vault location. Default: sibling directory.
export OBSIDIAN_VAULT="$HOME/my-vault"

bash setup-km.sh         # install everything (idempotent, safe to re-run)
source env.sh            # activate project environment
bash verify-km.sh        # confirm all tools installed
bash tests/run_all.sh    # run BATS test suite (163 tests)
```

`--recurse-submodules` pulls the BATS submodules under `tests/lib/` so the test suite runs. If you cloned without it, run `git submodule update --init --recursive`.

Setup asks: **Track notes in git?** (default: yes). To skip the prompt, set `KM_TRACK_NOTES=true` or `false` beforehand. Notes tracked = full git history (pair with git-crypt). Notes untracked = local only.

Setup logs: `~/.local/log/setup-km-*.log`. For day-to-day commands, see [okm CLI](#okm-cli).

### Manual setup steps (not automated)

- **SSH key** — `ssh-keygen -t ed25519 -C km-vault` then add to git host
- **Git remote** — `git -C "$(okm path)" remote add origin <url>`
- **git-crypt** — optional, initialise before first push (see [Advanced: git-crypt](#advanced-git-crypt))

---

## Architecture

> **Maintenance:** keep the tree below in sync with disk. Update after any major refactor (file moves, renames, new top-level dirs).

```
.
├── env.sh                          # source to activate
├── setup-km.sh                     # idempotent bootstrap
├── verify-km.sh                    # post-install checks
├── ai-instructions.md              # AI assistant rules
├── bin/
│   ├── okm                         # vault CLI (tracked)
│   ├── nvim                        # neovim (gitignored, setup creates)
│   └── lazygit                     # lazygit (gitignored, setup creates)
├── config/
│   ├── nvim/                       # NVIM_APPNAME=km → ~/.config/km/
│   ├── lazygit/                    # LG_CONFIG_FILE → no global symlink
│   └── mpv/                        # MPV_HOME → screenshot config (generated)
├── scripts/
│   ├── todo-summary.sh             # PARA TODO scanner → yearly file (cron: 07/12/15:00)
│   ├── weekly-tasks.sh             # PARA TODO scanner → weekly file (cron: 07/12/15:00)
│   └── compress-images.py          # PNG/JPG → WebP (cron: 17:00)
├── tests/                          # BATS test suite (163 tests)
├── _skills/                        # AI skills library (extensible)
└── venv/                           # Python venv (gitignored, setup creates)

../knowledge-management/            # vault (override with $OBSIDIAN_VAULT)
├── daily/                          # Areas — one file per day (YYYY-MM-DD.md)
├── inbox/                          # Projects — named notes, quick captures, active work
├── attachments/                    # Resources — images, PDFs, screenshots
├── archive/                        # Archive — completed/inactive notes (manual move)
└── private-*/                      # Mirror of above; off-limits to AI assistants
```

Vault follows [Tiago Forte's PARA method](https://fortelabs.com/blog/para/):

| PARA bucket | Folder | What goes here |
|---|---|---|
| **Projects** | `inbox/` | Active notes with a clear end goal — ideas, drafts, research |
| **Areas** | `daily/` | Ongoing responsibilities — daily logs, recurring reviews |
| **Resources** | `attachments/` | Reference material — images, PDFs, screenshots |
| **Archive** | `archive/` | Completed or inactive notes — moved here during review |

`private-{daily,inbox,attachments,archive}/` mirror the public PARA folders for AI-private content.

---

## Rules

- AI assistants don't read `private-*/` paths — see `ai-instructions.md`
- Update the Architecture tree above after any major refactor (file moves, renames, new top-level dirs)
- Notes are plain Markdown — no proprietary fields, no cross-tool dependencies
- Project-scoped — never modify the user's global configs (`~/.config/nvim`, `~/.zshrc`, etc.)
- IMPORTANT: this stack is offline-first — don't introduce cloud dependencies in the core flow

---

## Workflow

Pick your editor:

| Editor | Command | Notes |
|---|---|---|
| **Obsidian** | `okm obs` | First launch: open `$(okm path)` as vault |
| **Neovim** | `okm today` | Project config via `NVIM_APPNAME=km` |
| **Vim** | `EDITOR=vim okm today` | No plugins, plain Markdown |

- **Capture**: `okm today` (daily note) or `okm capture <text>` (timestamped)
- **Search**: `okm grep <pattern>` (content) or `okm files [pattern]` (paths)
- **Sync**: `okm sync [message]` — stages all, commits, rebases, pushes
- **Test before merge**: `bash tests/run_all.sh`
- **Commit conventions**: one logical change per commit; `okm sync` defaults to `vault sync YYYY-MM-DD HH:MM:SS`
- **Ask before**: destructive ops (`rm -rf`, force push), scope creep beyond requested files

For auto-activation with [direnv](https://direnv.net/), create `.envrc`: `source_env env.sh`

---

## Out of scope

| Item | Reason |
|---|---|
| `private-*/` note bodies | AI-private; only structural metadata is read |
| `_skills/` content | Manually curated; agents don't auto-modify |
| `disclaimer.md` | Manually maintained legal text |
| `okm link/backlinks/tags/stats` | One-liner `rg` commands, not worth subcommands |
| `okm archive/template` | Obsidian handles this; daily notes are small |
| Auto-sync cron | Silent pushes are risky; `okm sync` is intentional |

---

## okm CLI

| Subcommand | What it does |
|---|---|
| `okm today` | Open/create today's daily note |
| `okm new <title>` | Create slugified note in `inbox/` with frontmatter |
| `okm capture [text]` | Timestamped quick-capture note |
| `okm spot <spotify-url>` | Create note from Spotify link (episode, track, album, playlist) |
| `okm open [path]` | Open a note or launch fzf picker |
| `okm grep <pattern>` | ripgrep across all `.md` files |
| `okm files [pattern]` | List all `.md` paths, optionally filtered |
| `okm recent` | fzf picker over 200 most recently modified notes |
| `okm sync [message]` | `git add -A` → commit → `pull --rebase` → push |
| `okm obs` | Launch Obsidian GUI |
| `okm path` | Print vault path |

### Environment variables

Set by `source env.sh`:

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | `../knowledge-management` | Vault root |
| `OBSIDIAN_DAILY_DIR` | `daily` | Where `okm today` writes |
| `OBSIDIAN_NOTES_DIR` | `inbox` | Where `okm new` / `okm capture` write |
| `EDITOR` | `nvim` | Editor for all note commands |
| `KM_TRACK_NOTES` | `true` | Track notes in git (`false` = gitignored) |

---

## Neovim

Config: `config/nvim/lua/plugins/obsidian.lua` via `NVIM_APPNAME=km` → `~/.config/km/`. Your global `~/.config/nvim` is not affected.

| Keymap | Command | What it does |
|---|---|---|
| `<leader>od` | `:ObsidianToday` | Open today's daily note |
| `<leader>on` | `:ObsidianNew` | Create new note in `inbox/` |
| `<leader>os` | `:ObsidianSearch` | Full-text search (ripgrep + fzf) |
| `<leader>oo` | `:ObsidianQuickSwitch` | Quick switch between notes |
| `<leader>ob` | `:ObsidianBacklinks` | Show notes linking to current note |
| `<leader>og` | `:ObsidianOpen` | Open current note in Obsidian GUI |

---

## Media Transcription

Transcribe podcasts, YouTube videos, Spotify episodes, and local audio into searchable notes.

### Toolchain

| Tool | Role |
|---|---|
| yt-dlp / youtube-transcript-api | YouTube transcript + audio download |
| spotdl | Spotify metadata + audio download |
| whisperX (large-v3-turbo) | Local transcription with speaker diarization |
| ffmpeg | Audio format conversion |
| mpv | Video playback with screenshot capture (`s` key → `attachments/`) |

### Workflow

| Source | Command | Network? |
|---|---|---|
| YouTube (has captions) | `okm yt <URL>` | One-time fetch |
| YouTube (no captions) | `okm yt <URL>` → whisperX | Fetch + local |
| Spotify episode | `okm spot <URL>` → `spotdl` → `okm pod` | One-time fetch |
| Spotify track/album/playlist | `okm spot <URL>` | One-time fetch |
| Podcast | Check [Happy Scribe](https://podcasts.happyscribe.com) first | One-time fetch |
| Local audio | `okm pod <file> "Title"` | Fully offline |
| Summarise | `okm distill <note>` or `okm distill --local <note>` | Claude / Ollama |

### Note anatomy

Templates in `inbox/yt-note-format-template.md` and `inbox/spotify-note-format-template.md`.

**YouTube notes** (`okm yt`):

| Section | How it's produced |
|---|---|
| Frontmatter (source_type, url, author, tags) | Auto-generated |
| Thumbnail (`![[file.png]]`) | Auto-saved |
| Summary (3-5 caveman-speech bullets) | `okm distill` or manual |
| Structured data table | `okm distill` or manual |
| Key quotes (`> [MM:SS] "..."`) | `okm distill` or manual |
| Screenshots (`![[screenshot.png]]`) | mpv `s` key during playback |
| Timestamps (chapter markers) | Auto-extracted |
| Transcript (full text) | Fetched or whisperX |

**Spotify notes** (`okm spot`):

| Section | How it's produced |
|---|---|
| Frontmatter + player embed iframe | Auto-generated |
| Summary + key quotes + transcript | Episodes only — `okm distill` or manual |
| Notes section | Tracks/albums/playlists — lighter template |

**Summary style:** short sentences, no filler, bullets over paragraphs, numbers over prose, tables for structured data.

---

## Cron Jobs

| Schedule | Script | What it does |
|---|---|---|
| 07:00, 12:00, 15:00 | `todo-summary.sh --output` | PARA-structured TODO scan → `inbox/todo-summary-YYYY.md` |
| 07:00, 12:00, 15:00 | `weekly-tasks.sh --output` | PARA-structured TODO scan → `inbox/weekly-DATE-to-DATE.md` |
| 17:00 | `compress-images.py` | Convert PNG/JPG/GIF → WebP, update `![[wikilinks]]` |

**PARA mapping for TODO scanner:**

| Marker | PARA bucket |
|---|---|
| `TODO:` `FIXME:` `HACK:` `XXX:` | **Projects** |
| `- [ ]` unchecked tasks | **Areas** |
| `REVIEW:` | **Resources** |

```bash
bash scripts/todo-summary.sh              # print to stdout
bash scripts/todo-summary.sh --output     # write yearly living doc
```

**System crontab** — replace `$KM` with your project path:
```bash
3 7,12,15 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
0 7,12,15 * * * /usr/bin/bash $KM/scripts/weekly-tasks.sh --output
0 17 * * * $KM/venv/bin/python $KM/scripts/compress-images.py
```

---

## Git Sync

`okm sync [message]` stages all, commits, rebases, pushes. Skips push if no upstream.

For advanced operations: `lazygit -p "$(okm path)"` or `git -C "$(okm path)" <cmd>`.

```bash
ssh-keygen -t ed25519 -C "km-vault" -f ~/.ssh/id_ed25519
git -C "$(okm path)" remote add origin git@github.com:user/repo.git
```

---

## Advanced: git-crypt

Optional. Encrypts `daily/*.md` and `inbox/*.md` in the remote repo (AES-256-CTR). Plaintext locally, opaque blobs on remote. Single symmetric key, no GPG.

```bash
sudo apt install git-crypt
cd "$(okm path)"
git-crypt init
git-crypt export-key ~/git-crypt-km.key    # BACK THIS UP — only way to decrypt

cat >> .gitattributes <<'EOF'
daily/*.md filter=git-crypt diff=git-crypt
inbox/*.md filter=git-crypt diff=git-crypt
EOF

git add .gitattributes && git commit -m "configure git-crypt"
```

Unlock on new machine: `git clone <url> && cd repo && git-crypt unlock ~/git-crypt-km.key`

**Risks:** key loss = permanent data loss. Key exposure = all history compromised. Pre-init commits stay plaintext. Filenames/timestamps not encrypted.

---

## Offline Mode

All tools run offline. Network only for explicit `git push/pull`.

| Tool | Enforcement |
|---|---|
| Obsidian | Flatpak sandbox `--unshare=network` |
| lazygit | `update.method: never` |
| lazy.nvim | `checker = { enabled = false }` |
| ripgrep, fzf, okm, vim | No network capability |

---

## Roadmap

- `okm yt` — YouTube transcript + metadata → note
- `okm pod` — local audio → whisperX → note
- `okm distill` — AI summary (Claude + Ollama backends)
- `okm online` / `okm offline` toggle
- HuggingFace token for pyannote (speaker diarization)
- git-crypt initialisation
- GitHub Actions CI for the BATS suite
- Private PARA mirror folder

---

## See Also

- `ai-instructions.md` — AI assistant rules
- `_skills/README.md` — AI skills library
- `scripts/README.md` — cron job documentation
- `setup-km.sh` — canonical source for versions and defaults
