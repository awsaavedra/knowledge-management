# env.sh — Activate the knowledge management project environment.
#
# Usage:
#   source env.sh          (from any shell)
#   direnv + .envrc        (automatic; see .envrc)
#
# This sets project-scoped environment variables, PATH, and aliases.
# It does NOT modify ~/.zshrc, ~/.bashrc, or any global config files.
# Your global nvim, lazygit, and shell configs are untouched.

# Resolve project root relative to this file
KMS_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# --- Project binaries first on PATH (dedup guard for repeated sourcing) ---
[[ ":${PATH}:" != *":${KMS_ROOT}/bin:"* ]] && export PATH="${KMS_ROOT}/bin:${PATH}"

# --- Vault location (sibling directory by default; override with OBSIDIAN_VAULT) ---
export OBSIDIAN_VAULT="${OBSIDIAN_VAULT:-$(cd "${KMS_ROOT}/.." && pwd)/knowledge-management-system}"
export OBSIDIAN_DAILY_DIR=daily
export OBSIDIAN_NOTES_DIR=inbox

# --- Note tracking: set before running setup to control vault .gitignore ---
# Default (true): notes are tracked in git (pair with git-crypt for encryption).
# Set to "false" if you want notes gitignored and local-only.
export KM_TRACK_NOTES="${KM_TRACK_NOTES:-true}"

# --- Editor: use project-scoped nvim config via NVIM_APPNAME ---
# This makes nvim read from ~/.config/km/ instead of ~/.config/nvim/
# Your global nvim config is not affected.
export EDITOR=nvim
export NVIM_APPNAME=km

# --- lazygit: use project config without symlinking ~/.config/lazygit ---
export LG_CONFIG_FILE="${KMS_ROOT}/config/lazygit/config.yml"

# --- mpv: use project config without touching ~/.config/mpv ---
export MPV_HOME="${KMS_ROOT}/config/mpv"

# --- Python venv: project-local transcription tools (yt-dlp, whisperX, etc.) ---
if [ -d "${KMS_ROOT}/venv/bin" ]; then
    [[ ":${PATH}:" != *":${KMS_ROOT}/venv/bin:"* ]] && export PATH="${KMS_ROOT}/venv/bin:${PATH}"
    export VIRTUAL_ENV="${KMS_ROOT}/venv"
fi
