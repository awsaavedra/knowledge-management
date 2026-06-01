#!/usr/bin/env bats
# tests/v1_spec.bats — Implementation specs for all v1 work.
#
# Each test is a skipped regression/spec that encodes the full bug description
# or feature design so this file alone is sufficient to implement v1 from scratch.
#
# Roadmap reference: README.md § Roadmap → v1
# When a test is implemented, remove the skip and move passing tests to the
# appropriate domain file (tagging.bats, okm_cli.bats, path_safety.bats, etc.).
#
# Run only this file: bash tests/run_all.sh tests/v1_spec.bats

load 'helpers/test_helper'

setup() {
    common_setup
    OKM="${PROJECT_ROOT}/bin/okm"
    export OBSIDIAN_VAULT="${FAKE_VAULT_DIR}"
    export OBSIDIAN_DAILY_DIR="public/daily"
    export OBSIDIAN_NOTES_DIR="public/inbox"
    export EDITOR="true"
}

# =============================================================================
# N9: okm spot — URL escape in markdown link
# =============================================================================
# okm spot generates: [Listen on Spotify](${url})
# If the Spotify URL contains ) or backtick characters the markdown link
# syntax breaks: the ) closes the link prematurely, backtick opens a code span.
#
# Fix: percent-encode ) as %29 and ` as %60 in the URL before embedding,
# or use angle-bracket form: [Listen on Spotify](<${url}>).
# Angle-bracket form is CommonMark-compliant and handles all special chars.

@test "N9: okm spot URL with ) does not break markdown link syntax" {
    skip "v1: spot URL escape not yet implemented"
    # Simulate a note already written with a URL containing )
    # The fix must be in the template substitution in bin/okm spot handler.
    # Verify the generated note parses as valid markdown (link has matching parens).
    create_vault_file "public/inbox/spot-paren.md" "---
title: Track With Paren
tags: [source/spotify]
---
[Listen on Spotify](https://open.spotify.com/track/abc?si=foo%29bar)"
    # A markdown parser reading this must see one complete link, not two fragments.
    # Acceptance: the url in the link does not contain a bare unescaped ).
    run grep -oP '\[Listen on Spotify\]\(<?\K[^)>]+' \
        "${FAKE_VAULT_DIR}/public/inbox/spot-paren.md"
    refute_output --partial ")"
}

# =============================================================================
# F2: okm spot — document network requirement
# =============================================================================
# okm spot fetches Spotify metadata over the network. v0 has no offline-mode
# docs and no error message distinguishing "bad URL" from "no network".
#
# Fix: add to okm spot handler — if spotdl/network call fails, emit:
#   "okm spot requires network access. Check connectivity or use --offline."
# Also: update README offline mode table to list okm spot as networked.
# (README already done. This test covers the error message.)

@test "F2: okm spot emits network-required message on fetch failure" {
    skip "v1: spot network error message not yet implemented"
    # Simulate no network by pointing spotdl to /dev/null or a fake
    # Force failure by passing an invalid URL
    run "${OKM}" spot "https://open.spotify.com/track/INVALID000000"
    assert_failure
    assert_output --partial "network"
}

# =============================================================================
# F6: KM_TRACK_NOTES — default must be true across all subcommands
# =============================================================================
# v0 inconsistency: when KM_TRACK_NOTES is unset (not exported), some
# subcommands treat it as false (skip git operations) while others treat it
# as true (attempt git add). The authoritative default is true.
#
# Fix: in bin/okm, normalize at the top: KM_TRACK_NOTES="${KM_TRACK_NOTES:-true}"
# This must happen before any subcommand dispatch.
# Affected subcommands: okm new, okm today, okm capture (all write notes).

@test "F6: okm new with KM_TRACK_NOTES unset behaves same as KM_TRACK_NOTES=true" {
    skip "v1: KM_TRACK_NOTES default unification not yet done"
    unset KM_TRACK_NOTES
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    run "${OKM}" new "consistency test"
    assert_success
    # With KM_TRACK_NOTES defaulting to true, the new note should be git-added
    local status
    status=$(git -C "${FAKE_VAULT_DIR}" status --porcelain)
    [[ "$status" == *"public/inbox/"* ]]
}

@test "F6: okm today with KM_TRACK_NOTES unset behaves same as KM_TRACK_NOTES=true" {
    skip "v1: KM_TRACK_NOTES default unification not yet done"
    unset KM_TRACK_NOTES
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    run "${OKM}" today
    assert_success
    local status
    status=$(git -C "${FAKE_VAULT_DIR}" status --porcelain)
    [[ "$status" == *"public/daily/"* ]]
}

# =============================================================================
# F7: Cron tests — decouple from README strings
# =============================================================================
# tests/cron.bats currently hard-codes schedule strings copied from README
# (e.g. "3 7,12,15 * * *"). When README is updated the tests drift silently.
#
# Fix: cron tests should assert behavioral output (script produces correct file,
# correct content) not that README contains specific text. Remove any test that
# does grep README for cron schedule strings.

@test "F7: cron tests do not grep README for schedule strings" {
    skip "v1: cron test decoupling not yet done"
    # Acceptance: no test in cron.bats should contain 'grep.*README' or
    # assert_output against cron schedule strings sourced from README.
    run grep -c 'README' "${PROJECT_ROOT}/tests/cron.bats"
    assert_output "0"
}

# =============================================================================
# N6: README dual-mode architecture diagram
# =============================================================================
# When the project directory name matches the vault directory name
# (e.g. both are "knowledge-management"), the architecture diagram in README
# shows them as separate paths but they are actually the same directory.
# This confuses first-time users who clone and find vault + app co-located.
#
# Fix: README Architecture section should note: "If $OBSIDIAN_VAULT is unset
# and the default sibling path resolves to the same directory as the project,
# vault and app are co-located. Use $OBSIDIAN_VAULT to separate them."
# Also: verify-km.sh should warn when project dir == vault dir.

@test "N6: verify-km warns when project dir equals vault dir" {
    skip "v1: dual-mode co-location warning not yet implemented"
    export OBSIDIAN_VAULT="${PROJECT_ROOT}"
    run bash "${PROJECT_ROOT}/scripts/verify-km.sh"
    assert_output --partial "co-located"
}

# =============================================================================
# N7: okm version / --version flag
# =============================================================================
# No version command exists. When users fork and file bugs, there is no way
# to identify which version of okm they are running.
#
# Fix: add to bin/okm dispatch:
#   version|--version) echo "okm v1.0.0"; exit 0 ;;
# Version string should be a single source of truth — define as variable at
# top of bin/okm: OKM_VERSION="1.0.0"

@test "N7: okm version prints version string" {
    skip "v1: okm version not yet implemented"
    run "${OKM}" version
    assert_success
    assert_output --partial "okm v"
}

@test "N7: okm --version prints version string" {
    skip "v1: okm --version not yet implemented"
    run "${OKM}" --version
    assert_success
    assert_output --partial "okm v"
}

# =============================================================================
# N8: verify-km.sh — report direnv / .envrc state
# =============================================================================
# verify-km.sh does not check whether direnv is installed or whether
# the .envrc is allowed. Users who skip `direnv allow .` get silent
# failures where env vars are never set.
#
# Fix: add to verify-km.sh:
#   1. Check `which direnv` — WARN if not installed
#   2. Check `direnv status` exit code — WARN if .envrc is blocked/not allowed
#   3. Print: "Run: direnv allow . to activate auto-loading"

@test "N8: verify-km reports direnv not installed" {
    skip "v1: verify-km direnv check not yet implemented"
    # PATH without direnv
    local orig_path="$PATH"
    export PATH="${TEST_TEMP_DIR}/empty_bin:${PATH}"
    mkdir -p "${TEST_TEMP_DIR}/empty_bin"
    run bash "${PROJECT_ROOT}/scripts/verify-km.sh"
    # Should WARN, not FAIL (direnv is optional)
    assert_output --partial "direnv"
    export PATH="$orig_path"
}

# =============================================================================
# okm sync — warn on uncommon file extensions
# =============================================================================
# Before staging all files in okm sync, check for extensions that are likely
# mistakes: .env, .pem, .key, common binary types (.exe, .dll, .so, .dylib),
# database files (.db, .sqlite).
#
# Fix: in okm sync, before `git add -A`:
#   suspicious=$(git -C "$vault" diff --name-only HEAD -- '*.env' '*.pem' ...)
#   if [[ -n "$suspicious" ]]; then
#       echo "WARNING: suspicious files staged: $suspicious"
#       echo "Set KM_FORCE_SYNC=1 to override."
#       exit 1
#   fi

@test "okm sync warns before staging .env file" {
    skip "v1: okm sync extension check not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/note.md" "safe"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
    create_vault_file ".env" "SECRET=hunter2"
    run "${OKM}" sync
    assert_failure
    assert_output --partial "suspicious"
}

@test "okm sync allows .env override with KM_FORCE_SYNC=1" {
    skip "v1: okm sync extension check not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/note.md" "safe"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
    create_vault_file ".env" "SECRET=hunter2"
    KM_FORCE_SYNC=1 run "${OKM}" sync
    # May fail for other reasons (no remote) but must not fail on extension check
    refute_output --partial "suspicious"
}

# =============================================================================
# okm audit --json
# =============================================================================
# okm audit currently prints human-readable text only. v1 adds --json output
# for machine consumption (pre-commit hooks, CI pipelines).
#
# JSON schema:
#   {
#     "findings": [
#       { "type": "secret|para|filename", "file": "path", "line": N, "match": "..." }
#     ],
#     "summary": { "total": N, "secrets": N, "para": N, "filenames": N }
#   }
# Exit code: 0 if no findings, 1 if any finding.

@test "okm audit --json outputs valid JSON" {
    skip "v1: okm audit --json not yet implemented"
    create_vault_file "public/inbox/clean.md" "---
title: Clean
tags: [foo]
---
clean content"
    run "${OKM}" audit --json
    assert_success
    # Basic JSON structure check
    assert_output --partial '"findings"'
    assert_output --partial '"summary"'
}

@test "okm audit --json includes secret findings" {
    skip "v1: okm audit --json not yet implemented"
    create_vault_file "public/inbox/oops.md" "---
title: Oops
---
AKIA1234567890EXAMPLE"
    run "${OKM}" audit --json
    assert_failure
    assert_output --partial '"type": "secret"'
}

# =============================================================================
# okm rename-tag <old> <new>
# =============================================================================
# Renames a tag across all notes in the vault.
# Equivalent to: okm tagged <old> | xargs -I{} okm untag {} <old> && okm tag {} <new>
# But atomic per-file and safe against partial failure.
#
# Fix: add rename-tag subcommand to bin/okm dispatch.
#   For each file returned by tagged <old>: untag <old>, tag <new>.
#   Print count of files updated.

@test "okm rename-tag renames tag across all notes" {
    skip "v1: okm rename-tag not yet implemented"
    create_vault_file "public/inbox/a.md" "---\ntitle: A\ntags: [oldtag]\n---"
    create_vault_file "public/inbox/b.md" "---\ntitle: B\ntags: [oldtag, other]\n---"
    run "${OKM}" rename-tag oldtag newtag
    assert_success
    run "${OKM}" tagged oldtag
    assert_output ""
    run "${OKM}" tagged newtag
    assert_output --partial "a.md"
    assert_output --partial "b.md"
}

# =============================================================================
# -t flag on okm today
# =============================================================================
# okm new and okm capture accept -t tag1,tag2 at creation time.
# okm today does not. v1 adds symmetry.

@test "okm today -t sets tags in frontmatter" {
    skip "v1: -t flag on okm today not yet implemented"
    run "${OKM}" today -t work,journal
    assert_success
    local today
    today=$(date +%Y-%m-%d)
    run grep "tags:" "${FAKE_VAULT_DIR}/public/daily/${today}.md"
    assert_output --partial "work"
    assert_output --partial "journal"
}

# =============================================================================
# okm tags --json
# =============================================================================
# okm tags currently prints "tag (N)" human-readable lines.
# v1 adds --json: [{"tag":"foo","count":3}, ...]

@test "okm tags --json outputs valid JSON array" {
    skip "v1: okm tags --json not yet implemented"
    create_vault_file "public/inbox/a.md" "---\ntitle: A\ntags: [foo, bar]\n---"
    create_vault_file "public/inbox/b.md" "---\ntitle: B\ntags: [foo]\n---"
    run "${OKM}" tags --json
    assert_success
    assert_output --partial '"tag"'
    assert_output --partial '"count"'
    assert_output --partial '"foo"'
}

# =============================================================================
# okm private <subcmd> — write-side private namespace
# =============================================================================
# v0 private support is read-side only: grep/tags/files/tagged skip private-*/
# by default. There is no write-side: no command puts notes INTO private-*.
#
# v1 design:
#   okm private new <title>    → creates in private/inbox/
#   okm private today          → creates/opens in private/daily/
#   okm private capture [text] → creates in private/inbox/ (timestamped)
#
# Implementation: okm private dispatches to the same underlying functions
# as new/today/capture but overrides OBSIDIAN_NOTES_DIR=private/inbox and
# OBSIDIAN_DAILY_DIR=private/daily before calling them.
# The private-* dirs must already exist (setup-km.sh creates them).

@test "okm private new creates note in private/inbox" {
    skip "v1: okm private not yet implemented"
    mkdir -p "${FAKE_VAULT_DIR}/private/inbox"
    run "${OKM}" private new "secret project"
    assert_success
    local slug="secret-project"
    [ -f "${FAKE_VAULT_DIR}/private/inbox/${slug}.md" ]
}

@test "okm private today creates daily note in private/daily" {
    skip "v1: okm private not yet implemented"
    mkdir -p "${FAKE_VAULT_DIR}/private/daily"
    run "${OKM}" private today
    assert_success
    local today
    today=$(date +%Y-%m-%d)
    [ -f "${FAKE_VAULT_DIR}/private/daily/${today}.md" ]
}

@test "okm private capture adds note to private/inbox" {
    skip "v1: okm private not yet implemented"
    mkdir -p "${FAKE_VAULT_DIR}/private/inbox"
    run "${OKM}" private capture "secret thought"
    assert_success
    run find "${FAKE_VAULT_DIR}/private/inbox" -name "*.md"
    assert_output --partial ".md"
}

# =============================================================================
# okm crypt init
# =============================================================================
# git-crypt initialisation as a first-class subcommand. Currently users must
# run git-crypt init manually and write .gitattributes by hand.
#
# okm crypt init should:
#   1. Check git-crypt is installed; error if not.
#   2. Run git-crypt init in the vault repo.
#   3. Append to .gitattributes (idempotent):
#        daily/*.md filter=git-crypt diff=git-crypt
#        inbox/*.md filter=git-crypt diff=git-crypt
#   4. Export key to ~/git-crypt-km.key with a warning to back it up.
#   5. Print next-step instructions.

@test "okm crypt init requires git-crypt to be installed" {
    skip "v1: okm crypt init not yet implemented"
    local orig_path="$PATH"
    export PATH="${TEST_TEMP_DIR}/empty_bin"
    mkdir -p "${TEST_TEMP_DIR}/empty_bin"
    run "${OKM}" crypt init
    assert_failure
    assert_output --partial "git-crypt"
    export PATH="$orig_path"
}

@test "okm crypt init writes .gitattributes entries" {
    skip "v1: okm crypt init not yet implemented"
    # Requires git-crypt installed — skip if not available
    which git-crypt || skip "git-crypt not installed"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    run "${OKM}" crypt init
    assert_success
    run cat "${FAKE_VAULT_DIR}/.gitattributes"
    assert_output --partial "daily/*.md filter=git-crypt"
    assert_output --partial "inbox/*.md filter=git-crypt"
}

# =============================================================================
# Fork-safety: okm port <handle>
# =============================================================================
# Full design: README.md § Fork-safety architecture → Approach A
#
# okm port flow:
#   1. Preconditions: gh CLI installed + auth OK; clean working tree; okm audit passes.
#   2. gh repo create {handle}-knowledge-management --private --clone=false
#   3. git remote rename origin upstream
#   4. git remote set-url --push upstream DISABLED
#   5. git remote add origin git@github.com:{handle}/{handle}-knowledge-management.git
#   6. Install pre-push hook (see content below).
#   7. git push -u origin main  (skipped if --no-push)
#   8. Print topology summary.
#
# Pre-push hook content (.git/hooks/pre-push, mode 755):
# -------------------------------------------------------
#   #!/usr/bin/env bash
#   # Installed by okm port. Blocks pushes to the public OSS upstream.
#   REMOTE_URL="$2"
#   BLOCKLIST="${KM_UPSTREAM_PATTERN:-knowledge-management}"
#   if [[ "$REMOTE_URL" =~ $BLOCKLIST ]]; then
#     if [[ "${KM_ALLOW_UPSTREAM_PUSH:-0}" != "1" ]]; then
#       echo "ERROR: push to upstream OSS blocked. Remote: $REMOTE_URL" >&2
#       echo "Override: KM_ALLOW_UPSTREAM_PUSH=1 git push ..." >&2
#       exit 1
#     fi
#   fi
# -------------------------------------------------------
# okm sync uses git push with no remote arg (bin/okm:639), following @{u}
# tracking branch — safe by construction once origin points at the private repo.

@test "okm port installs pre-push hook" {
    skip "v1: okm port not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    run "${OKM}" port testhandle --no-push
    assert_success
    [ -x "${FAKE_VAULT_DIR}/.git/hooks/pre-push" ]
}

@test "okm port sets upstream push URL to DISABLED" {
    skip "v1: okm port not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    git -C "${FAKE_VAULT_DIR}" remote add origin "https://github.com/upstream/knowledge-management.git"
    run "${OKM}" port testhandle --no-push
    assert_success
    local push_url
    push_url=$(git -C "${FAKE_VAULT_DIR}" remote get-url --push upstream)
    assert_output --partial "DISABLED"
}

@test "pre-push hook blocks push to upstream URL" {
    skip "v1: okm port not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    # Install hook directly
    mkdir -p "${FAKE_VAULT_DIR}/.git/hooks"
    cat > "${FAKE_VAULT_DIR}/.git/hooks/pre-push" <<'HOOK'
#!/usr/bin/env bash
REMOTE_URL="$2"
BLOCKLIST="${KM_UPSTREAM_PATTERN:-knowledge-management}"
if [[ "$REMOTE_URL" =~ $BLOCKLIST ]]; then
    if [[ "${KM_ALLOW_UPSTREAM_PUSH:-0}" != "1" ]]; then
        echo "ERROR: push to upstream OSS blocked. Remote: $REMOTE_URL" >&2
        exit 1
    fi
fi
HOOK
    chmod 755 "${FAKE_VAULT_DIR}/.git/hooks/pre-push"
    run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" upstream \
        "https://github.com/user/knowledge-management.git"
    assert_failure
    assert_output --partial "blocked"
}

@test "pre-push hook allows override with KM_ALLOW_UPSTREAM_PUSH=1" {
    skip "v1: okm port not yet implemented"
    mkdir -p "${FAKE_VAULT_DIR}/.git/hooks"
    cat > "${FAKE_VAULT_DIR}/.git/hooks/pre-push" <<'HOOK'
#!/usr/bin/env bash
REMOTE_URL="$2"
BLOCKLIST="${KM_UPSTREAM_PATTERN:-knowledge-management}"
if [[ "$REMOTE_URL" =~ $BLOCKLIST ]]; then
    if [[ "${KM_ALLOW_UPSTREAM_PUSH:-0}" != "1" ]]; then
        echo "ERROR: push to upstream OSS blocked." >&2
        exit 1
    fi
fi
HOOK
    chmod 755 "${FAKE_VAULT_DIR}/.git/hooks/pre-push"
    KM_ALLOW_UPSTREAM_PUSH=1 run bash "${FAKE_VAULT_DIR}/.git/hooks/pre-push" \
        upstream "https://github.com/user/knowledge-management.git"
    assert_success
}

@test "okm port refuses if working tree is dirty" {
    skip "v1: okm port not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/uncommitted.md" "dirty"
    run "${OKM}" port testhandle --no-push
    assert_failure
    assert_output --partial "clean"
}

@test "okm sync refuses if origin URL matches upstream blocklist" {
    skip "v1: okm sync upstream guard not yet implemented"
    # Misconfigured: origin still points at public OSS
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    git -C "${FAKE_VAULT_DIR}" remote add origin \
        "https://github.com/upstream/knowledge-management.git"
    create_vault_file "public/inbox/note.md" "body"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
    run "${OKM}" sync
    assert_failure
    assert_output --partial "upstream"
}

# =============================================================================
# Polish items
# =============================================================================

@test "okm sync accepts -m flag for commit message" {
    skip "v1: okm sync -m flag not yet implemented"
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/note.md" "body"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
    create_vault_file "public/inbox/note2.md" "body2"
    run "${OKM}" sync -m "my custom message"
    assert_success
    run git -C "${FAKE_VAULT_DIR}" log --oneline -1
    assert_output --partial "my custom message"
}

@test "setup-km.sh rotates logs keeping only last N" {
    skip "v1: log rotation not yet implemented"
    # setup-km.sh should keep only the last 5 log files in ~/.local/log/setup-km-*.log
    # Create 10 old fake logs and verify only 5 remain after a run.
    for i in $(seq 1 10); do
        touch "${HOME}/.local/log/setup-km-200${i}-01-01.log"
    done
    run bash "${PROJECT_ROOT}/scripts/setup-km.sh" --dry-run 2>/dev/null || true
    local count
    count=$(find "${HOME}/.local/log" -name "setup-km-*.log" | wc -l)
    [ "$count" -le 5 ]
}

# =============================================================================
# Known papercuts from v0 audit — document here, fix in v1
# =============================================================================

@test "setup-km.sh gives clear error on unsupported platform/arch" {
    skip "v1: unsupported platform emits confusing 'unbound variable' crash instead of log_error"
    # install_nvim() and install_lazygit() declare nvim_tarball/nvim_dir and lg_os/lg_arch
    # but have no *) fallback case. On an unknown PLATFORM_OS/PLATFORM_ARCH the next
    # variable reference hits set -u and aborts with a cryptic message.
    # Fix: add *) log_error "Unsupported platform: ${PLATFORM_OS}/${PLATFORM_ARCH}"; return 1 ;;
    PLATFORM_OS=haiku PLATFORM_ARCH=riscv \
        run bash -c 'source '"${PROJECT_ROOT}/scripts/setup-km.sh"'; install_nvim'
    assert_failure
    assert_output --partial "Unsupported"
}

@test "yaml_escape_dq strips tab characters from titles" {
    skip "v1: yaml_escape_dq escapes newlines/CRs but not tabs; literal tab leaks into YAML frontmatter"
    # A title with a raw tab produces: title: "foo\tbar" (literal tab in YAML string).
    # YAML allows tabs in double-quoted scalars but it breaks some parsers and is unexpected.
    # Fix: add s="${s//$'\t'/ }" in yaml_escape_dq alongside the \n strip.
    run "${OKM}" new $'Tab\there'
    assert_success
    local file
    file="$(find "${FAKE_VAULT_DIR}/public/inbox" -name '*.md' | head -1)"
    run grep '^title:' "$file"
    # Must not contain a raw tab character
    refute_output --regexp $'title:.*\t'
}

@test "compress-images.py closes image handle before removing original" {
    skip "v1: Image.open(out).verify() leaves file handle open; on WSL2 this can block os.remove(path)"
    # Fix: replace Image.open(out).verify() with:
    #   with Image.open(out) as img: img.verify()
    # so the handle is closed before the original is deleted.
    true
}

@test "setup-km.sh cleans up tmp dirs on failure" {
    skip "v1: mktemp -d in install_nvim/install_lazygit/install_nerd_font not removed when set -e fires mid-install"
    # Fix: use a trap ERR / trap EXIT to rm -rf the tmp_dir on any exit path.
    true
}

@test "okm recent warns when vault is unreadable instead of showing empty picker" {
    skip "v1: || true on the find|stat pipeline silently swallows errors; user sees empty fzf with no explanation"
    # Fix: capture the exit status separately and emit a warning to stderr before
    # falling through to the empty-selection exit.
    mkdir -p "${FAKE_VAULT_DIR}/public/inbox"
    chmod 000 "${FAKE_VAULT_DIR}/public/inbox"
    run "${OKM}" recent
    chmod 755 "${FAKE_VAULT_DIR}/public/inbox"
    assert_output --partial "warn"
}

@test "okm tagged warns when files with block-style tags are skipped" {
    skip "v1: list_tagged silently skips block-style-tag files; users get incomplete results with no notice"
    # Fix: count skipped files and emit a warning: "N note(s) with block-style tags skipped (v1)".
    create_vault_file "public/inbox/block.md" "$(printf -- '---\ntags:\n  - foo\n---\nbody')"
    run "${OKM}" tagged foo
    assert_output --partial "skipped"
}
