---
title: Weekly Review 2026-W15
created: 2026-04-10 14:45
date: 2026-04-10
week: 2026-W15
tags: [weekly-review, para, automated]
---

# Weekly Review — 2026-W15

> PARA-structured task summary generated 2026-04-10 14:45.
> Scanned for `TODO:`, `FIXME:`, `HACK:`, `XXX:`, `REVIEW:` markers and unchecked `- [ ]` tasks.

---

## Projects

Active work with a clear end goal. Fix these, ship these, close these out.

- [ ] `scripts/README.md:11` — | `TODO:` `FIXME:` `HACK:` `XXX:` | **Projects** | Active work with a clear end goal |

---

## Areas

Ongoing responsibilities and maintenance. These don't have a finish line — keep them healthy.

- [ ] `README.md:111` — - [ ] **git** — version control (`apt`)
- [ ] `README.md:112` — - [ ] **vim** — fallback editor (`apt`)
- [ ] `README.md:113` — - [ ] **ripgrep** — fast full-text search (`apt`)
- [ ] `README.md:114` — - [ ] **fzf** — fuzzy file picker (`apt`)
- [ ] `README.md:115` — - [ ] **curl** — required for binary downloads (`apt`)
- [ ] `README.md:116` — - [ ] **xclip** — clipboard bridge for X11 (`apt`)
- [ ] `README.md:117` — - [ ] **wl-clipboard** — clipboard bridge for Wayland (`apt`)
- [ ] `README.md:118` — - [ ] **flatpak** — Obsidian container runtime (`apt`)
- [ ] `README.md:119` — - [ ] **Obsidian** — GUI vault viewer (`flatpak install flathub md.obsidian.Obsidian`)
- [ ] `README.md:120` — - [ ] **Neovim** — primary terminal editor (`~/bin/nvim` via GitHub release tarball)
- [ ] `README.md:121` — - [ ] **lazygit** — TUI git client (`~/bin/lazygit` via GitHub release tarball)
- [ ] `README.md:122` — - [ ] **okm** — vault CLI (`~/bin/okm` written by setup)
- [ ] `README.md:123` — - [ ] **Vault directories** — `daily/`, `inbox/`, `attachments/`
- [ ] `README.md:124` — - [ ] **`.gitignore`** — excludes attachments, OS noise, swap files
- [ ] `README.md:125` — - [ ] **git repo** — vault initialised as a git repository
- [ ] `README.md:126` — - [ ] **Neovim config** — if no prior config: `~/.config/nvim` symlinked to `config/nvim/` in vault; if existing config: `obsidian.lua` installed into it and update checker disabled
- [ ] `README.md:127` — - [ ] **Shell exports** — `EDITOR`, `OBSIDIAN_VAULT`, `OBSIDIAN_DAILY_DIR`, `OBSIDIAN_NOTES_DIR`, `PATH`, `obs` alias in `~/.zshrc`
- [ ] `README.md:131` — - [ ] **Obsidian network revoked** — `flatpak override --user --unshare=network md.obsidian.Obsidian` (hard container boundary)
- [ ] `README.md:132` — - [ ] **lazygit config symlinked** — `~/.config/lazygit` → `config/lazygit/` in vault
- [ ] `README.md:133` — - [ ] **lazygit update checks disabled** — `update.method: never` in `config/lazygit/config.yml`
- [ ] `README.md:134` — - [ ] **lazy.nvim checker disabled** — `enabled = false` in `lua/config/lazy.lua` (existing config) or `config/nvim/init.lua` (fresh symlink)
- [ ] `README.md:135` — - [ ] **Neovim plugins bootstrapped** — downloaded once during setup; offline thereafter
- [ ] `README.md:141` — - [ ] **lazy.nvim** — plugin manager (bootstraps from `config/nvim/init.lua`)
- [ ] `README.md:142` — - [ ] **obsidian.nvim** — vault integration plugin (installed by lazy.nvim)
- [ ] `README.md:143` — - [ ] **plenary.nvim** — obsidian.nvim dependency (installed by lazy.nvim)
- [ ] `README.md:149` — - [ ] **SSH key** — `ssh-keygen -t ed25519 -C kms-vault` then add public key to git host
- [ ] `README.md:150` — - [ ] **Git remote** — `git -C "$(okm path)" remote add origin <url>`
- [ ] `README.md:151` — - [ ] **git-crypt** — initialise before first remote push of note content (see [git-crypt](#git-crypt))
- [ ] `README.md:565` — - [ ] `git-crypt export-key ~/git-crypt-kms.key` run after `git-crypt init`
- [ ] `README.md:566` — - [ ] Key stored in password manager (Bitwarden, 1Password, pass)
- [ ] `README.md:567` — - [ ] Key stored on an encrypted USB drive or printed as a QR code and stored offline
- [ ] `README.md:568` — - [ ] Key NOT stored inside the vault directory
- [ ] `README.md:569` — - [ ] Key NOT committed to the repository

---

## Resources

Items to review, evaluate, or learn from. Move to Projects once you decide to act.

- [ ] `scripts/README.md:13` — | `REVIEW:` | **Resources** | Items to evaluate or learn from |

---

## Archive

Move completed items here during your review. Nothing lands here automatically.

- _(drag completed items from above)_
