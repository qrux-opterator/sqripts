#!/bin/bash

# Function to get RAM usage percentage with two decimal places
get_ram_usage() {
    # Extract total and used memory in KB from the 'Mem:' line
    read total used <<< $(free | awk '/^Mem:/ {print $2, $3}')
    # Calculate RAM usage percentage with two decimal places
    usage=$(echo "scale=4; ($used / $total) * 100" | bc)
    # Format to two decimal places, ensuring leading zero if necessary
    printf "%.2f" "$usage"
}

# Function to get Swap usage in GB with two decimal places
get_swap_usage() {
    # Extract used swap in MB from the 'Swap:' line
    used_swap_mb=$(free -m | awk '/^Swap:/ {print $3}')
    # If swap used is empty or "-", set to 0
    used_swap_mb=${used_swap_mb:-0}
    # Convert to GB with two decimal places
    swap_gb=$(echo "scale=2; $used_swap_mb / 1024" | bc)
    # Ensure leading zero for values less than 1G
    printf "%.2f" "$swap_gb"
}

# Get RAM and Swap usage
ram=$(get_ram_usage)
swap=$(get_swap_usage)

# Define ANSI color codes for output
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m' # Reset color

# Function to check and display RAM usage
check_ram() {
    if (( $(echo "$ram > 95" | bc -l) )); then
        echo -e "${YELLOW}RAM Usage: ${ram}% - ${RED}Check Failed ❌${RESET}"
        echo "RAM nearly full: Restaring Service Now..."
        sleep 3
        service ceremonyclient restart
        exit
    else
        echo -e "${YELLOW}RAM Usage: ${ram}% - ${GREEN}Check Passed! ✅${RESET}"
    fi
}

# Function to check and display Swap usage
check_swap() {
    if (( $(echo "$swap > 2" | bc -l) )); then
        echo -e "${BLUE}Swap Used: ${swap}G - ${RED}Check Failed ❌${RESET}"
        echo "Swap getting used: Restaring Service Now..."
        sleep 3
        service ceremonyclient restart
        exit
    else
        echo -e "${BLUE}Swap Used: ${swap}G - ${GREEN}Check Passed! ✅${RESET}"
    fi
}

# Execute the checks
check_ram
check_swap
