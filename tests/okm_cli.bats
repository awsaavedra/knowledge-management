#!/usr/bin/env bats
# Tests for bin/okm — the vault CLI.

load 'helpers/test_helper'

setup() {
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"

    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="daily"
    export OBSIDIAN_NOTES_DIR="inbox"
    # Use 'true' as editor so exec doesn't launch an interactive editor
    export EDITOR="true"
}

# === Help and usage ===

@test "okm help prints usage" {
    run "${OKM}" help
    assert_success
    assert_output --partial "okm - simple terminal knowledge manager"
}

@test "okm --help prints usage" {
    run "${OKM}" --help
    assert_success
    assert_output --partial "okm - simple terminal knowledge manager"
}

@test "okm -h prints usage" {
    run "${OKM}" -h
    assert_success
    assert_output --partial "okm - simple terminal knowledge manager"
}

@test "unknown subcommand prints usage and exits 1" {
    run "${OKM}" banana
    assert_failure
}

# === okm path ===

@test "okm path prints vault path" {
    run "${OKM}" path
    assert_success
    assert_output "${FAKE_VAULT_DIR}"
}

# === okm new ===

@test "okm new creates note with frontmatter" {
    run "${OKM}" new "Test Note Title"
    local file="${FAKE_VAULT_DIR}/inbox/test-note-title.md"
    [ -f "$file" ]
    grep -q "title: Test Note Title" "$file"
    grep -q "created:" "$file"
    grep -q "tags: \[\]" "$file"
    grep -q "# Test Note Title" "$file"
}

@test "okm new slugifies the title correctly" {
    run "${OKM}" new "My Cool Note!!!"
    local file="${FAKE_VAULT_DIR}/inbox/my-cool-note.md"
    [ -f "$file" ]
}

@test "okm new requires a title" {
    run "${OKM}" new
    assert_failure
    assert_output --partial "Title required"
}

@test "okm new is idempotent (does not overwrite existing)" {
    local file="${FAKE_VAULT_DIR}/inbox/existing-note.md"
    echo "original content" > "$file"
    run "${OKM}" new "Existing Note"
    # File should still contain original content
    grep -q "original content" "$file"
}

# === okm capture ===

@test "okm capture creates timestamped note" {
    run "${OKM}" capture "quick thought"
    # Find the created file (matches YYYYMMDD-HHMMSS.md pattern)
    local found
    found=$(find "${FAKE_VAULT_DIR}/inbox" -name '*.md' -newer "${FAKE_VAULT_DIR}" | head -1)
    [ -n "$found" ]
    grep -q "Quick Capture" "$found"
    grep -q "quick thought" "$found"
    grep -q "tags: \[capture, inbox\]" "$found"
}

# === okm today ===

@test "okm today creates daily note with correct date" {
    run "${OKM}" today
    local today
    today="$(date +%F)"
    local file="${FAKE_VAULT_DIR}/daily/${today}.md"
    [ -f "$file" ]
    grep -q "date: ${today}" "$file"
    grep -q "## Tasks" "$file"
    grep -q "\- \[ \]" "$file"
    grep -q "## Notes" "$file"
}

@test "okm today is idempotent (does not overwrite)" {
    local today
    today="$(date +%F)"
    local file="${FAKE_VAULT_DIR}/daily/${today}.md"
    # Create it first
    run "${OKM}" today
    [ -f "$file" ]
    local original_hash
    original_hash="$(sha256sum "$file" | cut -d' ' -f1)"
    # Run again
    run "${OKM}" today
    local second_hash
    second_hash="$(sha256sum "$file" | cut -d' ' -f1)"
    [ "$original_hash" = "$second_hash" ]
}

@test "okm today creates daily and inbox dirs if missing" {
    rm -rf "${FAKE_VAULT_DIR}/daily" "${FAKE_VAULT_DIR}/inbox"
    run "${OKM}" today
    [ -d "${FAKE_VAULT_DIR}/daily" ]
    [ -d "${FAKE_VAULT_DIR}/inbox" ]
}

# === okm files ===

@test "okm files lists .md files" {
    echo "test" > "${FAKE_VAULT_DIR}/inbox/alpha.md"
    echo "test" > "${FAKE_VAULT_DIR}/inbox/beta.md"
    run "${OKM}" files
    assert_success
    assert_output --partial "alpha.md"
    assert_output --partial "beta.md"
}

@test "okm files with pattern filters results" {
    echo "test" > "${FAKE_VAULT_DIR}/inbox/alpha.md"
    echo "test" > "${FAKE_VAULT_DIR}/inbox/beta.md"
    run "${OKM}" files alpha
    assert_success
    assert_output --partial "alpha.md"
    refute_output --partial "beta.md"
}

# === okm grep ===

@test "okm grep finds pattern in vault" {
    echo "unique-test-string-42" > "${FAKE_VAULT_DIR}/inbox/searchable.md"
    run "${OKM}" grep "unique-test-string-42"
    assert_success
    assert_output --partial "unique-test-string-42"
}

@test "okm grep requires a pattern" {
    run "${OKM}" grep
    assert_failure
    assert_output --partial "Pattern required"
}

# === okm sync ===

@test "okm sync requires git repo" {
    run "${OKM}" sync
    assert_failure
    assert_output --partial "not a git repo"
}

@test "okm sync with git repo commits changes" {
    git -C "${FAKE_VAULT_DIR}" init -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "test@test.com"
    git -C "${FAKE_VAULT_DIR}" config user.name "Test"
    echo "initial" > "${FAKE_VAULT_DIR}/inbox/note.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial"
    # Add a new file
    echo "new content" > "${FAKE_VAULT_DIR}/inbox/new-note.md"
    run "${OKM}" sync "test commit message"
    assert_success
    # Verify commit exists
    run git -C "${FAKE_VAULT_DIR}" log --oneline -1
    assert_output --partial "test commit message"
}

@test "okm sync with no changes says so" {
    git -C "${FAKE_VAULT_DIR}" init -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "test@test.com"
    git -C "${FAKE_VAULT_DIR}" config user.name "Test"
    echo "content" > "${FAKE_VAULT_DIR}/inbox/note.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial"
    run "${OKM}" sync
    assert_success
    assert_output --partial "No changes to commit"
}
