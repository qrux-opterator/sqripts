#!/bin/bash

# Define file URLs
BASE_URL="https://raw.githubusercontent.com/qrux-opterator/sqripts/refs/heads/main"
FILES=(
    "open_quileye.py"
    "blink_quileye.bash"
    "quileye2.bash"
)

# Installation directory
INSTALL_DIR="/root"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
RESET='\033[0m'

# Download and make executable
install_scripts() {
    echo "Starting installation..."
    local success=0
    for file in "${FILES[@]}"; do
        local file_path="${INSTALL_DIR}/${file}"
        echo "Downloading ${file}..."
        curl -s -o "${file_path}" "${BASE_URL}/${file}"
        if [[ $? -eq 0 ]]; then
            chmod +x "${file_path}"
            echo -e "${GREEN}Successfully installed ${file}.${RESET}"
        else
            echo -e "${RED}Failed to download ${file}. Aborting installation.${RESET}"
            return 1
        fi
    done
    return 0
}

# Create crontab entry
setup_cron() {
    echo "Setting up crontab for blink_quileye.bash..."
    read -p "How often should the Balance be Updated? Set in minutes: " interval
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid interval. Please enter a numeric value.${RESET}"
        return 1
    fi
    local cron_entry="*/${interval} * * * * /root/blink_quileye.bash"
    (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Crontab entry created successfully.${RESET}"
        echo "Current crontab entries:"
        echo -e "${BLUE}$(crontab -l | grep blink_quileye.bash)${RESET}"
    else
        echo -e "${RED}Failed to create crontab entry.${RESET}"
        return 1
    fi
    return 0
}

# Run blink_quileye.bash and open_quileye.py
run_scripts() {
    echo "Running blink_quileye.bash for the first time..."
    /root/blink_quileye.bash
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}blink_quileye.bash executed successfully.${RESET}"
    else
        echo -e "${RED}Failed to execute blink_quileye.bash.${RESET}"
        return 1
    fi

    echo "Running open_quileye.py for the first time..."
    python3 /root/open_quileye.py
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}open_quileye.py executed successfully.${RESET}"
    else
        echo -e "${RED}Failed to execute open_quileye.py.${RESET}"
        return 1
    fi
    return 0
}

# Main execution
main() {
    install_scripts
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Installation failed. Exiting.${RESET}"
        exit 1
    fi

    setup_cron
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Crontab setup failed. Exiting.${RESET}"
        exit 1
    fi

    run_scripts
    if [[ $? -ne 0 ]]; then
        echo -e "${RED}Script execution failed. Exiting.${RESET}"
        exit 1
    fi

    echo -e "${GREEN}Installation and setup completed successfully!${RESET}"
}

main
