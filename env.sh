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

# --- Project binaries first on PATH ---
export PATH="${KMS_ROOT}/bin:${PATH}"

# --- Vault location ---
export OBSIDIAN_VAULT="/home/aws/workspace/knowledge-management-system"
export OBSIDIAN_DAILY_DIR=daily
export OBSIDIAN_NOTES_DIR=inbox

# --- Editor: use project-scoped nvim config via NVIM_APPNAME ---
# This makes nvim read from ~/.config/kms/ instead of ~/.config/nvim/
# Your global nvim config is not affected.
export EDITOR=nvim
export NVIM_APPNAME=kms

# --- lazygit: use project config without symlinking ~/.config/lazygit ---
export LG_CONFIG_FILE="${KMS_ROOT}/config/lazygit/config.yml"

# --- Aliases ---
alias obs="flatpak run md.obsidian.Obsidian"
