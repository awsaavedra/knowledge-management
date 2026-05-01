#!/usr/bin/env bats
# Tests for the public/private PARA banner configuration in nvim and vim.

load 'helpers/test_helper'

setup() {
    common_setup
    AUTOCMDS="${PROJECT_ROOT}/config/nvim/lua/config/autocmds.lua"
    VIMRC="${PROJECT_ROOT}/config/vim/vimrc"
}

# --- Neovim: autocmds.lua ---

@test "autocmds.lua defines KMBannerPublic and KMBannerPrivate highlights" {
    grep -q 'KMBannerPublic'  "$AUTOCMDS"
    grep -q 'KMBannerPrivate' "$AUTOCMDS"
}

@test "autocmds.lua KMBannerPublic uses green hex (#7CB342)" {
    grep -q 'KMBannerPublic.*#7CB342' "$AUTOCMDS"
}

@test "autocmds.lua KMBannerPrivate uses red hex (#C62828)" {
    grep -q 'KMBannerPrivate.*#C62828' "$AUTOCMDS"
}

@test "autocmds.lua matches private-*/ paths" {
    grep -q 'private%-' "$AUTOCMDS"
}

@test "autocmds.lua matches public PARA folders" {
    grep -q '/(daily)/' "$AUTOCMDS"
    grep -q '/(inbox)/' "$AUTOCMDS"
    grep -q '/(attachments)/' "$AUTOCMDS"
    grep -q '/(archive)/' "$AUTOCMDS"
}

@test "autocmds.lua sets winbar via opt_local" {
    grep -q 'vim.opt_local.winbar' "$AUTOCMDS"
}

@test "autocmds.lua creates the KMBanner augroup" {
    grep -q 'KMBanner' "$AUTOCMDS"
}

@test "autocmds.lua is syntactically valid Lua" {
    run nvim --headless --clean -c "luafile $AUTOCMDS" -c "qa"
    [ "$status" -eq 0 ]
}

# --- Vim: vimrc ---

@test "vimrc defines KMBannerPublic and KMBannerPrivate highlights" {
    grep -q 'KMBannerPublic'  "$VIMRC"
    grep -q 'KMBannerPrivate' "$VIMRC"
}

@test "vimrc KMBannerPublic uses green ctermbg=Green and #7CB342" {
    grep -q 'KMBannerPublic.*ctermbg=Green' "$VIMRC"
    grep -q 'KMBannerPublic.*#7CB342'        "$VIMRC"
}

@test "vimrc KMBannerPrivate uses red ctermbg=Red and #C62828" {
    grep -q 'KMBannerPrivate.*ctermbg=Red' "$VIMRC"
    grep -q 'KMBannerPrivate.*#C62828'      "$VIMRC"
}

@test "vimrc detects private-*/ paths" {
    grep -qF '/private-[^/]\+/' "$VIMRC"
}

@test "vimrc detects public PARA folders" {
    grep -qF 'daily\|inbox\|attachments\|archive' "$VIMRC"
}

@test "vimrc sets local statusline for banners" {
    grep -q '&l:statusline' "$VIMRC"
}
