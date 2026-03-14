#!/bin/bash

# Main setup function - can be sourced or executed directly
main_setup() {
    # Get the directory of this script
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Load exit codes first (needed by all other libraries)
    source "$KITBASH_LIB/exitcodes.sh"

    # Load path management library
    source "$KITBASH_LIB/paths.sh"
    if ! init_paths; then
        echo "ERROR: Failed to initialize kitbash paths" >&2
        return $KIT_EXIT_ERROR
    fi

    # Verify installation integrity
    if ! verify_installation; then
        echo "ERROR: Kitbash installation verification failed" >&2
        return $KIT_EXIT_ERROR
    fi

    # Check if we're running a specific module or help (config is optional)
    # vs running full setup (config is required)
    if [ $# -gt 0 ]; then
        case "$1" in
            help|-h|--help)
                # Help command doesn't need config
                export KITBASH_REQUIRE_CONFIG=false
                ;;
            *)
                # Check if it's a module
                if [ -f "$KITBASH_MODULES/$1.sh" ]; then
                    export KITBASH_REQUIRE_CONFIG=false
                else
                    export KITBASH_REQUIRE_CONFIG=true
                fi
                ;;
        esac
    else
        export KITBASH_REQUIRE_CONFIG=true
    fi

    # Load configuration management library
    source "$KITBASH_LIB/config.sh"
    if ! init_config; then
        # Only error if config was required
        if [ "$KITBASH_REQUIRE_CONFIG" = "true" ]; then
            echo "ERROR: Failed to load configuration" >&2
            return $?  # Propagate specific config error code
        fi
    fi

    # Set legacy variables for backwards compatibility (temporary)
    _scripts="$KITBASH_MODULES/"
    _packages="$KITBASH_PACKAGES"
    _desktop=$(echo $XDG_CURRENT_DESKTOP)

    # Load remaining library functions
    source "$KITBASH_LIB/logging.sh"
    source "$KITBASH_LIB/pkg.sh"
    source "$KITBASH_LIB/validation.sh"
    source "$KITBASH_LIB/module-runner.sh"
    source "$KITBASH_LIB/setup-functions.sh"
    source "$KITBASH_LIB/state.sh"

    # Initialize logging and state tracking
    log_init

    # jq is required for state tracking; install now if missing
    if ! command -v jq >/dev/null 2>&1; then
        log_info "Installing required dependency: jq"
        source "$KITBASH_MODULES/jq.sh"
    fi

    state_init

    # Validate preferences before any execution
    validate_preferences "$1"

    # Check if first argument matches a module name
    requested_module="$1"

    if [ -n "$requested_module" ] && [ "$requested_module" != "help" ] && [ "$requested_module" != "-h" ] && [ "$requested_module" != "--help" ]; then
        # Check if it's a valid module (script exists)
        script_file="$_scripts${requested_module}.sh"
        if [ -f "$script_file" ]; then
            log_info "Initializing..."
            log_debug "Requested module: $requested_module"
            sudo -n true 2>/dev/null || sudo -v || return 1

            # If override arguments provided (e.g. `run-setup.sh module arg`),
            # pass them through so module can consume values. Otherwise, when
            # the user explicitly asked for a module (e.g. `kit dotfiles`) we
            # should run the module regardless of kit.conf booleans. That means
            # we bypass the preference-based skipping logic in
            # process_module and run the module with defaults.
            local module_exit_code
            if [ ${#@} -gt 1 ]; then
                # There are extra args after the module name; let process_module
                # handle them (it will call the module with provided args).
                process_module "$script_file" "${@:2}"
                module_exit_code=$?
            else
                # No override args — run the module unconditionally with
                # default behavior (ignore kit.conf boolean values).
                run_module_with_defaults "$requested_module" "$script_file"
                module_exit_code=$?
            fi

            state_record_module "$requested_module" "$module_exit_code"
            state_write
            return $module_exit_code
        fi
    fi

    # Handle special cases and fallbacks
    case "$requested_module" in
        "help"|"-h"|"--help")
            show_usage
            return 0
            ;;
        "")
            # Run full setup with module discovery
            log_info "Initializing..."
            sudo -n true 2>/dev/null || sudo -v || return 1

            # Run discovered modules
            run_discovered_modules
            ;;
        *)
            if [ -n "$requested_module" ]; then
                log_error "Unknown module '$requested_module'"
                echo ""
                echo "Available modules:"
                for script_file in "$_scripts"*.sh; do
                    if [ -f "$script_file" ]; then
                        module_name=$(basename "$script_file" .sh)
                        echo "  - $module_name"
                    fi
                done
                echo ""
                echo "Use '$0 help' for more information."
                return 1
            fi
            ;;
    esac
}

# If this script is executed directly (not sourced), run main_setup
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main_setup "$@"
fi