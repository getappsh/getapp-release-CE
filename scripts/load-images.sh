#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Use variables from install.sh
if [ -z "$ZIP_FILE" ]; then
    log $RED "Error: ZIP_FILE is not set"
    exit 1
fi

REPOSITORY=$REGISTRY_URL
DOCKER_USER=$REGISTRY_USER
DOCKER_PASSWORD=$REGISTRY_PASSWORD

# Validate required variables
if [ -z "$REPOSITORY" ] || [ -z "$DOCKER_USER" ] || [ -z "$DOCKER_PASSWORD" ] || [ -z "$IMAGE_PREFIX" ]; then
    log $RED "Error: REGISTRY_URL, REGISTRY_USER, REGISTRY_PASSWORD, and IMAGE_PREFIX must be set"
    exit 1
fi

# Extract date from ZIP filename
DATE=$(echo "$ZIP_FILE" | grep -o "[0-9]\{2\}-[0-9]\{2\}-[0-9]\{2\}")
if [ -z "$DATE" ]; then
    log $RED "Error: Could not extract date from ZIP_FILE name. Expected format: getapp-DD-MM-YY.zip"
    exit 1
fi

EXTRACT_DIR="getapp-$DATE"

# Unzip the file if not already unzipped
if [ ! -d "$EXTRACT_DIR" ]; then
    log $YELLOW "Extracting $ZIP_FILE..."
    if ! unzip "$ZIP_FILE"; then
        log $RED "Error: Failed to unzip $ZIP_FILE"
        exit 1
    fi
fi

# Login to docker registry
log $YELLOW "Logging into docker registry $REPOSITORY..."
if ! echo "$DOCKER_PASSWORD" | docker login $REPOSITORY -u $DOCKER_USER --password-stdin; then
    log $RED "Error: Failed to login to docker registry"
    rm -rf "$EXTRACT_DIR"
    exit 1
fi

log $YELLOW "Using image prefix: $IMAGE_PREFIX"

# Load and push each tar file
for tar_file in $EXTRACT_DIR/*.tar; do
    log $YELLOW "Loading image from $tar_file..."
    if ! docker load -i "$tar_file"; then
        log $RED "Error: Failed to load image from $tar_file"
        continue
    fi
    
    # Get the image name from the tar filename (reverse the tr / _ transformation)
    base_image_name=$(basename "$tar_file" .tar | tr _ /)
    # Extract the part after getapp-dev/ (or any other prefix)
    image_suffix=$(echo "$base_image_name" | sed "s|^[^/]*/||")
    # Construct new image name with the desired prefix
    image_name="$IMAGE_PREFIX/$image_suffix"
    
    # Tag and push the image
    log $YELLOW "Tagging and pushing $image_name to $REPOSITORY..."
    if ! docker tag "$base_image_name" "$REPOSITORY/$image_name"; then
        log $RED "Error: Failed to tag $image_name"
        continue
    fi
    
    if ! docker push "$REPOSITORY/$image_name"; then
        log $RED "Error: Failed to push $REPOSITORY/$image_name"
        continue
    fi
    
    # Clean up docker images after successful push
    log $YELLOW "Cleaning up docker images..."
    docker rmi "$base_image_name" "$REPOSITORY/$image_name" || true
    log $GREEN "Successfully processed $image_name"
done

# Cleanup extracted files
log $YELLOW "Cleaning up..."
rm -rf "$EXTRACT_DIR"

log $GREEN "All images have been processed!"
