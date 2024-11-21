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

# Service Configuration
if systemctl list-units --full -all | grep -Fq "qmaster.service"; then
    SERVICE_NAME=qmaster
else
    SERVICE_NAME=ceremonyclient
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
