# Knowledge Management

Personal notes, daily logs, and captured ideas — managed via the `okm` CLI and visualised in Obsidian, with full terminal editing via Neovim.

---

## Quickstart

### Step 1 — Run setup (all scenarios)

```bash
bash setup-kms.sh        # install everything: Obsidian, Neovim, vim, okm, lazygit
source ~/.zshrc           # reload shell to pick up PATH, EDITOR, and aliases
bash verify-kms.sh       # confirm all tools installed correctly
```

---

### Scenario A — Obsidian GUI only

No terminal editing required. Obsidian's built-in editor handles everything.

```bash
obs                      # launch Obsidian GUI (alias for flatpak run md.obsidian.Obsidian)
```

**First launch only:** Obsidian will ask how to open the vault. Choose **Open folder as vault** and select:
```
/home/aws/workspace/knowledge-management-system
```

From then on Obsidian remembers the vault. Use its built-in UI to create notes, browse the graph, search, and manage daily notes.

> [!tip] Daily note
> Use the `okm today` command in any terminal to create today's note, then switch to Obsidian to view or edit it — changes sync instantly since both tools read the same files.

---

### Scenario B — Neovim

Full vault integration via `obsidian.nvim`. Requires the first launch to download plugins.

```bash
nvim                     # first launch: lazy.nvim bootstraps and downloads plugins automatically
                         # run :Lazy sync if plugins do not auto-install
okm today                # create/open today's daily note in Neovim
```

**Key commands inside Neovim:**

| Command | What it does |
|---|---|
| `:ObsidianToday` | Open today's daily note |
| `:ObsidianNew <title>` | Create a new named note in `inbox/` |
| `:ObsidianSearch` | Full-text search across all notes (requires `rg`) |
| `:ObsidianOpen` | Open the current note in the Obsidian GUI |
| `:ObsidianFollowLink` | Follow a `[[wikilink]]` under the cursor |
| `:ObsidianBacklinks` | Show all notes linking to the current note |

**`okm` CLI commands (work from any terminal):**

```bash
okm today                # open/create today's daily note
okm new "my note title"  # create a new named note in inbox/
okm capture "quick idea" # timestamped quick-capture note
okm recent               # fzf picker over 200 most recently modified notes
okm sync "message"       # git add + commit + pull + push
```

---

### Scenario C — Vim

Plain `vim` is installed by setup and works as a drop-in editor for all `okm` commands. No plugins required.

**Switch the default editor to vim:**

```bash
# Add this line to ~/.zshrc after the setup-kms block, then source ~/.zshrc
export EDITOR=vim
```

Or run one-off:
```bash
EDITOR=vim okm today     # override for a single command
```

**Workflow:**

```bash
okm today                # create/open today's daily note in vim
okm new "my note title"  # create and open a new note in vim
okm capture              # open a blank timestamped capture note in vim
okm grep "search term"   # search across all notes (uses ripgrep)
okm recent               # fzf picker — opens selected note in $EDITOR
okm sync                 # commit and push all changes
```

Vim has no vault-specific plugins in this setup. Notes are plain Markdown — vim's built-in syntax highlighting works out of the box. `[[wikilink]]` navigation and backlinks require Neovim + obsidian.nvim.

---

## Installation Checklist

Run `bash verify-kms.sh` after setup to confirm every item. The script prints `PASS`, `FAIL`, or `WARN` for each and exits non-zero if any required check fails.

### Automated by `setup-kms.sh`

These are installed or configured when you run `bash setup-kms.sh`:

- [ ] **git** — version control (`apt`)
- [ ] **vim** — fallback editor (`apt`)
- [ ] **ripgrep** — fast full-text search (`apt`)
- [ ] **fzf** — fuzzy file picker (`apt`)
- [ ] **curl** — required for binary downloads (`apt`)
- [ ] **xclip** — clipboard bridge for X11 (`apt`)
- [ ] **wl-clipboard** — clipboard bridge for Wayland (`apt`)
- [ ] **flatpak** — Obsidian container runtime (`apt`)
- [ ] **Obsidian** — GUI vault viewer (`flatpak install flathub md.obsidian.Obsidian`)
- [ ] **Neovim** — primary terminal editor (`~/bin/nvim` via GitHub release tarball)
- [ ] **lazygit** — TUI git client (`~/bin/lazygit` via GitHub release tarball)
- [ ] **okm** — vault CLI (`~/bin/okm` written by setup)
- [ ] **Vault directories** — `daily/`, `inbox/`, `attachments/`
- [ ] **`.gitignore`** — excludes attachments, OS noise, swap files
- [ ] **git repo** — vault initialised as a git repository
- [ ] **Neovim config** — if no prior config: `~/.config/nvim` symlinked to `config/nvim/` in vault; if existing config: `obsidian.lua` installed into it and update checker disabled
- [ ] **Shell exports** — `EDITOR`, `OBSIDIAN_VAULT`, `OBSIDIAN_DAILY_DIR`, `OBSIDIAN_NOTES_DIR`, `PATH`, `obs` alias in `~/.zshrc`

### Offline mode enforcement (automated by `setup-kms.sh`)

- [ ] **Obsidian network revoked** — `flatpak override --user --unshare=network md.obsidian.Obsidian` (hard container boundary)
- [ ] **lazygit config symlinked** — `~/.config/lazygit` → `config/lazygit/` in vault
- [ ] **lazygit update checks disabled** — `update.method: never` in `config/lazygit/config.yml`
- [ ] **lazy.nvim checker disabled** — `enabled = false` in `lua/config/lazy.lua` (existing config) or `config/nvim/init.lua` (fresh symlink)
- [ ] **Neovim plugins bootstrapped** — downloaded once during setup; offline thereafter

### Requires first `nvim` launch

These download automatically when `nvim` is opened for the first time:

- [ ] **lazy.nvim** — plugin manager (bootstraps from `config/nvim/init.lua`)
- [ ] **obsidian.nvim** — vault integration plugin (installed by lazy.nvim)
- [ ] **plenary.nvim** — obsidian.nvim dependency (installed by lazy.nvim)

To trigger: `nvim` then `:Lazy sync` if plugins do not auto-install.

### Manual steps (not automated)

- [ ] **SSH key** — `ssh-keygen -t ed25519 -C kms-vault` then add public key to git host
- [ ] **Git remote** — `git -C "$(okm path)" remote add origin <url>`
- [ ] **git-crypt** — initialise before first remote push of note content (see [git-crypt](#git-crypt))

---

## Stack Overview

| Tool | Role | Status |
|---|---|---|
| Obsidian | GUI vault viewer, graph view, plugin ecosystem | Installed via Flatpak |
| Neovim | Primary terminal editor | Installed to `~/bin/nvim` via GitHub release tarball |
| lazy.nvim | Neovim plugin manager | Auto-bootstraps on first `nvim` launch via `config/nvim/init.lua` |
| obsidian.nvim | Neovim plugin: vault nav, note creation, backlinks, search | Config at `config/nvim/lua/plugins/obsidian.lua` |
| ripgrep | Fast full-text search; used by `okm grep` and `obsidian.nvim` | Installed via apt |
| git | Version control for vault notes | Installed via apt |
| SSH | Encrypted transport for git remote operations | Key generation not yet automated — see [Open Items](#open-items) |
| lazygit | TUI git client for visual commit, diff, and history operations | Installed to `~/bin/lazygit` via GitHub release tarball |
| xclip / wl-clipboard | Clipboard bridge between terminal (Neovim) and GUI | Installed via apt |
| fzf | Fuzzy file picker; used by `okm open` and `okm recent` | Installed via apt |

---

## Vault Structure

```
knowledge-management-system/
  daily/               ← one file per day (YYYY-MM-DD.md)
  inbox/               ← named notes and quick captures
  attachments/         ← images, PDFs, other assets
  config/nvim/         ← Neovim config (symlinked to ~/.config/nvim by setup)
  config/lazygit/      ← lazygit config (symlinked to ~/.config/lazygit by setup)
  _skills/             ← privacy framework reference library for AI tools
  README.md            ← this file
  ai-instructions.md   ← rules for AI assistants in this vault
  setup-kms.sh         ← idempotent bootstrap script
  verify-kms.sh        ← post-install verification script
  .gitignore           ← excludes attachments, OS noise, editor swap files
```

- `daily/` — daily notes created by `okm today`. One file per calendar day.
- `inbox/` — named notes from `okm new` (slugified title) and timestamped captures from `okm capture`.
- `attachments/` — binary and non-markdown assets; reference them from notes with standard markdown links.
- `_skills/` — privacy framework reference library for AI tools. Contains [[_skills/privacy-by-design]], [[_skills/contextual-integrity]], [[_skills/sensitive-data-categories]], [[_skills/data-minimisation]], and [[_skills/ai-privacy-risks]].
- `.gitignore` — written by `setup-kms.sh`. Excludes `.obsidian/workspace.json` (changes on every session), common binary attachment types, OS noise, and editor swap files. To track a specific attachment, remove its pattern or use `git add -f`.

---

## Setup

### First run

```bash
bash setup-kms.sh [git-remote-url]
```

What it does:
- Installs apt packages: `vim git ripgrep fzf xdg-utils flatpak xclip wl-clipboard curl`
- Installs Obsidian via Flatpak from Flathub; revokes its network permission
- Downloads Neovim binary to `~/bin/nvim` and lazygit binary to `~/bin/lazygit`
- Creates `daily/`, `inbox/`, `attachments/` directories
- Writes `~/bin/okm`, appends env vars and alias to `~/.zshrc` (`EDITOR=nvim`)
- Symlinks `~/.config/lazygit` → `config/lazygit/` in vault
- If no `~/.config/nvim` exists: symlinks it to `config/nvim/` in vault. If one exists: installs `obsidian.lua` into it and disables the lazy.nvim update checker
- Bootstraps Neovim plugins via `nvim --headless "+Lazy! sync" +qa`
- Initialises a git repo; optionally sets remote and pushes (remote URL is optional)

### Re-running (idempotent)

> [!tip] Safe to re-run
> Every step is guarded — re-running on an already-configured machine skips what's already in place:
> - apt packages checked via `dpkg -s` — only missing ones are installed; `apt update` is skipped if all present
> - Obsidian skipped if already in `flatpak list`
> - Directories skipped if they exist
> - `okm` binary skipped if SHA-256 hash matches; overwrites with a warning if content changed
> - Shell lines skipped if already present in `~/.zshrc`
> - Git repo skipped if `.git/` exists

### Post-setup

```bash
source ~/.zshrc   # reload shell to pick up PATH, EDITOR, alias
okm today         # verify okm is working
```

Logs from each run are written to `~/.local/log/setup-kms-YYYYMMDD-HHMMSS.log`. On failure the script logs the failing command, line number, and exit code, then exits non-zero.

---

## Neovim + lazy.nvim + obsidian.nvim

> [!note] Installed by `setup-kms.sh`
> Neovim binary is downloaded to `~/bin/nvim`. `EDITOR=nvim` is set in `~/.zshrc`. Config behaviour depends on whether a pre-existing `~/.config/nvim` exists:
> - **No existing config** — `~/.config/nvim` is symlinked to `config/nvim/` in this vault
> - **Existing config** — `obsidian.lua` is copied into `~/.config/nvim/lua/plugins/` and the lazy.nvim update checker is disabled in-place; your config is otherwise untouched

### Why Neovim

Neovim provides:
- Lua-based configuration (more maintainable than vimscript)
- `lazy.nvim` plugin manager with lazy-loading and lock files
- `obsidian.nvim` for first-class vault integration directly in the terminal

### lazy.nvim

[lazy.nvim](https://github.com/folke/lazy.nvim) is the plugin manager. It:
- Auto-bootstraps on first `nvim` launch if the config is in place
- Maintains a `lazy-lock.json` for reproducible plugin versions
- Supports lazy-loading plugins by command, filetype, or keymap

Configuration root: `~/.config/nvim/`

### obsidian.nvim

[obsidian.nvim](https://github.com/epwalsh/obsidian.nvim) integrates the vault into Neovim. Key capabilities:

| Command | What it does |
|---|---|
| `:ObsidianNew <title>` | Create a new note (mirrors `okm new`) |
| `:ObsidianToday` | Open today's daily note (mirrors `okm today`) |
| `:ObsidianSearch` | ripgrep-powered full-text search with fzf |
| `:ObsidianOpen` | Open current note in Obsidian GUI |
| `:ObsidianBacklinks` | Show all notes that link to the current note |
| `:ObsidianTags` | Browse notes by tag |
| `:ObsidianFollowLink` | Follow `[[wikilink]]` under cursor |

**Config** (`config/nvim/lua/plugins/obsidian.lua` in vault, symlinked to `~/.config/nvim/`):
```lua
return {
  "epwalsh/obsidian.nvim",
  version = "*",
  lazy = true,
  ft = "markdown",
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    workspaces = {
      { name = "personal", path = vim.env.OBSIDIAN_VAULT or "/home/aws/workspace/knowledge-management-system" },
    },
    daily_notes = {
      folder = "daily",
      date_format = "%Y-%m-%d",
    },
    notes_subdir = "inbox",
  },
}
```

**ripgrep dependency**: `obsidian.nvim` search requires `rg` on `$PATH`. Already installed by `setup-kms.sh`.

---

## SSH and Git Remote

### Why SSH over HTTPS

Using SSH for git remotes means:
- No stored passwords or tokens on disk
- Authentication is by key, not credential helper
- The remote URL is in the form `git@github.com:user/repo.git` — no username embedded

### Generating an SSH key

If no key exists at `~/.ssh/id_ed25519`:
```bash
ssh-keygen -t ed25519 -C "kms-vault" -f ~/.ssh/id_ed25519
```
- Use a strong passphrase. The passphrase protects the private key at rest.
- Add the public key (`~/.ssh/id_ed25519.pub`) to the git host (GitHub, Gitea, etc.).

### ssh-agent

To avoid re-entering the passphrase on every push:
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

Add to `~/.zshrc` for automatic agent startup:
```bash
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
```

### SSH config

`~/.ssh/config` can set a preferred key per host:
```
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  AddKeysToAgent yes
```

> [!warning] SSH key setup is not yet automated. See [Open Items](#open-items).

---

## lazygit

[lazygit](https://github.com/jesseduffield/lazygit) is a TUI git client that complements `okm sync` for cases requiring more control:
- Visual staging of individual hunks (partial commits)
- Interactive rebase
- Branch/stash management
- Diff viewing with syntax highlighting

Installed to `~/bin/lazygit` by `setup-kms.sh` (latest release from GitHub).

**Usage in vault:**
```bash
lazygit -p "$(okm path)"
```

---

## Clipboard Integration (xclip / wl-clipboard)

Neovim's `+` and `*` registers require a clipboard provider to bridge the terminal and GUI clipboard.

| Display server | Tool | Package |
|---|---|---|
| X11 | xclip | `apt install xclip` |
| Wayland | wl-clipboard | `apt install wl-clipboard` |

Neovim auto-detects the provider via `vim.fn.has('clipboard')`. With either tool installed, `"+y` copies to the system clipboard and `"+p` pastes from it.

**Detect which display server is running:**
```bash
echo $XDG_SESSION_TYPE   # "x11" or "wayland"
```

> [!tip]
> Install both packages — the correct one is used automatically based on the active session. This also covers SSH-forwarded clipboard scenarios where the session type may differ.

---

## okm CLI

`okm` is a bash CLI installed to `~/bin/okm` by `setup-kms.sh`.

| Subcommand | Syntax | What it does |
|---|---|---|
| `open` | `okm open [path]` | Open a specific note or launch an fzf fuzzy-picker over all `.md` files |
| `new` | `okm new <title>` | Create a slugified note in `$OBSIDIAN_NOTES_DIR` with YAML frontmatter, open in `$EDITOR` |
| `capture` | `okm capture [text]` | Create a timestamped quick-capture note tagged `[capture, inbox]`, open in `$EDITOR` |
| `today` | `okm today` | Open (or create) today's daily note at `daily/YYYY-MM-DD.md` with Tasks and Notes sections |
| `grep` | `okm grep <pattern>` | Run `ripgrep` across all `.md` files; prints filename and line number |
| `files` | `okm files [pattern]` | List all `.md` paths relative to vault root, optionally filtered by a case-insensitive string |
| `recent` | `okm recent` | fzf picker over the 200 most recently modified `.md` files |
| `sync` | `okm sync [message]` | Stage all, commit, pull --rebase --autostash, push; skips push if no upstream configured |
| `obs` | `okm obs` | Launch Obsidian in the background via `flatpak run md.obsidian.Obsidian` |
| `path` | `okm path` | Print the resolved vault path (`$OBSIDIAN_VAULT`) |

> [!note] Dependencies
> `okm open` and `okm recent` require `fzf`. `okm grep` requires `rg`. Both are installed by `setup-kms.sh`. All other subcommands work without them.

---

## obs Alias

`obs` is a shell alias for `flatpak run md.obsidian.Obsidian`, written to `~/.zshrc` by `setup-kms.sh`. It opens the Obsidian GUI directly without going through `okm`. Equivalent to `okm obs`.

---

## Environment Variables

All four are written to `~/.zshrc` by `setup-kms.sh`. Override them after the setup block to change behaviour without touching the script.

| Variable | Default | Purpose |
|---|---|---|
| `OBSIDIAN_VAULT` | `/home/aws/workspace/knowledge-management-system` | Absolute path to vault root; all `okm` subcommands resolve paths against this |
| `OBSIDIAN_DAILY_DIR` | `daily` | Subdirectory (relative to vault) where `okm today` writes notes |
| `OBSIDIAN_NOTES_DIR` | `inbox` | Subdirectory where `okm new` and `okm capture` write notes |
| `EDITOR` | `nvim` | Editor binary invoked by all note-opening subcommands |

---

## Git Sync Workflow

Edit locally, then sync with `okm sync [message]`.

What `okm sync` does in order:
1. `git add -A` — stages everything including new files and deletions
2. `git commit -m "<message>"` — skipped silently if there are no staged changes
3. `git pull --rebase --autostash` then `git push` — only if an upstream branch is configured

> [!warning] No upstream configured
> If `setup-kms.sh` was run without a remote URL, push and pull are skipped with a notice. To add one later:
> ```bash
> git -C "$(okm path)" remote add origin <url>
> okm sync
> ```

The vault is a standard git repo. Advanced use: `git -C "$(okm path)" <any-git-command>`.

---

## git-crypt

> [!warning] Not yet set up
> git-crypt is the chosen approach for encrypting note content in the remote repository. It is not yet initialised in this vault. See [Open Items](#open-items).

### What it is

[git-crypt](https://github.com/AGWA/git-crypt) sits between your working tree and the git object store. Files matching patterns in `.gitattributes` are transparently encrypted when committed and decrypted when checked out — but only on machines that have been unlocked with the key. On the remote (GitHub, Gitea, etc.) those files are opaque binary blobs.

Encryption algorithm: AES-256 in CTR mode, one random nonce per file per commit.

### Two modes

| Mode | How it works | Best for |
|---|---|---|
| Symmetric key | `git-crypt init` generates a 32-byte random key stored in `.git/git-crypt/keys/default`; export and back up with `git-crypt export-key` | Single-user vault; simpler setup |
| GPG | Key is sealed with one or more GPG public keys; each keyholder decrypts with their private key | Multi-user or when you already maintain a GPG identity |

For a personal vault, symmetric key is the simpler and sufficient choice.

### Setup (symmetric key)

```bash
# Install
sudo apt install git-crypt

# Initialise inside the vault
cd "$(okm path)"
git-crypt init

# Export and back up the key — this file IS the secret; store it outside the vault
git-crypt export-key ~/git-crypt-kms.key
# Put this key in your password manager (Bitwarden, 1Password, pass, etc.)

# Declare which files to encrypt in .gitattributes
# Operational files (README, setup scripts, _skills/) stay plaintext
cat >> .gitattributes <<'EOF'
daily/*.md filter=git-crypt diff=git-crypt
inbox/*.md filter=git-crypt diff=git-crypt
EOF

git add .gitattributes
git commit -m "configure git-crypt encryption for daily and inbox notes"
```

> [!important]
> Only files committed *after* `git-crypt init` and matching the `.gitattributes` patterns will be encrypted. Any `.md` files already in git history remain in plaintext in that history. If notes were pushed before setup, consider the history permanently accessible to anyone with repo access.

### Unlocking on a new machine

```bash
git clone <remote-url> knowledge-management-system
cd knowledge-management-system
git-crypt unlock ~/git-crypt-kms.key   # key retrieved from password manager
```

After unlocking, all matching files decrypt transparently. The working tree is fully readable.

### What is and is not encrypted

| Content | Encrypted? | Reason |
|---|---|---|
| `daily/*.md` | Yes | Personal note content |
| `inbox/*.md` | Yes | Personal note content |
| `README.md` | No | Operational documentation; no personal content |
| `ai-instructions.md` | No | Operational documentation |
| `_skills/*.md` | No | Privacy framework reference; no personal content |
| `setup-kms.sh` | No | No personal data |
| `.gitattributes` | No | Must be plaintext for git-crypt to read it |
| Filenames and directory structure | No | git-crypt does not encrypt metadata — see Risks |
| Commit messages | No | git-crypt does not encrypt git history metadata |

### Risks

**Key loss — the most serious risk.**
The symmetric key is the only way to decrypt the encrypted blobs in the remote repository. git-crypt has no recovery mechanism, no escrow, and no backdoor. If the key is lost and you have no unlocked working tree copy, those files are permanently inaccessible. The encrypted objects remain in the repo forever but cannot be read.

Mitigation: store the exported key in at least two places — a password manager and an encrypted offline backup (e.g. a USB drive kept somewhere safe).

**Key exposure.**
If the key file is leaked, every encrypted commit in the repository's entire history becomes readable. git-crypt provides no forward secrecy. Changing the key requires decrypting all files, re-initialising git-crypt with a new key, and force-pushing rewritten history — treat it as a full breach response.

Mitigation: never commit the key file, never paste it into a terminal where it might be logged, and never store it inside the vault directory.

**Working tree is always plaintext.**
git-crypt only encrypts content in the git object store and on the remote. Your local working files are readable by any process with filesystem access. This is by design — your editors need to read them. Full-disk encryption (LUKS, BitLocker) or OS-level login auth handles the at-rest local risk; git-crypt handles the remote risk.

**Pre-setup history is not encrypted.**
Files committed before `git-crypt init` are in plaintext in git history, permanently. If you later add a file to `.gitattributes`, future commits are encrypted but the old plaintext blobs remain reachable via `git log` and `git show`. If the remote repo is or ever was public, assume that content is indexed.

**Filenames and metadata are not encrypted.**
git-crypt does not encrypt file paths, directory names, commit messages, author names, timestamps, or file sizes. A filename like `daily/2026-03-25.md` reveals that you write daily notes and the date. Commit timestamps reveal when you write. If these patterns are sensitive, git-crypt alone is not sufficient — you would need a different approach (encrypted container, private repo only with no public history).

**No authenticated encryption (AES-CTR without HMAC).**
git-crypt uses AES-256-CTR without a message authentication code. This means an attacker who can write to the remote repository could flip specific bits in an encrypted file and those changes would silently decrypt to corrupted content — there is no integrity check. For a personal vault where you are the only one with repo access, this is a low practical risk. If the repo is shared, prefer GPG mode (which wraps the key exchange, not the file encryption) or add a separate integrity check.

### What to do if you cannot unlock

**Scenario A: you have an unlocked local working tree.**
Your files are fine. All the plaintext lives on your machine. The lock-out only affects the remote copy and future clones. Back up your working tree immediately, then recover the key or re-initialise git-crypt.

```bash
# Verify your working tree is unlocked
git-crypt status   # shows "encrypted: unlocked" for matching files

# Back up the plaintext working tree while you still can
tar -czf ~/kms-plaintext-backup-$(date +%F).tar.gz "$(okm path)"
```

**Scenario B: you lost the key and have no unlocked working tree.**
The encrypted blobs in the remote are unrecoverable. This is the permanent data loss scenario. The repository itself still works — unencrypted files (README, scripts, skills) are all accessible. Only the daily and inbox note content is gone.

**Recovery from Scenario B:**
1. Remove the git-crypt filter from `.gitattributes` so future notes are not encrypted.
2. Delete the encrypted blobs (or leave them — they are inert without the key).
3. Generate a new key with `git-crypt init` if you want to re-enable encryption going forward.
4. Start writing notes again.

**Prevention — key backup checklist:**
- [ ] `git-crypt export-key ~/git-crypt-kms.key` run after `git-crypt init`
- [ ] Key stored in password manager (Bitwarden, 1Password, pass)
- [ ] Key stored on an encrypted USB drive or printed as a QR code and stored offline
- [ ] Key NOT stored inside the vault directory
- [ ] Key NOT committed to the repository

---

## Privacy and Security

This section describes the operational security posture for the vault. The AI-specific privacy rules are in [[ai-instructions]]; this section covers the human and system-level controls.

### Threat model

The vault holds personal notes, daily logs, and captured thoughts. The primary concerns are:

1. **Accidental disclosure** — note content exposed through AI indexing, cloud sync, or shared terminals
2. **Remote repository exposure** — notes pushed to a public or compromised git host
3. **Git history leakage** — sensitive content in commit messages or accidentally committed files
4. **Clipboard sniffing** — clipboard contents readable by any process on the desktop
5. **Unencrypted local storage** — notes readable on-disk if the machine is accessed without authentication

### Offline mode

The vault is designed to run fully offline during normal use. No background connections are permitted outside of explicit, user-initiated git operations via SSH. This is both a privacy control and a data sovereignty measure — notes never leave the machine unless you explicitly push them.

**The rule:** any process in this stack may not initiate outbound connections except `git push / pull / fetch` via the configured SSH remote (including `okm sync` and lazygit when you explicitly trigger a sync).

**Enforcement per tool:**

| Tool | Offline enforcement | Mechanism |
|---|---|---|
| Obsidian | Hard — container-level | `flatpak override --user --unshare=network` revokes the network permission from the Flatpak sandbox; Obsidian cannot bypass this regardless of its internal settings or plugins |
| lazygit | Configuration | `update.method: never` in `config/lazygit/config.yml` disables background update polling; push/pull only happens when you explicitly trigger it |
| lazy.nvim | Configuration | `checker = { enabled = false }` in `lua/config/lazy.lua` (existing config) or `config/nvim/init.lua` (vault symlink) disables update polling |
| ripgrep, fzf, okm, vim, xclip, wl-clipboard | Inherent | No network capability in these tools |
| git / SSH | Permitted path | Outbound only when explicitly invoked by the user; the only intentional external channel |

**Setup vs runtime distinction:**
`setup-kms.sh` requires internet access exactly once to download binaries and bootstrap plugins:
- apt packages (vim, git, ripgrep, fzf, curl, xclip, wl-clipboard, flatpak)
- Obsidian flatpak from Flathub
- Neovim binary from GitHub releases
- lazygit binary from GitHub releases
- Neovim plugins (lazy.nvim + obsidian.nvim + plenary.nvim) bootstrapped via `nvim --headless "+Lazy! sync" +qa`

Once setup completes, offline enforcement is applied as the final step and all subsequent use is offline. `verify-kms.sh` confirms enforcement is active.

**What is not enforced at the OS firewall level:**
Per-process firewall rules on Linux require either AppArmor/SELinux profiles or a network-namespace tool (firejail). These are intentionally out of scope here — the goal is to prevent accidental background connections from the application layer, not to harden against a compromised binary. The Flatpak sandbox covers the highest-risk tool (Obsidian, which has an update system and plugin ecosystem). For the remaining tools, configuration-level enforcement is applied and audited by `verify-kms.sh`.

### Controls in place

| Control | Mechanism |
|---|---|
| AI note body privacy | Enforced by [[ai-instructions]] — note bodies private by default |
| Binary/large file exclusion | `.gitignore` excludes attachments, OS noise, editor swap files |
| No workspace state leakage | `.obsidian/workspace.json` excluded from git |
| Generic commit messages | `okm sync` uses `vault sync YYYY-MM-DD HH:MM:SS` by default — no note content in git log |
| SSH transport | Recommended over HTTPS; no stored credentials, key auth only |
| Log URL sensitivity | Setup logs at `~/.local/log/setup-kms-*.log` may contain git remote URL; not volunteered by AI |
| Obsidian network revoked | Flatpak sandbox blocks all outbound connections from Obsidian |
| lazygit background polling disabled | `update.method: never` in versioned config |
| lazy.nvim update polling disabled | `checker = { enabled = false }` in active lazy config |

### Controls not yet in place (gaps)

| Gap | Risk | Options |
|---|---|---|
| Remote note content unencrypted | Notes pushed to remote are readable by anyone with repo access | `git-crypt` chosen — not yet initialised; see [Open Items](#open-items) |
| No `.obsidian/` config audit | Plugin configs or community plugin data could contain sensitive paths | Review `.obsidian/plugins/` before committing; add per-plugin ignore rules |
| SSH key setup not automated | User may fall back to HTTPS with stored credentials | Add SSH keygen guidance to `setup-kms.sh` or a companion script |
| Clipboard not cleared | Yanked note content persists in clipboard until overwritten | `xdotool` or `wl-copy --paste-once` for one-shot clipboard; or accept the risk |
| No audit log of AI access | No record of which files AI tools read in a session | Out of scope for CLI tooling; rely on `ai-instructions.md` rules |

### Recommended hardening steps

1. **Use a private remote repository.** GitHub private repos, self-hosted Gitea, or Forgejo all work. The remote URL should not be shared.

2. **Protect the SSH private key with a passphrase.** A key without a passphrase is equivalent to no key if the machine is compromised.

3. **Review `.obsidian/` before first commit.** The directory is tracked (except `workspace.json`). Community plugin configs may store API keys or access tokens — check before pushing.

4. **Initialise `git-crypt` before first push of note content.** Once set up, `daily/*.md` and `inbox/*.md` are encrypted in the remote repository. See the [git-crypt](#git-crypt) section for setup steps, risks, and key backup requirements.

5. **Do not store credentials in notes.** Use a dedicated password manager (Bitwarden, pass, 1Password) instead of the vault.

---

## Audio & Video Transcription → Citations Pipeline

Transcribe podcasts, YouTube videos, and audio sources into citable, searchable
notes using a minimal, offline-first toolchain.

### Fact-Check: Tools Originally Considered

Before settling on the minimal stack below, these tools were evaluated and rejected
or deferred:

| Tool | Claim | Reality | Verdict |
|---|---|---|---|
| **Snipd** | iOS podcast app with Obsidian sync via BRAT plugin | Real app (iOS + Android), AI transcription works. But the Obsidian BRAT plugin (`obsidian-snipd`) is a community beta — maintenance status uncertain, may be abandoned. Freemium with limited free-tier transcriptions. | **Deferred** — unnecessary if you already download podcast audio locally |
| **Readwise Reader** | Syncs podcast/YouTube transcripts to Obsidian | Real, ~$8–12/month subscription. Pulls *existing* transcripts only — does not run its own speech-to-text. Podcast transcript coverage is inconsistent. | **Rejected** — paid dependency for something yt-dlp does free |
| **Note Companion** | Native Obsidian plugin for YouTube + Whisper | **Does not appear to exist as described.** Likely conflated from multiple tools. Real alternatives: `obsidian-ytranscript` (YouTube captions) and `obsidian-whisper` (OpenAI Whisper API, paid per use). | **Rejected** — phantom tool |
| **Fabric** | CLI tool that processes transcripts locally, runs offline | Real and actively maintained (25k+ GitHub stars). **But requires an LLM API key** (OpenAI, Anthropic, etc.) — it sends transcripts to a cloud LLM for summarisation. The `yt` helper extracts transcripts via yt-dlp, but `fabric -p extract_wisdom` is a cloud API call. Only runs offline if you set up a local LLM via Ollama. | **Deferred** — the `yt` transcript extraction is just yt-dlp; the AI summarisation can be done by Claude directly |

### Toolchain

All free. No subscriptions, no paid API keys. Transcription runs fully local.
Summarisation uses your existing Claude Code subscription (already paid for) or
a local LLM via Ollama (free).

| Tool | Role | Install | Cost |
|---|---|---|---|
| **yt-dlp** | YouTube transcript extraction + audio download | `pip install yt-dlp` | Free |
| **youtube-transcript-api** | Cleaner YouTube transcript extraction (primary) | `pip install youtube-transcript-api` | Free |
| **whisperX** | Local transcription with speaker diarization (host vs guest) | `pip install whisperx` | Free |
| **large-v3-turbo** | Whisper model — 809M params, near-best quality at ~3x speed | Auto-downloaded by whisperX | Free (MIT) |
| **ffmpeg** | Audio format conversion | `sudo apt install ffmpeg` | Free |
| **mpv** | Video player with one-key screenshot capture | `sudo apt install mpv` | Free |
| **Claude Code** (`claude -p`) | Summarisation, citation extraction, tagging | Already installed | Already paid for |
| **Ollama** + `llm` CLI | Offline summarisation alternative | `curl -fsSL https://ollama.com/install.sh \| sh` + `pip install llm llm-ollama` | Free |

### How Each Source Is Handled

| Source | Primary tool | Fallback | Network? |
|---|---|---|---|
| YouTube (has captions) | youtube-transcript-api fetches clean text | yt-dlp `--write-auto-sub` | Yes (one-time fetch) |
| YouTube (no captions) | yt-dlp downloads audio → whisperX transcribes | — | Yes (fetch), then local |
| Downloaded podcast file | whisperX transcribes directly with speaker labels | — | No — fully offline |
| Podcast URL | yt-dlp or curl downloads → whisperX transcribes | — | Yes (fetch), then local |
| Any local audio file | whisperX transcribes directly | — | No — fully offline |
| Video screenshots | mpv: press `s` during playback | flameshot for annotation | No |

### Why whisperX Over Plain Whisper

[whisperX](https://github.com/m-bain/whisperX) wraps faster-whisper and adds two
critical features for podcasts:

1. **Speaker diarization** via pyannote.audio — identifies host vs guest and labels
   each segment (`SPEAKER_00`, `SPEAKER_01`). Specify `--min_speakers 2 --max_speakers 2`
   for typical 2-person podcasts.
2. **Word-level timestamps** via forced alignment — enables precise quote citations
   with timestamps in the output notes.

> [!note] pyannote.audio models require accepting a free license on HuggingFace and
> obtaining an access token. The models run fully locally after download.

### Why large-v3-turbo

OpenAI released Whisper large-v3-turbo in late 2024:
- **809M parameters** (vs 1,550M for large-v3) — same encoder, smaller decoder (4 layers vs 32)
- **~3x faster** than large-v3 with only marginal quality loss (<1% WER difference on clean English speech)
- **Handles technical jargon** better than smaller models (base, small, medium)
- Supported natively by whisperX, faster-whisper, and whisper.cpp

For CPU-only transcription: a 1-hour podcast takes ~2-3 hours with large-v3-turbo.
With a GPU: ~2-5 minutes.

### Summarisation Options

| Option | Quality | Privacy | Setup |
|---|---|---|---|
| **Claude Code** (`claude -p`) | Best — 200K context, nuanced extraction | Sends transcript to Anthropic servers | Zero — already installed |
| **Ollama + Llama 3.1 8B** | ~75% of Claude quality | Fully local, fully private | Install Ollama, pull model (~5GB) |
| **Ollama + Qwen 2.5 14B** | ~85% of Claude quality | Fully local, fully private | Install Ollama, pull model (~8GB), needs 16GB+ RAM |

**Claude Code approach** (recommended for non-sensitive transcripts):
```bash
cat transcript.txt | claude -p "Extract: 1) Summary bullets 2) Key quotes with speaker attribution 3) Topic tags. Format as markdown."
```

**Ollama approach** (for sensitive/private transcripts):
```bash
cat transcript.txt | llm -m llama3.1 -t summarize-transcript
```

The `llm` CLI by Simon Willison supports reusable prompt templates and logs every
interaction to a SQLite database — useful for tracking what you've processed.

### Online Mode

The vault's default posture is offline (see [Privacy and Security](#privacy-and-security)).
Transcription workflows that fetch from the internet require temporarily enabling
network access. This is handled via an `okm online` / `okm offline` toggle:

```bash
okm online                # re-enable Obsidian network; mark shell session as online
okm offline               # revoke Obsidian network; restore default posture
```

**What `okm online` does:**
1. Runs `flatpak override --user --share=network md.obsidian.Obsidian` (re-enables Obsidian network)
2. Exports `OKM_ONLINE=1` in the current shell session
3. Prints a warning that online mode is active

**What `okm offline` does:**
1. Runs `flatpak override --user --unshare=network md.obsidian.Obsidian` (revokes Obsidian network)
2. Unsets `OKM_ONLINE`
3. Confirms offline mode restored

> [!important]
> Online mode is session-scoped. Closing the terminal restores the default offline
> posture on next launch (the Flatpak override persists, but `setup-kms.sh` and
> `verify-kms.sh` re-enforce offline as the baseline). The `okm yt` and `okm pod`
> commands that need network access should check `$OKM_ONLINE` and warn if offline.

### Workflow

1. **YouTube (has captions)**: `okm yt <URL>` → youtube-transcript-api fetches clean
   text (falls back to yt-dlp) → markdown note with frontmatter and `#source/youtube`
2. **YouTube (no captions)**: `okm yt <URL>` → yt-dlp downloads audio → whisperX
   transcribes locally → markdown note
3. **Downloaded podcast**: `okm pod <file> "Episode Title"` → whisperX transcribes
   with speaker diarization (host vs guest labels) → markdown note (fully offline)
4. **Podcast URL**: `okm pod <url> "Episode Title"` → downloads audio → whisperX
   transcribes → markdown note
5. **Any audio file**: Same as podcast — `okm pod <file> "Title"`
6. **Distillation** (optional): `okm distill <note>` → pipes transcript through
   Claude Code (`claude -p`) or Ollama for summary, key quotes, and tags
7. **Screenshots**: Watch in mpv → press `s` to capture frame → auto-saved to
   `attachments/` as `VideoTitle-HH-MM-SS.png` → reference from note with
   `![[VideoTitle-HH-MM-SS.png]]`

### Note Format

Each ingested source produces a note with this structure:

```yaml
---
title: "Episode Title or Video Title"
source_type: podcast | youtube | audio
source_url: "https://..."
author: "Host / Channel / Speaker"
publish_date: 2026-03-28
captured_date: 2026-03-30
captured_via: okm-yt | okm-pod | manual
tags:
  - source/podcast
  - topic/machine-learning
---
```

Note body contains:
- Full or partial transcript with timestamps
- AI-generated summary (if distillation step was run)
- Key quotes formatted as blockquotes with timestamp citations

### Source Tagging System

Every ingested source gets tagged by type and origin so you can trace where content
came from and filter by source in search or graph view.

| Tag | When applied | Example source |
|---|---|---|
| `#source/podcast` | Any podcast episode | The Tim Ferriss Show ep. 400 |
| `#source/youtube` | Any YouTube video | 3Blue1Brown linear algebra series |
| `#source/audio` | Non-podcast audio (lectures, voice memos, interviews) | Recorded meeting, audiobook clip |
| `#source/video` | Non-YouTube video (conference talks, local files) | WWDC session, downloaded lecture |
| `#source/article` | Web articles (manual capture) | Blog post, newsletter |

The `captured_via` frontmatter field records which tool brought the content into the
vault (`okm-yt`, `okm-pod`, or `manual`). The `source_type` + `source_url` fields
let you always trace back to the original.

**Obsidian Dataview queries** (once Dataview plugin is installed):

```dataview
TABLE source_type, author, publish_date
FROM #source/podcast
SORT publish_date DESC
```

### Implementation Plan

#### Phase 1 — Core transcription pipeline

| Step | Action | Detail |
|---|---|---|
| 1 | Install Python deps | `pip install yt-dlp youtube-transcript-api whisperx` |
| 2 | Install ffmpeg + mpv | `sudo apt install ffmpeg mpv` |
| 3 | Download Whisper model | whisperX auto-downloads on first use, or pre-fetch: `whisperx --model large-v3-turbo --compute_type int8 test.wav` |
| 4 | Get HuggingFace token | Free account at huggingface.co → accept pyannote terms → generate access token for speaker diarization |
| 5 | Configure mpv | Write `~/.config/mpv/mpv.conf` with `screenshot-directory` pointing to `attachments/` and `screenshot-template=%F-%wH-%wM-%wS` |
| 6 | Add `okm yt <URL>` | Shell wrapper: tries youtube-transcript-api first → falls back to yt-dlp subtitles → falls back to audio download + whisperX. Writes markdown note to `inbox/` with frontmatter and `#source/youtube` tag |
| 7 | Add `okm pod <file\|url> "Title"` | Shell wrapper: if URL, downloads via yt-dlp/curl; runs whisperX with `--diarize --min_speakers 2`; formats speaker-labelled transcript as markdown note in `inbox/` with `#source/podcast` tag |
| 8 | Test all paths | `okm yt` on a captioned video, one without captions. `okm pod` on a local podcast file. Verify speaker labels and timestamps |

> [!note] Phase 1 requires network only for fetching YouTube content and the initial
> model download (~1GB for large-v3-turbo + pyannote). Local podcast audio files are
> transcribed fully offline after setup. No paid API keys or subscriptions.

#### Phase 2 — Online mode toggle

| Step | Action | Detail |
|---|---|---|
| 1 | Add `okm online` | Re-enables Obsidian Flatpak network, sets `$OKM_ONLINE=1`, prints warning |
| 2 | Add `okm offline` | Revokes Obsidian network, unsets `$OKM_ONLINE`, confirms offline |
| 3 | Gate network commands | `okm yt` and URL-based `okm pod` check `$OKM_ONLINE` and warn if offline |
| 4 | Update `verify-kms.sh` | Verify offline is the default; report current mode |

#### Phase 3 — Summarisation and distillation

| Step | Action | Detail |
|---|---|---|
| 1 | Build distillation prompt template | Markdown file with the extraction prompt: summary bullets, key quotes with speaker attribution and timestamps, `[[wikilinks]]` to related notes, suggested tags |
| 2 | Add `okm distill <note>` | Shell wrapper: pipes note through `claude -p` (uses existing Claude Code subscription) with the prompt template. Writes enriched version back to the note with a `## Summary` section prepended |
| 3 | Install Ollama (offline alternative) | `curl -fsSL https://ollama.com/install.sh \| sh` then `ollama pull llama3.1:8b` (~5GB) |
| 4 | Install `llm` CLI + Ollama plugin | `pip install llm llm-ollama` then `llm templates edit summarize-transcript` to save the prompt template |
| 5 | Add `--local` flag to `okm distill` | `okm distill <note>` uses Claude by default; `okm distill --local <note>` uses Ollama for private transcripts |
| 6 | Test both paths | Run `okm distill` and `okm distill --local` on the same transcript; compare output quality |

> [!note] Claude Code (`claude -p`) uses your existing subscription — no additional
> API cost. Ollama is fully free and runs locally for privacy-sensitive content.
> Transcription itself (Phases 1–2) requires neither.

### Alternatives Evaluated but Deferred

These tools may be worth revisiting if the minimal stack proves insufficient:

| Tool | When to reconsider | Cost |
|---|---|---|
| **Fabric** (`danielmiessler/fabric`) | If you want pre-built LLM prompt patterns beyond what Claude/Ollama distillation provides. The `yt` helper is redundant with yt-dlp. | Free (but needs LLM API key or Ollama) |
| **Snipd** (iOS/Android) | If you want timestamp-based audio highlights while listening on mobile. The Obsidian BRAT plugin needs verification. | Freemium (limited free tier) |
| **Readwise Reader** | If you want unified highlight management across Kindle, web, podcasts. | ~$8–12/month — **paid** |
| **obsidian-ytranscript** | If you want YouTube transcripts fetched inside Obsidian rather than CLI. | Free |
| **obsidian-whisper** | If you want audio transcription inside Obsidian. Uses OpenAI Whisper API. | Free plugin, **paid API** |
| **distil-large-v3** | English-only distilled Whisper model, ~5-6x faster than large-v3. | Free |
| **Qwen 2.5 14B** (Ollama) | If Llama 3.1 8B summarisation quality is insufficient. Needs 16GB+ RAM. | Free |

### Design Decisions Remaining

| Decision | Options | Recommendation |
|---|---|---|
| Transcript storage | (a) Full transcript in note body, (b) transcript as separate file linked from summary, (c) summary-only | Full transcript in note body with `## Summary` prepended after distillation. Transcripts are the primary source of truth. |
| Speaker label format | (a) `**Host:**` / `**Guest:**` prefixes, (b) `> [Speaker 1]` blockquotes, (c) raw whisperX `SPEAKER_00` labels | Replace `SPEAKER_00`/`SPEAKER_01` with human names via a post-processing step or manual edit after first transcription |
| Long transcript git impact | Full podcast transcripts (10-30K words) will bloat git history | Accept for now; consider `git-lfs` or moving transcripts to a `transcripts/` dir excluded from git-crypt if encryption overhead is high |

---

## Open Items

| Item | Priority | Notes |
|---|---|---|
| Initialise git-crypt | High | Symmetric key mode; encrypt `daily/*.md` and `inbox/*.md`; must run before first remote push — see [git-crypt](#git-crypt) |
| Install yt-dlp + whisperX + ffmpeg + mpv | High | Phase 1 of transcription pipeline; all free, see [Implementation Plan](#implementation-plan) |
| Get HuggingFace token for pyannote | High | Free account; required for whisperX speaker diarization |
| Add `okm yt` and `okm pod` subcommands | High | Shell wrappers for YouTube and podcast transcription with speaker labels |
| Add `okm online` / `okm offline` toggle | Medium | Phase 2; session-scoped network mode switch for Obsidian Flatpak |
| Configure mpv screenshot directory | Medium | Point `screenshot-directory` to vault `attachments/`; set `screenshot-template` for auto-naming |
| SSH key generation | Medium | Not yet guided by `setup-kms.sh`; see [SSH and Git Remote](#ssh-and-git-remote) for manual steps |
| Add `okm distill` subcommand | Low | Phase 3; pipes notes through Claude Code or Ollama for summarisation |
| Install Ollama + `llm` CLI | Low | Phase 3; free offline summarisation alternative to Claude Code |
| `.obsidian/` plugin config audit | Low | One-time manual review before first remote push; community plugins may store tokens in `.obsidian/plugins/` |

---

## See Also

- [[ai-instructions]] — rules for AI assistants operating in this vault
- [[_skills/README]] — privacy skills library used by AI tools
- `setup-kms.sh` — canonical source of truth for all installed versions, paths, and defaults
- `verify-kms.sh` — post-install verification; run after setup to confirm all tools are present
