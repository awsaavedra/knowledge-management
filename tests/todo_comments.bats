#!/usr/bin/env bats
# Tests for TODO/FIXME/BUG syntax highlighting in vim and neovim.
# Verifies the spec contract (keywords + colors) without depending on
# plugins being synced or a runtime nvim/vim being available.

load 'helpers/test_helper'

setup() {
    common_setup
}

# --- Neovim: todo-comments.nvim plugin spec ---

@test "todo-comments plugin spec file exists" {
    [ -f "${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua" ]
}

@test "todo-comments spec lazy-loads on file open" {
    grep -q 'BufReadPost' "${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
}

@test "todo-comments spec maps TODO to yellow" {
    grep -E 'TODO\s*=\s*\{.*todo_yellow' "${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
}

@test "todo-comments spec maps FIXME to orange" {
    grep -E 'FIXME\s*=\s*\{.*todo_orange' "${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
}

@test "todo-comments spec maps BUG to red" {
    grep -E 'BUG\s*=\s*\{.*todo_red' "${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
}

@test "todo-comments spec defines yellow/orange/red color hex codes" {
    local f="${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
    grep -q 'todo_yellow.*#FFD700' "$f"
    grep -q 'todo_orange.*#FF8C00' "$f"
    grep -q 'todo_red.*#FF3030'    "$f"
}

@test "todo-comments spec disables default alt keywords on TODO and FIXME" {
    local f="${PROJECT_ROOT}/config/nvim/lua/plugins/todo-comments.lua"
    grep -E 'TODO\s*=\s*\{.*alt\s*=\s*\{\s*\}'  "$f"
    grep -E 'FIXME\s*=\s*\{.*alt\s*=\s*\{\s*\}' "$f"
}

# --- Vim: project vimrc ---

@test "project vimrc exists" {
    [ -f "${PROJECT_ROOT}/config/vim/vimrc" ]
}

@test "vimrc sources user ~/.vimrc when present" {
    grep -q "source ~/.vimrc" "${PROJECT_ROOT}/config/vim/vimrc"
}

@test "vimrc defines KMTodoYellow with #FFD700" {
    grep -E 'highlight\s+KMTodoYellow.*#FFD700' "${PROJECT_ROOT}/config/vim/vimrc"
}

@test "vimrc defines KMTodoOrange with #FF8C00" {
    grep -E 'highlight\s+KMTodoOrange.*#FF8C00' "${PROJECT_ROOT}/config/vim/vimrc"
}

@test "vimrc defines KMTodoRed with #FF3030" {
    grep -E 'highlight\s+KMTodoRed.*#FF3030' "${PROJECT_ROOT}/config/vim/vimrc"
}

@test "vimrc matchadd targets TODO: FIXME: BUG: with colon" {
    local f="${PROJECT_ROOT}/config/vim/vimrc"
    grep -qF "matchadd('KMTodoYellow', '\\v<TODO>:')"  "$f"
    grep -qF "matchadd('KMTodoOrange', '\\v<FIXME>:')" "$f"
    grep -qF "matchadd('KMTodoRed',    '\\v<BUG>:')"   "$f"
}

# --- env.sh: vim wiring ---
#
# The project switched from VIMINIT (which nvim also honored, breaking LazyVim)
# to a bin/vim wrapper that explicitly invokes vim with `-u config/vim/vimrc`.
# The wrapper test lives in tests/config.bats — see "bin/vim wrapper applies
# project vimrc to vim only (not nvim)".
