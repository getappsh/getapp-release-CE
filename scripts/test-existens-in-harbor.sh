#!/bin/bash

# Harbor base URL
HARBOR_BASE_URL="https://harbor.getapp.sh/api/v2.0"
PROJECT_NAME="getapp-dev"
# File containing list of image tags and repository names (in the format "tag:repo")
IMAGES_FILE="getapp-images-list.txt"

# Loop through each line in the file
while IFS= read -r line; do
    # Extract image tag and repository name from the line
    tag=$(echo "$line" | cut -d '/' -f 3 | cut -d ':' -f 2)
    repo=$(echo "$line" | cut -d '/' -f 3 | cut -d ':' -f 1)
    
    # Make GET request to check if image exists
    response=$(curl -sSL -o /dev/null -w "%{http_code}" "${HARBOR_BASE_URL}/projects/${PROJECT_NAME}/repositories/${repo}/artifacts/${tag}")
    
    # Check HTTP response code
    if [ "$response" -eq 200 ]; then
        echo "Image tag $tag in repository $repo exists"
    elif [ "$response" -eq 404 ]; then
        echo "Image tag $tag in repository $repo does not exist"
        exit 1
    else
        echo "Error: Unexpected HTTP response code $response for image tag $tag in repository $repo"
    fi
done < "$IMAGES_FILE"
