#!/bin/bash

# This script runs inside the container to set up the development environment

set -e

# Detect package manager
if command -v pacman &>/dev/null; then
  # Arch Linux
  echo "Setting up Arch Linux container..."
  sudo pacman -Syu --noconfirm
  sudo pacman -S --noconfirm \
    base-devel \
    git \
    neovim \
    tmux \
    zsh \
    python \
    python-pip \
    nodejs \
    npm \
    go \
    rust \
    ripgrep \
    fd \
    fzf \
    bat \
    exa \
    htop \
    tree \
    jq \
    wget \
    curl
elif command -v apt &>/dev/null; then
  # Debian/Ubuntu
  echo "Setting up Debian/Ubuntu container..."
  sudo apt update
  sudo apt install -y \
    build-essential \
    git \
    neovim \
    tmux \
    zsh \
    python3 \
    python3-pip \
    nodejs \
    npm \
    golang \
    rustc \
    ripgrep \
    fd-find \
    fzf \
    bat \
    exa \
    htop \
    tree \
    jq \
    wget \
    curl
fi

# Set up font access
mkdir -p ~/.local/share/fonts
if [ -d /run/host/home/$(whoami)/.local/share/fonts/JetBrainsMono ]; then
  echo "Importing JetBrainsMono Nerd Font from host..."
  cp -r /run/host/home/$(whoami)/.local/share/fonts/JetBrainsMono ~/.local/share/fonts/
  fc-cache -fv
fi

echo "Container setup complete!"
