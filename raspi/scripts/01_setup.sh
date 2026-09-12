#!/usr/bin/env bash
# One-shot setup: checks .env, generates the local CA + cert, brings the
# stack up, seeds Pi-hole's blocklists, and prints where everything lives.
#
# Usage:
#   ./scripts/01_setup.sh                 # core setup
#   ./scripts/01_setup.sh --with-firewall # also lock down the host with UFW
#
# Script layout / naming convention:
#   The number is the execution order. 00_ runs *before* this file; 01 is this
#   orchestrator; 02_, 03_, ... run from here in numeric order. To add a setup
#   step, take the next number and call it from below.
#   Anything that runs on its own, outside this script (host tuning, cert
#   renewal), lives in scripts/maintenance/ with no number - so the setup
#   numbering never runs out.
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
  echo -e "${RED}Docker isn't installed.${NC} Run ./scripts/00_host-prep.sh first, log out and back in (needed for docker group membership to apply), then re-run this script."
  exit 1
fi

# --- 1. .env check ---------------------------------------------------------
if [[ ! -f .env ]]; then
  echo -e "${RED}No .env found.${NC} Copy .env.example to .env, fill in every value, then re-run this script."
  exit 1
fi
echo -e "${GREEN}Step 1/9${NC} .env found"

# --- 2. detect this machine's current LAN IP --------------------------------
# Refreshes SERVER_LAN_IP in .env every run, so Pi-hole's Local DNS Records
# stay correct even if the Pi moves to a different network or gets a new
# DHCP lease - no manual editing needed.
echo -e "${GREEN}Step 2/9${NC} Detecting LAN IP"
./scripts/02_setup-lan-ip.sh
set -a
# shellcheck disable=SC1091
source .env
set +a

# scripts/03_setup-beszel.sh may rotate the hub key/token below. Capture the
# current values so step 7 can force-recreate the hub when they change: a plain
# `docker compose up -d` recreates the agent (its env changed) but leaves the
# hub holding the old private key, which breaks the SSH signature handshake.
BESZEL_KEY_BEFORE="${BESZEL_KEY:-}"
BESZEL_TOKEN_BEFORE="${BESZEL_TOKEN:-}"

# --- 3. media directories ---------------------------------------------------
# Immich's library and Jellyfin's media are host bind mounts, not docker
# volumes (they're the two things you'll want on a real path you can back up
# or move to an external disk). Docker would create them as root-owned
# directories on first `up`; creating them here means they exist with sane
# ownership and a missing path fails loudly now rather than mid-boot.
echo -e "${GREEN}Step 3/9${NC} Preparing media directories"
for dir in "${IMMICH_UPLOAD_LOCATION:-}" "${JELLYFIN_MEDIA_PATH:-}"; do
  [[ -z "$dir" ]] && continue
  if [[ ! -d "$dir" ]]; then
    echo "  creating $dir"
    sudo mkdir -p "$dir"
    sudo chown "$(id -u):$(id -g)" "$dir"
  else
    echo "  $dir exists"
  fi
done

# --- 4. pre-configure Beszel ------------------------------------------------
# Generates the hub's SSH key, a registration token and the declared system,
# writing the agent's half back into .env. Doing this *before* the first
# `docker compose up` is what removes every manual step from Beszel's setup.
echo -e "${GREEN}Step 4/9${NC} Pre-configuring Beszel"
./scripts/03_setup-beszel.sh

# --- 5. pre-configure Authentik ---------------------------------------------
# Generates the OIDC client ID/secret pairs the blueprint reads from .env.
echo -e "${GREEN}Step 5/9${NC} Pre-configuring Authentik SSO credentials"
./scripts/04_setup-authentik.sh

# Re-read .env: the two scripts above just added values the compose file needs.
set -a
# shellcheck disable=SC1091
source .env
set +a

# Did scripts/03_setup-beszel.sh rotate the key or token? If so the hub must be
# recreated in step 7 so it reloads the private key and re-syncs config.yml.
BESZEL_CHANGED=0
if [[ "${BESZEL_KEY:-}" != "$BESZEL_KEY_BEFORE" || "${BESZEL_TOKEN:-}" != "$BESZEL_TOKEN_BEFORE" ]]; then
  BESZEL_CHANGED=1
fi

# --- 6. local CA + cert -----------------------------------------------------
echo -e "${GREEN}Step 6/9${NC} Generating local CA and TLS certificate"
DOMAIN_BASE="${DOMAIN_BASE:-home.arpa}" TAILSCALE_IP="${TAILSCALE_IP:-}" ./scripts/05_setup-ca.sh

# --- 7. bring the stack up ---------------------------------------------------
echo -e "${GREEN}Step 7/9${NC} Pulling images and starting containers"

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

# The hub holds its private key in memory: recreate it (and the agent) whenever
# step 4 changed the key/token, or the two ends desync and the agent logs
# "invalid signature - check KEY value".
if [[ "$BESZEL_CHANGED" == 1 ]]; then
  echo "  Beszel key/token changed - recreating the hub + agent so they stay in sync"
  docker compose up -d --force-recreate beszel beszel-agent
fi

# --- 8. seed Pi-hole ----------------------------------------------------------
echo -e "${GREEN}Step 8/9${NC} Seeding Pi-hole blocklists"
./scripts/06_setup-pihole.sh

# --- 9. prepare the AI assistant ---------------------------------------------
# Generates Open WebUI's session secret and pulls the configured Ollama model,
# so the first visit to the chat works. The model download is the slow part.
echo -e "${GREEN}Step 9/9${NC} Preparing the AI assistant (pulling the Ollama model)"
./scripts/07_setup-ai.sh

# --- 10. summary --------------------------------------------------------------
echo ""
echo -e "${GREEN}======================================"
echo "Setup complete"
echo -e "======================================${NC}"
echo ""
echo "Still to do by hand (all of it is also listed on Glance's Setup page):"
echo "  1. Download and trust the root CA:"
echo "     https://glance.${DOMAIN_BASE}/assets/rootCA.pem"
echo "  2. Point your router/devices' DNS at Pi-hole (or let its DHCP take over)."
echo "     (Local DNS Records for every *.${DOMAIN_BASE} name are already set"
echo "     via SERVER_LAN_IP in .env - nothing to add by hand in the admin UI.)"
echo "  3. Create the Authentik admin account (one-time link, expires):"
echo "     https://auth.${DOMAIN_BASE}/if/flow/initial-setup/"
echo "     This is the single login for Glance, Stirling PDF and Traefik."
echo "  4. Create your Beszel account at https://beszel.${DOMAIN_BASE} - the"
echo "     system, its token and the hub key are already seeded, so there is"
echo "     nothing to copy. Restart it once afterwards to attach the system:"
echo "     docker compose restart beszel"
echo "  5. Add media libraries in Jellyfin (pointing at /media) and start an"
echo "     upload in Immich. Turn off Immich's Settings -> Machine Learning;"
echo "     that container isn't deployed."
  echo "  6. Optional: finish the OIDC integrations (Immich, Nextcloud, Jellyfin,"
  echo "     Beszel) using the credentials in .env - see the README's SSO table."
  echo "  7. Open https://ai.${DOMAIN_BASE} and sign in with Authentik. The first"
  echo "     account to do so becomes Open WebUI's admin (the model is already"
  echo "     pulled)."
echo ""
echo "Access:"
echo "  Glance      https://glance.${DOMAIN_BASE}  (also on https://${DOMAIN_BASE})"
echo "  Beszel      https://beszel.${DOMAIN_BASE}"
echo "  Vaultwarden https://vaultwarden.${DOMAIN_BASE}"
echo "  OctoPrint   https://octoprint.${DOMAIN_BASE}"
echo "  Pi-hole     https://pihole.${DOMAIN_BASE}/admin"
echo "  Nextcloud   https://nextcloud.${DOMAIN_BASE}"
echo "  Immich      https://immich.${DOMAIN_BASE}"
echo "  Jellyfin    https://jellyfin.${DOMAIN_BASE}"
echo "  AI          https://ai.${DOMAIN_BASE}  (local LLM chat)"
echo "  Stirling    https://pdf.${DOMAIN_BASE}"
echo "  ONLYOFFICE  https://office.${DOMAIN_BASE}  (editor backend for Nextcloud)"
echo "  Authentik   https://auth.${DOMAIN_BASE}"
echo "  Traefik     https://traefik.${DOMAIN_BASE}  (basic auth)"
echo "  Minecraft   minecraft.${DOMAIN_BASE}:25565  (not HTTP - no Traefik)"
echo ""

if [[ "${1:-}" == "--with-firewall" ]]; then
  echo -e "${YELLOW}Applying firewall rules (needs sudo)...${NC}"
  ./scripts/08_setup-firewall.sh
fi
