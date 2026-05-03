#!/usr/bin/env bats
# Tests for install_direnv() in setup-km.sh.
#
# This file does NOT use the eval-based setup() from setup_km.bats because that
# pattern runs `set +e`, which masks command-not-found and produces false passes.
# Instead, each test that calls install_direnv spawns a fresh bash -euo pipefail
# subprocess with a stub direnv on PATH.

load 'helpers/test_helper'

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    common_setup
    export LOG_FILE="${TEST_TEMP_DIR}/setup.log"
}

# Helper: run install_direnv from setup-km.sh in an isolated subprocess.
# Uses env-var injection + single-quoted body to avoid quoting/expansion bugs.
# $1 = fake HOME   $2 = fake SCRIPT_DIR   $3 = stub bin dir (contains fake direnv)
_run_install_direnv() {
    local fake_home="$1" fake_script_dir="$2" stub_bin="$3"
    _ID_HOME="$fake_home" \
    _ID_SCRIPT="$fake_script_dir" \
    _ID_STUB="$stub_bin" \
    _ID_PROJ="$PROJECT_ROOT" \
    bash -euo pipefail -c '
        LOG_FILE=/dev/null
        log_info()  { :; }
        log_warn()  { :; }
        log_error() { :; }
        HOME="$_ID_HOME"
        SCRIPT_DIR="$_ID_SCRIPT"
        PATH="$_ID_STUB:$PATH"
        touch "$_ID_SCRIPT/.envrc"
        eval "$(sed -n "/^install_direnv()/,/^}/p" "$_ID_PROJ/setup-km.sh")"
        install_direnv
    '
}

# --- Static checks (no subprocess needed) ---

@test "install_direnv function exists in setup-km.sh" {
    grep -q '^install_direnv()' "${PROJECT_ROOT}/setup-km.sh"
}

@test "setup-km.sh calls install_direnv in the install steps section" {
    sed -n '/^# --- Install steps ---/,$p' "${PROJECT_ROOT}/setup-km.sh" \
        | grep -q 'install_direnv'
}

@test ".envrc sources env.sh via source_env" {
    grep -q 'source_env env.sh' "${PROJECT_ROOT}/.envrc"
}

@test "install_direnv only writes to ~/.bashrc not ~/.zshrc" {
    # Extract install_direnv body and check it targets only ~/.bashrc
    local fn_body
    fn_body="$(sed -n '/^install_direnv()/,/^}/p' "${PROJECT_ROOT}/setup-km.sh")"
    echo "$fn_body" | grep -q '\.bashrc'
    ! echo "$fn_body" | grep -q '\.zshrc'
}

# --- Behavioural checks via subprocess ---

@test "install_direnv writes direnv hook line to ~/.bashrc" {
    local fh="${TEST_TEMP_DIR}/fh" sb="${TEST_TEMP_DIR}/sb"
    mkdir -p "${fh}" "${sb}"
    touch "${fh}/.bashrc"
    printf '#!/bin/bash\necho fake-direnv\n' > "${sb}/direnv"
    chmod +x "${sb}/direnv"

    run _run_install_direnv "${fh}" "${FAKE_PROJECT_DIR}" "${sb}"
    assert_success
    grep -q 'direnv hook bash' "${fh}/.bashrc"
}

@test "install_direnv hook write is idempotent (no duplicate lines)" {
    local fh="${TEST_TEMP_DIR}/fh2" sb="${TEST_TEMP_DIR}/sb2"
    mkdir -p "${fh}" "${sb}"
    touch "${fh}/.bashrc"
    printf '#!/bin/bash\necho fake-direnv\n' > "${sb}/direnv"
    chmod +x "${sb}/direnv"

    _run_install_direnv "${fh}" "${FAKE_PROJECT_DIR}" "${sb}"
    _run_install_direnv "${fh}" "${FAKE_PROJECT_DIR}" "${sb}"

    local count
    count="$(grep -c 'direnv hook bash' "${fh}/.bashrc")"
    [ "${count}" -eq 1 ]
}

@test "install_direnv does not write anything to ~/.zshrc" {
    local fh="${TEST_TEMP_DIR}/fh3" sb="${TEST_TEMP_DIR}/sb3"
    mkdir -p "${fh}" "${sb}"
    touch "${fh}/.bashrc" "${fh}/.zshrc"
    printf '#!/bin/bash\necho fake-direnv\n' > "${sb}/direnv"
    chmod +x "${sb}/direnv"

    _run_install_direnv "${fh}" "${FAKE_PROJECT_DIR}" "${sb}"

    run grep -c 'direnv' "${fh}/.zshrc"
    assert_output "0"
}

@test "install_direnv skips hook write when already present" {
    local fh="${TEST_TEMP_DIR}/fh4" sb="${TEST_TEMP_DIR}/sb4"
    mkdir -p "${fh}" "${sb}"
    echo 'eval "$(direnv hook bash)"' > "${fh}/.bashrc"
    printf '#!/bin/bash\necho fake-direnv\n' > "${sb}/direnv"
    chmod +x "${sb}/direnv"

    run _run_install_direnv "${fh}" "${FAKE_PROJECT_DIR}" "${sb}"
    assert_success

    local count
    count="$(grep -c 'direnv hook bash' "${fh}/.bashrc")"
    [ "${count}" -eq 1 ]
}
