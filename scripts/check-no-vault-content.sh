#!/usr/bin/env bash
# check-no-vault-content.sh — fail if any input path is personal vault content.
#
# Reads candidate paths from stdin (one per line) and tests each against
# km_path_is_vault_content. This is the git-agnostic core of the contribution
# guard: the caller chooses which paths to feed in (a pushed tree, a staged
# diff, the tracked file list), so this stays a pure, independently testable
# seam with no knowledge of git.
#
# Usage:  <path-producer> | check-no-vault-content.sh [-q|--quiet]
# Output: offending paths on stdout (suppressed with --quiet)
# Exit:   0 = no vault content   1 = vault content found   2 = usage error
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/privacy.sh
source "${SCRIPT_DIR}/lib/privacy.sh"

quiet=false
case "${1:-}" in
    -q|--quiet) quiet=true ;;
    "")         ;;
    *)          echo "check-no-vault-content.sh: unknown argument '$1'" >&2; exit 2 ;;
esac

found=false
while IFS= read -r path; do
    [ -n "$path" ] || continue
    if km_path_is_vault_content "$path"; then
        found=true
        $quiet || printf '%s\n' "$path"
    fi
done

$found && exit 1
exit 0
