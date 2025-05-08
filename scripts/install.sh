#!/bin/bash

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

REGISTRY_URL="harbor.company.com"
REGISTRY_USER="your_username"
REGISTRY_PASSWORD="your_password"
IMAGE_PREFIX=${IMAGE_PREFIX:-"getapp-f"}
NAMESPACE="getapp-dev"
RELEASE_NAME="getapp"
#------------------------------------------------------------------------------#

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

# Function to check if a command exists
check_command() {
    if ! command -v $1 &> /dev/null; then
        log $RED "Error: $1 is required but not installed."
        exit 1
    fi
}

# Source the .env file
if [ -f ".env" ]; then
    log $YELLOW "Loading environment variables from .env file..."
    source .env
else
    log $RED "Error: .env file not found"
    exit 1
fi

# Function to update Chart.yaml appVersion
update_chart_version() {
    local chart_file="helm-chart/Chart.yaml"
    
    if [ -z "$GETAPP_RELEASE_TAG" ]; then
        log $RED "Error: GETAPP_RELEASE_TAG is not set in .env file"
        exit 1
    }
    
    log $YELLOW "Updating appVersion in $chart_file to: $GETAPP_RELEASE_TAG"
    if [ -f "$chart_file" ]; then
        # Use sed to replace the appVersion line while preserving indentation
        sed -i "s|^appVersion:.*|appVersion: $GETAPP_RELEASE_TAG|" "$chart_file"
        if [ $? -eq 0 ]; then
            log $GREEN "Successfully updated appVersion in $chart_file"
        else
            log $RED "Failed to update appVersion in $chart_file"
            exit 1
        fi
    else
        log $RED "Chart file $chart_file not found"
        exit 1
    fi
}

# Function to update values.yaml repository
update_values_repository() {
    local values_file="helm-chart/values.yaml"
    local new_repository="$REGISTRY_URL/$IMAGE_PREFIX/"
    
    log $YELLOW "Updating repository in $values_file to: $new_repository"
    if [ -f "$values_file" ]; then
        # Use sed to replace the repository line while preserving indentation
        sed -i "s|^[[:space:]]*repository:.*|  repository: $new_repository|" "$values_file"
        if [ $? -eq 0 ]; then
            log $GREEN "Successfully updated repository in $values_file"
        else
            log $RED "Failed to update repository in $values_file"
            exit 1
        fi
    else
        log $RED "Values file $values_file not found"
        exit 1
    fi
}

# Function to update namespace in values.yaml
update_namespace() {
    log $YELLOW "Updating namespace in values.yaml..."
    sed -i "s/openshiftProjectName:.*/openshiftProjectName: $NAMESPACE/" helm-chart/values.yaml
}

# Check required commands
log $YELLOW "Checking prerequisites..."
check_command docker
check_command kubectl
check_command helm

# Update Chart.yaml with version from .env
update_chart_version

# Update namespace in values.yaml
update_namespace

# Update values.yaml with configured repository
update_values_repository

# Create namespace if it doesn't exist
log $YELLOW "Creating namespace $NAMESPACE..."
kubectl create namespace $NAMESPACE 2>/dev/null || true

# Create registry secret
log $YELLOW "Creating registry secret..."
kubectl create secret docker-registry registry-secret \
    --docker-server=$REGISTRY_URL \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_PASSWORD \
    --namespace=$NAMESPACE 2>/dev/null || \
kubectl patch secret registry-secret -n $NAMESPACE -p \
    '{"data":{".dockerconfigjson":"'$(echo -n "{\"auths\":{\"$REGISTRY_URL\":{\"username\":\"$REGISTRY_USER\",\"password\":\"$REGISTRY_PASSWORD\",\"auth\":\"$(echo -n "$REGISTRY_USER:$REGISTRY_PASSWORD" | base64)\"}}}" | base64)'"}}'

# Find the images zip file
IMAGES_ZIP=$(ls getapp-images-*.zip 2>/dev/null)
if [ -z "$IMAGES_ZIP" ]; then
    log $RED "Error: Images package (getapp-images-*.zip) not found in current directory"
    exit 1
fi

# Configure and run load-images script
log $YELLOW "Loading images to registry..."
cat > load-images-config.sh << EOF
ZIP_FILE="$IMAGES_ZIP"
REPOSITORY="$REGISTRY_URL"
DOCKER_USER="$REGISTRY_USER"
DOCKER_PASSWORD="$REGISTRY_PASSWORD"
EOF

source load-images-config.sh
chmod +x load-images.sh
./load-images.sh

# Find the Helm chart zip
CHART_ZIP=$(ls getapp-chart-*.zip 2>/dev/null)
if [ -z "$CHART_ZIP" ]; then
    log $RED "Error: Helm chart package (getapp-chart-*.zip) not found in current directory"
    exit 1
fi

# Extract Helm chart
log $YELLOW "Extracting Helm chart..."
unzip -q "$CHART_ZIP"

# Deploy using Helm
log $YELLOW "Deploying to Kubernetes..."
helm upgrade --install $RELEASE_NAME ./helm-chart \
    --namespace $NAMESPACE \
    --set imagePullSecrets[0].name=registry-secret \
    --set repository=$REGISTRY_URL \
    -f ./helm-chart/values.yaml

# Check deployment status
log $YELLOW "Checking deployment status..."
kubectl get pods -n $NAMESPACE

# Clean up
log $YELLOW "Cleaning up temporary files..."
rm -f load-images-config.sh
rm -rf helm-chart

log $GREEN "Installation completed!"
log $GREEN "To check the status of your deployment, run:"
log $GREEN "kubectl get pods -n $NAMESPACE"
