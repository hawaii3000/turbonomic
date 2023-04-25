#!/bin/bash

base_url="https://download.vmturbo.com/appliance/download/updates"
log_file="version_check.log"
max_attempts=100
my_ip_address=$(hostname -I | awk '{print $1}')
turbonomic_url="https://${my_ip_address}/vmturbo/rest/admin/versions"

# Logging function
log() {
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp - $1" | tee -a "$log_file"
}

# Function to increment version number
increment_version() {
    local version=$1
    local arr=(${version//./ })
    arr[2]=$((arr[2] + 1))
    echo "${arr[0]}.${arr[1]}.${arr[2]}"
}

# Function to install jq if not present
install_jq() {
    if ! command -v jq > /dev/null; then
        log "jq not found. Starting installation."
        yum install -y epel-release
        yum install -y jq
        log "jq installation completed."
    else
        log "jq is already installed."
    fi
}

install_jq

# Get current version
current_version=$(curl -k "${turbonomic_url}" | jq -r '.version')
log "Current version: ${current_version}"

attempt=0
latest_version=""

while [ $attempt -lt $max_attempts ]; do
    current_version=$(increment_version "$current_version")
    download_url="${base_url}/${current_version}/onlineUpgrade.sh"
    
    # Check if onlineUpgrade.sh exists
    if curl -s --head "$download_url" | head -n 1 | grep "HTTP/1.[01] [23].."; then
        log "New version found: ${current_version}"
        latest_version="$current_version"
    else
        log "New version not found: ${current_version}"
        break
    fi

    attempt=$((attempt + 1))
done

if [ -n "$latest_version" ]; then
    download_url="${base_url}/${latest_version}/onlineUpgrade.sh"
    wget -O "onlineUpgrade-${latest_version}.sh" "$download_url"
    log "Download completed: onlineUpgrade-${latest_version}.sh"

    # Grant execution permission to the downloaded file
    chmod +x "onlineUpgrade-${latest_version}.sh"

    # Select "n" and execute
    echo "n" | ./onlineUpgrade-${latest_version}.sh "${latest_version}"
    log "onlineUpgrade-${latest_version}.sh executed."
else
    log "No new version found."
fi

