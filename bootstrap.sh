#!/bin/bash

set -e

# Display step information
step() {
  echo "==== $1 ===="
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  echo "Please don't run this script as root"
  exit 1
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Initialize submodules if they exist
if [ -f .gitmodules ]; then
  step "Initializing git submodules"
  git submodule update --init --recursive
fi

# Install required dependencies
step "Installing dependencies"
if command -v pacman &>/dev/null; then
  sudo pacman -Syu --noconfirm
  sudo pacman -S --needed --noconfirm ansible git curl python python-pip
elif command -v apt &>/dev/null; then
  sudo apt update
  sudo apt install -y ansible git curl python3 python3-pip
fi

# Install distrobox if not already installed
if ! command -v distrobox &>/dev/null; then
  step "Installing Distrobox"
  curl -s https://raw.githubusercontent.com/89luca89/distrobox/main/install | sudo sh
fi

# Run Ansible for system configuration
step "Configuring system with Ansible"
ansible-playbook ansible/playbooks/site.yml --limit $(hostname)

# Set up Distrobox containers
step "Setting up development containers"
bash distrobox/create-containers.sh

# Set up Chezmoi if dotfiles submodule exists
if [ -d dotfiles ]; then
  step "Setting up dotfiles with Chezmoi"
  if ! command -v chezmoi &>/dev/null; then
    if command -v pacman &>/dev/null; then
      sudo pacman -S --noconfirm chezmoi
    elif command -v apt &>/dev/null; then
      sudo apt install -y chezmoi || {
        sh -c "$(curl -fsLS get.chezmoi.io)" -- -b $HOME/.local/bin
        export PATH="$HOME/.local/bin:$PATH"
      }
    fi
  fi

  if [ ! -d ~/.local/share/chezmoi ]; then
    chezmoi init --source="$SCRIPT_DIR/dotfiles"
    chezmoi apply
  else
    chezmoi update
  fi
fi

step "Setup complete!"
echo "You may now restart your shell or log out and back in."
