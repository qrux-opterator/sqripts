#!/bin/bash

# Description:
# This script analyzes proof creation and submission frame ages to determine
# likelihood of proofs landing successfully. It provides a summary with reduced output.
#
# Usage:  ~/scripts/qnode_proof_monitor.sh [minutes]
# Example:  ~/scripts/qnode_proof_monitor.sh 600    # analyzes last 10 hours

# Default time window in minutes (3 hours by default)
DEFAULT_TIME_WINDOW=180
TIME_WINDOW=${1:-$DEFAULT_TIME_WINDOW}

services=("ceremonyclient.service" "para.service")

# Find running services
found=($(systemctl list-units --type=service --state=running | awk '{print $1}' | grep -E "$(IFS=\|; echo "${services[*]}")"))

local SERVICE_OPTIONS=("para.service" "alt.service")  # Define services to check
local SETTINGS_FILE="/root/quileye_settings.txt"      # File to save the selected service
local SERVICE_NAME                                    # Variable to hold the selected service

# If the settings file exists, use the saved service and skip further checks
if [ -f "$SETTINGS_FILE" ]; then
    SERVICE_NAME=$(cat "$SETTINGS_FILE")
    echo "Using saved service from $SETTINGS_FILE: $SERVICE_NAME"
    return 0
else
    # Find running services that match the options
    local found=()
    for service in "${SERVICE_OPTIONS[@]}"; do
        if systemctl is-active --quiet "$service"; then
            found+=("$service")
        fi
    done

    # Handle different scenarios
    if [ "${#found[@]}" -eq 1 ]; then
        # If only one service is found, use it directly
        SERVICE_NAME=$(echo "${found[0]}" | sed 's/.service//')  # Remove .service suffix
        echo "Found single service: $SERVICE_NAME"
    elif [ "${#found[@]}" -gt 1 ]; then
        # If multiple services are found, prompt the user to select one
        echo "Multiple services are running. Please select one:"
        select service in "${found[@]}"; do
            if [ -n "$service" ]; then
                SERVICE_NAME=$(echo "$service" | sed 's/.service//')  # Remove .service suffix
                break
            else
                echo "Invalid selection. Please try again."
            fi
        done
    else
        # Exit if no matching services are found
        echo "No matching services are running."
        exit 1
    fi

    # Save the selected service to the settings file
    echo "$SERVICE_NAME" > "$SETTINGS_FILE"
    echo "Service name saved to $SETTINGS_FILE: $SERVICE_NAME"
fi


# Temporary files
TEMP_CREATE=$(mktemp)
TEMP_SUBMIT=$(mktemp)
TEMP_CREATE_FRAMES=$(mktemp)
TEMP_SUBMIT_FRAMES=$(mktemp)
TEMP_MATCHES=$(mktemp)

# Function to calculate average
calculate_avg() {
    local file=$1
    awk '{ sum += $1; n++ } END { if (n > 0) printf "%.2f", sum / n }' "$file"
}

# Extract frame ages (not frame numbers) for statistics
journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
    grep -F "creating data shard ring proof" | \
    sed -E 's/.*"frame_age":([0-9]+\.[0-9]+).*/\1/' > "$TEMP_CREATE"

journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
    grep -F "submitting data proof" | \
    sed -E 's/.*"frame_age":([0-9]+\.[0-9]+).*/\1/' > "$TEMP_SUBMIT"

# Extract frame numbers AND ages for CPU time calculation
journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
    grep -F "creating data shard ring proof" | \
    sed -E 's/.*"frame_number":([0-9]+).*"frame_age":([0-9]+\.[0-9]+).*/\1 \2/' > "$TEMP_CREATE_FRAMES"

journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
    grep -F "submitting data proof" | \
    sed -E 's/.*"frame_number":([0-9]+).*"frame_age":([0-9]+\.[0-9]+).*/\1 \2/' > "$TEMP_SUBMIT_FRAMES"

# Calculate CPU Processing Time
while read -r create_line; do
    create_frame=$(echo "$create_line" | cut -d' ' -f1)
    create_age=$(echo "$create_line" | cut -d' ' -f2)
    submit_line=$(grep "^$create_frame " "$TEMP_SUBMIT_FRAMES")
    if [ ! -z "$submit_line" ]; then
        submit_age=$(echo "$submit_line" | cut -d' ' -f2)
        cpu_time=$(awk "BEGIN {printf \"%.2f\", $submit_age - $create_age}")
        echo "$cpu_time" >> "$TEMP_MATCHES"
    fi
done < "$TEMP_CREATE_FRAMES"

# Calculate statistics if we have data
if [ -s "$TEMP_CREATE" ] && [ -s "$TEMP_SUBMIT" ] && [ -s "$TEMP_MATCHES" ]; then
    CREATE_AVG=$(calculate_avg "$TEMP_CREATE")
    SUBMIT_AVG=$(calculate_avg "$TEMP_SUBMIT")
    CPU_AVG=$(calculate_avg "$TEMP_MATCHES")
    TOTAL_PROOFS=$(wc -l < "$TEMP_CREATE")

    # Reduced output
    echo "${TOTAL_PROOFS} Proofs - Creation: ${CREATE_AVG}s - Submission: ${SUBMIT_AVG}s - CPU-Processing: ${CPU_AVG}s"
else
    echo "No proofs found in the last $TIME_WINDOW minutes"
fi

# Cleanup
rm -f "$TEMP_CREATE" "$TEMP_SUBMIT" "$TEMP_CREATE_FRAMES" "$TEMP_SUBMIT_FRAMES" "$TEMP_MATCHES"
