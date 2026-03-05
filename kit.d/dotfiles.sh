#!/bin/bash

# Module: dotfiles.sh
# Purpose: Manage $HOME as git repo for dotfiles
# Tier: 0 (Dotfiles Management - FIRST)
# Description: Manages $HOME as a git repository for dotfiles tracking
# Installs: none (git configuration only)

DOTFILES_REPO="${_dotfiles_repo:-https://github.com/daevski/dotfiles.git}"
DOTFILES_BRANCH="${_dotfiles_branch:-main}"

log_info "Dotfiles module starting"

# Change to home directory
cd "$HOME"

# Initialize git if needed
if [ ! -d "$HOME/.git" ]; then
    log_step "Initializing $HOME as git repository"
    git init
    git branch -m "$DOTFILES_BRANCH"
fi

# Check for remote (robust against grep non-zero exit when no remotes exist)
# Use a safe pipeline that won't trigger 'set -e' in the caller
REMOTE_EXISTS=$( (git remote -v 2>/dev/null || true) | grep origin | wc -l || true)
if [ "$REMOTE_EXISTS" -eq 0 ]; then
    log_step "Adding remote origin"
    git remote add origin "$DOTFILES_REPO"
fi

# Fetch latest from remote
run_with_progress "fetching from origin" git fetch origin

# Confirm before overwriting local changes
if ! git diff --quiet HEAD "origin/$DOTFILES_BRANCH"; then
    prompt_yes_no "Overwrite local changes in $HOME with remote dotfiles?" "n"
    if [ "$PROMPT_RESULT" != "y" ] && [ "$PROMPT_RESULT" != "Y" ]; then
        log_info "Aborting dotfiles update. Local changes preserved."
        return 0
    fi
fi

# Detect untracked files that would conflict with files in the remote branch
# (git reset --hard won't remove untracked files, but it can fail if an
# untracked file would be overwritten by checkout). Warn and prompt first.
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
    log_warning "Found untracked files in \$HOME that would be overwritten by remote dotfiles:"
    for f in "${conflicts[@]}"; do
        echo "  - $f"
    done
    echo ""
    prompt_yes_no "Proceed and overwrite these untracked files?" "n"
    if [ "$PROMPT_RESULT" != "y" ] && [ "$PROMPT_RESULT" != "Y" ]; then
        log_info "Aborting dotfiles update to avoid overwriting untracked files."
        return 0
    fi
fi

# Overwrite with remote (this will update tracked files; untracked files not
# listed above will be left alone)
run_with_progress "resetting to origin/$DOTFILES_BRANCH" git reset --hard "origin/$DOTFILES_BRANCH"
log_success "Dotfiles deployed successfully"

log_success "Dotfiles module complete"
