#!/bin/bash

# Module: easyeffects.sh
# Purpose: Install EasyEffects audio processor and enable background service
# Tier: 4 (Applications)
# Description: PipeWire audio processor with LV2 plugins for microphone and audio enhancement
# Installs: easyeffects, lsp-plugins-lv2

AUTOSTART_DESKTOP="$HOME/.config/autostart/easyeffects-service.desktop"

log_info "Installing EasyEffects"

# Check if already installed and autostart already configured
if command -v easyeffects >/dev/null 2>&1; then
    if systemctl --user is-enabled easyeffects >/dev/null 2>&1 || \
       [ -f "$AUTOSTART_DESKTOP" ]; then
        log_success "EasyEffects is already installed and configured for autostart"
        exit 0
    fi
fi

# Install EasyEffects and LSP plugins (high-quality compressor, EQ, etc.)
run_with_progress "installing EasyEffects" \
    pkg_install easyeffects lsp-plugins-lv2

if ! command -v easyeffects >/dev/null 2>&1; then
    log_error "EasyEffects installation failed"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Try systemd user service first (available on some distro/version combos)
AUTOSTART_CONFIGURED=false
if systemctl --user cat easyeffects >/dev/null 2>&1; then
    if run_with_progress "enabling EasyEffects service" \
        systemctl --user enable --now easyeffects; then
        AUTOSTART_CONFIGURED=true
    fi
fi

# Fall back to XDG autostart .desktop file (works on all compositors)
if [ "$AUTOSTART_CONFIGURED" = false ]; then
    mkdir -p "$HOME/.config/autostart"
    cat > "$AUTOSTART_DESKTOP" << 'EOF'
[Desktop Entry]
Name=EasyEffects Service
Comment=EasyEffects audio processing background service
Exec=easyeffects --gapplication-service
Icon=easyeffects
Terminal=false
Type=Application
Categories=AudioVideo;Audio;
StartupNotify=false
X-GNOME-Autostart-enabled=true
EOF
    easyeffects --gapplication-service >/dev/null 2>&1 &
    disown
    log_step "autostart configured via XDG (~/.config/autostart/)"
fi

log_success "EasyEffects installed and configured for autostart"
log_step "Open the EasyEffects app to configure your microphone processing chain"
