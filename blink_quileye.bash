#!/bin/bash

# Description:
# This script ensures LastUserCheck: and LastAutoCheck: exist in the log file.
# It increments LastAutoCheck, appends a new Check-Nr header, runs /root/quileye2.bash,
# and appends its output to the log.

# Log file path
LOG_FILE="/root/quileye2.log"

# Step 1: Ensure LastUserCheck: and LastAutoCheck: exist in the log
if ! grep -q "LastUserCheck:" "$LOG_FILE"; then
    echo "LastUserCheck: 0" | cat - "$LOG_FILE" > /tmp/quileye2.tmp && mv /tmp/quileye2.tmp "$LOG_FILE"
fi

if ! grep -q "LastAutoCheck:" "$LOG_FILE"; then
    echo "LastAutoCheck: 0" | cat - "$LOG_FILE" > /tmp/quileye2.tmp && mv /tmp/quileye2.tmp "$LOG_FILE"
fi

# Step 2: Extract the last sequence number from the log file
LAST_CHECK=$(grep "LastAutoCheck:" "$LOG_FILE" | awk -F': ' '{print $2}')

# Step 3: Increment the sequence number
if [[ -n "$LAST_CHECK" ]]; then
    NEW_CHECK=$((LAST_CHECK + 1))
else
    # Default to 1 if the value is missing or the file is empty
    NEW_CHECK=1
fi

# Step 4: Run /root/quileye2.bash and capture its output
QUILEYE_OUTPUT=$(/root/quileye2.bash)

# Step 5: Append the new header, a new line, and the output to the log
{
    echo
    echo "Check-Nr $NEW_CHECK:"
    echo "$QUILEYE_OUTPUT"
} >> "$LOG_FILE"

# Step 6: Update the LastAutoCheck value in the log file
sed -i "s/LastAutoCheck: $LAST_CHECK/LastAutoCheck: $NEW_CHECK/" "$LOG_FILE"

# Optional: Display a message to indicate success
# echo "Ensured LastUserCheck and LastAutoCheck exist, appended Check-Nr $NEW_CHECK, and updated LastAutoCheck in $LOG_FILE"
