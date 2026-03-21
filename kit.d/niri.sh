#!/bin/bash

# Module: niri.sh
# Purpose: Install Niri scrollable-tiling Wayland compositor and idle/lock tools
# Tier: 1 (System Fundamentals)
# Description: Niri scrollable-tiling Wayland compositor with idle management and screen locking
# Installs: niri, hypridle, hyprlock
# Config-var: _compositor
# Config-match: niri

log_info "Setting up Niri window manager"

# Check what's already installed
NIRI_INSTALLED=false
HYPRIDLE_INSTALLED=false
HYPRLOCK_INSTALLED=false

command -v niri >/dev/null 2>&1 && NIRI_INSTALLED=true
command -v hypridle >/dev/null 2>&1 && HYPRIDLE_INSTALLED=true
command -v hyprlock >/dev/null 2>&1 && HYPRLOCK_INSTALLED=true

# Early exit if everything is in place
if $NIRI_INSTALLED && $HYPRIDLE_INSTALLED && $HYPRLOCK_INSTALLED && \
   systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    log_success "Niri and lock/idle tools are already installed"
    exit 0
fi

# ---------------------------------------------------------------------------
# Installation — distro-specific
# ---------------------------------------------------------------------------

if [ "$KITBASH_DISTRO" = "arch" ]; then
    # All three packages are in the official extra repo on Arch
    PACKAGES_TO_INSTALL=()
    $NIRI_INSTALLED     || PACKAGES_TO_INSTALL+=(niri)
    $HYPRIDLE_INSTALLED || PACKAGES_TO_INSTALL+=(hypridle)
    $HYPRLOCK_INSTALLED || PACKAGES_TO_INSTALL+=(hyprlock)

    if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
        if ! run_with_progress "installing ${PACKAGES_TO_INSTALL[*]}" \
            pkg_install "${PACKAGES_TO_INSTALL[@]}"; then
            log_error "Failed to install Niri packages"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi

else
    # Fedora: niri is in the yalter/niri COPR

    # Ensure Wayland base libraries are present
    log_step "checking Wayland dependencies"
    if ! rpm -q libwayland-client >/dev/null 2>&1; then
        log_warning "Wayland libraries not detected, installing base dependencies"
        if ! run_with_progress "installing Wayland dependencies" \
            sudo dnf install -y wayland-devel libwayland-client libwayland-server; then
            log_error "Failed to install Wayland dependencies"
            exit $KIT_EXIT_DEPENDENCY_MISSING
        fi
    fi

    # Enable COPR
    log_step "enabling COPR repository for Niri"
    if ! dnf copr list 2>/dev/null | grep -q "yalter/niri"; then
        if ! run_with_progress "adding yalter/niri COPR repository" \
            sudo dnf copr enable -y yalter/niri; then
            log_error "Failed to enable COPR repository for Niri"
            log_error "You may need to enable COPR manually: sudo dnf copr enable yalter/niri"
            exit $KIT_EXIT_NETWORK_ERROR
        fi
    fi

    # Install niri
    if ! $NIRI_INSTALLED; then
        if ! run_with_progress "installing niri" sudo dnf install -y niri; then
            log_error "Failed to install Niri"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi

    # Install hypridle/hyprlock
    if ! $HYPRIDLE_INSTALLED || ! $HYPRLOCK_INSTALLED; then
        PACKAGES_TO_INSTALL=""
        $HYPRIDLE_INSTALLED || PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hypridle"
        $HYPRLOCK_INSTALLED || PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hyprlock"

        if ! run_with_progress "installing idle/lock tools" \
            sudo dnf install -y $PACKAGES_TO_INSTALL; then
            log_error "Failed to install hypridle/hyprlock"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Verify and enable service — common to all distros
# ---------------------------------------------------------------------------

if ! command -v niri >/dev/null 2>&1 || \
   ! command -v hypridle >/dev/null 2>&1 || \
   ! command -v hyprlock >/dev/null 2>&1; then
    log_error "Installation verification failed — one or more packages missing"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_step "enabling hypridle service"
if ! systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    run_with_progress "enabling hypridle service" \
        systemctl --user enable hypridle || log_warning "Failed to enable hypridle service"
fi

if ! systemctl --user is-active hypridle >/dev/null 2>&1; then
    run_with_progress "starting hypridle service" \
        systemctl --user start hypridle || log_warning "Failed to start hypridle (may need a running compositor)"
fi

log_success "Niri installation completed successfully"
log_info "Note: Configure hypridle.conf and hyprlock.conf in ~/.config/hypr/"
log_info "Note: hypridle may show warnings when not in Hyprland — this is expected"
exit 0
