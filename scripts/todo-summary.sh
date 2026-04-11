#!/usr/bin/env bash
# todo-summary.sh — Scan project and vault for TODO markers and unchecked tasks,
# then generate a PARA-structured review checklist.
#
# Usage:
#   bash scripts/todo-summary.sh              # print latest scan to stdout
#   bash scripts/todo-summary.sh --output     # append scan to yearly summary file
#
# Scanned markers: TODO, FIXME, HACK, XXX, REVIEW
# Also picks up unchecked markdown tasks: - [ ]
# Does NOT pick up checked items: - [x] or - [X]
#
# Output follows Tiago Forte's PARA structure:
#   Projects  — items from active project work (code markers, build tasks)
#   Areas     — ongoing responsibilities (unchecked tasks in notes)
#   Resources — items tagged for review or learning
#   Archive   — (section placeholder for manual use after completing items)
#
# The --output file is a living yearly document (inbox/todo-summary-YYYY.md).
# Each scan prepends a timestamped section at the top (below frontmatter).
# Items you check off in the summary stay as a record of accomplishments.
# A new file is created at the start of each year.
#
# Scheduled via Claude Code cron at 07:00, 12:00, and 15:00 daily.

set -euo pipefail

PROJECT_DIR="${KMS_PROJECT_DIR:-/home/aws/workspace/knowledge-management}"
VAULT_DIR="${OBSIDIAN_VAULT:-/home/aws/workspace/knowledge-management-system}"
YEAR="$(date +%Y)"
WEEK="$(date +%G-W%V)"
TIMESTAMP="$(date '+%F %H:%M')"
OUTPUT_FILE="${PROJECT_DIR}/inbox/todo-summary-${YEAR}.md"

WRITE_FILE=false
if [[ "${1:-}" == "--output" ]]; then
    WRITE_FILE=true
fi

# --- Collectors for PARA buckets ---
projects_items=""
areas_items=""
resources_items=""

# Cache note titles to avoid re-reading the same file
declare -A _title_cache

# Extract a human-readable title from a file.
#   .md files: try YAML frontmatter "title:", then first "# heading", then filename stem.
#   other files: filename only.
get_title() {
    local filepath="$1"

    if [[ -n "${_title_cache["$filepath"]+x}" ]]; then
        echo "${_title_cache["$filepath"]}"
        return
    fi

    local title=""

    if [[ "$filepath" == *.md ]]; then
        if [[ -f "$filepath" ]]; then
            title="$(sed -n '/^---$/,/^---$/{/^title:/{ s/^title:[[:space:]]*//; s/^["'\''"]//; s/["'\''"]$//; p; q; }}' "$filepath")"
        fi
        if [[ -z "$title" && -f "$filepath" ]]; then
            title="$(sed -n 's/^# *//p' "$filepath" | head -1)"
        fi
        if [[ -z "$title" ]]; then
            title="$(basename "$filepath" .md)"
        fi
    else
        title="$(basename "$filepath")"
    fi

    _title_cache["$filepath"]="$title"
    echo "$title"
}

format_item() {
    local dir="$1"
    local line="$2"
    local relative="${line#"$dir"/}"
    local file_part="${relative%%:*}"
    local rest="${relative#*:}"
    local lineno="${rest%%:*}"
    local text="${rest#*:}"
    text="$(echo "$text" | sed 's/^[[:space:]]*//')"
    # Strip leading "- [ ] " from unchecked task text so it doesn't double up
    text="$(echo "$text" | sed 's/^- \[ \] *//')"

    local title
    title="$(get_title "${dir}/${file_part}")"

    echo "- [ ] **${title}** (\`${file_part}:${lineno}\`) — ${text}"
}

scan_directory() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        return
    fi

    # Common exclusions: self, previous summaries, test fixtures
    local -a exclude_globs=(
        --glob '!**/todo-summary.sh'
        --glob '!**/todo-summary-*.md'
        --glob '!tests/**'
    )

    # --- Projects: code markers (TODO, FIXME, HACK, XXX) from scripts, config, code ---
    local marker_hits
    marker_hits="$(rg -n --no-heading \
        --glob '*.sh' --glob '*.lua' --glob '*.yml' --glob '*.json' --glob '*.md' \
        "${exclude_globs[@]}" \
        -e '\bTODO:' -e '\bFIXME:' -e '\bHACK:' -e '\bXXX:' \
        "$dir" 2>/dev/null || true)"

    if [[ -n "$marker_hits" ]]; then
        while IFS= read -r line; do
            # Skip markdown table rows (documentation about markers, not actual markers)
            local text_part="${line#*:*:}"
            if [[ "$text_part" == *"|"*"TODO:"*"|"* || "$text_part" == *"|"*"FIXME:"*"|"* || \
                  "$text_part" == *"|"*"HACK:"*"|"* || "$text_part" == *"|"*"XXX:"*"|"* ]]; then
                continue
            fi
            projects_items+="$(format_item "$dir" "$line")\n"
        done <<< "$marker_hits"
    fi

    # --- Resources: REVIEW markers (things to read, evaluate, learn) ---
    local review_hits
    review_hits="$(rg -n --no-heading \
        --glob '*.sh' --glob '*.lua' --glob '*.yml' --glob '*.json' --glob '*.md' \
        "${exclude_globs[@]}" \
        -e '\bREVIEW:' \
        "$dir" 2>/dev/null || true)"

    if [[ -n "$review_hits" ]]; then
        while IFS= read -r line; do
            local text_part="${line#*:*:}"
            if [[ "$text_part" == *"|"*"REVIEW:"*"|"* ]]; then
                continue
            fi
            resources_items+="$(format_item "$dir" "$line")\n"
        done <<< "$review_hits"
    fi

    # --- Areas: unchecked markdown tasks (ongoing responsibilities) ---
    local unchecked_tasks
    unchecked_tasks="$(rg -n --no-heading --glob '*.md' \
        "${exclude_globs[@]}" \
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

# --- Build the scan section ---
scan_section="### Scan — ${TIMESTAMP}

#### Projects

"

if [[ -n "$projects_items" ]]; then
    scan_section+="${projects_items}\n"
else
    scan_section+="_No active project items._\n\n"
fi

scan_section+="#### Areas

"

if [[ -n "$areas_items" ]]; then
    scan_section+="${areas_items}\n"
else
    scan_section+="_No area tasks._\n\n"
fi

scan_section+="#### Resources

"

if [[ -n "$resources_items" ]]; then
    scan_section+="${resources_items}\n"
else
    scan_section+="_No review items._\n\n"
fi

scan_section+="---

"

# --- Frontmatter for new files ---
frontmatter="---
title: TODO Summary ${YEAR}
created: ${TIMESTAMP}
year: ${YEAR}
tags: [todo-summary, para, automated]
---

# TODO Summary — ${YEAR}

> Living document. Each cron scan prepends a timestamped section below.
> Check off items as you complete them — they stay as a record of accomplishments.
> New file each year.

---

## Archive

Move completed items here during your review.

---

"

if [[ "$WRITE_FILE" == true ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    if [[ -f "$OUTPUT_FILE" ]]; then
        # Existing file: prepend the new scan below frontmatter
        if grep -qn "^### Scan" "$OUTPUT_FILE"; then
            # File has previous scans — insert new scan before the first one
            first_scan_line=$(grep -n "^### Scan" "$OUTPUT_FILE" | head -1 | cut -d: -f1)
            header="$(head -n $((first_scan_line - 1)) "$OUTPUT_FILE")"
            body="$(tail -n +${first_scan_line} "$OUTPUT_FILE")"
            printf '%s\n%b%s\n' "$header" "$scan_section" "$body" > "$OUTPUT_FILE"
        else
            # First scan in this file — append after header
            printf '%b' "$scan_section" >> "$OUTPUT_FILE"
        fi
    else
        # New file: write frontmatter + first scan
        printf '%b' "$frontmatter" > "$OUTPUT_FILE"
        printf '%b' "$scan_section" >> "$OUTPUT_FILE"
    fi
    echo "Summary written to: ${OUTPUT_FILE}"
else
    # Stdout mode: just print the scan (no file manipulation)
    printf '%b' "$scan_section"
fi
