#!/bin/bash
check_directory="/root/ceremonyclient/node"
log_file="/root/update.log"
update_needed=false

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
            echo "Update needed for $file (version: $version)"
            update_needed=true
        else
            echo "$file (version: $version) is already up-to-date."
        fi
    done
}

run_update() {

    # Function to update service and restart it

    # Determine the OS and architecture
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
     
    # Fetch files and check for updates
    files=$(curl -s https://releases.quilibrium.com/release | grep $release_os-$release_arch)
    
    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$check_directory/$file"; then
            curl -s "https://releases.quilibrium.com/$file" > "$check_directory/$file"
            echo "Downloaded and updated $file"
        else
            echo "$file is already up-to-date."
            chmod +x /root/ceremonyclient/node/*-linux-amd64
            echo "Node is executable"
        fi
    done

    # Disable and stop the ceremonyclient service
    systemctl disable ceremonyclient
    service ceremonyclient stop

    # Update ExecStart path to new version in the service file
    cat << 'EOF' | sudo tee /lib/systemd/system/ceremonyclient.service > /dev/null
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
ExecStart=/root/ceremonyclient/node/node-2.0.3.4-linux-amd64
KillSignal=SIGINT
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd daemon and restart the service
    systemctl daemon-reload
    service ceremonyclient restart

    # Monitor the service logs

    # Remove the cron job that triggers the update check every 5 minutes
    /usr/bin/crontab -l | grep -v '/root/autoupdate_default_2.0.3.4.bash' | /usr/bin/crontab -
    echo "Cron job for /root/autoupdate_default_2.0.3.4.bash removed after update."

}

# Call the run_update function

# Check for new files for the binary release
echo "Checking for binary release updates..."
check_update_needed "https://releases.quilibrium.com/release"

# Output whether an update is needed
if [ "$update_needed" = true ]; then
    echo "Update needed: yes"
    echo "$(date): Update needed: $update_needed" >> /root/update.log
    random_sleep=$(( RANDOM % 120 ))
    echo "Sleeping for $random_sleep seconds..." 
    sleep $random_sleep
    run_update
else
    echo "Update needed: no"
    echo "$(date): Update needed: $update_needed" >> /root/update.log

fi
