#!/usr/bin/env bash
# verify-kms.sh — check that all KMS stack components are properly installed
#
# Usage:  bash verify-kms.sh
# Exits 0 if all required checks pass; exits 1 if any FAIL.
# WARN items are advisory and do not affect the exit code.

set -uo pipefail

VAULT_DIR="/home/aws/workspace/knowledge-management-system"
BIN_DIR="${HOME}/bin"
SHELL_RC="${HOME}/.zshrc"
LAZY_DIR="${HOME}/.local/share/nvim/lazy"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

_pass()    { printf "${GREEN}[PASS]${NC} %s\n" "$1"; PASS_COUNT=$((PASS_COUNT + 1)); }
_fail()    { printf "${RED}[FAIL]${NC} %s\n" "$1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
_warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; WARN_COUNT=$((WARN_COUNT + 1)); }
_section() { printf "\n${BOLD}── %s ${NC}\n" "$1"; }

# ── System packages (apt) ────────────────────────────────────────────────────
_section "System packages"

for cmd in vim git rg fzf curl; do
    if command -v "${cmd}" >/dev/null 2>&1; then
        _pass "${cmd}  ($(command -v "${cmd}"))"
    else
        _fail "${cmd} not found — run: sudo apt install <package>"
    fi
done

# xclip or wl-clipboard — at least one required for Neovim clipboard registers
xclip_ok=false
wlcopy_ok=false
command -v xclip   >/dev/null 2>&1 && xclip_ok=true
command -v wl-copy >/dev/null 2>&1 && wlcopy_ok=true

if "${xclip_ok}" && "${wlcopy_ok}"; then
    _pass "clipboard: xclip + wl-clipboard (both installed)"
elif "${xclip_ok}"; then
    _pass "clipboard: xclip installed"
elif "${wlcopy_ok}"; then
    _pass "clipboard: wl-clipboard installed"
else
    _fail "clipboard: neither xclip nor wl-clipboard — run: sudo apt install xclip wl-clipboard"
fi

# ── Flatpak / Obsidian ───────────────────────────────────────────────────────
_section "Flatpak / Obsidian"

if command -v flatpak >/dev/null 2>&1; then
    _pass "flatpak  ($(command -v flatpak))"
else
    _fail "flatpak not found — run: sudo apt install flatpak"
fi

if flatpak list --app --columns=application 2>/dev/null | grep -qx 'md.obsidian.Obsidian'; then
    _pass "Obsidian flatpak installed (md.obsidian.Obsidian)"
else
    _fail "Obsidian not installed — run: flatpak install flathub md.obsidian.Obsidian"
fi

# ── ~/bin binaries ───────────────────────────────────────────────────────────
_section "~/bin binaries"

for bin in nvim lazygit okm obs; do
    if [ -x "${BIN_DIR}/${bin}" ]; then
        _pass "${bin}  (${BIN_DIR}/${bin})"
    else
        _fail "${bin} not found at ${BIN_DIR}/${bin} — run: bash setup-kms.sh"
    fi
done

# ── Vault structure ──────────────────────────────────────────────────────────
_section "Vault structure"

for subdir in daily inbox attachments; do
    if [ -d "${VAULT_DIR}/${subdir}" ]; then
        _pass "${subdir}/"
    else
        _fail "${VAULT_DIR}/${subdir}/ missing — run: bash setup-kms.sh"
    fi
done

if [ -f "${VAULT_DIR}/.gitignore" ]; then
    _pass ".gitignore present"
else
    _fail ".gitignore missing — run: bash setup-kms.sh"
fi

if [ -d "${VAULT_DIR}/.git" ]; then
    _pass "git repo initialised"
else
    _fail "vault is not a git repo — run: bash setup-kms.sh"
fi

# ── Neovim config ────────────────────────────────────────────────────────────
_section "Neovim config"

nvim_cfg="${HOME}/.config/nvim"
nvim_vault="${VAULT_DIR}/config/nvim"

# Determine active config location and whether obsidian.lua + checker are in place
if [ -L "${nvim_cfg}" ] && [ "$(readlink "${nvim_cfg}")" = "${nvim_vault}" ]; then
    _pass "~/.config/nvim -> vault (symlinked)"
    active_nvim="${nvim_vault}"
elif [ -d "${nvim_cfg}" ]; then
    _pass "~/.config/nvim: pre-existing config (global install preserved)"
    active_nvim="${nvim_cfg}"
else
    _fail "~/.config/nvim missing — run: bash setup-kms.sh"
    active_nvim=""
fi

# Vault reference config files must always exist
for f in \
    "${nvim_vault}/init.lua" \
    "${nvim_vault}/lua/plugins/obsidian.lua"
do
    rel="${f#"${nvim_vault}/"}"
    if [ -f "${f}" ]; then
        _pass "vault config/nvim/${rel} present"
    else
        _fail "vault config/nvim/${rel} missing"
    fi
done

# obsidian.lua must be in the active config (vault symlink or real dir)
if [ -n "${active_nvim}" ]; then
    obs_plugin="${active_nvim}/lua/plugins/obsidian.lua"
    if [ -f "${obs_plugin}" ]; then
        _pass "obsidian.lua installed in active nvim config"
    else
        _fail "obsidian.lua missing from active nvim config — run: bash setup-kms.sh"
    fi
fi

# lazy.nvim and obsidian.nvim download on first `nvim` launch — advisory only
if [ -d "${LAZY_DIR}/lazy.nvim" ]; then
    _pass "lazy.nvim downloaded (${LAZY_DIR}/lazy.nvim)"
else
    _warn "lazy.nvim not yet downloaded — launch nvim once to trigger bootstrap"
fi

if [ -d "${LAZY_DIR}/obsidian.nvim" ]; then
    _pass "obsidian.nvim downloaded (${LAZY_DIR}/obsidian.nvim)"
else
    _warn "obsidian.nvim not yet downloaded — launch nvim once to trigger bootstrap"
fi

# ── Shell config ─────────────────────────────────────────────────────────────
_section "Shell config (${SHELL_RC})"

if [ ! -f "${SHELL_RC}" ]; then
    _fail "${SHELL_RC} not found"
else
    shell_checks=(
        'export PATH="$HOME/bin:$PATH"'
        'export EDITOR=nvim'
        'export OBSIDIAN_VAULT="/home/aws/workspace/knowledge-management-system"'
        'export OBSIDIAN_DAILY_DIR=daily'
        'export OBSIDIAN_NOTES_DIR=inbox'
        'alias obs="flatpak run md.obsidian.Obsidian"'
    )
    for line in "${shell_checks[@]}"; do
        if grep -qxF "${line}" "${SHELL_RC}"; then
            _pass "${line}"
        else
            _fail "missing from .zshrc: ${line}"
        fi
    done
fi

# ── Git remote ───────────────────────────────────────────────────────────────
_section "Git remote"

if git -C "${VAULT_DIR}" remote get-url origin >/dev/null 2>&1; then
    _pass "remote 'origin' configured"
else
    _warn "no git remote — vault is local-only (add one with: git -C \"\$(okm path)\" remote add origin <url>)"
fi

# ── Offline mode enforcement ─────────────────────────────────────────────────
_section "Offline mode enforcement"

# Obsidian: flatpak network permission revocation
# flatpak override writes: [Context] shared=!network; into the override file
obsidian_override="${HOME}/.local/share/flatpak/overrides/md.obsidian.Obsidian"
if [ -f "${obsidian_override}" ] && grep -q '!network' "${obsidian_override}"; then
    _pass "Obsidian: network revoked via flatpak sandbox"
else
    _fail "Obsidian has network access — run: flatpak override --user --unshare=network md.obsidian.Obsidian"
fi

# lazygit: config symlink
lazygit_link="${HOME}/.config/lazygit"
lazygit_target="${VAULT_DIR}/config/lazygit"
if [ -L "${lazygit_link}" ] && [ "$(readlink "${lazygit_link}")" = "${lazygit_target}" ]; then
    _pass "lazygit config: symlinked to vault"
else
    _fail "~/.config/lazygit not symlinked to vault — run: bash setup-kms.sh"
fi

# lazygit: update checks disabled
lazygit_cfg="${VAULT_DIR}/config/lazygit/config.yml"
if grep -q 'method: never' "${lazygit_cfg}" 2>/dev/null; then
    _pass "lazygit: update checks disabled (method: never)"
else
    _fail "lazygit update checks not disabled — check ${lazygit_cfg}"
fi

# lazy.nvim: update checker disabled — check active config location
lazy_lua="${HOME}/.config/nvim/lua/config/lazy.lua"  # LazyVim layout
vault_init="${VAULT_DIR}/config/nvim/init.lua"         # minimal layout fallback
if grep -q 'enabled = false' "${lazy_lua}" 2>/dev/null; then
    _pass "lazy.nvim: update checker disabled (${lazy_lua})"
elif grep -q 'checker.*enabled.*false' "${vault_init}" 2>/dev/null; then
    _pass "lazy.nvim: update checker disabled (${vault_init})"
else
    _fail "lazy.nvim update checker not disabled — check ${lazy_lua}"
fi

# ── Security (advisory — WARNs only, never block) ────────────────────────────
_section "Security (advisory)"

if [ -f "${HOME}/.ssh/id_ed25519.pub" ]; then
    _pass "SSH key present (~/.ssh/id_ed25519)"
else
    _warn "no ed25519 SSH key — run: ssh-keygen -t ed25519 -C kms-vault"
fi

if [ -f "${VAULT_DIR}/.gitattributes" ] \
   && grep -q 'filter=git-crypt' "${VAULT_DIR}/.gitattributes" 2>/dev/null; then
    _pass "git-crypt configured (.gitattributes has filter=git-crypt)"
else
    _warn "git-crypt not initialised — note content will be unencrypted in the remote repository"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
printf "\n${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
printf "  ${GREEN}PASS: %-4d${NC}  ${RED}FAIL: %-4d${NC}  ${YELLOW}WARN: %-4d${NC}\n" \
    "${PASS_COUNT}" "${FAIL_COUNT}" "${WARN_COUNT}"
printf "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ "${FAIL_COUNT}" -gt 0 ]; then
    printf "\n${RED}%d check(s) failed.${NC} Run 'bash setup-kms.sh' to fix most issues.\n" \
        "${FAIL_COUNT}"
    exit 1
else
    printf "\n${GREEN}All required checks passed.${NC}"
    if [ "${WARN_COUNT}" -gt 0 ]; then
        printf " ${YELLOW}%d advisory warning(s) above.${NC}" "${WARN_COUNT}"
    fi
    printf "\n"
fi
