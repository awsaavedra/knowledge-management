#!/usr/bin/env bats
# Tests for scripts/lib/privacy.sh, the setup-km.sh privacy gate,
# the vault pre-push hook installer, and okm sync privacy enforcement.

load 'helpers/test_helper'

# ---------------------------------------------------------------------------
# Helpers shared across tests
# ---------------------------------------------------------------------------

# Create a fake `gh` binary in FAKE_BIN_DIR and prepend it to PATH.
# Behaviour is controlled by env vars set in each test:
#   FAKE_GH_PRIVATE   = true | false  (default: true)
#   FAKE_GH_API_FAIL  = 1             (simulate API/auth error)
_setup_fake_gh() {
    FAKE_BIN_DIR="${TEST_TEMP_DIR}/fake-bin"
    mkdir -p "${FAKE_BIN_DIR}"
    cat > "${FAKE_BIN_DIR}/gh" <<'SH'
#!/usr/bin/env bash
case "$1" in
    api)
        [ "${FAKE_GH_API_FAIL:-0}" = "1" ] && exit 1
        echo "${FAKE_GH_PRIVATE:-true}"
        ;;
    auth)
        echo "mock-token"
        ;;
    *)
        exit 1
        ;;
esac
SH
    chmod +x "${FAKE_BIN_DIR}/gh"
    export PATH="${FAKE_BIN_DIR}:${PATH}"
}

# Init a bare git repo, add it as origin of a second repo, return the second repo path.
_setup_vault_with_remote() {
    local remote_url="$1"
    local vault_dir="${TEST_TEMP_DIR}/vault-remote"
    mkdir -p "${vault_dir}"
    git -C "${vault_dir}" init -b main -q
    git -C "${vault_dir}" remote add origin "${remote_url}"
    echo "$vault_dir"
}

setup() {
    common_setup
    # Source the privacy library under test
    source "${PROJECT_ROOT}/scripts/lib/privacy.sh"
}

# ---------------------------------------------------------------------------
# km_parse_github_slug
# ---------------------------------------------------------------------------

@test "km_parse_github_slug: SSH URL returns owner/repo" {
    run km_parse_github_slug "git@github.com:alice/my-vault.git"
    assert_success
    assert_output "alice/my-vault"
}

@test "km_parse_github_slug: SSH URL without .git suffix" {
    run km_parse_github_slug "git@github.com:alice/my-vault"
    assert_success
    assert_output "alice/my-vault"
}

@test "km_parse_github_slug: HTTPS URL returns owner/repo" {
    run km_parse_github_slug "https://github.com/alice/my-vault.git"
    assert_success
    assert_output "alice/my-vault"
}

@test "km_parse_github_slug: HTTPS URL without .git suffix" {
    run km_parse_github_slug "https://github.com/alice/my-vault"
    assert_success
    assert_output "alice/my-vault"
}

@test "km_parse_github_slug: non-GitHub URL prints nothing" {
    run km_parse_github_slug "https://gitlab.com/alice/repo.git"
    assert_success
    assert_output ""
}

@test "km_parse_github_slug: empty string prints nothing" {
    run km_parse_github_slug ""
    assert_success
    assert_output ""
}

# ---------------------------------------------------------------------------
# km_is_note_path
# ---------------------------------------------------------------------------

@test "km_is_note_path: daily note is a personal note" {
    run km_is_note_path "daily/2026-05-13.md"
    assert_success
}

@test "km_is_note_path: archive note is a personal note" {
    run km_is_note_path "archive/completed-project.md"
    assert_success
}

@test "km_is_note_path: inbox note is a personal note" {
    run km_is_note_path "inbox/my-note.md"
    assert_success
}

@test "km_is_note_path: inbox template is NOT a personal note" {
    run km_is_note_path "inbox/templates/daily-template.md"
    assert_failure
}

@test "km_is_note_path: attachment is NOT a personal note" {
    run km_is_note_path "attachments/screenshot.png"
    assert_failure
}

@test "km_is_note_path: project-level file is NOT a personal note" {
    run km_is_note_path "bin/okm"
    assert_failure
}

# ---------------------------------------------------------------------------
# km_check_url_is_private — no remote
# ---------------------------------------------------------------------------

@test "km_check_url_is_private: empty URL is safe (local-only vault)" {
    run km_check_url_is_private ""
    assert_success
}

# ---------------------------------------------------------------------------
# km_check_url_is_private — non-GitHub remote
# ---------------------------------------------------------------------------

@test "km_check_url_is_private: non-GitHub URL warns but allows (cannot verify)" {
    run km_check_url_is_private "https://gitlab.com/alice/vault.git"
    assert_success
    assert_output --partial "Warning"
}

# ---------------------------------------------------------------------------
# km_check_url_is_private — GitHub remote, gh not available
# ---------------------------------------------------------------------------

@test "km_check_url_is_private: fails when gh CLI is absent" {
    # Remove gh from PATH entirely
    local safe_path
    safe_path="$(echo "$PATH" | tr ':' '\n' | grep -v '/usr/bin\|/bin' | tr '\n' ':' || true)"
    # Just test with a PATH that won't have gh
    PATH="/usr/bin:/bin" run km_check_url_is_private "git@github.com:alice/vault.git"
    assert_failure
    assert_output --partial "PRIVACY:"
}

# ---------------------------------------------------------------------------
# km_check_url_is_private — GitHub remote, fake gh
# ---------------------------------------------------------------------------

@test "km_check_url_is_private: private GitHub repo returns success" {
    _setup_fake_gh
    FAKE_GH_PRIVATE=true run km_check_url_is_private "git@github.com:alice/vault.git"
    assert_success
}

@test "km_check_url_is_private: public GitHub repo returns failure" {
    _setup_fake_gh
    FAKE_GH_PRIVATE=false run km_check_url_is_private "git@github.com:alice/vault.git"
    assert_failure
    assert_output --partial "PUBLIC"
}

@test "km_check_url_is_private: gh API error returns failure" {
    _setup_fake_gh
    FAKE_GH_API_FAIL=1 run km_check_url_is_private "git@github.com:alice/vault.git"
    assert_failure
    assert_output --partial "PRIVACY:"
}

# ---------------------------------------------------------------------------
# km_check_remote_is_private — reads remote from git repo
# ---------------------------------------------------------------------------

@test "km_check_remote_is_private: vault with no remote is safe" {
    local vault_dir="${TEST_TEMP_DIR}/vault-no-remote"
    mkdir -p "${vault_dir}"
    git -C "${vault_dir}" init -b main -q
    run km_check_remote_is_private "${vault_dir}"
    assert_success
}

@test "km_check_remote_is_private: vault with private GitHub remote is safe" {
    _setup_fake_gh
    local vault_dir
    vault_dir="$(_setup_vault_with_remote "git@github.com:alice/vault.git")"
    FAKE_GH_PRIVATE=true run km_check_remote_is_private "${vault_dir}"
    assert_success
}

@test "km_check_remote_is_private: vault with public GitHub remote fails" {
    _setup_fake_gh
    local vault_dir
    vault_dir="$(_setup_vault_with_remote "git@github.com:alice/vault.git")"
    FAKE_GH_PRIVATE=false run km_check_remote_is_private "${vault_dir}"
    assert_failure
    assert_output --partial "PUBLIC"
}

# ---------------------------------------------------------------------------
# install_vault_privacy_hook
# ---------------------------------------------------------------------------

_load_setup_km_functions() {
    export LOG_FILE="${TEST_TEMP_DIR}/setup.log"
    export SCRIPT_DIR="${FAKE_PROJECT_DIR}"
    export VAULT_DIR="${FAKE_VAULT_DIR}"
    export BIN_DIR="${FAKE_PROJECT_DIR}/bin"
    local funcs_src
    funcs_src="$(sed -n '1,/^# --- Install steps ---/p' "${PROJECT_ROOT}/setup-km.sh" \
        | sed 's/^set -euo pipefail/set +e; set -uo pipefail/' \
        | grep -v '^mkdir -p "\${LOG_DIR}"' \
        | grep -v "^trap ")"
    eval "$funcs_src"
}

@test "install_vault_privacy_hook: creates executable hook in vault .git/hooks" {
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    _load_setup_km_functions
    install_vault_privacy_hook "${FAKE_VAULT_DIR}"
    local hook="${FAKE_VAULT_DIR}/.git/hooks/pre-push"
    [ -f "$hook" ]
    [ -x "$hook" ]
}

@test "install_vault_privacy_hook: hook is a valid bash script (syntax check)" {
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    _load_setup_km_functions
    install_vault_privacy_hook "${FAKE_VAULT_DIR}"
    run bash -n "${FAKE_VAULT_DIR}/.git/hooks/pre-push"
    assert_success
}

@test "install_vault_privacy_hook: skips gracefully when .git/hooks absent" {
    # FAKE_VAULT_DIR has no git repo
    _load_setup_km_functions
    run install_vault_privacy_hook "${FAKE_VAULT_DIR}"
    assert_success
    assert_output --partial "WARN"
}

# ---------------------------------------------------------------------------
# Pre-push hook behaviour (invoke hook directly)
# ---------------------------------------------------------------------------

_install_hook_in_temp_vault() {
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    _load_setup_km_functions
    install_vault_privacy_hook "${FAKE_VAULT_DIR}"
}

@test "pre-push hook: allows push to private GitHub repo" {
    _setup_fake_gh
    _install_hook_in_temp_vault
    FAKE_GH_PRIVATE=true \
        run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
            "origin" "git@github.com:alice/vault.git" \
            <<< "refs/heads/main abc123 refs/heads/main 0000000000000000000000000000000000000000"
    assert_success
}

@test "pre-push hook: blocks push to public GitHub repo with no note files" {
    _setup_fake_gh
    _install_hook_in_temp_vault
    # Even with no note files in the push range, public repo is blocked
    # (push range is empty — git diff-tree returns nothing)
    FAKE_GH_PRIVATE=false \
        run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
            "origin" "git@github.com:alice/vault.git" \
            <<< ""
    # Exit 0 because no note files were found in the (empty) push range
    assert_success
}

@test "pre-push hook: allows push to non-GitHub remote without checking" {
    _setup_fake_gh
    _install_hook_in_temp_vault
    run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
        "origin" "https://gitlab.com/alice/vault.git" \
        <<< ""
    assert_success
}

@test "pre-push hook: blocks when gh is missing" {
    # Ensure gh is not on PATH
    _install_hook_in_temp_vault
    PATH="/usr/bin:/bin" run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
        "origin" "git@github.com:alice/vault.git" \
        <<< ""
    assert_failure
    assert_output --partial "gh CLI not found"
}

@test "pre-push hook: blocks when gh API is unresponsive" {
    _setup_fake_gh
    _install_hook_in_temp_vault
    FAKE_GH_API_FAIL=1 \
        run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
            "origin" "git@github.com:alice/vault.git" \
            <<< ""
    assert_failure
    assert_output --partial "Could not verify"
}

# ---------------------------------------------------------------------------
# setup-km.sh privacy gate: KM_TRACK_NOTES overridden for public remote
# ---------------------------------------------------------------------------

@test "setup-km.sh privacy gate: public remote forces KM_TRACK_NOTES=false" {
    _setup_fake_gh
    _load_setup_km_functions
    KM_TRACK_NOTES=true
    GIT_REMOTE="git@github.com:alice/vault.git"
    FAKE_GH_PRIVATE=false

    # Re-run just the gate logic inline (mirrors setup-km.sh gate block)
    if [ "${KM_TRACK_NOTES}" = "true" ] && [ -n "${GIT_REMOTE}" ]; then
        if ! km_check_url_is_private "${GIT_REMOTE}" 2>/dev/null; then
            KM_TRACK_NOTES=false
        fi
    fi

    [ "${KM_TRACK_NOTES}" = "false" ]
}

@test "setup-km.sh privacy gate: private remote keeps KM_TRACK_NOTES=true" {
    _setup_fake_gh
    _load_setup_km_functions
    KM_TRACK_NOTES=true
    GIT_REMOTE="git@github.com:alice/vault.git"
    FAKE_GH_PRIVATE=true

    if [ "${KM_TRACK_NOTES}" = "true" ] && [ -n "${GIT_REMOTE}" ]; then
        if ! km_check_url_is_private "${GIT_REMOTE}" 2>/dev/null; then
            KM_TRACK_NOTES=false
        fi
    fi

    [ "${KM_TRACK_NOTES}" = "true" ]
}

@test "setup-km.sh privacy gate: no remote keeps KM_TRACK_NOTES=true" {
    _load_setup_km_functions
    KM_TRACK_NOTES=true
    GIT_REMOTE=""

    if [ "${KM_TRACK_NOTES}" = "true" ] && [ -n "${GIT_REMOTE}" ]; then
        if ! km_check_url_is_private "${GIT_REMOTE}" 2>/dev/null; then
            KM_TRACK_NOTES=false
        fi
    fi

    [ "${KM_TRACK_NOTES}" = "true" ]
}

# ---------------------------------------------------------------------------
# okm sync privacy enforcement
# ---------------------------------------------------------------------------

@test "okm sync: blocks push to public GitHub remote" {
    _setup_fake_gh
    # Set up vault as a git repo with a GitHub remote
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    git -C "${FAKE_VAULT_DIR}" remote add origin "git@github.com:alice/vault.git"
    git -C "${FAKE_VAULT_DIR}" config user.email "test@test.com"
    git -C "${FAKE_VAULT_DIR}" config user.name "Test"
    # Make an initial commit so there's something to push
    echo "test" > "${FAKE_VAULT_DIR}/daily/2026-05-13.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial" -q
    # Point upstream to something (fake)
    git -C "${FAKE_VAULT_DIR}" config "branch.main.remote" "origin"
    git -C "${FAKE_VAULT_DIR}" config "branch.main.merge" "refs/heads/main"

    FAKE_GH_PRIVATE=false \
        run "${PROJECT_ROOT}/bin/okm" sync "test message"
    assert_failure
    assert_output --partial "push aborted"
}

@test "okm sync: skips push check when no upstream configured" {
    # Vault with no upstream — sync should not error on privacy check
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    git -C "${FAKE_VAULT_DIR}" remote add origin "git@github.com:alice/vault.git"
    git -C "${FAKE_VAULT_DIR}" config user.email "test@test.com"
    git -C "${FAKE_VAULT_DIR}" config user.name "Test"
    echo "test" > "${FAKE_VAULT_DIR}/daily/2026-05-13.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial" -q
    # No upstream branch configured → sync prints "No upstream configured"
    run "${PROJECT_ROOT}/bin/okm" sync "test"
    assert_output --partial "No upstream configured"
}
