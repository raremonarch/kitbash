#!/bin/bash
# Individual setup functions for setupv2.sh

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Functions for individual steps
setup_hostname() {
    local hostname="${1:-$_hostname}"
    log_info "Running module: hostname (value: $hostname)"
    source ${_scripts}hostname.sh "$hostname"
    log_success "Module 'hostname' completed"
}

setup_dotfiles() {
    echo -n "> setting up dotfiles ... "
    source ${_scripts}dotfiles.sh
}

setup_wallpaper() {
    local wallpaper_path="${1:-$_wallpaper}"
    if [ -n "$wallpaper_path" ]; then
        log_info "Running module: wallpaper (value: $wallpaper_path)"
        wallpaper_expanded=$(eval echo "$wallpaper_path")
        source ${_scripts}wallpaper.sh "$wallpaper_expanded"
        log_success "Module 'wallpaper' completed"
    else
        log_debug "Module 'wallpaper': no wallpaper specified, skipping"
    fi
}

setup_font() {
    local font_name="${1:-$_font}"
    if [ -n "$font_name" ]; then
        log_info "Running module: font (value: $font_name)"
        source ${_scripts}font.sh "$font_name"
        log_success "Module 'font' completed"
    else
        log_debug "Module 'font': no font specified, skipping"
    fi
}

setup_ollama() {
    echo "> setting up Ollama AI runtime ... "
    source ${_scripts}ollama.sh
}

setup_cursor() {
    local cursor_theme="${1:-$_cursor}"
    local cursor_size="${2:-$_cursor_size}"
    log_info "Running module: cursor (theme: $cursor_theme, size: $cursor_size)"
    source ${_scripts}cursor.sh "$cursor_theme" "$cursor_size"
    log_success "Module 'cursor' completed"
}

show_usage() {
    local cmd_name="${KITBASH_ALIAS:-kit}"
    echo "Usage: $cmd_name [MODULE] [OPTIONS]"
    echo ""
    echo "Run the full setup or individual modules:"
    echo "  $cmd_name --setup                 Run all enabled modules (discovered automatically)"
    echo "  $cmd_name <module_name>           Run a specific module"
    echo "  $cmd_name log                     Open the kit log file in \$EDITOR"
    echo "  $cmd_name help                    Show this help message"
    echo ""
    echo "Configuration:"
    echo "  _wallpaper_targets         Array of wallpaper locations to update"
    echo "                             Valid values: desktop, lock, login"
    echo "                             Current: (${_wallpaper_targets[*]})"
    echo ""
    echo "Available modules:"
    for script_file in "$_scripts"*.sh; do
        if [ -f "$script_file" ]; then
            module_name=$(basename "$script_file" .sh)
            pref_var="_${module_name}"
            if declare -p "$pref_var" >/dev/null 2>&1; then
                pref_value="${!pref_var}"
                echo "  - $module_name (preference: $pref_var = $pref_value)"
            else
                echo "  - $module_name"
            fi
        fi
    done
    echo ""
    echo "Examples:"
    echo "  $cmd_name google_chrome           Run the google_chrome module"
    echo "  $cmd_name wallpaper ~/Pictures/my-wallpaper.jpg"
    echo "  $cmd_name hostname mycomputer"
}