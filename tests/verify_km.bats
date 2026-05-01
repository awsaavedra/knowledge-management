#!/usr/bin/env bats
# Tests for verify-km.sh — output format, exit codes, PASS/FAIL/WARN logic.

load 'helpers/test_helper'

setup() {
    common_setup
}

@test "verify-km.sh is valid bash" {
    run bash -n "${PROJECT_ROOT}/verify-km.sh"
    assert_success
}

@test "output includes PASS/FAIL/WARN prefixes" {
    # Run verify against fake HOME — many checks will fail, which is expected
    run bash "${PROJECT_ROOT}/verify-km.sh"
    # Should contain at least one [PASS] (system packages like git, rg are installed)
    echo "$output" | grep -q '\[PASS\]'
    # Should contain at least one [FAIL] (vault dir doesn't exist in fake HOME context)
    echo "$output" | grep -q '\[FAIL\]'
}

@test "summary line shows counts" {
    run bash "${PROJECT_ROOT}/verify-km.sh"
    echo "$output" | grep -q 'PASS:'
    echo "$output" | grep -q 'FAIL:'
    echo "$output" | grep -q 'WARN:'
}

@test "exits 1 when any FAIL check triggers" {
    # With fake HOME and no vault, there will be FAILs
    run bash "${PROJECT_ROOT}/verify-km.sh"
    assert_failure
}

@test "verify checks project binaries in SCRIPT_DIR/bin not ~/bin" {
    # verify-km.sh should reference SCRIPT_DIR/bin, not HOME/bin
    grep -q 'SCRIPT_DIR.*bin' "${PROJECT_ROOT}/verify-km.sh"
    ! grep -q 'HOME.*bin.*nvim\|HOME.*bin.*okm' "${PROJECT_ROOT}/verify-km.sh" || \
        grep 'HOME.*bin' "${PROJECT_ROOT}/verify-km.sh" | grep -qv 'BIN_DIR'
}

# === Neovim installation checks ===

@test "verify checks nvim.bin binary exists" {
    grep -q 'nvim\.bin' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify checks nvim runtime directory" {
    grep -q 'nvim-runtime/share/nvim/runtime' "${PROJECT_ROOT}/verify-km.sh"
    grep -q 'syntax/syntax.vim' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify checks nvim version >= 0.10" {
    grep -q 'nvim_minor' "${PROJECT_ROOT}/verify-km.sh"
    grep -q '0\.10' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify checks nvim headless startup for runtime errors" {
    grep -q 'E484' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify reports PASS for nvim installation when present" {
    run bash "${PROJECT_ROOT}/verify-km.sh"
    echo "$output" | grep -q '\[PASS\].*nvim.bin binary present'
    echo "$output" | grep -q '\[PASS\].*nvim runtime present'
    echo "$output" | grep -q '\[PASS\].*nvim version'
    echo "$output" | grep -q '\[PASS\].*nvim headless startup OK'
}

# === Nerd Font checks ===

@test "verify checks for Nerd Font installation" {
    grep -q 'Nerd Font' "${PROJECT_ROOT}/verify-km.sh"
    grep -q 'JetBrainsMonoNerdFont-Regular.ttf' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify Nerd Font check handles WSL2 and native Linux" {
    grep -q 'is_wsl2' "${PROJECT_ROOT}/verify-km.sh"
    grep -q 'Library/Fonts' "${PROJECT_ROOT}/verify-km.sh"
    grep -q '\.local/share/fonts' "${PROJECT_ROOT}/verify-km.sh"
}

@test "verify reports PASS for Nerd Font when installed" {
    grep -qi 'microsoft' /proc/version 2>/dev/null || skip "not WSL2"
    run bash "${PROJECT_ROOT}/verify-km.sh"
    echo "$output" | grep -q '\[PASS\].*Nerd Font'
}
