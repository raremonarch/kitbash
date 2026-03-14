#!/bin/bash
# Package manager abstraction for kitbash
# Provides distro-agnostic wrappers over dnf, pacman, and apt.
#
# KITBASH_PKG_MANAGER is set automatically on source (via pkg_detect).
# Modules should use these functions instead of calling dnf/pacman directly,
# so that the same module logic works on both Fedora and Arch.
#
# For packages that require distro-specific repo setup (RPMFusion, COPR, AUR),
# modules should branch on $KITBASH_PKG_MANAGER directly for those sections.
#
# Usage in modules:
#   pkg_install copyq                  # install from official repos
#   pkg_installed copyq && exit 0      # idempotency check
#   pkg_remove old-package             # uninstall
#   pkg_aur_install google-chrome      # AUR on Arch; dnf fallback on Fedora
#   pkg_copr_enable yalter/niri        # COPR on Fedora; no-op on Arch
#   pkg_repo_exists google-chrome      # check if repo is configured
#   [ "$KITBASH_DISTRO" = "arch" ] && ...          # distro-specific branch
#   [ "$KITBASH_PKG_MANAGER" = "pacman" ] && ...  # package-manager branch

# ---------------------------------------------------------------------------
# Detection
# ---------------------------------------------------------------------------

# Detect the active package manager and distro, setting:
#   KITBASH_PKG_MANAGER — "dnf" | "pacman" | "apt" | "unknown"
#   KITBASH_DISTRO      — "fedora" | "arch" | "debian" | "ubuntu" | "unknown"
#   KITBASH_AUR_HELPER  — "paru" | "yay" | "" (Arch only)
#
# KITBASH_DISTRO is read from /etc/os-release for accuracy; it answers "what
# distro is this?" while KITBASH_PKG_MANAGER answers "how do I install things?"
# Use KITBASH_DISTRO when branching on distro-specific behavior that isn't
# purely about package installation (e.g. repo layout, default service names).
#
# Safe to call multiple times — exits early if already set.
pkg_detect() {
    if [ -n "$KITBASH_PKG_MANAGER" ]; then
        return 0
    fi

    # Detect distro from /etc/os-release
    local os_id=""
    if [ -f /etc/os-release ]; then
        os_id="$(. /etc/os-release && echo "${ID:-}")"
    fi

    if command -v dnf >/dev/null 2>&1; then
        export KITBASH_PKG_MANAGER="dnf"
        export KITBASH_DISTRO="${os_id:-fedora}"
    elif command -v pacman >/dev/null 2>&1; then
        export KITBASH_PKG_MANAGER="pacman"
        export KITBASH_DISTRO="${os_id:-arch}"
        if command -v paru >/dev/null 2>&1; then
            export KITBASH_AUR_HELPER="paru"
        elif command -v yay >/dev/null 2>&1; then
            export KITBASH_AUR_HELPER="yay"
        else
            export KITBASH_AUR_HELPER=""
        fi
    elif command -v apt >/dev/null 2>&1; then
        export KITBASH_PKG_MANAGER="apt"
        export KITBASH_DISTRO="${os_id:-debian}"
    else
        export KITBASH_PKG_MANAGER="unknown"
        export KITBASH_DISTRO="${os_id:-unknown}"
        log_warning "No supported package manager detected (dnf, pacman, apt)"
    fi

    log_debug "Distro: $KITBASH_DISTRO  Package manager: $KITBASH_PKG_MANAGER"
    [ -n "${KITBASH_AUR_HELPER:-}" ] && log_debug "AUR helper: $KITBASH_AUR_HELPER"
}

# ---------------------------------------------------------------------------
# Core package operations
# ---------------------------------------------------------------------------

# Install one or more packages from official repositories.
# Usage: pkg_install <pkg> [<pkg> ...]
pkg_install() {
    case "$KITBASH_PKG_MANAGER" in
        dnf)    sudo dnf install -y "$@" ;;
        pacman) sudo pacman -S --noconfirm "$@" ;;
        apt)    sudo apt install -y "$@" ;;
        *)
            log_error "pkg_install: unsupported package manager '$KITBASH_PKG_MANAGER'"
            return 1
            ;;
    esac
}

# Check whether a package is installed.
# Returns 0 if installed, 1 if not.
# Usage: pkg_installed <pkg>
pkg_installed() {
    local pkg="$1"
    case "$KITBASH_PKG_MANAGER" in
        dnf)    rpm -q "$pkg" >/dev/null 2>&1 ;;
        pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
        apt)    dpkg -l "$pkg" 2>/dev/null | grep -q "^ii" ;;
        *)      return 1 ;;
    esac
}

# Remove one or more packages.
# Usage: pkg_remove <pkg> [<pkg> ...]
pkg_remove() {
    case "$KITBASH_PKG_MANAGER" in
        dnf)    sudo dnf remove -y "$@" ;;
        pacman) sudo pacman -R --noconfirm "$@" ;;
        apt)    sudo apt remove -y "$@" ;;
        *)
            log_error "pkg_remove: unsupported package manager '$KITBASH_PKG_MANAGER'"
            return 1
            ;;
    esac
}

# Refresh the package database / metadata cache.
# Usage: pkg_update
pkg_update() {
    case "$KITBASH_PKG_MANAGER" in
        dnf)
            # makecache refreshes metadata; dnf check-update exits 100 on updates
            # available which would look like an error, so use makecache instead.
            sudo dnf makecache
            ;;
        pacman) sudo pacman -Sy ;;
        apt)    sudo apt update ;;
        *)
            log_error "pkg_update: unsupported package manager '$KITBASH_PKG_MANAGER'"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Repository operations
# ---------------------------------------------------------------------------

# Check whether a named repository is configured.
# dnf:    matches against dnf repolist output by repo ID prefix
# pacman: matches a [section] header in /etc/pacman.conf
# apt:    searches sources.list and sources.list.d for the string
# Usage: pkg_repo_exists <repo-name>
pkg_repo_exists() {
    local repo_name="$1"
    case "$KITBASH_PKG_MANAGER" in
        dnf)    dnf repolist --all 2>/dev/null | grep -q "^${repo_name}" ;;
        pacman) grep -q "^\[${repo_name}\]" /etc/pacman.conf ;;
        apt)    grep -rq "${repo_name}" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null ;;
        *)      return 1 ;;
    esac
}

# Enable a Fedora COPR repository.
# On Arch this is a no-op — AUR packages are handled by pkg_aur_install instead.
# Usage: pkg_copr_enable <owner/repo>
pkg_copr_enable() {
    local copr="$1"
    case "$KITBASH_PKG_MANAGER" in
        dnf)
            sudo dnf copr enable -y "$copr"
            ;;
        pacman)
            log_debug "pkg_copr_enable: COPR not applicable on Arch; use pkg_aur_install for AUR packages"
            return 0
            ;;
        *)
            log_warning "pkg_copr_enable: not supported on $KITBASH_PKG_MANAGER"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# AUR helper bootstrap
# ---------------------------------------------------------------------------

# Ensure an AUR helper is available on Arch. If neither paru nor yay is found,
# installs paru from the AUR using makepkg. No-op on non-Arch systems.
# Call this from run-setup.sh after pkg_detect, before running any modules.
pkg_ensure_aur_helper() {
    [ "$KITBASH_PKG_MANAGER" = "pacman" ] || return 0
    [ -n "${KITBASH_AUR_HELPER:-}" ] && return 0

    log_info "No AUR helper found — installing paru"

    local tmp_dir
    tmp_dir="$(mktemp -d)"

    run_with_progress "installing build dependencies" \
        sudo pacman -S --needed --noconfirm base-devel git

    run_with_progress "cloning paru" \
        git clone -q https://aur.archlinux.org/paru.git "$tmp_dir/paru"

    if (cd "$tmp_dir/paru" && makepkg -si --noconfirm); then
        rm -rf "$tmp_dir"
        export KITBASH_AUR_HELPER="paru"
        log_success "paru installed"
    else
        rm -rf "$tmp_dir"
        log_error "paru installation failed — AUR packages will not be available"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# AUR / extra-source installs
# ---------------------------------------------------------------------------

# Install packages from AUR (Arch) or equivalent out-of-tree sources.
# On Arch: uses paru or yay (KITBASH_AUR_HELPER must be set).
# On Fedora: delegates to pkg_install — assumes the package is reachable via
#   dnf after any required COPR/repo has been configured by the caller.
# Usage: pkg_aur_install <pkg> [<pkg> ...]
pkg_aur_install() {
    case "$KITBASH_PKG_MANAGER" in
        pacman)
            if [ -z "${KITBASH_AUR_HELPER:-}" ]; then
                log_error "pkg_aur_install: no AUR helper found. Install paru or yay first."
                return 1
            fi
            "$KITBASH_AUR_HELPER" -S --noconfirm "$@"
            ;;
        dnf)
            log_debug "pkg_aur_install: on Fedora, delegating to dnf for: $*"
            sudo dnf install -y "$@"
            ;;
        *)
            log_error "pkg_aur_install: not supported on $KITBASH_PKG_MANAGER"
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

export -f pkg_detect
export -f pkg_install
export -f pkg_installed
export -f pkg_remove
export -f pkg_update
export -f pkg_repo_exists
export -f pkg_copr_enable
export -f pkg_ensure_aur_helper
export -f pkg_aur_install

# Auto-detect on source so KITBASH_PKG_MANAGER is always set after sourcing.
pkg_detect
