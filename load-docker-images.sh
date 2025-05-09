#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    local color="$1"
    shift
    echo -e "${color}${*}${NC}"
}

# Prerequisites:
# 1. Docker - Container runtime (https://docs.docker.com/get-docker/)
# 2. kubectl - Kubernetes command-line tool (https://kubernetes.io/docs/tasks/tools/)
# 3. helm - Kubernetes package manager (https://helm.sh/docs/intro/install/)
# 4. Access to container registry (harbor.company.com)
# 5. Valid registry credentials (username and password)
# 6. Access to a Kubernetes cluster (configured kubectl context)
#
# Environment variables required:
# - REGISTRY_URL (default: harbor.company.com)
# - REGISTRY_USER (your registry username)
# - REGISTRY_PASSWORD (your registry password)
# - NAMESPACE (default: default)

#------------------------------------------------------------------------------#
# Configuration - MUST BE SET BEFORE RUNNING THE SCRIPT!

# 1] Docker registry credentials
REGISTRY_URL="harbor.getapp.sh"
REGISTRY_USER='robot$test'
REGISTRY_PASSWORD="T2vciYC4k8I1UUiNv6sXUSmjCQ2g53SK"

# 2] the poject name in the image repository. 
# for example: in the image name "harbor.getapp.sh/getapp-fxample/api:1.1.1",  
# the project name is "getapp-fxample". you might need to create it a head of time. 
IMAGE_PREFIX="getapp-ci"

# 3] the namespace where the images will be loaded.

# 4] the zip file name of the images. Don't change it. it works fine as it is.
IMAGES_ZIP=$(find . -maxdepth 1 -name "getapp-images-*.zip" -print -quit)
#------------------------------------------------------------------------------#

# Validate zip file exists
if [ -z "$IMAGES_ZIP" ]; then
    log $RED "Error: No image package matching getapp-images-*.zip found"
    exit 1
fi

# Login to Docker registry
log $YELLOW "Logging into Docker registry $REGISTRY_URL..."
echo "$REGISTRY_PASSWORD" | docker login $REGISTRY_URL -u "$REGISTRY_USER" --password-stdin

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Extract images
log $YELLOW "Extracting images from $IMAGES_ZIP..."
unzip -q "$IMAGES_ZIP" -d "$TEMP_DIR"

# Find the extracted directory (should be something like getapp-DD-MM-YY)
IMAGES_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "getapp-*" | head -n1)

if [ -z "$IMAGES_DIR" ]; then
    log $RED "Error: Could not find extracted images directory"
    exit 1
fi

# Load and tag images
log $YELLOW "Loading and tagging images..."
total_images=$(find "$IMAGES_DIR" -maxdepth 1 -type f -name "*.tar" | wc -l)
log $YELLOW "Found $total_images images to process"

# Store image paths in an array
mapfile -t image_files < <(find "$IMAGES_DIR" -maxdepth 1 -type f -name "*.tar")

# Process each image
for ((i = 0; i < ${#image_files[@]}; i++)); do
    image_tar="${image_files[$i]}"
    count=$((i + 1))
    
    image_name=$(basename "$image_tar")
    log $YELLOW "[$count/$total_images] Processing image: $image_name"
    
    # Load image
    log $YELLOW "  → Loading image from $image_tar..."
    docker load -i "$image_tar"
    
    # Get the original image name and tag from docker images
    original_name=$(docker images --format "{{.Repository}}:{{.Tag}}" | head -n1)
    original_size=$(docker images --format "{{.Size}}" | head -n1)
    
    log $GREEN "  Loaded image: $original_name (Size: $original_size)"
    
    # Extract just the image name and tag, removing any registry prefix
    image_base_name=$(echo "$original_name" | sed -E 's|^.*getapp-dev/||' | sed -E 's|^.*/||')
    new_name="$REGISTRY_URL/$IMAGE_PREFIX/$image_base_name"
    
    # Tag and push
    log $YELLOW "  → Tagging as: $new_name"
    docker tag "$original_name" "$new_name"
    
    log $YELLOW "  → Pushing to registry..."
    docker push "$new_name"
    log $GREEN "  Successfully pushed: $new_name"
    
    # Clean up local images
    log $YELLOW "  → Cleaning up local images..."
    docker rmi "$original_name" "$new_name" > /dev/null 2>&1
    log $GREEN "  Cleaned up local images"
    
    log $GREEN "[$count/$total_images] Completed processing: $image_name"
    echo "----------------------------------------"
done

log $GREEN "\nSummary:"
log $GREEN "Processed $total_images images"
log $GREEN "All images have been successfully loaded and pushed to $REGISTRY_URL/$IMAGE_PREFIX/"
