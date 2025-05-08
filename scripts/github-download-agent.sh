#!/bin/bash
set -xe

# GitHub owner and repo
owner="getappsh"
repo="agent"

# Your GitHub personal access token (PAT)
GITHUB_TOKEN=${PAT_ACCESS_TOKEN}

# Get latest version
version=$(curl -s -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/repos/${owner}/${repo}/releases | grep -oP '"tag_name": "\K(.*)(?=")' | head -n 1)

# Get release assets information
assets_url="https://api.github.com/repos/${owner}/${repo}/releases/tags/${version}"
assets_info=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$assets_url")

# Extract asset IDs and names
while IFS= read -r line; do
    asset_id=$(echo "$line" | cut -d',' -f1)
    asset_name=$(echo "$line" | cut -d',' -f2)
    
    echo "Downloading ${asset_name}..."
    
    # Use the GitHub API to download the asset
    curl -L -H "Authorization: token $GITHUB_TOKEN" \
         -H "Accept: application/octet-stream" \
         "https://api.github.com/repos/${owner}/${repo}/releases/assets/${asset_id}" \
         --output "${asset_name}"
         
done < <(echo "$assets_info" | jq -r '.assets[] | "\(.id),\(.name)"')

echo "Download completed."