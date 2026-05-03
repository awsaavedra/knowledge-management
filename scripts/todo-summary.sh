#!/usr/bin/env bash
# todo-summary.sh — Scan project and vault for TODO markers and unchecked tasks,
# then generate a PARA-structured review checklist.
#
# Usage:
#   bash scripts/todo-summary.sh              # print today's scan to stdout
#   bash scripts/todo-summary.sh --output     # write/update yearly summary file
#
# Scanned markers: TODO, FIXME, HACK, XXX, REVIEW
# Also picks up unchecked markdown tasks: - [ ]
# Does NOT pick up checked items: - [x] or - [X]
#
# Output follows Tiago Forte's PARA structure:
#   Projects  — items from active project work (code markers, build tasks)
#   Areas     — ongoing responsibilities (unchecked tasks in notes)
#   Resources — items tagged for review or learning
#
# The --output file is a living yearly document (inbox/todo-summary-YYYY.md).
#   - One section per day (### YYYY-MM-DD), newest at top.
#   - Same-day re-runs replace that day's section.
#   - Unchecked items from the previous day carry forward into the new day.
#   - Checked items stay in the day they were checked off.
#   - Archive section lives at the bottom.
#   - A new file is created at the start of each year.
#
# Scheduled via Claude Code cron at 07:00, 12:00, and 15:00 daily.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="${KM_PROJECT_DIR:-${SCRIPT_DIR}}"
if [ -z "${OBSIDIAN_VAULT:-}" ]; then
    _parent="$(cd "${SCRIPT_DIR}/.." && pwd)"
    _sibling="${_parent}/knowledge-management"
    if [ "${_sibling}" = "${SCRIPT_DIR}" ]; then
        VAULT_DIR="${SCRIPT_DIR}"
    else
        VAULT_DIR="${_sibling}"
    fi
    unset _parent _sibling
else
    VAULT_DIR="${OBSIDIAN_VAULT}"
fi
YEAR="$(date +%Y)"
TODAY="$(date +%F)"
OUTPUT_FILE="${PROJECT_DIR}/inbox/todo-summary-${YEAR}.md"

WRITE_FILE=false
if [[ "${1:-}" == "--output" ]]; then
    WRITE_FILE=true
fi

# --- Shared scanning library ---
# shellcheck source=scripts/lib/scan.sh
source "${SCRIPT_DIR}/scripts/lib/scan.sh"

# --- Collectors for PARA buckets ---
projects_items=""
areas_items=""
resources_items=""

declare -A _title_cache

# Scan both directories
scan_directory "$PROJECT_DIR"
scan_directory "$VAULT_DIR"

# --- Build today's day section ---
day_section="### ${TODAY}

#### Projects

"

if [[ -n "$projects_items" ]]; then
    day_section+="${projects_items}
"
else
    day_section+="_No active project items._

"
fi

day_section+="#### Areas

"

if [[ -n "$areas_items" ]]; then
    day_section+="${areas_items}
"
else
    day_section+="_No area tasks._

"
fi

day_section+="#### Resources

"

if [[ -n "$resources_items" ]]; then
    day_section+="${resources_items}
"
else
    day_section+="_No review items._

"
fi

day_section+="---

"

# --- Frontmatter for new files ---
frontmatter="---
title: TODO Summary ${YEAR}
created: ${TODAY}
year: ${YEAR}
tags: [todo-summary, para, automated]
---

# TODO Summary — ${YEAR}

> Living document. Each scan adds a day section (newest at top).
> Unchecked items carry forward to the next day automatically.
> Check off items as you complete them — they stay as a record.

---

"

archive_section="## Archive

Move completed items here during your review.
"

if [[ "$WRITE_FILE" == true ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    rendered_day="$day_section"

    if [[ -f "$OUTPUT_FILE" ]]; then
        # Check if today's section already exists (same-day re-run)
        if grep -qn "^### ${TODAY}$" "$OUTPUT_FILE"; then
            # Extract the previous version of today's section to preserve checked items
            today_line=$(grep -n "^### ${TODAY}$" "$OUTPUT_FILE" | head -1 | cut -d: -f1)
            # Find the end of today's section (next ### or ## Archive)
            next_section_line=$(tail -n +$((today_line + 1)) "$OUTPUT_FILE" | grep -n '^\(### \|## Archive\)' | head -1 | cut -d: -f1)
            if [[ -n "$next_section_line" ]]; then
                today_end=$((today_line + next_section_line - 1))
            else
                today_end=$(wc -l < "$OUTPUT_FILE")
            fi

            # Get content before and after today's section
            header="$(head -n $((today_line - 1)) "$OUTPUT_FILE")"
            footer="$(tail -n +$((today_end + 1)) "$OUTPUT_FILE")"

            # Replace today's section with fresh scan
            {
                [[ -n "$header" ]] && printf '%s\n' "$header"
                printf '%s\n' "$rendered_day"
                [[ -n "$footer" ]] && printf '%s\n' "$footer"
            } > "$OUTPUT_FILE"
        else
            # New day: carry forward unchecked items from the most recent day section
            prev_day_line=$(grep -n '^### [0-9]' "$OUTPUT_FILE" | head -1 | cut -d: -f1)
            prev_section=""
            if [[ -n "$prev_day_line" ]]; then
                # Extract previous day's section
                next_after_prev=$(tail -n +$((prev_day_line + 1)) "$OUTPUT_FILE" | grep -n '^\(### \|## Archive\)' | head -1 | cut -d: -f1)
                if [[ -n "$next_after_prev" ]]; then
                    prev_end=$((prev_day_line + next_after_prev - 1))
                else
                    prev_end=$(wc -l < "$OUTPUT_FILE")
                fi
                prev_section="$(sed -n "${prev_day_line},${prev_end}p" "$OUTPUT_FILE")"
            fi

            # Merge carried items into today's section
            rendered_day="$(carry_forward_into "$rendered_day" "$prev_section")"

            # Insert today before the first existing day section (or before Archive)
            if [[ -n "$prev_day_line" ]]; then
                header="$(head -n $((prev_day_line - 1)) "$OUTPUT_FILE")"
                body="$(tail -n +${prev_day_line} "$OUTPUT_FILE")"
                printf '%s\n%s\n%s\n' "$header" "$rendered_day" "$body" > "$OUTPUT_FILE"
            else
                # No day sections yet — insert before Archive
                if grep -qn "^## Archive" "$OUTPUT_FILE"; then
                    archive_line=$(grep -n "^## Archive" "$OUTPUT_FILE" | head -1 | cut -d: -f1)
                    header="$(head -n $((archive_line - 1)) "$OUTPUT_FILE")"
                    footer="$(tail -n +${archive_line} "$OUTPUT_FILE")"
                    printf '%s\n%s\n%s\n' "$header" "$rendered_day" "$footer" > "$OUTPUT_FILE"
                else
                    # Append before archive (shouldn't happen with proper frontmatter)
                    printf '%s\n' "$rendered_day" >> "$OUTPUT_FILE"
                fi
            fi
        fi
    else
        # New file: frontmatter + first day section + archive
        {
            printf '%b' "$frontmatter"
            printf '%s\n\n' "$rendered_day"
            printf '%s\n' "$archive_section"
        } > "$OUTPUT_FILE"
    fi
    echo "Summary written to: ${OUTPUT_FILE}"
else
    printf '%s' "$day_section"
fi
