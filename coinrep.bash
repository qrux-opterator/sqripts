#!/bin/bash

# Check if an argument is provided; default to 24 if not
HOURS=${1:-24}

cd /root/ceremonyclient/node

# Retrieve and process coin metadata
COIN_DATA=$(
   ./qclient-2.0.4.1-linux-amd64 token coins metadata --public-rpc --config /root/ceremonyclient/node/.config | \
awk -v hours="$HOURS" '
BEGIN {
    ENVIRON["TZ"] = "UTC"
}
{
    for(i=1; i<=NF; i++) {
        if ($i == "Timestamp") {
            ts_full = $(i+1)
            gsub("Z", "", ts_full)
            # Convert timestamp to epoch seconds using system date command
            cmd = "date -u -d \"" ts_full "\" +%s"
            cmd | getline ts_epoch
            close(cmd)
            if (ts_epoch == "") {
                # Handle parsing errors
                next
            }
            # Get current time in epoch seconds
            now_epoch = systime()
            # Calculate time difference
            diff = now_epoch - ts_epoch
            # Check if the timestamp is within the last specified hours
            if (diff >= 0 && diff <= hours * 3600) {
                print $6, $0
            }
            break
        }
    }
}' | sort | cut -d' ' -f2-
)

# Extract QUIL values and calculate total, average, median, high, and low
QUIL_VALUES=$(echo "$COIN_DATA" | awk '/QUIL/ {print $1}')
TOTAL_QUIL=$(echo "$QUIL_VALUES" | awk '{sum += $1} END {print sum}')
AVERAGE_QUIL=$(echo "$QUIL_VALUES" | awk '{sum += $1} END {if (NR > 0) print sum / NR}')
MEDIAN_QUIL=$(echo "$QUIL_VALUES" | sort -n | awk '{a[NR] = $1} END {if (NR % 2) {print a[(NR + 1) / 2]} else {print (a[(NR / 2)] + a[(NR / 2) + 1]) / 2}}')
HIGH_QUIL=$(echo "$QUIL_VALUES" | sort -n | tail -n 1)
LOW_QUIL=$(echo "$QUIL_VALUES" | sort -n | head -n 1)

# Check if /root/quileye2.log exists and retrieve Active Workers
if [ -f /root/quileye2.log ]; then
    ACTIVE_WORKERS=$(grep "Active Workers:" /root/quileye2.log | tail -n1 | awk -F'Active Workers: ' '{print $2}' | awk '{print $1}')
else
    read -p "File /root/quileye2.log not found. Enter the number of active workers: " ACTIVE_WORKERS
fi

# Calculate per worker metrics
if [ "$ACTIVE_WORKERS" -gt 0 ]; then
    TOTAL_PER_WORKER=$(awk "BEGIN {print $TOTAL_QUIL / $ACTIVE_WORKERS}")
    AVG_PER_WORKER=$(awk "BEGIN {print $AVERAGE_QUIL / $ACTIVE_WORKERS}")
    MEDIAN_PER_WORKER=$(awk "BEGIN {print $MEDIAN_QUIL / $ACTIVE_WORKERS}")
    HIGH_PER_WORKER=$(awk "BEGIN {print $HIGH_QUIL / $ACTIVE_WORKERS}")
    LOW_PER_WORKER=$(awk "BEGIN {print $LOW_QUIL / $ACTIVE_WORKERS}")
else
    TOTAL_PER_WORKER="N/A"
    AVG_PER_WORKER="N/A"
    MEDIAN_PER_WORKER="N/A"
    HIGH_PER_WORKER="N/A"
    LOW_PER_WORKER="N/A"
fi

# Calculate landing rate
LANDING_RATE=$(echo "$COIN_DATA" | awk '
/Frame / {
    n++
    match($0, /Frame ([0-9]+),/, arr)
    frame = arr[1]
    frames[n] = frame
}
END {
    asort(frames)
    first_frame = frames[1]
    last_frame = frames[n]
    frame_diff = last_frame - first_frame
    landing_rate = (frame_diff != 0) ? (n / frame_diff) * 100 : 0
    printf("%.2f", landing_rate)
}')

# Determine landing rate color
if (( $(echo "$LANDING_RATE < 5" | bc -l) )); then
    RATE_COLOR="\033[31m" # Red
elif (( $(echo "$LANDING_RATE > 10" | bc -l) )); then
    RATE_COLOR="\033[32m" # Green
else
    RATE_COLOR="" # Default
fi

# Append the report to /root/coinreport.log
{
  echo ""
  # Print Landing Rate with ANSI color
  printf "Landing Rate: \033[32m%s%%\033[0m\n" "$LANDING_RATE"
  date
  echo -e "━━━━━━━━━━━━━━━━ COINREPORT "$HOURS"hs  ━━━━━━━━━━━━━━━━"
  printf "%-25s %-20s\n" "Total QUIL earned:" "$TOTAL_QUIL"
  printf "%-25s %-20s\n" "Average QUIL per Coin:" "$AVERAGE_QUIL"
  printf "%-25s %-20s\n" "Median QUIL per Coin:" "$MEDIAN_QUIL"
  printf "%-25s %-20s\n" "High QUIL per Coin:" "$HIGH_QUIL"
  printf "%-25s %-20s\n" "Low QUIL per Coin:" "$LOW_QUIL"
  printf "%-25s %-20s\n" "Active Workers:" "$ACTIVE_WORKERS"
  printf "%-25s %-20s\n" "Total per Worker:" "$TOTAL_PER_WORKER"
  printf "%-25s %-20s\n" "Average per Worker:" "$AVG_PER_WORKER"
  printf "%-25s %-20s\n" "Median per Worker:" "$MEDIAN_PER_WORKER"
  printf "%-25s %-20s\n" "High per Worker:" "$HIGH_PER_WORKER"
  printf "%-25s %-20s\n" "Low per Worker:" "$LOW_PER_WORKER"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
} >> /root/coinreport.log

# Display the content of the log file
cat /root/coinreport.log
