#!/usr/bin/env bats
# Tests for bin/okm — the vault CLI.

load 'helpers/test_helper'

setup() {
    common_setup

    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="public/daily"
    export OBSIDIAN_NOTES_DIR="public/inbox"
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
    local file="${FAKE_VAULT_DIR}/public/inbox/test-note-title.md"
    [ -f "$file" ]
    grep -q 'title: "Test Note Title"' "$file"
    grep -q "created:" "$file"
    grep -q "tags: \[\]" "$file"
    grep -q "# Test Note Title" "$file"
}

@test "okm new slugifies the title correctly" {
    run "${OKM}" new "My Cool Note!!!"
    local file="${FAKE_VAULT_DIR}/public/inbox/my-cool-note.md"
    [ -f "$file" ]
}

@test "okm new requires a title" {
    run "${OKM}" new
    assert_failure
    assert_output --partial "Title required"
}

@test "okm new is idempotent (does not overwrite existing)" {
    local file="${FAKE_VAULT_DIR}/public/inbox/existing-note.md"
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
    found=$(find "${FAKE_VAULT_DIR}/public/inbox" -name '*.md' -newer "${FAKE_VAULT_DIR}" | head -1)
    [ -n "$found" ]
    grep -q "Quick Capture" "$found"
    grep -q "quick thought" "$found"
    grep -q "tags: \[capture, inbox\]" "$found"
}

# === okm today ===

@test "okm today creates weekly note for the current week" {
    run "${OKM}" today
    local dow week_start
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
    [ -f "$file" ]
    grep -q "week_start: ${week_start}" "$file"
    grep -q "## Captures" "$file"
    grep -q "## Notes" "$file"
    grep -q "## Tasks" "$file"
    grep -q "\- \[ \]" "$file"
    grep -q "## Reflection" "$file"
}

@test "okm today is idempotent (does not overwrite)" {
    local dow week_start
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
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
    rm -rf "${FAKE_VAULT_DIR}/public/daily" "${FAKE_VAULT_DIR}/public/inbox"
    run "${OKM}" today
    [ -d "${FAKE_VAULT_DIR}/public/daily" ]
    [ -d "${FAKE_VAULT_DIR}/public/inbox" ]
}

@test "okm today carries unfinished tasks forward from the previous week" {
    local dow week_start prev_week
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    prev_week="$(date -d "${week_start} -7 days" +%F)"
    cat > "${FAKE_VAULT_DIR}/public/daily/${prev_week}-weekly.md" <<EOF
---
week_start: ${prev_week}
---
# Week of ${prev_week}

## Tasks

- [ ] carry me over
- [x] leave me behind
- [ ]

## Reflection
EOF
    run "${OKM}" today
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
    [ -f "$file" ]
    # Unchecked item rolls into the new week; checked item and empty placeholder do not.
    grep -q '^- \[ \] carry me over' "$file"
    ! grep -q 'leave me behind' "$file"
}

@test "okm today carries tasks forward across skipped weeks" {
    local dow week_start old_week
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    # A note three weeks back, with the intervening weeks having no note at all.
    old_week="$(date -d "${week_start} -21 days" +%F)"
    cat > "${FAKE_VAULT_DIR}/public/daily/${old_week}-weekly.md" <<EOF
---
week_start: ${old_week}
---
# Week of ${old_week}

## Tasks

- [ ] ancient unfinished task

## Reflection
EOF
    run "${OKM}" today
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
    # Survives the gap even though no note exists for the weeks in between.
    grep -q '^- \[ \] ancient unfinished task' "$file"
}

@test "okm today does not resurrect a task checked off in a later week" {
    local dow week_start week_a week_b
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    week_a="$(date -d "${week_start} -14 days" +%F)"  # older
    week_b="$(date -d "${week_start} -7 days" +%F)"   # newer
    cat > "${FAKE_VAULT_DIR}/public/daily/${week_a}-weekly.md" <<EOF
---
week_start: ${week_a}
---
## Tasks

- [ ] finish later
EOF
    cat > "${FAKE_VAULT_DIR}/public/daily/${week_b}-weekly.md" <<EOF
---
week_start: ${week_b}
---
## Tasks

- [x] finish later
EOF
    run "${OKM}" today
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
    # Latest state wins: it was checked off, so it must not come back.
    ! grep -q 'finish later' "$file"
}

@test "okm today deduplicates a task carried across many weeks" {
    local dow week_start week_a week_b
    dow="$(date +%u)"
    week_start="$(date -d "-$((dow - 1)) days" +%F)"
    week_a="$(date -d "${week_start} -14 days" +%F)"
    week_b="$(date -d "${week_start} -7 days" +%F)"
    for w in "$week_a" "$week_b"; do
        cat > "${FAKE_VAULT_DIR}/public/daily/${w}-weekly.md" <<EOF
---
week_start: ${w}
---
## Tasks

- [ ] recurring task
EOF
    done
    run "${OKM}" today
    local file="${FAKE_VAULT_DIR}/public/daily/${week_start}-weekly.md"
    [ "$(grep -c '^- \[ \] recurring task' "$file")" -eq 1 ]
}

# === okm files ===

@test "okm files lists .md files" {
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/alpha.md"
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/beta.md"
    run "${OKM}" files
    assert_success
    assert_output --partial "alpha.md"
    assert_output --partial "beta.md"
}

@test "okm files with pattern filters results" {
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/alpha.md"
    echo "test" > "${FAKE_VAULT_DIR}/public/inbox/beta.md"
    run "${OKM}" files alpha
    assert_success
    assert_output --partial "alpha.md"
    refute_output --partial "beta.md"
}

# === okm grep ===

@test "okm grep finds pattern in vault" {
    echo "unique-test-string-42" > "${FAKE_VAULT_DIR}/public/inbox/searchable.md"
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
    echo "initial" > "${FAKE_VAULT_DIR}/public/inbox/note.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial"
    # Add a new file
    echo "new content" > "${FAKE_VAULT_DIR}/public/inbox/new-note.md"
    run "${OKM}" sync "test commit message"
    assert_success
    # Verify commit exists
    run git -C "${FAKE_VAULT_DIR}" log --oneline -1
    assert_output --partial "test commit message"
}

# === okm pod — podcast capture (link or file) ===
# Hermetic: OKM_POD_FEED_FILE injects a local RSS feed (no network);
# OKM_POD_OFFLINE=1 forces the graceful-degradation path.

# Write a fixture feed (+ local VTT transcript) and echo the feed path.
_pod_fixture_feed() {
    local vtt="${BATS_TEST_TMPDIR}/fix.vtt"
    cat > "$vtt" <<'VTT'
WEBVTT

00:00:01.000 --> 00:00:04.000
Welcome to the show.
VTT
    local feed="${BATS_TEST_TMPDIR}/fix-feed.xml"
    cat > "$feed" <<XML
<?xml version="1.0"?>
<rss version="2.0" xmlns:itunes="http://www.itunes.com/dtds/podcast-1.0.dtd" xmlns:podcast="https://podcastindex.org/namespace/1.0">
<channel><title>Danielle Newnham Podcast</title>
  <item>
    <title>Riva Tez on Genius, Mania and The Impact of Cancel Culture</title>
    <itunes:episode>99</itunes:episode>
    <pubDate>Mon, 1 Jan 2024 14:59:52 +0000</pubDate>
    <enclosure length="1" type="audio/mpeg" url="https://cdn.example.com/riva.mp3"/>
    <podcast:transcript url="file://${vtt}" type="text/vtt"/>
  </item>
</channel></rss>
XML
    echo "$feed"
}

@test "okm pod requires a link or file" {
    run "${OKM}" pod
    assert_failure
    assert_output --partial "Podcast link or file required"
}

@test "okm pod rejects a bare non-link, non-file string" {
    run "${OKM}" pod "not-a-link"
    assert_failure
    assert_output --partial "Not a link or a readable file"
}

@test "okm pod redirects a YouTube link to okm video" {
    run "${OKM}" pod "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    assert_failure
    assert_output --partial "use 'okm video"
    run "${OKM}" pod "https://youtu.be/dQw4w9WgXcQ"
    assert_failure
    assert_output --partial "okm video"
}

@test "okm pod resolves an episode via the feed into a PascalCase filename" {
    export OKM_POD_FEED_FILE="$(_pod_fixture_feed)"
    run "${OKM}" pod "https://open.spotify.com/episode/077HR1ZC7hySodvybYdm6H?si=x"
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/podcast-DanielleNewnhamPodcast-RivaTezOnGeniusManiaAndTheImpactOfCancelCulture-99-2024-01-01.md"
    [ -f "$file" ]
    grep -q "source_type: podcast" "$file"
    grep -q "source_platform: spotify" "$file"
    grep -q 'show: "Danielle Newnham Podcast"' "$file"
    grep -q "episode: 99" "$file"
    grep -q "publish_date: 2024-01-01" "$file"
    grep -q "## Transcript" "$file"
    grep -q "^\[00:01\] Welcome to the show." "$file"
}

@test "okm pod embeds an existing RSS transcript verbatim" {
    export OKM_POD_FEED_FILE="$(_pod_fixture_feed)"
    "${OKM}" pod "https://feeds.example.com/x.xml" >/dev/null
    local f; f="$(find "${FAKE_VAULT_DIR}/public/inbox" -name 'podcast-*.md' | head -1)"
    run grep -q "Welcome to the show." "$f"; assert_success
}

@test "okm pod degrades gracefully offline (scaffold, no hard fail)" {
    export OKM_POD_OFFLINE=1
    run "${OKM}" pod "https://open.spotify.com/episode/077HR1ZC7hySodvybYdm6H?si=x"
    assert_success
    assert_output --partial "Created: public/inbox/podcast-"
    local f; f="$(find "${FAKE_VAULT_DIR}/public/inbox" -name 'podcast-*.md' | head -1)"
    run grep -q "does not transcribe audio" "$f"; assert_success
}

@test "okm pod is idempotent (does not overwrite existing)" {
    export OKM_POD_FEED_FILE="$(_pod_fixture_feed)"
    "${OKM}" pod "https://feeds.example.com/x.xml" >/dev/null
    local f; f="$(find "${FAKE_VAULT_DIR}/public/inbox" -name 'podcast-*.md' | head -1)"
    echo "user added content" >> "$f"
    run "${OKM}" pod "https://feeds.example.com/x.xml"
    assert_output --partial "Exists:"
    grep -q "user added content" "$f"
}

@test "okm pod imports a local transcript file verbatim" {
    local srt="${BATS_TEST_TMPDIR}/local.srt"
    cat > "$srt" <<'SRT'
1
00:00:02,000 --> 00:00:05,000
Local transcript line.
SRT
    run "${OKM}" pod "$srt" "My Local Talk"
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/podcast-MyLocalTalk-$(date +%F).md"
    [ -f "$file" ]
    grep -q "^\[00:02\] Local transcript line." "$file"
}

@test "okm sync with no changes says so" {
    git -C "${FAKE_VAULT_DIR}" init -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "test@test.com"
    git -C "${FAKE_VAULT_DIR}" config user.name "Test"
    echo "content" > "${FAKE_VAULT_DIR}/public/inbox/note.md"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -m "initial"
    run "${OKM}" sync
    assert_success
    assert_output --partial "No changes to commit"
}

# === N12: privacy — read-side commands skip private-*/ by default ===

setup_privacy_fixture() {
    mkdir -p "${FAKE_VAULT_DIR}/private/inbox"
    create_vault_file "public/inbox/public-note.md" "---
title: Public
tags: [public-tag]
---
public secret payload"
    create_vault_file "private/inbox/secret.md" "---
title: Secret
tags: [therapy, abusive-boss-name]
---
private secret payload"
}

@test "N12: okm grep skips private/ by default" {
    setup_privacy_fixture
    run "${OKM}" grep "secret payload"
    assert_success
    assert_output --partial "public-note.md"
    refute_output --partial "private/inbox"
    refute_output --partial "abusive"
}

@test "N12: okm tags (vault-wide) skips private/ by default" {
    setup_privacy_fixture
    run "${OKM}" tags
    assert_success
    assert_output --partial "public-tag"
    refute_output --partial "therapy"
    refute_output --partial "abusive-boss-name"
}

@test "N12: okm files skips private/ by default" {
    setup_privacy_fixture
    run "${OKM}" files
    assert_success
    assert_output --partial "public/inbox/public-note.md"
    refute_output --partial "private/inbox"
}

@test "N12: okm tagged skips private/ by default" {
    setup_privacy_fixture
    run "${OKM}" tagged "therapy"
    assert_success
    refute_output --partial "private/inbox"
    refute_output --partial "secret.md"
}

@test "N12: okm tags <explicit-private-path> still works (only walking is gated)" {
    setup_privacy_fixture
    run "${OKM}" tags "private/inbox/secret.md"
    assert_success
    assert_output --partial "therapy"
    assert_output --partial "abusive-boss-name"
}

@test "N12: KM_INCLUDE_PRIVATE=1 opt-in restores private/ scanning" {
    setup_privacy_fixture
    KM_INCLUDE_PRIVATE=1 run "${OKM}" grep "secret payload"
    assert_success
    assert_output --partial "public-note.md"
    assert_output --partial "private/inbox/secret.md"
}

@test "N12: KM_INCLUDE_PRIVATE=1 surfaces private tags in vault-wide tags listing" {
    setup_privacy_fixture
    KM_INCLUDE_PRIVATE=1 run "${OKM}" tags
    assert_success
    assert_output --partial "therapy"
}

# === N13: YAML double-quote escaping ===

@test "N13: okm new escapes double-quotes in YAML title" {
    run "${OKM}" new 'Lessons from "The Manager"'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/lessons-from-the-manager.md"
    [ -f "$file" ]
    grep -q 'title: "Lessons from \\"The Manager\\""' "$file"
}

# === N14 + N18 + N20: slugify hardening ===

@test "N14: okm new with all-emoji title fails with clear error" {
    run "${OKM}" new "☕"
    assert_failure
    assert_output --partial "empty or too-short slug"
}

@test "N18: okm new with very long title truncates slug (no OS error)" {
    local long_title
    long_title="$(python3 -c 'print("a" * 300)')"
    run "${OKM}" new "$long_title"
    assert_success
    local file
    file="$(find "${FAKE_VAULT_DIR}/public/inbox" -name '*.md' -newer "${FAKE_VAULT_DIR}" | head -1)"
    [ -n "$file" ]
    local bname
    bname="$(basename "$file")"
    [ "${#bname}" -le 204 ]
}

@test "N20: okm new with newline in title collapses to single-line slug" {
    run "${OKM}" new $'multi\nline\ntitle'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/multi-line-title.md"
    [ -f "$file" ]
}

# === N26: backslash escaping in YAML ===

@test "N26: okm new escapes backslashes in YAML title" {
    run "${OKM}" new 'test\note'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/test-note.md"
    [ -f "$file" ]
    grep -q 'title: "test\\\\note"' "$file"
}

# === N27: -t flag validation ===

@test "N27: okm new -t rejects YAML-breaking tag values" {
    run "${OKM}" new "Test" -t 'evil], injected: true'
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "N27: okm new -t accepts valid comma-separated tags" {
    run "${OKM}" new "Tag Test" -t 'foo,bar,source/music'
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/tag-test.md"
    [ -f "$file" ]
    grep -q 'tags: \[foo, bar, source/music\]' "$file"
}

@test "N27: okm capture -t rejects invalid tags" {
    run "${OKM}" capture "body" -t 'ok,bad tag'
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "N27: okm pod -t rejects invalid tags" {
    export OKM_POD_OFFLINE=1
    run "${OKM}" pod "https://open.spotify.com/episode/077HR1ZC7hySodvybYdm6H" -t 'evil]'
    assert_failure
    assert_output --partial "Invalid tag"
}

# === recent_notes: smoke test ===

@test "okm recent exits cleanly with empty vault (no fzf interaction)" {
    # Stub fzf to immediately return empty (simulates no selection / Esc)
    mkdir -p "${FAKE_VAULT_DIR}/public/inbox" "${FAKE_VAULT_DIR}/public/daily"
    export PATH="${BATS_TEST_TMPDIR}/stub:${PATH}"
    mkdir -p "${BATS_TEST_TMPDIR}/stub"
    printf '#!/bin/sh\nexit 130\n' > "${BATS_TEST_TMPDIR}/stub/fzf"
    chmod +x "${BATS_TEST_TMPDIR}/stub/fzf"
    run "${OKM}" recent
    # exit 0 because okm treats empty fzf selection as a normal no-op exit
    assert_success
}

@test "okm recent with one note opens editor without crashing" {
    mkdir -p "${FAKE_VAULT_DIR}/public/inbox"
    echo -e '---\ntitle: "A"\n---' > "${FAKE_VAULT_DIR}/public/inbox/a.md"
    export PATH="${BATS_TEST_TMPDIR}/stub2:${PATH}"
    mkdir -p "${BATS_TEST_TMPDIR}/stub2"
    # fzf stub: print the first line it receives (simulates selecting the note)
    printf '#!/bin/sh\nhead -1\n' > "${BATS_TEST_TMPDIR}/stub2/fzf"
    chmod +x "${BATS_TEST_TMPDIR}/stub2/fzf"
    export EDITOR="true"
    run "${OKM}" recent
    assert_success
}

# === okm video — video/lecture capture (link or file) ===

@test "okm video: creates a note and prints its relative path" {
    run "${OKM}" video "https://www.youtube.com/watch?v=3k20zFlbFfE" < /dev/null
    assert_success
    assert_output --partial "Created: public/inbox/video-"
    [ -n "$(find "${FAKE_VAULT_DIR}/public/inbox" -name 'video-*.md')" ]
}

@test "okm video: writes video frontmatter with a canonical source_url" {
    "${OKM}" video "https://youtu.be/3k20zFlbFfE?t=42" < /dev/null >/dev/null
    local f; f="$(find "${FAKE_VAULT_DIR}/public/inbox" -name 'video-*.md' | head -1)"
    run grep -q 'source_type: video' "$f"; assert_success
    run grep -q 'source_platform: youtube' "$f"; assert_success
    run grep -q 'video_id: "3k20zFlbFfE"' "$f"; assert_success
    run grep -q 'source_url: "https://www.youtube.com/watch?v=3k20zFlbFfE"' "$f"; assert_success
}

@test "okm video: rejects an unsupported link" {
    run "${OKM}" video "https://example.com/watch?v=abcdefghijk" < /dev/null
    assert_failure
    assert_output --partial "Not a supported video link"
}

@test "okm video: rejects a YouTube URL with no video id" {
    run "${OKM}" video "https://www.youtube.com/feed/subscriptions" < /dev/null
    assert_failure
    assert_output --partial "video ID"
}

@test "okm video: requires a link or file argument" {
    run "${OKM}" video < /dev/null
    assert_failure
    assert_output --partial "Video link or file required"
}
