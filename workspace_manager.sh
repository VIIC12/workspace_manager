#!/bin/bash
"""
File: 	workspace_manager.sh
Author: Tom U. Schlegel
Date: 	2025-02-11
"""

# Configuration
USERNAME=$(whoami)
HOME_DIR="/home/sc.uni-leipzig.de/$USERNAME"   # Correct home directory path
LAST_RUN_FILE="$HOME_DIR/.workspace_manager_last_run"
WARNING_DAYS=1  # Warn when less than this many days remaining
LOG_FILE="$HOME_DIR/.workspace_manager.log"
EXTENSION_DAYS=30

# Function to log messages
log_message() {
    color_start="\033[1;35m"
    color_end="\033[0m"
    echo -e "${color_start}[WORKSPACE MANAGER] [$(date '+%Y-%m-%d %H:%M:%S')] $1${color_end}" | tee -a "$LOG_FILE"
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

    if [ "$remaining_days" -lt "$WARNING_DAYS" ] && [ "$extensions" -gt 0 ]; then
        log_message "Extending workspace $workspace (had $remaining_days days left)"
        ws_extend "$workspace" "$EXTENSION_DAYS"
        if [ $? -eq 0 ]; then
            log_message "Successfully extended workspace $workspace"
        else
            log_message "Failed to extend workspace $workspace"
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
            log_message "current_workspace: $current_workspace"
        elif [[ $line =~ remaining\ time.*:\ ([0-9]+)\ days ]]; then # if Line starts with "remaining time: 2 days" -> BASH_REMATCH[1] = 2
            remaining_days="${BASH_REMATCH[1]}"
            log_message "remaining_days: $remaining_days"
        elif [[ $line =~ available\ extensions.*:\ (.*)$ ]]; then # if Line starts with "available extensions: 1" -> BASH_REMATCH[1] = 1
            extensions="${BASH_REMATCH[1]}"
            log_message "extensions: $extensions"
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
        log_message "Moving contents from $restored_path to $workspace_path"
        # Move all contents including hidden files
        mv "$restored_path"/* "$workspace_path" 2>/dev/null || true
        echo rmdir "$restored_path"
        log_message "Cleanup of restored workspace structure complete"
    else
        log_message "Error: Restored path $restored_path not found"
    fi
}

# Check if workspace exists and is empty
check_workspace() {
    local workspace="$1"
    local workspace_path="/work/$USERNAME-$workspace"
    
    # Check if workspace path exists
    if [ -d "$workspace_path" ]; then
        log_message "Workspace $workspace exists"
        # Check if workspace is empty
        if [ -z "$(ls -A $workspace_path)" ]; then
            log_message "Workspace $workspace is empty" 
            return 0  # Exists and is empty
        else
            log_message "Workspace $workspace is not empty"
            return 2  # Exists but not empty
        fi
    else
        log_message "Workspace $workspace does not exist"
        return 1  # Does not exist
    fi
}

# Handle workspace restoration
handle_restoration() {
    local username_workspace_number="$1"
    local workspace=$(echo "$username_workspace_number" | sed "s/$USERNAME-\(.*\)-[0-9]\+/\1/")
    
    log_message "Attempting to restore $username_workspace_number as $workspace"
    
    # Check if workspace already exists
    check_workspace "$workspace"
    case $? in
        2)  log_message "Cannot restore: Workspace $workspace exists and is not empty"
            return 1 ;;
        0)  log_message "Found empty workspace $workspace, will use it for restoration" ;;
        *)  log_message "Creating new workspace $workspace"
            if ! ws_allocate "$workspace" 30; then
                log_message "Failed to create new workspace: $workspace"
                return 1
            fi ;;
    esac
    
    log_message "Starting restoration to workspace: $workspace"
    
    # Start restoration process and capture verification string
    ws_restore "$username_workspace_number" "$workspace"
      
    if [ $? -eq 0 ]; then
        log_message "Restoration successful for $username_workspace_number to $workspace"
        # Reorganize the files
        reorganize_workspace "$workspace" "$username_workspace_number"
    else
        log_message "Restoration failed for $username_workspace_number"
    fi
}

# Process restorable workspaces
process_restorable() {
    local restorable=$(ws_restore -l | grep "^$USERNAME-" || true)
    
    if [ ! -z "$restorable" ]; then
        log_message "Found restorable workspaces:"
        echo "$restorable" | while read -r workspace; do
            log_message "Processing restoration of: $workspace"
            handle_restoration "$workspace"
        done
    fi
}

main() {
    if ! check_last_run; then
        log_message "Already run today"
        exit 0
    fi

    log_message "Starting workspace management check"
    process_workspaces
    process_restorable
    update_last_run
    log_message "Finished workspace management check"
}

main