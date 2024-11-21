#!/bin/bash

# Description:
# This script combines two functionalities:
# 1. Fetch and format node and coin information.
# 2. Analyze proof creation and submission frame ages with reduced output.

# Find running services
found=($(systemctl list-units --type=service --state=running | awk '{print $1}' | grep -E "$(IFS=\|; echo "${services[*]}")"))

# Default time window for proof analysis (3 hours by default)
DEFAULT_TIME_WINDOW=180
TIME_WINDOW=${1:-$DEFAULT_TIME_WINDOW}

# Boundaries for coloring metrics
CREATION_OPTIMAL_MIN=1
CREATION_OPTIMAL_MAX=17
CREATION_WARNING_MAX=50

SUBMISSION_OPTIMAL_MIN=1
SUBMISSION_OPTIMAL_MAX=28
SUBMISSION_WARNING_MAX=70

CPU_OPTIMAL_MAX=20
CPU_WARNING_MAX=30

# Colors for thresholds
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Function: Fetch node and coin information
fetch_node_and_coin_info() {
    # Navigate to node directory
    cd /root/ceremonyclient/node || exit

    # Get the current date
    date_info=$(date)

    # Check if the first qclient path exists
    if [ -f /root/ceremonyclient/client/qclient-2.0.4-linux-amd64 ]; then
        coin_count=$(/root/ceremonyclient/client/qclient-2.0.4-linux-amd64 token coins --config /root/ceremonyclient/node/.config | wc -l)
    elif [ -f /root/ceremonyclient/node/qclient-2.0.4-linux-amd64 ]; then
        # Check if the second qclient path exists
        coin_count=$(/root/ceremonyclient/node/qclient-2.0.4-linux-amd64 token coins --config /root/ceremonyclient/node/.config | wc -l)
    else
        # If neither exists, set coin_count to -1 to indicate an issue
        coin_count=-1
    fi


    # Run node-info and format output
    ./node-2.0.4-linux-amd64 --node-info | awk -v date="$date_info" -v coins="$coin_count" '
    /Peer ID/ {peer_id=$3}
    /Max Frame/ {max_frame=$3}
    /Active Workers/ {workers=$3}
    /Prover Ring/ {prover_ring=$3}
    /Seniority/ {seniority=$2}
    /Owned balance/ {balance=$3}
    END {
        printf "Peer ID: %s - Date: %s\nMax Frame: %s - Active Workers: %s - Prover Ring: %s - Seniority: %s - Coins: %s - Owned balance: %s QUIL\n",
        peer_id, date, max_frame, workers, prover_ring, seniority, coins, balance
    }'
}

# Function: Analyze proof creation and submission frame ages
analyze_proofs() {
    # Temporary files for storing data
    TEMP_CREATE=$(mktemp)
    TEMP_SUBMIT=$(mktemp)
    TEMP_CREATE_FRAMES=$(mktemp)
    TEMP_SUBMIT_FRAMES=$(mktemp)
    TEMP_MATCHES=$(mktemp)

    if [ "${#found[@]}" -eq 1 ]; then
        # If only one service is found, use it
        SERVICE_NAME=$(echo "${found[0]}" | sed 's/.service//')  # Remove .service suffix
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
        # Exit with an error if no services are found
        echo "No matching services are running."
        exit 1
    fi

    # Function: Calculate average
    calculate_avg() {
        local file=$1
        awk '{ sum += $1; n++ } END { if (n > 0) printf "%.2f", sum / n }' "$file"
    }

    # Function: Colorize based on thresholds
    colorize() {
        local value=$1
        local min=$2
        local optimal_max=$3
        local warning_max=$4

        if (( $(echo "$value <= $optimal_max" | bc -l) )); then
            echo -e "${GREEN}${value}${RESET}"
        elif (( $(echo "$value <= $warning_max" | bc -l) )); then
            echo -e "${YELLOW}${value}${RESET}"
        else
            echo -e "${RED}${value}${RESET}"
        fi
    }

    # Extract frame ages for statistics
    journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
        grep -F "creating data shard ring proof" | \
        sed -E 's/.*"frame_age":([0-9]+\.[0-9]+).*/\1/' > "$TEMP_CREATE"

    journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
        grep -F "submitting data proof" | \
        sed -E 's/.*"frame_age":([0-9]+\.[0-9]+).*/\1/' > "$TEMP_SUBMIT"

    # Extract frame numbers and ages for CPU time calculation
    journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
        grep -F "creating data shard ring proof" | \
        sed -E 's/.*"frame_number":([0-9]+).*"frame_age":([0-9]+\.[0-9]+).*/\1 \2/' > "$TEMP_CREATE_FRAMES"

    journalctl -u $SERVICE_NAME.service --since "$TIME_WINDOW minutes ago" | \
        grep -F "submitting data proof" | \
        sed -E 's/.*"frame_number":([0-9]+).*"frame_age":([0-9]+\.[0-9]+).*/\1 \2/' > "$TEMP_SUBMIT_FRAMES"

    # Calculate CPU processing times
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

    # Summarized output
    if [ -s "$TEMP_CREATE" ] && [ -s "$TEMP_SUBMIT" ] && [ -s "$TEMP_MATCHES" ]; then
        CREATE_AVG=$(calculate_avg "$TEMP_CREATE")
        SUBMIT_AVG=$(calculate_avg "$TEMP_SUBMIT")
        CPU_AVG=$(calculate_avg "$TEMP_MATCHES")
        TOTAL_PROOFS=$(wc -l < "$TEMP_CREATE")

        # Apply color coding
        CREATE_AVG_COLOR=$(colorize "$CREATE_AVG" "$CREATION_OPTIMAL_MIN" "$CREATION_OPTIMAL_MAX" "$CREATION_WARNING_MAX")
        SUBMIT_AVG_COLOR=$(colorize "$SUBMIT_AVG" "$SUBMISSION_OPTIMAL_MIN" "$SUBMISSION_OPTIMAL_MAX" "$SUBMISSION_WARNING_MAX")
        CPU_AVG_COLOR=$(colorize "$CPU_AVG" 0 "$CPU_OPTIMAL_MAX" "$CPU_WARNING_MAX")

        # Output the summarized data
        echo -e "${TOTAL_PROOFS} Proofs - Creation: ${CREATE_AVG_COLOR}s - Submission: ${SUBMIT_AVG_COLOR}s - CPU-Processing: ${CPU_AVG_COLOR}s"
    else
        echo "No proofs found in the last $TIME_WINDOW minutes"
    fi

    # Cleanup
    rm -f "$TEMP_CREATE" "$TEMP_SUBMIT" "$TEMP_CREATE_FRAMES" "$TEMP_SUBMIT_FRAMES" "$TEMP_MATCHES"
}

# Main execution
fetch_node_and_coin_info
analyze_proofs
