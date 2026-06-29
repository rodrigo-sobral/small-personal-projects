#!/usr/bin/env bash
# One-shot setup: checks .env, generates the local CA + cert, brings the
# stack up, seeds Pi-hole's blocklists, and prints where everything lives.
#
# Usage:
#   ./scripts/setup.sh                 # core setup
#   ./scripts/setup.sh --with-firewall # also lock down the host with UFW
#
set -euo pipefail
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}======================================"
echo "Homelab stack setup"
echo -e "======================================${NC}"

# --- 0. Docker present? -----------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  echo -e "${RED}Docker isn't installed.${NC} Run ./scripts/host-prep.sh first,"
  echo "log out and back in (needed for docker group membership to apply),"
  echo "then re-run this script."
  exit 1
fi

# --- 1. .env check ---------------------------------------------------------
if [[ ! -f .env ]]; then
  echo -e "${RED}No .env found.${NC} Copy .env.example to .env, fill in every value,"
  echo "then re-run this script."
  exit 1
fi
echo -e "${GREEN}Step 1/5${NC} .env found"
set -a
# shellcheck disable=SC1091
source .env
set +a

# --- 2. detect this machine's current LAN IP --------------------------------
# Refreshes SERVER_LAN_IP in .env every run, so Pi-hole's Local DNS Records
# stay correct even if the Pi moves to a different network or gets a new
# DHCP lease - no manual editing needed.
echo -e "${GREEN}Step 2/5${NC} Detecting LAN IP"
./scripts/detect-lan-ip.sh
set -a
# shellcheck disable=SC1091
source .env
set +a

# --- 3. local CA + cert -----------------------------------------------------
echo -e "${GREEN}Step 3/5${NC} Generating local CA and TLS certificate"
DOMAIN_BASE="${DOMAIN_BASE:-home.arpa}" TAILSCALE_IP="${TAILSCALE_IP:-}" ./scripts/generate-ca.sh

# --- 4. bring the stack up ---------------------------------------------------
echo -e "${GREEN}Step 4/5${NC} Pulling images and starting containers"

# Pi-hole runs with network_mode: host, binding port 53 directly on the host.
# Raspberry Pi OS (and most Debian/Ubuntu) ships systemd-resolved, which
# usually already holds port 53 - Pi-hole will fail to start until it's freed.
if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet systemd-resolved 2>/dev/null; then
  if ss -tulnp 2>/dev/null | grep -q ':53 '; then
    echo -e "${YELLOW}systemd-resolved appears to be holding port 53.${NC}"
    echo "Pi-hole (network_mode: host) needs that port. Fix it with:"
    echo "  sudo sed -i 's/#\\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf"
    echo "  sudo rm -f /etc/resolv.conf"
    echo "  echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf"
    echo "  sudo systemctl restart systemd-resolved"
    echo "Then re-run this script."
    exit 1
  fi
fi

docker compose pull
docker compose up -d

# --- 5. seed Pi-hole ----------------------------------------------------------
echo -e "${GREEN}Step 5/5${NC} Seeding Pi-hole blocklists"
./scripts/pihole-setup.sh

# --- 6. summary ---------------------------------------------------------------
echo ""
echo -e "${GREEN}======================================"
echo "Setup complete"
echo -e "======================================${NC}"
echo ""
echo "Still to do by hand:"
echo "  1. Download and trust the root CA: https://portal.${DOMAIN_BASE}/cert/rootCA.pem"
echo "  2. Point your router/devices' DNS at Pi-hole (or let its DHCP take over)."
echo "     (Local DNS Records for every *.${DOMAIN_BASE} name are already set"
echo "     via SERVER_LAN_IP in .env - nothing to add by hand in the admin UI.)"
echo ""
echo "Access:"
echo "  Portal      https://portal.${DOMAIN_BASE}"
echo "  Vaultwarden https://vaultwarden.${DOMAIN_BASE}"
echo "  OctoPrint   https://octoprint.${DOMAIN_BASE}"
echo "  Pi-hole     https://pihole.${DOMAIN_BASE}/admin"
echo "  Nextcloud   https://nextcloud.${DOMAIN_BASE}"
echo "  Grafana     https://grafana.${DOMAIN_BASE}"
echo "  Status page https://status.${DOMAIN_BASE}"
echo "  Traefik     https://traefik.${DOMAIN_BASE}  (basic auth)"
echo "  Prometheus  https://prometheus.${DOMAIN_BASE}  (basic auth)"
echo ""
if [[ "${1:-}" == "--with-firewall" ]]; then
  echo -e "${YELLOW}Applying firewall rules (needs sudo)...${NC}"
  ./scripts/setup-firewall.sh
fi
