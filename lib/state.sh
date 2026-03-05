#!/bin/bash
# State tracking library for kitbash
# Records module execution results to $KITBASH_STATE_FILE
# (default: ~/.local/state/kitbash/state.json)

# Accumulates results for the current run: module_name -> "exit_code timestamp status"
declare -A _STATE_CURRENT_RUN

# Create the state directory and an empty state file if they don't exist
state_init() {
    mkdir -p "$KITBASH_STATE_DIR"
    if [ ! -f "$KITBASH_STATE_FILE" ]; then
        echo '{"modules": {}}' > "$KITBASH_STATE_FILE"
    fi
}

# Record a module result in memory (call after each module runs)
# Usage: state_record_module <module_name> <exit_code>
state_record_module() {
    local module_name="$1"
    local exit_code="${2:-0}"
    local timestamp
    timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    local status="success"
    [ "$exit_code" -ne 0 ] && status="failed"
    _STATE_CURRENT_RUN["$module_name"]="${exit_code} ${timestamp} ${status}"
}

# Flush in-memory results to disk, merging with any existing state
# Existing records for modules not in the current run are preserved
state_write() {
    [ ${#_STATE_CURRENT_RUN[@]} -eq 0 ] && return 0

    local last_updated
    last_updated=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

    # Serialize current run results to a temp JSON file
    local tmp_file
    tmp_file=$(mktemp /tmp/kitbash-state.XXXXXX.json)

    {
        echo "{"
        local first=true
        for module in "${!_STATE_CURRENT_RUN[@]}"; do
            read -r exit_code timestamp status <<< "${_STATE_CURRENT_RUN[$module]}"
            [ "$first" = true ] || echo ","
            first=false
            printf '  "%s": {"last_run": "%s", "exit_code": %d, "status": "%s"}' \
                "$module" "$timestamp" "$exit_code" "$status"
        done
        [ "$first" = false ] && echo ""
        echo "}"
    } > "$tmp_file"

    # Merge new results into the existing state file via jq
    local out_file="${KITBASH_STATE_FILE}.tmp"
    jq --slurpfile entries "$tmp_file" \
       --arg ts "$last_updated" \
       '.modules += ($entries[0]) | .last_updated = $ts' \
       "$KITBASH_STATE_FILE" > "$out_file" \
    && mv "$out_file" "$KITBASH_STATE_FILE"

    rm -f "$tmp_file"
}

export -f state_init
export -f state_record_module
export -f state_write
