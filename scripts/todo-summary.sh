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
PROJECT_DIR="${KMS_PROJECT_DIR:-${SCRIPT_DIR}}"
VAULT_DIR="${OBSIDIAN_VAULT:-$(cd "${SCRIPT_DIR}/.." && pwd)/knowledge-management-system}"
YEAR="$(date +%Y)"
TODAY="$(date +%F)"
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

# --- Build today's day section ---
day_section="### ${TODAY}

#### Projects

"

if [[ -n "$projects_items" ]]; then
    day_section+="${projects_items}\n"
else
    day_section+="_No active project items._\n\n"
fi

day_section+="#### Areas

"

if [[ -n "$areas_items" ]]; then
    day_section+="${areas_items}\n"
else
    day_section+="_No area tasks._\n\n"
fi

day_section+="#### Resources

"

if [[ -n "$resources_items" ]]; then
    day_section+="${resources_items}\n"
else
    day_section+="_No review items._\n\n"
fi

day_section+="---

"

# --- Carry forward: merge unchecked items from previous day into today's section ---
# Reads the new day section line by line. When it hits a bucket boundary (#### Areas,
# #### Resources, ---), it first emits any carried items for the bucket that just ended.
carry_forward_into() {
    local new_section="$1"
    local prev_section="$2"

    if [[ -z "$prev_section" ]]; then
        echo "$new_section"
        return
    fi

    # Extract unchecked items from previous day, grouped by PARA bucket
    local prev_projects prev_areas prev_resources
    prev_projects="$(echo "$prev_section" | sed -n '/^#### Projects/,/^#### Areas/p' | grep '^\- \[ \]' || true)"
    prev_areas="$(echo "$prev_section" | sed -n '/^#### Areas/,/^#### Resources/p' | grep '^\- \[ \]' || true)"
    prev_resources="$(echo "$prev_section" | sed -n '/^#### Resources/,/^---$/p' | grep '^\- \[ \]' || true)"

    # Build result line by line, injecting carried items at bucket boundaries
    local current_bucket=""
    local result=""
    while IFS= read -r line; do
        case "$line" in
            "#### Projects") current_bucket="projects" ;;
            "#### Areas")
                # Emit carried project items before switching to Areas
                if [[ -n "$prev_projects" ]]; then
                    while IFS= read -r item; do
                        if ! echo "$new_section" | grep -qF "$item"; then
                            result+="${item}"$'\n'
                        fi
                    done <<< "$prev_projects"
                fi
                current_bucket="areas"
                ;;
            "#### Resources")
                # Emit carried area items before switching to Resources
                if [[ -n "$prev_areas" ]]; then
                    while IFS= read -r item; do
                        if ! echo "$new_section" | grep -qF "$item"; then
                            result+="${item}"$'\n'
                        fi
                    done <<< "$prev_areas"
                fi
                current_bucket="resources"
                ;;
            "---")
                # Emit carried resource items before the closing ---
                if [[ "$current_bucket" == "resources" ]]; then
                    if [[ -n "$prev_resources" ]]; then
                        while IFS= read -r item; do
                            if ! echo "$new_section" | grep -qF "$item"; then
                                result+="${item}"$'\n'
                            fi
                        done <<< "$prev_resources"
                    fi
                    current_bucket=""
                fi
                ;;
        esac
        result+="${line}"$'\n'
    done <<< "$new_section"

    echo "$result"
}

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

    # Render day_section (resolve \n escapes)
    rendered_day="$(printf '%b' "$day_section")"

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
    # Stdout mode: just print today's section
    printf '%b' "$day_section"
fi
