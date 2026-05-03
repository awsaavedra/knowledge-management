#!/usr/bin/env bats
# Tests for bin/okm — the vault CLI.

load 'helpers/test_helper'

setup() {
    common_setup

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
    grep -q 'title: "Test Note Title"' "$file"
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

# === okm spot ===

@test "okm spot requires a URL" {
    run "${OKM}" spot
    assert_failure
    assert_output --partial "Spotify URL required"
}

@test "okm spot rejects non-Spotify URLs" {
    run "${OKM}" spot "https://youtube.com/watch?v=abc123"
    assert_failure
    assert_output --partial "Not a Spotify URL"
}

@test "okm spot creates episode note with podcast template" {
    run "${OKM}" spot "https://open.spotify.com/episode/5sNnwbraj8xpzCZ87iASXi"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/spotify-episode-5snnwbraj8xpzcz87iasxi.md"
    [ -f "$file" ]
    grep -q "source_type: spotify-episode" "$file"
    grep -q "source_url:" "$file"
    grep -q "source/podcast" "$file"
    grep -q "## Player" "$file"
    grep -q "embed/episode" "$file"
    grep -q "## Summary" "$file"
    grep -q "## Transcript" "$file"
}

@test "okm spot creates track note with music template" {
    run "${OKM}" spot "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/spotify-track-6rqhfgbbkwnb9mlmuqdhg6.md"
    [ -f "$file" ]
    grep -q "source_type: spotify-track" "$file"
    grep -q "source/music" "$file"
    grep -q "## Player" "$file"
    grep -q "embed/track" "$file"
    grep -q "## Notes" "$file"
    # Track notes should NOT have transcript section
    ! grep -q "## Transcript" "$file"
}

@test "okm spot creates album note" {
    run "${OKM}" spot "https://open.spotify.com/album/1DFixLWuPkv3KT3TnV35m3"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/spotify-album-1dfixlwupkv3kt3tnv35m3.md"
    [ -f "$file" ]
    grep -q "source_type: spotify-album" "$file"
}

@test "okm spot creates playlist note" {
    run "${OKM}" spot "https://open.spotify.com/playlist/37i9dQZF1DXcBWIGoYBM5M"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/spotify-playlist-37i9dqzf1dxcbwigoybm5m.md"
    [ -f "$file" ]
    grep -q "source_type: spotify-playlist" "$file"
    grep -q "source/playlist" "$file"
}

@test "okm spot is idempotent (does not overwrite existing)" {
    run "${OKM}" spot "https://open.spotify.com/episode/5sNnwbraj8xpzCZ87iASXi"
    local file="${FAKE_VAULT_DIR}/inbox/spotify-episode-5snnwbraj8xpzcz87iasxi.md"
    [ -f "$file" ]
    echo "user added content" >> "$file"
    run "${OKM}" spot "https://open.spotify.com/episode/5sNnwbraj8xpzCZ87iASXi"
    assert_output --partial "Exists:"
    grep -q "user added content" "$file"
}

@test "okm spot embed URL has correct format" {
    run "${OKM}" spot "https://open.spotify.com/episode/5sNnwbraj8xpzCZ87iASXi"
    local file="${FAKE_VAULT_DIR}/inbox/spotify-episode-5snnwbraj8xpzcz87iasxi.md"
    grep -q "https://open.spotify.com/embed/episode/5sNnwbraj8xpzCZ87iASXi" "$file"
}

@test "okm spot includes Listen on Spotify link" {
    run "${OKM}" spot "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6"
    local file="${FAKE_VAULT_DIR}/inbox/spotify-track-6rqhfgbbkwnb9mlmuqdhg6.md"
    grep -q "Listen on Spotify" "$file"
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

# === N12: privacy — read-side commands skip private-*/ by default ===

setup_privacy_fixture() {
    mkdir -p "${FAKE_VAULT_DIR}/private-inbox"
    create_vault_file "inbox/public-note.md" "---
title: Public
tags: [public-tag]
---
public secret payload"
    create_vault_file "private-inbox/secret.md" "---
title: Secret
tags: [therapy, abusive-boss-name]
---
private secret payload"
}

@test "N12: okm grep skips private-*/ by default" {
    setup_privacy_fixture
    run "${OKM}" grep "secret payload"
    assert_success
    assert_output --partial "public-note.md"
    refute_output --partial "private-inbox"
    refute_output --partial "abusive"
}

@test "N12: okm tags (vault-wide) skips private-*/ by default" {
    setup_privacy_fixture
    run "${OKM}" tags
    assert_success
    assert_output --partial "public-tag"
    refute_output --partial "therapy"
    refute_output --partial "abusive-boss-name"
}

@test "N12: okm files skips private-*/ by default" {
    setup_privacy_fixture
    run "${OKM}" files
    assert_success
    assert_output --partial "inbox/public-note.md"
    refute_output --partial "private-inbox"
}

@test "N12: okm tagged skips private-*/ by default" {
    setup_privacy_fixture
    run "${OKM}" tagged "therapy"
    assert_success
    refute_output --partial "private-inbox"
    refute_output --partial "secret.md"
}

@test "N12: okm tags <explicit-private-path> still works (only walking is gated)" {
    setup_privacy_fixture
    run "${OKM}" tags "private-inbox/secret.md"
    assert_success
    assert_output --partial "therapy"
    assert_output --partial "abusive-boss-name"
}

@test "N12: KM_INCLUDE_PRIVATE=1 opt-in restores private-*/ scanning" {
    setup_privacy_fixture
    KM_INCLUDE_PRIVATE=1 run "${OKM}" grep "secret payload"
    assert_success
    assert_output --partial "public-note.md"
    assert_output --partial "private-inbox/secret.md"
}

@test "N12: KM_INCLUDE_PRIVATE=1 surfaces private tags in vault-wide tags listing" {
    setup_privacy_fixture
    KM_INCLUDE_PRIVATE=1 run "${OKM}" tags
    assert_success
    assert_output --partial "therapy"
}
