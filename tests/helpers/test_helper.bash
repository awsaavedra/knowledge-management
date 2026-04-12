# tests/helpers/test_helper.bash — Shared setup/teardown for all BATS test files.
#
# Every .bats file should: load 'helpers/test_helper'
# This provides:
#   - bats-support and bats-assert libraries
#   - A unique temp directory per test (TEST_TEMP_DIR)
#   - Fake project dir (FAKE_PROJECT_DIR) and fake vault (FAKE_VAULT_DIR)
#   - Fake HOME so tests never touch real ~/.config or ~/.local
#   - Automatic cleanup in teardown — nothing survives after tests run

_helper_dir="$(cd "$(dirname "${BASH_BATS_TEST_DIRNAME:-$BATS_TEST_DIRNAME}")/../helpers" 2>/dev/null || cd "$(dirname "$BASH_SOURCE")" && pwd)"
_lib_dir="$(cd "$(dirname "$_helper_dir")/../tests/lib" 2>/dev/null || cd "$_helper_dir/../lib" && pwd)"

load "${_lib_dir}/bats-support/load"
load "${_lib_dir}/bats-assert/load"

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

common_setup() {
    # Create a unique temp directory for this test
    TEST_TEMP_DIR="$(mktemp -d)"

    # Create a fake project directory (mirrors real layout)
    FAKE_PROJECT_DIR="${TEST_TEMP_DIR}/fake-project"
    mkdir -p "${FAKE_PROJECT_DIR}/scripts"
    mkdir -p "${FAKE_PROJECT_DIR}/inbox"
    mkdir -p "${FAKE_PROJECT_DIR}/bin"
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim/lua/plugins"
    mkdir -p "${FAKE_PROJECT_DIR}/config/nvim/lua/config"
    mkdir -p "${FAKE_PROJECT_DIR}/config/lazygit"

    # Create a fake vault directory
    FAKE_VAULT_DIR="${TEST_TEMP_DIR}/fake-vault"
    mkdir -p "${FAKE_VAULT_DIR}/daily"
    mkdir -p "${FAKE_VAULT_DIR}/inbox"
    mkdir -p "${FAKE_VAULT_DIR}/attachments"
    mkdir -p "${FAKE_VAULT_DIR}/archive"

    # Set vault env var to fake vault
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"

    # Fake HOME so tests never touch real ~/.config or ~/.local
    REAL_HOME="${HOME}"
    export HOME="${TEST_TEMP_DIR}/fakehome"
    mkdir -p "${HOME}/.config"
    mkdir -p "${HOME}/.local/share"
    mkdir -p "${HOME}/.local/log"
}

teardown() {
    # Restore real HOME
    export HOME="${REAL_HOME}"

    # Nuke the entire temp directory — nothing survives
    if [[ -n "${TEST_TEMP_DIR:-}" && -d "${TEST_TEMP_DIR}" ]]; then
        rm -rf "${TEST_TEMP_DIR}"
    fi
}

# --- Fixture generators ---

# Create a file in the fake project
create_project_file() {
    local filename="$1"
    local content="$2"
    local filepath="${FAKE_PROJECT_DIR}/${filename}"
    mkdir -p "$(dirname "$filepath")"
    printf '%s\n' "$content" > "$filepath"
}

# Create a file in the fake vault
create_vault_file() {
    local filename="$1"
    local content="$2"
    local filepath="${FAKE_VAULT_DIR}/${filename}"
    mkdir -p "$(dirname "$filepath")"
    printf '%s\n' "$content" > "$filepath"
}
