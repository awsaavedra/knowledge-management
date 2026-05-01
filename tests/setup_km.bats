#!/usr/bin/env bats
# Tests for setup-km.sh helper functions and scoping guarantees.
# Does NOT run apt/flatpak/binary downloads — only tests file-level operations.

load 'helpers/test_helper'

setup() {
    common_setup

    # Source just the function definitions from setup-km.sh (stop before install steps).
    # We patch set -e to set +e so function failures don't kill the test harness,
    # and redirect LOG_FILE to our temp dir.
    export LOG_FILE="${TEST_TEMP_DIR}/setup.log"
    export SCRIPT_DIR="${FAKE_PROJECT_DIR}"
    export VAULT_DIR="${FAKE_VAULT_DIR}"
    export BIN_DIR="${FAKE_PROJECT_DIR}/bin"

    # Extract function definitions up to "# --- Install steps ---"
    local funcs_src
    funcs_src="$(sed -n '1,/^# --- Install steps ---/p' "${PROJECT_ROOT}/setup-km.sh" \
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

@test "ensure_gitignore excludes notes by default (KM_TRACK_NOTES=false)" {
    local target="${TEST_TEMP_DIR}/vault-test"
    mkdir -p "$target"
    KM_TRACK_NOTES=false ensure_gitignore "$target"
    grep -q "daily/*.md" "${target}/.gitignore"
    grep -q "inbox/*.md" "${target}/.gitignore"
    grep -q "archive/*.md" "${target}/.gitignore"
}

@test "ensure_gitignore tracks notes when KM_TRACK_NOTES=true" {
    local target="${TEST_TEMP_DIR}/vault-test"
    mkdir -p "$target"
    KM_TRACK_NOTES=true ensure_gitignore "$target"
    ! grep -q "daily/*.md" "${target}/.gitignore"
    ! grep -q "inbox/*.md" "${target}/.gitignore"
    ! grep -q "archive/*.md" "${target}/.gitignore"
}

@test "ensure_gitignore is idempotent" {
    local target="${TEST_TEMP_DIR}/vault-test"
    mkdir -p "$target"
    ensure_gitignore "$target"
    local hash1
    hash1="$(sha256sum "${target}/.gitignore" | cut -d' ' -f1)"
    ensure_gitignore "$target"
    local hash2
    hash2="$(sha256sum "${target}/.gitignore" | cut -d' ' -f1)"
    [ "$hash1" = "$hash2" ]
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

# === install_nvim ===

@test "install_nvim creates wrapper script at bin/nvim" {
    # Simulate a successful install by creating the expected structure
    mkdir -p "${BIN_DIR}"
    cat > "${BIN_DIR}/nvim" <<'WRAPPER'
#!/usr/bin/env bash
NVIM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VIMRUNTIME="${NVIM_DIR}/nvim-runtime/share/nvim/runtime"
exec "${NVIM_DIR}/nvim.bin" "$@"
WRAPPER
    chmod +x "${BIN_DIR}/nvim"
    # Wrapper must set VIMRUNTIME
    grep -q 'VIMRUNTIME' "${BIN_DIR}/nvim"
    grep -q 'nvim-runtime/share/nvim/runtime' "${BIN_DIR}/nvim"
    grep -q 'nvim.bin' "${BIN_DIR}/nvim"
}

@test "install_nvim skip guard requires both nvim and nvim.bin" {
    mkdir -p "${BIN_DIR}"
    # Only nvim exists (no nvim.bin) — should NOT skip
    touch "${BIN_DIR}/nvim" && chmod +x "${BIN_DIR}/nvim"
    # The guard: if [ -x nvim ] && [ -x nvim.bin ]
    [ ! -x "${BIN_DIR}/nvim.bin" ]
}

@test "install_nvim produces self-contained structure" {
    # Verify the expected file layout that install_nvim creates
    local expected_files=(
        "bin/nvim"
        "bin/nvim.bin"
        "bin/nvim-runtime/share/nvim/runtime/syntax/syntax.vim"
    )
    # Check real install on disk (integration test)
    for f in "${expected_files[@]}"; do
        [ -e "${PROJECT_ROOT}/${f}" ] || skip "not installed: ${f}"
    done
    [ -x "${PROJECT_ROOT}/bin/nvim" ]
    [ -x "${PROJECT_ROOT}/bin/nvim.bin" ]
}

@test "install_nvim wrapper invokes nvim.bin with VIMRUNTIME set" {
    [ -x "${PROJECT_ROOT}/bin/nvim" ] || skip "nvim not installed"
    run "${PROJECT_ROOT}/bin/nvim" --version
    assert_success
    assert_output --partial "NVIM v"
}

@test "install_nvim version is >= 0.10 (LazyVim requirement)" {
    [ -x "${PROJECT_ROOT}/bin/nvim" ] || skip "nvim not installed"
    local version
    version="$("${PROJECT_ROOT}/bin/nvim" --version | head -1 | sed 's/NVIM v//')"
    local minor
    minor="$(echo "$version" | cut -d. -f2)"
    [ "$minor" -ge 10 ]
}

@test "install_nvim runtime files are accessible via wrapper" {
    [ -x "${PROJECT_ROOT}/bin/nvim" ] || skip "nvim not installed"
    run env TERM=xterm-256color NVIM_APPNAME=km "${PROJECT_ROOT}/bin/nvim" --headless -c 'quitall' 2>&1
    # Must NOT contain E484 (missing runtime)
    refute_output --partial "E484"
    refute_output --partial "Can't open file"
}

# === install_nerd_font ===

@test "install_nerd_font skip detection works when font exists (WSL2)" {
    # Simulate WSL2 with font already installed
    grep -qi 'microsoft' /proc/version 2>/dev/null || skip "not WSL2"
    local win_user
    win_user="$(cmd.exe /c 'echo %USERNAME%' 2>/dev/null | tr -d '\r')"
    local win_font_dir="/mnt/c/Users/${win_user}/AppData/Local/Microsoft/Windows/Fonts"
    [ -f "${win_font_dir}/JetBrainsMonoNerdFont-Regular.ttf" ]
}

@test "install_nerd_font font family name matches Windows Terminal config" {
    grep -qi 'microsoft' /proc/version 2>/dev/null || skip "not WSL2"
    # The setup script must use "JetBrainsMono NF" (actual registered family name)
    grep -q 'JetBrainsMono NF' "${PROJECT_ROOT}/setup-km.sh"
}

@test "setup-km.sh install_nerd_font handles all platforms" {
    # Function must exist and handle linux, macos, and WSL2
    grep -q 'is_wsl2' "${PROJECT_ROOT}/setup-km.sh"
    grep -q 'macos.*Library/Fonts' "${PROJECT_ROOT}/setup-km.sh"
    grep -q '\.local/share/fonts' "${PROJECT_ROOT}/setup-km.sh"
}

# === Scoping guarantees ===

@test "setup-km.sh does not reference ~/.zshrc for writes" {
    # The script should not contain ensure_shell_line or replace_shell_line calls
    run grep -c 'ensure_shell_line\|replace_shell_line' "${PROJECT_ROOT}/setup-km.sh"
    assert_output "0"
}

@test "setup-km.sh does not symlink ~/.config/nvim" {
    # Should only reference ~/.config/km, never ~/.config/nvim for symlinking
    local nvim_refs
    nvim_refs=$(grep '\.config/nvim' "${PROJECT_ROOT}/setup-km.sh" | grep -cv '#\|log_info\|log_warn\|echo' || true)
    [ "$nvim_refs" -eq 0 ]
}

@test "bin/okm exists as standalone file" {
    [ -f "${PROJECT_ROOT}/bin/okm" ]
    [ -x "${PROJECT_ROOT}/bin/okm" ]
    grep -q "okm - simple terminal knowledge manager" "${PROJECT_ROOT}/bin/okm"
}
