#!/bin/bash

# Prompt for number of coins to process
read -p "Enter how many coins to process from the bottom: " N

# Navigate to the directory
cd /root/ceremonyclient/node

# Retrieve and process coin metadata
COIN_DATA=$(
    ./qclient-2.0.4.1-linux-amd64 token coins metadata --public-rpc --config /root/ceremonyclient/node/.config | \
    awk '{print $6, $0}' | sort | cut -d' ' -f2- | head -n -2 | tail -n "$N"
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
    AVG_PER_WORKER=$(awk "BEGIN {print $AVERAGE_QUIL / $ACTIVE_WORKERS}")
    MEDIAN_PER_WORKER=$(awk "BEGIN {print $MEDIAN_QUIL / $ACTIVE_WORKERS}")
    HIGH_PER_WORKER=$(awk "BEGIN {print $HIGH_QUIL / $ACTIVE_WORKERS}")
    LOW_PER_WORKER=$(awk "BEGIN {print $LOW_QUIL / $ACTIVE_WORKERS}")
else
    AVG_PER_WORKER="N/A"
    MEDIAN_PER_WORKER="N/A"
    HIGH_PER_WORKER="N/A"
    LOW_PER_WORKER="N/A"
fi

# Append the report to /root/coinreport.log
{
  echo ""
  date
  echo -e "━━━━━━━━━━━━━━━━ COINREPORT ━━━━━━━━━━━━━━━━"
  printf "%-25s %-20s\n" "Total QUIL:" "$TOTAL_QUIL"
  printf "%-25s %-20s\n" "Average QUIL:" "$AVERAGE_QUIL"
  printf "%-25s %-20s\n" "Median QUIL:" "$MEDIAN_QUIL"
  printf "%-25s %-20s\n" "High QUIL:" "$HIGH_QUIL"
  printf "%-25s %-20s\n" "Low QUIL:" "$LOW_QUIL"
  printf "%-25s %-20s\n" "Active Workers:" "$ACTIVE_WORKERS"
  printf "%-25s %-20s\n" "Average per Worker:" "$AVG_PER_WORKER"
  printf "%-25s %-20s\n" "Median per Worker:" "$MEDIAN_PER_WORKER"
  printf "%-25s %-20s\n" "High per Worker:" "$HIGH_PER_WORKER"
  printf "%-25s %-20s\n" "Low per Worker:" "$LOW_PER_WORKER"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
} >> /root/coinreport.log

# Display the content of the log file
cat /root/coinreport.log