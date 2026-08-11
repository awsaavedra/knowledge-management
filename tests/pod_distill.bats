#!/usr/bin/env bats
# Tests for okm pod (local-file capture) and okm distill (AI summary).
# Offline by design: okm never transcribes audio; claude / ollama are stubbed.

load 'helpers/test_helper'

setup() {
    common_setup

    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="public/daily"
    export OBSIDIAN_NOTES_DIR="public/inbox"
    # Use 'true' as editor so exec doesn't launch an interactive editor
    export EDITOR="true"

    STUB_DIR="${BATS_TEST_TMPDIR}/stub"
    mkdir -p "${STUB_DIR}"

    AUDIO_FILE="${BATS_TEST_TMPDIR}/morning-episode.mp3"
    : > "${AUDIO_FILE}"
}

# Stub an LLM CLI: drains stdin, emits a fixed summary.
stub_llm() {
    printf '#!/bin/sh\ncat >/dev/null\necho "- %s stub summary"\n' "$1" > "${STUB_DIR}/$1"
    chmod +x "${STUB_DIR}/$1"
    export PATH="${STUB_DIR}:${PATH}"
}

make_note() {
    local f="${FAKE_VAULT_DIR}/public/inbox/source-note.md"
    printf -- '---\ntitle: "Source"\ntags: [test]\n---\n\n# Source\n\nBody text.\n' > "$f"
    echo "public/inbox/source-note.md"
}

# === okm pod — local file capture (no ASR; we never transcribe audio) ===

@test "okm pod: requires a link or file argument" {
    run "${OKM}" pod
    assert_failure
    assert_output --partial "Podcast link or file required"
}

@test "okm pod: rejects a nonexistent path that is not a link" {
    export OKM_POD_OFFLINE=1
    run "${OKM}" pod "${BATS_TEST_TMPDIR}/missing.mp3"
    assert_failure
    assert_output --partial "Not a link or a readable file"
}

@test "okm pod: a raw audio file becomes a metadata scaffold (no transcription)" {
    local today; today="$(date +%F)"
    run "${OKM}" pod "${AUDIO_FILE}"
    assert_success
    local f="${FAKE_VAULT_DIR}/public/inbox/podcast-MorningEpisode-${today}.md"
    [ -f "$f" ]
    run grep -q 'source_type: podcast' "$f"; assert_success
    run grep -q 'source_platform: local' "$f"; assert_success
    run grep -q 'source_file: "morning-episode.mp3"' "$f"; assert_success
    run grep -q 'captured_via: okm-pod' "$f"; assert_success
    run grep -q 'source/podcast' "$f"; assert_success
    run grep -q 'does not transcribe audio' "$f"; assert_success
}

@test "okm pod: uses an explicit title for the filename and heading" {
    local today; today="$(date +%F)"
    run "${OKM}" pod "${AUDIO_FILE}" Deep Work Episode
    assert_success
    assert_output --partial "Created: public/inbox/podcast-DeepWorkEpisode-${today}.md"
    local f="${FAKE_VAULT_DIR}/public/inbox/podcast-DeepWorkEpisode-${today}.md"
    run grep -q '^# Deep Work Episode' "$f"; assert_success
}

@test "okm pod: -t merges custom tags with source/podcast" {
    local today; today="$(date +%F)"
    "${OKM}" pod -t finance "${AUDIO_FILE}" >/dev/null
    local f="${FAKE_VAULT_DIR}/public/inbox/podcast-MorningEpisode-${today}.md"
    run grep -q 'finance' "$f"; assert_success
    run grep -q 'source/podcast' "$f"; assert_success
}

@test "okm pod: second run reports existing note instead of overwriting" {
    "${OKM}" pod "${AUDIO_FILE}" >/dev/null
    run "${OKM}" pod "${AUDIO_FILE}"
    assert_success
    assert_output --partial "Exists:"
}

# === okm distill — AI summary ===

@test "okm distill: requires a note argument" {
    run "${OKM}" distill
    assert_failure
    assert_output --partial "Note required"
}

@test "okm distill: rejects a nonexistent note" {
    run "${OKM}" distill public/inbox/no-such-note.md
    assert_failure
    assert_output --partial "Note not found"
}

@test "okm distill: rejects an unknown model" {
    local note; note="$(make_note)"
    run "${OKM}" distill "$note" --model gpt
    assert_failure
    assert_output --partial "unknown model 'gpt'"
}

@test "okm distill: --model requires a value" {
    local note; note="$(make_note)"
    run "${OKM}" distill "$note" --model
    assert_failure
    assert_output --partial "requires a value"
}

@test "okm distill: accepts --model before the note argument" {
    local note; note="$(make_note)"
    run "${OKM}" distill --model bogus "$note"
    assert_failure
    assert_output --partial "unknown model 'bogus'"
}

@test "okm distill: claude stub writes a distilled note with frontmatter" {
    stub_llm claude
    local note; note="$(make_note)"
    run "${OKM}" distill "$note"
    assert_success
    assert_output --partial "Created: public/inbox/source-note-distilled.md"
    local f="${FAKE_VAULT_DIR}/public/inbox/source-note-distilled.md"
    run grep -q 'distilled_by: claude' "$f"; assert_success
    run grep -q 'source_note: "public/inbox/source-note.md"' "$f"; assert_success
    run grep -q -- '- claude stub summary' "$f"; assert_success
}

@test "okm distill: --model ollama uses the ollama stub" {
    stub_llm ollama
    local note; note="$(make_note)"
    run "${OKM}" distill "$note" --model ollama
    assert_success
    local f="${FAKE_VAULT_DIR}/public/inbox/source-note-distilled.md"
    run grep -q 'distilled_by: ollama' "$f"; assert_success
    run grep -q -- '- ollama stub summary' "$f"; assert_success
}

@test "okm distill: reports an existing distilled note instead of overwriting" {
    stub_llm claude
    local note; note="$(make_note)"
    "${OKM}" distill "$note" >/dev/null
    run "${OKM}" distill "$note"
    assert_success
    assert_output --partial "already exists"
}

@test "okm distill: fails clearly when the claude CLI is absent" {
    export PATH="/usr/bin:/bin"
    if command -v claude >/dev/null 2>&1; then
        skip "claude resolvable from /usr/bin:/bin — absence not testable"
    fi
    local note; note="$(make_note)"
    run "${OKM}" distill "$note"
    assert_failure
    assert_output --partial "'claude' CLI not found"
}
