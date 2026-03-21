#!/bin/bash

# Module: wallpaper.sh
# Purpose: Download and configure wallpapers for desktop/lock/login
# Tier: 2 (Core Desktop Environment)
# Description: Downloads wallpapers from URLs and applies them to desktop, lock screen, and login
# Installs: none (wallpapers downloaded to ~/Pictures/wallpapers)

# Check if wallpaper path is provided as first parameter
if [ -z "$1" ]; then
    log_error "No wallpaper path provided. Usage: $0 <wallpaper_path_or_name>"
    return 1
fi

_wallpaper_input="$1"
log_debug "Wallpaper input: $_wallpaper_input"

# Function to resolve wallpaper name to URL from definitions
resolve_wallpaper_name() {
    local name="$1"
    for definition in "${_wallpaper_definitions[@]}"; do
        if [[ "$definition" == "$name:"* ]]; then
            echo "${definition#*:}"
            return 0
        fi
    done
    return 1
}

# Function to download wallpaper from URL
download_wallpaper() {
    local url="$1"
    local name="$2"
    
    # Extract file extension from URL (remove query parameters first)
    local url_without_params="${url%%\?*}"
    local extension="${url_without_params##*.}"
    # If no extension found, extension contains path separators, or extension is too long, default to jpg
    if [ -z "$extension" ] || [[ "$extension" == */* ]] || [ "${#extension}" -gt 4 ]; then
        extension="jpg"
    fi
    
    local output_file="$HOME/wallpaper.$extension"

    log_debug "Downloading from: $url to $output_file"

    if command -v curl >/dev/null 2>&1; then
        if run_with_progress "downloading wallpaper '$name'" curl -fsSL "$url" -o "$output_file"; then
            # Return the output file path via stdout (last line)
            echo "$output_file"
            return 0
        else
            return 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if run_with_progress "downloading wallpaper '$name'" wget -q "$url" -O "$output_file"; then
            # Return the output file path via stdout (last line)
            echo "$output_file"
            return 0
        else
            return 1
        fi
    else
        log_error "No curl or wget available"
        return 1
    fi
}

# Resolve wallpaper input to actual file path and normalize to ~/wallpaper.(ext)
_wallpaper_source=""
if [[ "$_wallpaper_input" == *"/"* ]] && [ -f "$_wallpaper_input" ]; then
    # It's a file path that exists
    _wallpaper_source="$_wallpaper_input"
elif [ -f "$_wallpaper_input" ]; then
    # It's a file in current directory
    _wallpaper_source="$_wallpaper_input"
else
    # Try to resolve as predefined wallpaper name
    wallpaper_url=$(resolve_wallpaper_name "$_wallpaper_input")
    if [ $? -eq 0 ] && [ -n "$wallpaper_url" ]; then
        log_step "resolved '$_wallpaper_input' as predefined wallpaper"
        log_debug "Wallpaper URL: $wallpaper_url"
        # Download wallpaper - the function will print progress and return the file path
        download_output=$(download_wallpaper "$wallpaper_url" "$_wallpaper_input")
        download_exit_code=$?
        if [ $download_exit_code -eq 0 ]; then
            # Extract the file path from the last line of output
            _wallpaper_source=$(echo "$download_output" | tail -1)
            if [ -f "$_wallpaper_source" ]; then
                log_debug "Downloaded to: $_wallpaper_source"
            else
                log_error "Download succeeded but file not found: $_wallpaper_source"
                return 1
            fi
        else
            log_error "Failed to download wallpaper"
            return 1
        fi
    else
        log_error "'$_wallpaper_input' is not a valid file path or predefined wallpaper name"
        log_error ""
        if [ ${#_wallpaper_definitions[@]} -gt 0 ]; then
            log_error "Available predefined wallpapers:"
            for definition in "${_wallpaper_definitions[@]}"; do
                local name="${definition%%:*}"
                log_error "  - $name"
            done
        else
            log_error "No predefined wallpapers configured in kit.conf"
            log_error "Add wallpapers to _wallpaper_definitions array in the format:"
            log_error "  _wallpaper_definitions=("
            log_error "    \"name:https://example.com/wallpaper.jpg\""
            log_error "  )"
        fi
        return 1
    fi
fi

# Final check if wallpaper source file exists
if [ ! -f "$_wallpaper_source" ]; then
    log_error "Wallpaper file '$_wallpaper_source' not found"
    return 1
fi

# Normalize: Copy/move source to ~/wallpaper.(ext) for consistent naming
_source_ext="${_wallpaper_source##*.}"
_wallpaper_path="$HOME/wallpaper.$_source_ext"

# Only copy if it's not already at the target location
if [ "$_wallpaper_source" != "$_wallpaper_path" ]; then
    if ! run_with_progress "normalizing wallpaper to ~/wallpaper.$_source_ext" cp "$_wallpaper_source" "$_wallpaper_path"; then
        log_error "Failed to normalize wallpaper"
        return 1
    fi
fi

# Use consistent naming for all operations
_wallpaper_name="wallpaper.$_source_ext"
_wallpaper_base="wallpaper"
_wallpaper_ext="$_source_ext"
log_debug "Normalized wallpaper path: $_wallpaper_path"

# Source the configuration to get wallpaper targets and definitions
if [ -f "$KITBASH_CONFIG" ]; then
    source "$KITBASH_CONFIG"
else
    log_error "Could not find kit.conf - required for wallpaper definitions"
    log_error "Please ensure kit.conf exists in your kitbash root directory"
    return 1
fi

# Verify required variables are loaded
if [ -z "${_wallpaper_targets[*]}" ]; then
    log_warning "_wallpaper_targets not found in kit.conf, using defaults"
    _wallpaper_targets=("desktop" "lock" "login")
fi

if [ -z "${_wallpaper_definitions[*]}" ]; then
    log_warning "_wallpaper_definitions not found in kit.conf"
    log_warning "Predefined wallpaper names will not work"
    _wallpaper_definitions=()
fi

log_debug "Wallpaper targets: ${_wallpaper_targets[*]}"

# Ensure ImageMagick is available — needed for dimension detection and wallpaper splitting
if ! command -v magick >/dev/null 2>&1; then
    log_step "installing ImageMagick"
    source "$KITBASH_MODULES/imagemagick.sh"
fi

# Check if ImageMagick is available for dimension detection
if ! command -v magick >/dev/null 2>&1; then
    log_warning "ImageMagick not found — cannot detect image dimensions"
    _is_dual_monitor=false
else
    # Get image dimensions using ImageMagick
    log_step "detecting image dimensions"
    _dimensions=$(magick identify -format "%wx%h" "$_wallpaper_path")
    _exit_code=$?

    if [ $_exit_code -eq 0 ] && [ -n "$_dimensions" ]; then
        _width=$(echo "$_dimensions" | cut -d'x' -f1)
        _height=$(echo "$_dimensions" | cut -d'x' -f2)
        log_debug "Image dimensions: ${_width}x${_height}"

        # Calculate aspect ratio to determine if it's likely a dual monitor setup
        # Typical dual monitor setups: 3840x1080 (2x1920x1080), 2560x1024 (2x1280x1024), etc.
        # Look for aspect ratios wider than 2.5:1 (normal widescreen is ~1.78:1)
        if command -v bc >/dev/null 2>&1; then
            _aspect_ratio=$(echo "scale=2; $_width / $_height" | bc -l 2>/dev/null || echo "0")
            _aspect_check=$(echo "$_aspect_ratio > 2.5" | bc -l 2>/dev/null || echo "0")
        else
            # Fallback calculation without bc (less precise)
            _aspect_times_10=$((($_width * 10) / $_height))
            if [ $_aspect_times_10 -gt 25 ]; then
                _aspect_check="1"
                _aspect_ratio="$_aspect_times_10.0/10"
            else
                _aspect_check="0"
                _aspect_ratio="$_aspect_times_10.0/10"
            fi
        fi

        if [ "$_aspect_check" = "1" ]; then
            log_debug "Detected ultra-wide aspect ratio ($_aspect_ratio:1) - likely dual monitor wallpaper"
            _is_dual_monitor=true
        else
            log_debug "Detected standard aspect ratio ($_aspect_ratio:1) - single monitor wallpaper"
            _is_dual_monitor=false
        fi
    else
        log_debug "Failed to detect dimensions"
        # Fallback to filename detection
        if [[ "$_wallpaper_name" == *"dual"* ]] || [[ "$_wallpaper_name" == *"monitor"* ]] || [[ "$_wallpaper_name" == *"wide"* ]]; then
            log_debug "Fallback: detected dual monitor keywords in filename"
            _is_dual_monitor=true
        else
            _is_dual_monitor=false
        fi
    fi
fi

# Define system paths for the wallpapers
_system_wallpaper_dir="/usr/share/backgrounds"
_system_wallpaper="$_system_wallpaper_dir/$_wallpaper_name"
_system_split_0="$_system_wallpaper_dir/${_wallpaper_base}-0.${_wallpaper_ext}"
_system_split_1="$_system_wallpaper_dir/${_wallpaper_base}-1.${_wallpaper_ext}"
log_debug "System wallpaper paths: $_system_wallpaper, $_system_split_0, $_system_split_1"

# Ensure system wallpaper directory exists (may not on a fresh Arch install)
sudo mkdir -p "$_system_wallpaper_dir"

# Copy original wallpaper to system directory (needed for all targets)
if ! run_with_progress "copying wallpaper to system directory" sudo cp "$_wallpaper_path" "$_system_wallpaper"; then
    log_error "Failed to copy wallpaper to system directory"
    return 1
fi

# Handle dual monitor wallpaper splitting if needed for desktop target
if [ "$_is_dual_monitor" = true ] && [[ " ${_wallpaper_targets[*]} " == *" desktop "* ]]; then
    log_step "detected dual monitor wallpaper for Sway desktop"

    # Check if split versions need to be created/updated
    # Create if they don't exist OR if the main wallpaper is newer than the split versions
    if [ ! -f "$_system_split_0" ] || [ ! -f "$_system_split_1" ] || [ "$_system_wallpaper" -nt "$_system_split_0" ]; then
        log_debug "Creating/updating split wallpapers"

        # Check if ImageMagick is available
        if ! command -v magick >/dev/null 2>&1; then
            log_error "ImageMagick not found — cannot split dual monitor wallpaper"
            return 1
        fi

        if ! run_with_progress "splitting wallpaper into dual monitor versions" sudo magick "$_system_wallpaper" -crop 50%x100% +repage +adjoin "${_system_wallpaper_dir}/${_wallpaper_base}-%d.${_wallpaper_ext}"; then
            log_error "Failed to split wallpaper"
            return 1
        fi

        # Verify split files were created
        if [ ! -f "$_system_split_0" ] || [ ! -f "$_system_split_1" ]; then
            log_error "Split wallpaper files not created properly"
            return 1
        fi
    else
        log_debug "Split wallpapers already exist in system directory"
    fi
fi

# Function to configure Sway desktop wallpaper
configure_sway_desktop() {
    SWAY_CONFIG="$HOME/.config/sway/config"
    if [ ! -f "$SWAY_CONFIG" ]; then
        log_debug "Sway config not found at $SWAY_CONFIG"
        return 1
    fi

    if [ "$_is_dual_monitor" = true ]; then
        # Check for existing output lines with bg settings
        if grep -q "^output.*bg.*" "$SWAY_CONFIG"; then
            log_step "updating Sway desktop (dual monitor)"
            log_debug "Updating Sway output lines for dual monitor wallpapers"

            # Update existing output lines to use the system split wallpapers
            sed -i "s|^output HDMI-A-1.*bg.*|output HDMI-A-1 pos    0 0 bg $_system_split_0 fill|" "$SWAY_CONFIG"
            sed -i "s|^output HDMI-A-2.*bg.*|output HDMI-A-2 pos 1920 0 bg $_system_split_1 fill|" "$SWAY_CONFIG"
        else
            log_warning "No Sway output configurations found with wallpaper settings"
            log_warning "Dual monitor wallpapers created but not applied to Sway config"
        fi
    else
        # Single monitor wallpaper handling
        if grep -q "^output.*bg.*" "$SWAY_CONFIG"; then
            log_step "updating Sway desktop (single monitor)"
            log_debug "Updating Sway output lines for single wallpaper"

            # Update existing output lines to use the same single wallpaper on both monitors
            sed -i "s|^output HDMI-A-1.*bg.*|output HDMI-A-1 pos    0 0 bg $_system_wallpaper fill|" "$SWAY_CONFIG"
            sed -i "s|^output HDMI-A-2.*bg.*|output HDMI-A-2 pos 1920 0 bg $_system_wallpaper fill|" "$SWAY_CONFIG"
        fi
    fi
}

# Function to configure Hyprland desktop wallpaper
configure_hyprland_desktop() {
    HYPRLAND_CONFIG="$HOME/.config/hypr/hyprland.conf"
    if [ ! -f "$HYPRLAND_CONFIG" ]; then
        log_debug "Hyprland config not found at $HYPRLAND_CONFIG"
        return 1
    fi

    # Ensure hyprpaper is in autostart
    if ! grep -q "^exec-once = hyprpaper" "$HYPRLAND_CONFIG"; then
        log_debug "Adding hyprpaper to Hyprland autostart"
        # Find the AUTOSTART section and add hyprpaper as the first exec-once
        sed -i '/^### AUTOSTART ###$/a exec-once = hyprpaper' "$HYPRLAND_CONFIG"
    fi

    # Check if hyprpaper is being used
    if grep -q "hyprpaper" "$HYPRLAND_CONFIG"; then
        if [ "$_is_dual_monitor" = true ]; then
            log_step "updating Hyprland desktop (dual monitor)"
            log_debug "Updating Hyprland hyprpaper commands for dual monitor wallpapers"

            # Update preload command
            sed -i "s|exec = hyprctl hyprpaper preload .*|exec = hyprctl hyprpaper preload $_system_split_0\nexec = hyprctl hyprpaper preload $_system_split_1|" "$HYPRLAND_CONFIG"
            # Update wallpaper assignments for each monitor
            sed -i "s|exec = hyprctl hyprpaper wallpaper \"HDMI-A-1,.*\"|exec = hyprctl hyprpaper wallpaper \"HDMI-A-1,$_system_split_0\"|" "$HYPRLAND_CONFIG"
            sed -i "s|exec = hyprctl hyprpaper wallpaper \"HDMI-A-2,.*\"|exec = hyprctl hyprpaper wallpaper \"HDMI-A-2,$_system_split_1\"|" "$HYPRLAND_CONFIG"

            # Apply wallpaper immediately if in Hyprland session
            if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
                log_debug "Applying dual monitor wallpapers via hyprctl"

                # Check if hyprpaper is running
                if pgrep -x hyprpaper >/dev/null 2>&1; then
                    log_debug "Restarting hyprpaper daemon to ensure clean output"
                    pkill -x hyprpaper
                    sleep 0.2
                fi

                # Start hyprpaper with output redirected
                log_debug "Starting hyprpaper daemon"
                hyprpaper >/dev/null 2>&1 &
                disown
                # Give it a moment to start
                sleep 0.5

                # Apply wallpaper commands
                hyprctl hyprpaper preload "$_system_split_0" 2>/dev/null || true
                hyprctl hyprpaper preload "$_system_split_1" 2>/dev/null || true
                hyprctl hyprpaper wallpaper "HDMI-A-1,$_system_split_0" 2>/dev/null || true
                hyprctl hyprpaper wallpaper "HDMI-A-2,$_system_split_1" 2>/dev/null || true
            fi
        else
            log_step "updating Hyprland desktop (single monitor)"
            log_debug "Updating Hyprland hyprpaper commands for single wallpaper"

            # Update preload command
            sed -i "s|exec = hyprctl hyprpaper preload .*|exec = hyprctl hyprpaper preload $_system_wallpaper|" "$HYPRLAND_CONFIG"
            # Update wallpaper assignments for all monitors
            sed -i "s|exec = hyprctl hyprpaper wallpaper \"HDMI-A-1,.*\"|exec = hyprctl hyprpaper wallpaper \"HDMI-A-1,$_system_wallpaper\"|" "$HYPRLAND_CONFIG"
            sed -i "s|exec = hyprctl hyprpaper wallpaper \"HDMI-A-2,.*\"|exec = hyprctl hyprpaper wallpaper \"HDMI-A-2,$_system_wallpaper\"|" "$HYPRLAND_CONFIG"

            # Apply wallpaper immediately if in Hyprland session
            if command -v hyprctl >/dev/null 2>&1 && hyprctl version >/dev/null 2>&1; then
                log_debug "Applying single wallpaper via hyprctl"

                # Check if hyprpaper is running
                if pgrep -x hyprpaper >/dev/null 2>&1; then
                    log_debug "Restarting hyprpaper daemon to ensure clean output"
                    pkill -x hyprpaper
                    sleep 0.2
                fi

                # Start hyprpaper with output redirected
                log_debug "Starting hyprpaper daemon"
                hyprpaper >/dev/null 2>&1 &
                disown
                # Give it a moment to start
                sleep 0.5

                # Apply wallpaper commands
                hyprctl hyprpaper preload "$_system_wallpaper" 2>/dev/null || true
                hyprctl hyprpaper wallpaper "HDMI-A-1,$_system_wallpaper" 2>/dev/null || true
                hyprctl hyprpaper wallpaper "HDMI-A-2,$_system_wallpaper" 2>/dev/null || true
            fi
        fi

        return 0
    else
        log_warning "No hyprpaper configuration found in Hyprland config"
        return 1
    fi
}

# Function to configure swaylock wallpaper
configure_swaylock() {
    SWAYLOCK_CONFIG="$HOME/.config/swaylock/config"
    SWAY_CONFIG="$HOME/.config/sway/config"

    if [ ! -f "$SWAYLOCK_CONFIG" ]; then
        log_debug "Swaylock config not found at $SWAYLOCK_CONFIG"
        return 1
    fi

    # Choose appropriate wallpaper for lock screen
    local lock_wallpaper
    if [ "$_is_dual_monitor" = true ]; then
        # Use first half of split image for lock screen (looks better than full-width stretched)
        lock_wallpaper="$_system_split_0"
    else
        lock_wallpaper="$_system_wallpaper"
    fi

    log_step "updating swaylock configuration"
    log_debug "Lock wallpaper: $lock_wallpaper"

    # Update only the image path in existing swaylock config
    sed -i "s|^image=.*|image=$lock_wallpaper|" "$SWAYLOCK_CONFIG"

    # Update Sway config to use simple swaylock commands (swaylock will read its own config)
    if [ -f "$SWAY_CONFIG" ]; then
        # Update swayidle configuration to use simple swaylock command
        sed -i "s|swaylock -f -i [^']*|swaylock -f|g" "$SWAY_CONFIG"
        sed -i "s|swaylock -f -c [^']*|swaylock -f|g" "$SWAY_CONFIG"

        # Update manual lock keybinding to use simple swaylock command
        sed -i "s|\$mod+l exec swaylock[^\"]*|\$mod+l exec swaylock -f|" "$SWAY_CONFIG"
    fi

    return 0
}

# Function to configure Hyprlock wallpaper
configure_hyprlock() {
    HYPRLOCK_CONFIG="$HOME/.config/hypr/hyprlock.conf"

    if [ ! -f "$HYPRLOCK_CONFIG" ]; then
        log_debug "Hyprlock config not found at $HYPRLOCK_CONFIG"
        return 1
    fi

    # Choose appropriate wallpaper for lock screen
    local lock_wallpaper
    if [ "$_is_dual_monitor" = true ]; then
        # Use first half of split image for lock screen (looks better than full-width stretched)
        lock_wallpaper="$_system_split_0"
    else
        lock_wallpaper="$_system_wallpaper"
    fi

    log_step "updating Hyprlock configuration"
    log_debug "Lock wallpaper: $lock_wallpaper"

    # Update the path in the background block
    sed -i "s|^\s*path = .*|    path = $lock_wallpaper|" "$HYPRLOCK_CONFIG"

    return 0
}

# Function to configure SDDM wallpaper
configure_sddm() {
    SDDM_THEME_CONFIG="/usr/share/sddm/themes/custom/theme.conf"
    if [ ! -f "$SDDM_THEME_CONFIG" ]; then
        log_debug "SDDM custom theme config not found at $SDDM_THEME_CONFIG"
        return 0  # Not an error if SDDM isn't installed
    fi

    # Choose appropriate wallpaper for login screen
    local login_wallpaper
    if [ "$_is_dual_monitor" = true ]; then
        # Use first half of split image for login screen (looks better than full-width stretched)
        login_wallpaper="$_system_split_0"
    else
        login_wallpaper="$_system_wallpaper"
    fi

    log_step "updating SDDM login screen"
    log_debug "Login wallpaper: $login_wallpaper"

    if ! sudo sed -i "s|^background=.*|background=$login_wallpaper|" "$SDDM_THEME_CONFIG"; then
        log_error "Failed to update SDDM theme (insufficient permissions)"
        return 1
    fi

    # Ensure SDDM is configured to use the custom theme
    SDDM_CONFIG="/etc/sddm.conf"
    if [ -f "$SDDM_CONFIG" ] && ! sudo grep -q "^Current=custom" "$SDDM_CONFIG"; then
        log_debug "Configuring SDDM to use custom theme"
        if ! sudo sed -i 's|#Current=.*|Current=custom|' "$SDDM_CONFIG"; then
            log_error "Failed to configure SDDM (insufficient permissions)"
            return 1
        fi
    fi

    return 0
}

# Function to configure Niri desktop wallpaper
configure_niri_desktop() {
    NIRI_CONFIG="$HOME/.config/niri/config.kdl"
    if [ ! -f "$NIRI_CONFIG" ]; then
        log_debug "Niri config not found at $NIRI_CONFIG"
        return 1
    fi

    # Niri uses swaybg for wallpapers
    if ! command -v swaybg >/dev/null 2>&1; then
        log_step "installing swaybg"
        pkg_install swaybg
    fi

    if ! command -v swaybg >/dev/null 2>&1; then
        log_warning "swaybg not available — skipping desktop wallpaper"
        return 1
    fi

    if [ "$_is_dual_monitor" = true ]; then
        log_step "updating Niri desktop (dual monitor)"
        log_debug "Updating Niri swaybg command for dual monitor wallpapers"

        # For dual monitor, we use the full wallpaper image
        # swaybg will stretch it across all outputs
        local wallpaper_cmd="pkill swaybg; swaybg -i $_system_wallpaper -m fill"

        # Update or add swaybg spawn command in Niri config
        if grep -q "spawn.*swaybg" "$NIRI_CONFIG"; then
            sed -i "s|spawn.*swaybg.*|spawn-sh-at-startup \"$wallpaper_cmd\"|" "$NIRI_CONFIG"
        else
            # Add after waybar spawn line
            sed -i "/spawn.*waybar/a \\
\\
// Wallpaper background daemon\\
spawn-sh-at-startup \"$wallpaper_cmd\"" "$NIRI_CONFIG"
        fi

        # Apply wallpaper immediately if in Niri session
        if command -v niri >/dev/null 2>&1 && pgrep -x niri >/dev/null 2>&1; then
            log_debug "Applying dual monitor wallpaper via swaybg"
            pkill swaybg 2>/dev/null || true
            swaybg -i "$_system_wallpaper" -m fill >/dev/null 2>&1 &
            disown
        fi
    else
        log_step "updating Niri desktop (single monitor)"
        log_debug "Updating Niri swaybg command for single wallpaper"

        local wallpaper_cmd="pkill swaybg; swaybg -i $_system_wallpaper -m fill"

        # Update or add swaybg spawn command in Niri config
        if grep -q "spawn.*swaybg" "$NIRI_CONFIG"; then
            sed -i "s|spawn.*swaybg.*|spawn-sh-at-startup \"$wallpaper_cmd\"|" "$NIRI_CONFIG"
        else
            # Add after waybar spawn line
            sed -i "/spawn.*waybar/a \\
\\
// Wallpaper background daemon\\
spawn-sh-at-startup \"$wallpaper_cmd\"" "$NIRI_CONFIG"
        fi

        # Apply wallpaper immediately if in Niri session
        if command -v niri >/dev/null 2>&1 && pgrep -x niri >/dev/null 2>&1; then
            log_debug "Applying single wallpaper via swaybg"
            pkill swaybg 2>/dev/null || true
            swaybg -i "$_system_wallpaper" -m fill >/dev/null 2>&1 &
            disown
        fi
    fi

    return 0
}

# Detect which compositor is running.
# Use XDG_CURRENT_DESKTOP first (authoritative for the live session),
# then fall back to pgrep. Config file presence is NOT used — a user may
# have configs for multiple compositors installed simultaneously.
_compositor=""
if [[ "$XDG_CURRENT_DESKTOP" == *"Hyprland"* ]]; then
    _compositor="hyprland"
elif [[ "$XDG_CURRENT_DESKTOP" == *"sway"* ]]; then
    _compositor="sway"
elif [[ "$XDG_CURRENT_DESKTOP" == *"niri"* ]]; then
    _compositor="niri"
elif pgrep -x niri >/dev/null 2>&1; then
    _compositor="niri"
elif pgrep -x Hyprland >/dev/null 2>&1; then
    _compositor="hyprland"
elif pgrep -x sway >/dev/null 2>&1; then
    _compositor="sway"
else
    log_warning "Could not detect running compositor (Sway, Hyprland, or Niri)"
    _compositor="unknown"
fi
log_debug "Detected compositor: $_compositor (XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP)"

# Apply wallpaper to specified targets
log_debug "Applying wallpaper to targets: ${_wallpaper_targets[*]}"
for target in "${_wallpaper_targets[@]}"; do
    case "$target" in
        "desktop")
            if [ "$_compositor" = "hyprland" ]; then
                configure_hyprland_desktop
            elif [ "$_compositor" = "sway" ]; then
                configure_sway_desktop
            elif [ "$_compositor" = "niri" ]; then
                configure_niri_desktop
            else
                log_warning "Unknown compositor, skipping desktop wallpaper configuration"
            fi
            ;;
        "lock")
            if [ "$_compositor" = "hyprland" ]; then
                configure_hyprlock
            elif [ "$_compositor" = "sway" ]; then
                configure_swaylock
            elif [ "$_compositor" = "niri" ]; then
                configure_swaylock  # Niri can use swaylock too
            else
                log_warning "Unknown compositor, skipping lock screen wallpaper configuration"
            fi
            ;;
        "login")
            configure_sddm
            ;;
        *)
            log_warning "Unknown wallpaper target '$target'"
            ;;
    esac
done

# Create default symlink for compatibility (only if not dual monitor or desktop not in targets)
if [ "$_is_dual_monitor" = false ] || [[ ! " ${_wallpaper_targets[*]} " == *" desktop "* ]]; then
    # Remove existing default wallpaper if it exists and is not our target
    if [ -f "/usr/share/backgrounds/default" ] && [ "$(readlink /usr/share/backgrounds/default)" != "$_system_wallpaper" ]; then
        log_debug "Removing old default wallpaper symlink"
        sudo rm -f /usr/share/backgrounds/default
    fi

    # Create symlink to new wallpaper
    if ! run_with_progress "setting as system default wallpaper" sudo ln -sf "$_system_wallpaper" /usr/share/backgrounds/default; then
        log_error "Failed to create wallpaper symlink"
    fi
fi

# Reload compositor configuration if any compositor-related targets were configured
if [[ " ${_wallpaper_targets[*]} " == *" desktop "* ]] || [[ " ${_wallpaper_targets[*]} " == *" lock "* ]]; then
    if [ "$_compositor" = "sway" ]; then
        if run_with_progress "reloading Sway configuration" swaymsg reload; then
            log_debug "Sway configuration reloaded successfully"
        else
            log_debug "Failed to reload Sway (not in Sway session or swaymsg not available)"
        fi
    elif [ "$_compositor" = "hyprland" ]; then
        if run_with_progress "reloading Hyprland configuration" hyprctl reload; then
            log_debug "Hyprland configuration reloaded successfully"
        else
            log_debug "Failed to reload Hyprland (not in Hyprland session or hyprctl not available)"
        fi
    elif [ "$_compositor" = "niri" ]; then
        log_debug "Niri wallpaper applied directly via swaybg, no reload needed"
        # Niri config changes require restart, but wallpaper is already applied
    fi
fi

log_success "Wallpaper configured successfully"
return 0