#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building web upload app Docker image...${NC}"

# Build the Docker image for linux/amd64 platform (Azure VMs)
docker build --platform linux/amd64 -t im2nguyenhashi/web-upload-app:latest .
# docker push im2nguyenhashi/web-upload-app:latest

echo -e "${GREEN}Docker image built successfully!${NC}"
echo -e "${BLUE}Image: im2nguyenhashi/web-upload-app:latest${NC}" 