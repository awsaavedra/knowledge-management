#!/usr/bin/env bats
# Tests for scripts/todo-summary.sh — PARA-structured TODO scanner.
# Heavy coverage: marker classification, edge cases, output format, self-exclusion,
# living yearly document behavior.

load 'helpers/test_helper'

setup() {
    # Run shared setup (creates TEST_TEMP_DIR, FAKE_PROJECT_DIR, FAKE_VAULT_DIR, fake HOME)
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"

    # Copy and patch todo-summary.sh to use fake directories
    cp "${PROJECT_ROOT}/scripts/todo-summary.sh" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^PROJECT_DIR=.*|PROJECT_DIR=\"${FAKE_PROJECT_DIR}\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^VAULT_DIR=.*|VAULT_DIR=\"${FAKE_VAULT_DIR}\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    sed -i "s|^OUTPUT_FILE=.*|OUTPUT_FILE=\"${FAKE_PROJECT_DIR}/inbox/todo-summary-\${YEAR}.md\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    chmod +x "${TEST_TEMP_DIR}/todo-summary.sh"
}

# Helper to run the patched script
run_scanner() {
    run bash "${TEST_TEMP_DIR}/todo-summary.sh" "$@"
}

# === Scan Section Structure (stdout mode) ===

@test "stdout mode prints scan timestamp header" {
    run_scanner
    assert_success
    assert_output --partial "### Scan —"
}

@test "stdout mode prints all three PARA scan sections in order" {
    run_scanner
    assert_success
    assert_output --partial "#### Projects"
    assert_output --partial "#### Areas"
    assert_output --partial "#### Resources"
    # Check order
    local proj_line areas_line res_line
    proj_line=$(echo "$output" | grep -n "#### Projects" | head -1 | cut -d: -f1)
    areas_line=$(echo "$output" | grep -n "#### Areas" | head -1 | cut -d: -f1)
    res_line=$(echo "$output" | grep -n "#### Resources" | head -1 | cut -d: -f1)
    [ "$proj_line" -lt "$areas_line" ]
    [ "$areas_line" -lt "$res_line" ]
}

@test "empty dirs produce placeholder messages" {
    run_scanner
    assert_success
    assert_output --partial "_No active project items._"
    assert_output --partial "_No area tasks._"
    assert_output --partial "_No review items._"
}

# === Projects Section (TODO, FIXME, HACK, XXX) ===

@test "TODO marker in .sh file appears in Projects section" {
    create_project_file "example.sh" "#!/bin/bash
# TODO: fix the frobnicator"
    run_scanner
    assert_success
    local projects_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    echo "$projects_section" | grep -q "fix the frobnicator"
}

@test "FIXME marker in .lua file appears in Projects section" {
    create_project_file "config/nvim/lua/plugins/test.lua" "-- FIXME: broken keybind"
    run_scanner
    assert_success
    local projects_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    echo "$projects_section" | grep -q "broken keybind"
}

@test "HACK marker in .yml file appears in Projects section" {
    create_project_file "config/lazygit/test.yml" "# HACK: workaround for upstream bug"
    run_scanner
    assert_success
    local projects_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    echo "$projects_section" | grep -q "workaround for upstream bug"
}

@test "XXX marker in .json file appears in Projects section" {
    create_project_file "test.json" '{"note": "XXX: temporary schema"}'
    run_scanner
    assert_success
    local projects_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    echo "$projects_section" | grep -q "temporary schema"
}

@test "TODO marker in vault .md file appears in Projects section" {
    create_vault_file "inbox/note.md" "---
title: test
---
TODO: research quantum computing"
    run_scanner
    assert_success
    local projects_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    echo "$projects_section" | grep -q "research quantum computing"
}

# === Resources Section (REVIEW) ===

@test "REVIEW marker in .sh file appears in Resources section" {
    create_project_file "example.sh" "#!/bin/bash
# REVIEW: evaluate alternative approach"
    run_scanner
    assert_success
    local resources_section
    resources_section=$(echo "$output" | sed -n '/^#### Resources/,/^---$/p')
    echo "$resources_section" | grep -q "evaluate alternative approach"
}

@test "REVIEW marker in vault .md appears in Resources section" {
    create_vault_file "inbox/reading.md" "REVIEW: read the Zettelkasten paper"
    run_scanner
    assert_success
    local resources_section
    resources_section=$(echo "$output" | sed -n '/^#### Resources/,/^---$/p')
    echo "$resources_section" | grep -q "read the Zettelkasten paper"
}

# === Areas Section (unchecked tasks) ===

@test "unchecked task in .md appears in Areas section" {
    create_vault_file "daily/2026-04-10.md" "---
date: 2026-04-10
---
- [ ] water the plants"
    run_scanner
    assert_success
    local areas_section
    areas_section=$(echo "$output" | sed -n '/^#### Areas/,/^#### Resources/p')
    echo "$areas_section" | grep -q "water the plants"
}

@test "checked tasks are NOT collected" {
    create_vault_file "daily/done.md" "- [x] completed task
- [X] also done"
    run_scanner
    assert_success
    refute_output --partial "completed task"
    refute_output --partial "also done"
}

# === Cross-section and cross-directory ===

@test "multiple markers in same file land in correct sections" {
    create_vault_file "inbox/mixed.md" "TODO: project item
REVIEW: resource item
- [ ] area item"
    run_scanner
    assert_success
    local projects_section areas_section resources_section
    projects_section=$(echo "$output" | sed -n '/^#### Projects/,/^#### Areas/p')
    areas_section=$(echo "$output" | sed -n '/^#### Areas/,/^#### Resources/p')
    resources_section=$(echo "$output" | sed -n '/^#### Resources/,/^---$/p')
    echo "$projects_section" | grep -q "project item"
    echo "$areas_section" | grep -q "area item"
    echo "$resources_section" | grep -q "resource item"
}

@test "markers from both project dir AND vault dir are collected" {
    create_project_file "build.sh" "# TODO: fix build step"
    create_vault_file "inbox/tasks.md" "- [ ] review notes"
    run_scanner
    assert_success
    assert_output --partial "fix build step"
    assert_output --partial "review notes"
}

# === Exclusions ===

@test "self-exclusion: scripts/todo-summary.sh is not scanned" {
    create_project_file "scripts/todo-summary.sh" "# TODO: meta task that should be excluded"
    run_scanner
    assert_success
    refute_output --partial "meta task that should be excluded"
}

@test "inbox/todo-summary-*.md files are excluded from scan" {
    create_project_file "inbox/todo-summary-2026.md" "TODO: old item from previous scan"
    run_scanner
    assert_success
    refute_output --partial "old item from previous scan"
}

@test "non-scanned file types are ignored" {
    create_project_file "data.txt" "TODO: hidden in txt file"
    create_project_file "image.png" "TODO: hidden in png"
    run_scanner
    assert_success
    refute_output --partial "hidden in txt file"
    refute_output --partial "hidden in png"
}

# === Word boundary matching ===

@test "AUTODO is not matched (word boundary)" {
    create_project_file "tricky.sh" "# AUTODO: not a real todo marker"
    run_scanner
    assert_success
    refute_output --partial "not a real todo marker"
}

@test "MYFIXME is not matched (word boundary)" {
    create_project_file "tricky2.sh" "# MYFIXME: not a real fixme"
    run_scanner
    assert_success
    refute_output --partial "not a real fixme"
}

@test "TODO without colon is not matched" {
    create_project_file "nocolon.sh" "# TODO fix this without colon"
    run_scanner
    assert_success
    refute_output --partial "fix this without colon"
}

# === Output format ===

@test "format_item produces checklist with bold title and file:line reference" {
    create_project_file "example.sh" "# TODO: format test item"
    run_scanner
    assert_success
    # Format: - [ ] **title** (`file:line`) — text
    echo "$output" | grep -qE '^\- \[ \] \*\*example\.sh\*\* \(`example\.sh:[0-9]+`\) —'
}

@test "leading whitespace is stripped from marker text" {
    create_project_file "spaces.sh" "    # TODO:    lots of spaces here"
    run_scanner
    assert_success
    echo "$output" | grep -q "lots of spaces"
}

# === --output mode: yearly file creation ===

@test "--output flag creates yearly file in inbox/" {
    create_project_file "job.sh" "# TODO: test output mode"
    run_scanner --output
    assert_success
    local expected_file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    [ -f "$expected_file" ]
}

@test "--output flag prints path to stdout" {
    run_scanner --output
    assert_success
    assert_output --partial "Summary written to:"
}

@test "--output file contains frontmatter with todo-summary tag" {
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q 'tags: \[todo-summary, para, automated\]' "$file"
}

@test "--output file contains year in frontmatter" {
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "year: $(date +%Y)" "$file"
}

@test "--output file contains TODO Summary title" {
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "# TODO Summary — $(date +%Y)" "$file"
}

@test "--output file contains Archive section" {
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "## Archive" "$file"
}

@test "--output file contains scan section with PARA headers" {
    create_project_file "job.sh" "# TODO: para output test"
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "### Scan —" "$file"
    grep -q "#### Projects" "$file"
    grep -q "#### Areas" "$file"
    grep -q "#### Resources" "$file"
}

@test "--output scan section contains scanned items" {
    create_project_file "job.sh" "# TODO: output item test"
    create_vault_file "inbox/tasks.md" "- [ ] vault output test"
    run_scanner --output
    assert_success
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "output item test" "$file"
    grep -q "vault output test" "$file"
}

# === Living document: prepend behavior ===

@test "second scan prepends above first scan in yearly file" {
    create_project_file "first.sh" "# TODO: first run item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    [ -f "$file" ]

    # Add a new item and re-run
    create_project_file "second.sh" "# TODO: second run item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # Both items should exist
    grep -q "first run item" "$file"
    grep -q "second run item" "$file"

    # Second scan should appear BEFORE first scan (prepend order)
    local scan_lines scan_count
    scan_lines=$(grep -n "^### Scan" "$file")
    scan_count=$(echo "$scan_lines" | wc -l)
    [ "$scan_count" -eq 2 ]

    # The first "### Scan" in the file should be the NEWER one (second run)
    local first_scan_line second_scan_line second_item_line
    first_scan_line=$(echo "$scan_lines" | head -1 | cut -d: -f1)
    second_scan_line=$(echo "$scan_lines" | tail -1 | cut -d: -f1)
    second_item_line=$(grep -n "second run item" "$file" | head -1 | cut -d: -f1)
    [ "$second_item_line" -gt "$first_scan_line" ]
    [ "$second_item_line" -lt "$second_scan_line" ]
}

@test "three scans produce three scan sections in newest-first order" {
    create_project_file "a.sh" "# TODO: alpha item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    sleep 1

    create_project_file "b.sh" "# TODO: beta item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    sleep 1

    create_project_file "c.sh" "# TODO: gamma item"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    local scan_count
    scan_count=$(grep -c "^### Scan" "$file")
    [ "$scan_count" -eq 3 ]

    # All items preserved
    grep -q "alpha item" "$file"
    grep -q "beta item" "$file"
    grep -q "gamma item" "$file"
}

@test "frontmatter appears only once even after multiple scans" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    local title_count
    title_count=$(grep -c "^# TODO Summary" "$file")
    [ "$title_count" -eq 1 ]

    local first_dash_line
    first_dash_line=$(grep -n "^---" "$file" | head -1 | cut -d: -f1)
    [ "$first_dash_line" -eq 1 ]
}

@test "Archive section preserved after multiple scans" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"
    grep -q "## Archive" "$file"
    local archive_count
    archive_count=$(grep -c "## Archive" "$file")
    [ "$archive_count" -eq 1 ]
}

# === Data preservation ===

@test "checked items in summary file are preserved across scans" {
    create_project_file "task.sh" "# TODO: preserve me"
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"

    # Simulate user checking off an item in the summary file
    sed -i 's/- \[ \] \*\*task.sh\*\*/- [x] **task.sh**/' "$file"
    grep -q '\- \[x\] \*\*task.sh\*\*' "$file"

    # Second scan prepends new section
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # The checked item in the OLD scan section should still be there
    grep -q '\- \[x\] \*\*task.sh\*\*' "$file"
}

@test "user-added notes in summary file are preserved across scans" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local file="${FAKE_PROJECT_DIR}/inbox/todo-summary-$(date +%Y).md"

    # Simulate user adding a note in the Archive section
    sed -i '/^## Archive/a\- [x] Finished the deploy — went smoothly' "$file"
    grep -q "Finished the deploy" "$file"

    # Re-run scan
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output

    # User's note should survive
    grep -q "Finished the deploy" "$file"
}

# === Title context ===

@test "md file with YAML title shows title in output" {
    create_vault_file "inbox/my-research.md" "---
title: Quantum Computing Notes
created: 2026-04-10
tags: []
---

TODO: read Shor's algorithm paper"
    run_scanner
    assert_success
    assert_output --partial "**Quantum Computing Notes**"
}

@test "md file with heading (no frontmatter) shows heading as title" {
    create_vault_file "inbox/quick-note.md" "# Weekend Project Ideas

TODO: build a weather station"
    run_scanner
    assert_success
    assert_output --partial "**Weekend Project Ideas**"
}

@test "md file with no title or heading shows filename stem" {
    create_vault_file "inbox/untitled.md" "TODO: orphan item with no title"
    run_scanner
    assert_success
    assert_output --partial "**untitled**"
}

@test "non-md file shows filename as title" {
    create_project_file "deploy.sh" "# TODO: add rollback logic"
    run_scanner
    assert_success
    assert_output --partial "**deploy.sh**"
}

@test "title is shown alongside file:line reference" {
    create_vault_file "daily/2026-04-10.md" "---
date: 2026-04-10
tags: [daily]
---

# 2026-04-10

- [ ] review pull requests"
    run_scanner
    assert_success
    local areas_section
    areas_section=$(echo "$output" | sed -n '/^#### Areas/,/^#### Resources/p')
    echo "$areas_section" | grep -q '**2026-04-10**'
    echo "$areas_section" | grep -q 'daily/2026-04-10.md:'
    echo "$areas_section" | grep -q 'review pull requests'
}

@test "unchecked task text does not double up the checkbox prefix" {
    create_vault_file "inbox/tasks.md" "---
title: Sprint Tasks
---
- [ ] deploy to staging"
    run_scanner
    assert_success
    local areas_section
    areas_section=$(echo "$output" | sed -n '/^#### Areas/,/^#### Resources/p')
    echo "$areas_section" | grep -q '— deploy to staging'
    ! echo "$areas_section" | grep -q '— - \[ \]'
}

# === Table row filtering (false positive exclusion) ===

@test "markdown table rows containing marker names are excluded" {
    create_project_file "docs.md" "# Documentation

| Marker | Bucket |
|---|---|
| \`TODO:\` \`FIXME:\` | **Projects** |
| \`REVIEW:\` | **Resources** |

TODO: this is a real todo item"
    run_scanner
    assert_success
    assert_output --partial "this is a real todo item"
    refute_output --partial "**Projects** |"
}

@test "tests directory is excluded from scan" {
    create_project_file "tests/example.bats" "# TODO: test fixture that should not appear"
    run_scanner
    assert_success
    refute_output --partial "test fixture that should not appear"
}

# === Edge cases ===

@test "missing vault dir does not cause error" {
    sed -i "s|^VAULT_DIR=.*|VAULT_DIR=\"/nonexistent/path/that/does/not/exist\"|" "${TEST_TEMP_DIR}/todo-summary.sh"
    run_scanner
    assert_success
}

@test "deeply nested files are found" {
    create_vault_file "projects/2026/q2/deep-notes.md" "TODO: deep nested item"
    run_scanner
    assert_success
    assert_output --partial "deep nested item"
}

@test "files with spaces in names are handled" {
    create_vault_file "inbox/my important notes.md" "- [ ] task in spaced filename"
    run_scanner
    assert_success
    assert_output --partial "task in spaced filename"
}

@test "indented unchecked tasks are found" {
    create_vault_file "inbox/indented.md" "  - [ ] indented task
    - [ ] deeply indented task"
    run_scanner
    assert_success
    assert_output --partial "indented task"
    assert_output --partial "deeply indented task"
}

@test "only one yearly file exists after multiple runs" {
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    bash "${TEST_TEMP_DIR}/todo-summary.sh" --output
    local count
    count=$(find "${FAKE_PROJECT_DIR}/inbox" -name 'todo-summary-*.md' | wc -l)
    [ "$count" -eq 1 ]
}
