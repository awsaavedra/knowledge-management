#!/usr/bin/env bats
# Tests for setup-kms.sh helper functions and scoping guarantees.
# Does NOT run apt/flatpak/binary downloads — only tests file-level operations.

load 'helpers/test_helper'

setup() {
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"

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

# === install_okm_binary ===

@test "install_okm_binary writes content and sets +x" {
    local target="${TEST_TEMP_DIR}/test-bin"
    install_okm_binary "$target" "#!/bin/bash\necho hello"
    [ -x "$target" ]
    grep -q "echo hello" "$target"
}

@test "install_okm_binary is idempotent (same hash)" {
    local target="${TEST_TEMP_DIR}/test-bin"
    local content="#!/bin/bash\necho hello"
    install_okm_binary "$target" "$content"
    run install_okm_binary "$target" "$content"
    assert_output --partial "SKIP"
}

@test "install_okm_binary overwrites when content differs" {
    local target="${TEST_TEMP_DIR}/test-bin"
    install_okm_binary "$target" "version 1"
    install_okm_binary "$target" "version 2"
    grep -q "version 2" "$target"
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

# === ensure_nvim_config_link (NVIM_APPNAME=kms) ===

@test "ensure_nvim_config_link creates symlink at ~/.config/kms" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ensure_nvim_config_link
    [ -L "${HOME}/.config/kms" ]
    [ "$(readlink "${HOME}/.config/kms")" = "${FAKE_PROJECT_DIR}/config/nvim" ]
}

@test "ensure_nvim_config_link is idempotent" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ensure_nvim_config_link
    run ensure_nvim_config_link
    assert_output --partial "SKIP"
}

@test "ensure_nvim_config_link updates stale symlink" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    ln -s "/wrong/target" "${HOME}/.config/kms"
    ensure_nvim_config_link
    [ "$(readlink "${HOME}/.config/kms")" = "${FAKE_PROJECT_DIR}/config/nvim" ]
}

@test "ensure_nvim_config_link skips real directory" {
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim"
    mkdir -p "${HOME}/.config/kms"
    run ensure_nvim_config_link
    assert_output --partial "manual merge required"
    # Should still be a directory, not a symlink
    [ -d "${HOME}/.config/kms" ]
    [ ! -L "${HOME}/.config/kms" ]
}

# === Scoping guarantees ===

@test "setup-kms.sh does not reference ~/.zshrc for writes" {
    # The script should not contain ensure_shell_line or replace_shell_line calls
    run grep -c 'ensure_shell_line\|replace_shell_line' "${PROJECT_ROOT}/setup-kms.sh"
    assert_output "0"
}

@test "setup-kms.sh does not symlink ~/.config/nvim" {
    # Should only reference ~/.config/kms, never ~/.config/nvim for symlinking
    local nvim_refs
    nvim_refs=$(grep '\.config/nvim' "${PROJECT_ROOT}/setup-kms.sh" | grep -cv '#\|log_info\|log_warn\|echo' || true)
    [ "$nvim_refs" -eq 0 ]
}

@test "bin/okm exists as standalone file" {
    [ -f "${PROJECT_ROOT}/bin/okm" ]
    [ -x "${PROJECT_ROOT}/bin/okm" ]
    grep -q "okm - simple terminal knowledge manager" "${PROJECT_ROOT}/bin/okm"
}
