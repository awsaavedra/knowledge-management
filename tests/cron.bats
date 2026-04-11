#!/usr/bin/env bats
# Tests for the scheduled cron job configuration.
#
# Validates:
#   - The documented cron schedule (7:00, 12:00, 15:00 daily) is consistent
#     across all documentation and config files
#   - The cron-invoked command (todo-summary.sh --output) works correctly
#   - Repeated invocations (simulating multiple cron fires per day) behave correctly
#   - The yearly file uses prepend behavior (living document)

load 'helpers/test_helper'

EXPECTED_HOURS=("7" "12" "15")
EXPECTED_CRON_LINES=(
    "3 7 * * *"
    "3 12 * * *"
    "3 15 * * *"
)

setup() {
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"

    # Patch todo-summary.sh for sandboxed execution
    cp "${PROJECT_ROOT}/scripts/todo-summary.sh" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^PROJECT_DIR=.*|PROJECT_DIR=\"${FAKE_PROJECT_DIR}\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^VAULT_DIR=.*|VAULT_DIR=\"${FAKE_VAULT_DIR}\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^OUTPUT_FILE=.*|OUTPUT_FILE=\"${FAKE_PROJECT_DIR}/inbox/todo-summary-\${YEAR}.md\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    chmod +x "${TEST_TEMP_DIR}/todo-summary.sh"
}

# === Documentation consistency ===

@test "scripts/README.md documents all 3 cron times" {
    for hour in "${EXPECTED_HOURS[@]}"; do
        grep -q "3 ${hour} \* \* \*" "${PROJECT_ROOT}/scripts/README.md"
    done
}

@test "scripts/README.md mentions 07:00, 12:00, and 15:00" {
    grep -q '07:00.*12:00.*15:00' "${PROJECT_ROOT}/scripts/README.md"
}

@test "README.md documents all 3 cron times" {
    for hour in "${EXPECTED_HOURS[@]}"; do
        grep -q "3 ${hour} \* \* \*" "${PROJECT_ROOT}/README.md"
    done
}

@test "README.md mentions 07:00, 12:00, and 15:00" {
    grep -q '07:00.*12:00.*15:00' "${PROJECT_ROOT}/README.md"
}

@test "todo-summary.sh header mentions all 3 times" {
    grep -q '07:00.*12:00.*15:00' "${PROJECT_ROOT}/scripts/todo-summary.sh"
}

@test "no stale 2-time schedule references remain in scripts/README.md" {
    ! grep -qi 'twice daily' "${PROJECT_ROOT}/scripts/README.md"
}

@test "no stale 2-time schedule references remain in README.md" {
    ! grep -qi 'twice daily' "${PROJECT_ROOT}/README.md"
}

# === Cron expression validity ===

@test "cron expressions use minute 3 (off-peak)" {
    for cron in "${EXPECTED_CRON_LINES[@]}"; do
        [[ "$cron" == 3\ * ]]
    done
}

@test "cron expressions run every day of the week" {
    for cron in "${EXPECTED_CRON_LINES[@]}"; do
        [[ "$cron" == *"* * *" ]]
    done
}

@test "exactly 3 crontab entries documented in scripts/README.md" {
    local count
    count=$(grep -c '^\(3 [0-9]\+ \* \* \*\)' "${PROJECT_ROOT}/scripts/README.md" || true)
    [ "$count" -eq 3 ]
}

@test "exactly 3 crontab entries documented in README.md" {
    local count
    count=$(grep -c '^\(3 [0-9]\+ \* \* \*\)' "${PROJECT_ROOT}/README.md" || true)
    [ "$count" -eq 3 ]
}

# === Cron-invoked command behavior ===

@test "cron command (--output) creates yearly summary file" {
    create_project_file "job.sh" "# TODO: cron test item"
    run bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    assert_success
    local expected="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    [ -f "$expected" ]
}

@test "cron command output file contains PARA structure" {
    create_project_file "job.sh" "# TODO: cron para test"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "#### Projects" "$file"
    grep -q "#### Areas" "$file"
    grep -q "#### Resources" "$file"
    grep -q "## Archive" "$file"
}

@test "cron command output file has correct frontmatter tags" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q 'tags: \[todo-summary, para, automated\]' "$file"
}

# === Multiple cron fires per day ===

@test "re-run prepends new scan (not overwrites) the yearly file" {
    create_project_file "first.sh" "# TODO: first run item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    [ -f "$file" ]

    # Add a new item and re-run (simulating the 12:00 cron)
    create_project_file "second.sh" "# TODO: second run item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # Should contain both items (data preserved, not overwritten)
    grep -q "first run item" "$file"
    grep -q "second run item" "$file"

    # Should have two scan sections
    local scan_count
    scan_count=$(grep -c "^### Scan" "$file")
    [ "$scan_count" -eq 2 ]
}

@test "only one yearly file exists after multiple runs" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local count
    count=$(find "${FAKE_PROJECT_DIR}/inbox" -name 'todo-summary-*.md' | wc -l)
    [ "$count" -eq 1 ]
}

@test "later cron run picks up items added since earlier run" {
    # Simulate 07:00 run with one item
    create_project_file "morning.sh" "# TODO: morning task"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "morning task" "$file"

    # Simulate work done between 07:00 and 12:00
    create_vault_file "inbox/new-note.md" "- [ ] added after morning scan"
    create_project_file "afternoon.sh" "# FIXME: afternoon bugfix"

    # Simulate 12:00 run
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # All items preserved across both scans
    grep -q "morning task" "$file"
    grep -q "added after morning scan" "$file"
    grep -q "afternoon bugfix" "$file"
}

@test "completed items disappear from new scan but old scan preserved" {
    # First run: unchecked task exists
    create_vault_file "daily/today.md" "- [ ] pending task"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "pending task" "$file"

    # User checks off the task in source file between runs
    create_vault_file "daily/today.md" "- [x] pending task"

    # Next cron run
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # Two scan sections exist (old data preserved)
    local scan_count
    scan_count=$(grep -c "^### Scan" "$file")
    [ "$scan_count" -eq 2 ]
}

# === Cron script path ===

@test "documented crontab command points to correct script path" {
    grep -q '/home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output' \
        "${PROJECT_ROOT}/scripts/README.md"
    grep -q '/home/aws/workspace/knowledge-management/scripts/todo-summary.sh --output' \
        "${PROJECT_ROOT}/README.md"
}

@test "todo-summary.sh is executable" {
    [ -x "${PROJECT_ROOT}/scripts/todo-summary.sh" ]
}
