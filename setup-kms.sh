#!/usr/bin/env bash
# Setting up all tools for my knowledge management system

set -euo pipefail

# --- Logging setup (must be first) ---
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/setup-kms-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

_log() {
    local level="$1"
    shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '[%s] [%-5s] %s\n' "${ts}" "${level}" "${msg}" | tee -a "${LOG_FILE}"
}
log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }

_on_error() {
    local exit_code=$?
    local line_no="${1}"
    local last_cmd="${BASH_COMMAND}"
    log_error "Command '${last_cmd}' failed at line ${line_no} (exit ${exit_code})"
    log_error "Setup did NOT complete. See full log: ${LOG_FILE}"
    exit "${exit_code}"
}
trap '_on_error ${LINENO}' ERR

# --- Variables ---
VAULT_DIR="/home/aws/workspace/knowledge-management-system"
BIN_DIR="${HOME}/bin"
OKM_PATH="${BIN_DIR}/okm"
SHELL_RC="${HOME}/.zshrc"
GIT_REMOTE="${1:-}"

# --- Helper functions ---

install_apt_packages() {
    local packages=("$@")
    local to_install=()

    for pkg in "${packages[@]}"; do
        if dpkg -s "${pkg}" >/dev/null 2>&1 \
           && dpkg -s "${pkg}" 2>/dev/null | grep -q 'Status: install ok installed'; then
            log_info "SKIP: apt package '${pkg}' already installed"
        else
            log_info "QUEUE: apt package '${pkg}' will be installed"
            to_install+=("${pkg}")
        fi
    done

    if [ "${#to_install[@]}" -eq 0 ]; then
        log_info "SKIP: all apt packages already present — skipping apt update"
        return 0
    fi

    log_info "Running: apt update"
    sudo apt update -q

    log_info "Installing: ${to_install[*]}"
    sudo apt install -y "${to_install[@]}"
}

ensure_flathub_remote() {
    if flatpak remotes --columns=name 2>/dev/null | grep -qx 'flathub'; then
        log_info "SKIP: Flathub remote already configured"
    else
        log_info "ACTION: Adding Flathub remote"
        flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

install_obsidian() {
    if flatpak list --app --columns=application 2>/dev/null | grep -qx 'md.obsidian.Obsidian'; then
        log_info "SKIP: Obsidian flatpak already installed"
    else
        log_info "ACTION: Installing Obsidian flatpak"
        flatpak install -y flathub md.obsidian.Obsidian
    fi
}

ensure_dir() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        log_info "SKIP: directory already exists: ${dir}"
    else
        log_info "ACTION: Creating directory: ${dir}"
        mkdir -p "${dir}"
    fi
}

install_okm_binary() {
    local target_path="$1"
    local new_content="$2"
    local new_hash existing_hash

    new_hash="$(printf '%s' "${new_content}" | sha256sum | cut -d' ' -f1)"

    if [ -x "${target_path}" ]; then
        existing_hash="$(sha256sum "${target_path}" | cut -d' ' -f1)"
        if [ "${new_hash}" = "${existing_hash}" ]; then
            log_info "SKIP: okm binary at ${target_path} is unchanged (sha256 match)"
            return 0
        else
            log_warn "okm binary exists but content differs — overwriting (old=${existing_hash:0:12} new=${new_hash:0:12})"
        fi
    else
        log_info "ACTION: Writing okm binary to ${target_path}"
    fi

    printf '%s' "${new_content}" > "${target_path}"
    chmod +x "${target_path}"
    log_info "OK: okm binary written and made executable"
}

ensure_shell_line() {
    local rc_file="$1"
    local line="$2"
    if grep -qxF "${line}" "${rc_file}" 2>/dev/null; then
        log_info "SKIP: already in ${rc_file}: ${line}"
    else
        log_info "ACTION: Appending to ${rc_file}: ${line}"
        printf '%s\n' "${line}" >> "${rc_file}"
    fi
}

# Replace old_line with new_line in rc_file (exact-line match); appends if old not found.
replace_shell_line() {
    local rc_file="$1"
    local old_line="$2"
    local new_line="$3"

    if grep -qxF "${new_line}" "${rc_file}" 2>/dev/null; then
        log_info "SKIP: already in ${rc_file}: ${new_line}"
        return 0
    fi
    if grep -qxF "${old_line}" "${rc_file}" 2>/dev/null; then
        log_info "ACTION: Replacing in ${rc_file}: '${old_line}' -> '${new_line}'"
        local tmp
        tmp="$(mktemp)"
        while IFS= read -r _line || [ -n "${_line}" ]; do
            if [ "${_line}" = "${old_line}" ]; then
                printf '%s\n' "${new_line}"
            else
                printf '%s\n' "${_line}"
            fi
        done < "${rc_file}" > "${tmp}"
        mv "${tmp}" "${rc_file}"
    else
        log_info "ACTION: Appending to ${rc_file}: ${new_line}"
        printf '%s\n' "${new_line}" >> "${rc_file}"
    fi
}

ensure_gitignore() {
    local dir="$1"
    local gitignore="${dir}/.gitignore"
    if [ -f "${gitignore}" ]; then
        log_info "SKIP: .gitignore already exists at ${gitignore}"
    else
        log_info "ACTION: Writing .gitignore at ${gitignore}"
        cat > "${gitignore}" <<'GITIGNORE'
# Obsidian workspace state (changes constantly, not worth tracking)
.obsidian/workspace.json
.obsidian/workspace-mobile.json

# Large or binary attachments (track explicitly if needed)
attachments/*.pdf
attachments/*.zip
attachments/*.tar.gz
attachments/*.mp4
attachments/*.mov
attachments/*.png
attachments/*.jpg
attachments/*.jpeg
attachments/*.gif
attachments/*.webp

# OS noise
.DS_Store
Thumbs.db

# Editor swap/backup files
*.swp
*.swo
*~
GITIGNORE
        log_info "OK: .gitignore written"
    fi
}

ensure_git_repo() {
    local dir="$1"
    if [ -d "${dir}/.git" ]; then
        log_info "SKIP: git repo already initialised at ${dir}"
    else
        log_info "ACTION: Initialising git repo at ${dir}"
        git -C "${dir}" init -b main
        git -C "${dir}" add .
        git -C "${dir}" commit -m "initial vault"
        log_info "OK: git repo initialised with initial commit"
    fi
}

ensure_git_remote() {
    local dir="$1"
    local remote_url="$2"

    [ -n "${remote_url}" ] || { log_info "No GIT_REMOTE specified — skipping remote configuration"; return 0; }

    if git -C "${dir}" remote get-url origin >/dev/null 2>&1; then
        local current_url
        current_url="$(git -C "${dir}" remote get-url origin)"
        if [ "${current_url}" = "${remote_url}" ]; then
            log_info "SKIP: git remote 'origin' already points to ${remote_url}"
        else
            log_warn "git remote 'origin' exists with different URL (${current_url}) — updating to ${remote_url}"
            git -C "${dir}" remote set-url origin "${remote_url}"
        fi
    else
        log_info "ACTION: Adding git remote origin -> ${remote_url}"
        git -C "${dir}" remote add origin "${remote_url}"
    fi

    log_info "Pushing to origin/main"
    git -C "${dir}" push -u origin main || log_warn "git push failed — continuing (remote may not be accessible yet)"
}

install_nvim() {
    if [ -x "${BIN_DIR}/nvim" ]; then
        log_info "SKIP: neovim already installed at ${BIN_DIR}/nvim"
        return 0
    fi
    log_info "ACTION: Installing Neovim (latest stable)"
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    curl -fsSL -o "${tmp_dir}/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz"
    tar -xf "${tmp_dir}/nvim.tar.gz" -C "${tmp_dir}"
    cp "${tmp_dir}/nvim-linux-x86_64/bin/nvim" "${BIN_DIR}/nvim"
    chmod +x "${BIN_DIR}/nvim"
    rm -rf "${tmp_dir}"
    log_info "OK: neovim installed at ${BIN_DIR}/nvim"
}

install_lazygit() {
    if [ -x "${BIN_DIR}/lazygit" ]; then
        log_info "SKIP: lazygit already installed at ${BIN_DIR}/lazygit"
        return 0
    fi
    log_info "ACTION: Installing lazygit (latest release)"
    local tmp_dir version
    tmp_dir="$(mktemp -d)"
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')"
    curl -fsSL -o "${tmp_dir}/lazygit.tar.gz" \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_Linux_x86_64.tar.gz"
    tar -xf "${tmp_dir}/lazygit.tar.gz" -C "${BIN_DIR}" lazygit
    chmod +x "${BIN_DIR}/lazygit"
    rm -rf "${tmp_dir}"
    log_info "OK: lazygit installed at ${BIN_DIR}/lazygit"
}

ensure_nvim_config_link() {
    local vault_nvim="${VAULT_DIR}/config/nvim"
    local target="${HOME}/.config/nvim"
    local obs_src="${vault_nvim}/lua/plugins/obsidian.lua"

    mkdir -p "${HOME}/.config"

    if [ -L "${target}" ]; then
        local current_target
        current_target="$(readlink "${target}")"
        if [ "${current_target}" = "${vault_nvim}" ]; then
            log_info "SKIP: ~/.config/nvim already linked to ${vault_nvim}"
            return 0
        fi
        log_warn "~/.config/nvim symlinks to ${current_target} — skipping (unexpected symlink target)"
        return 0
    elif [ -d "${target}" ]; then
        # Pre-existing config — install obsidian.lua and disable the update checker; leave everything else alone.
        local plugin_dir="${target}/lua/plugins"
        local dest="${plugin_dir}/obsidian.lua"
        mkdir -p "${plugin_dir}"
        if [ -f "${dest}" ]; then
            local src_hash dest_hash
            src_hash="$(sha256sum "${obs_src}" | cut -d' ' -f1)"
            dest_hash="$(sha256sum "${dest}" | cut -d' ' -f1)"
            if [ "${src_hash}" = "${dest_hash}" ]; then
                log_info "SKIP: obsidian.lua already installed in existing nvim config"
            else
                log_warn "obsidian.lua in nvim config differs from vault — overwriting"
                cp "${obs_src}" "${dest}"
                log_info "OK: obsidian.lua updated at ${dest}"
            fi
        else
            cp "${obs_src}" "${dest}"
            log_info "OK: obsidian.lua installed into existing nvim config at ${dest}"
        fi
        # Disable background update checker (offline-first policy)
        local lazy_lua="${target}/lua/config/lazy.lua"
        if [ -f "${lazy_lua}" ] && grep -q 'enabled = true' "${lazy_lua}"; then
            sed -i 's/enabled = true, -- check for plugin updates periodically/enabled = false, -- disabled: offline-first; update manually with :Lazy sync/' "${lazy_lua}"
            log_info "OK: disabled lazy.nvim update checker in existing config"
        fi
        return 0
    fi

    # No existing config — create the symlink (new machine path)
    ln -s "${vault_nvim}" "${target}"
    log_info "OK: ~/.config/nvim -> ${vault_nvim}"
}

ensure_lazygit_config_link() {
    local vault_lg="${VAULT_DIR}/config/lazygit"
    local target="${HOME}/.config/lazygit"

    mkdir -p "${HOME}/.config"
    mkdir -p "${vault_lg}"   # idempotent; dir is already committed to repo

    if [ -L "${target}" ]; then
        local current_target
        current_target="$(readlink "${target}")"
        if [ "${current_target}" = "${vault_lg}" ]; then
            log_info "SKIP: ~/.config/lazygit already linked to ${vault_lg}"
            return 0
        fi
        log_warn "~/.config/lazygit symlinks to ${current_target} — updating to ${vault_lg}"
        rm "${target}"
    elif [ -e "${target}" ]; then
        log_warn "~/.config/lazygit exists as a real directory — skipping symlink (manual merge required)"
        return 0
    fi

    ln -s "${vault_lg}" "${target}"
    log_info "OK: ~/.config/lazygit -> ${vault_lg}"
}

# Bootstrap all Neovim plugins while the network is still available.
# After this runs, nvim operates fully offline — no plugin auto-updates.
bootstrap_nvim_plugins() {
    if [ ! -x "${BIN_DIR}/nvim" ]; then
        log_warn "nvim not found — skipping plugin bootstrap"
        return 0
    fi

    local lazy_path="${HOME}/.local/share/nvim/lazy/lazy.nvim"
    local obsidian_path="${HOME}/.local/share/nvim/lazy/obsidian.nvim"

    if [ -d "${lazy_path}" ] && [ -d "${obsidian_path}" ]; then
        log_info "SKIP: Neovim plugins already bootstrapped"
        return 0
    fi

    log_info "ACTION: Bootstrapping Neovim plugins (one-time; requires network)"
    if timeout 180 "${BIN_DIR}/nvim" --headless "+Lazy! sync" +qa 2>/dev/null; then
        log_info "OK: Neovim plugins bootstrapped"
    else
        log_warn "Plugin bootstrap exited non-zero — run 'nvim' once to finish install"
    fi
}

# Revoke Obsidian's network permission via the flatpak sandbox.
# After this, Obsidian cannot initiate outbound connections regardless of its
# internal settings. Explicit git push/pull (via okm sync or lazygit) is unaffected.
ensure_obsidian_offline() {
    local override_file="${HOME}/.local/share/flatpak/overrides/md.obsidian.Obsidian"

    if [ -f "${override_file}" ] && grep -q '!network' "${override_file}"; then
        log_info "SKIP: Obsidian flatpak network permission already revoked"
        return 0
    fi

    log_info "ACTION: Revoking Obsidian network permission via flatpak override"
    flatpak override --user --unshare=network md.obsidian.Obsidian
    log_info "OK: Obsidian network access revoked (flatpak sandbox enforced)"
}

# --- Install steps ---

log_info "==> Installing packages"
install_apt_packages vim git ripgrep fzf xdg-utils flatpak xclip wl-clipboard curl

log_info "==> Ensuring Flathub is configured"
ensure_flathub_remote

log_info "==> Installing Obsidian"
install_obsidian

log_info "==> Creating vault structure"
ensure_dir "${VAULT_DIR}/daily"
ensure_dir "${VAULT_DIR}/inbox"
ensure_dir "${VAULT_DIR}/attachments"
ensure_dir "${VAULT_DIR}/config/lazygit"
ensure_dir "${BIN_DIR}"

log_info "==> Writing okm CLI"
OKM_SOURCE=$(cat <<'OKMSRC'
#!/usr/bin/env bash
set -euo pipefail

VAULT="${OBSIDIAN_VAULT:-/home/aws/workspace/knowledge-management-system}"
EDITOR_CMD="${EDITOR:-vim}"
DAILY_DIR="${OBSIDIAN_DAILY_DIR:-daily}"
NOTES_DIR="${OBSIDIAN_NOTES_DIR:-inbox}"

usage() {
  cat <<'EOF2'
okm - simple terminal knowledge manager

Usage:
  okm open [path]
  okm new <title>
  okm capture [text]
  okm today
  okm grep <pattern>
  okm files [pattern]
  okm recent
  okm sync [message]
  okm obs
  okm path
EOF2
}

need_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "Missing: $1" >&2; exit 1; }; }
slugify() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'; }
iso_now() { date -Iseconds; }
timestamp() { date +"%Y%m%d-%H%M%S"; }

ensure_dirs() {
  mkdir -p "$VAULT/$DAILY_DIR" "$VAULT/$NOTES_DIR"
}

pick_file() {
  need_cmd fzf
  find "$VAULT" -type f -name '*.md' | sed "s#^$VAULT/##" | sort | fzf --height=40% --reverse --border --prompt="notes> "
}

open_note() {
  ensure_dirs
  local target="${1:-}"
  if [ -z "$target" ]; then
    local picked
    picked="$(pick_file || true)"
    [ -n "${picked:-}" ] || exit 0
    exec "$EDITOR_CMD" "$VAULT/$picked"
  fi
  if [ -e "$target" ]; then
    exec "$EDITOR_CMD" "$target"
  else
    exec "$EDITOR_CMD" "$VAULT/$target"
  fi
}

new_note() {
  ensure_dirs
  local title="$*"
  [ -n "$title" ] || { echo "Title required" >&2; exit 1; }
  local slug file
  slug="$(slugify "$title")"
  file="$VAULT/$NOTES_DIR/$slug.md"
  [ -f "$file" ] || cat > "$file" <<EOF2
---
title: $title
created: $(iso_now)
tags: []
---

# $title

EOF2
  exec "$EDITOR_CMD" "$file"
}

capture_note() {
  ensure_dirs
  local file ts
  ts="$(timestamp)"
  file="$VAULT/$NOTES_DIR/$ts.md"
  cat > "$file" <<EOF2
---
title: Quick Capture $ts
created: $(iso_now)
tags: [capture, inbox]
---

# Quick Capture $ts

${*:-}
EOF2
  exec "$EDITOR_CMD" "$file"
}

today_note() {
  ensure_dirs
  local d file
  d="$(date +%F)"
  file="$VAULT/$DAILY_DIR/$d.md"
  [ -f "$file" ] || cat > "$file" <<EOF2
---
date: $d
created: $(iso_now)
tags: [daily]
---

# $d

## Tasks

- [ ]

## Notes

EOF2
  exec "$EDITOR_CMD" "$file"
}

grep_vault() {
  need_cmd rg
  local pattern="${1:-}"
  [ -n "$pattern" ] || { echo "Pattern required" >&2; exit 1; }
  rg -n --hidden --glob '*.md' "$pattern" "$VAULT"
}

files_vault() {
  local pattern="${1:-}"
  if [ -z "$pattern" ]; then
    find "$VAULT" -type f -name '*.md' | sed "s#^$VAULT/##" | sort
  else
    find "$VAULT" -type f -name '*.md' | sed "s#^$VAULT/##" | grep -i -- "$pattern" | sort || true
  fi
}

recent_notes() {
  need_cmd fzf
  local picked
  picked="$(
    find "$VAULT" -type f -name '*.md' -printf '%T@ %p\n' \
      | sort -nr \
      | head -200 \
      | cut -d' ' -f2- \
      | sed "s#^$VAULT/##" \
      | fzf --height=40% --reverse --border --prompt="recent> "
  )"
  [ -n "${picked:-}" ] || exit 0
  exec "$EDITOR_CMD" "$VAULT/$picked"
}

sync_git() {
  git -C "$VAULT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
    echo "Vault is not a git repo" >&2
    exit 1
  }
  local msg="${*:-vault sync $(date '+%F %T')}"
  git -C "$VAULT" add -A
  if git -C "$VAULT" diff --cached --quiet; then
    echo "No changes to commit"
  else
    git -C "$VAULT" commit -m "$msg"
  fi
  local upstream
  upstream="$(git -C "$VAULT" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
  if [ -n "$upstream" ]; then
    git -C "$VAULT" pull --rebase --autostash
    git -C "$VAULT" push
  else
    echo "No upstream configured; skipped pull/push"
  fi
}

open_obsidian() {
  flatpak run md.obsidian.Obsidian >/dev/null 2>&1 &
}

case "${1:-help}" in
  open) shift; open_note "${1:-}" ;;
  new) shift; new_note "$*" ;;
  capture) shift; capture_note "$*" ;;
  today) shift; today_note ;;
  grep) shift; grep_vault "${1:-}" ;;
  files) shift; files_vault "${1:-}" ;;
  recent) shift; recent_notes ;;
  sync) shift; sync_git "$*" ;;
  obs) shift; open_obsidian ;;
  path) printf '%s\n' "$VAULT" ;;
  help|-h|--help) usage ;;
  *) usage; exit 1 ;;
esac
OKMSRC
)

install_okm_binary "${OKM_PATH}" "${OKM_SOURCE}"

log_info "==> Writing shell config"
ensure_shell_line  "${SHELL_RC}" 'export PATH="$HOME/bin:$PATH"'
replace_shell_line "${SHELL_RC}" 'export EDITOR=vim' 'export EDITOR=nvim'
ensure_shell_line  "${SHELL_RC}" 'export OBSIDIAN_VAULT="/home/aws/workspace/knowledge-management-system"'
ensure_shell_line  "${SHELL_RC}" 'export OBSIDIAN_DAILY_DIR=daily'
ensure_shell_line  "${SHELL_RC}" 'export OBSIDIAN_NOTES_DIR=inbox'
ensure_shell_line  "${SHELL_RC}" 'alias obs="flatpak run md.obsidian.Obsidian"'

log_info "==> Writing obs binary"
OBS_SOURCE='#!/usr/bin/env bash
if [ $# -gt 0 ]; then
    path="$(realpath "${1}")"
    flatpak run md.obsidian.Obsidian "obsidian://open?path=${path}" >/dev/null 2>&1 &
else
    flatpak run md.obsidian.Obsidian >/dev/null 2>&1 &
fi
'
if [ -x "${BIN_DIR}/obs" ]; then
    existing_hash="$(sha256sum "${BIN_DIR}/obs" | cut -d' ' -f1)"
    new_hash="$(printf '%s' "${OBS_SOURCE}" | sha256sum | cut -d' ' -f1)"
    if [ "${new_hash}" = "${existing_hash}" ]; then
        log_info "SKIP: obs binary at ${BIN_DIR}/obs is unchanged"
    else
        log_warn "obs binary exists but content differs — overwriting"
        printf '%s' "${OBS_SOURCE}" > "${BIN_DIR}/obs"
        chmod +x "${BIN_DIR}/obs"
        log_info "OK: obs binary updated"
    fi
else
    log_info "ACTION: Writing obs binary to ${BIN_DIR}/obs"
    printf '%s' "${OBS_SOURCE}" > "${BIN_DIR}/obs"
    chmod +x "${BIN_DIR}/obs"
    log_info "OK: obs binary written and made executable"
fi

log_info "==> Writing .gitignore"
ensure_gitignore "${VAULT_DIR}"

log_info "==> Bootstrapping Git repo"
ensure_git_repo "${VAULT_DIR}"

log_info "==> Configuring Git remote"
ensure_git_remote "${VAULT_DIR}" "${GIT_REMOTE}"

log_info "==> Installing Neovim"
install_nvim

log_info "==> Installing lazygit"
install_lazygit

log_info "==> Linking Neovim config"
ensure_nvim_config_link

log_info "==> Linking lazygit config"
ensure_lazygit_config_link

log_info "==> Bootstrapping Neovim plugins"
bootstrap_nvim_plugins

log_info "==> Enforcing offline mode"
ensure_obsidian_offline

log_info "==> Setup complete"
log_info "Full log written to: ${LOG_FILE}"
echo ""
echo "Setup complete. Log: ${LOG_FILE}"
echo "Reload shell: source ${SHELL_RC}"
echo "Examples:"
echo "  okm today"
echo "  okm new \"Linux notes\""
echo "  okm capture \"read about systemd\""
echo "  okm grep postgres"
echo "  okm recent"
echo "  okm sync \"notes update\""
echo "  obs"
