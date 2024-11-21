#!/bin/bash

# Description:
# This script ensures LastUserCheck: and LastAutoCheck: exist in the log file.
# It increments LastAutoCheck, appends a new Check-Nr header, runs /root/qnode_proof_monitor_light.sh,
# and appends its output to the log.

# Log file path
LOG_FILE="/root/quileye2.log"

# Step 1: Create the log file if it does not exist
if [[ ! -f "$LOG_FILE" ]]; then
    echo "Log file not found. Creating $LOG_FILE..."
    touch "$LOG_FILE"
    echo "LastUserCheck: 0" >> "$LOG_FILE"
    echo "LastAutoCheck: 0" >> "$LOG_FILE"
fi

# Step 2: Ensure LastUserCheck: and LastAutoCheck: exist in the log
if ! grep -q "LastUserCheck:" "$LOG_FILE"; then
    echo "LastUserCheck: 0" | cat - "$LOG_FILE" > /tmp/quileye2.tmp && mv /tmp/quileye2.tmp "$LOG_FILE"
fi

if ! grep -q "LastAutoCheck:" "$LOG_FILE"; then
    echo "LastAutoCheck: 0" | cat - "$LOG_FILE" > /tmp/quileye2.tmp && mv /tmp/quileye2.tmp "$LOG_FILE"
fi

# Step 3: Extract the last sequence number from the log file
LAST_CHECK=$(grep "LastAutoCheck:" "$LOG_FILE" | awk -F': ' '{print $2}')

# Step 4: Increment the sequence number
if [[ -n "$LAST_CHECK" ]]; then
    NEW_CHECK=$((LAST_CHECK + 1))
else
    # Default to 1 if the value is missing or the file is empty
    NEW_CHECK=1
fi

# Step 5: Run /root/qnode_proof_monitor_light.sh and capture its output
QUILEYE_OUTPUT=$(/root/qnode_proof_monitor_light.sh)

# Step 6: Append the new header, a new line, and the output to the log
{
    echo
    echo "Check-Nr $NEW_CHECK:"
    echo "$QUILEYE_OUTPUT"
} >> "$LOG_FILE"

# Step 7: Update the LastAutoCheck value in the log file
sed -i "s/LastAutoCheck: $LAST_CHECK/LastAutoCheck: $NEW_CHECK/" "$LOG_FILE"

# Optional: Display a message to indicate success
echo "Log updated: Check-Nr $NEW_CHECK added to $LOG_FILE."
