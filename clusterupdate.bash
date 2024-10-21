#!/bin/bash

# Function to decrypt the file using Python
decrypt_file() {
    ENCRYPTED_FILE_PATH="$1"
    PASSWORD="$2"
    DECRYPTED_FILE_PATH="$3"

    python3 - << EOF
from cryptography.fernet import Fernet
import base64
import hashlib
import sys

def generate_key(password: str) -> bytes:
    password_bytes = password.encode()
    key = hashlib.sha256(password_bytes).digest()
    return base64.urlsafe_b64encode(key)

def decrypt_file(encrypted_file_path: str, password: str, output_file: str):
    key = generate_key(password)
    fernet = Fernet(key)

    try:
        with open(encrypted_file_path, 'rb') as enc_file:
            encrypted_data = enc_file.read()

        # Debug output: show the size of the encrypted file
        print(f"Debug: Encrypted file size: {len(encrypted_data)} bytes")

        decrypted_data = fernet.decrypt(encrypted_data)

        with open(output_file, 'wb') as dec_file:
            dec_file.write(decrypted_data)

        print(f"File decrypted successfully to {output_file}")
    except Exception as e:
        print(f"Decryption failed: {e}")
        sys.exit(1)

decrypt_file('$ENCRYPTED_FILE_PATH', '$PASSWORD', '$DECRYPTED_FILE_PATH')
EOF
}

# Function to color the output
color_text() {
    COLOR="$1"
    TEXT="$2"
    echo -e "\033[${COLOR}m${TEXT}\033[0m"
}

# Function to handle backup
backup_config() {
    BACKUP_DIR="/root/clusterupdate_backup"
    CONFIG_FILE="/root/ceremonyclient/node/.config/config.yml"

    if [ -f "$CONFIG_FILE" ]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_SUBDIR="${BACKUP_DIR}/config_${TIMESTAMP}"

        # Create backup directory if it doesn't exist
        mkdir -p "$BACKUP_SUBDIR"

        # Backup the config file
        cp "$CONFIG_FILE" "$BACKUP_SUBDIR/config.yml"
        
        # Provide user feedback
        color_text "32" "Backup has been saved in ${BACKUP_SUBDIR}/config.yml"
    else
        echo "No existing config file found. Skipping backup."
    fi
}

# Check if /root/node_nr.txt exists
if [ ! -f /root/node_nr.txt ]; then
    echo "Node Number and Cluster Letter not found."
    read -p "Please enter the Node Number: " NODE_NR
    read -p "Please enter the Cluster Letter: " CLUSTER_LETTER
    echo "$NODE_NR $CLUSTER_LETTER" > /root/node_nr.txt
else
    # Read Node Number and Cluster Letter
    read NODE_NR CLUSTER_LETTER < /root/node_nr.txt
fi

# Check if /root/autorestart.txt exists
if [ ! -f /root/autorestart.txt ]; then
    AUTORESTART="off"
else
    AUTORESTART=$(cat /root/autorestart.txt)
fi

# Start the menu loop
while true; do
    # Clear the screen (optional)
    clear

    # Display Node Number, Cluster Letter, and Autorestart status
    echo -e "\033[32mNode Number: $NODE_NR\033[0m"
    echo -e "\033[36mCluster Letter: $CLUSTER_LETTER\033[0m"  # Light blue for the cluster letter
    echo "Autorestart: $AUTORESTART"
    echo ""
    echo "Menu:"
    echo "1. Update ClusterServiceFile"
    echo "2. Download and decrypt config file"
    echo "x. Toggle Autorestart (currently $AUTORESTART)"
    echo "q. Quit"
    echo ""
    read -p "Select an option: " OPTION

    if [ "$OPTION" = "1" ]; then
        # Existing logic for updating the ClusterServiceFile
        echo "Updating ClusterServiceFile..."  # Replace with actual logic

    elif [ "$OPTION" = "2" ]; then
        # Step 1: Download the file based on the Cluster Letter
        CONFIG_URL="https://raw.githubusercontent.com/qrux-opterator/sqripts/main/x_${CLUSTER_LETTER}"

        # Use a temporary file for the encrypted config
        TMP_ENCRYPTED_FILE="/tmp/config_${CLUSTER_LETTER}.enc"

        echo "Downloading encrypted config file for Cluster $CLUSTER_LETTER..."
        curl -s -o "$TMP_ENCRYPTED_FILE" -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "$CONFIG_URL"

        if [ ! -f "$TMP_ENCRYPTED_FILE" ]; then
            color_text "31" "Error: Failed to download the config file."
            read -p "Press Enter to continue..."
            exit 1
        fi

        # Show file size of the downloaded encrypted file for debugging
        ENCRYPTED_SIZE=$(stat --format="%s" "$TMP_ENCRYPTED_FILE")
        echo "Debug: Encrypted config file size: $ENCRYPTED_SIZE bytes"

        # Step 2: Perform a backup
        backup_config

        # Step 3: Prompt the user for a password to decrypt the file
        read -sp "Enter the password to decrypt the config file: " PASSWORD
        echo ""

        # Step 4: Decrypt the file using the Python function
        DECRYPTED_FILE="/root/ceremonyclient/node/.config/config.yml"
        echo "Decrypting the file..."
        decrypt_file "$TMP_ENCRYPTED_FILE" "$PASSWORD" "$DECRYPTED_FILE"

        # Step 5: Check if the file was decrypted successfully
        if [ -f "$DECRYPTED_FILE" ]; then
            color_text "32" "New config.yml for Cluster \033[36m$CLUSTER_LETTER\033[32m has been downloaded and decrypted."  # Show cluster letter in light blue
        else
            color_text "31" "Decryption failed. The file could not be decrypted."
        fi

        # Clean up: remove the temporary encrypted file
        rm -f "$TMP_ENCRYPTED_FILE"

        read -p "Press Enter to continue..."

    elif [ "$OPTION" = "x" ]; then
        # Toggle autorestart
        if [ "$AUTORESTART" = "on" ]; then
            AUTORESTART="off"
        else
            AUTORESTART="on"
        fi
        echo "$AUTORESTART" > /root/autorestart.txt
        echo "Autorestart is now $AUTORESTART."
        read -p "Press Enter to refresh the menu..."

    elif [ "$OPTION" = "q" ]; then
        echo "Exiting."
        exit 0
    else
        echo "Invalid option."
        read -p "Press Enter to continue..."
    fi
done
