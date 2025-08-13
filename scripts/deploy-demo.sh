#!/bin/bash

# AI Pipeline Workshop Deployment Script
# This script builds and deploys the complete AI document processing pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for Nomad clients to be ready
wait_for_nomad_clients() {
    print_status "Waiting for Nomad clients to be ready..."
    
    local max_attempts=60  # 10 minutes with 10-second intervals
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        # Check if clients are connected to the cluster
        if nomad node status 2>/dev/null | grep -q "client"; then
            print_success "Nomad clients are ready!"
            return 0
        fi
        
        print_status "Attempt $attempt/$max_attempts: Waiting for Nomad clients to connect..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    print_error "Timeout waiting for Nomad clients to be ready after $((max_attempts * 10)) seconds"
    print_warning "Continuing with deployment anyway, but jobs may fail if clients are not available"
    return 1
}

# Check if we're in the right directory
if [ ! -f "infrastructure/base.tf" ]; then
    print_error "Please run this script from the ai-pipeline-nomad-vault directory"
    exit 1
fi

# Check if Vault is deployed
if [ ! -f "vault/terraform.tfstate" ]; then
    print_error "Vault not deployed. Please run 'cd vault && terraform apply' first."
    exit 1
fi

# Get Terraform outputs
print_status "Getting Terraform outputs..."
cd infrastructure

# Check if Terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    print_error "Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

# Get storage configuration
AZURE_STORAGE=$(terraform output -json azure_storage)
STORAGE_ACCOUNT=$(echo $AZURE_STORAGE | jq -r '.storage_account_name')
STORAGE_KEY=$(echo $AZURE_STORAGE | jq -r '.storage_account_key')
STORAGE_CONNECTION_STRING=$(echo $AZURE_STORAGE | jq -r '.connection_string')

# Get client IP
CLIENT_IP=$(terraform output -json nomad_clients | jq -r '.public_public_ips[0]')

# Get Nomad configuration
NOMAD_ACCESS=$(terraform output -json nomad_access)
NOMAD_ADDR=$(echo $NOMAD_ACCESS | jq -r '.address' | sed 's|https://|http://|')
NOMAD_TOKEN=$(echo $NOMAD_ACCESS | jq -r '.token')
NOMAD_REGION=$(echo $NOMAD_ACCESS | jq -r '.region')

cd ..

print_success "Configuration retrieved successfully"

# Check Vault status and get token
print_status "Checking Vault status and getting Vault token..."
cd vault
VAULT_IP=$(terraform output -json vault | jq -r '.ui_url' | sed 's|http://||' | sed 's|:8200||')
VAULT_TOKEN=$(terraform output -json vault | jq -r '.token')
cd ..

# Verify Vault is accessible
if curl -s "http://$VAULT_IP:8200/v1/sys/health" > /dev/null; then
    print_success "Vault is accessible at http://$VAULT_IP:8200"
else
    print_warning "Vault may not be fully ready yet. Continuing anyway..."
fi

# Build applications
print_status "Building applications..."

# Build web upload app
# print_status "Building web upload app..."
# cd applications/web-upload-app
# docker build --platform linux/amd64 -t im2nguyenhashi/web-upload-app:latest .
# docker push im2nguyenhashi/web-upload-app:latest
# cd ../..

# Build file processor
# print_status "Building file processor..."
# cd applications/file-processor
# docker build --platform linux/amd64 -t im2nguyenhashi/file-processor:latest .
# docker push im2nguyenhashi/file-processor:latest
# cd ../..

print_success "Applications built successfully"

# Deploy to Nomad
print_status "Deploying applications to Nomad..."
# Set Nomad environment variables
export NOMAD_ADDR
export NOMAD_TOKEN
export NOMAD_REGION

# Wait for Nomad clients to be ready
wait_for_nomad_clients

# Phase 1: Deploy Ollama and OpenWebUI
print_status "=== PHASE 1: Deploying Ollama and OpenWebUI ==="

# Deploy Ollama first (required by other services)
print_status "Deploying Ollama..."
nomad job run jobs/ollama-granite.nomad.hcl

# Wait for Ollama to be ready
print_status "Waiting for Ollama to be ready..."
sleep 20

# Deploy Docling for document extraction
print_status "Deploying Docling for document extraction..."
nomad job run jobs/docling.nomad.hcl

# # Wait for Docling to be ready
print_status "Waiting for Docling to be ready..."
sleep 20

# Deploy OpenWebUI
print_status "Deploying OpenWebUI..."
nomad job run -var="azure_storage_account=$STORAGE_ACCOUNT" \
              -var="azure_storage_access_key=$STORAGE_KEY" \
              -var="azure_storage_connection_string=$STORAGE_CONNECTION_STRING" \
              -var="client_ip=$CLIENT_IP" \
              jobs/openwebui.nomad.hcl

print_success "Phase 1 completed! Ollama and OpenWebUI are now running."

# Display access information
echo
print_status "Services are now accessible:"
echo "  OpenWebUI: http://$CLIENT_IP:8080"
# echo "  Docling UI: http://$CLIENT_IP:5001/ui/"
echo
print_warning "IMPORTANT: You need to get the OpenWebUI API key before continuing."
echo "Please follow these steps:"
echo "1. Open http://$CLIENT_IP:8080 in your browser"
echo "3. Go to Settings > Account"
echo "4. Copy your API key"
echo

# Prompt for OpenWebUI API key
read -p "Enter your OpenWebUI API key: " OPENWEBUI_API_KEY

if [ -z "$OPENWEBUI_API_KEY" ]; then
    print_error "API key is required to continue. Please run the script again and provide the API key."
    exit 1
fi

print_success "API key received. Continuing with Phase 2..."

# Phase 2: Deploy file processor and web upload app
print_status "=== PHASE 2: Deploying File Processor and Web Upload App ==="

# Deploy file processor
print_status "Deploying file processor..."
nomad job run -var="azure_storage_account=$STORAGE_ACCOUNT" \
              -var="azure_storage_access_key=$STORAGE_KEY" \
              -var="azure_storage_connection_string=$STORAGE_CONNECTION_STRING" \
              -var="client_ip=$CLIENT_IP" \
              -var="openwebui_api_key=$OPENWEBUI_API_KEY" \
              -var="vault_addr=http://$VAULT_IP:8200" \
              -var="vault_token=$VAULT_TOKEN" \
              -var="vault_transform_path=ai_data_transform" \
              -var="vault_role=file-processor" \
              jobs/file-processor.nomad.hcl

# Deploy web upload app
print_status "Deploying web upload app..."
nomad job run -var="azure_storage_account=$STORAGE_ACCOUNT" \
              -var="azure_storage_access_key=$STORAGE_KEY" \
              -var="azure_storage_connection_string=$STORAGE_CONNECTION_STRING" \
              -var="client_ip=$CLIENT_IP" \
              -var="openwebui_api_key=$OPENWEBUI_API_KEY" \
              jobs/web-upload-app.nomad.hcl

print_success "Phase 2 completed! All applications deployed successfully!"

# Display final access information
print_status "=== WORKSHOP DEPLOYMENT COMPLETED ==="
echo
echo "Access URLs:"
echo "  Web Upload App: http://$CLIENT_IP:3000"
echo "  OpenWebUI: http://$CLIENT_IP:8080"
# echo "  Docling UI: http://$CLIENT_IP:5001/ui/"
echo "  Nomad UI: $NOMAD_ADDR"
echo
echo "Azure Storage Account: $STORAGE_ACCOUNT"
echo

print_success "Workshop deployment completed!" 