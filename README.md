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
- One script bootstraps everything — `setup-kms.sh` is idempotent and safe to re-run

---

## Quickstart

```bash
bash setup-kms.sh        # install everything: Obsidian, Neovim, vim, okm, lazygit
source ~/.zshrc           # reload shell
bash verify-kms.sh       # confirm all tools installed correctly
```

Then pick your editor:

| Editor | How to start | Notes |
|---|---|---|
| **Obsidian** | `obs` | First launch: open `/home/aws/workspace/knowledge-management-system` as vault |
| **Neovim** | `okm today` | Plugins auto-bootstrap on first launch. `:Lazy sync` if needed |
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

## Project Structure

```
knowledge-management-system/
  daily/               ← one file per day (YYYY-MM-DD.md)
  inbox/               ← named notes and quick captures
  attachments/         ← images, PDFs, other assets
  config/
    nvim/              ← Neovim config (symlinked to ~/.config/nvim)
    lazygit/           ← lazygit config (symlinked to ~/.config/lazygit)
  scripts/
    todo-summary.sh    ← PARA-structured TODO/task scanner (runs on cron)
  _skills/             ← privacy framework reference library for AI tools
  ai-instructions.md   ← rules for AI assistants in this vault
  setup-kms.sh         ← idempotent bootstrap script
  verify-kms.sh        ← post-install verification script
  .gitignore           ← excludes attachments, OS noise, editor swap files
```

---

## Stack

| Tool | Role | Installed by |
|---|---|---|
| Obsidian | GUI vault viewer, graph view | Flatpak (network revoked) |
| Neovim | Primary terminal editor | `~/bin/nvim` via GitHub release |
| obsidian.nvim | Vault integration in Neovim (nav, backlinks, search) | lazy.nvim auto-bootstrap |
| lazygit | TUI git client | `~/bin/lazygit` via GitHub release |
| okm | Vault CLI (notes, search, sync) | `~/bin/okm` written by setup |
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
| `grep` | `okm grep <pattern>` | ripgrep across all `.md` files |
| `files` | `okm files [pattern]` | List all `.md` paths, optionally filtered |
| `recent` | `okm recent` | fzf picker over 200 most recently modified notes |
| `sync` | `okm sync [message]` | Stage all → commit → pull --rebase → push |
| `obs` | `okm obs` | Launch Obsidian GUI |
| `path` | `okm path` | Print vault path |

**Environment variables** (set in `~/.zshrc` by setup):

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | `/home/aws/workspace/knowledge-management-system` | Vault root |
| `OBSIDIAN_DAILY_DIR` | `daily` | Where `okm today` writes |
| `OBSIDIAN_NOTES_DIR` | `inbox` | Where `okm new` / `okm capture` write |
| `EDITOR` | `nvim` | Editor for all note commands |

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

Config: `config/nvim/lua/plugins/obsidian.lua` (symlinked to `~/.config/nvim/`).

---

## Automated TODO Summary (Cron)

`scripts/todo-summary.sh` scans the project and vault for open work items and generates a PARA-structured checklist.

**Schedule:** runs at 07:00 and 12:00 daily.

**PARA mapping:**

| Marker | PARA bucket |
|---|---|
| `TODO:` `FIXME:` `HACK:` `XXX:` | **Projects** — active work to close out |
| `- [ ]` unchecked tasks | **Areas** — ongoing responsibilities |
| `REVIEW:` | **Resources** — items to evaluate |

```bash
bash scripts/todo-summary.sh              # print to stdout
bash scripts/todo-summary.sh --output     # write to inbox/todo-summary-YYYY-MM-DD.md
```

**System crontab (persistent):**
```bash
# crontab -e
3 7 * * * /usr/bin/bash /home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output
3 12 * * * /usr/bin/bash /home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output
```

See `scripts/README.md` for full details.

---

## Setup Details

### What `setup-kms.sh` does

1. Installs apt packages: vim, git, ripgrep, fzf, curl, xclip, wl-clipboard, flatpak
2. Installs Obsidian via Flatpak; revokes its network permission
3. Downloads Neovim and lazygit binaries to `~/bin/`
4. Creates vault directories (`daily/`, `inbox/`, `attachments/`)
5. Writes `~/bin/okm` and shell config to `~/.zshrc`
6. Symlinks Neovim and lazygit configs (or installs `obsidian.lua` into existing config)
7. Bootstraps Neovim plugins, initialises git repo, optionally sets remote
8. Enforces offline mode as the final step

Safe to re-run — every step is guarded (checks `dpkg -s`, SHA-256 hashes, existing dirs/files).

Logs: `~/.local/log/setup-kms-YYYYMMDD-HHMMSS.log`

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
| whisperX (large-v3-turbo model) | Local transcription with speaker diarization |
| ffmpeg | Audio format conversion |
| mpv | Video playback with screenshot capture |
| Claude Code / Ollama | Summarisation and citation extraction |

### Workflow

| Source | Command | Network? |
|---|---|---|
| YouTube (has captions) | `okm yt <URL>` | One-time fetch |
| YouTube (no captions) | `okm yt <URL>` → downloads audio → whisperX | Fetch, then local |
| Podcast (known show) | Check [Happy Scribe](https://podcasts.happyscribe.com) first | One-time fetch |
| Local audio/podcast file | `okm pod <file> "Title"` | Fully offline |
| Distillation | `okm distill <note>` (Claude) or `okm distill --local <note>` (Ollama) | Claude: yes / Ollama: no |

### Note format

```yaml
---
title: "Episode Title"
source_type: podcast | youtube | audio
source_url: "https://..."
author: "Host / Channel"
tags: [source/podcast, topic/machine-learning]
---
```

### Implementation status

- **Phase 1** (core pipeline): install yt-dlp, whisperX, ffmpeg, mpv. Add `okm yt` and `okm pod`.
- **Phase 2** (online toggle): add `okm online` / `okm offline`.
- **Phase 3** (summarisation): add `okm distill` with Claude and Ollama backends.

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

## Open Items

| Item | Priority |
|---|---|
| Initialise git-crypt | High |
| Install yt-dlp + whisperX + ffmpeg + mpv | High |
| Get HuggingFace token for pyannote (speaker diarization) | High |
| Add `okm yt` and `okm pod` subcommands | High |
| Add `okm online` / `okm offline` toggle | Medium |
| Configure mpv screenshot directory | Medium |
| SSH key generation | Medium |
| Add `okm distill` subcommand | Low |
| Install Ollama + `llm` CLI | Low |
| Audit `.obsidian/` plugin configs | Low |

---

## See Also

- `ai-instructions.md` — rules for AI assistants in this vault
- `_skills/README.md` — privacy skills library
- `setup-kms.sh` — canonical source for installed versions, paths, and defaults
- `verify-kms.sh` — post-install verification
- `scripts/README.md` — automated TODO summary cron documentation
