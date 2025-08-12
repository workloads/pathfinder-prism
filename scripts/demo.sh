#!/bin/bash

# AI Pipeline Workshop Demo Script
# This script demonstrates the complete AI document processing workflow

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

# Check if we're in the right directory
if [ ! -f "infrastructure/base.tf" ]; then
    print_error "Please run this script from the ai-pipeline-nomad-vault directory"
    exit 1
fi

# Get configuration from Terraform
print_status "Getting configuration..."
cd infrastructure

# Get client IP and storage info
CLIENT_IP=$(terraform output -raw nomad_clients.public_public_ips | head -n1)
STORAGE_ACCOUNT=$(terraform output -raw azure_storage.storage_account_name)

cd ..

print_success "Configuration retrieved"

# Demo workflow
echo
print_status "=== AI Pipeline Workshop Demo ==="
echo
print_status "This demo will show you the complete AI document processing workflow:"
echo "1. Upload documents via web interface"
echo "2. Automatic document processing with DocLings"
echo "3. Knowledge base integration with OpenWebUI"
echo "4. AI-powered document Q&A"
echo

# Check if services are running
print_status "Checking service status..."

# Check Nomad jobs
NOMAD_ADDR=$(cd infrastructure && terraform output -raw nomad_access.ui_url | sed 's|https://|http://|')
export NOMAD_ADDR

if ! nomad job status web-upload-app > /dev/null 2>&1; then
    print_error "Web upload app is not running. Please run deploy-workshop.sh first."
    exit 1
fi

if ! nomad job status openwebui > /dev/null 2>&1; then
    print_error "OpenWebUI is not running. Please run deploy-workshop.sh first."
    exit 1
fi

if ! nomad job status file-processor > /dev/null 2>&1; then
    print_error "File processor is not running. Please run deploy-workshop.sh first."
    exit 1
fi

if ! nomad job status ollama > /dev/null 2>&1; then
    print_error "Ollama is not running. Please run deploy-workshop.sh first."
    exit 1
fi

print_success "All services are running!"

# Display access information
echo
print_status "=== Access Information ==="
echo
echo "Web Upload App: http://$CLIENT_IP:3000"
echo "OpenWebUI: http://$CLIENT_IP:8080"
echo "Nomad UI: $NOMAD_ADDR"
echo "Azure Storage Account: $STORAGE_ACCOUNT"
echo

# Demo steps
print_status "=== Demo Steps ==="
echo
echo "1. Open the Web Upload App in your browser:"
echo "   http://$CLIENT_IP:3000"
echo
echo "2. Upload a document (PDF, TXT, MD, or DOCX)"
echo
echo "3. Monitor the processing in Nomad UI:"
echo "   $NOMAD_ADDR"
echo
echo "4. Check the processed document in Azure Blob Storage:"
echo "   Container: processed"
echo
echo "5. Open OpenWebUI to interact with the knowledge base:"
echo "   http://$CLIENT_IP:8080"
echo
echo "6. Ask questions about your uploaded documents!"
echo

# Sample content for testing
print_status "=== Sample Content ==="
echo
echo "You can use these sample documents for testing:"
echo "- PDF files with technical documentation"
echo "- Markdown files with API references"
echo "- Text files with setup instructions"
echo "- Word documents with project documentation"
echo

# Monitoring commands
print_status "=== Monitoring Commands ==="
echo
echo "Check job status:"
echo "  nomad job status"
echo
echo "View job logs:"
echo "  nomad alloc logs <allocation-id>"
echo
echo "Monitor file processor:"
echo "  nomad alloc logs -f -job file-processor"
echo
echo "Check Azure storage:"
echo "  az storage blob list --account-name $STORAGE_ACCOUNT --container-name uploads"
echo "  az storage blob list --account-name $STORAGE_ACCOUNT --container-name processed"
echo

print_success "Demo setup complete! Follow the steps above to test the AI pipeline." 