# Objective of this project
The open-source knowledge OS for Obsidian users who live in Vim, Neovim, and CLI-powered interactions, file-native, and continuously tested.

> **Disclaimer:** Content in this vault (especially financial, health, and investment topics) is for educational purposes only. See [`disclaimer.md`](disclaimer.md) for full terms.

# Market Niche 

Thesis: The open-source knowledge OS for Obsidian users who live in Vim, Neovim, 
and CLI-powered interactions — file-native, AiCLI-powered, and continuously tested.

This should exist in the developer infrastructure segment of knowledge management: 
a tool for engineers who treat notes like code, want local markdown/Obsidian-compatible 
files, and prefer terminal, Vim, and Neovim workflows over heavy app-centric PKM systems.

Its wedge is not “AI note-taking” but a fast, composable, Unix-native knowledge 
layer that users can trust first for speed, portability, and safe file operations, 
with Claude/Copilot/Agent (Cursor) added later as an optional multiplier rather 
than the core dependency.

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

**Platform support:** Linux (apt + Flatpak). Auto-detects x86_64 / arm64. macOS support is planned (see [roadmap.md](roadmap.md)).

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
bash tests/run_all.sh    # run full BATS test suite
```

`--recurse-submodules` pulls the BATS submodules under `tests/lib/` so the test suite runs. If you cloned without it, run `git submodule update --init --recursive`.

Setup asks: **Track notes in git?** (default: yes). To skip the prompt, set `KM_TRACK_NOTES=true` or `false` beforehand. Notes tracked = full git history (pair with git-crypt). Notes untracked = local only.

Setup logs: `~/.local/log/setup-km-*.log`. For day-to-day commands, see [okm CLI](#okm-cli).

### Quickstart — verify Obsidian, Neovim, and Vim

After `bash setup-km.sh` finishes and you've sourced `env.sh`, seed the demo dataset once and use it to confirm all three editors are wired up:

```bash
bash scripts/seed-demo.sh                  # 11 demo-* files across daily/, inbox/, attachments/, archive/
okm files demo-                            # confirm what got seeded
```

Then verify each editor in turn. They share the seeded files and the same project-scoped configs.

#### 1. Obsidian (GUI)

```bash
okm obs                                    # launches the Flatpak with network revoked
```

- First launch: choose **"Open folder as vault"** and point it at `$(okm path)`.
- In the file tree you should see `daily/demo-YYYY-MM-DD.md`, `inbox/demo-*.md`, `archive/demo-completed-project.md`, `attachments/demo-screenshot.png`.
- Open `inbox/demo-yt-example.md` — confirm the YAML frontmatter renders, the embedded `![[demo-screenshot.png]]` resolves, and the `## Sources Cited` / `## Actionable Insights` / `## Follow-ups` sections are present.
- Obsidian has no banner integration yet — the public/private warning is editor-side only (Neovim winbar, Vim statusline). Use the file path itself as the visual cue in Obsidian.

#### 2. Neovim

`setup-km.sh` already ran `Lazy! sync` headlessly during install, so plugins are present.

```bash
nvim daily/demo-$(date +%Y-%m-%d).md
```

In that buffer you should see:

| What | Where it comes from |
|---|---|
| Green **winbar** at the top: `PUBLIC PARA · daily` | `config/nvim/lua/config/autocmds.lua` (KMBanner) |
| Yellow `TODO:`, orange `FIXME:`, red `BUG:` when you type them | `config/nvim/lua/plugins/todo-comments.lua` |
| `<leader>od / on / os / oo / ob / og` keymaps work | `config/nvim/lua/plugins/obsidian.lua` |

Flip to the private side to confirm the banner turns red:

```bash
mkdir -p private-inbox && echo '# private test' > private-inbox/demo-private.md
nvim private-inbox/demo-private.md         # red "⚠ PRIVATE PARA · private-inbox" winbar
rm private-inbox/demo-private.md
```

If the banner or highlights are missing, re-run `bash setup-km.sh` (idempotent) or sync plugins manually: `NVIM_APPNAME=km nvim --headless "+Lazy! sync" +qa`.

#### 3. Vim

`env.sh` exports `VIMINIT="source $KM_ROOT/config/vim/vimrc"`, so plain vim picks up the project config automatically without symlinking your `~/.vimrc`.

```bash
EDITOR=vim okm open inbox/demo-meeting-notes.md
```

You should see:

| What | Where it comes from |
|---|---|
| Green **statusline** band: `PUBLIC PARA · inbox` | `config/vim/vimrc` (KMBanner) |
| Yellow `TODO:`, orange `FIXME:`, red `BUG:` | `config/vim/vimrc` (KMTodoHighlights via `matchadd`) |

The same private-side test works:

```bash
EDITOR=vim vim private-inbox/demo-private.md  # red "⚠ PRIVATE PARA" statusline
```

#### Tear down

```bash
bash scripts/seed-demo.sh --teardown       # removes only demo-* files; real notes untouched
```

For full reference: [Templates](#templates) · [Demo Dataset](#demo-dataset) · [Workflow](#workflow).

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
├── tests/                          # BATS test suite
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
| **Vim** | `EDITOR=vim okm today` | Project vimrc via `VIMINIT` (sources `~/.vimrc` first); TODO/FIXME/BUG colored |

- **Capture**: `okm today` (daily note) or `okm capture <text>` (timestamped)
- **Search**: `okm grep <pattern>` (content) or `okm files [pattern]` (paths)
- **Sync**: `okm sync [message]` — stages all, commits, rebases, pushes
- **Test before merge**: `bash tests/run_all.sh`
- **Commit conventions**: one logical change per commit; `okm sync` defaults to `vault sync YYYY-MM-DD HH:MM:SS`
- **Ask before**: destructive ops (`rm -rf`, force push), scope creep beyond requested files

For auto-activation with [direnv](https://direnv.net/), the repo includes `.envrc`. Run `direnv allow .` to activate it.

---

## Out of scope

| Item | Reason |
|---|---|
| `private-*/` note bodies | AI-private; only structural metadata is read |
| `_skills/` content | Manually curated; agents don't auto-modify |
| `disclaimer.md` | Manually maintained legal text |
| `okm link/backlinks/stats` | One-liner `rg` commands, not worth subcommands |
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
| `okm tags [note]` | List all tags with counts, or tags for a specific note |
| `okm tag <note> <tag> [...]` | Add tag(s) to a note's frontmatter |
| `okm untag <note> <tag> [...]` | Remove tag(s) from a note's frontmatter |
| `okm tagged <tag>` | List all notes with a given tag |
| `okm obs` | Launch Obsidian GUI |
| `okm path` | Print vault path |

`okm new`, `okm capture`, and `okm spot` accept `-t tag1,tag2` to set tags at creation time.

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
| `<leader>ot` | `:ObsidianTemplate` | Insert template |
| `<leader>op` | `:ObsidianPasteImg` | Paste image into attachments/ |
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

| Source | Command | Network? | Status |
|---|---|---|---|
| YouTube (has captions) | `okm yt <URL>` | One-time fetch | **Planned** |
| YouTube (no captions) | `okm yt <URL>` → whisperX | Fetch + local | **Planned** |
| Spotify episode | `okm spot <URL>` → `spotdl` | One-time fetch | Shipped |
| Spotify track/album/playlist | `okm spot <URL>` | One-time fetch | Shipped |
| Podcast | Check [Happy Scribe](https://podcasts.happyscribe.com) first | One-time fetch | Manual |
| Local audio | `okm pod <file> "Title"` | Fully offline | **Planned** |
| Summarise | `okm distill <note>` or `okm distill --local <note>` | Claude / Ollama | **Planned** |

### Note anatomy

Templates live in `inbox/templates/` — one file per markdown type the system produces. Each starts with a `Format Specification:` HTML comment block declaring required frontmatter, sections, and the producing command/script. See [Templates](#templates) for the full list.

**YouTube notes** (`okm yt` — planned, see [roadmap.md](roadmap.md)):

| Section | How it's produced |
|---|---|
| Frontmatter (source_type, url, author, tags) | Auto-generated |
| Thumbnail (`![[file.png]]`) | Auto-saved |
| Summary (3-5 caveman-speech bullets) | `okm distill` (planned) or manual |
| Structured data table | `okm distill` (planned) or manual |
| Key quotes (`> [MM:SS] "..."`) | `okm distill` (planned) or manual |
| Screenshots (`![[screenshot.png]]`) | mpv `s` key during playback |
| Timestamps (chapter markers) | Auto-extracted |
| Transcript (full text) | Fetched or whisperX |

**Spotify notes** (`okm spot`):

| Section | How it's produced |
|---|---|
| Frontmatter + player embed iframe | Auto-generated |
| Summary + key quotes + transcript | Episodes only — `okm distill` (planned) or manual |
| Notes section | Tracks/albums/playlists — lighter template |

**Summary style:** short sentences, no filler, bullets over paragraphs, numbers over prose, tables for structured data.

---

## Templates

`inbox/templates/` holds one canonical template per markdown file type. Each begins with a `<!-- Format Specification: ... -->` block declaring required frontmatter, required sections, and the producing command. Use these as references when writing notes by hand or when the LLM needs to know what a "podcast note" should look like.

| Template | Producer | Purpose |
|---|---|---|
| `daily-template.md` | `okm today` | Daily note (Captures / Notes / Tasks / Reflection) |
| `note-template.md` | `okm new <title>` | Generic project note (Context / Notes / Links) |
| `capture-template.md` | `okm capture [text]` | Timestamped quick-capture |
| `yt-template.md` | `okm yt <URL>` (**planned**) + mpv | YouTube video with screenshots, quotes, transcript |
| `spotify-episode-template.md` | `okm spot <URL>` | Spotify episode (transcript flow) |
| `spotify-track-template.md` | `okm spot <URL>` | Track / album / playlist (no transcript) |
| `podcast-template.md` | `okm pod <file> "Title"` (**planned**) | Local audio transcribed via whisperX |
| `todo-summary-template.md` | `scripts/todo-summary.sh --output` | Yearly PARA TODO scan (cron) |
| `weekly-template.md` | `scripts/weekly-tasks.sh --output` | Weekly task summary (cron) |
| `archive-template.md` | manual move to `archive/` | Archived note with `archived_date` + `archive_reason` |

---

## Demo Dataset

Populate the public PARA folders with demo content derived from the templates so you can exercise every part of the system end-to-end.

```bash
bash scripts/seed-demo.sh             # seed demo-* files (idempotent)
# ...verify with the printed checklist (okm files demo-, okm grep, okm today, ...)
bash scripts/seed-demo.sh --teardown  # remove every demo-* file
bash scripts/seed-demo.sh --help      # usage
```

What gets seeded (11 files, all gitignored automatically):

| Folder | Files |
|---|---|
| `daily/` | `demo-YYYY-MM-DD.md` |
| `inbox/` | `demo-meeting-notes.md`, `demo-capture.md`, `demo-yt-example.md`, `demo-spotify-episode.md`, `demo-spotify-track.md`, `demo-podcast.md`, `demo-todo-summary-YYYY.md`, `demo-weekly-START-to-END.md` |
| `attachments/` | `demo-screenshot.png` (1×1 placeholder) |
| `archive/` | `demo-completed-project.md` |

Demo content is **only seeded into the public PARA folders**. The `private-*/` mirrors are never touched — banners are how you tell which side you're editing on.

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
3 7 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
3 15 * * * /usr/bin/bash $KM/scripts/todo-summary.sh --output
0 7 * * * /usr/bin/bash $KM/scripts/weekly-tasks.sh --output
0 12 * * * /usr/bin/bash $KM/scripts/weekly-tasks.sh --output
0 15 * * * /usr/bin/bash $KM/scripts/weekly-tasks.sh --output
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

The full roadmap, critique, and ship plan live in **[roadmap.md](roadmap.md)**.

**Current state:** suite is green (292 tests, 0 failures). v0 is **yellow, not green** — four review passes have surfaced bugs the previous pass missed (B1–B5, F1–F7, N1–N25), and a fuzz/property-test harness over `bin/okm` is the recommended final gate before tagging v0.

`roadmap.md` covers:

- **[Scope by Version](roadmap.md#scope-by-version)** — what lands in v0, v1, and v2 (table)
- **[Recommended Ship Plan](roadmap.md#recommended-ship-plan)** — clustered fixes in merge order
- **[Pre-v0 Blockers](roadmap.md#pre-v0-blockers)** (B1–B5) and **[Known Bugs](roadmap.md#known-bugs)** (F1–F7)
- **Findings by review pass** — [second](roadmap.md#second-pass-findings) (N1–N9), [third](roadmap.md#third-pass-findings) (N10–N15), [fourth](roadmap.md#fourth-pass-findings) (N16–N25 + fuzz harness)
- **[Tagging Gaps](roadmap.md#tagging-gaps-to-close)**, **[Polish](roadmap.md#polish)**, and **[Planned Features](roadmap.md#planned-features)** (`okm yt` / `pod` / `distill`, macOS, git-crypt init, …)
- **[Skills Roadmap](roadmap.md#skills-roadmap)** — already-shipped editor and template skills

---

## See Also

- `roadmap.md` — full v0/v1/v2 roadmap, critique, and ship plan
- `ai-instructions.md` — AI assistant rules
- `_skills/README.md` — AI skills library
- `scripts/README.md` — cron job documentation
- `setup-km.sh` — canonical source for versions and defaults
