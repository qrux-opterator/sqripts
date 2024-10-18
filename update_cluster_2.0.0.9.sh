#!/bin/bash

# Function to update binaries
function update {
    cd /root/ceremonyclient/node || exit

    # Create and write the script into update_binary.sh
    cat << 'EOF' > update_binary.sh
    #!/bin/bash

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

    files=$(curl -s https://releases.quilibrium.com/release | grep $release_os-$release_arch)
    
    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "./$file"; then
            curl -s "https://releases.quilibrium.com/$file" > "$file"
            echo "Downloaded and updated $file"
        else
            echo "$file is already up-to-date."
        fi
    done
EOF

    # Make the script executable and run it
    chmod +x update_binary.sh
    ./update_binary.sh
}

# Function to update service and restart it
function update_service_start {
    systemctl disable ceremonyclient
    service ceremonyclient stop

    # Update ExecStart path to new version
    sudo awk '/^ExecStart=/ {$NF="2.0.0.9"}1' /etc/systemd/system/para.service > temp
    sudo mv temp /etc/systemd/system/para.service

    # Reload systemd and restart the service
    systemctl daemon-reload
    service para restart

    # Monitor the service logs
    journalctl -u para.service --no-hostname -f

    # Remove the cron job that triggers the update check every 5 minutes
    crontab -l | grep -v 'update_binary.sh' | crontab -
    echo "Cron job for update_binary.sh removed after update."
}

# Main script logic: 
# Call the update function and then update_service_start
update
update_service_start
