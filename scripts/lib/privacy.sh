#!/usr/bin/env bash
# privacy.sh — remote-visibility helpers for knowledge-management.
# Source this file; do not execute directly.
#
# Public API:
#   km_parse_github_slug URL          → prints "owner/repo" or nothing
#   km_repo_is_public_tool URL        → 0 if URL is the public tool repo (repo name = knowledge-management)
#   km_check_url_is_private URL       → 0 if private/no-remote, 1 if public/unverifiable
#   km_check_remote_is_private DIR    → same but reads origin URL from git repo at DIR
#   km_path_is_vault_content PATH     → 0 if path is personal vault content (note/attachment, not a template)

# Parse a GitHub SSH or HTTPS remote URL into "owner/repo".
# Prints nothing if the URL is not a GitHub URL.
km_parse_github_slug() {
    local url="$1"
    case "$url" in
        git@github.com:*)
            local s="${url#git@github.com:}"
            printf '%s\n' "${s%.git}"
            ;;
        https://github.com/*)
            local s="${url#https://github.com/}"
            s="${s%.git}"
            printf '%s\n' "${s%/}"
            ;;
    esac
}

# Returns 0 if URL is the public tool repo — the one whose repository name is
# exactly "knowledge-management". A personal vault is named
# "{handle}-knowledge-management", so it never matches. Deterministic and
# offline (no gh/network), which is what makes the contribution guard a hard
# guarantee rather than a best-effort visibility check.
km_repo_is_public_tool() {
    local slug
    slug="$(km_parse_github_slug "$1")"
    [ -n "$slug" ] || return 1
    [ "${slug##*/}" = "knowledge-management" ]
}

# km_check_url_is_private REMOTE_URL
# Returns:
#   0 — URL is empty (local-only), or the GitHub repo is confirmed private
#   1 — repo is public, non-GitHub, gh missing/unauthenticated
# Prints a human-readable reason to stderr on failure.
km_check_url_is_private() {
    local remote_url="$1"

    [ -n "$remote_url" ] || return 0   # no remote = local-only = safe

    local slug
    slug="$(km_parse_github_slug "$remote_url")"

    if [ -z "$slug" ]; then
        # Non-GitHub remote — we cannot verify visibility, but we also cannot block
        # users with legitimately private self-hosted remotes (GitLab, Gitea, etc.).
        # Warn and allow; the user is responsible for their own privacy on non-GitHub hosts.
        printf 'PRIVACY: Warning — cannot verify visibility of non-GitHub remote: %s\n' "$remote_url" >&2
        printf 'PRIVACY: Ensure this remote is private before pushing personal notes.\n' >&2
        return 0
    fi

    if ! command -v gh >/dev/null 2>&1; then
        printf 'PRIVACY: gh CLI not found — cannot verify that %s is private.\n' "$slug" >&2
        printf 'PRIVACY: Install gh (https://cli.github.com), then run: gh auth login\n' >&2
        return 1
    fi

    local is_private
    is_private="$(gh api "repos/$slug" --jq '.private' 2>/dev/null || true)"

    case "$is_private" in
        true)
            return 0
            ;;
        false)
            printf 'PRIVACY: Remote repo %s is PUBLIC.\n' "$slug" >&2
            printf 'PRIVACY: Refusing to track personal notes in a public repository.\n' >&2
            printf 'PRIVACY: Make the repository private on GitHub, then re-run setup.\n' >&2
            return 1
            ;;
        *)
            printf 'PRIVACY: Could not determine visibility of %s (gh API error or not authenticated).\n' "$slug" >&2
            printf 'PRIVACY: Run: gh auth login\n' >&2
            return 1
            ;;
    esac
}

# km_check_remote_is_private DIR
# Reads the origin remote URL from the git repo at DIR, then delegates to
# km_check_url_is_private. Returns 0 if safe, 1 if not.
km_check_remote_is_private() {
    local dir="${1:-.}"
    local remote_url
    remote_url="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
    km_check_url_is_private "$remote_url"
}

# km_path_is_vault_content PATH
# Returns 0 if PATH is personal vault content that must never reach the public
# tool repo: any file under public/ or private/, covering notes AND attachments.
# Excluded (legitimately shared): inbox templates and structural .gitkeep
# placeholders.
km_path_is_vault_content() {
    case "$1" in
        */.gitkeep)               return 1 ;;
        public/inbox/templates/*) return 1 ;;
        public/*|private/*)       return 0 ;;
    esac
    return 1
}
