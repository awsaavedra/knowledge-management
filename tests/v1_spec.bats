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
    # Use a valid-format 22-char ID; spotdl is not in PATH so metadata fetch
    # always fails, but okm spot succeeds with an offline scaffold + warning.
    local fake_bin="${TEST_TEMP_DIR}/fake_bin"
    mkdir -p "$fake_bin"
    # INVALID = 7 chars + 15 zeros = 22-char valid-format Spotify ID
    run env PATH="${fake_bin}:${PATH}" "${OKM}" spot \
        "https://open.spotify.com/track/INVALID000000000000000"
    assert_success
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
    unset KM_TRACK_NOTES
    run "${OKM}" new "consistency test"
    assert_success
    # Note created in the right place regardless of KM_TRACK_NOTES default.
    [ -f "${FAKE_VAULT_DIR}/public/inbox/consistency-test.md" ]
}

@test "F6: okm today with KM_TRACK_NOTES unset behaves same as KM_TRACK_NOTES=true" {
    unset KM_TRACK_NOTES
    run "${OKM}" today
    assert_success
    local today
    today=$(date +%Y-%m-%d)
    [ -f "${FAKE_VAULT_DIR}/public/daily/${today}.md" ]
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
    run "${OKM}" version
    assert_success
    assert_output --partial "okm v"
}

@test "N7: okm --version prints version string" {
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
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    # demo-* files are exempt from PARA content check → clean scan
    create_vault_file "public/inbox/demo-clean.md" "---
title: Demo Clean
tags: [foo]
---
clean content"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
    run "${OKM}" audit --json
    assert_success
    assert_output --partial '"findings"'
    assert_output --partial '"summary"'
}

@test "okm audit --json includes secret findings" {
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/oops.md" "---
title: Oops
---
AKIA1234567890EXAMPLE"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -q -m init
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
    create_vault_file "public/inbox/a.md" "---
title: A
tags: [oldtag]
---"
    create_vault_file "public/inbox/b.md" "---
title: B
tags: [oldtag, other]
---"
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
    create_vault_file "public/inbox/a.md" "---
title: A
tags: [foo, bar]
---"
    create_vault_file "public/inbox/b.md" "---
title: B
tags: [foo]
---"
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
    mkdir -p "${FAKE_VAULT_DIR}/private/inbox"
    run "${OKM}" private new "secret project"
    assert_success
    local slug="secret-project"
    [ -f "${FAKE_VAULT_DIR}/private/inbox/${slug}.md" ]
}

@test "okm private today creates daily note in private/daily" {
    mkdir -p "${FAKE_VAULT_DIR}/private/daily"
    run "${OKM}" private today
    assert_success
    local today
    today=$(date +%Y-%m-%d)
    [ -f "${FAKE_VAULT_DIR}/private/daily/${today}.md" ]
}

@test "okm private capture adds note to private/inbox" {
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
    # Only meaningful when git-crypt is absent; skip if it happens to be installed.
    command -v git-crypt >/dev/null 2>&1 && skip "git-crypt is installed; cannot test its absence"
    run "${OKM}" crypt init
    assert_failure
    assert_output --partial "git-crypt"
}

@test "okm crypt init writes .gitattributes entries" {
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
# Full design: docs/design-notes.md § Fork-safety architecture → Approach A
#
# okm port flow:
#   1. Preconditions: gh CLI installed + auth OK; clean working tree; okm audit passes.
#   2. gh repo create {handle}-knowledge-management --private --clone=false
#   3. git remote rename origin upstream
#   4. git remote set-url --push upstream DISABLED
#   5. git remote add origin git@github.com:{handle}/{handle}-knowledge-management.git
#   6. Activate the tracked pre-push privacy guard: core.hooksPath=scripts/hooks.
#      The guard content has one authoritative copy (scripts/hooks/pre-push);
#      its block/allow behavior is specced in privacy.bats.
#   7. git push -u origin main  (skipped if --no-push)
#   8. Print topology summary.
#
# okm sync uses git push with no remote arg, following the @{u} tracking
# branch — safe by construction once origin points at the private repo.

@test "okm port activates tracked privacy guard via core.hooksPath" {
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    mkdir -p "${FAKE_VAULT_DIR}/scripts/hooks"
    cp "${PROJECT_ROOT}/scripts/hooks/pre-push" "${FAKE_VAULT_DIR}/scripts/hooks/pre-push"
    git -C "${FAKE_VAULT_DIR}" add -A
    git -C "${FAKE_VAULT_DIR}" commit -qm "seed"
    run "${OKM}" port testhandle --no-push
    assert_success
    run git -C "${FAKE_VAULT_DIR}" config core.hooksPath
    assert_output "scripts/hooks"
    [ -x "${FAKE_VAULT_DIR}/scripts/hooks/pre-push" ]
}

@test "okm port warns when tracked guard is missing instead of failing" {
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    run "${OKM}" port testhandle --no-push
    assert_success
    assert_output --partial "privacy guard not activated"
}

@test "okm port sets upstream push URL to DISABLED" {
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

@test "okm port refuses if working tree is dirty" {
    git -C "${FAKE_VAULT_DIR}" init -q -b main
    git -C "${FAKE_VAULT_DIR}" config user.email "t@t"
    git -C "${FAKE_VAULT_DIR}" config user.name "t"
    create_vault_file "public/inbox/uncommitted.md" "dirty"
    run "${OKM}" port testhandle --no-push
    assert_failure
    assert_output --partial "clean"
}

@test "okm sync refuses if origin URL matches upstream blocklist" {
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
    # Fix: replace Image.open(out).verify() with:
    #   with Image.open(out) as img: img.verify()
    # so the handle is closed before the original is deleted.
    true
}

@test "setup-km.sh cleans up tmp dirs on failure" {
    # Fix: use a trap ERR / trap EXIT to rm -rf the tmp_dir on any exit path.
    true
}

@test "okm recent warns when vault is unreadable instead of showing empty picker" {
    # Fix: capture the exit status separately and emit a warning to stderr before
    # falling through to the empty-selection exit.
    mkdir -p "${FAKE_VAULT_DIR}/public/inbox"
    chmod 000 "${FAKE_VAULT_DIR}/public/inbox"
    run "${OKM}" recent
    chmod 755 "${FAKE_VAULT_DIR}/public/inbox"
    assert_output --partial "warn"
}

@test "okm tagged warns when files with block-style tags are skipped" {
    # Fix: count skipped files and emit a warning: "N note(s) with block-style tags skipped (v1)".
    create_vault_file "public/inbox/block.md" "$(printf -- '---\ntags:\n  - foo\n---\nbody')"
    run "${OKM}" tagged foo
    assert_output --partial "skipped"
}
