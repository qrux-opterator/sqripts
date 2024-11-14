#!/bin/bash

input_file="/root/cm_settings.txt"
output_file="/root/ping_results.txt"

# Clear the output file if it exists
> "$output_file"

# Read the file line by line
while read -r line; do
    # Extract IP and associated value
    ip=$(echo "$line" | awk '{print $1}')
    value=$(echo "$line" | awk '{print $2}')

    # Ping the IP address 3 times and extract the average time
    avg_time=$(ping -c 3 "$ip" | awk -F'/' '/rtt/ {print $5}')

    # Handle cases where ping fails
    if [ -z "$avg_time" ]; then
        avg_time="N/A"
    fi

    # Log the result
    echo "$ip $avg_time" >> "$output_file"
    echo "[LOG] Processed $ip: Average Ping = $avg_time ms"
done < "$input_file"

# Output the results
echo -e "\nPing Results:"
cat "$output_file"
