#!/bin/bash

# Module: theme.sh
# Purpose: Install GTK theme for dark mode support (Catppuccin)
# Tier: 4 (Applications)
# Description: Installs Catppuccin Mocha GTK theme for dark mode desktop environments
# Installs: sassc, gtk-murrine-engine, gnome-themes-extra (build dependencies)

THEME="${1:-$_theme}"

# Default to catppuccin if not specified or just "true"
if [ -z "$THEME" ] || [ "$THEME" = "true" ]; then
    THEME="catppuccin"
fi

log_info "Installing GTK theme: $THEME"

# Install dependencies
log_step "checking dependencies"
DEPS_NEEDED=()
if ! rpm -q sassc >/dev/null 2>&1; then
    DEPS_NEEDED+=("sassc")
fi
if ! rpm -q gtk-murrine-engine >/dev/null 2>&1; then
    DEPS_NEEDED+=("gtk-murrine-engine")
fi
if ! rpm -q gnome-themes-extra >/dev/null 2>&1; then
    DEPS_NEEDED+=("gnome-themes-extra")
fi

if [ ${#DEPS_NEEDED[@]} -gt 0 ]; then
    log_step "installing dependencies: ${DEPS_NEEDED[*]}"
    if ! run_with_progress "installing theme dependencies" sudo dnf install -y "${DEPS_NEEDED[@]}"; then
        log_error "Failed to install dependencies"
        return $KIT_EXIT_DEPENDENCY_MISSING
    fi
else
    log_success "All dependencies already installed"
fi

# Clone the Catppuccin GTK theme repository
THEME_DIR=$(mktemp -d)
log_debug "Temporary directory: $THEME_DIR"

log_step "downloading Catppuccin GTK theme"
if ! run_with_progress "cloning theme repository" git clone --depth=1 https://github.com/Fausto-Korpsvart/Catppuccin-GTK-Theme.git "$THEME_DIR"; then
    log_error "Failed to clone Catppuccin GTK theme repository"
    rm -rf "$THEME_DIR"
    return $KIT_EXIT_NETWORK_ERROR
fi

# Run the installation script
log_step "installing theme files"
cd "$THEME_DIR"

# Install the theme with the specified variant
# Using: -c dark (dark mode), -l (link libadwaita for GTK4)
if ! run_with_progress "running theme installer" ./install.sh -c dark -l 2>&1; then
    log_warning "Theme installation may have encountered issues"
fi

# Clean up
cd - >/dev/null
rm -rf "$THEME_DIR"

# Set the GTK theme
log_step "configuring GTK to use Catppuccin theme"
gsettings set org.gnome.desktop.interface gtk-theme "Catppuccin-GTK-Dark"
gsettings set org.gnome.desktop.interface color-scheme "prefer-dark"

# Check if theme was installed
if [ -d "$HOME/.themes/Catppuccin-GTK-Dark" ] || [ -d "$HOME/.local/share/themes/Catppuccin-GTK-Dark" ]; then
    log_success "Catppuccin GTK theme installed successfully"
    log_info "Restart your applications to see the dark theme"
    return $KIT_EXIT_SUCCESS
else
    log_error "Theme installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
