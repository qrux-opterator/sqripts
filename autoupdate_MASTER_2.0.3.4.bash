#!/bin/bash
check_directory="/root/ceremonyclient/node"
update_needed=false
log_file="/root/update.log"

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

# Function to check versions for updates
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

run_update() {

    files=$(curl -s https://releases.quilibrium.com/release | grep $release_os-$release_arch)
    
    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$check_directory/$file"; then
            curl -s "https://releases.quilibrium.com/$file" > "$check_directory/$file"
            echo "Downloaded and updated $file"
            chmod +x /root/ceremonyclient/node/*-linux-amd64
            echo "Node is executable"
        else
            echo "$file is already up-to-date."
        fi
    done

    # Stop and restart services
    systemctl disable ceremonyclient
    service ceremonyclient stop
    service para stop

    # Update ExecStart path in the service file
    sudo awk '/^ExecStart=/ {$NF="2.0.3.4"}1' /etc/systemd/system/para.service > temp
    sudo mv temp /etc/systemd/system/para.service

    # Remove cron job for this script
    /usr/bin/crontab -l | grep -v '/root/autoupdate_MASTER_2.0.3.4.bash' | /usr/bin/crontab -
    echo "Cron job removed after update."

    # Restart the service and log success
    systemctl daemon-reload
    service para restart
    echo "$(date) - Restart: Yes" >> "$log_file"
}

# Check if update is needed
echo "Checking for binary release updates..."
check_update_needed "https://releases.quilibrium.com/release"

# Log the outcome of the check
if [ "$update_needed" = true ]; then
    echo "Update needed: yes"
    sleep 30
    random_sleep=$(( RANDOM % 61 ))
    echo "Sleeping for $random_sleep seconds..." 
    sleep $random_sleep
    run_update
else
    echo "Update needed: no"
    echo "$(date) - Restart: No" >> "$log_file"
fi
