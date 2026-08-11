#!/usr/bin/env bats
# Tests for `okm publish` — the harness-only sync to the public tool repo.
#
# Every case builds a real personal-vault git repo (harness changes + vault
# notes, with a personal-vault .gitignore) and a bare "public" remote seeded
# with a harness-only commit whose .gitignore is the tool-repo version. The
# invariant under test: publish ships harness only — never public/* or private/*
# notes — and preserves the public repo's own .gitignore.

load 'helpers/test_helper'

setup() {
    common_setup
    OKM="${PROJECT_ROOT}/bin/okm"

    REMOTE="${TEST_TEMP_DIR}/pub.git"
    VAULT="${TEST_TEMP_DIR}/vault"

    # --- Seed the public tool remote with a harness-only initial commit ---
    local seed="${TEST_TEMP_DIR}/seed"
    mkdir -p "${seed}/bin" "${seed}/docs" "${seed}/public/inbox/templates"
    git -C "${seed}" init -q -b main
    git -C "${seed}" config user.email t@t.com
    git -C "${seed}" config user.name T
    echo "old tool" > "${seed}/bin/okm"
    printf '# tool-repo .gitignore: ignore vault notes\npublic/inbox/*.md\n' > "${seed}/.gitignore"
    echo "tmpl" > "${seed}/public/inbox/templates/note-template.md"
    touch "${seed}/public/inbox/.gitkeep"
    git -C "${seed}" add -A
    git -C "${seed}" commit -qm "#add, seed harness"
    git init --bare -q "${REMOTE}"
    git -C "${seed}" push -q "${REMOTE}" main

    # --- Personal vault repo: harness changes + notes, personal .gitignore ---
    mkdir -p "${VAULT}/bin" "${VAULT}/docs" "${VAULT}/public/inbox/templates" \
             "${VAULT}/public/daily" "${VAULT}/private/inbox"
    git -C "${VAULT}" init -q -b main
    git -C "${VAULT}" config user.email t@t.com
    git -C "${VAULT}" config user.name T
    echo "new tool v2" > "${VAULT}/bin/okm"
    printf '# personal vault .gitignore: tracks public notes as first-class\n' > "${VAULT}/.gitignore"
    echo "tmpl v2" > "${VAULT}/public/inbox/templates/note-template.md"
    echo "new doc" > "${VAULT}/docs/newthing.md"
    touch "${VAULT}/public/inbox/.gitkeep"
    echo "SECRET" > "${VAULT}/public/inbox/mynote.md"
    echo "weekly" > "${VAULT}/public/daily/2026-08-11-weekly.md"
    echo "priv" > "${VAULT}/private/inbox/secret.md"
    git -C "${VAULT}" add -A
    git -C "${VAULT}" commit -qm "#add, vault + harness"
    git -C "${VAULT}" remote add public "${REMOTE}"

    export OBSIDIAN_VAULT="${VAULT}"
}

# Print the file list of the remote's main branch tree.
_remote_tree() {
    git -C "${REMOTE}" ls-tree -r --name-only main
}

# === Core invariant: no vault notes reach the public remote ===

@test "publish excludes vault notes from the public remote" {
    run "${OKM}" publish
    assert_success
    run _remote_tree
    refute_output --partial "public/inbox/mynote.md"
    refute_output --partial "public/daily/2026-08-11-weekly.md"
    refute_output --partial "private/inbox/secret.md"
}

@test "publish includes harness and inbox templates" {
    run "${OKM}" publish
    assert_success
    run _remote_tree
    assert_output --partial "bin/okm"
    assert_output --partial "docs/newthing.md"
    assert_output --partial "public/inbox/templates/note-template.md"
    assert_output --partial "public/inbox/.gitkeep"
}

@test "publish preserves the public repo's own .gitignore" {
    run "${OKM}" publish
    assert_success
    run git -C "${REMOTE}" show main:.gitignore
    assert_output --partial "tool-repo .gitignore"
    refute_output --partial "personal vault"
}

@test "publish fast-forwards the public branch by one commit" {
    local before
    before="$(git -C "${REMOTE}" rev-parse main)"
    run "${OKM}" publish
    assert_success
    local after parent
    after="$(git -C "${REMOTE}" rev-parse main)"
    [ "${before}" != "${after}" ]
    parent="$(git -C "${REMOTE}" rev-parse "main^")"
    [ "${parent}" = "${before}" ]
}

# === --dry-run ===

@test "publish --dry-run pushes nothing and lists excluded notes" {
    local before
    before="$(git -C "${REMOTE}" rev-parse main)"
    run "${OKM}" publish --dry-run
    assert_success
    assert_output --partial "public/inbox/mynote.md"
    assert_output --partial "private/inbox/secret.md"
    assert_output --partial "Nothing pushed"
    [ "$(git -C "${REMOTE}" rev-parse main)" = "${before}" ]
}

# === Idempotence and guards ===

@test "publish is idempotent — second run has nothing to publish" {
    run "${OKM}" publish
    assert_success
    run "${OKM}" publish
    assert_success
    assert_output --partial "nothing to publish"
}

@test "publish refuses on a dirty working tree" {
    echo "uncommitted" > "${VAULT}/bin/okm"
    run "${OKM}" publish
    assert_failure
    assert_output --partial "working tree is not clean"
}

@test "publish errors when the public remote cannot be resolved" {
    git -C "${VAULT}" remote remove public
    run "${OKM}" publish
    assert_failure
    assert_output --partial "could not find the public tool remote"
}

@test "publish honors an explicit --remote name" {
    git -C "${VAULT}" remote rename public pubmirror
    run "${OKM}" publish --remote pubmirror
    assert_success
    run _remote_tree
    assert_output --partial "docs/newthing.md"
    refute_output --partial "public/inbox/mynote.md"
}

@test "publish rejects unknown arguments" {
    run "${OKM}" publish --bogus
    assert_failure
    assert_output --partial "unknown argument"
}

@test "publish -h prints usage" {
    run "${OKM}" publish -h
    assert_success
    assert_output --partial "okm publish"
    assert_output --partial "vault notes"
}
