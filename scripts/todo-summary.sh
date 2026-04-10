#!/usr/bin/env bash
# todo-summary.sh — Scan project and vault for TODO markers and unchecked tasks,
# then generate a PARA-structured weekly review checklist.
#
# Usage:
#   bash scripts/todo-summary.sh              # print to stdout
#   bash scripts/todo-summary.sh --output     # write to inbox/todo-summary-<date>.md
#
# Scanned markers: TODO, FIXME, HACK, XXX, REVIEW
# Also picks up unchecked markdown tasks: - [ ]
#
# Output follows Tiago Forte's PARA structure:
#   Projects  — items from active project work (code markers, build tasks)
#   Areas     — ongoing responsibilities (unchecked tasks in notes)
#   Resources — items tagged for review or learning
#   Archive   — (section placeholder for manual use after completing items)
#
# Scheduled via Claude Code cron at 07:00 and 12:00 daily.

set -euo pipefail

PROJECT_DIR="/home/aws/workspace/knowledge-management"
VAULT_DIR="${OBSIDIAN_VAULT:-/home/aws/workspace/knowledge-management-system}"
DATE="$(date +%F)"
WEEK="$(date +%G-W%V)"
TIMESTAMP="$(date '+%F %H:%M')"
OUTPUT_FILE="${PROJECT_DIR}/inbox/todo-summary-${DATE}.md"

WRITE_FILE=false
if [[ "${1:-}" == "--output" ]]; then
    WRITE_FILE=true
fi

# --- Collectors for PARA buckets ---
projects_items=""
areas_items=""
resources_items=""

format_item() {
    local dir="$1"
    local line="$2"
    local relative="${line#"$dir"/}"
    local file_part="${relative%%:*}"
    local rest="${relative#*:}"
    local lineno="${rest%%:*}"
    local text="${rest#*:}"
    text="$(echo "$text" | sed 's/^[[:space:]]*//')"
    echo "- [ ] \`${file_part}:${lineno}\` — ${text}"
}

scan_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    # --- Projects: code markers (TODO, FIXME, HACK, XXX) from scripts, config, code ---
    local marker_hits
    marker_hits="$(rg -n --no-heading \
        --glob '*.sh' --glob '*.lua' --glob '*.yml' --glob '*.json' --glob '*.md' \
        --glob '!scripts/todo-summary.sh' \
        --glob '!inbox/todo-summary-*.md' \
        -e '\bTODO:' -e '\bFIXME:' -e '\bHACK:' -e '\bXXX:' \
        "$dir" 2>/dev/null || true)"

    if [[ -n "$marker_hits" ]]; then
        while IFS= read -r line; do
            projects_items+="$(format_item "$dir" "$line")\n"
        done <<< "$marker_hits"
    fi

    # --- Resources: REVIEW markers (things to read, evaluate, learn) ---
    local review_hits
    review_hits="$(rg -n --no-heading \
        --glob '*.sh' --glob '*.lua' --glob '*.yml' --glob '*.json' --glob '*.md' \
        --glob '!scripts/todo-summary.sh' \
        --glob '!inbox/todo-summary-*.md' \
        -e '\bREVIEW:' \
        "$dir" 2>/dev/null || true)"

    if [[ -n "$review_hits" ]]; then
        while IFS= read -r line; do
            resources_items+="$(format_item "$dir" "$line")\n"
        done <<< "$review_hits"
    fi

    # --- Areas: unchecked markdown tasks (ongoing responsibilities) ---
    local unchecked_tasks
    unchecked_tasks="$(rg -n --no-heading --glob '*.md' \
        --glob '!inbox/todo-summary-*.md' \
        -e '^\s*- \[ \]' \
        "$dir" 2>/dev/null || true)"

    if [[ -n "$unchecked_tasks" ]]; then
        while IFS= read -r line; do
            areas_items+="$(format_item "$dir" "$line")\n"
        done <<< "$unchecked_tasks"
    fi
}

# Scan both directories
scan_directory "$PROJECT_DIR"
scan_directory "$VAULT_DIR"

# --- Build the PARA-structured document ---
doc="---
title: Weekly Review ${WEEK}
created: ${TIMESTAMP}
date: ${DATE}
week: ${WEEK}
tags: [weekly-review, para, automated]
---

# Weekly Review — ${WEEK}

> PARA-structured task summary generated ${TIMESTAMP}.
> Scanned for \`TODO:\`, \`FIXME:\`, \`HACK:\`, \`XXX:\`, \`REVIEW:\` markers and unchecked \`- [ ]\` tasks.

---

## Projects

Active work with a clear end goal. Fix these, ship these, close these out.

"

if [[ -n "$projects_items" ]]; then
    doc+="${projects_items}\n"
else
    doc+="_No active project items found._\n\n"
fi

doc+="---

## Areas

Ongoing responsibilities and maintenance. These don't have a finish line — keep them healthy.

"

if [[ -n "$areas_items" ]]; then
    doc+="${areas_items}\n"
else
    doc+="_No area tasks found._\n\n"
fi

doc+="---

## Resources

Items to review, evaluate, or learn from. Move to Projects once you decide to act.

"

if [[ -n "$resources_items" ]]; then
    doc+="${resources_items}\n"
else
    doc+="_No review items found._\n\n"
fi

doc+="---

## Archive

Move completed items here during your review. Nothing lands here automatically.

- _(drag completed items from above)_
"

if [[ "$WRITE_FILE" == true ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"
    printf '%b' "$doc" > "$OUTPUT_FILE"
    echo "Summary written to: ${OUTPUT_FILE}"
else
    printf '%b' "$doc"
fi
