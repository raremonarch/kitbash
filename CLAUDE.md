# Kitbash System Architecture Guide for Claude

This document provides a comprehensive overview of the kitbash system architecture, module API, and development patterns. This is intended for AI assistants to quickly understand the codebase structure.

## Table of Contents

1. [System Overview](#system-overview)
2. [Project Structure](#project-structure)
3. [Module API & Interface](#module-api--interface)
4. [Logging System](#logging-system)
5. [Configuration System](#configuration-system)
6. [Exit Codes & Error Handling](#exit-codes--error-handling)
7. [Module Development Patterns](#module-development-patterns)
8. [Environment Variables](#environment-variables)
9. [Testing Modules](#testing-modules)

---

## System Overview

Kitbash is a modular system configuration and application installer for Fedora Linux. It uses:

- **Bash scripts** for all modules and core functionality
- **Configuration-driven execution** via `kit.conf`
- **Automatic module discovery** from `kit.d/` directory
- **Dual logging** (console + file) for debugging
- **Idempotent operations** for safe re-runs

### Key Philosophy

- Modules are self-contained and independent
- Configuration is declarative (`_modulename=true`)
- Operations should be idempotent (safe to run multiple times)
- User feedback is clean and minimal; details go to log file

---

## Project Structure

```
/home/david/Downloads/kitbash/
├── kit-start.sh              # Main entry point and bootstrap
├── kit.conf.example          # Configuration template
├── kit.conf                  # User configuration (git-ignored)
├── README.md                 # User documentation
├── CLAUDE.md                 # This file (AI assistant guide)
├── lib/                      # Core library functions
│   ├── paths.sh              # Path detection and initialization
│   ├── config.sh             # Configuration loading/validation
│   ├── logging.sh            # Dual console/file logging
│   ├── module-runner.sh      # Module discovery and execution
│   ├── setup-functions.sh    # Setup helper functions
│   ├── validation.sh         # Configuration validation
│   └── exitcodes.sh          # Standardized exit codes
└── kit.d/                    # Module scripts directory
    ├── alacritty.sh          # Terminal app installer
    ├── cursor.sh             # Cursor theme configuration
    ├── docker.sh             # Docker setup
    ├── dotfiles.sh           # Dotfiles repository management
    ├── editor.sh             # Default editor setup
    ├── font.sh               # Font installation
    ├── google_chrome.sh      # Chrome repository setup
    ├── hostname.sh           # System hostname configuration
    ├── mounts.sh             # Network/local mount points
    ├── ollama.sh             # Ollama AI runtime installer
    ├── sddm.sh               # SDDM login manager setup
    ├── synology.sh           # Synology Drive client setup
    ├── terminal.sh           # Default terminal configuration
    ├── vscode.sh             # VS Code repository setup
    ├── wallpaper.sh          # Wallpaper configuration
    └── power_never_sleep.sh  # Power management settings
```

---

## Module API & Interface

### Basic Module Template

```bash
#!/bin/bash

# Module: example.sh
# Purpose: Brief description of what this module does
# Tier: N (Tier Name)
# Description: Human-readable description for --info display
# Installs: package1, package2 (or "none (configuration only)")

# 1. Get configuration value (parameter or kit.conf variable)
MODULE_VALUE="${1:-$_example}"

# 2. Validate configuration if needed
if [ -z "$MODULE_VALUE" ]; then
    log_error "No value specified for example module"
    exit $KIT_EXIT_INVALID_INPUT
fi

# 3. Check idempotency (already installed/configured?)
if command -v example-tool >/dev/null 2>&1; then
    log_success "Example tool is already installed"
    exit 0
fi

# 4. Log progress
log_info "Setting up example module"
log_step "performing installation steps"

# 5. Run commands with proper logging
if ! run_with_progress "installing package" sudo dnf install -y example-package; then
    log_error "Failed to install example-package"
    exit $KIT_EXIT_MODULE_FAILED
fi

# 6. Verify success
if command -v example-tool >/dev/null 2>&1; then
    log_success "Example module completed successfully"
    exit 0
else
    log_error "Installation verification failed"
    exit $KIT_EXIT_MODULE_FAILED
fi
```

### Module Naming Convention

- **Filename**: `modulename.sh` (lowercase, descriptive)
- **Config variable**: `_modulename` (underscore prefix)
- **Example**: `niri.sh` uses `_niri=true` in `kit.conf`

### How Modules Are Discovered and Run

From `lib/module-runner.sh:11-18`:

```bash
should_run_module() {
    local pref_value="$1"
    # Module runs if value is:
    #   - "true" (explicitly enabled)
    #   - Any non-empty, non-false value (e.g., "sway", "latest", "1.2.3")
    # Module skips if value is:
    #   - "false" (explicitly disabled)
    #   - Empty/unset
    [ "$pref_value" = "true" ] || [ "$pref_value" != "false" -a -n "$pref_value" ]
}
```

The system:
1. Discovers all `*.sh` files in `kit.d/`
2. Extracts module name (removes `.sh` extension)
3. Looks up `_modulename` in loaded configuration
4. Runs module if `should_run_module()` returns true
5. Passes config value as first parameter to module script

---

## Logging System

All logging functions are exported globally and available to modules.

### Logging Functions

```bash
log_info "Main message"              # [INFO] - Console and log file
log_debug "Debug details"            # DEBUG - Log file only (not console)
log_success "Task completed"         # [SUCCESS] - Green, console and log
log_warning "Non-fatal issue"        # [WARNING] - Yellow, console and log
log_error "Fatal error"              # [ERROR] - Red, stderr, and log
log_step "Sub-task description"      # Indented gray text for progress
```

### Command Execution Helpers

```bash
# Show progress indicator on console, full output to log
run_with_progress "installing package" sudo dnf install -y package-name
# Output: "  installing package ... done" (or "... failed")

# Silent execution, log only
run_quiet "background task" some-command --flags
```

### Logging Behavior

- **Console**: Clean, minimal progress indicators and status messages
- **Log File** (`~/kit.log`): Detailed timestamped output with full command stdout/stderr
- **Timestamps**: All log file entries include ISO 8601 timestamps
- **Colors**: Console uses ANSI colors; log file is plain text

### Implementation Details

From `lib/logging.sh`:

- `log_info()`: Tees to both console and file
- `log_debug()`: File only (no console spam)
- `log_error()`: Outputs to stderr and log file
- `run_with_progress()`: Captures command output, shows "... done/failed"

---

## Configuration System

### kit.conf Format

Configuration is a bash-sourceable file with variables:

```bash
# System Configuration
_hostname="my-workstation"

# Applications (boolean)
_vscode=true
_google_chrome=true
_docker=false

# Applications (with values)
_terminal="alacritty"
_editor="nvim"

# Complex configuration (multiple variables)
_dotfiles_repo="https://github.com/username/dotfiles.git"
_dotfiles_branch="main"
```

### Configuration Loading

From `lib/config.sh`:

1. Looks for `kit.conf` in `$KITBASH_ROOT/kit.conf`
2. Sources the file to load variables into environment
3. Validates required variables if defined in module
4. Exports variables for use by modules

### Accessing Configuration in Modules

```bash
#!/bin/bash

# Method 1: Parameter (when run with argument)
CONFIG_VALUE="${1:-$_modulename}"

# Method 2: Direct variable access
if [ "$_modulename" = "true" ]; then
    # Module is enabled with boolean
fi

if [ -n "$_modulename" ] && [ "$_modulename" != "false" ]; then
    # Module is enabled with string value or true
fi

# Method 3: Multi-variable module
REPO="${_modulename_repo:-https://default-url.com}"
BRANCH="${_modulename_branch:-main}"
```

### Adding New Configuration

To add a module configuration:

1. Add to `kit.conf.example` with comment
2. Add to your personal `kit.conf`
3. Access via `$_modulename` in your module script

---

## Exit Codes & Error Handling

From `lib/exitcodes.sh`, these constants are available globally:

```bash
KIT_EXIT_SUCCESS=0              # Successful completion
KIT_EXIT_ERROR=1                # General error
KIT_EXIT_CONFIG_MISSING=2       # Config file not found
KIT_EXIT_CONFIG_INVALID=3       # Invalid configuration value
KIT_EXIT_DEPENDENCY_MISSING=3   # Required dependency not available
KIT_EXIT_PERMISSION_DENIED=4    # Insufficient permissions
KIT_EXIT_MODULE_FAILED=5        # Module execution failed
KIT_EXIT_MODULE_SKIPPED=6       # Module intentionally skipped
KIT_EXIT_NETWORK_ERROR=7        # Network/download failure
KIT_EXIT_USER_CANCELLED=8       # User cancelled operation
KIT_EXIT_INVALID_INPUT=9        # Invalid user input
```

### Usage Examples

```bash
# Check dependency
if ! command -v required-tool >/dev/null 2>&1; then
    log_error "Missing required dependency: required-tool"
    exit $KIT_EXIT_DEPENDENCY_MISSING
fi

# Handle download failure
if ! curl -LO https://example.com/file.tar.gz; then
    log_error "Failed to download required file"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Permission check
if [ ! -w "/etc/config" ]; then
    log_error "Permission denied: cannot write to /etc/config"
    exit $KIT_EXIT_PERMISSION_DENIED
fi

# Success
log_success "Module completed"
exit $KIT_EXIT_SUCCESS  # or simply: exit 0
```

---

## Module Development Patterns

### Pattern 1: Repository Setup Module

**Example**: [google_chrome.sh](kit.d/google_chrome.sh)

```bash
#!/bin/bash

log_info "Setting up Google Chrome repository"

# Idempotency: Check if already installed
if command -v google-chrome-stable >/dev/null 2>&1; then
    log_success "Google Chrome is already installed"
    exit 0
fi

# Check if repository already configured
if ! dnf repolist --all 2>/dev/null | grep -q "^google-chrome"; then
    run_with_progress "installing DNF plugins" \
        sudo dnf install -y dnf-plugins-core

    run_with_progress "adding Google Chrome repository" \
        sudo dnf config-manager addrepo \
            --id=google-chrome \
            --set=baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64 \
            --set=name=google-chrome \
            --set=enabled=1 \
            --set=gpgcheck=1 \
            --set=gpgkey=https://dl.google.com/linux/linux_signing_key.pub
fi

# Install the application
run_with_progress "installing Google Chrome" \
    sudo dnf install -y google-chrome-stable

log_success "Google Chrome installed successfully"
```

**Key Points**:
- Check if already installed before doing work
- Check if repository exists before adding
- Use `run_with_progress` for user feedback
- Verify installation succeeded

### Pattern 2: Service Installation Module

**Example**: [ollama.sh](kit.d/ollama.sh)

```bash
#!/bin/bash

log_info "Installing Ollama"

# Download binary
if ! run_with_progress "downloading Ollama" \
    curl -LO https://ollama.com/download/ollama-linux-amd64.tgz; then
    log_error "Failed to download Ollama"
    exit $KIT_EXIT_NETWORK_ERROR
fi

# Extract
run_with_progress "extracting Ollama" \
    sudo tar -C /usr -xzf ollama-linux-amd64.tgz

# Create system user (idempotent with || true)
sudo useradd -r -s /bin/false -U -m -d /usr/share/ollama ollama 2>/dev/null || true

# Create systemd service
sudo tee /etc/systemd/system/ollama.service > /dev/null << 'EOF'
[Unit]
Description=Ollama Service
After=network-online.target

[Service]
ExecStart=/usr/bin/ollama serve
User=ollama
Group=ollama
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
run_with_progress "enabling service" sudo systemctl daemon-reload
run_with_progress "starting Ollama" sudo systemctl enable --now ollama

# Verify
if sudo systemctl is-active --quiet ollama; then
    log_success "Ollama installed and running"
else
    log_error "Ollama service failed to start"
    exit $KIT_EXIT_MODULE_FAILED
fi
```

**Key Points**:
- Downloads and extracts from source
- Creates system users/groups safely
- Manages systemd services
- Verifies service is running
- Proper error handling with exit codes

### Pattern 3: Configuration Module with Dependency Handling

**Example**: [terminal.sh](kit.d/terminal.sh)

```bash
#!/bin/bash

TERMINAL_APP="${1:-$_terminal}"

if [ -z "$TERMINAL_APP" ]; then
    log_error "No terminal application specified"
    exit $KIT_EXIT_INVALID_INPUT
fi

log_info "Setting $TERMINAL_APP as default terminal"

# Auto-install dependency if module exists
if ! command -v "$TERMINAL_APP" >/dev/null 2>&1; then
    log_warning "$TERMINAL_APP not found, attempting to install..."

    if [ -f "$KITBASH_MODULES/${TERMINAL_APP}.sh" ]; then
        log_step "running $TERMINAL_APP installer module"
        if (source "$KITBASH_MODULES/${TERMINAL_APP}.sh"); then
            log_success "$TERMINAL_APP installed successfully"
        else
            log_error "Failed to install $TERMINAL_APP"
            exit $KIT_EXIT_DEPENDENCY_MISSING
        fi
    else
        log_error "$TERMINAL_APP not found and no installer available"
        exit $KIT_EXIT_DEPENDENCY_MISSING
    fi
fi

# Configure as default
run_with_progress "setting default terminal" \
    sudo update-alternatives --install /usr/bin/x-terminal-emulator \
        x-terminal-emulator "/usr/bin/$TERMINAL_APP" 50

log_success "Default terminal configured"
```

**Key Points**:
- Accepts configuration value as parameter
- Checks for dependencies automatically
- Invokes other modules when needed (via `source`)
- Graceful error handling when tools unavailable

### Pattern 4: Git Repository Management

**Example**: [dotfiles.sh](kit.d/dotfiles.sh)

```bash
#!/bin/bash

DOTFILES_REPO="${_dotfiles_repo:-https://github.com/default/dotfiles.git}"
DOTFILES_BRANCH="${_dotfiles_branch:-main}"

log_info "Setting up dotfiles repository"

cd "$HOME"

# Initialize if needed (idempotent)
if [ ! -d "$HOME/.git" ]; then
    log_step "initializing git repository"
    git init
    git branch -m "$DOTFILES_BRANCH"
fi

# Add remote safely
REMOTE_EXISTS=$((git remote -v 2>/dev/null || true) | grep origin | wc -l || true)
if [ "$REMOTE_EXISTS" -eq 0 ]; then
    log_step "adding remote origin"
    git remote add origin "$DOTFILES_REPO"
fi

# Fetch latest
run_with_progress "fetching from remote" git fetch origin

# Detect conflicts before checking out
remote_files=$(git ls-tree -r --name-only "origin/$DOTFILES_BRANCH" 2>/dev/null || true)
untracked_files=$(git ls-files --others --exclude-standard 2>/dev/null || true)

conflicts=()
if [ -n "$remote_files" ] && [ -n "$untracked_files" ]; then
    while IFS= read -r uf; do
        if echo "$remote_files" | grep -xF -- "$uf" >/dev/null 2>&1; then
            conflicts+=("$uf")
        fi
    done <<< "$untracked_files"
fi

if [ ${#conflicts[@]} -gt 0 ]; then
    log_warning "Found ${#conflicts[@]} files that would be overwritten"
    # Handle conflicts (backup, prompt, etc.)
fi

log_success "Dotfiles configured"
```

**Key Points**:
- Uses multiple config variables
- Robust error handling with `|| true` fallbacks
- Conflict detection before destructive operations
- Idempotency checks throughout

---

## Environment Variables

These variables are available to all modules:

```bash
$KITBASH_ROOT        # Root directory: /home/david/Downloads/kitbash
$KITBASH_LIB         # Library directory: $KITBASH_ROOT/lib
$KITBASH_MODULES     # Modules directory: $KITBASH_ROOT/kit.d
$_scripts            # Alias for $KITBASH_MODULES
$LOG_FILE            # Full path to log file: $HOME/kit.log
$HOME                # User home directory
$USER                # Current username
```

All configuration variables from `kit.conf` (prefixed with `_`) are also available.

---

## Testing Modules

### Running Individual Modules

```bash
# Run just one module
./kit-start.sh modulename

# Run with specific config value
_modulename=value ./kit-start.sh modulename
```

### Testing Idempotency

Modules should be safe to run multiple times:

```bash
# First run - does work
./kit-start.sh mymodule

# Second run - should detect already done and exit quickly
./kit-start.sh mymodule
```

### Checking Logs

```bash
# View full log
cat $HOME/kit.log

# Tail log in real-time
tail -f $HOME/kit.log

# Search for errors
grep ERROR $HOME/kit.log
```

### Common Idempotency Checks

```bash
# Check if command exists
if command -v tool-name >/dev/null 2>&1; then
    log_success "Already installed"
    exit 0
fi

# Check if file/directory exists
if [ -f "/path/to/config" ]; then
    log_success "Already configured"
    exit 0
fi

# Check if service is enabled
if systemctl is-enabled service-name >/dev/null 2>&1; then
    log_success "Service already enabled"
    exit 0
fi

# Check if repository exists
if dnf repolist | grep -q "repo-name"; then
    log_success "Repository already configured"
    exit 0
fi

# Idempotent commands (don't fail if already done)
sudo useradd username 2>/dev/null || true
sudo systemctl enable service 2>/dev/null || true
```

---

## Best Practices Summary

1. **Always check idempotency first** - Exit early if work is already done
2. **Use descriptive logging** - Help users understand what's happening
3. **Validate inputs** - Check configuration values before using
4. **Handle errors gracefully** - Use appropriate exit codes
5. **Verify success** - Check that operations actually worked
6. **Use `run_with_progress`** - For user-facing operations
7. **Use `run_quiet`** - For background/setup tasks
8. **Fail fast** - Exit immediately on critical errors
9. **Document dependencies** - Check for and install required tools
10. **Test twice** - Run module twice to verify idempotency

---

## Quick Reference: Creating a New Module

1. Create `/home/david/Downloads/kitbash/kit.d/mymodule.sh`
2. Add `_mymodule=true` to `kit.conf` and `kit.conf.example`
3. **Note**: Module scripts are sourced by the main script, not executed directly, so they do NOT need to be made executable with `chmod +x`
4. Follow module template pattern (see above)
5. Test: `./kit-start.sh mymodule`
6. Test idempotency: Run twice, verify second run is quick
7. Check logs: `tail $HOME/kit.log`

---

## File Locations Reference

- **Main script**: `/home/david/Downloads/kitbash/kit-start.sh`
- **Modules**: `/home/david/Downloads/kitbash/kit.d/*.sh`
- **Config template**: `/home/david/Downloads/kitbash/kit.conf.example`
- **User config**: `/home/david/Downloads/kitbash/kit.conf`
- **Libraries**: `/home/david/Downloads/kitbash/lib/*.sh`
- **Log file**: `$HOME/kit.log`

---

## Common Module Types

- **Repository Setup**: Add DNF/APT repositories (chrome, vscode)
- **Package Installer**: Install from repos or download binaries (ollama)
- **System Configuration**: Modify system settings (hostname, power)
- **Service Management**: Install and configure systemd services (ollama, docker)
- **Dotfiles Management**: Clone and manage configuration repositories
- **Default Application**: Set system-wide defaults (terminal, editor)

---

*Last updated: 2025-10-30*
*Generated by: Claude (Sonnet 4.5)*
