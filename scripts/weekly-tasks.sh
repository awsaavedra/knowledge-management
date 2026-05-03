#!/usr/bin/env bash
# weekly-tasks.sh — Scan project and vault for TODO markers and unchecked tasks,
# then push results to a weekly file (one per Mon–Sun week).
#
# Usage:
#   bash scripts/weekly-tasks.sh              # print today's scan to stdout
#   bash scripts/weekly-tasks.sh --output     # write/update weekly file
#
# Scanned markers: TODO, FIXME, HACK, XXX, REVIEW
# Also picks up unchecked markdown tasks: - [ ]
#
# Output follows PARA structure (Projects / Areas / Resources).
#
# Weekly file: inbox/weekly-YYYY-MM-DD-to-YYYY-MM-DD.md (Mon to Sun).
#   - One section per day (### YYYY-MM-DD Weekday), newest at top.
#   - Same-day re-runs replace that day's section.
#   - Unchecked items from the previous day carry forward.
#   - On Monday, unchecked items from last week's file carry forward.
#   - Checked items stay in the day they were checked off.
#
# Scheduled via cron at 07:00, 12:00, and 15:00 daily.

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
TEMPLATE="${PROJECT_DIR}/inbox/weekly-template.md"

TODAY="$(date +%F)"
DOW="$(date +%u)"  # 1=Monday, 7=Sunday
DAY_NAME="$(date +%A)"

# Compute this week's Monday and Sunday
WEEK_START="$(date -d "${TODAY} -$((DOW - 1)) days" +%F)"
WEEK_END="$(date -d "${TODAY} +$((7 - DOW)) days" +%F)"

OUTPUT_FILE="${PROJECT_DIR}/inbox/weekly-${WEEK_START}-to-${WEEK_END}.md"

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
day_section="### ${TODAY} ${DAY_NAME}

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

# --- Find the previous week's file for Monday carry-forward ---
get_prev_week_file() {
    local prev_monday prev_sunday prev_file
    prev_monday="$(date -d "${WEEK_START} -7 days" +%F)"
    prev_sunday="$(date -d "${WEEK_END} -7 days" +%F)"
    prev_file="${PROJECT_DIR}/inbox/weekly-${prev_monday}-to-${prev_sunday}.md"
    if [[ -f "$prev_file" ]]; then
        echo "$prev_file"
    fi
}

# Extract the last day section from a file (the most recent ### heading)
get_last_day_section() {
    local file="$1"
    local last_day_line next_line section_end

    last_day_line="$(grep -n '^### [0-9]' "$file" | head -1 | cut -d: -f1)"
    if [[ -z "$last_day_line" ]]; then
        return
    fi

    next_line="$(tail -n +$((last_day_line + 1)) "$file" | grep -n '^\(### [0-9]\)' | head -1 | cut -d: -f1)"
    if [[ -n "$next_line" ]]; then
        section_end=$((last_day_line + next_line - 1))
    else
        section_end=$(wc -l < "$file")
    fi

    sed -n "${last_day_line},${section_end}p" "$file"
}

if [[ "$WRITE_FILE" == true ]]; then
    mkdir -p "$(dirname "$OUTPUT_FILE")"

    if [[ ! -f "$OUTPUT_FILE" ]]; then
        # New week: create from template
        if [[ -f "$TEMPLATE" ]]; then
            sed -e "s/{{WEEK_START}}/${WEEK_START}/g" \
                -e "s/{{WEEK_END}}/${WEEK_END}/g" \
                "$TEMPLATE" > "$OUTPUT_FILE"
        else
            cat > "$OUTPUT_FILE" <<EOF
---
title: "Weekly Tasks — ${WEEK_START} to ${WEEK_END}"
created: "${WEEK_START}"
week_start: "${WEEK_START}"
week_end: "${WEEK_END}"
tags: [weekly-tasks, para, automated]
---

# Weekly Tasks — ${WEEK_START} to ${WEEK_END}

> Auto-generated weekly task file. Each cron run adds/updates the day's section.
> Unchecked items carry forward from the previous day or prior week.
> Check off items as you complete them — they stay as a record.

---

EOF
        fi

        # On Monday (or first run of the week), carry forward from last week
        prev_week_file="$(get_prev_week_file)"
        prev_section=""
        if [[ -n "$prev_week_file" ]]; then
            prev_section="$(get_last_day_section "$prev_week_file")"
        fi

        day_section="$(carry_forward_into "$day_section" "$prev_section")"

        # Append today's section
        printf '%s\n' "$day_section" >> "$OUTPUT_FILE"
    else
        # File exists for this week
        if grep -qn "^### ${TODAY}" "$OUTPUT_FILE"; then
            # Same-day re-run: replace today's section
            today_line=$(grep -n "^### ${TODAY}" "$OUTPUT_FILE" | head -1 | cut -d: -f1)
            next_section_line=$(tail -n +$((today_line + 1)) "$OUTPUT_FILE" | grep -n '^### [0-9]' | head -1 | cut -d: -f1 || true)
            if [[ -n "$next_section_line" ]]; then
                today_end=$((today_line + next_section_line - 1))
            else
                today_end=$(wc -l < "$OUTPUT_FILE")
            fi

            header="$(head -n $((today_line - 1)) "$OUTPUT_FILE")"
            footer=""
            if [[ "$today_end" -lt "$(wc -l < "$OUTPUT_FILE")" ]]; then
                footer="$(tail -n +$((today_end + 1)) "$OUTPUT_FILE")"
            fi

            {
                printf '%s\n' "$header"
                printf '%s\n' "$day_section"
                [[ -n "$footer" ]] && printf '%s\n' "$footer"
            } > "$OUTPUT_FILE"
        else
            # New day within the same week: carry forward from previous day
            prev_section="$(get_last_day_section "$OUTPUT_FILE")"
            day_section="$(carry_forward_into "$day_section" "$prev_section")"

            # Insert at top (after frontmatter/header, before other day sections)
            first_day_line="$(grep -n '^### [0-9]' "$OUTPUT_FILE" | head -1 | cut -d: -f1)"
            if [[ -n "$first_day_line" ]]; then
                header="$(head -n $((first_day_line - 1)) "$OUTPUT_FILE")"
                body="$(tail -n +${first_day_line} "$OUTPUT_FILE")"
                printf '%s\n%s\n%s\n' "$header" "$day_section" "$body" > "$OUTPUT_FILE"
            else
                # No day sections yet — append
                printf '%s\n' "$day_section" >> "$OUTPUT_FILE"
            fi
        fi
    fi
    echo "Weekly tasks written to: ${OUTPUT_FILE}"
else
    printf '%s' "$day_section"
fi
