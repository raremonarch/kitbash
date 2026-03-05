#!/bin/bash

# Source path management to set KITBASH_ROOT and related variables
source "$(dirname "$0")/lib/paths.sh"
init_paths

# Require interactive terminal
require_interactive() {
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        echo "[ERROR] This script must be run in an interactive terminal (not piped or redirected)." >&2
        exit 1
    fi
}


# Prompt user for input with default value (interactive only)
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    printf "%s [%s]: " "$prompt" "$default"
    read -r result
    if [ -z "$result" ]; then
        result="$default"
    fi
    PROMPT_RESULT="$result"
}

# Prompt user for yes/no with default (interactive only)
prompt_yes_no() {
    local prompt="$1"
    local default="$2"
    if [ "$default" = "y" ]; then
        printf "%s [Y/n]: " "$prompt"
    else
        printf "%s [y/N]: " "$prompt"
    fi
    read -r result
    if [ -z "$result" ]; then
        result="$default"
    fi
    PROMPT_RESULT="$result"
    if [[ "$PROMPT_RESULT" =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

# This script can be downloaded and executed directly:
#   curl -fsSL https://raw.githubusercontent.com/daevski/kitbash/main/kit-start.sh | bash
#
# Or downloaded and run with options:
#   curl -fsSL https://raw.githubusercontent.com/daevski/kitbash/main/kit-start.sh -o kit-start.sh
#   chmod +x kit-start.sh
#   ./kit-start.sh

set -eo pipefail  # Exit on error, pipe failures (nounset disabled for debugging)

# Default configuration (can be overridden by user input)
DEFAULT_REPO_OWNER="daevski"
DEFAULT_REPO_NAME="dotfiles"
DEFAULT_BRANCH="main"
DOTFILES_DIR="$KITBASH_ROOT/dotfiles"

# Variables to be set by user input
REPO_OWNER=""
REPO_NAME=""
REPO_URL=""
BRANCH=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Gather repository information from user
gather_repo_info() {
    log_info "Repository Configuration"
    echo ""
    echo "[DEBUG] About to prompt for GitHub username/organization" >&2
    prompt_with_default "GitHub username/organization" "$DEFAULT_REPO_OWNER"
    REPO_OWNER="$PROMPT_RESULT"
    echo "[DEBUG] Got REPO_OWNER: $REPO_OWNER" >&2
    prompt_with_default "Repository name" "$DEFAULT_REPO_NAME"
    REPO_NAME="$PROMPT_RESULT"
    echo "[DEBUG] Got REPO_NAME: $REPO_NAME" >&2
    prompt_with_default "Branch to use" "$DEFAULT_BRANCH"
    BRANCH="$PROMPT_RESULT"
    echo "[DEBUG] Got BRANCH: $BRANCH" >&2
    REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"
    echo ""
    log_info "Will clone: $REPO_URL (branch: $BRANCH)"
    echo ""
}

# Customize kit.conf based on user preferences
customize_setup_config() {
    local setup_conf="$KITBASH_ROOT/kit.conf"

    if [ ! -f "$setup_conf" ]; then
        log_error "kit.conf not found - cannot customize"
        return 1
    fi
    
    log_info "Setup Configuration"
    echo ""
    
    if prompt_yes_no "Would you like to customize the setup configuration?" "n"; then
        echo ""
        log_info "Let's customize your setup..."
        
        # Hostname
        current_hostname=$(grep "^_hostname=" "$setup_conf" | cut -d"'" -f2)
        prompt_with_default "System hostname" "${current_hostname:-$(hostname)}"
        new_hostname="$PROMPT_RESULT"
        sed -i "s/^_hostname=.*/_hostname='$new_hostname'/" "$setup_conf"
        
        # Terminal
        current_terminal=$(grep "^_terminal=" "$setup_conf" | cut -d"'" -f2)
        echo ""
        echo "Available terminals: alacritty, gnome-terminal, kitty, wezterm"
        prompt_with_default "Preferred terminal" "${current_terminal:-alacritty}"
        new_terminal="$PROMPT_RESULT"
        sed -i "s/^_terminal=.*/_terminal='$new_terminal'/" "$setup_conf"
        
        # Editor
        current_editor=$(grep "^_editor=" "$setup_conf" | cut -d"'" -f2)
        echo ""
        echo "Available editors: vim, nvim, nano, code"
        prompt_with_default "Preferred editor" "${current_editor:-vim}"
        new_editor="$PROMPT_RESULT"
        sed -i "s/^_editor=.*/_editor='$new_editor'/" "$setup_conf"
        
        # Wallpaper
        current_wallpaper=$(grep "^_wallpaper=" "$setup_conf" | cut -d"'" -f2)
        echo ""
        echo "Available predefined wallpapers:"
        
        # Extract wallpaper names from _wallpaper_definitions
        if grep -q "_wallpaper_definitions" "$setup_conf"; then
            # Show available wallpapers
            grep "_wallpaper_definitions" -A 20 "$setup_conf" | grep '".*:.*"' | while read line; do
                if [[ "$line" =~ \"([^:]+): ]]; then
                    echo "  - ${BASH_REMATCH[1]}"
                fi
            done
            echo "  - (or enter a file path)"
        else
            echo "  - fractal-colors, mountain-lake, forest-mist, city-lights, abstract-waves"
            echo "  - (or enter a file path)"
        fi
        
        prompt_with_default "Wallpaper choice" "${current_wallpaper:-fractal-colors}"
        new_wallpaper="$PROMPT_RESULT"
        sed -i "s/^_wallpaper=.*/_wallpaper='$new_wallpaper'/" "$setup_conf"
        
        # Optional modules
        echo ""
        log_info "Optional Modules (you can enable/disable these):"
        
        # Docker
        docker_pref=$(grep "^_docker=" "$setup_conf" | cut -d= -f2)
        docker_default="n"; [ "$docker_pref" = "true" ] && docker_default="y"
        if prompt_yes_no "Enable Docker?" "$docker_default"; then
            sed -i "s/^_docker=.*/_docker=true/" "$setup_conf"
        else
            sed -i "s/^_docker=.*/_docker=false/" "$setup_conf"
        fi

        # Google Chrome
        chrome_pref=$(grep "^_google_chrome=" "$setup_conf" | cut -d= -f2)
        chrome_default="n"; [ "$chrome_pref" = "true" ] && chrome_default="y"
        if prompt_yes_no "Install Google Chrome?" "$chrome_default"; then
            sed -i "s/^_google_chrome=.*/_google_chrome=true/" "$setup_conf"
        else
            sed -i "s/^_google_chrome=.*/_google_chrome=false/" "$setup_conf"
        fi

        # VS Code
        vscode_pref=$(grep "^_vscode=" "$setup_conf" | cut -d= -f2)
        vscode_default="n"; [ "$vscode_pref" = "true" ] && vscode_default="y"
        if prompt_yes_no "Install VS Code?" "$vscode_default"; then
            sed -i "s/^_vscode=.*/_vscode=true/" "$setup_conf"
        else
            sed -i "s/^_vscode=.*/_vscode=false/" "$setup_conf"
        fi

        # Ollama
        ollama_pref=$(grep "^_ollama=" "$setup_conf" | cut -d= -f2)
        ollama_default="n"; [ "$ollama_pref" = "true" ] && ollama_default="y"
        if prompt_yes_no "Install Ollama (AI models)?" "$ollama_default"; then
            sed -i "s/^_ollama=.*/_ollama=true/" "$setup_conf"
        else
            sed -i "s/^_ollama=.*/_ollama=false/" "$setup_conf"
        fi

        # Synology
        synology_pref=$(grep "^_synology=" "$setup_conf" | cut -d= -f2)
        synology_default="n"; [ "$synology_pref" = "true" ] && synology_default="y"
        if prompt_yes_no "Install Synology Drive?" "$synology_default"; then
            sed -i "s/^_synology=.*/_synology=true/" "$setup_conf"
        else
            sed -i "s/^_synology=.*/_synology=false/" "$setup_conf"
        fi
        
        echo ""
        log_success "Configuration customized successfully!"
        
        # Show summary
        echo ""
        log_info "Configuration Summary:"
        echo "  Hostname: $new_hostname"
        echo "  Terminal: $new_terminal"
        echo "  Editor: $new_editor"
        echo "  Docker: $(grep "^_docker=" "$setup_conf" | cut -d= -f2)"
        echo "  Chrome: $(grep "^_google_chrome=" "$setup_conf" | cut -d= -f2)"
        echo "  VS Code: $(grep "^_vscode=" "$setup_conf" | cut -d= -f2)"
        echo "  Ollama: $(grep "^_ollama=" "$setup_conf" | cut -d= -f2)"
        echo "  Synology: $(grep "^_synology=" "$setup_conf" | cut -d= -f2)"
        echo ""
        
        if ! prompt_yes_no "Does this look correct?" "y"; then
            log_warning "You can manually edit $KITBASH_ROOT/kit.conf later to make changes"
            echo "Aborting setup as requested."
            exit 1
        fi
        
    else
        log_info "Using default configuration from repository"
        
        # Still update hostname to match current system
        current_hostname=$(grep "^_hostname=" "$setup_conf" | cut -d"'" -f2)
        system_hostname=$(hostname)
        if [ "$current_hostname" != "$system_hostname" ]; then
            log_info "Updating hostname from '$current_hostname' to '$system_hostname'"
            sed -i "s/^_hostname=.*/_hostname='$system_hostname'/" "$setup_conf"
        fi
    fi
}

# Check if running on supported system
check_system() {
    log_info "Checking system compatibility..."
    
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        log_error "This setup script is designed for Linux systems only"
        exit 1
    fi
    
    # Check for Fedora (primary target)
    if command -v dnf >/dev/null 2>&1; then
        log_success "Fedora detected - fully supported"
        return 0
    fi
    
    # Check for other package managers
    if command -v apt >/dev/null 2>&1; then
        log_warning "Debian/Ubuntu detected - some features may not work"
    elif command -v pacman >/dev/null 2>&1; then
        log_warning "Arch detected - some features may not work"
    else
        log_warning "Unknown package manager - proceed with caution"
    fi
}

# Install essential dependencies
install_dependencies() {
    log_info "Installing essential dependencies..."
    
    if command -v dnf >/dev/null 2>&1; then
        # Fedora
        sudo dnf install -y git curl wget jq
    elif command -v apt >/dev/null 2>&1; then
        # Debian/Ubuntu
        sudo apt update
        sudo apt install -y git curl wget jq
    elif command -v pacman >/dev/null 2>&1; then
        # Arch
        sudo pacman -S --noconfirm git curl wget jq
    else
        log_error "Could not install dependencies - unknown package manager"
        log_error "Please install git, curl, wget, and jq manually"
        exit 1
    fi
    
    log_success "Dependencies installed"
}

# Clone or update dotfiles repository
setup_dotfiles() {
    log_info "Skipping repository clone: the dotfiles module will manage $HOME directly"
    # The dotfiles module (`kit.d/dotfiles.sh`) manages remotes and performs
    # the fetch/reset into $HOME. We intentionally avoid cloning the
    # dotfiles repository into $KITBASH_ROOT/dotfiles to prevent duplicate
    # flows and to ensure the module operates on $HOME as the working tree.
    return 0
}

# Copy dotfiles to home directory
copy_dotfiles() {
    log_info "Copying dotfiles to kitbash root directory..."
    
    # Create symlinks or copy files as needed
    # Use kit.conf from the repository root (preferred)
    if [ -f "$KITBASH_ROOT/kit.conf" ]; then
        log_info "Found kit.conf in kitbash root; using repository configuration"

        # Customize the configuration
        customize_setup_config
    else
        log_error "kit.conf not found in kitbash root ($KITBASH_ROOT/kit.conf)"
        exit 1
    fi
    
    # Copy other essential files
    if [ -f "$DOTFILES_DIR/packages.txt" ]; then
        cp "$DOTFILES_DIR/packages.txt" "$KITBASH_ROOT/"
    fi
    
    # Copy setup.d directory
    if [ -d "$DOTFILES_DIR/kit.d" ]; then
        cp -r "$DOTFILES_DIR/kit.d" "$KITBASH_ROOT/"
        log_success "Kitbash modules copied"
    else
        log_error "kit.d directory not found"
        exit 1
    fi
    
    # Copy lib directory (includes run-setup.sh)
    if [ -d "$DOTFILES_DIR/lib" ]; then
        mkdir -p "$KITBASH_ROOT/lib"
        cp -r "$DOTFILES_DIR/lib" "$KITBASH_ROOT/lib/"
        log_success "Kitbash library copied"
    else
        log_error "lib directory not found"
        exit 1
    fi
    
    # Copy dotfiles (hidden files)
    for file in "$DOTFILES_DIR"/.*; do
        if [[ -f "$file" && ! "$file" =~ /\.(git|gitignore)$ ]]; then
            filename=$(basename "$file")
            if [[ ! "$filename" =~ ^\.(git|gitignore)$ ]]; then
                cp "$file" "$KITBASH_ROOT/"
            fi
        fi
    done
    
    # Copy directories
    for dir in "$DOTFILES_DIR"/.*/; do
        if [[ -d "$dir" && ! "$dir" =~ /\.git/ ]]; then
            dirname=$(basename "$dir")
            if [[ "$dirname" != ".git" ]]; then
                cp -r "$dir" "$KITBASH_ROOT/"
            fi
        fi
    done
    
    log_success "Dotfiles copied to home directory"
}

# Run the actual setup
run_setup() {
    log_info "Running dotfiles setup..."
    
    cd "$KITBASH_ROOT"
    if [ -f "$KITBASH_LIB/run-setup.sh" ]; then
        # Source the run-setup script to call the main_setup function
        source "$KITBASH_LIB/run-setup.sh"
        if main_setup "$@"; then
            log_success "Kitbash setup completed successfully!"
        else
            log_error "Setup encountered errors"
            exit 1
        fi
    else
        log_error "run-setup.sh not found in lib/"
        exit 1
    fi
}

# Main execution
main() {
    # If first argument matches a module in kit.d/, delegate immediately
    if [[ $# -gt 0 ]] && [ -f "$KITBASH_MODULES/$1.sh" ]; then
        source "$KITBASH_LIB/run-setup.sh"
        main_setup "$@"
        exit $?
    fi

    echo "=== Kitbash Bootstrap Script ==="
    echo "This will set up your Fedora + Sway development environment"
    echo ""

    # Parse arguments
    SKIP_CONFIRMATION=false
    SKIP_PROMPTS=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            -y|--yes)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --defaults)
                SKIP_PROMPTS=true
                REPO_OWNER="$DEFAULT_REPO_OWNER"
                REPO_NAME="$DEFAULT_REPO_NAME"
                BRANCH="$DEFAULT_BRANCH"
                REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"
                shift
                ;;
            --repo)
                if [[ -n "${2:-}" ]]; then
                    # Parse owner/repo from argument
                    if [[ "$2" =~ ^([^/]+)/(.+)$ ]]; then
                        REPO_OWNER="${BASH_REMATCH[1]}"
                        REPO_NAME="${BASH_REMATCH[2]}"
                        BRANCH="${3:-$DEFAULT_BRANCH}"
                        REPO_URL="https://github.com/$REPO_OWNER/$REPO_NAME.git"
                        SKIP_PROMPTS=true
                        shift 2
                    else
                        log_error "Invalid repo format. Use: owner/repo"
                        exit 1
                    fi
                else
                    log_error "--repo requires an argument (owner/repo)"
                    exit 1
                fi
                ;;
            -h|--help)
                if is_kitbash_environment; then
                    echo "=== Dotfiles Management ==="
                    echo ""
                    echo "Existing environment detected - you can use either:"
                    echo ""
                    echo "Module mode (run specific modules):"
                    echo "  $(basename "$0") <module>          # Run specific module"
                    echo "  $(basename "$0") help              # Show available modules"
                    echo ""
                    echo "Bootstrap mode (fresh setup):"
                    echo "  $(basename "$0") [OPTIONS]         # Run full bootstrap"
                    echo ""
                    echo "Bootstrap Options:"
                    echo "  -y, --yes           Skip confirmation prompts"
                    echo "  --defaults          Use all default settings"
                    echo "  --repo OWNER/REPO   Specify GitHub repository"
                    echo ""
                    echo "Available modules:"
                    for script_file in "$KITBASH_MODULES"/*.sh; do
                        if [ -f "$script_file" ]; then
                            module_name=$(basename "$script_file" .sh)
                            echo "  - $module_name"
                        fi
                    done
                else
                    echo "Usage: $(basename "$0") [OPTIONS]"
                    echo ""
                    echo "Options:"
                    echo "  -y, --yes           Skip confirmation prompts"
                    echo "  --defaults          Use all default settings (no interactive prompts)"
                    echo "  --repo OWNER/REPO   Specify GitHub repository (skips repo prompt)"
                    echo "  -h, --help          Show this help message"
                    echo ""
                    echo "Examples:"
                    echo "  $(basename "$0")                           # Interactive setup"
                    echo "  $(basename "$0") --defaults                # Use all defaults (daevski/dotfiles)"
                    echo "  $(basename "$0") --repo myuser/mydotfiles  # Use specific repository"
                    echo "  $(basename "$0") -y --defaults             # Non-interactive with defaults"
                    echo ""
                    echo "This script will:"
                    echo "  1. Prompt for GitHub repository (unless --defaults or --repo used)"
                    echo "  2. Install essential dependencies (git, curl, wget)"
                    echo "  3. Clone/update the dotfiles repository"
                    echo "  4. Optionally customize kit.conf preferences"
                    echo "  5. Copy configuration files to your home directory"
                    echo "  6. Run the full dotfiles setup"
                fi
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done

    # Require interactive terminal
    require_interactive

    # Gather repository info if not provided via arguments
    if [ "$SKIP_PROMPTS" = false ]; then
        gather_repo_info
    fi

    # Confirmation prompt
    if [ "$SKIP_CONFIRMATION" = false ]; then
        echo ""
        log_warning "This will modify your system configuration"
        log_info "Repository: $REPO_URL"
        log_info "Branch: $BRANCH"
        echo ""
        if ! prompt_yes_no "Do you want to continue?" "n"; then
            log_info "Setup cancelled by user"
            exit 0
        fi
        echo ""
    fi

    # Run setup steps
    check_system
    install_dependencies
    # Do not clone/copy dotfiles; the dotfiles module will manage $HOME
    run_setup

    log_success "Bootstrap complete!"
    echo ""
    echo "Your dotfiles have been set up successfully."
    echo "You may need to restart your shell or log out/in for all changes to take effect."
    echo ""
    echo "Useful commands:"
    echo "  $KITBASH_LIB/run-setup.sh              # Re-run full setup"
    echo "  $KITBASH_LIB/run-setup.sh <module>     # Run specific module"
    echo "  $KITBASH_LIB/run-setup.sh help         # Show available modules"
}

# Check if we're in an existing kitbash installation (not necessarily configured)
is_kitbash_environment() {
    # Check if the key files exist that indicate kitbash is installed
    # Note: kit.conf is NOT required - modules can run without it
    if [ -d "$KITBASH_MODULES" ] && [ -f "$KITBASH_LIB/run-setup.sh" ]; then
        return 0  # Yes, we have a kitbash installation
    else
        return 1  # No, we need to bootstrap/install
    fi
}

# Check if we should delegate to existing environment first
if is_kitbash_environment && [ $# -gt 0 ]; then
    # We have arguments and we're in an existing environment
    # Check if the first argument might be a module name or special command
    case "$1" in
        "help"|"-h"|"--help")
            # These are valid run-setup commands, delegate to it
            source "$KITBASH_LIB/run-setup.sh"
            main_setup "$@"
            exit $?
            ;;
        -*)
            # Other flags starting with - should go to main() for bootstrap handling
            ;;
        *)
            # Check if it's a module file in kit.d only
            if [ -f "$KITBASH_MODULES/$1.sh" ]; then
                source "$KITBASH_LIB/run-setup.sh"
                main_setup "$@"
                exit $?
            else
                # Not a valid module, show error and exit
                log_error "Module '$1' not found in kit.d/"
                echo ""
                echo "Available modules:"
                for script_file in "$KITBASH_MODULES"/*.sh; do
                    if [ -f "$script_file" ]; then
                        module_name=$(basename "$script_file" .sh)
                        echo "  - $module_name"
                    fi
                done
                echo ""
                echo "Use '$(basename "$0") --help' for more information"
                exit 1
            fi
            ;;
    esac
fi

# Run main function with all arguments
main "$@"