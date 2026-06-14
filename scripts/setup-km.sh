#!/usr/bin/env bash
# Install and configure all tools for the knowledge management vault.
# shellcheck disable=SC2088  # tildes appear only in user-facing messages, never expanded as paths

set -euo pipefail

# --- Logging setup (must be first) ---
LOG_DIR="${HOME}/.local/log"
LOG_FILE="${LOG_DIR}/setup-km-$(date +%Y%m%d-%H%M%S).log"
mkdir -p "${LOG_DIR}"

# Rotate: keep only the last 5 log files.
_rotate_logs() {
    local logs
    mapfile -t logs < <(find "${LOG_DIR}" -maxdepth 1 -name 'setup-km-*.log' \
        -not -name "$(basename "${LOG_FILE}")" | sort -r)
    local i=0
    for f in "${logs[@]}"; do
        i=$((i + 1))
        [ "$i" -ge 5 ] && rm -f "$f"
    done
}
_rotate_logs

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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN_DIR="${SCRIPT_DIR}/bin"

# Argument parsing (before sourcing so --dry-run works when sourced).
DRY_RUN=false
_setup_args=()
for _arg in "$@"; do
    case "$_arg" in
        --dry-run) DRY_RUN=true ;;
        *)         _setup_args+=("$_arg") ;;
    esac
done
GIT_REMOTE="${_setup_args[0]:-}"
unset _arg _setup_args

# --- Shared libraries ---
# shellcheck source=scripts/lib/platform.sh
source "${SCRIPT_DIR}/scripts/lib/platform.sh"
# shellcheck source=scripts/lib/vault.sh
source "${SCRIPT_DIR}/scripts/lib/vault.sh"
# shellcheck source=scripts/lib/privacy.sh
source "${SCRIPT_DIR}/scripts/lib/privacy.sh"

VAULT_DIR="$(km_vault_dir "${SCRIPT_DIR}")"

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
    if flatpak remotes --user --columns=name 2>/dev/null | grep -qx 'flathub'; then
        log_info "SKIP: Flathub remote already configured (user installation)"
    else
        log_info "ACTION: Adding Flathub remote (user installation — no polkit needed on WSL2)"
        flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    fi
}

install_obsidian() {
    if flatpak list --user --app --columns=application 2>/dev/null | grep -qx 'md.obsidian.Obsidian'; then
        log_info "SKIP: Obsidian flatpak already installed (user installation)"
    else
        log_info "ACTION: Installing Obsidian flatpak (user installation)"
        flatpak install --user -y flathub md.obsidian.Obsidian
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

    log_info "ACTION: Writing .gitignore at ${gitignore} (KM_TRACK_NOTES=${KM_TRACK_NOTES:-false})"
    cat > "${gitignore}" <<'GITIGNORE'
# Obsidian workspace state (changes constantly, not worth tracking)
.obsidian/workspace.json
.obsidian/workspace-mobile.json

# Secrets — never commit these regardless of KM_TRACK_NOTES (B5)
.env
.env.*
*.pem
*.key
*.crt
*credentials*
id_rsa
id_rsa.*
id_ed25519
id_ed25519.*

# Private notes — local-only by default (N3). Opt in by removing these lines
# (e.g. when you've initialised git-crypt and want history under encryption).
private/daily/*.md
private/inbox/*.md
private/archive/*.md
private/attachments/*

# Large or binary attachments (track explicitly if needed)
public/attachments/*.pdf
public/attachments/*.zip
public/attachments/*.tar.gz
public/attachments/*.mp4
public/attachments/*.mov
public/attachments/*.png
public/attachments/*.jpg
public/attachments/*.jpeg
public/attachments/*.gif
public/attachments/*.webp

# OS noise
.DS_Store
Thumbs.db

# Editor swap/backup files
*.swp
*.swo
*~

# Per-user editor choice (written by setup-km.sh)
.km-editor

# Downloaded binaries (installed by setup-km.sh, not source-controlled)
bin/nvim
bin/nvim.bin
bin/nvim-runtime/
bin/lazygit

# Machine-specific generated configs (regenerated by setup-km.sh with local paths)
config/mpv/mpv.conf

# Python
venv/
__pycache__/
*.py[cod]
*.pyo
.pytest_cache/
*.egg-info/
dist/
build/
.eggs/
GITIGNORE

    # KM_TRACK_NOTES=true: notes are tracked in git (user wants full history/git-crypt).
    # KM_TRACK_NOTES=false (default): notes are gitignored for privacy.
    if [ "${KM_TRACK_NOTES:-false}" != "true" ]; then
        cat >> "${gitignore}" <<'PRIVATE'

# Vault notes — set KM_TRACK_NOTES=true before setup to track these in git
public/inbox/*.md
!public/inbox/templates/
public/daily/*.md
public/archive/*.md
PRIVATE
        log_info "OK: .gitignore written (notes excluded — private mode)"
    else
        log_info "OK: .gitignore written (notes tracked — KM_TRACK_NOTES=true)"
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
    # N15: store symlinks as their target-path text rather than following
    # them. `okm sync` also refuses on symlinks pointing outside the vault;
    # this is belt-and-braces.
    git -C "${dir}" config core.symlinks false
}

# Derive the default private-fork remote from the authenticated GitHub handle.
# Convention: git@github.com:{handle}/{handle}-knowledge-management.git
# Sets GIT_REMOTE if it is currently empty and gh is available + authenticated.
derive_default_remote() {
    [ -n "${GIT_REMOTE}" ] && return 0   # already set — nothing to do

    if ! command -v gh >/dev/null 2>&1; then
        log_warn "gh CLI not found — cannot auto-derive GIT_REMOTE. Pass it as: bash setup-km.sh <remote-url>"
        return 0
    fi

    local handle
    handle="$(gh api user --jq '.login' 2>/dev/null || true)"
    if [ -z "${handle}" ]; then
        log_warn "gh not authenticated — cannot auto-derive GIT_REMOTE. Run: gh auth login"
        return 0
    fi

    GIT_REMOTE="git@github.com:${handle}/${handle}-knowledge-management.git"
    log_info "Derived default origin: ${GIT_REMOTE} (rename your fork if needed)"
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

# Set the 'upstream' remote on the vault to the canonical OSS source repo.
# Derives owner from origin URL (e.g. git@github.com:alice/alice-km → alice owns it,
# upstream = git@github.com:alice/knowledge-management). Falls back to a no-op warn.
ensure_upstream_remote() {
    local dir="$1"

    local origin_url
    origin_url="$(git -C "${dir}" remote get-url origin 2>/dev/null || true)"
    [ -n "${origin_url}" ] || { log_info "No origin set — skipping upstream remote"; return 0; }

    # Extract owner (works for both SSH and HTTPS GitHub URLs)
    local owner
    case "${origin_url}" in
        git@github.com:*)  owner="$(echo "${origin_url#git@github.com:}" | cut -d'/' -f1)" ;;
        https://github.com/*) owner="$(echo "${origin_url#https://github.com/}" | cut -d'/' -f1)" ;;
        *) log_warn "Cannot derive upstream — unrecognised remote format: ${origin_url}"; return 0 ;;
    esac

    local upstream_url="git@github.com:${owner}/knowledge-management.git"

    if git -C "${dir}" remote get-url upstream >/dev/null 2>&1; then
        log_info "SKIP: 'upstream' remote already configured"
    else
        log_info "ACTION: Adding upstream remote -> ${upstream_url}"
        git -C "${dir}" remote add upstream "${upstream_url}"
        # Fetch-only: disable push to upstream so okm sync never accidentally pushes there
        git -C "${dir}" remote set-url --push upstream DISABLED
        log_info "OK: upstream push URL disabled (fetch-only)"
    fi
}

detect_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}" in
        Linux)  PLATFORM_OS="linux" ;;
        Darwin) PLATFORM_OS="macos" ;;
        *)      log_error "Unsupported OS: ${os}"; exit 1 ;;
    esac
    case "${arch}" in
        x86_64|amd64)  PLATFORM_ARCH="x86_64" ;;
        aarch64|arm64) PLATFORM_ARCH="arm64" ;;
        *)             log_error "Unsupported architecture: ${arch}"; exit 1 ;;
    esac
    log_info "Platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"
}

install_nvim() {
    if [ -x "${BIN_DIR}/nvim" ] && [ -x "${BIN_DIR}/nvim.bin" ]; then
        log_info "SKIP: neovim already installed at ${BIN_DIR}/nvim"
        return 0
    fi
    log_info "ACTION: Installing Neovim (latest stable) with runtime"
    local tmp_dir nvim_tarball nvim_dir
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' EXIT
    case "${PLATFORM_OS}" in
        linux)  nvim_tarball="nvim-linux-${PLATFORM_ARCH}.tar.gz"; nvim_dir="nvim-linux-${PLATFORM_ARCH}" ;;
        macos)  nvim_tarball="nvim-macos-${PLATFORM_ARCH}.tar.gz"; nvim_dir="nvim-macos-${PLATFORM_ARCH}" ;;
        *)      log_error "Unsupported platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"; rm -rf "${tmp_dir}"; return 1 ;;
    esac
    curl -fsSL -o "${tmp_dir}/nvim.tar.gz" \
        "https://github.com/neovim/neovim/releases/latest/download/${nvim_tarball}"
    tar -xzf "${tmp_dir}/nvim.tar.gz" -C "${tmp_dir}"

    # Install binary
    cp "${tmp_dir}/${nvim_dir}/bin/nvim" "${BIN_DIR}/nvim.bin"
    chmod +x "${BIN_DIR}/nvim.bin"

    # Install runtime (lib + share) for self-contained operation
    rm -rf "${BIN_DIR}/nvim-runtime"
    mkdir -p "${BIN_DIR}/nvim-runtime"
    cp -r "${tmp_dir}/${nvim_dir}/lib" "${BIN_DIR}/nvim-runtime/"
    cp -r "${tmp_dir}/${nvim_dir}/share" "${BIN_DIR}/nvim-runtime/"

    # Create wrapper that sets VIMRUNTIME so nvim finds its runtime files
    cat > "${BIN_DIR}/nvim" <<'WRAPPER'
#!/usr/bin/env bash
NVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VIMRUNTIME="${NVIM_DIR}/nvim-runtime/share/nvim/runtime"
exec "${NVIM_DIR}/nvim.bin" "$@"
WRAPPER
    chmod +x "${BIN_DIR}/nvim"

    rm -rf "${tmp_dir}"
    log_info "OK: neovim installed at ${BIN_DIR}/nvim (wrapper + runtime)"
}

install_lazygit() {
    if [ -x "${BIN_DIR}/lazygit" ]; then
        log_info "SKIP: lazygit already installed at ${BIN_DIR}/lazygit"
        return 0
    fi
    log_info "ACTION: Installing lazygit (latest release)"
    local tmp_dir version
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' EXIT
    version="$(curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')"
    if [[ ! "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Could not determine lazygit version from GitHub API (got: '${version}')"
        return 1
    fi
    local lg_os lg_arch
    case "${PLATFORM_OS}" in
        linux)  lg_os="Linux" ;;
        macos)  lg_os="Darwin" ;;
        *)      log_error "Unsupported platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"; rm -rf "${tmp_dir}"; return 1 ;;
    esac
    case "${PLATFORM_ARCH}" in
        x86_64) lg_arch="x86_64" ;;
        arm64)  lg_arch="arm64" ;;
        *)      log_error "Unsupported architecture: ${PLATFORM_ARCH}"; rm -rf "${tmp_dir}"; return 1 ;;
    esac
    curl -fsSL -o "${tmp_dir}/lazygit.tar.gz" \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${version}_${lg_os}_${lg_arch}.tar.gz"
    tar --no-absolute-file-names -xf "${tmp_dir}/lazygit.tar.gz" -C "${BIN_DIR}" lazygit
    chmod +x "${BIN_DIR}/lazygit"
    rm -rf "${tmp_dir}"
    log_info "OK: lazygit installed at ${BIN_DIR}/lazygit"
}

ensure_nvim_config_link() {
    # Use NVIM_APPNAME=km so the project nvim config lives at ~/.config/km/
    # and does NOT touch the user's global ~/.config/nvim config.
    local project_nvim="${SCRIPT_DIR}/config/nvim"
    local target="${HOME}/.config/km"

    mkdir -p "${HOME}/.config"

    if [ -L "${target}" ]; then
        local current_target
        current_target="$(readlink "${target}")"
        if [ "${current_target}" = "${project_nvim}" ]; then
            log_info "SKIP: ~/.config/km already linked to ${project_nvim}"
            return 0
        fi
        log_warn "~/.config/km symlinks to ${current_target} — updating to ${project_nvim}"
        rm "${target}"
    elif [ -d "${target}" ]; then
        log_warn "~/.config/km exists as a real directory — skipping symlink (manual merge required)"
        return 0
    fi

    ln -s "${project_nvim}" "${target}"
    log_info "OK: ~/.config/km -> ${project_nvim} (NVIM_APPNAME=km isolates from global nvim config)"
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

ensure_transcription_venv() {
    local venv_dir="${SCRIPT_DIR}/venv"

    if [ -d "${venv_dir}" ] && [ -x "${venv_dir}/bin/python" ]; then
        log_info "SKIP: Python venv already exists at ${venv_dir}"
    else
        log_info "ACTION: Creating Python venv at ${venv_dir}"
        python3 -m venv "${venv_dir}"
        log_info "OK: venv created"
    fi

    log_info "ACTION: Installing transcription packages into venv"
    "${venv_dir}/bin/pip" install --quiet --upgrade pip
    "${venv_dir}/bin/pip" install --quiet \
        yt-dlp \
        "youtube-transcript-api>=1.0" \
        whisperx \
        Pillow \
        spotdl

    log_info "OK: transcription packages installed (see requirements.txt)"
}

ensure_mpv_config() {
    # Always regenerate — vault path may have changed.
    local mpv_dir="${SCRIPT_DIR}/config/mpv"
    local mpv_conf="${mpv_dir}/mpv.conf"

    mkdir -p "${mpv_dir}"
    cat > "${mpv_conf}" <<MPV_CONF
# Project-scoped mpv config for knowledge-management.
# Loaded via MPV_HOME in env.sh — does NOT touch ~/.config/mpv.

# Screenshots save directly into the vault attachments directory.
screenshot-directory=${VAULT_DIR}/public/attachments
screenshot-format=png
screenshot-template=%F-%wH%wM%wS
MPV_CONF
    log_info "OK: mpv config written at ${mpv_conf} (loaded via MPV_HOME in env.sh)"
}

# Bootstrap all Neovim plugins while the network is still available.
# After this runs, nvim operates fully offline — no plugin auto-updates.
#
# Two-phase approach:
#   1. First headless launch lets lazy.nvim clone itself (config/lazy.lua handles this).
#   2. Once lazy.nvim exists, run "Lazy! sync" to install all plugins.
bootstrap_nvim_plugins() {
    if [ ! -x "${BIN_DIR}/nvim" ]; then
        log_warn "nvim not found — skipping plugin bootstrap"
        return 0
    fi

    # NVIM_APPNAME=km stores plugin data under ~/.local/share/km/ (isolated from global nvim)
    local lazy_path="${HOME}/.local/share/km/lazy/lazy.nvim"
    local obsidian_path="${HOME}/.local/share/km/lazy/obsidian.nvim"

    if [ -d "${lazy_path}" ] && [ -d "${obsidian_path}" ]; then
        log_info "SKIP: Neovim plugins already bootstrapped (NVIM_APPNAME=km)"
        return 0
    fi

    log_info "ACTION: Bootstrapping Neovim plugins (one-time; requires network; NVIM_APPNAME=km)"

    # Phase 1: first launch clones lazy.nvim itself (config/lazy.lua bootstrap block)
    if [ ! -d "${lazy_path}" ]; then
        log_info "Phase 1: cloning lazy.nvim plugin manager..."
        _timeout 60 env TERM=xterm-256color NVIM_APPNAME=km "${BIN_DIR}/nvim" \
            --headless -c 'quitall' 2>/dev/null || true
    fi

    # Phase 2: install all plugins via Lazy sync
    if [ -d "${lazy_path}" ]; then
        log_info "Phase 2: syncing plugins via Lazy..."
        if _timeout 180 env TERM=xterm-256color NVIM_APPNAME=km "${BIN_DIR}/nvim" \
            --headless "+Lazy! sync" +qa 2>/dev/null; then
            log_info "OK: Neovim plugins bootstrapped under ~/.local/share/km/"
        else
            log_warn "Lazy sync exited non-zero — run 'source env.sh && nvim' once to finish install"
        fi
    else
        log_warn "lazy.nvim failed to clone — run 'source env.sh && nvim' once to finish install"
    fi
}

# Install a Nerd Font so terminal renders LazyVim icons correctly.
# On WSL2: installs to Windows user fonts + registers in registry + updates Windows Terminal.
# On native Linux: installs to ~/.local/share/fonts.
# On macOS: installs to ~/Library/Fonts.
install_nerd_font() {
    local font_name="JetBrainsMono"
    local font_family="JetBrainsMono NF"
    local font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font_name}.zip"
    local tmp_dir

    # Skip if already installed
    if is_wsl2; then
        local win_user win_font_dir
        win_user="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')"
        win_font_dir="/mnt/c/Users/${win_user}/AppData/Local/Microsoft/Windows/Fonts"
        if ls "${win_font_dir}"/JetBrainsMonoNerdFont-Regular.ttf >/dev/null 2>&1; then
            log_info "SKIP: Nerd Font already installed (${win_font_dir})"
            return 0
        fi
    elif [ "${PLATFORM_OS}" = "macos" ]; then
        if ls "${HOME}/Library/Fonts"/JetBrainsMonoNerdFont-Regular.ttf >/dev/null 2>&1; then
            log_info "SKIP: Nerd Font already installed (~/Library/Fonts)"
            return 0
        fi
    else
        if ls "${HOME}/.local/share/fonts"/JetBrainsMonoNerdFont-Regular.ttf >/dev/null 2>&1; then
            log_info "SKIP: Nerd Font already installed (~/.local/share/fonts)"
            return 0
        fi
    fi

    log_info "ACTION: Installing ${font_family} (required for LazyVim icons)"
    tmp_dir="$(mktemp -d)"
    trap 'rm -rf "${tmp_dir}"' EXIT
    curl -fsSL -o "${tmp_dir}/font.zip" "${font_url}"
    unzip -oq "${tmp_dir}/font.zip" -d "${tmp_dir}/font"

    if is_wsl2; then
        local win_user win_font_dir wt_settings
        win_user="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')"
        win_font_dir="/mnt/c/Users/${win_user}/AppData/Local/Microsoft/Windows/Fonts"
        mkdir -p "${win_font_dir}"

        # Copy font files to Windows user fonts
        cp "${tmp_dir}"/font/JetBrainsMonoNerdFont-*.ttf "${win_font_dir}/"
        log_info "OK: Font files copied to ${win_font_dir}"

        # Register fonts in Windows registry (current user)
        powershell.exe -c '
            $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
            $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
            Get-ChildItem "$fontDir\JetBrainsMonoNerdFont-*.ttf" | ForEach-Object {
                $name = $_.BaseName -replace "JetBrainsMonoNerdFont-", "JetBrainsMono Nerd Font "
                New-ItemProperty -Path $regPath -Name "$name (TrueType)" -Value $_.FullName -PropertyType String -Force | Out-Null
            }
        ' 2>/dev/null
        log_info "OK: Fonts registered in Windows registry"

        # Update Windows Terminal settings to use the Nerd Font
        wt_settings="/mnt/c/Users/${win_user}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
        if [ -f "${wt_settings}" ]; then
            WT_SETTINGS_PATH="${wt_settings}" WT_FONT_FAMILY="${font_family}" python3 -c "
import json, os
settings_path = os.environ['WT_SETTINGS_PATH']
font_family = os.environ['WT_FONT_FAMILY']
with open(settings_path, 'r') as f:
    data = json.load(f)
data.setdefault('profiles', {}).setdefault('defaults', {})['font'] = {
    'face': font_family,
    'size': 12
}
with open(settings_path, 'w') as f:
    json.dump(data, f, indent=4)
" 2>/dev/null
            log_info "OK: Windows Terminal settings updated (font: ${font_family})"
        else
            log_warn "Windows Terminal settings.json not found — set font manually to '${font_family}'"
        fi

    elif [ "${PLATFORM_OS}" = "macos" ]; then
        mkdir -p "${HOME}/Library/Fonts"
        cp "${tmp_dir}"/font/JetBrainsMonoNerdFont-*.ttf "${HOME}/Library/Fonts/"
        log_info "OK: Font installed to ~/Library/Fonts (restart terminal to use)"

    else
        # Native Linux (X11/Wayland)
        mkdir -p "${HOME}/.local/share/fonts"
        cp "${tmp_dir}"/font/JetBrainsMonoNerdFont-*.ttf "${HOME}/.local/share/fonts/"
        fc-cache -f 2>/dev/null || true
        log_info "OK: Font installed to ~/.local/share/fonts"
    fi

    rm -rf "${tmp_dir}"
    log_info "OK: ${font_family} installed — restart terminal for icons to appear"
}

# Detect if running under WSL2
is_wsl2() {
    grep -qi 'microsoft' /proc/version 2>/dev/null
}

# Install direnv and hook it into ~/.bashrc so the project environment activates
# automatically whenever the user cd's into the project directory.
# Uses the official install script (https://direnv.net/install.sh) into
# ~/.local/bin — no sudo required, always gets the current release.
# Only ~/.bashrc is touched (one generic line); all project vars stay in .envrc.
install_direnv() {
    if command -v direnv >/dev/null 2>&1; then
        log_info "SKIP: direnv already installed at $(command -v direnv)"
    else
        log_info "ACTION: Installing direnv via official install script"
        local bin_dir="${HOME}/.local/bin"
        mkdir -p "${bin_dir}"
        export bin_path="${bin_dir}"
        curl -sfL https://direnv.net/install.sh | bash
        [[ ":${PATH}:" != *":${bin_dir}:"* ]] && export PATH="${bin_dir}:${PATH}"
        if command -v direnv >/dev/null 2>&1; then
            log_info "OK: direnv installed to ${bin_dir}"
        else
            log_error "FAIL: direnv install failed — check network or install manually: sudo apt install direnv"
            return 1
        fi
    fi

    local bashrc="${HOME}/.bashrc"
    local hook_line='eval "$(direnv hook bash)"'
    if grep -qF 'direnv hook bash' "${bashrc}" 2>/dev/null; then
        log_info "SKIP: direnv hook already present in ${bashrc}"
    else
        log_info "ACTION: Adding direnv hook to ${bashrc}"
        printf '\n# direnv — auto-activate project environments on cd\n%s\n' \
            "${hook_line}" >> "${bashrc}"
        log_info "OK: direnv hook added to ${bashrc}"
    fi

    if [ -f "${SCRIPT_DIR}/.envrc" ]; then
        log_info "ACTION: Allowing direnv for ${SCRIPT_DIR}"
        direnv allow "${SCRIPT_DIR}"
        log_info "OK: direnv allowed — open a new terminal tab and cd into the project"
    fi
}

# Activate the tracked pre-push privacy guard by pointing the vault's git at
# scripts/hooks/ (which sources scripts/lib/privacy.sh). Using core.hooksPath
# instead of copying a script into .git/hooks/ keeps a single authoritative copy
# of the guard — version-controlled and testable like any other script.
install_vault_privacy_hook() {
    local vault_dir="$1"

    if ! git -C "${vault_dir}" rev-parse --git-dir >/dev/null 2>&1; then
        log_warn "Vault is not a git repo — skipping privacy hook activation"
        return 0
    fi

    chmod +x "${vault_dir}/scripts/hooks/pre-push" 2>/dev/null || true
    git -C "${vault_dir}" config core.hooksPath scripts/hooks
    log_info "OK: pre-push privacy guard activated (core.hooksPath=scripts/hooks)"
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
# Guard: when sourced (e.g. in tests), only define functions — don't execute.
[[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 0

log_info "==> Detecting platform"
detect_platform

if $DRY_RUN; then
    log_info "DRY RUN: skipping all installation steps"
    exit 0
fi

log_info "==> Installing packages"
install_apt_packages vim git ripgrep fzf xdg-utils flatpak xclip wl-clipboard curl unzip \
    ffmpeg mpv python3-venv python3-pip

log_info "==> Ensuring Flathub is configured"
ensure_flathub_remote

log_info "==> Installing Obsidian"
install_obsidian

log_info "==> Creating vault structure"
ensure_dir "${VAULT_DIR}/public/daily"
ensure_dir "${VAULT_DIR}/public/inbox"
ensure_dir "${VAULT_DIR}/public/attachments"
ensure_dir "${VAULT_DIR}/public/archive"
ensure_dir "${VAULT_DIR}/private/daily"
ensure_dir "${VAULT_DIR}/private/inbox"
ensure_dir "${VAULT_DIR}/private/attachments"
ensure_dir "${VAULT_DIR}/private/archive"
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

log_info "==> Deriving default origin remote"
derive_default_remote

# Ask about note tracking if the user hasn't already set KM_TRACK_NOTES
if [ -z "${KM_TRACK_NOTES:-}" ]; then
    echo ""
    echo "Do you want to track your notes in git history?"
    echo "  yes — notes (public/daily/, public/inbox/, public/archive/) are committed to git. (default)"
    echo "        Pair with git-crypt for encrypted remote backups."
    echo "  no  — notes are gitignored. They stay local only."
    echo ""
    printf "Track notes in git? [Y/n] "
    read -r track_answer
    case "${track_answer}" in
        [Nn]|[Nn][Oo]) KM_TRACK_NOTES=false ;;
        *)             KM_TRACK_NOTES=true ;;
    esac
    log_info "KM_TRACK_NOTES=${KM_TRACK_NOTES} (user selected)"
fi

# Ask which editor okm should open notes in, unless KM_EDITOR is preset
# (preset lets non-interactive/automated installs skip the prompt).
if [ -z "${KM_EDITOR:-}" ]; then
    echo ""
    echo "Which editor should okm open your notes in?"
    echo "  vim  — classic Vim, project vimrc via the bin/vim wrapper. Lightweight; nothing extra to install. (default)"
    echo "  nvim — Neovim with the bundled LazyVim + obsidian.nvim config. Downloads the Neovim binary + plugins."
    echo ""
    printf "Editor? [vim/nvim] (default: vim) "
    read -r editor_answer
    case "${editor_answer}" in
        [Nn]|[Nn][Vv][Ii][Mm]|[Nn][Ee][Oo]*) KM_EDITOR=nvim ;;
        *)                                    KM_EDITOR=vim ;;
    esac
    log_info "KM_EDITOR=${KM_EDITOR} (user selected)"
fi

# Persist the choice so env.sh defaults EDITOR to it every session.
# .km-editor is gitignored (per-user, not source). An EDITOR you export
# yourself still wins; this only sets the default.
printf '%s\n' "${KM_EDITOR}" > "${SCRIPT_DIR}/.km-editor"
log_info "OK: saved editor choice to ${SCRIPT_DIR}/.km-editor (${KM_EDITOR})"

# Privacy gate: if the user wants to track notes AND a remote is provided,
# verify it is a private GitHub repo. A public remote is rejected — personal
# notes must never be pushed to a public repository.
if [ "${KM_TRACK_NOTES:-false}" = "true" ] && [ -n "${GIT_REMOTE}" ]; then
    log_info "==> Verifying remote privacy before enabling note tracking"
    if km_check_url_is_private "${GIT_REMOTE}"; then
        log_info "OK: remote is private — note tracking enabled"
    else
        log_warn "Remote failed privacy check — forcing KM_TRACK_NOTES=false"
        log_warn "Notes will be gitignored. Make the remote private and re-run setup to enable tracking."
        KM_TRACK_NOTES=false
    fi
elif [ "${KM_TRACK_NOTES:-false}" = "true" ] && [ -z "${GIT_REMOTE}" ]; then
    log_info "No remote specified at setup time — note tracking enabled for local repo."
    log_info "A pre-push privacy hook will be installed to block pushes to public remotes."
fi

export KM_TRACK_NOTES

log_info "==> Installing direnv (auto-activate project env on cd)"
install_direnv

log_info "==> Writing .gitignore"
ensure_gitignore "${VAULT_DIR}"

log_info "==> Bootstrapping Git repo"
ensure_git_repo "${VAULT_DIR}"

log_info "==> Configuring Git remote"
ensure_git_remote "${VAULT_DIR}" "${GIT_REMOTE}"

log_info "==> Configuring upstream remote"
ensure_upstream_remote "${VAULT_DIR}"

log_info "==> Installing vault privacy hook"
install_vault_privacy_hook "${VAULT_DIR}"

# Neovim is opt-in: only install the (heavy) nvim binary + plugins when the
# user chose nvim at the editor prompt. vim users get a lighter-weight setup.
if [ "${KM_EDITOR:-vim}" = "nvim" ]; then
    log_info "==> Installing Neovim"
    install_nvim
else
    log_info "SKIP: Neovim install (editor=${KM_EDITOR:-vim}; re-run setup and choose nvim to add it)"
fi

log_info "==> Installing lazygit"
install_lazygit

if [ "${KM_EDITOR:-vim}" = "nvim" ]; then
    log_info "==> Linking Neovim config"
    ensure_nvim_config_link
else
    log_info "SKIP: Neovim config link (editor=${KM_EDITOR:-vim})"
fi

if [ "${KM_INSTALL_FONT:-1}" = "1" ]; then
    log_info "==> Installing Nerd Font (terminal icons)"
    install_nerd_font
else
    log_info "SKIP: Nerd Font install (KM_INSTALL_FONT=0)"
fi

log_info "==> Verifying lazygit config"
verify_lazygit_config

if [ "${KM_EDITOR:-vim}" = "nvim" ]; then
    log_info "==> Bootstrapping Neovim plugins"
    bootstrap_nvim_plugins
else
    log_info "SKIP: Neovim plugin bootstrap (editor=${KM_EDITOR:-vim})"
fi

log_info "==> Setting up transcription tools"
ensure_transcription_venv

log_info "==> Configuring mpv screenshots"
ensure_mpv_config

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
