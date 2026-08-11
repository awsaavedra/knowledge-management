#!/usr/bin/env bats
# Property-test / fuzz harness for bin/okm.
# Throws adversarial inputs at every user-facing subcommand.
#
# Pass criterion: every command either exits 0 with sane output, OR exits
# non-zero with a human-readable error on stderr/stdout. Never: silent success
# with no file written, partial file corruption, or files written outside the
# vault.

load 'helpers/test_helper'

setup() {
    common_setup
    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="public/daily"
    export OBSIDIAN_NOTES_DIR="public/inbox"
    export EDITOR="true"
    mkdir -p "${FAKE_VAULT_DIR}/public/inbox" "${FAKE_VAULT_DIR}/public/daily"
}

# Helper: assert no files were created outside the vault.
assert_no_escape() {
    local outside
    outside="$(find "${TEST_TEMP_DIR}" -newer "${FAKE_VAULT_DIR}" -not -path "${FAKE_VAULT_DIR}/*" -name '*.md' 2>/dev/null || true)"
    [ -z "$outside" ] || {
        echo "Files created outside vault: $outside" >&2
        return 1
    }
}

# === okm new — title fuzzing ===

@test "fuzz: okm new with empty string" {
    run "${OKM}" new ""
    assert_failure
}

@test "fuzz: okm new with spaces only" {
    run "${OKM}" new "   "
    assert_failure
}

@test "fuzz: okm new with unicode-only title" {
    run "${OKM}" new "日本語タイトル"
    assert_failure
    assert_no_escape
}

@test "fuzz: okm new with slashes in title" {
    run "${OKM}" new "foo/bar/baz"
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/foo-bar-baz.md"
    [ -f "$file" ]
    assert_no_escape
}

@test "fuzz: okm new with backticks and dollar signs" {
    run "${OKM}" new 'note $(whoami) `id`'
    assert_success
    assert_no_escape
}

@test "fuzz: okm new with single quotes" {
    run "${OKM}" new "it's a note"
    assert_success
    assert_no_escape
}

@test "fuzz: okm new with double quotes" {
    run "${OKM}" new 'She said "hello"'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/she-said-hello.md"
    [ -f "$file" ]
    grep -q 'title: "She said \\"hello\\""' "$file"
}

@test "fuzz: okm new with backslash-n in title (YAML escape sequence)" {
    run "${OKM}" new 'test\note'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/test-note.md"
    [ -f "$file" ]
    grep -q 'title: "test\\\\note"' "$file"
}

@test "fuzz: okm new -t with injection attempt" {
    run "${OKM}" new "Safe Title" -t 'ok,evil]'
    assert_failure
    assert_output --partial "Invalid tag"
    [ ! -f "${FAKE_VAULT_DIR}/public/inbox/safe-title.md" ]
}

@test "fuzz: okm new with 250 char title (near filesystem limit)" {
    local title
    title="$(python3 -c 'print("a" * 250)')"
    run "${OKM}" new "$title"
    assert_success
    assert_no_escape
}

@test "fuzz: okm new with null bytes in title" {
    run "${OKM}" new $'title\x00with\x00nulls'
    # bash strips null bytes; just verify no crash
    assert_no_escape
}

@test "fuzz: okm new with tab characters" {
    run "${OKM}" new $'tab\there\tand\tthere'
    assert_success
    assert_no_escape
}

# === okm tag — tag fuzzing ===

@test "fuzz: okm tag with empty tag" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" ""
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "fuzz: okm tag with space in tag" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "two words"
    assert_failure
}

@test "fuzz: okm tag with YAML-breaking chars" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    for bad_tag in 'evil]' 'evil[' 'foo:bar' 'a,b' 'a"b' 'a|b'; do
        run "${OKM}" tag "public/inbox/note.md" "$bad_tag"
        assert_failure
    done
}

@test "fuzz: okm tag with very long tag name (500 chars)" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    local long_tag
    long_tag="$(python3 -c 'print("a" * 500)')"
    run "${OKM}" tag "public/inbox/note.md" "$long_tag"
    assert_success
    grep -q "tags:" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "fuzz: okm tag with tag starting with dash" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "-starts-with-dash"
    assert_success
    refute_output --partial "grep:"
}

@test "fuzz: okm tag idempotent — adding same tag twice" {
    create_vault_file "public/inbox/note.md" "---
tags: [foo]
---"
    run "${OKM}" tag "public/inbox/note.md" "foo"
    assert_success
    local count
    count="$(grep -o 'foo' "${FAKE_VAULT_DIR}/public/inbox/note.md" | grep -c . || true)"
    [ "$count" -eq 1 ]
}

# === okm tagged — query fuzzing ===

@test "fuzz: okm tagged with regex metacharacters" {
    create_vault_file "public/inbox/note.md" "---
tags: [safe]
---"
    for bad in '.*' 'foo|bar' '(group)' '[class]' 'star*' 'plus+question?'; do
        run "${OKM}" tagged "$bad"
        # Should fail validation (invalid tag chars) — not return all files
        assert_failure
    done
}

@test "fuzz: okm tagged with empty string" {
    run "${OKM}" tagged ""
    assert_failure
}

# === okm pod / okm video — URL fuzzing ===

@test "fuzz: okm pod with non-URL, non-file string" {
    export OKM_POD_OFFLINE=1
    run "${OKM}" pod "not-a-url"
    assert_failure
    assert_no_escape
}

@test "fuzz: okm pod with a spotify URL containing query params (offline scaffold)" {
    export OKM_POD_OFFLINE=1
    run "${OKM}" pod "https://open.spotify.com/episode/6rqhFgbbKwnb9MLmUQDhG6?si=abc123&x=)"
    assert_success
    assert_no_escape
}

@test "fuzz: okm video with non-URL, non-file string" {
    run "${OKM}" video "not-a-url"
    assert_failure
    assert_no_escape
}

@test "fuzz: okm video with a YouTube URL having a short id" {
    run "${OKM}" video "https://www.youtube.com/watch?v=abc"
    assert_failure
    assert_no_escape
}

# === okm open — path traversal fuzzing ===

@test "fuzz: okm open with absolute path outside vault" {
    run "${OKM}" open "/etc/passwd"
    assert_failure
    assert_output --partial "outside the vault"
}

@test "fuzz: okm open with ../../../etc/passwd" {
    run "${OKM}" open "../../../etc/passwd"
    assert_failure
    assert_output --partial "outside the vault"
}

@test "fuzz: okm open with symlink-like path" {
    run "${OKM}" open "/proc/self/environ"
    assert_failure
}

# === okm grep — pattern fuzzing ===

@test "fuzz: okm grep with regex special chars doesn't crash" {
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/x.md"
    run "${OKM}" grep '(unclosed'
    # rg treats this as an error; that's fine — just no crash
    [ "$status" -le 2 ]
}

@test "fuzz: okm grep with empty pattern" {
    run "${OKM}" grep ""
    assert_failure
}

# === okm files — pattern fuzzing ===

@test "fuzz: okm files with glob characters returns gracefully" {
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/readme.md"
    run "${OKM}" files "*.md"
    # Substring match: * is literal, so no results — graceful empty
    assert_success
}

@test "fuzz: okm files with empty vault returns empty" {
    rm -rf "${FAKE_VAULT_DIR}/public/inbox/"*.md "${FAKE_VAULT_DIR}/public/daily/"*.md
    run "${OKM}" files
    assert_success
}

# === yaml_escape_dq: newline injection ===

@test "fuzz: title with embedded newline does not break YAML frontmatter" {
    run "${OKM}" new $'Title With\nNewline'
    assert_success
    local file
    file="$(find "${FAKE_VAULT_DIR}/public/inbox" -name '*.md' | head -1)"
    [ -f "$file" ]
    run grep '^title:' "$file"
    assert_output --regexp '^title: "Title With Newline"'
    # Frontmatter must close properly (at least two --- lines)
    run grep -c '^---$' "$file"
    [ "${output}" -ge 2 ]
}

# === Cross-cutting: no file escapes vault ===

@test "fuzz: no subcommand creates files outside OBSIDIAN_VAULT" {
    run "${OKM}" new "safe note"
    assert_no_escape
    run "${OKM}" capture "safe capture"
    assert_no_escape
    run "${OKM}" today
    assert_no_escape
}
