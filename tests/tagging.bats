#!/usr/bin/env bats
# Tests for the okm tagging system: tags, tag, untag, tagged, and -t flag.

load 'helpers/test_helper'

setup() {
    common_setup

    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="daily"
    export OBSIDIAN_NOTES_DIR="inbox"
    export EDITOR="true"
}

# === okm tags (list all tags) ===

@test "okm tags lists all tags with counts" {
    create_vault_file "inbox/note1.md" "---
title: Note 1
tags: [foo, bar]
---"
    create_vault_file "inbox/note2.md" "---
title: Note 2
tags: [foo, baz]
---"
    run "${OKM}" tags
    assert_success
    assert_output --partial "foo"
    assert_output --partial "bar"
    assert_output --partial "baz"
}

@test "okm tags for a specific note shows its tags" {
    create_vault_file "inbox/note1.md" "---
title: Note 1
tags: [alpha, beta]
---"
    run "${OKM}" tags "inbox/note1.md"
    assert_success
    assert_output --partial "alpha"
    assert_output --partial "beta"
}

@test "okm tags for note with no tags shows (no tags)" {
    create_vault_file "inbox/empty.md" "---
title: Empty
---"
    run "${OKM}" tags "inbox/empty.md"
    assert_success
    assert_output --partial "(no tags)"
}

# === okm tag (add tags) ===

@test "okm tag adds a tag to a note" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: [existing]
---"
    run "${OKM}" tag "inbox/note.md" "newtag"
    assert_success
    grep -q "tags: \[existing, newtag\]" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "okm tag adds multiple tags" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: []
---"
    run "${OKM}" tag "inbox/note.md" "a" "b" "c"
    assert_success
    grep -q "tags: \[a, b, c\]" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "okm tag does not duplicate existing tags" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: [foo]
---"
    run "${OKM}" tag "inbox/note.md" "foo"
    assert_success
    local count
    count=$(grep -o "foo" "${FAKE_VAULT_DIR}/inbox/note.md" | wc -l)
    [ "$count" -eq 1 ]
}

@test "okm tag requires a note argument" {
    run "${OKM}" tag
    assert_failure
    assert_output --partial "Note required"
}

@test "okm tag requires at least one tag" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: []
---"
    run "${OKM}" tag "inbox/note.md"
    assert_failure
    assert_output --partial "tag required"
}

# === okm untag (remove tags) ===

@test "okm untag removes a tag from a note" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: [keep, remove]
---"
    run "${OKM}" untag "inbox/note.md" "remove"
    assert_success
    grep -q "tags: \[keep\]" "${FAKE_VAULT_DIR}/inbox/note.md"
    ! grep -q "remove" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "okm untag removes multiple tags" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: [a, b, c, d]
---"
    run "${OKM}" untag "inbox/note.md" "b" "d"
    assert_success
    grep -q "tags: \[a, c\]" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "okm untag all tags leaves empty array" {
    create_vault_file "inbox/note.md" "---
title: Note
tags: [only]
---"
    run "${OKM}" untag "inbox/note.md" "only"
    assert_success
    grep -q "tags: \[\]" "${FAKE_VAULT_DIR}/inbox/note.md"
}

# === okm tagged (search by tag) ===

@test "okm tagged lists notes with a given tag" {
    create_vault_file "inbox/has-tag.md" "---
title: Has Tag
tags: [target]
---"
    create_vault_file "inbox/no-tag.md" "---
title: No Tag
tags: [other]
---"
    run "${OKM}" tagged "target"
    assert_success
    assert_output --partial "has-tag.md"
    refute_output --partial "no-tag.md"
}

@test "okm tagged requires a tag argument" {
    run "${OKM}" tagged
    assert_failure
    assert_output --partial "Tag required"
}

# === -t flag on okm new ===

@test "okm new -t creates note with initial tags" {
    run "${OKM}" new "Tagged Note" -t "foo,bar"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/tagged-note.md"
    [ -f "$file" ]
    grep -q "tags: \[foo, bar\]" "$file"
}

@test "okm new without -t creates note with empty tags" {
    run "${OKM}" new "Plain Note"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/plain-note.md"
    [ -f "$file" ]
    grep -q "tags: \[\]" "$file"
}

# === -t flag on okm capture ===

@test "okm capture -t adds extra tags alongside defaults" {
    run "${OKM}" capture "some text" -t "extra"
    assert_success
    local found
    found=$(find "${FAKE_VAULT_DIR}/inbox" -name '*.md' -newer "${FAKE_VAULT_DIR}" | head -1)
    [ -n "$found" ]
    grep -q "tags: \[capture, inbox, extra\]" "$found"
}

# === -t flag on okm spot ===

@test "okm spot -t adds extra tags to spotify note" {
    run "${OKM}" spot "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6" -t "favorite"
    assert_success
    local file="${FAKE_VAULT_DIR}/inbox/spotify-track-6rqhfgbbkwnb9mlmuqdhg6.md"
    [ -f "$file" ]
    grep -q "source/music, favorite" "$file"
}
