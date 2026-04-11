#!/usr/bin/env bats
# Tests for verify-kms.sh — output format, exit codes, PASS/FAIL/WARN logic.

load 'helpers/test_helper'

setup() {
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"
}

@test "verify-kms.sh is valid bash" {
    run bash -n "${PROJECT_ROOT}/verify-kms.sh"
    assert_success
}

@test "output includes PASS/FAIL/WARN prefixes" {
    # Run verify against fake HOME — many checks will fail, which is expected
    run bash "${PROJECT_ROOT}/verify-kms.sh"
    # Should contain at least one [PASS] (system packages like git, rg are installed)
    echo "$output" | grep -q '\[PASS\]'
    # Should contain at least one [FAIL] (vault dir doesn't exist in fake HOME context)
    echo "$output" | grep -q '\[FAIL\]'
}

@test "summary line shows counts" {
    run bash "${PROJECT_ROOT}/verify-kms.sh"
    echo "$output" | grep -q 'PASS:'
    echo "$output" | grep -q 'FAIL:'
    echo "$output" | grep -q 'WARN:'
}

@test "exits 1 when any FAIL check triggers" {
    # With fake HOME and no vault, there will be FAILs
    run bash "${PROJECT_ROOT}/verify-kms.sh"
    assert_failure
}

@test "verify checks project binaries in SCRIPT_DIR/bin not ~/bin" {
    # verify-kms.sh should reference SCRIPT_DIR/bin, not HOME/bin
    grep -q 'SCRIPT_DIR.*bin' "${PROJECT_ROOT}/verify-kms.sh"
    ! grep -q 'HOME.*bin.*nvim\|HOME.*bin.*okm' "${PROJECT_ROOT}/verify-kms.sh" || \
        grep 'HOME.*bin' "${PROJECT_ROOT}/verify-kms.sh" | grep -qv 'BIN_DIR'
}
