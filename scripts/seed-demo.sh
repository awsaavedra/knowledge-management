#!/usr/bin/env bash
# seed-demo.sh — Populate the public PARA folders with demo-* files derived
# from inbox/templates/*. Use --teardown (or --clean) to remove only those
# files. Demo files are gitignored automatically (existing rules cover
# inbox/*.md, daily/*.md, archive/*.md, attachments/*.{png,...}).
#
# Usage:
#   bash scripts/seed-demo.sh             # seed demo dataset
#   bash scripts/seed-demo.sh --teardown  # remove every demo-* file
#   bash scripts/seed-demo.sh --clean     # alias for --teardown
#   bash scripts/seed-demo.sh --help      # this message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KM_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
VAULT="${OBSIDIAN_VAULT:-${KM_ROOT}}"
TEMPLATES="${KM_ROOT}/inbox/templates"

# 1x1 transparent PNG, base64-encoded. Used as a placeholder demo screenshot.
DEMO_PNG_B64='iVBORw0KGgoAAAANSUhEUgAAAAEAAAABAQAAAAA+UJ+JAAAACklEQVQI12NgAAAAAgABc3UBGAAAAABJRU5ErkJggg=='

usage() {
    cat <<'EOF'
Usage: seed-demo.sh [--teardown|--clean|--help]

Default: seed demo-* files into public PARA folders from inbox/templates/*.
--teardown / --clean: remove every demo-* file from the public PARA folders.
--help: this message.

After seeding, verify the dataset works:
  okm files demo-                 # list seeded files
  okm grep 'Format Specification' # confirm template content rendered
  okm today                       # daily/ exercise
  bash scripts/todo-summary.sh    # cron exercise (read-only, prints to stdout)
Then tear down:
  bash scripts/seed-demo.sh --teardown
EOF
}

# Strip the leading <!-- Format Specification ... --> block from a template
# so demo content reads cleanly. Returns the body on stdout.
strip_format_spec() {
    awk '
        BEGIN { in_spec = 0; done = 0 }
        !done && /^<!--$/ && NR == 1 { in_spec = 1; next }
        in_spec && /^-->$/ { in_spec = 0; done = 1; next }
        in_spec { next }
        { print }
    ' "$1"
}

# Render one template into a destination demo file, substituting common
# placeholders.
render_template() {
    local src="$1" dst="$2" title="$3"
    local today
    today="$(date +%Y-%m-%d)"
    strip_format_spec "$src" \
        | sed \
            -e "s|{{TITLE}}|${title}|g" \
            -e "s|{{DATE}}|${today}|g" \
            -e "s|{{CREATED}}|${today}|g" \
            -e "s|{{TIMESTAMP}}|$(date +%H:%M:%S)|g" \
            -e "s|{{TODAY}}|${today}|g" \
            -e "s|{{YEAR}}|$(date +%Y)|g" \
            -e "s|{{ARCHIVED_DATE}}|${today}|g" \
            -e "s|{{WEEK_START}}|${today}|g" \
            -e "s|{{WEEK_END}}|$(date -d '+6 days' +%Y-%m-%d 2>/dev/null || date -v+6d +%Y-%m-%d)|g" \
        > "$dst"
}

teardown() {
    local removed=0 dir
    for dir in daily inbox attachments archive; do
        if [ -d "${VAULT}/${dir}" ]; then
            while IFS= read -r -d '' f; do
                rm -f "$f" && removed=$((removed + 1))
            done < <(find "${VAULT}/${dir}" -maxdepth 1 -name 'demo-*' -type f -print0 2>/dev/null)
        fi
    done
    echo "Removed ${removed} demo-* files from ${VAULT}."
}

seed() {
    if [ ! -d "${TEMPLATES}" ]; then
        echo "ERROR: templates not found at ${TEMPLATES}" >&2
        exit 1
    fi

    local dir
    for dir in daily inbox attachments archive; do
        mkdir -p "${VAULT}/${dir}"
    done

    local today year week_end
    today="$(date +%Y-%m-%d)"
    year="$(date +%Y)"
    week_end="$(date -d '+6 days' +%Y-%m-%d 2>/dev/null || date -v+6d +%Y-%m-%d)"

    render_template "${TEMPLATES}/daily-template.md"           "${VAULT}/daily/demo-${today}.md"                              "${today}"
    render_template "${TEMPLATES}/note-template.md"            "${VAULT}/inbox/demo-meeting-notes.md"                          "Demo Meeting Notes"
    render_template "${TEMPLATES}/capture-template.md"         "${VAULT}/inbox/demo-capture.md"                                "Demo Capture"
    render_template "${TEMPLATES}/yt-template.md"              "${VAULT}/inbox/demo-yt-example.md"                             "Demo YouTube Example"
    render_template "${TEMPLATES}/spotify-episode-template.md" "${VAULT}/inbox/demo-spotify-episode.md"                        "Demo Spotify Episode"
    render_template "${TEMPLATES}/spotify-track-template.md"   "${VAULT}/inbox/demo-spotify-track.md"                          "Demo Spotify Track"
    render_template "${TEMPLATES}/podcast-template.md"         "${VAULT}/inbox/demo-podcast.md"                                "Demo Podcast"
    render_template "${TEMPLATES}/todo-summary-template.md"    "${VAULT}/inbox/demo-todo-summary-${year}.md"                   "Demo TODO Summary ${year}"
    render_template "${TEMPLATES}/weekly-template.md"          "${VAULT}/inbox/demo-weekly-${today}-to-${week_end}.md"         "Demo Weekly ${today} to ${week_end}"
    render_template "${TEMPLATES}/archive-template.md"         "${VAULT}/archive/demo-completed-project.md"                    "Demo Completed Project"

    # 1x1 placeholder PNG.
    printf '%s' "${DEMO_PNG_B64}" | base64 -d > "${VAULT}/attachments/demo-screenshot.png"

    cat <<EOF
Demo dataset seeded into ${VAULT}.

Verify it works:
  okm files demo-                 # list every seeded file
  okm grep 'demo'                 # spot-check content
  okm today                       # exercise daily/
  bash scripts/todo-summary.sh    # exercise cron scanner (stdout only)
  okm open inbox/demo-meeting-notes.md   # open a seeded note in your editor

Then tear down:
  bash scripts/seed-demo.sh --teardown
EOF
}

case "${1:-}" in
    --teardown|--clean) teardown ;;
    --help|-h)          usage ;;
    "")                 seed ;;
    *)                  usage; exit 1 ;;
esac
