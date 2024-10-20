#!/bin/bash
check_directory="/root/ceremonyclient/node"
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
    # BACKUP
    currtimestamp=$(date +%Y%m%d-%H%M%S)
     
    # back up your .config folder to root directory
    cp -r ~/ceremonyclient/node/.config ~/config-backup-$currtimestamp
     
    # back up your entire node folder to root directory
    cp -r ~/ceremonyclient/node ~/node-backup-$currtimestamp
    # Fetch files and check for updates
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

    # Disable and stop the ceremonyclient service
    systemctl disable ceremonyclient
    service ceremonyclient stop

    # Update ExecStart path to new version in the service file
    sudo awk '/^ExecStart=/ {$NF="2.0.1"}1' /etc/systemd/system/para.service > temp
    sudo mv temp /etc/systemd/system/para.service



    # Remove the cron job that triggers the update check every 5 minutes
    /usr/bin/crontab -l | grep -v '/root/autoupdate_default_2.0.0.9.bash' | /usr/bin/crontab -
    echo "Cron job for /root/autoupdate_default_2.0.0.9.bash removed after update."

    # Reload systemd daemon and restart the service
    systemctl daemon-reload
    service para restart
    # Monitor the service logs
    journalctl -u para.service --no-hostname -f

}

# Call the run_update function

# Check for new files for the binary release
echo "Checking for binary release updates..."
check_update_needed "https://releases.quilibrium.com/release"

# Output whether an update is needed
if [ "$update_needed" = true ]; then
    echo "Update needed: yes"
    # Call the update script if update is needed
    run_update
else
    echo "Update needed: no"
fi
