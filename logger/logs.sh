#!/bin/bash

################################################################################
# Logging Function
################################################################################
#
# Description:
#   This script demonstrates an advanced logging system for bash scripts with
#   the following features:
#   - Enable/disable logging via LOGGING_ENABLED variable (true/false)
#   - Multiple log levels: DEBUG, INFO, WARNING, ERROR
#   - Colored console output with ANSI color codes
#   - Optional file output with configurable path
#   - Automatic log rotation based on file size
#   - ISO 8601 timestamp formatting
#   - Caller information tracking
#
# Usage:
#   1. Source this script or copy the logging functions to your script
#   2. Configure the logging variables in the configuration section
#   3. Use the convenience functions: log_debug, log_info, log_warning, log_error
#   4. Or use the main log function directly: log "LEVEL" "message"
#
# Author: Bob (AI Assistant)
# Date: 2026-04-29
# Version: 1.0
#
################################################################################

################################################################################
# CONFIGURATION SECTION
################################################################################

# Master switch to enable/disable all logging
# Set to "true" to enable logging, "false" to disable
export LOGGING_ENABLED=false

# Minimum log level to display/record
# Options: DEBUG, INFO, WARNING, ERROR
# Only messages at this level or higher will be logged
export LOG_LEVEL="INFO"

# Enable/disable console output
export LOG_TO_CONSOLE=true

# Enable/disable file output
export LOG_TO_FILE=false

# Log file path (will be created if it doesn't exist)
# export LOG_FILE="./application.log"
export LOG_FILE=""

# Maximum log file size in bytes before rotation (default: 10MB)
export LOG_MAX_SIZE=$((10 * 1024 * 1024))

# Number of rotated log files to keep
export LOG_BACKUP_COUNT=5

# ANSI Color codes for console output
readonly COLOR_RESET='\033[0m'
readonly COLOR_DEBUG='\033[0;37m'    # Gray
readonly COLOR_INFO='\033[0;32m'     # Green
readonly COLOR_WARNING='\033[0;33m'  # Yellow
readonly COLOR_ERROR='\033[0;31m'    # Red
readonly COLOR_BOLD='\033[1m'

################################################################################
# HELPER FUNCTIONS
################################################################################

# Function: get_log_level_priority
# Description: Returns numeric priority for log level comparison
# Parameters: $1 - Log level (DEBUG, INFO, WARNING, ERROR)
# Returns: Numeric priority (0-3)
get_log_level_priority() {
    local level="$1"
    case "$level" in
        DEBUG)   echo 0 ;;
        INFO)    echo 1 ;;
        WARNING) echo 2 ;;
        ERROR)   echo 3 ;;
        *)       echo 0 ;;
    esac
}

# Function: get_log_color
# Description: Returns ANSI color code for the specified log level
# Parameters: $1 - Log level (DEBUG, INFO, WARNING, ERROR)
# Returns: ANSI color code
get_log_color() {
    local level="$1"
    case "$level" in
        DEBUG)   echo -e "$COLOR_DEBUG" ;;
        INFO)    echo -e "$COLOR_INFO" ;;
        WARNING) echo -e "$COLOR_WARNING" ;;
        ERROR)   echo -e "$COLOR_ERROR" ;;
        *)       echo -e "$COLOR_RESET" ;;
    esac
}

# Function: get_timestamp
# Description: Returns current timestamp in ISO 8601 format
# Returns: Timestamp string (YYYY-MM-DDTHH:MM:SS+TZ)
get_timestamp() {
    date '+%Y-%m-%dT%H:%M:%S%z'
}

# Function: get_caller_info
# Description: Returns information about the calling function/line
# Returns: String with filename:line:function
get_caller_info() {
    # Skip 2 levels: this function and the log function
    local frame=2
    local filename="${BASH_SOURCE[$frame]##*/}"
    local line="${BASH_LINENO[$((frame-1))]}"
    local func="${FUNCNAME[$frame]}"
    
    if [[ -z "$func" || "$func" == "main" ]]; then
        echo "${filename}:${line}"
    else
        echo "${filename}:${line}:${func}"
    fi
}

# Function: rotate_log
# Description: Rotates log files when size limit is exceeded
# Parameters: None (uses global LOG_FILE and LOG_BACKUP_COUNT)
rotate_log() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return 0
    fi
    
    local file_size
    file_size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null)
    
    if [[ $file_size -ge $LOG_MAX_SIZE ]]; then
        # Rotate existing backup files
        for ((i=$LOG_BACKUP_COUNT-1; i>=1; i--)); do
            if [[ -f "${LOG_FILE}.${i}" ]]; then
                mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i+1))"
            fi
        done
        
        # Move current log to .1
        mv "$LOG_FILE" "${LOG_FILE}.1"
        
        # Create new empty log file
        touch "$LOG_FILE"
    fi
}

################################################################################
# MAIN LOGGING FUNCTION
################################################################################

# Function: log
# Description: Main logging function with level filtering, coloring, and output
# Parameters:
#   $1 - Log level (DEBUG, INFO, WARNING, ERROR)
#   $2 - Log message
# Returns: 0 on success, 1 if logging is disabled
log() {
    # Check if logging is enabled
    if [[ "$LOGGING_ENABLED" != "true" ]]; then
        return 1
    fi
    
    local level="$1"
    local message="$2"

    # Validate log level
    if [[ ! "$level" =~ ^(DEBUG|INFO|WARNING|ERROR|ONLYMSG)$ ]]; then
        echo "Invalid log level: $level" >&2
        return 1
    fi
    
    # Check if message level meets minimum threshold
    local level_priority
    local min_priority
    level_priority=$(get_log_level_priority "$level")
    min_priority=$(get_log_level_priority "$LOG_LEVEL")

    if [[ $level_priority -lt $min_priority ]]; then
        return 0
    fi
    
    # Build log entry
    local timestamp
    local caller_info
    local color
    local log_entry
    
    timestamp=$(get_timestamp)
    caller_info=$(get_caller_info)
    color=$(get_log_color "$level")
    
    if [[ "$level" = "ONLYMSG" ]]; then
        # Format: MESSAGE
        log_entry="${message}"
    else
        # Format: [TIMESTAMP] [LEVEL] [CALLER] MESSAGE
        log_entry="[${timestamp}] [${level}] [${caller_info}] ${message}"
    fi
    # Output to console with color
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        if [[ "$level" = "ONLYMSG" ]]; then
            echo -e "${log_entry}"
        else
            echo -e "${color}${log_entry}${COLOR_RESET}"
        fi
    fi
    
    # Output to file (without color codes)
    if [[ ! -z "$LOG_TO_FILE" && "$LOG_TO_FILE" == "true" ]]; then
        # Ensure log directory exists
        local log_dir
        log_dir=$(dirname "$LOG_FILE")
        mkdir -p "$log_dir" 2>/dev/null
        
        # Check if rotation is needed
        rotate_log
        
        # Append to log file
        echo "$log_entry" >> "$LOG_FILE"
    fi
    
    return 0
}

################################################################################
# CONVENIENCE WRAPPER FUNCTIONS
################################################################################

# Function: log_debug
# Description: Log a DEBUG level message
# Parameters: $1 - Log message
log_debug() {
    log "DEBUG" "$1"
}

# Function: log_info
# Description: Log an INFO level message
# Parameters: $1 - Log message
log_info() {
    log "INFO" "$1"
}

# Function: log_warning
# Description: Log a WARNING level message
# Parameters: $1 - Log message
log_warning() {
    log "WARNING" "$1"
}

# Function: log_error
# Description: Log an ERROR level message
# Parameters: $1 - Log message
log_error() {
    log "ERROR" "$1"
}

# Function: log_msg
# Description: Log an INFO level message
# Parameters: $1 - Log message
log_msg() {
    log "ONLYMSG" "$1"
}


# Made with Bob
