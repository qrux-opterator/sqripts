#!/bin/bash
check_directory="/root/ceremonyclient/node"
update_needed=false
log_file="/root/update.log"

# Set OS and architecture based on the system
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    release_os="linux"
    if [[ $(uname -m) == "aarch64"* ]]; then
        release_arch="arm64"
    else
        release_arch="amd64"
    fi
else
    release_os="darwin"
    release_arch="arm64"
fi

# Function to check for update necessity
check_update_needed () {
    local file_list=$(curl -s $1 | grep $release_os-$release_arch)

    for file in $file_list; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$check_directory/$file"; then
            update_needed=true
        else
            echo "$file (version: $version) is already up-to-date."
        fi
    done
}

# Function to perform the update if needed
run_update() {
    currtimestamp=$(date +%Y%m%d-%H%M%S)
    cp -r ~/ceremonyclient/node/.config ~/config-backup-$currtimestamp
    cp -r ~/ceremonyclient/node ~/node-backup-$currtimestamp

    files=$(curl -s https://releases.quilibrium.com/release | grep $release_os-$release_arch)
    
    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$check_directory/$file"; then
            curl -s "https://releases.quilibrium.com/$file" > "$check_directory/$file"
            echo "Downloaded and updated $file"
        else
            echo "$file is already up-to-date."
        fi
    done

    # Stop and restart services
    systemctl disable ceremonyclient
    service ceremonyclient stop
    service para stop

    # Update ExecStart path in the service file
    sudo awk '/^ExecStart=/ {$NF="2.0.3"}1' /etc/systemd/system/para.service > temp
    sudo mv temp /etc/systemd/system/para.service

    # Remove cron job for this script
    (crontab -l | grep -v '/root/autoupdate_MASTER_2.0.3.bash') | crontab -
    echo "Cron job removed after update."

    # Restart the service and log the action
    systemctl daemon-reload
    service para restart
    echo "$(date) - Restart: Yes" >> "$log_file"
}

# Main process: Check for updates and log the result
echo "Checking for binary release updates..."
check_update_needed "https://releases.quilibrium.com/release"

# Log the outcome and take action based on update need
if [ "$update_needed" = true ]; then
    echo "Update needed: yes"
    sleep 90
    run_update
else
    echo "Update needed: no"
    echo "$(date) - Restart: No" >> "$log_file"
fi
