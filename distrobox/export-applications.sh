#!/bin/bash

set -e

# Applications to export from the container to the host
APPLICATIONS=(
  "neovim"
  "code-oss"
  "tmux"
)

# Export each application
for app in "${APPLICATIONS[@]}"; do
  if distrobox enter dev -- which $app &>/dev/null; then
    echo "Exporting $app from container..."
    distrobox-export --app $app 2>/dev/null || true
  else
    echo "$app not found in container, skipping export"
  fi
done

echo "Application export complete!"
