#!/usr/bin/env bats
# Phase 3 coverage: .envrc, enriched templates, _skills docs.

load 'helpers/test_helper'

setup() {
    common_setup
}

# --- .envrc / direnv auto-activation ---

@test ".envrc exists at project root" {
    [ -f "${PROJECT_ROOT}/.envrc" ]
}

@test ".envrc sources env.sh via direnv source_env" {
    grep -q '^source_env env.sh' "${PROJECT_ROOT}/.envrc"
}

@test ".envrc documents direnv setup steps" {
    grep -q 'direnv allow' "${PROJECT_ROOT}/.envrc"
}

# --- Enriched video / podcast templates ---

ENRICHED_TEMPLATES=(
    video-template.md
    podcast-template.md
)

@test "enriched templates have an Actionable Insights section" {
    for tpl in "${ENRICHED_TEMPLATES[@]}"; do
        grep -q '^## Actionable Insights$' "${PROJECT_ROOT}/public/inbox/templates/${tpl}"
    done
}

@test "enriched templates have a Sources Cited section" {
    for tpl in "${ENRICHED_TEMPLATES[@]}"; do
        grep -q '^## Sources Cited$' "${PROJECT_ROOT}/public/inbox/templates/${tpl}"
    done
}

@test "enriched templates have a Follow-ups section with checkbox" {
    for tpl in "${ENRICHED_TEMPLATES[@]}"; do
        local f="${PROJECT_ROOT}/public/inbox/templates/${tpl}"
        grep -q '^## Follow-ups$' "$f"
        grep -q '^- \[ \] Follow-up' "$f"
    done
}

@test "video-template marks Screenshots as REQUIRED" {
    local f="${PROJECT_ROOT}/public/inbox/templates/video-template.md"
    grep -q 'Screenshots (REQUIRED' "$f"
    grep -q 'REQUIRED for video notes' "$f"
}

@test "podcast-template marks Key Quotes as REQUIRED audio substitute" {
    local f="${PROJECT_ROOT}/public/inbox/templates/podcast-template.md"
    grep -q 'Key Quotes (REQUIRED' "$f"
    grep -q 'REQUIRED for audio-only sources' "$f"
}

# --- docs/skills/transcripts.md ---

@test "docs/skills/transcripts.md exists" {
    [ -f "${PROJECT_ROOT}/docs/skills/transcripts.md" ]
}

@test "transcripts skill specifies whisperX large-v3-turbo" {
    grep -q 'large-v3-turbo' "${PROJECT_ROOT}/docs/skills/transcripts.md"
}

@test "transcripts skill mandates speaker diarization" {
    grep -q -- '--diarize' "${PROJECT_ROOT}/docs/skills/transcripts.md"
}

@test "transcripts skill specifies float32 (no compression)" {
    grep -q 'compute_type float32' "${PROJECT_ROOT}/docs/skills/transcripts.md"
}

# --- docs/skills/distill-prompt.md ---

@test "docs/skills/distill-prompt.md exists" {
    [ -f "${PROJECT_ROOT}/docs/skills/distill-prompt.md" ]
}

@test "distill skill names the four required output sections" {
    local f="${PROJECT_ROOT}/docs/skills/distill-prompt.md"
    grep -q 'Summary' "$f"
    grep -q 'Actionable Insights' "$f"
    grep -q 'Sources Cited' "$f"
    grep -q 'Follow-ups' "$f"
}

@test "distill skill forbids hallucinated citations" {
    grep -qi 'hallucination\|do not invent\|Citing sources that aren' "${PROJECT_ROOT}/docs/skills/distill-prompt.md"
}

@test "distill skill calls out contradictions explicitly" {
    grep -qi 'contradict' "${PROJECT_ROOT}/docs/skills/distill-prompt.md"
}
