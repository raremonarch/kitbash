#!/bin/bash

# Module: sddm.sh
# Purpose: Install and configure SDDM login manager
# Tier: 1 (System Fundamentals)
# Description: SDDM display manager with Wayland support
# Installs: sddm
# Config-var: _display_manager
# Config-match: sddm

log_info "Setting up SDDM login manager"

# Install sddm
if ! run_with_progress "installing SDDM" pkg_install sddm; then
    log_error "Failed to install SDDM"
    exit $KIT_EXIT_MODULE_FAILED
fi

# Enable sddm.service so it starts on boot
if ! systemctl is-enabled sddm >/dev/null 2>&1; then
    if ! run_with_progress "enabling SDDM service" sudo systemctl enable sddm; then
        log_error "Failed to enable SDDM service"
        exit $KIT_EXIT_MODULE_FAILED
    fi
fi

# Allow the sddm user to traverse the home directory to reach theme symlinks
# 711 lets other users enter (but not list) the home directory
if [ "$(stat -c '%a' "$HOME")" = "700" ]; then
    log_step "setting home directory to 711 for sddm theme access"
    chmod 711 "$HOME"
fi

# Symlink themes from dotfiles into system theme directory
DOTFILES_THEMES="$HOME/system-configs/sddm/themes"
SYSTEM_THEMES="/usr/share/sddm/themes"
if [ -d "$DOTFILES_THEMES" ]; then
    for theme_dir in "$DOTFILES_THEMES"/*/; do
        theme_name=$(basename "$theme_dir")
        if [ ! -e "$SYSTEM_THEMES/$theme_name" ]; then
            log_step "linking SDDM theme: $theme_name"
            sudo ln -s "$theme_dir" "$SYSTEM_THEMES/$theme_name"
        else
            log_debug "SDDM theme already present: $theme_name"
        fi

        # Install dependencies declared in metadata.desktop
        metadata="$theme_dir/metadata.desktop"
        if [ -f "$metadata" ]; then
            dep_key="X-KitDependencies-$KITBASH_PKG_MANAGER"
            deps=$(grep "^$dep_key=" "$metadata" | cut -d= -f2-)
            if [ -n "$deps" ]; then
                log_step "installing theme dependencies for $theme_name: $deps"
                # shellcheck disable=SC2086
                run_with_progress "installing $theme_name dependencies" pkg_install $deps
            fi
        fi
    done
fi

# Patch system-specific values into theme.conf files
THEME_CONF="$HOME/system-configs/sddm/themes/hyprlock-sddm-theme/theme.conf"
if [ -f "$THEME_CONF" ]; then
    # Patch wallpaper path from _wallpaper_definitions or direct path
    if [ -n "${_wallpaper:-}" ]; then
        # Resolve wallpaper to full system path
        wallpaper_path=""
        for def in "${_wallpaper_definitions[@]:-}"; do
            name="${def%%:*}"
            if [ "$name" = "$_wallpaper" ]; then
                ext="${def##*.}"
                wallpaper_path="/usr/share/backgrounds/wallpaper.$ext"
                break
            fi
        done
        # Fallback: treat _wallpaper as a direct path
        [ -z "$wallpaper_path" ] && wallpaper_path="$_wallpaper"

        if [ -n "$wallpaper_path" ]; then
            log_step "patching SDDM theme wallpaper: $wallpaper_path"
            sudo sed -i "s|^background=.*|background=$wallpaper_path|" "$THEME_CONF"
        fi
    fi

    # Patch accent color from _accent_color
    if [ -n "${_accent_color:-}" ]; then
        log_step "patching SDDM theme accent color: $_accent_color"
        sudo sed -i "s|^AccentColor=.*|AccentColor=$_accent_color|" "$THEME_CONF"
    fi
fi

# Deploy sddm.conf.d files from dotfiles to /etc/sddm.conf.d/
DOTFILES_CONFD="$HOME/system-configs/sddm/sddm.conf.d"
if [ -d "$DOTFILES_CONFD" ]; then
    sudo mkdir -p /etc/sddm.conf.d
    for conf_file in "$DOTFILES_CONFD"/*.conf; do
        [ -f "$conf_file" ] || continue
        dest="/etc/sddm.conf.d/$(basename "$conf_file")"
        if [ ! -e "$dest" ]; then
            log_step "linking SDDM config: $(basename "$conf_file")"
            sudo ln -s "$conf_file" "$dest"
        else
            log_debug "SDDM config already present: $(basename "$conf_file")"
        fi
    done
fi

# Optional config — only applies if /etc/sddm.conf exists
SDDM_CONFIG="/etc/sddm.conf"
if [ -f "$SDDM_CONFIG" ]; then
    if sudo grep -q "^DisplayServer=x11" "$SDDM_CONFIG"; then
        log_step "switching to Wayland mode"
        sudo sed -i 's|^DisplayServer=x11|# DisplayServer=wayland|' "$SDDM_CONFIG"
    fi
fi

log_success "SDDM installed and enabled"
log_info "Note: SDDM will start on next boot. To start now: sudo systemctl start sddm"
