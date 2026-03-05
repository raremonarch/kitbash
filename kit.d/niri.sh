#!/bin/bash

# Module: niri.sh
# Purpose: Install Niri scrollable-tiling Wayland compositor and idle/lock tools
# Tier: 2 (Core Desktop Environment)

# Description: Niri scrollable-tiling Wayland compositor with idle management and screen locking
# Installs: niri, hypridle, hyprlock

log_info "Setting up Niri window manager"

# Check if Niri is already installed
NIRI_INSTALLED=false
if command -v niri >/dev/null 2>&1; then
    NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "unknown")
    log_debug "Niri is already installed: $NIRI_VERSION"
    NIRI_INSTALLED=true
fi

# Check if hypridle/hyprlock are already installed
HYPRIDLE_INSTALLED=false
HYPRLOCK_INSTALLED=false
if command -v hypridle >/dev/null 2>&1; then
    log_debug "hypridle is already installed"
    HYPRIDLE_INSTALLED=true
fi
if command -v hyprlock >/dev/null 2>&1; then
    log_debug "hyprlock is already installed"
    HYPRLOCK_INSTALLED=true
fi

# If everything is already installed and service is enabled, exit early
if $NIRI_INSTALLED && $HYPRIDLE_INSTALLED && $HYPRLOCK_INSTALLED && \
   systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    log_success "Niri and lock/idle tools are already installed"
    exit 0
fi

# Check if running on Wayland-compatible system
log_step "checking system compatibility"
if ! rpm -q libwayland-client >/dev/null 2>&1; then
    log_warning "Wayland libraries not detected, installing base dependencies"
    if ! run_with_progress "installing Wayland dependencies" \
        sudo dnf install -y wayland-devel libwayland-client libwayland-server; then
        log_error "Failed to install Wayland dependencies"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
else
    log_debug "Wayland libraries detected"
fi

# Enable COPR repository for Niri
log_step "enabling COPR repository for Niri"
if ! dnf copr list 2>/dev/null | grep -q "yalter/niri"; then
    if ! run_with_progress "adding yalter/niri COPR repository" \
        sudo dnf copr enable -y yalter/niri; then
        log_error "Failed to enable COPR repository for Niri"
        log_error "You may need to enable COPR manually: sudo dnf copr enable yalter/niri"
        exit $KIT_EXIT_NETWORK_ERROR
    fi
else
    log_debug "COPR repository already enabled"
fi

# Install Niri if needed
if ! $NIRI_INSTALLED; then
    log_step "installing Niri from COPR"
    if ! run_with_progress "installing niri package" \
        sudo dnf install -y niri; then
        log_error "Failed to install Niri"
        log_error "Check ~/kit.log for details"
        exit $KIT_EXIT_MODULE_FAILED
    fi

    # Verify installation
    if command -v niri >/dev/null 2>&1; then
        NIRI_VERSION=$(niri --version 2>&1 | head -n1 || echo "installed")
        log_debug "Niri installed successfully: $NIRI_VERSION"
    else
        log_error "Niri installation verification failed"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Install hypridle and hyprlock if needed
if ! $HYPRIDLE_INSTALLED || ! $HYPRLOCK_INSTALLED; then
    log_step "installing hypridle and hyprlock"
    PACKAGES_TO_INSTALL=""
    if ! $HYPRIDLE_INSTALLED; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hypridle"
    fi
    if ! $HYPRLOCK_INSTALLED; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL hyprlock"
    fi

    if ! run_with_progress "installing idle/lock tools" \
        sudo dnf install -y $PACKAGES_TO_INSTALL; then
        log_error "Failed to install hypridle/hyprlock"
        log_error "Check ~/kit.log for details"
        exit $KIT_EXIT_MODULE_FAILED
    fi

    # Verify installation
    if ! command -v hypridle >/dev/null 2>&1 || ! command -v hyprlock >/dev/null 2>&1; then
        log_error "hypridle/hyprlock installation verification failed"
        exit $KIT_EXIT_MODULE_FAILED
    fi
    log_debug "hypridle and hyprlock installed successfully"
fi

# Enable and start hypridle service
log_step "enabling hypridle service"
if ! systemctl --user is-enabled hypridle >/dev/null 2>&1; then
    if ! run_with_progress "enabling hypridle service" \
        systemctl --user enable hypridle; then
        log_warning "Failed to enable hypridle service"
    fi
fi

if ! systemctl --user is-active hypridle >/dev/null 2>&1; then
    if ! run_with_progress "starting hypridle service" \
        systemctl --user start hypridle; then
        log_warning "Failed to start hypridle service (may be compositor-specific)"
    fi
fi

log_success "Niri installation completed successfully"
log_info "Note: Configure hypridle.conf and hyprlock.conf in ~/.config/hypr/"
log_info "Note: hypridle may show warnings when not in Hyprland - this is expected"
exit 0
