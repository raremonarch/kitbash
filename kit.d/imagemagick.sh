#!/bin/bash

# Module: imagemagick.sh
# Purpose: Install ImageMagick image manipulation tools
# Tier: 5 (Applications)
# Description: ImageMagick image manipulation and conversion suite
# Installs: ImageMagick

log_info "Installing ImageMagick"

# Check if already installed
if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    log_success "ImageMagick is already installed"
    exit 0
fi

run_with_progress "installing ImageMagick" sudo dnf install -y ImageMagick

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    log_success "ImageMagick installed successfully"
else
    log_error "ImageMagick installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
