#!/bin/bash
# Module discovery and execution functions for setupv2.sh

# Source logging library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/logging.sh"

# Helper function to determine if a preference value should run a module
should_run_module() {
    local pref_value="$1"
    [ "$pref_value" = "true" ] || [ "$pref_value" != "false" -a -n "$pref_value" ]
}

# Helper function to get module execution type and args
get_module_execution_info() {
    local module_name="$1"
    local pref_value="$2"

    # Determine execution type and arguments
    if [ "$pref_value" = "true" ]; then
        echo "boolean_true"
    elif [ "$pref_value" = "false" ]; then
        echo "skip"
    else
        echo "configured"
        echo "$pref_value"
    fi
}

# Helper function to execute a single module
execute_module() {
    local module_name="$1"
    local script_file="$2"
    local execution_type="$3"
    local pref_value="$4"
    
    case "$execution_type" in
        "boolean_true")
            log_debug "Module '$module_name': enabled, running with defaults"
            run_module_with_defaults "$module_name" "$script_file"
            return $?
            ;;
        "configured")
            log_debug "Module '$module_name': configured with value '$pref_value', running"
            run_module_with_value "$module_name" "$script_file" "$pref_value"
            return $?
            ;;
        "skip")
            log_debug "Module '$module_name': disabled, skipping"
            return $KIT_EXIT_MODULE_SKIPPED
            ;;
    esac
}

# Helper function to run module with default values
run_module_with_defaults() {
    local module_name="$1"
    local script_file="$2"

    case "$module_name" in
        "hostname") setup_hostname ;;
        "wallpaper") setup_wallpaper ;;
        "cursor") setup_cursor ;;
        "font") setup_font ;;
        *)
            log_info "Running module: $module_name"
            if (set -- ; source "$script_file"); then
                log_success "Module '$module_name' completed"
                return 0
            else
                local exit_code=$?
                log_error "Module '$module_name' failed with exit code $exit_code"
                log_warning "Continuing with remaining modules..."
                return $exit_code
            fi
            ;;
    esac
}

# Helper function to run module with provided value
run_module_with_value() {
    local module_name="$1"
    local script_file="$2"
    local pref_value="$3"

    case "$module_name" in
        "hostname") setup_hostname "$pref_value" ;;
        "wallpaper") setup_wallpaper "$pref_value" ;;
        "cursor") setup_cursor "$pref_value" "$_cursor_size" ;;
        "font") setup_font "$pref_value" ;;
        *)
            log_info "Running module: $module_name (configured: $pref_value)"
            if (source "$script_file" "$pref_value"); then
                log_success "Module '$module_name' completed"
                return 0
            else
                local exit_code=$?
                log_error "Module '$module_name' failed with exit code $exit_code"
                log_warning "Continuing with remaining modules..."
                return $exit_code
            fi
            ;;
    esac
}

# Helper function to read a specific header value from a module script
get_module_header() {
    local script_file="$1"
    local header_key="$2"
    head -n 15 "$script_file" 2>/dev/null | grep "^# ${header_key}:" | head -n 1 | sed "s/^# ${header_key}:[[:space:]]*//"
}

# Function to process a single discovered module
process_module() {
    local script_file="$1"
    local override_args=("${@:2}")  # All arguments after the first
    local module_name
    local pref_var
    local pref_value
    local config_match
    local execution_info

    module_name=$(basename "$script_file" .sh)

    # Read Config-var header if present, otherwise fall back to _modulename convention
    local config_var_header
    config_var_header=$(get_module_header "$script_file" "Config-var")
    if [ -n "$config_var_header" ]; then
        pref_var="$config_var_header"
    else
        pref_var="_${module_name}"
    fi

    # Read Config-match header if present (only run if config var equals this value)
    config_match=$(get_module_header "$script_file" "Config-match")

    log_debug "Checking module '$module_name' (pref: $pref_var${config_match:+, match: $config_match})"

    # If override arguments provided, use them instead of preferences
    if [ ${#override_args[@]} -gt 0 ]; then
        log_debug "Module '$module_name': using provided arguments: ${override_args[*]}"
        case "$module_name" in
            "hostname") setup_hostname "${override_args[0]}" ;;
            "wallpaper") setup_wallpaper "${override_args[0]}" ;;
            "cursor") setup_cursor "${override_args[0]}" "${override_args[1]:-$_cursor_size}" ;;
            "font") setup_font "${override_args[0]}" ;;
            *)
                log_info "Running module: $module_name (args: ${override_args[*]})"
                if (source "$script_file" "${override_args[@]}"); then
                    log_success "Module '$module_name' completed"
                    return 0
                else
                    local exit_code=$?
                    log_error "Module '$module_name' failed with exit code $exit_code"
                    return $exit_code
                fi
                ;;
        esac
        return 0
    fi

    # Check if preference variable exists
    if ! declare -p "$pref_var" >/dev/null 2>&1; then
        log_debug "Module '$module_name': no preference variable '$pref_var' found, skipping"
        return $KIT_EXIT_MODULE_SKIPPED
    fi

    # Get preference value
    pref_value="${!pref_var}"

    # If Config-match is set, only run if the config value equals the match
    if [ -n "$config_match" ]; then
        if [ "$pref_value" != "$config_match" ]; then
            log_debug "Module '$module_name': $pref_var='$pref_value' != '$config_match', skipping"
            return $KIT_EXIT_MODULE_SKIPPED
        fi
        execute_module "$module_name" "$script_file" "boolean_true" ""
        return $?
    fi

    mapfile -t execution_info < <(get_module_execution_info "$module_name" "$pref_value")

    # Execute the module
    execute_module "$module_name" "$script_file" "${execution_info[@]}"
}

# Helper function to extract tier number from module header
get_module_tier() {
    local script_file="$1"
    local tier_line

    # Extract "# Tier: N" from module header (first 10 lines)
    tier_line=$(head -n 10 "$script_file" 2>/dev/null | grep -i "^# Tier:" | head -n 1)

    if [ -n "$tier_line" ]; then
        # Extract just the number (first digit after "Tier:")
        echo "$tier_line" | grep -oP 'Tier:\s*\K\d+' || echo "999"
    else
        # No tier found - put at end
        echo "999"
    fi
}

# Function to discover and run available modules
run_discovered_modules() {
    validate_required_prefs

    log_info "Discovering available modules in $_scripts"
    log_debug "Scripts directory: $_scripts"

    # Collect all module files with their tier numbers
    declare -a module_list
    for script_file in "$_scripts"*.sh; do
        if [ -f "$script_file" ]; then
            tier=$(get_module_tier "$script_file")
            module_name=$(basename "$script_file" .sh)
            # Format: "tier:filepath" for sorting
            module_list+=("${tier}:${script_file}")
            log_debug "Module '$module_name' assigned to tier $tier"
        fi
    done

    # Sort modules by tier number
    IFS=$'\n' sorted_modules=($(sort -t: -k1 -n <<<"${module_list[*]}"))
    unset IFS

    log_info "Executing modules in tier order"

    # Process modules in sorted order
    for entry in "${sorted_modules[@]}"; do
        script_file="${entry#*:}"  # Remove tier prefix
        local module_name
        module_name=$(basename "$script_file" .sh)
        process_module "$script_file"
        local module_exit=$?
        # Record result for all modules that actually ran (not skipped)
        if [ "$module_exit" -ne "$KIT_EXIT_MODULE_SKIPPED" ]; then
            state_record_module "$module_name" "$module_exit"
        fi
    done

    state_write
    log_success "All modules completed"
}