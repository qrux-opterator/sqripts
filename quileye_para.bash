#!/bin/bash

export LC_ALL=C

# Define the output log file
OUTPUT_LOG="/root/quileye.log"

# Define the number of log entries to display
DISPLAY_COUNT=50  # Adjust as needed

# We will fetch DISPLAY_COUNT + 1 entries to have a previous entry for gap calculation
FETCH_COUNT=$((DISPLAY_COUNT + 1))

# Temporary file to store gaps
GAPS_FILE=$(mktemp)

# Color codes using ANSI escape sequences
GREEN='\033[0;32m'   # Green
YELLOW='\033[1;33m'  # Yellow
BLUE='\033[0;34m'    # Blue
RED='\033[0;31m'     # Red
NC='\033[0m'         # No Color

# Redirect all script output to the output log file
exec > "$OUTPUT_LOG" 2>&1

echo -e "Processing Shard Logs...\n"

# Fetch the latest FETCH_COUNT log entries in reverse order (newest first)
log_entries=$(journalctl -u para.service --no-hostname --reverse | \
    grep "shard" | \
    head -n "$FETCH_COUNT" | \
    sed 's/ node-[^ ]*://')

# Reverse the log entries to process them in chronological order
log_entries=$(echo "$log_entries" | tac)

# Initialize arrays to store timestamps and log lines
declare -a ts_array=()
declare -a log_lines=()

# Read the reversed log entries
while read -r line; do
    # Extract the date part (first three fields)
    date_part=$(echo "$line" | awk '{print $1, $2, $3}')

    # Extract the JSON part
    json_part=$(echo "$line" | grep -o '{.*}')

    # Parse JSON using awk
    frame_number=$(echo "$json_part" | awk -F'"frame_number":' '{print $2}' | awk -F',' '{print $1}')
    frame_age=$(echo "$json_part" | awk -F'"frame_age":' '{print $2}' | awk -F'[},]' '{print $1}')
    ring=$(echo "$json_part" | awk -F'"ring":' '{print $2}' | awk -F',' '{print $1}')
    active_workers=$(echo "$json_part" | awk -F'"active_workers":' '{print $2}' | awk -F',' '{print $1}')
    ts=$(echo "$json_part" | awk -F'"ts":' '{print $2}' | awk -F',' '{print $1}')

    # Ensure all values are present
    if [ -z "$frame_number" ] || [ -z "$frame_age" ] || [ -z "$ring" ] || [ -z "$active_workers" ] || [ -z "$ts" ]; then
        echo "Incomplete log entry detected at $date_part. Skipping."
        continue
    fi

    # Store ts values and log lines
    ts_array+=("$ts")

    # Round frame_age to two decimal places
    frame_age_rounded=$(printf "%.2f" "$frame_age")

    # Store the formatted log line
    log_line="$date_part - ${GREEN}FrameNr:${NC} ${YELLOW}$frame_number${NC} - ${GREEN}FrameAge:${NC} ${YELLOW}$frame_age_rounded${NC} - ${GREEN}Ring:${NC} ${YELLOW}$ring${NC} - ${GREEN}Active_workers:${NC} ${YELLOW}$active_workers${NC}"

    log_lines+=("$log_line")
done <<< "$log_entries"

echo ""

# Check if there are enough log entries
if [ "${#ts_array[@]}" -lt 2 ]; then
    echo "Not enough log entries to calculate time gaps."
    echo -e "\n##   Shard Interval   ##"
    echo -e "${GREEN}Last Interval:${NC} N/A"
    echo -e "${GREEN}Low:${NC} N/A"
    echo -e "${GREEN}High:${NC} N/A"
    echo -e "${GREEN}Avg:${NC} N/A"
    echo -e "${GREEN}Median:${NC} N/A"
    # Clean up temporary file
    rm "$GAPS_FILE"
    exit 0
fi

# The first entry (index 0) is not displayed, but used for gap calculation
# We will display entries from index 1 onwards
display_start=1

# Calculate the time since the most recent log entry (last in the array)
current_time=$(date +%s)
recent_ts_int=$(printf "%.0f" "${ts_array[-1]}")  # Last element in the array
interval_sec=$(echo "$current_time - $recent_ts_int" | bc)
interval_int=$(printf "%.0f" "$interval_sec")
if [ "$interval_int" -lt 60 ]; then
    interval_display="${interval_int}s ago"
else
    interval_min=$((interval_int / 60))
    interval_rem_sec=$((interval_int % 60))
    interval_display="${interval_min}m ${interval_rem_sec}s ago"
fi

# Initialize an array to store gaps
declare -a gap_displays=()

# Calculate gaps and prepare log lines with gaps
for ((i=display_start; i<${#ts_array[@]}; i++)); do
    # Get the log line
    log_line="${log_lines[i]}"

    # Calculate the gap using the previous timestamp
    current_ts=${ts_array[i]}
    previous_ts=${ts_array[i-1]}

    # Calculate the gap
    gap=$(echo "$current_ts - $previous_ts" | bc)

    # Ensure gap is positive
    if (( $(echo "$gap < 0" | bc -l) )); then
        gap=$(echo "$gap * -1" | bc)
    fi

    # Append the gap in seconds to GAPS_FILE for statistics
    printf "%.2f\n" "$gap" >> "$GAPS_FILE"

    # Convert gap to integer (seconds)
    gap_int=$(printf "%.0f" "$gap")

    # Determine if gap is under a minute
    if [ "$gap_int" -lt 60 ]; then
        gap_display="${gap_int}s"
    else
        minutes=$(( gap_int / 60 ))
        seconds=$(( gap_int % 60 ))
        gap_display="${minutes}m ${seconds}s"
    fi

    # Store the gap display
    gap_displays+=("$gap_display")

    # Append the gap to the log line
    log_line="$log_line - ${RED}Gap:${NC} ${BLUE}$gap_display${NC}"

    # Print the log line
    echo -e "$log_line"
done

echo ""

# Check if there are at least two gaps to calculate statistics
if [ ! -s "$GAPS_FILE" ]; then
    echo "Not enough log entries to calculate time gaps."
    echo -e "\n##   Shard Interval   ##"
    echo -e "${GREEN}Last Interval:${NC} ${BLUE}$interval_display${NC}"
    echo -e "${GREEN}Low:${NC} N/A"
    echo -e "${GREEN}High:${NC} N/A"
    echo -e "${GREEN}Avg:${NC} N/A"
    echo -e "${GREEN}Median:${NC} N/A"
    # Clean up temporary file
    rm "$GAPS_FILE"
    exit 0
fi

# Function to format time
format_time() {
    local time_val=$(printf "%.0f" "$1")
    if (( time_val >= 60 )); then
        local minutes=$(( time_val / 60 ))
        local seconds=$(( time_val % 60 ))
        printf "%dm %ds" "$minutes" "$seconds"
    else
        printf "%ds" "$time_val"
    fi
}

# Function to calculate median
median() {
    sort -n "$1" | awk '
    {
        a[NR] = $1
    }
    END {
        if (NR == 0) {
            print 0
            exit
        }
        if (NR % 2) {
            print a[(NR + 1) / 2]
        } else {
            mid1 = a[NR / 2]
            mid2 = a[(NR / 2) + 1]
            printf "%.2f", (mid1 + mid2) / 2
        }
    }'
}

# Function to calculate average
average() {
    awk '{ total += $1; count++ } END { if(count > 0) printf "%.2f", total / count }' "$1"
}

# Function to calculate minimum
minimum() {
    sort -n "$1" | head -n1
}

# Function to calculate maximum
maximum() {
    sort -n "$1" | tail -n1
}

# Calculate statistics
lowest=$(minimum "$GAPS_FILE")
highest=$(maximum "$GAPS_FILE")
avg=$(average "$GAPS_FILE")
med=$(median "$GAPS_FILE")

# Format statistics
lowest_display=$(format_time "$lowest")
highest_display=$(format_time "$highest")
avg_display=$(format_time "$avg")
med_display=$(format_time "$med")

# Display the statistics
echo -e "##   Shard Interval   ##"
echo -e "${GREEN}Last Interval:${NC} ${BLUE}$interval_display${NC}"
echo -e "${GREEN}Low:${NC} ${YELLOW}$lowest_display${NC}"
echo -e "${GREEN}High:${NC} ${YELLOW}$highest_display${NC}"
echo -e "${GREEN}Avg:${NC} ${YELLOW}$avg_display${NC}"
echo -e "${GREEN}Median:${NC} ${YELLOW}$med_display${NC}"

# Clean up temporary file
rm "$GAPS_FILE"
