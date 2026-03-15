#!/bin/bash
# Logging library for setup scripts
# Provides clean console output with detailed logging to file

# Configuration
LOG_FILE="${LOG_FILE:-${KITBASH_LOG:-${XDG_STATE_HOME:-$HOME/.local/state}/kitbash/kit.log}}"
LOG_LEVEL="${LOG_LEVEL:-INFO}"  # DEBUG, INFO, WARNING, ERROR

# Colors for console output
_LOG_COLOR_RESET='\033[0m'
_LOG_COLOR_BLUE='\033[0;34m'
_LOG_COLOR_GREEN='\033[0;32m'
_LOG_COLOR_YELLOW='\033[1;33m'
_LOG_COLOR_RED='\033[0;31m'
_LOG_COLOR_GRAY='\033[0;90m'

# Initialize log file (called once at start)
log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    {
        echo ""
        echo "========================================"
        echo "Session started at $timestamp"
        echo "========================================"
        echo ""
    } > "$LOG_FILE"
}

# Internal function to write to log file
_log_to_file() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

# Log debug message (only to file, not console)
log_debug() {
    local message="$1"
    _log_to_file "DEBUG" "$message"
}

# Log info message (minimal console, detailed file)
log_info() {
    local message="$1"
    echo -e "${_LOG_COLOR_BLUE}[INFO]${_LOG_COLOR_RESET} $message"
    _log_to_file "INFO" "$message"
}

# Log success message
log_success() {
    local message="$1"
    echo -e "${_LOG_COLOR_GREEN}[SUCCESS]${_LOG_COLOR_RESET} $message"
    _log_to_file "SUCCESS" "$message"
}

# Log warning message
log_warning() {
    local message="$1"
    echo -e "${_LOG_COLOR_YELLOW}[WARNING]${_LOG_COLOR_RESET} $message"
    _log_to_file "WARNING" "$message"
}

# Log error message
log_error() {
    local message="$1"
    echo -e "${_LOG_COLOR_RED}[ERROR]${_LOG_COLOR_RESET} $message" >&2
    _log_to_file "ERROR" "$message"
}

# Log step (sub-task progress, indented on console)
log_step() {
    local message="$1"
    echo -e "  ${_LOG_COLOR_GRAY}${message}${_LOG_COLOR_RESET}"
    _log_to_file "STEP" "$message"
}

# Run a command and capture output to log file only
# Usage: run_quiet "description" command args...
run_quiet() {
    local description="$1"
    shift
    local cmd="$*"

    log_step "$description"
    log_debug "Executing: $cmd"

    local output
    local exit_code

    # Capture both stdout and stderr
    if output=$("$@" 2>&1); then
        exit_code=0
        log_debug "Command succeeded"
        [ -n "$output" ] && log_debug "Output: $output"
    else
        exit_code=$?
        log_debug "Command failed with exit code: $exit_code"
        [ -n "$output" ] && log_debug "Output: $output"
    fi

    return $exit_code
}

# Run a command with progress indicator (spinner)
# Usage: run_with_progress "description" command args...
run_with_progress() {
    local description="$1"
    shift
    local cmd="$*"

    echo -n "  $description ... "
    log_debug "Executing: $cmd"

    local output
    local exit_code
    local spinner_pid

    # Start spinner in background
    (
        local spinner_chars='|/-\'
        local i=0
        while true; do
            printf "\b${spinner_chars:$i:1}"
            i=$(( (i + 1) % 4 ))
            sleep 0.1
        done
    ) &
    spinner_pid=$!

    # Kill spinner and clean up line on interrupt
    trap "kill \$spinner_pid 2>/dev/null; wait \$spinner_pid 2>/dev/null; printf '\b\n'; trap - INT TERM; return 130" INT TERM

    # Capture both stdout and stderr
    if output=$("$@" 2>&1); then
        exit_code=0
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        printf "\b"
        echo -e "${_LOG_COLOR_GREEN}done${_LOG_COLOR_RESET}"
        log_debug "Command succeeded"
        [ -n "$output" ] && log_debug "Output: $output"
    else
        exit_code=$?
        kill $spinner_pid 2>/dev/null
        wait $spinner_pid 2>/dev/null
        printf "\b"
        echo -e "${_LOG_COLOR_RED}failed${_LOG_COLOR_RESET}"
        log_debug "Command failed with exit code: $exit_code"
        [ -n "$output" ] && log_debug "Output: $output"
    fi

    trap - INT TERM
    return $exit_code
}

# Log command execution (shows command and output in log only)
log_command() {
    local cmd="$*"
    log_debug "$ $cmd"
}

# Convenience function: echo to console and log
log_echo() {
    local message="$1"
    echo "$message"
    _log_to_file "INFO" "$message"
}

# Export functions for use in modules
export -f log_init
export -f log_debug
export -f log_info
export -f log_success
export -f log_warning
export -f log_error
export -f log_step
export -f run_quiet
export -f run_with_progress
export -f log_command
export -f log_echo
export -f _log_to_file
