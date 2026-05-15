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

# --- Vault location (project root by default; override with OBSIDIAN_VAULT) ---
export OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-${KM_ROOT}}"
export OBSIDIAN_DAILY_DIR=public/daily
export OBSIDIAN_NOTES_DIR=public/inbox

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
# ~/.config/km is kept in sync with the project's config/nvim so that
# NVIM_APPNAME=km always resolves correctly, regardless of repo location or username.
export EDITOR="${EDITOR:-nvim}"
export NVIM_APPNAME=km
if [ -d "${KM_ROOT}/config/nvim" ]; then
    _km_link="${HOME}/.config/km"
    _km_nvim="${KM_ROOT}/config/nvim"
    if [ ! -e "${_km_link}" ] || [ "$(readlink "${_km_link}")" != "${_km_nvim}" ]; then
        mkdir -p "${HOME}/.config"
        ln -sf "${_km_nvim}" "${_km_link}"
    fi
    unset _km_link _km_nvim
fi

# --- Vim: project-scoped vimrc via bin/vim wrapper (NOT VIMINIT) ---
# nvim also honors $VIMINIT and uses it in place of init.lua, which silently
# disables LazyVim. We use a bin/vim wrapper instead to scope the project
# vimrc to vim only — PATH-priority makes `vim` resolve to bin/vim.

# --- lazygit: use project config without symlinking ~/.config/lazygit ---
export LG_CONFIG_FILE="${KM_ROOT}/config/lazygit/config.yml"

# --- mpv: use project config without touching ~/.config/mpv ---
export MPV_HOME="${KM_ROOT}/config/mpv"

# --- Python venv: project-local transcription tools (yt-dlp, whisperX, etc.) ---
if [ -d "${KM_ROOT}/venv/bin" ]; then
    [[ ":${PATH}:" != *":${KM_ROOT}/venv/bin:"* ]] && export PATH="${KM_ROOT}/venv/bin:${PATH}"
    export VIRTUAL_ENV="${KM_ROOT}/venv"
fi

# --- Shell helpers (override global vf/vr to exclude venv/) ---
# vf: fuzzy-find a file and open it in vim (skips venv/)
vf() { local file; file=$(rg --files --glob '!venv' | fzf) && vim "$file"; }
# vr: grep via rg+fzf and open at the matched line (skips venv/)
vr() {
  local sel file line
  sel=$(rg -i --line-number --no-heading --color=never --glob '!venv' "$@" | fzf) || return
  file=$(echo "$sel" | cut -d: -f1)
  line=$(echo "$sel" | cut -d: -f2)
  vim +"$line" "$file"
}
