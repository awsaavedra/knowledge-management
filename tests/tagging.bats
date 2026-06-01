#!/usr/bin/env bats
# Tests for the okm tagging system: tags, tag, untag, tagged, and -t flag.

load 'helpers/test_helper'

setup() {
    common_setup

    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="public/daily"
    export OBSIDIAN_NOTES_DIR="public/inbox"
    export EDITOR="true"
}

# === okm tags (list all tags) ===

@test "okm tags lists all tags with counts" {
    create_vault_file "public/inbox/note1.md" "---
title: Note 1
tags: [foo, bar]
---"
    create_vault_file "public/inbox/note2.md" "---
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
    create_vault_file "public/inbox/note1.md" "---
title: Note 1
tags: [alpha, beta]
---"
    run "${OKM}" tags "public/inbox/note1.md"
    assert_success
    assert_output --partial "alpha"
    assert_output --partial "beta"
}

@test "okm tags for note with no tags shows (no tags)" {
    create_vault_file "public/inbox/empty.md" "---
title: Empty
---"
    run "${OKM}" tags "public/inbox/empty.md"
    assert_success
    assert_output --partial "(no tags)"
}

# === okm tag (add tags) ===

@test "okm tag adds a tag to a note" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: [existing]
---"
    run "${OKM}" tag "public/inbox/note.md" "newtag"
    assert_success
    grep -q "tags: \[existing, newtag\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "okm tag adds multiple tags" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "a" "b" "c"
    assert_success
    grep -q "tags: \[a, b, c\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "okm tag does not duplicate existing tags" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: [foo]
---"
    run "${OKM}" tag "public/inbox/note.md" "foo"
    assert_success
    local count
    count=$(grep -o "foo" "${FAKE_VAULT_DIR}/public/inbox/note.md" | wc -l)
    [ "$count" -eq 1 ]
}

@test "okm tag requires a note argument" {
    run "${OKM}" tag
    assert_failure
    assert_output --partial "Note required"
}

@test "okm tag requires at least one tag" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md"
    assert_failure
    assert_output --partial "tag required"
}

# === okm untag (remove tags) ===

@test "okm untag removes a tag from a note" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: [keep, remove]
---"
    run "${OKM}" untag "public/inbox/note.md" "remove"
    assert_success
    grep -q "tags: \[keep\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
    ! grep -q "remove" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "okm untag removes multiple tags" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: [a, b, c, d]
---"
    run "${OKM}" untag "public/inbox/note.md" "b" "d"
    assert_success
    grep -q "tags: \[a, c\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "okm untag all tags leaves empty array" {
    create_vault_file "public/inbox/note.md" "---
title: Note
tags: [only]
---"
    run "${OKM}" untag "public/inbox/note.md" "only"
    assert_success
    grep -q "tags: \[\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

# === okm tagged (search by tag) ===

@test "okm tagged lists notes with a given tag" {
    create_vault_file "public/inbox/has-tag.md" "---
title: Has Tag
tags: [target]
---"
    create_vault_file "public/inbox/no-tag.md" "---
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
    local file="${FAKE_VAULT_DIR}/public/inbox/tagged-note.md"
    [ -f "$file" ]
    grep -q "tags: \[foo, bar\]" "$file"
}

@test "okm new without -t creates note with empty tags" {
    run "${OKM}" new "Plain Note"
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/plain-note.md"
    [ -f "$file" ]
    grep -q "tags: \[\]" "$file"
}

# === -t flag on okm capture ===

@test "okm capture -t adds extra tags alongside defaults" {
    run "${OKM}" capture "some text" -t "extra"
    assert_success
    local found
    found=$(find "${FAKE_VAULT_DIR}/public/inbox" -name '*.md' -newer "${FAKE_VAULT_DIR}" | head -1)
    [ -n "$found" ]
    grep -q "tags: \[capture, inbox, extra\]" "$found"
}

# === -t flag on okm spot ===

@test "okm spot -t adds extra tags to spotify note" {
    run "${OKM}" spot "https://open.spotify.com/track/6rqhFgbbKwnb9MLmUQDhG6" -t "favorite"
    assert_success
    local file="${FAKE_VAULT_DIR}/public/inbox/spotify-track-6rqhfgbbkwnb9mlmuqdhg6.md"
    [ -f "$file" ]
    grep -q "source/music, favorite" "$file"
}

# === Tagging-cluster regressions (B2, B3, B4, N10, N11, N17, N21, N22, N23) ===

# B2: okm tagged uses parsed-tag equality, not boundary regex.
@test "B2: okm tagged 'source' does not match notes tagged 'source/spotify'" {
    create_vault_file "public/inbox/exact.md" "---
tags: [source]
---"
    create_vault_file "public/inbox/hier.md" "---
tags: [source/spotify]
---"
    run "${OKM}" tagged "source"
    assert_success
    assert_output --partial "exact.md"
    refute_output --partial "hier.md"
}

@test "B2: okm tagged 'para' does not match 'para-tag' or 'parameters'" {
    create_vault_file "public/inbox/a.md" "---
tags: [para-tag]
---"
    create_vault_file "public/inbox/b.md" "---
tags: [parameters]
---"
    create_vault_file "public/inbox/c.md" "---
tags: [para]
---"
    run "${OKM}" tagged "para"
    assert_success
    assert_output --partial "c.md"
    refute_output --partial "a.md"
    refute_output --partial "b.md"
}

# N17: regex metacharacters in `okm tagged` are rejected, not interpreted.
@test "N17: okm tagged '.*' is rejected as invalid (no regex injection)" {
    create_vault_file "public/inbox/note.md" "---
tags: [foo]
---"
    run "${OKM}" tagged ".*"
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "N17: okm tagged 'foo|bar' is rejected as invalid" {
    create_vault_file "public/inbox/note.md" "---
tags: [foo, bar]
---"
    run "${OKM}" tagged "foo|bar"
    assert_failure
    assert_output --partial "Invalid tag"
}

# N10: hierarchical tags don't break the sed delimiter.
@test "N10: okm tag accepts hierarchical tag 'source/podcast' without sed errors" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "source/podcast"
    assert_success
    refute_output --partial "sed:"
    grep -q "tags: \[source/podcast\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

@test "N10: okm tag round-trips hierarchical tag through tagged" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    "${OKM}" tag "public/inbox/note.md" "source/podcast" >/dev/null
    run "${OKM}" tagged "source/podcast"
    assert_success
    assert_output --partial "note.md"
}

# N11: no-frontmatter file gets one prepended and the tag added.
@test "N11: okm tag on a file without frontmatter prepends one and adds the tag" {
    create_vault_file "public/inbox/plain.md" "Just plain text"
    run "${OKM}" tag "public/inbox/plain.md" "newtag"
    assert_success
    grep -q "^---$" "${FAKE_VAULT_DIR}/public/inbox/plain.md"
    grep -q "tags: \[newtag\]" "${FAKE_VAULT_DIR}/public/inbox/plain.md"
    grep -q "^Just plain text$" "${FAKE_VAULT_DIR}/public/inbox/plain.md"
}

@test "N11: okm untag on a file without frontmatter is a no-op (not a fake success)" {
    create_vault_file "public/inbox/plain.md" "Just plain text"
    run "${OKM}" untag "public/inbox/plain.md" "anything"
    assert_success
    assert_output --partial "No tags to remove"
    [ "$(cat "${FAKE_VAULT_DIR}/public/inbox/plain.md")" = "Just plain text" ]
}

# B4 + N23: invalid characters rejected at validation time.
@test "B4: okm tag rejects tag containing space" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "machine learning"
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "B4/N23: okm tag rejects tag containing ]" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "evil]"
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "B4: okm tag rejects tag containing :" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "foo:bar"
    assert_failure
    assert_output --partial "Invalid tag"
}

@test "B4: okm tag rejects tag containing comma" {
    create_vault_file "public/inbox/note.md" "---
tags: []
---"
    run "${OKM}" tag "public/inbox/note.md" "foo,bar"
    assert_failure
    assert_output --partial "Invalid tag"
}

# N21: body `---...---` blocks are not parsed as frontmatter.
@test "N21: okm tags <note> reads only the first frontmatter block" {
    create_vault_file "public/inbox/note.md" "---
tags: [real]
---
Body content.

---
tags: [body-fake]
---"
    run "${OKM}" tags "public/inbox/note.md"
    assert_success
    assert_output --partial "real"
    refute_output --partial "body-fake"
}

@test "N21: okm tag preserves body --- blocks verbatim" {
    create_vault_file "public/inbox/note.md" "---
tags: [original]
---
# Body

Quoting someone else's frontmatter:

---
tags: [example-in-body]
---

End."
    run "${OKM}" tag "public/inbox/note.md" "added"
    assert_success
    # Frontmatter tags updated:
    grep -q "^tags: \[original, added\]$" "${FAKE_VAULT_DIR}/public/inbox/note.md"
    # Body example preserved (still appears in the file):
    grep -q "^tags: \[example-in-body\]$" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

# N22: tags starting with `-` work safely thanks to `grep --`.
@test "N22: okm tag accepts tag starting with - without grep flag-injection error" {
    create_vault_file "public/inbox/note.md" "---
tags: [foo]
---"
    run "${OKM}" tag "public/inbox/note.md" "-leading-dash-tag"
    assert_success
    refute_output --partial "grep:"
    grep -q -- "tags: \[foo, -leading-dash-tag\]" "${FAKE_VAULT_DIR}/public/inbox/note.md"
}

# B3: Block-style YAML tags — tolerant read.
@test "B3: okm tags reads block-style tag list" {
    create_vault_file "public/inbox/block.md" "---
title: Block Tags
tags:
  - foo
  - bar
---
body"
    run "${OKM}" tags public/inbox/block.md
    assert_success
    assert_output --partial "foo"
    assert_output --partial "bar"
}

@test "B3: okm tagged finds note with block-style tags" {
    create_vault_file "public/inbox/block.md" "---
title: Block Tags
tags:
  - findme
---
body"
    run "${OKM}" tagged findme
    assert_success
    assert_output --partial "block.md"
}

@test "B3: okm tag appends to block-style tags without corrupting frontmatter" {
    create_vault_file "public/inbox/block.md" "---
title: Block Tags
tags:
  - existing
---
body"
    run "${OKM}" tag public/inbox/block.md newtag
    assert_success
    run "${OKM}" tags public/inbox/block.md
    assert_output --partial "existing"
    assert_output --partial "newtag"
}

# N30: has_frontmatter horizontal-rule false positive.
@test "N30: okm tag errors on note with lone --- (not real frontmatter)" {
    create_vault_file "public/inbox/hr.md" "---
This is just a horizontal rule, no closing delimiter
body content here"
    run "${OKM}" tag public/inbox/hr.md sometag
    assert_failure
    assert_output --partial "frontmatter"
}

@test "N30: okm tag succeeds on note with valid opening and closing ---" {
    create_vault_file "public/inbox/valid.md" "---
title: Valid
tags: []
---
body"
    run "${OKM}" tag public/inbox/valid.md sometag
    assert_success
    run "${OKM}" tags public/inbox/valid.md
    assert_output --partial "sometag"
}

# N31: write_tags_line preserves original file permissions.
@test "N31: okm tag preserves 644 permissions after write" {
    create_vault_file "public/inbox/perms.md" "---
title: Perms
tags: []
---
body"
    chmod 644 "${FAKE_VAULT_DIR}/public/inbox/perms.md"
    run "${OKM}" tag public/inbox/perms.md footag
    assert_success
    local perms
    perms=$(stat -c '%a' "${FAKE_VAULT_DIR}/public/inbox/perms.md")
    [ "$perms" = "644" ]
}

@test "N31: okm untag preserves 664 permissions after write" {
    create_vault_file "public/inbox/perms2.md" "---
title: Perms2
tags: [keeptag]
---
body"
    chmod 664 "${FAKE_VAULT_DIR}/public/inbox/perms2.md"
    run "${OKM}" untag public/inbox/perms2.md keeptag
    assert_success
    local perms
    perms=$(stat -c '%a' "${FAKE_VAULT_DIR}/public/inbox/perms2.md")
    [ "$perms" = "664" ]
}
