#!/bin/bash

# Module: sunshine.sh
# Purpose: Install Sunshine game/desktop streaming server
# Tier: 5 (Applications)
# Description: Sunshine self-hosted streaming server (KMS capture, Wayland-compatible)
# Installs: sunshine

log_info "Installing Sunshine streaming server"

if command -v sunshine >/dev/null 2>&1; then
    log_success "Sunshine is already installed"
    return 0
fi

case "$KITBASH_PKG_MANAGER" in
    dnf)
        FEDORA_VER="$(rpm -E %fedora)"
        SUNSHINE_RPM_URL="https://github.com/LizardByte/Sunshine/releases/latest/download/sunshine-fedora-${FEDORA_VER}-amd64.rpm"
        TEMP_RPM="/tmp/sunshine-fedora-${FEDORA_VER}-amd64.rpm"

        if ! run_with_progress "downloading Sunshine" \
            curl -L -o "$TEMP_RPM" "$SUNSHINE_RPM_URL"; then
            log_error "Failed to download Sunshine RPM"
            return $KIT_EXIT_NETWORK_ERROR
        fi

        if ! run_with_progress "installing Sunshine" \
            sudo dnf install -y "$TEMP_RPM"; then
            rm -f "$TEMP_RPM"
            log_error "Failed to install Sunshine"
            return $KIT_EXIT_MODULE_FAILED
        fi

        rm -f "$TEMP_RPM"
        ;;
    pacman)
        log_info "Installing Sunshine from AUR (this may take a few minutes)..."
        if ! pkg_aur_install sunshine; then
            log_error "Failed to install Sunshine from AUR"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    *)
        log_error "Sunshine installation not supported on $KITBASH_PKG_MANAGER"
        return $KIT_EXIT_MODULE_FAILED
        ;;
esac

if ! command -v sunshine >/dev/null 2>&1; then
    log_error "Sunshine installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi

# Add current user to the input group (required for gamepad/keyboard capture)
if ! groups "$USER" | grep -q '\binput\b'; then
    run_with_progress "adding $USER to input group" \
        sudo usermod -aG input "$USER"
    log_warning "Group change requires re-login to take effect"
fi

# Enable the Sunshine user service
if ! systemctl --user is-enabled sunshine >/dev/null 2>&1; then
    run_with_progress "enabling Sunshine user service" \
        systemctl --user enable --now sunshine
fi

log_success "Sunshine installed successfully"
log_step "Web UI available at https://localhost:47990 after login"
