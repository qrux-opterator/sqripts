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

decrypt_file("$ENCRYPTED_FILE_PATH", "$PASSWORD", "$DECRYPTED_FILE_PATH")
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
    CONFIG_FILE="$1"  # Config or keys file path
    FILE_NAME="$2"    # Name of the file being backed up

    if [ -f "$CONFIG_FILE" ]; then
        TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_SUBDIR="${BACKUP_DIR}/backup_${TIMESTAMP}"

        # Create backup directory if it doesn't exist
        mkdir -p "$BACKUP_SUBDIR"

        # Backup the file
        cp "$CONFIG_FILE" "$BACKUP_SUBDIR/$FILE_NAME"
        
        # Provide user feedback
        color_text "32" "Backup of $FILE_NAME has been saved in ${BACKUP_SUBDIR}/$FILE_NAME"
    else
        echo "No existing $FILE_NAME found. Skipping backup."
    fi
}

# Function to update node_nr.txt
update_node_nr() {
    read -p "Enter new Node Number: " NEW_NODE_NR
    read -p "Enter new Cluster Letter: " NEW_CLUSTER_LETTER

    # Write the new node number and cluster letter to node_nr.txt
    NODE_NR_FILE="/root/node_nr.txt"
    echo "$NEW_NODE_NR $NEW_CLUSTER_LETTER" > "$NODE_NR_FILE"

    color_text "32" "node_nr.txt has been updated with Node Number: \033[36m$NEW_NODE_NR\033[32m and Cluster Letter: \033[36m$NEW_CLUSTER_LETTER\033[32m."
}

# Function to update the ClusterServiceFile
update_cluster_service_file() {
    # Check if the service file exists
    SERVICE_FILE="/etc/systemd/system/para.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        color_text "31" "Service file $SERVICE_FILE does not exist."
        read -p "Press Enter to continue..."
        return
    fi

    # Get the ExecStart line
    EXEC_START_LINE=$(grep '^ExecStart' "$SERVICE_FILE")
    if [ -z "$EXEC_START_LINE" ]; then
        color_text "31" "ExecStart line not found in $SERVICE_FILE."
        read -p "Press Enter to continue..."
        return
    fi

    # Get arguments after ExecStart=
    ARGS=$(echo "$EXEC_START_LINE" | cut -d'=' -f2-)
    read -a ARGS_ARRAY <<< "$ARGS"

    NUM_ARGS=${#ARGS_ARRAY[@]}
    if [ $NUM_ARGS -lt 3 ]; then
        color_text "31" "Not enough arguments in ExecStart line."
        read -p "Press Enter to continue..."
        return
    fi

    # Get 2nd and 3rd last arguments
    INDEX1=$((NUM_ARGS - 3))
    INDEX2=$((NUM_ARGS - 2))
    ARG1="${ARGS_ARRAY[$INDEX1]}"
    ARG2="${ARGS_ARRAY[$INDEX2]}"

    LAST_TWO_ARGS="$ARG1 $ARG2"

    # Fetch the remote node_nr.txt file with cache-busting
    REMOTE_FILE=$(curl -s -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "https://raw.githubusercontent.com/qrux-opterator/sqripts/main/node_nr.txt?$(date +%s)")

    # Retrieve remote values for the Node Number and Cluster Letter
    REMOTE_VALUES=$(echo "$REMOTE_FILE" | awk -v node_nr="$NODE_NR" '$1 == node_nr {print $2, $3, $4}')

    if [ -z "$REMOTE_VALUES" ]; then
        color_text "31" "Node Number $NODE_NR not found in remote file."
        read -p "Press Enter to continue..."
        return
    fi

    # Split REMOTE_VALUES into variables
    read REMOTE_ARG1 REMOTE_ARG2 REMOTE_CLUSTER_LETTER <<< "$REMOTE_VALUES"

    # Show the outputs retrieved
    color_text "32" "Your service file setup: \033[31m$LAST_TWO_ARGS\033[0m"
    color_text "32" "Cloud-Setup for Node \033[36m$NODE_NR\033[32m: \033[32m$REMOTE_ARG1 $REMOTE_ARG2\033[0m"
    color_text "32" "Your Cluster-Letter: \033[36m$CLUSTER_LETTER\033[0m"
    color_text "32" "Cloud Cluster-Letter: \033[32m$REMOTE_CLUSTER_LETTER\033[0m"

    # Compare Cluster Letters
    if [ "$CLUSTER_LETTER" == "$REMOTE_CLUSTER_LETTER" ]; then
        color_text "32" "Cluster: match."
    else
        color_text "31" "Cluster: do not match."
    fi

    # Compare values and update if necessary
    if [ "$LAST_TWO_ARGS" != "$REMOTE_ARG1 $REMOTE_ARG2" ]; then
        color_text "31" "Service Exec: Values do not match."
        ARGS_ARRAY[$INDEX1]="$REMOTE_ARG1"
        ARGS_ARRAY[$INDEX2]="$REMOTE_ARG2"

        # Reconstruct the ARGS and build the new ExecStart line
        NEW_ARGS=$(printf "%s " "${ARGS_ARRAY[@]}")
        NEW_ARGS=${NEW_ARGS% } # Remove trailing space
        NEW_EXEC_START_LINE="ExecStart=$NEW_ARGS"

        # Replace the ExecStart line in the service file
        sed -i "s|^ExecStart=.*|$NEW_EXEC_START_LINE|" "$SERVICE_FILE"
        color_text "32" "Your service has been set to $REMOTE_ARG1 $REMOTE_ARG2."
        
        # Log the changes
        echo "$(date): Updated ExecStart line in para.service with new values: $REMOTE_ARG1 $REMOTE_ARG2" >> /var/log/updatecluster.log
    else
        color_text "32" "Service Exec: Values match."
    fi

    # Reload service if autorestart is on
    if [ "$AUTORESTART" == "on" ]; then
        systemctl daemon-reload && systemctl restart para
        journalctl -u para.service --no-hostname -f
    fi

    read -p "Press Enter to continue..."
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
    echo "3. Update Node Number and Cluster Letter (node_nr.txt)"
    echo "x. Toggle Autorestart (currently $AUTORESTART)"
    echo "q. Quit"
    echo ""
    read -p "Select an option: " OPTION

    if [ "$OPTION" = "1" ]; then
        # Update ClusterServiceFile
        update_cluster_service_file

    elif [ "$OPTION" = "2" ]; then
        # Step 1: Download the config file based on the Cluster Letter
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

        # Step 2: Backup the current config file (if it exists)
        backup_config "/root/ceremonyclient/node/.config/config.yml" "config.yml"

        # Step 3: Prompt the user for a password to decrypt the config file
        read -sp "Enter the password to decrypt the config file: " PASSWORD
        echo ""

        # Step 4: Decrypt the config file using the Python function
        DECRYPTED_FILE="/root/ceremonyclient/node/.config/config.yml"
        echo "Decrypting the config file..."
        decrypt_file "$TMP_ENCRYPTED_FILE" "$PASSWORD" "$DECRYPTED_FILE"

        # Step 5: Check if the config file was decrypted successfully
        if [ -f "$DECRYPTED_FILE" ]; then
            color_text "32" "New config.yml for Cluster \033[36m$CLUSTER_LETTER\033[32m has been downloaded and decrypted."  # Show cluster letter in light blue
        else
            color_text "31" "Decryption failed. The config file could not be decrypted."
        fi

        # Clean up: remove the temporary encrypted file
        rm -f "$TMP_ENCRYPTED_FILE"

        # Prompt the user for downloading and decrypting the keys
        read -p "Do you want to download and decrypt the keys for Cluster $CLUSTER_LETTER? (yes/no): " DOWNLOAD_KEYS

        if [ "$DOWNLOAD_KEYS" = "yes" ]; then
            # Step 6: Download the keys file based on the Cluster Letter
            KEYS_URL="https://raw.githubusercontent.com/qrux-opterator/sqripts/main/y_${CLUSTER_LETTER}"

            # Use a temporary file for the encrypted keys
            TMP_KEYS_ENCRYPTED="/tmp/keys_${CLUSTER_LETTER}.enc"

            echo "Downloading encrypted keys file for Cluster $CLUSTER_LETTER..."
            curl -s -o "$TMP_KEYS_ENCRYPTED" -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "$KEYS_URL"

            if [ ! -f "$TMP_KEYS_ENCRYPTED" ]; then
                color_text "31" "Error: Failed to download the keys file."
                read -p "Press Enter to continue..."
                exit 1
            fi

            # Step 7: Backup the current keys file (if it exists)
            backup_config "/root/ceremonyclient/node/.config/keys.yml" "keys.yml"

            # Step 8: Prompt for the password to decrypt the keys
            read -sp "Enter the password to decrypt the keys file: " PASSWORD_KEYS
            echo ""

            # Step 9: Decrypt the keys file using the Python function
            DECRYPTED_KEYS="/root/ceremonyclient/node/.config/keys.yml"
            echo "Decrypting the keys file..."
            decrypt_file "$TMP_KEYS_ENCRYPTED" "$PASSWORD_KEYS" "$DECRYPTED_KEYS"

            # Step 10: Check if the keys file was decrypted successfully
            if [ -f "$DECRYPTED_KEYS" ]; then
                color_text "32" "New keys.yml for Cluster \033[36m$CLUSTER_LETTER\033[32m has been downloaded and decrypted."
            else
                color_text "31" "Decryption failed. The keys file could not be decrypted."
            fi

            # Clean up: remove the temporary encrypted keys file
            rm -f "$TMP_KEYS_ENCRYPTED"
        fi

        read -p "Press Enter to continue..."

    elif [ "$OPTION" = "3" ]; then
        # Update node_nr.txt
        update_node_nr

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
