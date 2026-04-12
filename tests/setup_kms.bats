#!/usr/bin/env bats
# Tests for setup-kms.sh helper functions and scoping guarantees.
# Does NOT run apt/flatpak/binary downloads — only tests file-level operations.

load 'helpers/test_helper'

setup() {
    common_setup

    # Source just the function definitions from setup-kms.sh (stop before install steps).
    # We patch set -e to set +e so function failures don't kill the test harness,
    # and redirect LOG_FILE to our temp dir.
    export LOG_FILE="${TEST_TEMP_DIR}/setup.log"
    export SCRIPT_DIR="${FAKE_PROJECT_DIR}"
    export VAULT_DIR="${FAKE_VAULT_DIR}"
    export BIN_DIR="${FAKE_PROJECT_DIR}/bin"

    # Extract function definitions up to "# --- Install steps ---"
    local funcs_src
    funcs_src="$(sed -n '1,/^# --- Install steps ---/p' "${PROJECT_ROOT}/setup-kms.sh" \
        | sed 's/^set -euo pipefail/set +e; set -uo pipefail/' \
        | grep -v '^mkdir -p "\${LOG_DIR}"' \
        | grep -v "^trap ")"
    eval "$funcs_src"
}

# === ensure_dir ===

@test "ensure_dir creates missing directory" {
    local target="${TEST_TEMP_DIR}/newdir/subdir"
    ensure_dir "$target"
    [ -d "$target" ]
}

@test "ensure_dir is idempotent for existing directory" {
    local target="${TEST_TEMP_DIR}/existing"
    mkdir -p "$target"
    run ensure_dir "$target"
    assert_output --partial "SKIP"
}

# === ensure_gitignore ===

@test "ensure_gitignore creates .gitignore with expected patterns" {
    local target="${TEST_TEMP_DIR}/vault-test"
    mkdir -p "$target"
    ensure_gitignore "$target"
    [ -f "${target}/.gitignore" ]
    grep -q ".DS_Store" "${target}/.gitignore"
    grep -q "*.swp" "${target}/.gitignore"
    grep -q "attachments/*.pdf" "${target}/.gitignore"
}

@test "ensure_gitignore is idempotent" {
    local target="${TEST_TEMP_DIR}/vault-test"
    mkdir -p "$target"
    ensure_gitignore "$target"
    run ensure_gitignore "$target"
    assert_output --partial "SKIP"
}

# === ensure_git_repo ===

@test "ensure_git_repo initializes repo with main branch" {
    local target="${TEST_TEMP_DIR}/repo-test"
    mkdir -p "$target"
    echo "test" > "${target}/README.md"
    ensure_git_repo "$target"
    [ -d "${target}/.git" ]
    run git -C "$target" branch --show-current
    assert_output "main"
}

@test "ensure_git_repo is idempotent" {
    local target="${TEST_TEMP_DIR}/repo-test"
    mkdir -p "$target"
    echo "test" > "${target}/README.md"
    ensure_git_repo "$target"
    run ensure_git_repo "$target"
    assert_output --partial "SKIP"
}

# === ensure_nvim_config_link (NVIM_APPNAME=km) ===

@test "ensure_nvim_config_link creates symlink at ~/.config/km" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ensure_nvim_config_link
    [ -L "${HOME}/.config/km" ]
    [ "$(readlink "${HOME}/.config/km")" = "${FAKE_PROJECT_DIR}/config/nvim" ]
}

@test "ensure_nvim_config_link is idempotent" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ensure_nvim_config_link
    run ensure_nvim_config_link
    assert_output --partial "SKIP"
}

@test "ensure_nvim_config_link updates stale symlink" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ln -s "/wrong/target" "${HOME}/.config/km"
    ensure_nvim_config_link
    [ "$(readlink "${HOME}/.config/km")" = "${FAKE_PROJECT_DIR}/config/nvim" ]
}

@test "ensure_nvim_config_link skips real directory" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    mkdir -p "${HOME}/.config/km"
    run ensure_nvim_config_link
    assert_output --partial "manual merge required"
    # Should still be a directory, not a symlink
    [ -d "${HOME}/.config/km" ]
    [ ! -L "${HOME}/.config/km" ]
}

# === Scoping guarantees ===

@test "setup-kms.sh does not reference ~/.zshrc for writes" {
    # The script should not contain ensure_shell_line or replace_shell_line calls
    run grep -c 'ensure_shell_line\|replace_shell_line' "${PROJECT_ROOT}/setup-kms.sh"
    assert_output "0"
}

@test "setup-kms.sh does not symlink ~/.config/nvim" {
    # Should only reference ~/.config/km, never ~/.config/nvim for symlinking
    local nvim_refs
    nvim_refs=$(grep '\.config/nvim' "${PROJECT_ROOT}/setup-kms.sh" | grep -cv '#\|log_info\|log_warn\|echo' || true)
    [ "$nvim_refs" -eq 0 ]
}

@test "bin/okm exists as standalone file" {
    [ -f "${PROJECT_ROOT}/bin/okm" ]
    [ -x "${PROJECT_ROOT}/bin/okm" ]
    grep -q "okm - simple terminal knowledge manager" "${PROJECT_ROOT}/bin/okm"
}
