#!/usr/bin/env bash
# scripts/lib/platform.sh — portable OS detection and cross-platform wrappers.
#
# Usage:
#   source "${SCRIPT_DIR}/scripts/lib/platform.sh"

is_macos() { [ "$(uname -s)" = "Darwin" ]; }
is_wsl2()  { grep -qi 'microsoft' /proc/version 2>/dev/null; }
is_linux() { [ "$(uname -s)" = "Linux" ]; }

# Omarchy (DHH's Arch Linux + Hyprland setup). Marked by OMARCHY_PATH in the
# session env and the omarchy install dir under ~/.local/share.
is_omarchy() { [ -n "${OMARCHY_PATH:-}" ] || [ -d "${HOME}/.local/share/omarchy" ]; }

# Any Arch-family system (Omarchy included) ships pacman.
is_arch() { command -v pacman >/dev/null 2>&1; }

# km_pkg_manager — name of the system package manager for the current OS.
# Prints one of: brew (macOS), apt (Debian/Ubuntu/WSL2), pacman (Arch/Omarchy),
# or "unknown" when none is detected. Checked most-specific first.
km_pkg_manager() {
    if is_macos; then
        echo brew
    elif command -v apt-get >/dev/null 2>&1; then
        echo apt
    elif command -v pacman >/dev/null 2>&1; then
        echo pacman
    else
        echo unknown
    fi
}

# _timeout SECONDS CMD [ARGS...]
# Works on GNU Linux (timeout) and macOS with Homebrew coreutils (gtimeout).
# Falls back to running the command without a timeout if neither is available.
_timeout() {
    local dur="$1"; shift
    if command -v gtimeout >/dev/null 2>&1; then
        gtimeout "$dur" "$@"
    elif command -v timeout >/dev/null 2>&1; then
        timeout "$dur" "$@"
    else
        "$@"
    fi
}

# _date_add YYYY-MM-DD OFFSET_DAYS
# Prints the resulting date in YYYY-MM-DD format.
# Supports GNU date (Linux) and BSD date (macOS).
# OFFSET_DAYS may be positive or negative (e.g. "-3" or "+5").
_date_add() {
    local base="$1" days="$2"
    # GNU date
    if date -d "${base} ${days} days" +%F 2>/dev/null; then
        return
    fi
    # BSD date (macOS): date -v[+-]Nd -j -f fmt input +fmt
    local abs="${days#[+-]}"
    if [ "${days:0:1}" = "-" ]; then
        date -v "-${abs}d" -j -f "%Y-%m-%d" "${base}" +%Y-%m-%d 2>/dev/null
    else
        date -v "+${abs}d" -j -f "%Y-%m-%d" "${base}" +%Y-%m-%d 2>/dev/null
    fi
}

# _pkg_install_hint PKG
# Prints the appropriate install hint for the current platform.
_pkg_install_hint() {
    case "$(km_pkg_manager)" in
        brew)   printf 'brew install %s' "$1" ;;
        pacman) printf 'sudo pacman -S %s' "$1" ;;
        *)      printf 'sudo apt install %s' "$1" ;;
    esac
}
