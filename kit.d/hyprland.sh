#!/bin/bash

# Module: hyprland.sh
# Purpose: Install Hyprland dynamic tiling Wayland compositor and ecosystem tools
# Tier: 1 (System Fundamentals)
# Description: Hyprland dynamic tiling compositor with lock, idle, wallpaper, and workspace plugins
# Installs: hyprland, hyprlock, hypridle, hyprpaper, hyprland-plugin-hyprexpo
# Config-var: _compositor
# Config-match: hyprland

log_info "Setting up Hyprland compositor and ecosystem"

# Check if Hyprland core is already installed
HYPRLAND_INSTALLED=false
if command -v Hyprland >/dev/null 2>&1; then
    HYPRLAND_VERSION=$(Hyprland --version 2>&1 | head -n1 || echo "unknown")
    log_debug "Hyprland core already installed: $HYPRLAND_VERSION"
    HYPRLAND_INSTALLED=true
fi

# Check ecosystem tools
HYPRLOCK_INSTALLED=false
HYPRIDLE_INSTALLED=false
HYPRPAPER_INSTALLED=false
HYPREXPO_INSTALLED=false

if command -v hyprlock >/dev/null 2>&1; then
    log_debug "hyprlock already installed"
    HYPRLOCK_INSTALLED=true
fi

if command -v hypridle >/dev/null 2>&1; then
    log_debug "hypridle already installed"
    HYPRIDLE_INSTALLED=true
fi

if command -v hyprpaper >/dev/null 2>&1; then
    log_debug "hyprpaper already installed"
    HYPRPAPER_INSTALLED=true
fi

if pkg_installed hyprland-plugin-hyprexpo 2>/dev/null; then
    log_debug "hyprexpo already installed"
    HYPREXPO_INSTALLED=true
fi

# If everything is installed, exit early
if $HYPRLAND_INSTALLED && $HYPRLOCK_INSTALLED && $HYPRIDLE_INSTALLED && $HYPRPAPER_INSTALLED && $HYPREXPO_INSTALLED; then
    log_success "Hyprland and all ecosystem tools are already installed"
    exit 0
fi

if [ "$KITBASH_DISTRO" = "arch" ]; then
    # ---------------------------------------------------------------------------
    # Arch: all Hyprland packages are in the official extra repo
    # ---------------------------------------------------------------------------
    PACKAGES_TO_INSTALL=()
    $HYPRLAND_INSTALLED || PACKAGES_TO_INSTALL+=(hyprland)
    $HYPRLOCK_INSTALLED  || PACKAGES_TO_INSTALL+=(hyprlock)
    $HYPRIDLE_INSTALLED  || PACKAGES_TO_INSTALL+=(hypridle)
    $HYPRPAPER_INSTALLED || PACKAGES_TO_INSTALL+=(hyprpaper)
    # hyprexpo is AUR on Arch; skip for now
    HYPREXPO_INSTALLED=true

    if [ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]; then
        if ! run_with_progress "installing ${PACKAGES_TO_INSTALL[*]}" \
            pkg_install "${PACKAGES_TO_INSTALL[@]}"; then
            log_error "Failed to install Hyprland packages"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi

else
    # ---------------------------------------------------------------------------
    # Fedora: Wayland deps check, COPR repos required
    # ---------------------------------------------------------------------------

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

    # Enable COPR repository for Hyprland ecosystem tools if needed
    COPR_ENABLED=false
    if ! $HYPRLOCK_INSTALLED || ! $HYPRIDLE_INSTALLED || ! $HYPRPAPER_INSTALLED || ! $HYPREXPO_INSTALLED; then
        log_step "checking for solopasha/hyprland COPR repository"
        if ! dnf copr list 2>/dev/null | grep -q "copr:copr.fedorainfracloud.org:solopasha:hyprland"; then
            log_step "enabling solopasha/hyprland COPR repository"
            if run_with_progress "enabling COPR repo" \
                sudo dnf copr enable -y solopasha/hyprland; then
                log_debug "COPR repository enabled successfully"
                COPR_ENABLED=true
            else
                log_error "Failed to enable COPR repository"
                exit $KIT_EXIT_MODULE_FAILED
            fi
        else
            log_debug "COPR repository already enabled"
            COPR_ENABLED=true
        fi
    fi

    # Install Hyprland core if not installed
    if ! $HYPRLAND_INSTALLED; then
        log_step "installing Hyprland from Fedora repos"
        if ! run_with_progress "installing hyprland package" \
            sudo dnf install -y hyprland; then
            log_error "Failed to install Hyprland"
            exit $KIT_EXIT_MODULE_FAILED
        fi

        if command -v Hyprland >/dev/null 2>&1; then
            HYPRLAND_VERSION=$(Hyprland --version 2>&1 | head -n1 || echo "installed")
            log_debug "Hyprland installed successfully: $HYPRLAND_VERSION"
        else
            log_error "Hyprland installation verification failed"
            exit $KIT_EXIT_MODULE_FAILED
        fi
    fi

    # Install ecosystem tools from COPR if needed
    if $COPR_ENABLED; then
        $HYPRLOCK_INSTALLED || run_with_progress "installing hyprlock" \
            sudo dnf install -y hyprlock || log_warning "Failed to install hyprlock from COPR"
        $HYPRIDLE_INSTALLED || run_with_progress "installing hypridle" \
            sudo dnf install -y hypridle || log_warning "Failed to install hypridle from COPR"
        $HYPRPAPER_INSTALLED || run_with_progress "installing hyprpaper" \
            sudo dnf install -y hyprpaper || log_warning "Failed to install hyprpaper from COPR"
        $HYPREXPO_INSTALLED || run_with_progress "installing hyprexpo" \
            sudo dnf install -y hyprland-plugin-hyprexpo || log_warning "Failed to install hyprexpo from COPR"
    fi
fi

# Final verification
MISSING_TOOLS=()
command -v Hyprland >/dev/null 2>&1 || MISSING_TOOLS+=("hyprland")
command -v hyprlock >/dev/null 2>&1 || MISSING_TOOLS+=("hyprlock")
command -v hypridle >/dev/null 2>&1 || MISSING_TOOLS+=("hypridle")
command -v hyprpaper >/dev/null 2>&1 || MISSING_TOOLS+=("hyprpaper")
pkg_installed hyprland-plugin-hyprexpo 2>/dev/null || MISSING_TOOLS+=("hyprexpo")

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    log_warning "Some tools could not be installed: ${MISSING_TOOLS[*]}"
    log_error "Installation incomplete - please check errors above"
    exit $KIT_EXIT_MODULE_FAILED
fi

log_success "Hyprland and all ecosystem tools installed successfully"

exit 0
