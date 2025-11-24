#!/bin/bash

# Author:   Tom U. Schlegel
# Date:     2025-11-24
# File: 	workspace_manager.sh
# Info:     Manage workspaces on HPC Leipzig automatically.
# Version:  1.0.4

# Configuration
USERNAME=$(whoami)
HOME_DIR="/home/sc.uni-leipzig.de/$USERNAME"
LAST_RUN_FILE="$HOME_DIR/.workspace_manager_last_run"
WARNING_DAYS=3  # Warn when less than this many days remaining
LOG_FILE="$HOME_DIR/.workspace_manager.log"
EXTENSION_DAYS=30  # Extend workspace by this many days
GITHUB_RAW_URL="https://raw.githubusercontent.com/VIIC12/workspace_manager/main/workspace_manager.sh"
CURRENT_VERSION="1.0.4"

# Function to log messages with different log levels
# Usage: log_message <level> "message"
# Levels: 1 = normal, 2 = success, 3 = attention/warning
log_message() {
    local level="$1"
    local message="$2"
    
    # Define colors for different log levels
    case "$level" in
        1)  # Normal log - Purple/Magenta (original color)
            color_start="\033[1;35m"
            ;;
        2)  # Success - Green
            color_start="\033[1;32m"
            ;;
        3)  # Attention/Warning - Yellow
            color_start="\033[1;33m"
            ;;
        *)  # Default to normal if invalid level
            color_start="\033[1;35m"
            ;;
    esac
    
    color_end="\033[0m"
    echo -e "${color_start}[WORKSPACE MANAGER] [$(date '+%Y-%m-%d %H:%M:%S')] $message${color_end}" | tee -a "$LOG_FILE"
}

# Function to check for updates
check_for_updates() {
    # Download the latest version from GitHub
    latest_script=$(curl -s "$GITHUB_RAW_URL")
    if [ $? -ne 0 ]; then
        log_message 1 "Failed to check for updates"
        return 1
    fi

    # Extract version from GitHub raw URL
    latest_version=$(echo "$latest_script" | grep -m 1 "Version:" | awk '{print $NF}')
    
    if [ "$latest_version" != "$CURRENT_VERSION" ]; then
        log_message 1 "New version $latest_version available (current: $CURRENT_VERSION)"
        log_message 1 "Updating script..."
        
        # Update script
        echo "$latest_script" > "$0"
        chmod +x "$0"
        
        log_message 1 "Script updated successfully."
        exit 0
    fi
}

# Check if script has already run today
check_last_run() {
    if [ -f "$LAST_RUN_FILE" ]; then
        last_run=$(cat "$LAST_RUN_FILE")
        today=$(date +%Y%m%d)
        if [ "$last_run" = "$today" ]; then
            return 1  # Already run today
        fi
    fi
    return 0  # Haven't run today
}

# Update last run timestamp
update_last_run() {
    date +%Y%m%d > "$LAST_RUN_FILE"
}

# Handle workspace extension
handle_extension() {
    local workspace="$1"
    local remaining_days="$2"
    local extensions="$3"

    if [ "$remaining_days" -lt "$WARNING_DAYS" ]; then
        if [ "$extensions" -gt 0 ]; then
            log_message 1 "Extending workspace $workspace (had $remaining_days days left)"
            ws_extend "$workspace" "$EXTENSION_DAYS"
            if [ $? -eq 0 ]; then
                log_message 2 "Successfully extended workspace $workspace"
            else
                log_message 1 "Failed to extend workspace $workspace"
            fi
        else
            log_message 1 "WARNING: Workspace $workspace has only $remaining_days days left and no more extensions available!"
            log_message 1 "WARNING: Restore $workspace in new ws (same name) and move files to it's original location."
        fi
    fi
}

# Process current workspaces
process_workspaces() {
    local current_workspace=""
    local remaining_time=""
    local extensions=""

    ws_list | while IFS= read -r line; do
        if [[ $line =~ ^id:\ (.*)$ ]]; then # if Line starts with "id: workspace" -> BASH_REMATCH[1] = workspace
            current_workspace="${BASH_REMATCH[1]}"
            log_message 1 "Processing workspace: $current_workspace"
        elif [[ $line =~ remaining\ time.*:\ ([0-9]+)\ days ]]; then # if Line starts with "remaining time: 2 days" -> BASH_REMATCH[1] = 2
            remaining_days="${BASH_REMATCH[1]}"
            log_message 1 "remaining_days: $remaining_days"
        elif [[ $line =~ available\ extensions.*:\ (.*)$ ]]; then # if Line starts with "available extensions: 1" -> BASH_REMATCH[1] = 1
            extensions="${BASH_REMATCH[1]}"
            log_message 1 "extensions: $extensions"
            if [ ! -z "$current_workspace" ] && [ ! -z "$remaining_days" ]; then
                handle_extension "$current_workspace" "$remaining_days" "$extensions"
            fi
        fi
    done
}

reorganize_workspace() {
    local workspace="$1"
    local username_workspace_number="$2"
    local workspace_path="/work/$USERNAME-$workspace"
    local restored_path="$workspace_path/$username_workspace_number"

    if [ -d "$restored_path" ]; then
        log_message 1 "Moving contents from $restored_path to $workspace_path"
        # Move all contents including hidden files
        mv "$restored_path"/* "$workspace_path" 2>/dev/null || true
        echo rmdir "$restored_path"
        log_message 1 "Cleanup of restored workspace structure complete"
    else
        log_message 1 "Error: Restored path $restored_path not found"
    fi
}

# Check if workspace exists and is empty
check_workspace() {
    local workspace="$1"
    local workspace_path="/work/$USERNAME-$workspace"
    
    # Check if workspace path exists
    if [ -d "$workspace_path" ]; then
        log_message 1 "Workspace $workspace exists"
        # Check if workspace is empty
        if [ -z "$(ls -A $workspace_path)" ]; then
            log_message 1 "Workspace $workspace is empty" 
            return 0  # Exists and is empty
        else
            log_message 1 "Workspace $workspace is not empty"
            return 2  # Exists but not empty
        fi
    else
        log_message 1 "Workspace $workspace does not exist yet"
        return 1  # Does not exist
    fi
}

# Handle workspace restoration
handle_restoration() {
    local username_workspace_number="$1"
    local workspace=$(echo "$username_workspace_number" | sed "s/$USERNAME-\(.*\)-[0-9]\+/\1/")

    #log_message "Attempting to restore $username_workspace_number as $workspace"
    
    # Check if workspace already exists
    check_workspace "$workspace"
    case $? in
        2)  log_message 3 "Cannot restore: Workspace $workspace exists and is not empty"
            return 1 ;;
        0)  log_message 1 "Found empty workspace $workspace, will use it for restoration" ;;
        *)  log_message 1 "Creating new workspace $workspace"
            if ! ws_allocate "$workspace" 30; then
                log_message 1 "Failed to create new workspace: $workspace"
                return 1
            fi ;;
    esac
    
    #log_message "Starting restoration to workspace: $workspace"
    
    # Start restoration process and capture verification string
    log_message 1 "Automatically restoring workspace does not work because of the verification string."
    log_message 1 "Run the follwing command and enter the verfication string to restore the workspace:"
    log_message 2 "ws_restore "$username_workspace_number" "$workspace""
    
    # TODO This does not work, because I don't know yet, how to parse the verification string
    # if [ $? -eq 0 ]; then
    #     log_message "Restoration successful for $username_workspace_number to $workspace"
    #     # Reorganize the files
    #     reorganize_workspace "$workspace" "$username_workspace_number"
    # else
    #     log_message "Restoration failed for $username_workspace_number"
    # fi
}

# Process restorable workspaces
process_restorable() {
    local restorable=$(ws_restore -l | grep "^$USERNAME-" || true)
    
    if [ ! -z "$restorable" ]; then
        log_message 3 "Found restorable workspaces:"
        echo "$restorable" | while read -r workspace; do
            log_message 2 "Processing restoration preparation of: $workspace"
            handle_restoration "$workspace"
        done
    fi
}

main() {
    check_for_updates
    
    if ! check_last_run; then
        log_message 1 "Already run today"
        exit 0
    fi

    log_message 1 "Starting workspace management check"
    process_workspaces
    process_restorable
    update_last_run
    log_message 2 "Finished workspace management check"
}

main
