#!/usr/bin/env bats
# Tests for static config files (nvim, lazygit).

load 'helpers/test_helper'

setup() {
    eval "$(cat "${BATS_TEST_DIRNAME}/helpers/test_helper.bash" | grep -A999 '^setup()'  | tail -n +2 | sed '/^}/q' | head -n -1)"
}

@test "lazygit config.yml has update method never" {
    grep -q 'method: never' "${PROJECT_ROOT}/config/lazygit/config.yml"
}

@test "obsidian.lua references OBSIDIAN_VAULT env var" {
    grep -q 'vim.env.OBSIDIAN_VAULT' "${PROJECT_ROOT}/config/nvim/lua/plugins/obsidian.lua"
}

@test "obsidian.lua sets notes_subdir to inbox" {
    grep -q 'notes_subdir.*inbox' "${PROJECT_ROOT}/config/nvim/lua/plugins/obsidian.lua"
}

@test "obsidian.lua sets daily folder to daily" {
    grep -q 'folder.*=.*daily' "${PROJECT_ROOT}/config/nvim/lua/plugins/obsidian.lua"
}

@test "lazy.lua has checker enabled = false" {
    grep -q 'enabled = false' "${PROJECT_ROOT}/config/nvim/lua/config/lazy.lua"
}

@test "init.lua bootstraps lazy" {
    grep -q 'require.*config.lazy' "${PROJECT_ROOT}/config/nvim/init.lua"
}

@test "obsidian.lua has all expected keybindings" {
    local obs="${PROJECT_ROOT}/config/nvim/lua/plugins/obsidian.lua"
    grep -q '<leader>on' "$obs"
    grep -q '<leader>oo' "$obs"
    grep -q '<leader>os' "$obs"
    grep -q '<leader>od' "$obs"
    grep -q '<leader>ob' "$obs"
    grep -q '<leader>ot' "$obs"
    grep -q '<leader>op' "$obs"
    grep -q '<leader>og' "$obs"
}
