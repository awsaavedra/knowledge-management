#!/usr/bin/env bats
# Tests for scripts/seed-demo.sh — seed the public PARA folders with demo-*
# files derived from inbox/templates/, and tear them down with --teardown.

load 'helpers/test_helper'

setup() {
    common_setup

    # Copy templates into the fake project so seed-demo can find them.
    mkdir -p "${FAKE_PROJECT_DIR}/inbox/templates"
    cp -r "${PROJECT_ROOT}/inbox/templates/." "${FAKE_PROJECT_DIR}/inbox/templates/"

    # Copy the script into the fake scripts/ dir so its KM_ROOT detection
    # resolves to FAKE_PROJECT_DIR (one level up from scripts/).
    cp "${PROJECT_ROOT}/scripts/seed-demo.sh" "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    chmod +x "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"

    # Point the script at the fake vault.
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
}

# Returns the count of demo-* files under the fake vault's PARA folders.
demo_count() {
    find "${FAKE_VAULT_DIR}" \
        \( -path '*/daily/demo-*' \
        -o -path '*/inbox/demo-*' \
        -o -path '*/attachments/demo-*' \
        -o -path '*/archive/demo-*' \) \
        -type f 2>/dev/null | wc -l
}

@test "seed-demo.sh --help prints usage and exits 0" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --help
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'Usage: seed-demo.sh'
    echo "$output" | grep -q '\-\-teardown'
}

@test "seed-demo.sh -h is the same as --help" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" -h
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'Usage: seed-demo.sh'
}

@test "seed-demo.sh (default) writes 11 demo-* files into the public PARA" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    [ "$status" -eq 0 ]
    [ "$(demo_count)" -eq 11 ]
}

@test "seed-demo.sh prints a verification checklist after seeding" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    echo "$output" | grep -q 'Verify it works'
    echo "$output" | grep -q 'okm files demo-'
    echo "$output" | grep -q '\-\-teardown'
}

@test "seed-demo.sh seeds files in every PARA folder" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    [ -n "$(find "${FAKE_VAULT_DIR}/daily"       -maxdepth 1 -name 'demo-*' -type f 2>/dev/null)" ]
    [ -n "$(find "${FAKE_VAULT_DIR}/inbox"       -maxdepth 1 -name 'demo-*' -type f 2>/dev/null)" ]
    [ -n "$(find "${FAKE_VAULT_DIR}/attachments" -maxdepth 1 -name 'demo-*' -type f 2>/dev/null)" ]
    [ -n "$(find "${FAKE_VAULT_DIR}/archive"     -maxdepth 1 -name 'demo-*' -type f 2>/dev/null)" ]
}

@test "seeded files have Format Specification block stripped" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    # No demo file should still contain the Format Specification marker.
    ! grep -l 'Format Specification:' "${FAKE_VAULT_DIR}/inbox/"demo-*.md
}

@test "seeded files have placeholders substituted (no remaining {{}})" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    ! grep -l '{{[A-Z_]*}}' "${FAKE_VAULT_DIR}/inbox/"demo-*.md
    ! grep -l '{{[A-Z_]*}}' "${FAKE_VAULT_DIR}/daily/"demo-*.md
    ! grep -l '{{[A-Z_]*}}' "${FAKE_VAULT_DIR}/archive/"demo-*.md
}

@test "seed-demo.sh is idempotent (re-run keeps count at 11)" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    [ "$(demo_count)" -eq 11 ]
}

@test "seed-demo.sh --teardown removes every demo-* file" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    [ "$(demo_count)" -eq 11 ]
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --teardown
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'Removed 11 demo-\* files'
    [ "$(demo_count)" -eq 0 ]
}

@test "seed-demo.sh --clean is an alias for --teardown" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --clean
    [ "$status" -eq 0 ]
    [ "$(demo_count)" -eq 0 ]
}

@test "teardown does NOT remove non-demo files" {
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh"
    # Sentinel: a real (non-demo) note in inbox/.
    echo "real note" > "${FAKE_VAULT_DIR}/inbox/real-note.md"
    bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --teardown
    [ -f "${FAKE_VAULT_DIR}/inbox/real-note.md" ]
}

@test "seed-demo.sh on empty vault prints zero removed (clean run)" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --teardown
    [ "$status" -eq 0 ]
    echo "$output" | grep -q 'Removed 0 demo-\* files'
}

@test "seed-demo.sh rejects unknown args with usage and non-zero exit" {
    run bash "${FAKE_PROJECT_DIR}/scripts/seed-demo.sh" --bogus
    [ "$status" -ne 0 ]
    echo "$output" | grep -q 'Usage: seed-demo.sh'
}
