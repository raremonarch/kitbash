#!/bin/bash

# Module: obsidian.sh
# Purpose: Install Obsidian markdown editor
# Tier: 4 (Applications)
# Description: Obsidian markdown knowledge base editor (AUR on Arch, AppImage on Fedora)
# Installs: obsidian

log_info "Installing Obsidian markdown editor"

# Check if Obsidian is already installed
if command -v obsidian >/dev/null 2>&1; then
    log_success "Obsidian is already installed"
    return 0
fi

case "$KITBASH_PKG_MANAGER" in
    dnf)
        # AppImages require FUSE2 libraries to run - install if missing
        if ! rpm -q fuse-libs >/dev/null 2>&1; then
            log_step "installing FUSE2 libraries for AppImage support"
            if ! run_with_progress "installing fuse-libs" sudo dnf install -y fuse-libs; then
                log_error "Failed to install FUSE2 libraries"
                return $KIT_EXIT_DEPENDENCY_MISSING
            fi
        fi

        # Define version and download URL
        OBSIDIAN_VERSION="1.10.3"
        OBSIDIAN_URL="https://github.com/obsidianmd/obsidian-releases/releases/download/v${OBSIDIAN_VERSION}/Obsidian-${OBSIDIAN_VERSION}.AppImage"
        INSTALL_DIR="/usr/local/bin"
        APPIMAGE_NAME="obsidian"

        # Download the AppImage
        if ! run_with_progress "downloading Obsidian AppImage v${OBSIDIAN_VERSION}" \
            curl -L -o "/tmp/Obsidian.AppImage" "$OBSIDIAN_URL"; then
            log_error "Failed to download Obsidian AppImage"
            return $KIT_EXIT_NETWORK_ERROR
        fi

        # Make it executable
        log_step "making AppImage executable"
        chmod +x "/tmp/Obsidian.AppImage"

        # Install to /usr/local/bin
        if ! run_with_progress "installing Obsidian to ${INSTALL_DIR}" \
            sudo mv "/tmp/Obsidian.AppImage" "${INSTALL_DIR}/${APPIMAGE_NAME}"; then
            log_error "Failed to install Obsidian to ${INSTALL_DIR}"
            return $KIT_EXIT_MODULE_FAILED
        fi

        # Create desktop entry for app launcher integration
        log_step "creating desktop entry"
        sudo tee /usr/share/applications/obsidian.desktop > /dev/null << EOF
[Desktop Entry]
Name=Obsidian
Comment=Obsidian - Markdown-based knowledge base
Exec=${INSTALL_DIR}/${APPIMAGE_NAME} %u
Terminal=false
Type=Application
Icon=obsidian
StartupWMClass=obsidian
Categories=Office;TextEditor;
MimeType=x-scheme-handler/obsidian;
EOF

        # Extract icon from AppImage (if possible)
        log_step "extracting application icon"
        cd /tmp
        if ${INSTALL_DIR}/${APPIMAGE_NAME} --appimage-extract obsidian.png >/dev/null 2>&1; then
            if [ -f "/tmp/squashfs-root/obsidian.png" ]; then
                sudo mkdir -p /usr/share/icons/hicolor/512x512/apps
                sudo cp /tmp/squashfs-root/obsidian.png /usr/share/icons/hicolor/512x512/apps/obsidian.png
                rm -rf /tmp/squashfs-root
                log_debug "Icon extracted successfully"
            fi
        else
            log_debug "Could not extract icon (non-fatal)"
        fi

        # Update desktop database
        if command -v update-desktop-database >/dev/null 2>&1; then
            run_quiet "updating desktop database" sudo update-desktop-database /usr/share/applications
        fi
        ;;
    pacman)
        if ! run_with_progress "installing Obsidian" \
            pkg_aur_install obsidian; then
            log_error "Failed to install Obsidian"
            return $KIT_EXIT_MODULE_FAILED
        fi
        ;;
    *)
        log_error "Obsidian installation not supported on $KITBASH_PKG_MANAGER"
        return $KIT_EXIT_MODULE_FAILED
        ;;
esac

# Verify installation
if command -v obsidian >/dev/null 2>&1; then
    log_success "Obsidian installed successfully"
    return 0
else
    log_error "Obsidian installation verification failed"
    return $KIT_EXIT_MODULE_FAILED
fi
