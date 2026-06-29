#!/usr/bin/env bash
# Locks the host down with UFW. Optional - the stack works without this if
# you're relying on your router's firewall instead, but defense in depth is
# cheap. Needs sudo.
#
# NOTE ON A FIX: an earlier version of this script (outside this repo) set
# `ufw default allow incoming` before adding specific allow rules - that
# leaves every port open by default and makes the allow rules decorative.
# This version defaults to deny-incoming and allows only what's needed.

set -euo pipefail

: "${LOCAL_SUBNET:?Set LOCAL_SUBNET in .env, e.g. 192.168.1.0/24}"

echo "Resetting UFW to a known state..."
sudo ufw --force reset

echo "Default deny incoming, allow outgoing..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

echo "Allowing SSH only from the local subnet (${LOCAL_SUBNET})..."
sudo ufw allow from "$LOCAL_SUBNET" to any port 22 proto tcp

echo "Allowing Traefik's HTTP/HTTPS entrypoints from the local subnet..."
sudo ufw allow from "$LOCAL_SUBNET" to any port 80 proto tcp
sudo ufw allow from "$LOCAL_SUBNET" to any port 443 proto tcp

echo "Allowing Pi-hole's DNS/DHCP/NTP from the local subnet (host-networked,"
echo "so unlike Traefik these bind directly on the host and need explicit rules)..."
sudo ufw allow from "$LOCAL_SUBNET" to any port 53 proto tcp
sudo ufw allow from "$LOCAL_SUBNET" to any port 53 proto udp
sudo ufw allow from "$LOCAL_SUBNET" to any port 67 proto udp
sudo ufw allow from "$LOCAL_SUBNET" to any port 123 proto udp

echo "Allowing Tailscale (full access over the tailnet interface)..."
sudo ufw allow in on tailscale0
sudo ufw allow out on tailscale0
# Tailscale needs its own UDP port reachable to establish connections
sudo ufw allow 41641/udp

sudo ufw --force enable
sudo ufw status verbose
