#!/bin/bash

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
        if ! test -f "./$file"; then
            echo "Update needed for $file (version: $version)"
            update_needed=true
        else
            echo "$file (version: $version) is already up-to-date."
        fi
    done
}

# Check for new files for the binary release
echo "Checking for binary release updates..."
check_update_needed "https://releases.quilibrium.com/release"

# Output whether an update is needed
if [ "$update_needed" = true ]; then
    echo "Update needed: yes"
    # Call the update script if update is needed
    ./update2.0.0.9.bash
else
    echo "Update needed: no"
fi
