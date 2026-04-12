#!/usr/bin/env bats
# Quickstart integration test — validates the full setup → activate → verify flow.
#
# Simulates the quickstart guide in a sandboxed environment:
#   1. setup-kms.sh (file-level operations only — apt/flatpak/binary downloads mocked)
#   2. source env.sh
#   3. verify-kms.sh (validates what we can in the sandbox)
#
# Uses fake HOME and temp directories. Everything is cleaned up in teardown.

load 'helpers/test_helper'

setup() {
    common_setup

    # Source the setup functions (not the install steps)
    export LOG_FILE="${TEST_TEMP_DIR}/setup.log"
    export SCRIPT_DIR="${PROJECT_ROOT}"
    export VAULT_DIR="${FAKE_VAULT_DIR}"
    export BIN_DIR="${FAKE_PROJECT_DIR}/bin"

    local funcs_src
    funcs_src="$(sed -n '1,/^# --- Install steps ---/p' "${PROJECT_ROOT}/setup-kms.sh" \
        | sed 's/^set -euo pipefail/set +e; set -uo pipefail/' \
        | grep -v '^mkdir -p "\${LOG_DIR}"' \
        | grep -v "^trap ")"
    eval "$funcs_src"
}

# === Step 1: setup-kms.sh creates vault structure ===

@test "quickstart: setup creates vault directories" {
    ensure_dir "${VAULT_DIR}/daily"
    ensure_dir "${VAULT_DIR}/inbox"
    ensure_dir "${VAULT_DIR}/attachments"
    ensure_dir "${VAULT_DIR}/archive"
    [ -d "${VAULT_DIR}/daily" ]
    [ -d "${VAULT_DIR}/inbox" ]
    [ -d "${VAULT_DIR}/attachments" ]
    [ -d "${VAULT_DIR}/archive" ]
}

@test "quickstart: setup creates .gitignore" {
    ensure_gitignore "${VAULT_DIR}"
    [ -f "${VAULT_DIR}/.gitignore" ]
    grep -q ".DS_Store" "${VAULT_DIR}/.gitignore"
}

@test "quickstart: setup initializes git repo" {
    ensure_gitignore "${VAULT_DIR}"
    ensure_git_repo "${VAULT_DIR}"
    [ -d "${VAULT_DIR}/.git" ]
    run git -C "${VAULT_DIR}" branch --show-current
    assert_output "main"
}

@test "quickstart: setup creates nvim config symlink at ~/.config/km" {
    ensure_nvim_config_link
    [ -L "${HOME}/.config/km" ]
    [ "$(readlink "${HOME}/.config/km")" = "${PROJECT_ROOT}/config/nvim" ]
}

@test "quickstart: setup does NOT create ~/.config/nvim" {
    ensure_nvim_config_link
    [ ! -e "${HOME}/.config/nvim" ]
}

@test "quickstart: setup does NOT create ~/.config/lazygit" {
    verify_lazygit_config
    [ ! -e "${HOME}/.config/lazygit" ]
}

@test "quickstart: bin/okm exists and is executable" {
    [ -f "${PROJECT_ROOT}/bin/okm" ]
    [ -x "${PROJECT_ROOT}/bin/okm" ]
    grep -q "okm - simple terminal knowledge manager" "${PROJECT_ROOT}/bin/okm"
}

# === Step 2: source env.sh activates environment ===

@test "quickstart: env.sh sets all required variables" {
    source "${PROJECT_ROOT}/env.sh"
    [ -n "$OBSIDIAN_VAULT" ]
    [ -n "$OBSIDIAN_DAILY_DIR" ]
    [ -n "$OBSIDIAN_NOTES_DIR" ]
    [ "$EDITOR" = "nvim" ]
    [ "$NVIM_APPNAME" = "km" ]
    [ -n "$LG_CONFIG_FILE" ]
}

@test "quickstart: env.sh makes okm accessible via PATH" {
    source "${PROJECT_ROOT}/env.sh"
    command -v okm >/dev/null 2>&1
}

# === Step 3: okm commands work after activation ===

@test "quickstart: okm path returns vault path after env activation" {
    source "${PROJECT_ROOT}/env.sh"
    run "${PROJECT_ROOT}/bin/okm" path
    assert_success
    # Should print the vault path (from OBSIDIAN_VAULT set by env.sh)
    local expected
    expected="$(cd "${PROJECT_ROOT}/.." && pwd)/knowledge-management-system"
    assert_output "$expected"
}

@test "quickstart: okm today creates daily note in vault" {
    export EDITOR="true"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="daily"
    export OBSIDIAN_NOTES_DIR="inbox"
    run "${PROJECT_ROOT}/bin/okm" today
    local today
    today="$(date +%F)"
    [ -f "${FAKE_VAULT_DIR}/daily/${today}.md" ]
}

@test "quickstart: okm new creates note in vault inbox" {
    export EDITOR="true"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="daily"
    export OBSIDIAN_NOTES_DIR="inbox"
    run "${PROJECT_ROOT}/bin/okm" new "quickstart test note"
    [ -f "${FAKE_VAULT_DIR}/inbox/quickstart-test-note.md" ]
}

# === Full flow: setup → activate → use → verify no pollution ===

@test "quickstart: full flow leaves no global config changes" {
    # Record state before
    local zshrc_before=""
    if [ -f "${HOME}/.zshrc" ]; then
        zshrc_before="$(cat "${HOME}/.zshrc")"
    fi

    # Step 1: Run setup operations
    ensure_dir "${VAULT_DIR}/daily"
    ensure_dir "${VAULT_DIR}/inbox"
    ensure_dir "${VAULT_DIR}/attachments"
    ensure_dir "${BIN_DIR}"
    ensure_gitignore "${VAULT_DIR}"
    ensure_git_repo "${VAULT_DIR}"
    ensure_nvim_config_link

    # Step 2: Source env
    source "${PROJECT_ROOT}/env.sh"

    # Step 3: Use okm
    export EDITOR="true"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    "${PROJECT_ROOT}/bin/okm" today || true

    # Verify: no global pollution
    [ ! -e "${HOME}/.config/nvim" ]
    [ ! -e "${HOME}/.config/lazygit" ]
    if [ -n "$zshrc_before" ]; then
        [ "$(cat "${HOME}/.zshrc")" = "$zshrc_before" ]
    fi
}

@test "quickstart: teardown removes all temp files" {
    # This test validates that our temp dir approach works.
    # After this test's teardown runs, TEST_TEMP_DIR should not exist.
    # We can't test this directly (teardown runs after), but we verify
    # the structure is isolated.
    [ -d "${TEST_TEMP_DIR}" ]
    [ -d "${FAKE_VAULT_DIR}" ]
    [ -d "${FAKE_PROJECT_DIR}" ]
    # All inside TEST_TEMP_DIR
    [[ "${FAKE_VAULT_DIR}" == "${TEST_TEMP_DIR}"/* ]]
    [[ "${FAKE_PROJECT_DIR}" == "${TEST_TEMP_DIR}"/* ]]
    [[ "${HOME}" == "${TEST_TEMP_DIR}"/* ]]
}
