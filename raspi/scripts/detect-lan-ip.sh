#!/usr/bin/env bash
# Detects this machine's real LAN-facing IP and writes it into .env as
# SERVER_LAN_IP. Run standalone any time (e.g. after moving the Pi to a new
# network) or let setup.sh call it automatically on every run.

set -euo pipefail
cd "$(dirname "$0")/.."

detect_lan_ip() {
  local ip=""

  # Ask the kernel which source IP it would use to reach the internet -
  # this reliably picks the real uplink (Wi-Fi/Ethernet), skipping Docker
  # bridges, which normally aren't in the default route at all.
  ip=$(ip route get 1.1.1.1 2>/dev/null | awk '{for (i=1;i<=NF;i++) if ($i=="src") {print $(i+1); exit}}') || true

  # Reject it if that route actually goes through Tailscale (CGNAT range
  # 100.64.0.0/10 - e.g. an exit node is active) or loopback; fall back
  # to scanning interfaces directly instead.
  if [[ -z "$ip" || "$ip" == 100.* || "$ip" == 127.* ]]; then
    ip=$(hostname -I 2>/dev/null | tr ' ' '\n' \
      | grep -Ev '^127\.|^100\.|^172\.1[7-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\.' \
      | head -1) || true
  fi

  echo "$ip"
}

DETECTED_IP="$(detect_lan_ip)"

if [[ -z "$DETECTED_IP" ]]; then
  echo "Couldn't auto-detect a LAN IP. Set SERVER_LAN_IP manually in .env." >&2
  exit 1
fi

echo "==> Detected LAN IP: $DETECTED_IP"

if [[ ! -f .env ]]; then
  echo "No .env found - copy .env.example to .env first." >&2
  exit 1
fi

if grep -q '^SERVER_LAN_IP=' .env; then
  sed -i "s/^SERVER_LAN_IP=.*/SERVER_LAN_IP=${DETECTED_IP}/" .env
else
  echo -e "\nSERVER_LAN_IP=${DETECTED_IP}" >> .env
fi

echo "==> .env updated (SERVER_LAN_IP=${DETECTED_IP})"
