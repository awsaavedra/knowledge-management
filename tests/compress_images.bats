#!/usr/bin/env bats
# Tests for scripts/compress-images.py — image compression and wikilink updater.

load 'helpers/test_helper'

setup() {
    common_setup

    COMPRESS_SCRIPT="${PROJECT_ROOT}/scripts/compress-images.py"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"

    mkdir -p "${FAKE_VAULT_DIR}/attachments"
}

has_pillow() {
    python3 -c "from PIL import Image" 2>/dev/null
}

# === Wikilink update logic (tested without actual image conversion) ===

@test "script exists and is valid Python" {
    python3 -c "import ast; ast.parse(open('${COMPRESS_SCRIPT}').read())"
}

@test "NOTE_DIRS includes archive and private dirs" {
    grep -q '"archive"' "${COMPRESS_SCRIPT}"
    grep -q '"private-daily"' "${COMPRESS_SCRIPT}"
    grep -q '"private-inbox"' "${COMPRESS_SCRIPT}"
}

@test "wikilink update path uses regex-bound matching (re.escape)" {
    grep -q 're.escape' "${COMPRESS_SCRIPT}"
}

@test "B1: adjacent filenames sharing a substring are not corrupted (foo.png vs super-foo.png)" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='red')
img.save('${FAKE_VAULT_DIR}/attachments/foo.png')
img.save('${FAKE_VAULT_DIR}/attachments/super-foo.png')
"
    create_vault_file "inbox/note.md" "Two images: ![[foo.png]] and ![[super-foo.png]] both shown."

    python3 "${COMPRESS_SCRIPT}"

    # foo.png link is rewritten to foo.webp; super-foo.png link is also rewritten
    # to super-foo.webp (its own conversion). What matters is the wikilink for
    # super-foo.png is NOT corrupted into super-foo.webp by the foo.png pass —
    # i.e., the file should never end up with `super-foo.webp.png` or the like.
    run cat "${FAKE_VAULT_DIR}/inbox/note.md"
    assert_output --partial "![[foo.webp]]"
    assert_output --partial "![[super-foo.webp]]"
    refute_output --partial "![[super-foo.webp.png]]"
    refute_output --partial "![[super-foo.png]]"
}

@test "B1: substring of filename in body prose is not rewritten" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='blue')
img.save('${FAKE_VAULT_DIR}/attachments/cat.png')
"
    # 'cat.png' is referenced as a wikilink AND appears as a non-link substring.
    create_vault_file "inbox/note.md" "Pic: ![[cat.png]]. Note: the file cat.png-archive is unrelated."

    python3 "${COMPRESS_SCRIPT}"

    run cat "${FAKE_VAULT_DIR}/inbox/note.md"
    assert_output --partial "![[cat.webp]]"
    # Body mention of cat.png-archive must be untouched (its filename ends in -archive)
    assert_output --partial "cat.png-archive"
    refute_output --partial "cat.webp-archive"
}

@test "B1: standard markdown image link [alt](path/foo.png) is rewritten" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='green')
img.save('${FAKE_VAULT_DIR}/attachments/diagram.png')
"
    create_vault_file "inbox/note.md" "![alt text](attachments/diagram.png)"

    python3 "${COMPRESS_SCRIPT}"

    run cat "${FAKE_VAULT_DIR}/inbox/note.md"
    assert_output --partial "attachments/diagram.webp"
    refute_output --partial "diagram.png"
}

@test "B1: wikilink with anchor or alt text is preserved (![[foo.png|caption]])" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='yellow')
img.save('${FAKE_VAULT_DIR}/attachments/anno.png')
"
    create_vault_file "inbox/note.md" "Annotated: ![[anno.png|My caption]]"

    python3 "${COMPRESS_SCRIPT}"

    run cat "${FAKE_VAULT_DIR}/inbox/note.md"
    assert_output --partial "![[anno.webp|My caption]]"
}

@test "dry-run mode does not modify files" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='red')
img.save('${FAKE_VAULT_DIR}/attachments/test.png')
"
    create_vault_file "inbox/note.md" "Look: ![[test.png]]"

    python3 "${COMPRESS_SCRIPT}" --dry-run

    [ -f "${FAKE_VAULT_DIR}/attachments/test.png" ]
    ! [ -f "${FAKE_VAULT_DIR}/attachments/test.webp" ]
    grep -q "test.png" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "conversion replaces original and updates wikilinks" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='blue')
img.save('${FAKE_VAULT_DIR}/attachments/photo.png')
"
    create_vault_file "inbox/note.md" "See ![[photo.png]] here"

    python3 "${COMPRESS_SCRIPT}"

    ! [ -f "${FAKE_VAULT_DIR}/attachments/photo.png" ]
    [ -f "${FAKE_VAULT_DIR}/attachments/photo.webp" ]
    grep -q "photo.webp" "${FAKE_VAULT_DIR}/inbox/note.md"
    ! grep -q "photo.png" "${FAKE_VAULT_DIR}/inbox/note.md"
}

@test "keep flag preserves original" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='green')
img.save('${FAKE_VAULT_DIR}/attachments/keep-me.jpg')
"

    python3 "${COMPRESS_SCRIPT}" --keep

    [ -f "${FAKE_VAULT_DIR}/attachments/keep-me.jpg" ]
    [ -f "${FAKE_VAULT_DIR}/attachments/keep-me.webp" ]
}

@test "already-converted files are skipped" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='white')
img.save('${FAKE_VAULT_DIR}/attachments/already.png')
img.save('${FAKE_VAULT_DIR}/attachments/already.webp')
"

    run python3 "${COMPRESS_SCRIPT}"
    assert_success
    assert_output --partial "already-converted"
}

@test "wikilinks in archive/ notes are updated" {
    if ! has_pillow; then skip "Pillow not installed"; fi

    python3 -c "
from PIL import Image
img = Image.new('RGB', (10, 10), color='yellow')
img.save('${FAKE_VAULT_DIR}/attachments/archived-img.png')
"
    create_vault_file "archive/old.md" "Image: ![[archived-img.png]]"

    python3 "${COMPRESS_SCRIPT}"

    grep -q "archived-img.webp" "${FAKE_VAULT_DIR}/archive/old.md"
}
