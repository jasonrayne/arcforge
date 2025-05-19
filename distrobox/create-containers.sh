#!/bin/bash

# Exit on any error
set -e

# Detect OS and machine type
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS_NAME=$ID
else
  OS_NAME=$(uname -s)
fi

HOSTNAME=$(hostname)

# Configure containers based on host machine
case "$HOSTNAME" in
workstation)
  CONTAINER_IMAGE="archlinux:latest"
  GPU_SUPPORT="--nvidia"
  ;;
personal-laptop)
  CONTAINER_IMAGE="archlinux:latest"
  # Check for NVIDIA GPU
  if command -v nvidia-smi &>/dev/null; then
    GPU_SUPPORT="--nvidia"
  else
    GPU_SUPPORT=""
  fi
  ;;
work-laptop)
  CONTAINER_IMAGE="archlinux:latest"
  GPU_SUPPORT=""
  ;;
*)
  CONTAINER_IMAGE="archlinux:latest"
  # Default GPU detection
  if command -v nvidia-smi &>/dev/null; then
    GPU_SUPPORT="--nvidia"
  else
    GPU_SUPPORT=""
  fi
  ;;
esac

# Create development container if it doesn't exist
if ! distrobox list | grep -q "dev"; then
  echo "Creating development container..."
  distrobox create --name dev --image $CONTAINER_IMAGE $GPU_SUPPORT

  # Wait for container to be ready
  sleep 2

  # Install packages inside the container
  echo "Setting up development container..."
  distrobox enter dev -- bash /run/host/$(pwd)/distrobox/setup-container.sh

  # Export applications from container
  echo "Exporting applications from container..."
  bash $(pwd)/distrobox/export-applications.sh
else
  echo "Development container already exists"
fi

echo "Container setup complete!"
