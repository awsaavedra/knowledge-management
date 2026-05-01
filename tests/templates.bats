#!/usr/bin/env bats
# Tests for inbox/templates/ — the canonical markdown templates for every
# file type the system produces.

load 'helpers/test_helper'

setup() {
    common_setup
    TEMPLATES_DIR="${PROJECT_ROOT}/inbox/templates"
}

EXPECTED_TEMPLATES=(
    daily-template.md
    note-template.md
    capture-template.md
    yt-template.md
    spotify-episode-template.md
    spotify-track-template.md
    podcast-template.md
    todo-summary-template.md
    weekly-template.md
    archive-template.md
)

@test "inbox/templates/ directory exists" {
    [ -d "${PROJECT_ROOT}/inbox/templates" ]
}

@test "all 10 expected templates exist" {
    for tpl in "${EXPECTED_TEMPLATES[@]}"; do
        [ -f "${PROJECT_ROOT}/inbox/templates/${tpl}" ]
    done
}

@test "every template begins with a Format Specification block" {
    for tpl in "${EXPECTED_TEMPLATES[@]}"; do
        local f="${PROJECT_ROOT}/inbox/templates/${tpl}"
        # First non-blank line must be the opening HTML comment
        head -1 "$f" | grep -q '^<!--$'
        # Within the first 6 lines, the spec keyword appears
        head -6 "$f" | grep -q 'Format Specification:'
    done
}

@test "every template names a Producer in its spec block" {
    for tpl in "${EXPECTED_TEMPLATES[@]}"; do
        head -10 "${PROJECT_ROOT}/inbox/templates/${tpl}" | grep -q 'Producer:'
    done
}

@test "every template has YAML frontmatter after the spec block" {
    for tpl in "${EXPECTED_TEMPLATES[@]}"; do
        # First two `---` lines must come after the spec block (within 30 lines)
        local count
        count=$(head -30 "${PROJECT_ROOT}/inbox/templates/${tpl}" | grep -c '^---$' || true)
        [ "$count" -ge 2 ]
    done
}

@test "no leftover *-format-template* templates at top of inbox" {
    # Old naming was inbox/yt-note-format-template.md and
    # inbox/spotify-note-format-template.md. After Phase 2 those should
    # only exist under inbox/templates/.
    ! ls "${PROJECT_ROOT}/inbox/"*-format-template.md 2>/dev/null
}
