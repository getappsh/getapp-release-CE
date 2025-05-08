# GetApp Deployment Guide

This repository contains the necessary files and scripts to deploy GetApp in various environments. Below you'll find detailed instructions for different deployment scenarios.

## Release Package Structure

The release package (`getapp-full-release-<version>.zip`) contains:
1. `getapp-images-<version>.zip` - Contains all Docker images as tar files
2. `getapp-chart-<version>.zip` - Contains Helm charts and Docker Compose files for deployment
3. `getapp-agent-<version>.zip` - Contains the GetApp agent files

## Deployment Steps

### 1. Upload Images to Your Registry

1. Configure the image upload script:
   Edit `scripts/load-images.sh` and set the following variables at the top of the file:
   ```bash
   ZIP_FILE="getapp-images-<version>.zip"    # Name of your images zip file
   REPOSITORY="your.docker.repository.com"    # Your registry hostname (e.g., harbor.company.com)
   DOCKER_USER="your_docker_username"         # Registry username
   DOCKER_PASSWORD="your_docker_password"     # Registry password
   ```

2. Make the script executable and run it:
   ```bash
   chmod +x scripts/load-images.sh
   ./scripts/load-images.sh
   ```

   The script will automatically:
   - Unzip the images package to a temporary directory
   - Load each Docker image from the tar files
   - Tag each image with your registry name
   - Log in to your registry
   - Push the images to your registry
   - Clean up temporary files and images

   > Note: Make sure you have enough disk space available, as the script needs to temporarily extract the images.

### 2. Deploy Using Helm (Kubernetes/OpenShift)

1. Extract the Helm chart package:
   ```bash
   unzip getapp-chart-<version>.zip
   ```

2. Configure the deployment:
   Edit `helm-chart/values.yaml` with your environment-specific settings:

   - **SSO Configuration**
     ```yaml
     auth:
       serverUrl: "<AUTH_SERVER_URL>"
       realm: "<REALM>"
       clientId: "<CLIENT_ID>"
       secretKey: "<SECRET_KEY>"
       cookieKey: "<COOKIE_KEY>"
     ```

   - **Kafka Settings**
     ```yaml
     kafka:
       brokerUrl: "<KAFKA_BROKER_URL>"
       noPartitionerWarning: "1"
     ```

   - **Database Configuration**
     ```yaml
     postgres:
       host: "<POSTGRES_HOST>"
       port: "<POSTGRES_PORT>"
       user: "<POSTGRES_USER>"
       password: "<POSTGRES_PASSWORD>"
       database: "<POSTGRES_DB>"
     ```

3. Deploy using Helm:
   ```bash
   helm upgrade -n <NAMESPACE> -i <RELEASE_NAME> \
     -f ./helm-chart/values.yaml ./helm-chart
   ```

### 3. Alternative: Deploy Using Docker Compose

1. Navigate to the docker-compose directory:
   ```bash
   cd docker-compose
   ```

2. Configure environment variables in `.env`

3. Start the services:
   ```bash
   docker-compose up -d
   ```

## Quick Start: One-Click Installation

For a streamlined installation process, use our one-click installation script included in the release package:

1. Extract the release package:
   ```bash
   unzip getapp-full-release-<version>.zip
   cd getapp-full-release-<version>
   ```

2. Make the installation script executable and run it:
   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. The script will prompt you for:
   - Registry URL, username, and password
   - Kubernetes namespace
   - Release name

The script will automatically:
- Create or update the Kubernetes namespace
- Configure registry credentials
- Load and push all images to your registry
- Deploy the application using Helm
- Clean up temporary files

> Note: Make sure you have the following prerequisites installed:
> - Docker CLI
> - kubectl (configured with access to your cluster)
> - Helm 3.x

## Prerequisites

- Docker CLI installed and configured
- Access to a container registry (Harbor, Docker Hub, etc.)
- For Kubernetes/OpenShift deployment:
  - Strimzi Operator for Kafka
  - Crunchy Data Operator for PostgreSQL
  - Helm 3.x
  - Kubernetes 1.20+ or OpenShift 4.x

## Important Notes

### OpenShift vs Standard Kubernetes
- The default configuration uses OpenShift Routes for service exposure
- For standard Kubernetes:
  1. Enable Ingress in values.yaml
  2. Configure your Ingress controller
  3. Update service type if needed

### Troubleshooting

1. **Image Upload Issues**
   - Verify registry credentials and permissions
   - Check network connectivity to registry
   - Ensure registry URL is correct
   - Verify disk space for image extraction

2. **Deployment Issues**
   - Verify all images were uploaded successfully
   - Check pod events for image pull errors
   - Verify registry credentials in Kubernetes secrets

## Version Compatibility

| Component | Minimum Version | Recommended Version |
|-----------|----------------|-------------------|
| Kubernetes | 1.20          | 1.24+            |
| OpenShift  | 4.6           | 4.12+            |
| Helm       | 3.0           | 3.8+             |
| Docker     | 20.10         | 23.0+            |

For additional support or questions, please contact the development team.
