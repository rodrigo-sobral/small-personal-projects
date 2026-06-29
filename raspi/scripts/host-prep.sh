#!/usr/bin/env bash
# Optional: run this once on a brand-new Raspberry Pi before ./scripts/setup.sh
# if Docker isn't installed yet. Skip it if Docker's already set up.

set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
fi

sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker "$USER" || true

echo "Docker is installed and running. Log out and back in for group"
echo "membership to take effect, then run ./scripts/setup.sh"
