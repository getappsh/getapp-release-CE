#!/bin/bash
set -xe

# GitHub owner and repo
owner="getappsh"
repo="agent"

# Your GitHub personal access token (PAT)
GITHUB_TOKEN=${GITHUB_ACCESS_TOKEN}

# Version of the release to download (e.g., v0.1.15)
version=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/getappsh/agent/releases | grep -oP '"tag_name": "\K(.*)(?=")' | head -n 1)
# Get release information
release_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$owner/$repo/releases/tags/$version")

# Extract download URLs for agent.exe and MSI files
download_urls=$(echo "$release_info" | grep -oP '"browser_download_url": "\K[^"]+')

# Download each file
for url in $download_urls; do
    echo "Downloading from $url..."
    file_name=$(basename "$url")
    curl -L -H "Authorization: token $GITHUB_TOKEN" -o "$file_name" "$url"
done

echo "Download completed."

