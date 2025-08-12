#!/bin/bash

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Building file processor Docker image...${NC}"

# Build the Docker image for linux/amd64 platform (Azure VMs)
docker build --platform linux/amd64 -t im2nguyenhashi/file-processor:latest .

echo -e "${GREEN}Docker image built successfully!${NC}"
echo -e "${BLUE}Image: im2nguyenhashi/file-processor:latest${NC}"
echo -e "${BLUE}To push to Docker Hub, run: docker push im2nguyenhashi/file-processor:latest${NC}"
