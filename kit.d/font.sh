#!/bin/bash

# Module: font.sh
# Purpose: Download and install fonts from URLs or local paths
# Tier: 2 (Core Desktop Environment)
# Description: Downloads and installs fonts from URLs to ~/.local/share/fonts
# Installs: none (fonts downloaded to ~/.local/share/fonts)

PRIMARY_FONT="${1:-$_font}"

if [ -z "$PRIMARY_FONT" ]; then
    log_error "No primary font specified"
    return $KIT_EXIT_INVALID_INPUT
fi

log_info "Installing fonts (primary: $PRIMARY_FONT)"

# Ensure required tools are available
for _tool in wget unzip fc-cache; do
    if ! command -v "$_tool" >/dev/null 2>&1; then
        case "$_tool" in
            fc-cache) _pkg="$(pkg_name fontconfig)" ;;
            *)        _pkg="$_tool" ;;
        esac
        log_step "installing missing dependency: $_pkg"
        pkg_install "$_pkg"
    fi
done

# Ensure fonts directory exists
FONTS_DIR="$HOME/.local/share/fonts"
log_debug "Fonts directory: $FONTS_DIR"
mkdir -p "$FONTS_DIR"

# Get list of currently installed fonts
log_debug "Checking installed fonts"
INSTALLED_FONTS=$(fc-list : family | sort -u)

# Function to check if a font family is already installed
is_font_installed() {
    local font_name="$1"
    echo "$INSTALLED_FONTS" | grep -qiF "$font_name"
}

# Function to install a single font
# Returns 0 on success (installed or already present), 1 on failure
# Sets FONT_WAS_INSTALLED=true if newly installed, false if skipped
install_font() {
    local font_name="$1"
    local font_url="$2"

    # Check if already installed
    if is_font_installed "$font_name"; then
        log_success "Font '$font_name' is already installed"
        FONT_WAS_INSTALLED=false
        return 0
    fi

    log_step "installing font: $font_name"
    log_debug "Font URL: $font_url"

    # Download to temp directory
    TEMP_DIR=$(mktemp -d)
    log_debug "Temp directory: $TEMP_DIR"

    # Download the font
    FONT_FILE="$TEMP_DIR/$(basename "$font_url")"
    log_debug "Downloading to: $FONT_FILE"

    if ! run_with_progress "downloading $font_name" wget -q "$font_url" -O "$FONT_FILE"; then
        log_error "Failed to download font"
        rm -rf "$TEMP_DIR"
        FONT_WAS_INSTALLED=false
        return 1
    fi

    # Handle zip files
    if [[ "$FONT_FILE" == *.zip ]]; then
        EXTRACT_DIR="$TEMP_DIR/font_extracted"
        mkdir -p "$EXTRACT_DIR"

        if ! run_with_progress "extracting $font_name" unzip -q "$FONT_FILE" -d "$EXTRACT_DIR"; then
            log_error "Failed to extract font archive"
            rm -rf "$TEMP_DIR"
            FONT_WAS_INSTALLED=false
            return 1
        fi

        # Copy all font files to fonts directory
        log_step "copying font files for $font_name"
        log_debug "Finding font files in $EXTRACT_DIR"
        find "$EXTRACT_DIR" -type f \( -name "*.ttf" -o -name "*.otf" -o -name "*.TTF" -o -name "*.OTF" \) -exec cp {} "$FONTS_DIR/" \;
    else
        # Not a zip, assume it's a direct font file
        log_step "copying font file for $font_name"
        cp "$FONT_FILE" "$FONTS_DIR/"
    fi

    # Clean up
    log_debug "Cleaning up temp directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"

    log_success "Installed font: $font_name"
    FONT_WAS_INSTALLED=true
    return 0
}

# Install all predefined fonts
FONTS_INSTALLED=0
FONTS_SKIPPED=0
FONTS_FAILED=0

for definition in "${_font_definitions[@]}"; do
    name="${definition%%:*}"
    url="${definition#*:}"

    if install_font "$name" "$url"; then
        # Success - check if it was actually installed or already present
        if [ "$FONT_WAS_INSTALLED" = "true" ]; then
            FONTS_INSTALLED=$((FONTS_INSTALLED + 1))
        else
            FONTS_SKIPPED=$((FONTS_SKIPPED + 1))
        fi
    else
        FONTS_FAILED=$((FONTS_FAILED + 1))
        log_warning "Failed to install font: $name"
    fi
done

# Rebuild font cache if any fonts were installed
if [ $FONTS_INSTALLED -gt 0 ]; then
    run_with_progress "rebuilding font cache" fc-cache -f
fi

# Summary
log_info "Font installation summary:"
log_info "  Installed: $FONTS_INSTALLED"
log_info "  Already present: $FONTS_SKIPPED"
if [ $FONTS_FAILED -gt 0 ]; then
    log_warning "  Failed: $FONTS_FAILED"
fi

log_success "Font installation complete (primary font: $PRIMARY_FONT)"

# Return error only if all fonts failed
if [ $FONTS_FAILED -gt 0 ] && [ $FONTS_INSTALLED -eq 0 ] && [ $FONTS_SKIPPED -eq 0 ]; then
    return $KIT_EXIT_MODULE_FAILED
fi

return $KIT_EXIT_SUCCESS
