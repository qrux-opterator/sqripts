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

    # Check and remove existing crontab entry for blink_quileye.bash
    if crontab -l 2>/dev/null | grep -q "blink_quileye.bash"; then
        echo "Removing existing crontab entry for blink_quileye.bash..."
        crontab -l 2>/dev/null | grep -v "blink_quileye.bash" | crontab -
    fi

    # Prompt the user for the update interval in minutes
    read -p "How often should the Balance be Updated? Set in minutes: " interval
    
    # Validate the interval is a numeric value
    if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Invalid interval. Please enter a numeric value.${RESET}"
        return 1
    fi

    # Add the new crontab entry
    local cron_entry="*/${interval} * * * * /root/blink_quileye.bash"
    (crontab -l 2>/dev/null; echo "${cron_entry}") | crontab -
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}Crontab entry created successfully.${RESET}"
        echo "Current crontab entries:"
        crontab -l | grep "blink_quileye.bash"
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

    echo "Running quileye2.bash for the first time..."
    /root/quileye2.bash
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}quileye2.bash executed successfully.${RESET}"
    else
        echo -e "${RED}Failed to execute quileye2.bash.${RESET}"
        return 1
    fi
    return 0
}

# Main execution
main() {
    echo "Checking if pip is installed..."
    if ! command -v pip3 &>/dev/null; then
        echo "pip3 not found. Installing python3-pip..."
        sudo apt update -y && sudo apt install -y python3-pip
        if [[ $? -ne 0 ]]; then
            echo "Failed to install python3-pip. Exiting."
            exit 1
        fi
    else
        echo "pip3 is already installed."
    fi
    
    echo "Checking if 'wcwidth' Python module is installed..."
    # Find the path to the python3 binary being used
    PYTHON_BIN=$(which python3)
    if [[ -z "$PYTHON_BIN" ]]; then
        echo -e "${RED}Python3 is not installed. Please install Python3 first.${RESET}"
        exit 1
    fi

    # Use python3 to verify if wcwidth is available
    $PYTHON_BIN -c "import wcwidth" 2>/dev/null
    if [[ $? -ne 0 ]]; then
        echo -e "${BLUE}'wcwidth' not found. Installing it...${RESET}"
        $PYTHON_BIN -m ensurepip --upgrade 2>/dev/null
        $PYTHON_BIN -m pip install --upgrade pip
        $PYTHON_BIN -m pip install wcwidth

        # Verify installation again
        $PYTHON_BIN -c "import wcwidth" 2>/dev/null
        if [[ $? -eq 0 ]]; then
            echo -e "${GREEN}'wcwidth' installed successfully.${RESET}"
        else
            echo -e "${RED}Failed to install 'wcwidth'. Exiting.${RESET}"
            exit 1
        fi
    else
        echo -e "${GREEN}'wcwidth' is already installed.${RESET}"
    fi
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
    echo -e "Run--> ${RED}python3 open_quileye.py${RESET} <--to check your Progress. Good Luck! 🍀"
}

main
