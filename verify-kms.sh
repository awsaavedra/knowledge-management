#!/usr/bin/env bash
# verify-kms.sh — check that all KMS stack components are properly installed
#
# Usage:  bash verify-kms.sh
#         source env.sh && bash verify-kms.sh
#
# Exits 0 if all required checks pass; exits 1 if any FAIL.
# WARN items are advisory and do not affect the exit code.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VAULT_DIR="${OBSIDIAN_VAULT:-$(cd "${SCRIPT_DIR}/.." && pwd)/knowledge-management-system}"
BIN_DIR="${SCRIPT_DIR}/bin"
LAZY_DIR="${HOME}/.local/share/km/lazy"

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

# ── Project binaries ────────────────────────────────────────────────────────
_section "Project binaries (${BIN_DIR})"

for bin in nvim lazygit okm; do
    if [ -x "${BIN_DIR}/${bin}" ]; then
        _pass "${bin}  (${BIN_DIR}/${bin})"
    else
        _fail "${bin} not found at ${BIN_DIR}/${bin} — run: bash setup-kms.sh"
    fi
done

# ── Vault structure ──────────────────────────────────────────────────────────
_section "Vault structure"

for subdir in daily inbox attachments archive; do
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

# ── Transcription tools ─────────────────────────────────────────────────────
_section "Transcription tools"

for cmd in ffmpeg mpv; do
    if command -v "${cmd}" >/dev/null 2>&1; then
        _pass "${cmd}  ($(command -v "${cmd}"))"
    else
        _fail "${cmd} not found — run: bash setup-kms.sh"
    fi
done

VENV_DIR="${SCRIPT_DIR}/venv"
if [ -d "${VENV_DIR}" ] && [ -x "${VENV_DIR}/bin/python" ]; then
    _pass "Python venv  (${VENV_DIR})"
else
    _fail "Python venv not found at ${VENV_DIR} — run: bash setup-kms.sh"
fi

for pkg in yt_dlp youtube_transcript_api whisperx PIL; do
    if "${VENV_DIR}/bin/python" -c "import ${pkg}" 2>/dev/null; then
        _pass "venv: ${pkg} installed"
    else
        _fail "venv: ${pkg} missing — run: bash setup-kms.sh"
    fi
done

# mpv config (project-scoped via MPV_HOME)
mpv_conf="${SCRIPT_DIR}/config/mpv/mpv.conf"
if [ -f "${mpv_conf}" ]; then
    _pass "mpv config  (${mpv_conf}, loaded via MPV_HOME)"
else
    _fail "mpv config missing at ${mpv_conf} — run: bash setup-kms.sh"
fi

if grep -q 'screenshot-directory' "${mpv_conf}" 2>/dev/null; then
    _pass "mpv: screenshot-directory configured"
else
    _fail "mpv: screenshot-directory not set in ${mpv_conf}"
fi

# ── Project-scoped config (NVIM_APPNAME=km) ─────────────────────────────────
_section "Neovim config (NVIM_APPNAME=km)"

km_cfg="${HOME}/.config/km"
project_nvim="${SCRIPT_DIR}/config/nvim"

if [ -L "${km_cfg}" ] && [ "$(readlink "${km_cfg}")" = "${project_nvim}" ]; then
    _pass "~/.config/km -> ${project_nvim} (NVIM_APPNAME isolation)"
elif [ -d "${km_cfg}" ]; then
    _pass "~/.config/km exists (manual config)"
else
    _fail "~/.config/km missing — run: bash setup-kms.sh"
fi

# Verify global nvim config was NOT modified
nvim_global="${HOME}/.config/nvim"
if [ -L "${nvim_global}" ] && [ "$(readlink "${nvim_global}")" = "${project_nvim}" ]; then
    _fail "~/.config/nvim is symlinked to project config — should use NVIM_APPNAME=km instead"
else
    _pass "~/.config/nvim not overridden by project"
fi

# Project config files must exist
for f in \
    "${project_nvim}/init.lua" \
    "${project_nvim}/lua/plugins/obsidian.lua"
do
    rel="${f#"${project_nvim}/"}"
    if [ -f "${f}" ]; then
        _pass "config/nvim/${rel} present"
    else
        _fail "config/nvim/${rel} missing"
    fi
done

# lazy.nvim and obsidian.nvim download on first `nvim` launch — advisory only
if [ -d "${LAZY_DIR}/lazy.nvim" ]; then
    _pass "lazy.nvim downloaded (${LAZY_DIR}/lazy.nvim)"
else
    _warn "lazy.nvim not yet downloaded — run: source env.sh && nvim (triggers bootstrap)"
fi

if [ -d "${LAZY_DIR}/obsidian.nvim" ]; then
    _pass "obsidian.nvim downloaded (${LAZY_DIR}/obsidian.nvim)"
else
    _warn "obsidian.nvim not yet downloaded — run: source env.sh && nvim (triggers bootstrap)"
fi

# ── Project activation (env.sh) ─────────────────────────────────────────────
_section "Project activation"

if [ -f "${SCRIPT_DIR}/env.sh" ]; then
    _pass "env.sh exists"
else
    _fail "env.sh missing at ${SCRIPT_DIR}/env.sh"
fi

# Check that env.sh did NOT modify ~/.zshrc
if [ -f "${HOME}/.zshrc" ]; then
    if grep -qF 'OBSIDIAN_VAULT' "${HOME}/.zshrc" 2>/dev/null; then
        _warn "~/.zshrc contains OBSIDIAN_VAULT — may be leftover from old setup; env.sh handles this now"
    else
        _pass "~/.zshrc does not contain project-specific exports"
    fi
fi

# ── lazygit config ──────────────────────────────────────────────────────────
_section "lazygit config"

lazygit_cfg="${SCRIPT_DIR}/config/lazygit/config.yml"
if [ -f "${lazygit_cfg}" ]; then
    _pass "lazygit config exists at ${lazygit_cfg}"
else
    _fail "lazygit config missing at ${lazygit_cfg}"
fi

if grep -q 'method: never' "${lazygit_cfg}" 2>/dev/null; then
    _pass "lazygit: update checks disabled (method: never)"
else
    _fail "lazygit update checks not disabled — check ${lazygit_cfg}"
fi

# Verify global lazygit config was NOT symlinked
lazygit_global="${HOME}/.config/lazygit"
if [ -L "${lazygit_global}" ] && [ "$(readlink "${lazygit_global}")" = "${SCRIPT_DIR}/config/lazygit" ]; then
    _fail "~/.config/lazygit is symlinked to project config — should use LG_CONFIG_FILE env var instead"
else
    _pass "~/.config/lazygit not overridden by project"
fi

# lazy.nvim: update checker disabled
lazy_lua="${project_nvim}/lua/config/lazy.lua"
if grep -q 'enabled = false' "${lazy_lua}" 2>/dev/null; then
    _pass "lazy.nvim: update checker disabled (${lazy_lua})"
else
    _fail "lazy.nvim update checker not disabled — check ${lazy_lua}"
fi

# ── Git remote ───────────────────────────────────────────────────────────────
_section "Git remote"

if [ -d "${VAULT_DIR}/.git" ] && git -C "${VAULT_DIR}" remote get-url origin >/dev/null 2>&1; then
    _pass "remote 'origin' configured"
else
    _warn "no git remote — vault is local-only (add one with: git -C \"\$(okm path)\" remote add origin <url>)"
fi

# ── Offline mode enforcement ─────────────────────────────────────────────────
_section "Offline mode enforcement"

obsidian_override="${HOME}/.local/share/flatpak/overrides/md.obsidian.Obsidian"
if [ -f "${obsidian_override}" ] && grep -q '!network' "${obsidian_override}"; then
    _pass "Obsidian: network revoked via flatpak sandbox"
else
    _fail "Obsidian has network access — run: flatpak override --user --unshare=network md.obsidian.Obsidian"
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
