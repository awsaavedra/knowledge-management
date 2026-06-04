#!/usr/bin/env bats
# Tests for scripts/lib/privacy.sh, scripts/check-no-vault-content.sh, the
# tracked pre-push privacy guard (scripts/hooks/pre-push), its setup-km.sh
# activation, and okm sync privacy enforcement.

load 'helpers/test_helper'

ZERO=0000000000000000000000000000000000000000

# Build a one-commit git repo containing the given relative paths and print its
# HEAD sha. Used to feed real trees to the pre-push hook.
_make_commit() {
    local repo="$1"; shift
    mkdir -p "$repo"
    git -C "$repo" init -b main -q
    git -C "$repo" config user.email t@t.com
    git -C "$repo" config user.name T
    local p
    for p in "$@"; do
        mkdir -p "$repo/$(dirname "$p")"
        echo content > "$repo/$p"
    done
    git -C "$repo" add -A
    git -C "$repo" commit -qm init
    git -C "$repo" rev-parse HEAD
}

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
# km_path_is_vault_content
# ---------------------------------------------------------------------------

@test "km_path_is_vault_content: public daily note is vault content" {
    run km_path_is_vault_content "public/daily/2026-05-13.md"
    assert_success
}

@test "km_path_is_vault_content: public inbox note is vault content" {
    run km_path_is_vault_content "public/inbox/my-note.md"
    assert_success
}

@test "km_path_is_vault_content: private daily note is vault content" {
    run km_path_is_vault_content "private/daily/2026-05-13.md"
    assert_success
}

@test "km_path_is_vault_content: private inbox note is vault content" {
    run km_path_is_vault_content "private/inbox/secret.md"
    assert_success
}

@test "km_path_is_vault_content: public attachment is vault content" {
    run km_path_is_vault_content "public/attachments/screenshot.png"
    assert_success
}

@test "km_path_is_vault_content: private attachment is vault content" {
    run km_path_is_vault_content "private/attachments/scan.pdf"
    assert_success
}

@test "km_path_is_vault_content: inbox template is shareable" {
    run km_path_is_vault_content "public/inbox/templates/daily-template.md"
    assert_failure
}

@test "km_path_is_vault_content: .gitkeep placeholder is shareable" {
    run km_path_is_vault_content "private/daily/.gitkeep"
    assert_failure
}

@test "km_path_is_vault_content: tool file is shareable" {
    run km_path_is_vault_content "bin/okm"
    assert_failure
}

# ---------------------------------------------------------------------------
# km_repo_is_public_tool
# ---------------------------------------------------------------------------

@test "km_repo_is_public_tool: SSH tool repo is the public tool" {
    run km_repo_is_public_tool "git@github.com:alice/knowledge-management.git"
    assert_success
}

@test "km_repo_is_public_tool: HTTPS tool repo is the public tool" {
    run km_repo_is_public_tool "https://github.com/bob/knowledge-management"
    assert_success
}

@test "km_repo_is_public_tool: contribution fork is still the public tool" {
    run km_repo_is_public_tool "git@github.com:alice-km-contrib/knowledge-management.git"
    assert_success
}

@test "km_repo_is_public_tool: personal vault is NOT the public tool" {
    run km_repo_is_public_tool "git@github.com:alice/alice-knowledge-management.git"
    assert_failure
}

@test "km_repo_is_public_tool: non-GitHub remote is NOT the public tool" {
    run km_repo_is_public_tool "https://gitlab.com/alice/knowledge-management.git"
    assert_failure
}

@test "km_repo_is_public_tool: empty URL is NOT the public tool" {
    run km_repo_is_public_tool ""
    assert_failure
}

# ---------------------------------------------------------------------------
# check-no-vault-content.sh — pipeline checker
# ---------------------------------------------------------------------------

@test "check-no-vault-content: clean path list exits 0 with no output" {
    run bash -c "printf 'bin/okm\ndocs/x.md\npublic/inbox/templates/t.md\n' | '${PROJECT_ROOT}/scripts/check-no-vault-content.sh'"
    assert_success
    assert_output ""
}

@test "check-no-vault-content: vault content exits 1 and lists offenders" {
    run bash -c "printf 'bin/okm\nprivate/daily/secret.md\npublic/attachments/x.png\n' | '${PROJECT_ROOT}/scripts/check-no-vault-content.sh'"
    assert_failure
    assert_line "private/daily/secret.md"
    assert_line "public/attachments/x.png"
}

@test "check-no-vault-content: --quiet suppresses the listing" {
    run bash -c "printf 'private/daily/secret.md\n' | '${PROJECT_ROOT}/scripts/check-no-vault-content.sh' --quiet"
    assert_failure
    assert_output ""
}

@test "check-no-vault-content: unknown argument is a usage error" {
    run bash -c "printf 'bin/okm\n' | '${PROJECT_ROOT}/scripts/check-no-vault-content.sh' --bogus"
    [ "$status" -eq 2 ]
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
    funcs_src="$(sed -n '1,/^# --- Install steps ---/p' "${PROJECT_ROOT}/scripts/setup-km.sh" \
        | sed 's/^set -euo pipefail/set +e; set -uo pipefail/' \
        | grep -v '^mkdir -p "\${LOG_DIR}"' \
        | grep -v "^trap ")"
    eval "$funcs_src"
}

@test "install_vault_privacy_hook: points core.hooksPath at scripts/hooks" {
    git -C "${FAKE_VAULT_DIR}" init -b main -q
    _load_setup_km_functions
    install_vault_privacy_hook "${FAKE_VAULT_DIR}"
    run git -C "${FAKE_VAULT_DIR}" config core.hooksPath
    assert_success
    assert_output "scripts/hooks"
}

@test "install_vault_privacy_hook: tracked pre-push hook is valid bash" {
    run bash -n "${PROJECT_ROOT}/scripts/hooks/pre-push"
    assert_success
}

@test "install_vault_privacy_hook: skips gracefully when vault is not a git repo" {
    _load_setup_km_functions
    run install_vault_privacy_hook "${FAKE_VAULT_DIR}"
    assert_success
    assert_output --partial "WARN"
}

# ---------------------------------------------------------------------------
# Pre-push guard behaviour (real trees via scripts/hooks/pre-push)
# ---------------------------------------------------------------------------

@test "pre-push guard: blocks vault content to the tool repo (deterministic, no gh)" {
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "bin/feature" "private/daily/secret.md")"
    cd "$repo"
    run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        upstream "git@github.com:someone/knowledge-management.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_failure
    assert_output --partial "private/daily/secret.md"
}

@test "pre-push guard: tool repo blocks even if gh would call it private" {
    _setup_fake_gh
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "public/inbox/leak.md")"
    cd "$repo"
    FAKE_GH_PRIVATE=true run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        upstream "git@github.com:someone/knowledge-management.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_failure
    assert_output --partial "public/inbox/leak.md"
}

@test "pre-push guard: allows a tooling-only push to the tool repo" {
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "bin/feature" "docs/guide.md" "public/inbox/templates/t.md")"
    cd "$repo"
    run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        upstream "git@github.com:someone/knowledge-management.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_success
}

@test "pre-push guard: allows vault content to your own private vault repo" {
    _setup_fake_gh
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "private/daily/secret.md")"
    cd "$repo"
    FAKE_GH_PRIVATE=true run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        origin "git@github.com:someone/someone-knowledge-management.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_success
}

@test "pre-push guard: blocks vault content to an accidentally-public vault repo" {
    _setup_fake_gh
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "public/daily/2026-05-13.md")"
    cd "$repo"
    FAKE_GH_PRIVATE=false run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        origin "git@github.com:someone/someone-knowledge-management.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_failure
    assert_output --partial "public/daily/2026-05-13.md"
}

@test "pre-push guard: allows a content-free push to a non-GitHub remote" {
    local repo="${TEST_TEMP_DIR}/r" sha
    sha="$(_make_commit "$repo" "bin/feature")"
    cd "$repo"
    run bash "${PROJECT_ROOT}/scripts/hooks/pre-push" \
        origin "https://gitlab.com/someone/vault.git" \
        <<< "refs/heads/main ${sha} refs/heads/main ${ZERO}"
    assert_success
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
    mkdir -p "${FAKE_VAULT_DIR}/public/daily"
    echo "test" > "${FAKE_VAULT_DIR}/public/daily/2026-05-13.md"
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
    mkdir -p "${FAKE_VAULT_DIR}/public/daily"
    echo "test" > "${FAKE_VAULT_DIR}/public/daily/2026-05-13.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial" -q
    # No upstream branch configured → sync prints "No upstream configured"
    run "${PROJECT_ROOT}/bin/okm" sync "test"
    assert_output --partial "No upstream configured"
}
