#!/bin/bash

# Module: sound.sh
# Purpose: Install and configure PipeWire audio stack with ALSA support
# Tier: 1 (System Fundamentals)
# Description: PipeWire audio with WirePlumber session manager, ALSA integration, and utilities
# Installs: pipewire, pipewire-alsa, pipewire-pulse, wireplumber, alsa-utils

log_info "Setting up PipeWire audio"

# Check if already fully configured
if systemctl --user is-active --quiet pipewire && \
   systemctl --user is-active --quiet wireplumber && \
   command -v amixer >/dev/null 2>&1; then
    log_success "PipeWire audio stack is already running"
    exit 0
fi

run_with_progress "installing PipeWire audio stack" \
    pkg_install pipewire pipewire-alsa pipewire-pulse wireplumber alsa-utils

# Enable and start services
run_with_progress "enabling PipeWire" \
    systemctl --user enable --now pipewire pipewire-pulse

run_with_progress "enabling WirePlumber" \
    systemctl --user enable --now wireplumber

# Unmute default outputs
log_step "unmuting Master output"
amixer sset Master unmute >/dev/null 2>&1 || true

# Set a sane default volume if currently at 0
CURRENT_VOL=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{print $2}' || echo "0")
if [ "$CURRENT_VOL" = "0.00" ] || [ "$CURRENT_VOL" = "0" ]; then
    log_step "setting default volume to 80%"
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 80%
fi

# Verify
if systemctl --user is-active --quiet pipewire && \
   systemctl --user is-active --quiet wireplumber; then
    log_success "PipeWire audio stack is running"
    log_step "run 'wpctl status' to see available audio devices"
else
    log_error "PipeWire services failed to start"
    exit $KIT_EXIT_MODULE_FAILED
fi
