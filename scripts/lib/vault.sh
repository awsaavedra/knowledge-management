#!/usr/bin/env bash
# scripts/lib/vault.sh — single source of truth for vault directory resolution.
#
# Usage (in any script):
#   source "${SCRIPT_DIR}/scripts/lib/vault.sh"
#   VAULT_DIR="$(km_vault_dir "${SCRIPT_DIR}")"
#
# Priority:
#   1. $OBSIDIAN_VAULT env var (explicit override)
#   2. SCRIPT_DIR (project root — self-contained by default)

km_vault_dir() {
    if [ -n "${OBSIDIAN_VAULT:-}" ]; then
        printf '%s' "${OBSIDIAN_VAULT}"
    else
        printf '%s' "${1}"
    fi
}
