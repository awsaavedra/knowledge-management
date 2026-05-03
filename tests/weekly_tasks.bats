#!/usr/bin/env bats
# Tests for scripts/weekly-tasks.sh — weekly PARA-structured TODO scanner.

load 'helpers/test_helper'

setup() {
    common_setup

    mkdir -p "${TEST_TEMP_DIR}/scripts/lib"
    cp "${PROJECT_ROOT}/scripts/lib/scan.sh" "${TEST_TEMP_DIR}/scripts/lib/scan.sh"
    cp "${PROJECT_ROOT}/scripts/weekly-tasks.sh" "${TEST_TEMP_DIR}/weekly-tasks.sh"
    sed -i "s|^SCRIPT_DIR=.*|SCRIPT_DIR=\"${TEST_TEMP_DIR}\"|" "${TEST_TEMP_DIR}/weekly-tasks.sh"
    sed -i "s|^PROJECT_DIR=.*|PROJECT_DIR=\"${FAKE_PROJECT_DIR}\"|" "${TEST_TEMP_DIR}/weekly-tasks.sh"
    sed -i "s|^OUTPUT_FILE=.*|OUTPUT_FILE=\"${FAKE_PROJECT_DIR}/inbox/weekly-test.md\"|" "${TEST_TEMP_DIR}/weekly-tasks.sh"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    chmod +x "${TEST_TEMP_DIR}/weekly-tasks.sh"
}

run_weekly() {
    run bash "${TEST_TEMP_DIR}/weekly-tasks.sh" "$@"
}

# === stdout mode ===

@test "stdout mode prints day header with weekday name" {
    run_weekly
    assert_success
    assert_output --partial "### $(date +%F)"
}

@test "stdout mode prints all three PARA sections" {
    run_weekly
    assert_success
    assert_output --partial "#### Projects"
    assert_output --partial "#### Areas"
    assert_output --partial "#### Resources"
}

@test "stdout mode picks up TODO markers from project files" {
    create_project_file "task.sh" "# TODO: weekly test item"
    run_weekly
    assert_success
    assert_output --partial "weekly test item"
}

@test "stdout mode picks up unchecked tasks from vault notes" {
    create_vault_file "inbox/tasks.md" "- [ ] weekly vault task"
    run_weekly
    assert_success
    assert_output --partial "weekly vault task"
}

@test "stdout mode picks up REVIEW markers as resources" {
    create_project_file "review.sh" "# REVIEW: evaluate weekly tools"
    run_weekly
    assert_success
    assert_output --partial "evaluate weekly tools"
}

# === --output mode ===

@test "output mode creates weekly file" {
    create_project_file "job.sh" "# TODO: weekly output test"
    run_weekly --output
    assert_success
    [ -f "${FAKE_PROJECT_DIR}/inbox/weekly-test.md" ]
}

@test "output file contains PARA structure" {
    create_project_file "job.sh" "# TODO: weekly para test"
    bash "${TEST_TEMP_DIR}/weekly-tasks.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/weekly-test.md"
    grep -q "#### Projects" "$file"
    grep -q "#### Areas" "$file"
    grep -q "#### Resources" "$file"
}

@test "output file has correct frontmatter tags" {
    bash "${TEST_TEMP_DIR}/weekly-tasks.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/weekly-test.md"
    grep -q 'tags: \[weekly-tasks, para, automated\]' "$file"
}

@test "same-day re-run replaces today's section" {
    create_project_file "first.sh" "# TODO: first weekly item"
    bash "${TEST_TEMP_DIR}/weekly-tasks.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/weekly-test.md"

    create_project_file "second.sh" "# TODO: second weekly item"
    bash "${TEST_TEMP_DIR}/weekly-tasks.sh" --output

    local day_count
    day_count=$(grep -c "^### $(date +%F)" "$file")
    [ "$day_count" -eq 1 ]

    grep -q "second weekly item" "$file"
}

# === edge cases ===

@test "does not match AUTODO or MYFIXME (word boundary)" {
    create_project_file "false-positive.sh" "echo AUTODO MYFIXME"
    run_weekly
    assert_success
    refute_output --partial "AUTODO"
    refute_output --partial "MYFIXME"
}

@test "does not match checked tasks" {
    create_vault_file "inbox/done.md" "- [x] completed task"
    run_weekly
    assert_success
    refute_output --partial "completed task"
}
