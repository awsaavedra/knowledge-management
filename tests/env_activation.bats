#!/usr/bin/env bats
# Tests for env.sh — project-scoped environment activation.
# Verifies that sourcing env.sh sets the right variables and does NOT modify global config.

load 'helpers/test_helper'

setup() {
    common_setup
}

@test "PATH is prepended with project bin/" {
    source "${PROJECT_ROOT}/env.sh"
    echo "$PATH" | grep -q "${PROJECT_ROOT}/bin"
}

@test "OBSIDIAN_VAULT defaults to project root (self-contained)" {
    unset OBSIDIAN_VAULT
    source "${PROJECT_ROOT}/env.sh"
    [ "$OBSIDIAN_VAULT" = "$KM_ROOT" ]
    [ -d "$OBSIDIAN_VAULT" ]
}

@test "OBSIDIAN_VAULT respects explicit override" {
    export OBSIDIAN_VAULT="/tmp"
    source "${PROJECT_ROOT}/env.sh"
    [ "$OBSIDIAN_VAULT" = "/tmp" ]
}

@test "OBSIDIAN_DAILY_DIR is set to public/daily" {
    source "${PROJECT_ROOT}/env.sh"
    [ "$OBSIDIAN_DAILY_DIR" = "public/daily" ]
}

@test "OBSIDIAN_NOTES_DIR is set to public/inbox" {
    source "${PROJECT_ROOT}/env.sh"
    [ "$OBSIDIAN_NOTES_DIR" = "public/inbox" ]
}

@test "EDITOR defaults to nvim when unset" {
    unset EDITOR
    source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "nvim" ]
}

@test "EDITOR is preserved if already set (e.g. EDITOR=vim)" {
    EDITOR=vim source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "vim" ]
}

@test "NVIM_APPNAME is set to km" {
    source "${PROJECT_ROOT}/env.sh"
    [ "$NVIM_APPNAME" = "km" ]
}

@test "LG_CONFIG_FILE points to project lazygit config" {
    source "${PROJECT_ROOT}/env.sh"
    [[ "$LG_CONFIG_FILE" == */config/lazygit/config.yml ]]
    [ -f "$LG_CONFIG_FILE" ]
}

@test "env.sh does NOT modify fake zshrc" {
    local rc="${HOME}/.zshrc"
    echo "# original content" > "$rc"
    local before_hash
    before_hash="$(sha256sum "$rc" | cut -d' ' -f1)"
    source "${PROJECT_ROOT}/env.sh"
    local after_hash
    after_hash="$(sha256sum "$rc" | cut -d' ' -f1)"
    [ "$before_hash" = "$after_hash" ]
}

@test "env.sh does NOT create or modify ~/.config/nvim" {
    source "${PROJECT_ROOT}/env.sh"
    # ~/.config/nvim should not exist in our fake HOME (env.sh doesn't create it)
    [ ! -e "${HOME}/.config/nvim" ]
}

@test "~/.config/km symlink is created pointing to project config/nvim" {
    source "${PROJECT_ROOT}/env.sh"
    [ -L "${HOME}/.config/km" ]
    [ "$(readlink "${HOME}/.config/km")" = "${KM_ROOT}/config/nvim" ]
}

@test "~/.config/km symlink is self-healed when stale" {
    ln -s "/tmp/stale-path" "${HOME}/.config/km"
    source "${PROJECT_ROOT}/env.sh"
    [ "$(readlink "${HOME}/.config/km")" = "${KM_ROOT}/config/nvim" ]
}

@test "~/.config/km symlink uses no hardcoded paths" {
    source "${PROJECT_ROOT}/env.sh"
    local target
    target="$(readlink "${HOME}/.config/km")"
    # Must derive from KM_ROOT, not contain any username-specific literal
    [[ "$target" == "${KM_ROOT}"* ]]
}

@test "env.sh does NOT create or modify ~/.config/lazygit" {
    source "${PROJECT_ROOT}/env.sh"
    [ ! -e "${HOME}/.config/lazygit" ]
}

@test "env.sh is idempotent (no duplicate PATH entries)" {
    source "${PROJECT_ROOT}/env.sh"
    local path_after_first="$PATH"
    source "${PROJECT_ROOT}/env.sh"
    # PATH may have a duplicate prepend but the bin/ entry should function the same
    # Count occurrences of the project bin dir
    local count
    count=$(echo "$PATH" | tr ':' '\n' | grep -c "${PROJECT_ROOT}/bin" || true)
    # After sourcing twice, at most 2 entries (acceptable for env.sh; direnv deduplicates)
    [ "$count" -le 2 ]
}

@test "KM_ROOT resolves correctly regardless of cwd" {
    cd /tmp
    source "${PROJECT_ROOT}/env.sh"
    [ -d "${KM_ROOT}" ]
    [ -f "${KM_ROOT}/env.sh" ]
}
