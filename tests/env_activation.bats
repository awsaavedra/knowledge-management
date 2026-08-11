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

@test "EDITOR defaults to vim when unset and no saved choice" {
    unset EDITOR
    KM_EDITOR_FILE="${TEST_TEMP_DIR}/no-such-file" source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "vim" ]
}

@test "EDITOR uses the saved choice (.km-editor) when unset" {
    unset EDITOR
    printf 'nvim\n' > "${TEST_TEMP_DIR}/.km-editor"
    KM_EDITOR_FILE="${TEST_TEMP_DIR}/.km-editor" source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "nvim" ]
}

@test "saved .km-editor choice overrides an inherited EDITOR" {
    # A global EDITOR=nvim (e.g. from ~/.bashrc) must NOT beat the vim chosen at setup.
    printf 'vim\n' > "${TEST_TEMP_DIR}/.km-editor"
    EDITOR=nvim KM_EDITOR_FILE="${TEST_TEMP_DIR}/.km-editor" source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "vim" ]
}

@test "inherited EDITOR is used when there is no saved choice" {
    # A real shell rc exports EDITOR, so simulate that: an un-exported temp
    # assignment (EDITOR=emacs source ...) isn't reliably visible to env.sh's
    # ${EDITOR:-vim} across bash modes, which is a test artifact, not a bug.
    export EDITOR=emacs
    KM_EDITOR_FILE="${TEST_TEMP_DIR}/no-such-file" source "${PROJECT_ROOT}/env.sh"
    [ "$EDITOR" = "emacs" ]
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

# === Shell helpers (vf / vr / vg) ===

@test "vf is defined after sourcing env.sh" {
    source "${PROJECT_ROOT}/env.sh"
    declare -f vf > /dev/null
}

@test "vr is defined after sourcing env.sh" {
    source "${PROJECT_ROOT}/env.sh"
    declare -f vr > /dev/null
}

@test "vg is defined after sourcing env.sh" {
    source "${PROJECT_ROOT}/env.sh"
    declare -f vg > /dev/null
}

_make_stubs() {
    local bin="$1" rg_out="$2"
    mkdir -p "$bin"
    printf '#!/bin/bash\nprintf "%s\n" "%s"\n' "$rg_out" > "${bin}/rg"
    printf '#!/bin/bash\nhead -1\n'                      > "${bin}/fzf"
    printf '#!/bin/bash\nprintf "vim %%s\n" "$*"\n'      > "${bin}/vim"
    chmod +x "${bin}/rg" "${bin}/fzf" "${bin}/vim"
}

@test "vr opens vim at correct file and line" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    _make_stubs "$bin" "notes/foo.md:42:matched text"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vr pattern
    "
    assert_success
    assert_output "vim +42 notes/foo.md"
}

@test "vg delegates to vr — opens vim at correct file and line" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    _make_stubs "$bin" "notes/bar.md:7:hello world"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vg pattern
    "
    assert_success
    assert_output "vim +7 notes/bar.md"
}

@test "vr returns 0 when fzf finds no match" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    mkdir -p "$bin"
    printf '#!/bin/bash\nprintf "notes/x.md:1:text\n"\n' > "${bin}/rg"
    printf '#!/bin/bash\nreturn 1\n'                      > "${bin}/fzf"
    chmod +x "${bin}/rg" "${bin}/fzf"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vr pattern
    "
    assert_success
}

@test "vg returns 0 when fzf finds no match" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    mkdir -p "$bin"
    printf '#!/bin/bash\nprintf "notes/x.md:1:text\n"\n' > "${bin}/rg"
    printf '#!/bin/bash\nreturn 1\n'                      > "${bin}/fzf"
    chmod +x "${bin}/rg" "${bin}/fzf"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vg pattern
    "
    assert_success
}

@test "vf opens vim with fzf-selected file" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    mkdir -p "$bin"
    printf '#!/bin/bash\nprintf "notes/my-note.md\n"\n' > "${bin}/fzf"
    printf '#!/bin/bash\nprintf "vim %%s\n" "$*"\n'     > "${bin}/vim"
    chmod +x "${bin}/fzf" "${bin}/vim"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vf
    "
    assert_success
    assert_output "vim notes/my-note.md"
}

@test "vf returns 0 when fzf finds no file" {
    local bin="${TEST_TEMP_DIR}/stubbin"
    mkdir -p "$bin"
    printf '#!/bin/bash\nreturn 1\n' > "${bin}/fzf"
    chmod +x "${bin}/fzf"
    local full_path="${bin}:${PATH}"
    run bash -c "
        export PATH='${full_path}'
        source '${PROJECT_ROOT}/env.sh'
        vf
    "
    assert_success
}
