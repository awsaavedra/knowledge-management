#!/usr/bin/env bats
# Tests for static config files (nvim, lazygit).

load 'helpers/test_helper'

setup() {
    common_setup
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

# WSL2 nvim bug: transparency.lua was in plugin/after/ (wrong) instead of after/plugin/
# Neovim only guarantees after-colorscheme ordering for after/plugin/ scripts.
@test "transparency.lua is in after/plugin/ not plugin/after/" {
    local correct="${PROJECT_ROOT}/config/nvim/after/plugin/transparency.lua"
    local wrong="${PROJECT_ROOT}/config/nvim/plugin/after/transparency.lua"
    [[ -f "$correct" ]] || fail "transparency.lua missing from after/plugin/ (correct location)"
    [[ ! -f "$wrong" ]] || fail "transparency.lua found in plugin/after/ (wrong location)"
}

@test "transparency.lua overrides Normal highlight to no background" {
    grep -q 'nvim_set_hl.*Normal.*bg.*none' \
        "${PROJECT_ROOT}/config/nvim/after/plugin/transparency.lua"
}

# WSL2 nvim bug: en_US.UTF-8 locale may not be generated; env.sh must set a UTF-8 fallback
@test "env.sh sets LC_ALL fallback for WSL2 when locale is missing" {
    grep -q 'LC_ALL' "${PROJECT_ROOT}/env.sh"
}

# nvim bug: env.sh exported VIMINIT for vim, but nvim also honors VIMINIT and
# uses it *in place of* init.lua — so LazyVim never loaded under the project env.
# A bin/vim wrapper handles vim's project vimrc instead, leaving nvim untouched.
@test "env.sh does not export VIMINIT (breaks nvim init.lua)" {
    run grep -E '^[[:space:]]*export[[:space:]]+VIMINIT' "${PROJECT_ROOT}/env.sh"
    refute_output --partial "VIMINIT"
}

@test "bin/vim wrapper applies project vimrc to vim only (not nvim)" {
    [ -f "${PROJECT_ROOT}/bin/vim" ] || fail "bin/vim wrapper missing"
    [ -x "${PROJECT_ROOT}/bin/vim" ] || fail "bin/vim wrapper not executable"
    grep -q 'config/vim/vimrc' "${PROJECT_ROOT}/bin/vim"
    grep -qE '/usr/bin/vim|exec.*vim' "${PROJECT_ROOT}/bin/vim"
}

# nvim bug: netrwPlugin was commented out of lazy.nvim disabled_plugins list,
# so `nvim .` opened netrw v184 instead of letting LazyVim's neo-tree handle the
# directory argument. The line must be uncommented (active) inside disabled_plugins.
@test "netrwPlugin is disabled (uncommented) in lazy.nvim config" {
    local lazy="${PROJECT_ROOT}/config/nvim/lua/config/lazy.lua"
    # Active entry: a line whose first non-whitespace char is " (the string opener),
    # value is "netrwPlugin", optionally trailing comma. Reject lines that start with --.
    run grep -E '^[[:space:]]*"netrwPlugin"' "$lazy"
    assert_success
    [ -n "$output" ]
}

@test "netrw is actually disabled when nvim launches under NVIM_APPNAME=km" {
    [ -x "${PROJECT_ROOT}/bin/nvim" ] || skip "nvim wrapper not installed"
    [ -L "${REAL_HOME}/.config/km" ] || skip "~/.config/km symlink not installed (run setup-km.sh)"
    # Use REAL_HOME so ~/.config/km resolves to its symlink → project config,
    # and ~/.local/share/km has lazy.nvim plugins. Also pass -u explicitly because
    # nvim --headless in 0.10+ doesn't auto-source init.lua.
    # When netrw loads it sets vim.g.loaded_netrwPlugin to its version ("v184").
    # When lazy.nvim disables it, the var stays nil. Reject the version string.
    run env HOME="${REAL_HOME}" NVIM_APPNAME=km "${PROJECT_ROOT}/bin/nvim" --headless \
        -u "${REAL_HOME}/.config/km/init.lua" \
        -c 'lua io.write(tostring(vim.g.loaded_netrwPlugin))' -c 'qa'
    assert_success
    refute_output --partial "v184"
}
