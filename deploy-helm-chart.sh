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
    local color=$1
    shift
    echo -e "${color}$@${NC}"
}

# Configuration
REGISTRY_URL="harbor.getapp.sh"
REGISTRY_USER='robot$test'
REGISTRY_PASSWORD="T2vciYC4k8I1UUiNv6sXUSmjCQ2g53SK"
IMAGE_PREFIX="getapp-ci"
NAMESPACE="getapp-ci"
RELEASE_NAME="getapp-ci"
CHART_ZIP=$(ls getapp-chart-*.zip 2>/dev/null)

# Kubernetes configuration
K8S_SERVER="https://api.sr.eastus.aroapp.io:6443"
K8S_TOKEN="sha256~SB94fRADLL91HVdAloc3QdUSrdBlHyPTn7S49Q1grm4"

# Check prerequisites
log $YELLOW "Checking prerequisites..."
for cmd in kubectl helm docker; do
    if ! command -v $cmd &> /dev/null; then
        log $RED "Error: $cmd is required but not installed."
        exit 1
    fi
done

# Login to Kubernetes cluster
log $YELLOW "Logging into Kubernetes cluster..."
kubectl config set-credentials cluster-admin --token="$K8S_TOKEN"
kubectl config set-cluster getapp-cluster --server="$K8S_SERVER" --insecure-skip-tls-verify=true
kubectl config set-context getapp-context --cluster=getapp-cluster --user=cluster-admin
kubectl config use-context getapp-context

# Verify connection
log $YELLOW "Verifying Kubernetes connection..."
if ! kubectl get nodes &>/dev/null; then
    log $RED "Error: Failed to connect to Kubernetes cluster"
    exit 1
fi
log $GREEN "Successfully connected to Kubernetes cluster"

# Check if chart zip exists
if [ -z "$CHART_ZIP" ]; then
    log $RED "Error: Helm chart package (getapp-chart-*.zip) not found"
    exit 1
fi

log $YELLOW "Found chart file: $CHART_ZIP"

# Create temporary directory for extraction
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Remove existing helm-chart directory if it exists
rm -rf helm-chart

# Extract Helm chart
log $YELLOW "Extracting Helm chart..."
unzip -o "$CHART_ZIP"

# Verify helm-chart directory exists
if [ ! -d "helm-chart" ]; then
    log $RED "Error: helm-chart directory not found after extraction"
    exit 1
fi

# Login to Docker registry
log $YELLOW "Logging into Docker registry $REGISTRY_URL..."
echo "$REGISTRY_PASSWORD" | docker login $REGISTRY_URL -u "$REGISTRY_USER" --password-stdin

# Create namespace if it doesn't exist
log $YELLOW "Creating namespace $NAMESPACE if it doesn't exist..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Create registry secret
log $YELLOW "Creating/updating registry secret..."
kubectl create secret docker-registry registry-secret \
    --docker-server=$REGISTRY_URL \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_PASSWORD \
    --namespace=$NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -

# Update values.yaml with correct repository
log $YELLOW "Updating repository in values.yaml..."
sed -i "s|repository:.*|repository: $REGISTRY_URL/$IMAGE_PREFIX/|" helm-chart/values.yaml

# Update all instances of getapp-f to getapp-ci in values.yaml
log $YELLOW "Updating namespace values in values.yaml..."
sed -i "s/getapp-f/getapp-ci/g" helm-chart/values.yaml

# Deploy using Helm
log $YELLOW "Deploying Helm chart..."
helm upgrade --install $RELEASE_NAME ./helm-chart \
    --namespace $NAMESPACE \
    --set imagePullSecrets[0].name=registry-secret \
    --set repository=$REGISTRY_URL/$IMAGE_PREFIX \
    -f ./helm-chart/values.yaml

# Check deployment status
log $YELLOW "Checking deployment status..."
kubectl get pods -n $NAMESPACE

log $GREEN "Deployment completed!"
log $GREEN "To check the status of your deployment, run:"
log $GREEN "kubectl get pods -n $NAMESPACE"
