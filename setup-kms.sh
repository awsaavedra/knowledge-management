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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="/home/aws/workspace/knowledge-management-system"
BIN_DIR="${SCRIPT_DIR}/bin"
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
    # Use NVIM_APPNAME=kms so the project nvim config lives at ~/.config/kms/
    # and does NOT touch the user's global ~/.config/nvim config.
    local project_nvim="${SCRIPT_DIR}/config/nvim"
    local target="${HOME}/.config/kms"

    mkdir -p "${HOME}/.config"

    if [ -L "${target}" ]; then
        local current_target
        current_target="$(readlink "${target}")"
        if [ "${current_target}" = "${project_nvim}" ]; then
            log_info "SKIP: ~/.config/kms already linked to ${project_nvim}"
            return 0
        fi
        log_warn "~/.config/kms symlinks to ${current_target} — updating to ${project_nvim}"
        rm "${target}"
    elif [ -d "${target}" ]; then
        log_warn "~/.config/kms exists as a real directory — skipping symlink (manual merge required)"
        return 0
    fi

    ln -s "${project_nvim}" "${target}"
    log_info "OK: ~/.config/kms -> ${project_nvim} (NVIM_APPNAME=kms isolates from global nvim config)"
}

verify_lazygit_config() {
    # lazygit config is pointed to by LG_CONFIG_FILE in env.sh.
    # No symlink to ~/.config/lazygit needed.
    local lg_config="${SCRIPT_DIR}/config/lazygit/config.yml"
    if [ -f "${lg_config}" ]; then
        log_info "OK: lazygit config exists at ${lg_config} (loaded via LG_CONFIG_FILE in env.sh)"
    else
        log_warn "lazygit config not found at ${lg_config}"
    fi
}

# Bootstrap all Neovim plugins while the network is still available.
# After this runs, nvim operates fully offline — no plugin auto-updates.
bootstrap_nvim_plugins() {
    if [ ! -x "${BIN_DIR}/nvim" ]; then
        log_warn "nvim not found — skipping plugin bootstrap"
        return 0
    fi

    # NVIM_APPNAME=kms stores plugin data under ~/.local/share/kms/ (isolated from global nvim)
    local lazy_path="${HOME}/.local/share/kms/lazy/lazy.nvim"
    local obsidian_path="${HOME}/.local/share/kms/lazy/obsidian.nvim"

    if [ -d "${lazy_path}" ] && [ -d "${obsidian_path}" ]; then
        log_info "SKIP: Neovim plugins already bootstrapped (NVIM_APPNAME=kms)"
        return 0
    fi

    log_info "ACTION: Bootstrapping Neovim plugins (one-time; requires network; NVIM_APPNAME=kms)"
    if timeout 180 env NVIM_APPNAME=kms "${BIN_DIR}/nvim" --headless "+Lazy! sync" +qa 2>/dev/null; then
        log_info "OK: Neovim plugins bootstrapped under ~/.local/share/kms/"
    else
        log_warn "Plugin bootstrap exited non-zero — run 'source env.sh && nvim' once to finish install"
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
ensure_dir "${BIN_DIR}"

log_info "==> Verifying okm CLI"
# bin/okm is tracked in git — just ensure it exists and is executable.
if [ ! -f "${BIN_DIR}/okm" ]; then
    log_error "bin/okm not found at ${BIN_DIR}/okm — project repo may be incomplete"
    exit 1
fi
chmod +x "${BIN_DIR}/okm"
log_info "OK: bin/okm is present and executable"

log_info "==> Verifying project env.sh"
if [ -f "${SCRIPT_DIR}/env.sh" ]; then
    log_info "OK: env.sh exists at ${SCRIPT_DIR}/env.sh — source it to activate the project environment"
else
    log_error "env.sh not found at ${SCRIPT_DIR}/env.sh — project environment cannot be activated"
fi

log_info "==> Verifying obs binary"
# bin/obs is tracked in git — just ensure it exists and is executable.
if [ ! -f "${BIN_DIR}/obs" ]; then
    log_error "bin/obs not found at ${BIN_DIR}/obs — project repo may be incomplete"
    exit 1
fi
chmod +x "${BIN_DIR}/obs"
log_info "OK: bin/obs is present and executable"

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

log_info "==> Verifying lazygit config"
verify_lazygit_config

log_info "==> Bootstrapping Neovim plugins"
bootstrap_nvim_plugins

log_info "==> Enforcing offline mode"
ensure_obsidian_offline

log_info "==> Setup complete"
log_info "Full log written to: ${LOG_FILE}"
echo ""
echo "Setup complete. Log: ${LOG_FILE}"
echo ""
echo "Activate the project environment:"
echo "  source env.sh"
echo ""
echo "Then use okm:"
echo "  okm today"
echo "  okm new \"Linux notes\""
echo "  okm capture \"read about systemd\""
echo "  okm sync \"notes update\""
echo ""
echo "No global config files were modified."
echo "Your ~/.zshrc, ~/.config/nvim, and ~/.config/lazygit are untouched."
