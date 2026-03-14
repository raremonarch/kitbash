#!/bin/bash
# Path management for Kitbash
# This library provides centralized path detection and management

# Detect and set the kitbash root directory
# This function resolves symlinks and handles various invocation methods
detect_kitbash_root() {
    local script_path

    # Get the real path of the script, resolving all symlinks
    if command -v readlink >/dev/null 2>&1; then
        # Use readlink -f if available (Linux)
        script_path="$(readlink -f "${BASH_SOURCE[1]}")"
    elif command -v greadlink >/dev/null 2>&1; then
        # Use greadlink on macOS (from coreutils)
        script_path="$(greadlink -f "${BASH_SOURCE[1]}")"
    else
        # Fallback: resolve manually (doesn't handle all symlink cases)
        script_path="${BASH_SOURCE[1]}"
        while [ -L "$script_path" ]; do
            dir="$(cd -P "$(dirname "$script_path")" && pwd)"
            script_path="$(readlink "$script_path")"
            [[ $script_path != /* ]] && script_path="$dir/$script_path"
        done
    fi

    # Get the directory containing the script
    local script_dir="$(cd "$(dirname "$script_path")" && pwd)"

    # Determine KITBASH_ROOT based on where this script lives
    # If called from lib/, go up one level
    # If called from kit.d/, go up one level
    # If called from root, use current directory
    if [[ "$script_dir" == */lib ]]; then
        KITBASH_ROOT="$(cd "$script_dir/.." && pwd)"
    elif [[ "$script_dir" == */kit.d ]]; then
        KITBASH_ROOT="$(cd "$script_dir/.." && pwd)"
    else
        KITBASH_ROOT="$script_dir"
    fi

    # Export for use in all child processes
    export KITBASH_ROOT
}

# Initialize all kitbash paths
# Call this once at the start of execution
init_paths() {
    # Detect the root directory if not already set
    if [ -z "$KITBASH_ROOT" ]; then
        detect_kitbash_root
    fi

    # Set and export all standard paths
    export KITBASH_MODULES="$KITBASH_ROOT/kit.d"
    export KITBASH_LIB="$KITBASH_ROOT/lib"
    export KITBASH_CONFIG="$KITBASH_ROOT/kit.conf"
    export KITBASH_CONFIG_EXAMPLE="$KITBASH_ROOT/kit.conf.example"
    export KITBASH_PACKAGES="$KITBASH_ROOT/packages.txt"

    # XDG state directory for runtime-generated files (log, state tracking)
    export KITBASH_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/kitbash"
    export KITBASH_STATE_FILE="$KITBASH_STATE_DIR/state.json"
    export KITBASH_LOG="$KITBASH_STATE_DIR/kit.log"

    # Default alias name for kitbash
    export KITBASH_ALIAS="${KITBASH_ALIAS:-kit}"

    # Validate that we found a valid kitbash installation
    if [ ! -d "$KITBASH_MODULES" ]; then
        echo "ERROR: Kitbash modules directory not found at: $KITBASH_MODULES" >&2
        echo "Are you running this from a valid kitbash installation?" >&2
        return 1
    fi

    if [ ! -d "$KITBASH_LIB" ]; then
        echo "ERROR: Kitbash library directory not found at: $KITBASH_LIB" >&2
        return 1
    fi

    return 0
}

# Verify kitbash installation integrity
verify_installation() {
    local errors=0

    # Check for required directories
    if [ ! -d "$KITBASH_ROOT" ]; then
        echo "ERROR: Kitbash root directory not found: $KITBASH_ROOT" >&2
        errors=$((errors + 1))
    fi

    if [ ! -d "$KITBASH_MODULES" ]; then
        echo "ERROR: Modules directory not found: $KITBASH_MODULES" >&2
        errors=$((errors + 1))
    fi

    if [ ! -d "$KITBASH_LIB" ]; then
        echo "ERROR: Library directory not found: $KITBASH_LIB" >&2
        errors=$((errors + 1))
    fi

    # Check for required library files
    local required_libs=("logging.sh" "pkg.sh" "config.sh" "module-runner.sh" "validation.sh")
    for lib in "${required_libs[@]}"; do
        if [ ! -f "$KITBASH_LIB/$lib" ]; then
            echo "ERROR: Required library not found: $KITBASH_LIB/$lib" >&2
            errors=$((errors + 1))
        fi
    done

    # Check for config file (at least example should exist)
    if [ ! -f "$KITBASH_CONFIG" ] && [ ! -f "$KITBASH_CONFIG_EXAMPLE" ]; then
        echo "ERROR: No configuration file found. Expected either:" >&2
        echo "  - $KITBASH_CONFIG" >&2
        echo "  - $KITBASH_CONFIG_EXAMPLE" >&2
        errors=$((errors + 1))
    fi

    if [ $errors -gt 0 ]; then
        return 1
    fi

    return 0
}

# Print paths for debugging
debug_paths() {
    echo "Kitbash Path Configuration:"
    echo "  KITBASH_ROOT: $KITBASH_ROOT"
    echo "  KITBASH_MODULES: $KITBASH_MODULES"
    echo "  KITBASH_LIB: $KITBASH_LIB"
    echo "  KITBASH_CONFIG: $KITBASH_CONFIG"
    echo "  KITBASH_CONFIG_EXAMPLE: $KITBASH_CONFIG_EXAMPLE"
    echo "  KITBASH_LOG: $KITBASH_LOG"
    echo "  KITBASH_PACKAGES: $KITBASH_PACKAGES"
    echo "  KITBASH_ALIAS: $KITBASH_ALIAS"
}
