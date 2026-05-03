# env.sh — Activate the knowledge management project environment.
#
# Usage:
#   source env.sh          (from any shell)
#   direnv + .envrc        (automatic; see .envrc)
#
# This sets project-scoped environment variables, PATH, and aliases.
# It does NOT modify ~/.zshrc, ~/.bashrc, or any global config files.
# Your global nvim, lazygit, and shell configs are untouched.

# Resolve project root relative to this file (works in bash and zsh)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    KM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "${ZSH_VERSION:-}" ]; then
    KM_ROOT="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    KM_ROOT="$(cd "$(dirname "$0")" && pwd)"
fi

# --- Project binaries first on PATH (dedup guard for repeated sourcing) ---
[[ ":${PATH}:" != *":${KM_ROOT}/bin:"* ]] && export PATH="${KM_ROOT}/bin:${PATH}"

# --- Vault location (sibling directory by default; override with OBSIDIAN_VAULT) ---
if [ -z "${OBSIDIAN_VAULT:-}" ]; then
    _km_parent="$(cd "${KM_ROOT}/.." && pwd)"
    _km_sibling="${_km_parent}/knowledge-management"
    if [ "${_km_sibling}" = "${KM_ROOT}" ]; then
        export OBSIDIAN_VAULT="${KM_ROOT}"
    else
        export OBSIDIAN_VAULT="${_km_sibling}"
    fi
    unset _km_parent _km_sibling
fi
export OBSIDIAN_DAILY_DIR=daily
export OBSIDIAN_NOTES_DIR=inbox

# --- Note tracking: set before running setup to control vault .gitignore ---
# Default (true): notes are tracked in git (pair with git-crypt for encryption).
# Set to "false" if you want notes gitignored and local-only.
export KM_TRACK_NOTES="${KM_TRACK_NOTES:-true}"

# --- Locale: WSL2 may not have en_US.UTF-8 generated; fall back to C.UTF-8 ---
# Without a valid UTF-8 locale, Neovim reports broken Unicode and icons won't render.
# Check locale -a (installed locales) rather than locale (which echoes $LC_ALL).
if ! locale -a 2>/dev/null | grep -qi 'en_US\.utf'; then
    export LC_ALL=C.UTF-8
    export LANG=C.UTF-8
fi

# --- Editor: use project-scoped nvim config via NVIM_APPNAME ---
# This makes nvim read from ~/.config/km/ instead of ~/.config/nvim/
# Your global nvim config is not affected.
export EDITOR="${EDITOR:-nvim}"
export NVIM_APPNAME=km

# --- Vim: project-scoped vimrc via VIMINIT ---
# VIMINIT replaces ~/.vimrc lookup; the project vimrc explicitly sources
# ~/.vimrc first so personal settings still apply.
export VIMINIT="source ${KM_ROOT}/config/vim/vimrc"

# --- lazygit: use project config without symlinking ~/.config/lazygit ---
export LG_CONFIG_FILE="${KM_ROOT}/config/lazygit/config.yml"

# --- mpv: use project config without touching ~/.config/mpv ---
export MPV_HOME="${KM_ROOT}/config/mpv"

# --- Python venv: project-local transcription tools (yt-dlp, whisperX, etc.) ---
if [ -d "${KM_ROOT}/venv/bin" ]; then
    [[ ":${PATH}:" != *":${KM_ROOT}/venv/bin:"* ]] && export PATH="${KM_ROOT}/venv/bin:${PATH}"
    export VIRTUAL_ENV="${KM_ROOT}/venv"
fi
