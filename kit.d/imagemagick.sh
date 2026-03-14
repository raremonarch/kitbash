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
    return 0
fi

# Package is 'imagemagick' on Arch, 'ImageMagick' on Fedora
case "$KITBASH_DISTRO" in
    arch) pkg_install imagemagick ;;
    *)    pkg_install ImageMagick ;;
esac

if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    log_success "ImageMagick installed successfully"
else
    log_error "ImageMagick installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
