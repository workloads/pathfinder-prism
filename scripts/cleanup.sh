#!/bin/bash

# AI Pipeline Workshop Cleanup Script
# This script stops all workshop jobs and optionally destroys infrastructure

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

# Parse command line arguments
DESTROY_INFRASTRUCTURE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --destroy-infrastructure)
            DESTROY_INFRASTRUCTURE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo
            echo "Options:"
            echo "  --destroy-infrastructure    Also destroy the Azure infrastructure"
            echo "  -h, --help                  Show this help message"
            echo
            echo "By default, this script only stops Nomad jobs."
            echo "Use --destroy-infrastructure to also destroy Azure resources."
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Get Nomad address
print_status "Getting Nomad configuration..."
cd infrastructure
NOMAD_ADDR=$(terraform output -raw nomad_access.ui_url | sed 's|https://|http://|')
cd ..

export NOMAD_ADDR

# Stop Nomad jobs
print_status "Stopping Nomad jobs..."

# Stop workshop jobs
print_status "Stopping web upload app..."
nomad job stop -purge web-upload-app || print_warning "Web upload app was not running"

print_status "Stopping OpenWebUI..."
nomad job stop -purge openwebui || print_warning "OpenWebUI was not running"

print_status "Stopping file processor..."
nomad job stop -purge file-processor || print_warning "File processor was not running"

print_status "Stopping Ollama..."
nomad job stop -purge ollama || print_warning "Ollama was not running"

print_success "All workshop jobs stopped"

# Optional infrastructure destruction
if [ "$DESTROY_INFRASTRUCTURE" = true ]; then
    print_warning "Destroying Azure infrastructure..."
    echo "This will permanently delete all Azure resources including:"
    echo "- Virtual machines"
    echo "- Storage accounts"
    echo "- Network resources"
    echo "- Azure AD applications"
    echo
    
    read -p "Are you sure you want to continue? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        print_status "Infrastructure destruction cancelled"
        exit 0
    fi
    
    print_status "Destroying infrastructure..."
    cd infrastructure
    terraform destroy -auto-approve
    cd ..
    
    print_success "Infrastructure destroyed successfully"
else
    print_status "Infrastructure preserved. Use --destroy-infrastructure to destroy it."
fi

print_success "Cleanup completed!" 