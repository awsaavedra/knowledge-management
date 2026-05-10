#!/usr/bin/env bash
# Audits the repo for open-source release readiness.
# Exits 0 = clean, 1 = warnings only, 2 = blockers found.
# Run from anywhere inside the repo; uses git to scope checks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; BOLD='\033[1m'; RESET='\033[0m'
exit_code=0
total_fails=0
total_warns=0

_fail() { printf "${RED}[FAIL]${RESET} %s\n" "$*"; (( total_fails++ )) || true; exit_code=2; }
_warn() { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; (( total_warns++ )) || true; [ "$exit_code" -lt 2 ] && exit_code=1; }
_ok()   { printf "${GREEN}[ OK ]${RESET} %s\n" "$*"; }
_head() { printf "\n${BOLD}%s${RESET}\n" "$*"; }

# ── 1. Binary / large files currently tracked in index ──────────────────────
_head "1. Tracked binaries & large files (current index)"

tracked_bins=$(git ls-files -- bin/nvim bin/nvim.bin bin/lazygit 2>/dev/null || true)
if [ -n "$tracked_bins" ]; then
  _fail "Compiled binaries still tracked in git index:"
  echo "$tracked_bins" | sed 's/^/       /'
else
  _ok "No nvim/lazygit binaries in index"
fi

tracked_nvim_runtime=$(git ls-files -- 'bin/nvim-runtime/' 2>/dev/null | head -3 || true)
if [ -n "$tracked_nvim_runtime" ]; then
  count=$(git ls-files -- 'bin/nvim-runtime/' | wc -l)
  _fail "bin/nvim-runtime/ still tracked ($count files); example:"
  echo "$tracked_nvim_runtime" | sed 's/^/       /'
else
  _ok "bin/nvim-runtime/ not in index"
fi

# Files over 1 MB tracked in index
large_tracked=$(git ls-tree -r -l HEAD 2>/dev/null \
  | awk '$4 > 1048576 {printf "%8.1f KB  %s\n", $4/1024, $5}' || true)
if [ -n "$large_tracked" ]; then
  _warn "Tracked files >1 MB:"
  echo "$large_tracked" | sed 's/^/       /'
else
  _ok "No tracked files >1 MB"
fi

# ── 2. Binary / large objects in git history ────────────────────────────────
_head "2. Large objects in git history (top 10)"

large_history=$(git rev-list --objects --branches 2>/dev/null \
  | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' 2>/dev/null \
  | awk '$1=="blob" && $3>524288 {printf "%8.1f KB  %s\n", $3/1024, $4}' \
  | sort -rn \
  | head -10 || true)
if [ -n "$large_history" ]; then
  _warn "Objects >512 KB in history (may inflate clone size):"
  echo "$large_history" | sed 's/^/       /'
else
  _ok "No objects >512 KB in history"
fi

# ── 3. Personal notes currently tracked ─────────────────────────────────────
_head "3. Personal notes in current index"

tracked_daily=$(git ls-files -- 'daily/' | grep '\.md$' || true)
if [ -n "$tracked_daily" ]; then
  _fail "Daily notes still tracked:"
  echo "$tracked_daily" | sed 's/^/       /'
else
  _ok "No daily/*.md in index"
fi

# inbox/*.md — but keep inbox/templates/ (those are source files)
tracked_inbox=$(git ls-files -- 'inbox/' | grep '\.md$' | grep -v '^inbox/templates/' || true)
if [ -n "$tracked_inbox" ]; then
  _fail "Personal inbox notes still tracked (non-template):"
  echo "$tracked_inbox" | sed 's/^/       /'
else
  _ok "No personal inbox/*.md in index"
fi

# Templates must always be present
missing_templates=()
for tmpl in daily-template note-template capture-template yt-template \
            spotify-episode-template spotify-track-template podcast-template \
            todo-summary-template weekly-template archive-template; do
  git ls-files --error-unmatch "inbox/templates/${tmpl}.md" &>/dev/null \
    || missing_templates+=("inbox/templates/${tmpl}.md")
done
if [ "${#missing_templates[@]}" -gt 0 ]; then
  _fail "Required templates missing from index:"
  printf '       %s\n' "${missing_templates[@]}"
else
  _ok "All 10 templates present in index"
fi

# ── 4. Personal notes in git history (reachable from any ref) ───────────────
_head "4. Personal notes in git history"

history_notes=$(git log --branches --name-only --pretty=format: \
  | grep -v '^$' | sort -u \
  | grep -E '^(daily/|inbox/).*\.md$' \
  | grep -v '^inbox/templates/' || true)
if [ -n "$history_notes" ]; then
  _fail "Personal note paths still in git history:"
  echo "$history_notes" | sed 's/^/       /'
else
  _ok "No personal notes in history"
fi

# ── 5. PII patterns in tracked text files ───────────────────────────────────
_head "5. PII patterns in tracked files"

# Emails
pii_email=$(git grep -rn --cached \
  -E '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}' \
  -- '*.md' '*.sh' '*.py' '*.yml' '*.yaml' '*.json' '*.txt' 2>/dev/null \
  | grep -v 'tests/lib/' \
  | grep -v 'example@\|user@example\|your-email\|placeholder\|noreply@\|@anthropic\|git@github' \
  || true)
if [ -n "$pii_email" ]; then
  _warn "Possible email addresses in tracked files:"
  echo "$pii_email" | sed 's/^/       /'
else
  _ok "No obvious email addresses in tracked files"
fi

# GitHub handles / personal URLs (hardcoded non-placeholder usernames)
pii_handle=$(git grep -rn --cached \
  -E 'github\.com/[a-zA-Z0-9_-]+/knowledge-management' \
  -- '*.md' '*.sh' '*.yml' '*.yaml' 2>/dev/null \
  | grep -v 'tests/lib/' \
  | grep -v '{your-handle}\|{handle}\|YOUR_HANDLE\|placeholder' \
  || true)
if [ -n "$pii_handle" ]; then
  _warn "Hardcoded GitHub handle/URL (should be placeholder):"
  echo "$pii_handle" | sed 's/^/       /'
else
  _ok "No hardcoded GitHub handle in tracked files"
fi

# ── 6. Secrets / credentials ─────────────────────────────────────────────────
_head "6. Secrets & credentials"

secret_patterns=(
  'AKIA[0-9A-Z]{16}'          # AWS access key
  'sk-[a-zA-Z0-9]{32,}'       # OpenAI/Anthropic key prefix
  'ghp_[a-zA-Z0-9]{36}'       # GitHub PAT
  'xox[baprs]-[0-9a-zA-Z]+'   # Slack token
  'BEGIN (RSA|EC|OPENSSH) PRIVATE'
  'password\s*=\s*[^$\{]'
  'secret\s*=\s*[^$\{]'
  'api.key\s*=\s*[^$\{]'
)

found_secrets=0
for pat in "${secret_patterns[@]}"; do
  hits=$(git grep -rn --cached -iE "$pat" \
    -- '*.md' '*.sh' '*.py' '*.yml' '*.yaml' '*.env' '*.json' 2>/dev/null \
    | grep -v 'tests/lib/' || true)
  if [ -n "$hits" ]; then
    _fail "Possible secret matching pattern '$pat':"
    echo "$hits" | sed 's/^/       /'
    found_secrets=1
  fi
done
[ "$found_secrets" -eq 0 ] && _ok "No obvious secrets/credentials in tracked files"

# ── 7. .gitignore coverage ───────────────────────────────────────────────────
_head "7. .gitignore coverage"

missing_ignores=()
for pat in 'bin/nvim' 'bin/lazygit' 'bin/nvim-runtime' 'venv/' '.env'; do
  if ! grep -qF "$pat" .gitignore 2>/dev/null; then
    missing_ignores+=("$pat")
  fi
done
if [ "${#missing_ignores[@]}" -gt 0 ]; then
  _warn ".gitignore missing rules for: ${missing_ignores[*]}"
else
  _ok ".gitignore covers binaries, venv, and .env"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}────────────────────────────────────────${RESET}\n"
printf "${BOLD}Summary:${RESET} %d failure(s), %d warning(s)\n" "$total_fails" "$total_warns"
if [ "$exit_code" -eq 0 ]; then
  printf "${GREEN}${BOLD}READY — repo appears clean for open-source release.${RESET}\n"
elif [ "$exit_code" -eq 1 ]; then
  printf "${YELLOW}${BOLD}WARNINGS — review items above before releasing.${RESET}\n"
else
  printf "${RED}${BOLD}BLOCKED — resolve failures before releasing.${RESET}\n"
fi
printf "${BOLD}────────────────────────────────────────${RESET}\n\n"

exit "$exit_code"
