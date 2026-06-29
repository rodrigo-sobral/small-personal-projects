#!/usr/bin/env bash
# Run once after `docker compose up -d pihole` to seed default blocklists
# and pull gravity (the actual block database). Without this, a fresh
# Pi-hole has zero adlists and won't block anything.
#
# Pi-hole v6 dropped the old `pihole -a adlist add` CLI syntax entirely, so
# this goes through the REST API instead (authenticate, then POST each list).
# Runs curl from inside the container so it works regardless of the host's
# networking/DNS state.

set -euo pipefail

CONTAINER="pihole"
PIHOLE_PASSWORD="${PIHOLE_PASSWORD:?Set PIHOLE_PASSWORD in .env (source it first: set -a; source .env; set +a)}"

LISTS=(
  "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts"
  "https://big.oisd.nl"
)

echo "==> Waiting for Pi-hole to be healthy..."
until docker exec "$CONTAINER" pihole status >/dev/null 2>&1; do
  sleep 2
done

echo "==> Authenticating against Pi-hole's local API"
AUTH_RESPONSE=$(docker exec "$CONTAINER" curl -s -X POST http://127.0.0.1:8081/api/auth \
  -H "Content-Type: application/json" \
  -d "{\"password\":\"${PIHOLE_PASSWORD}\"}")

SID=$(echo "$AUTH_RESPONSE" | grep -o '"sid":"[^"]*"' | head -1 | cut -d'"' -f4 || true)

if [[ -z "$SID" ]]; then
  echo "Couldn't authenticate against Pi-hole's API. Response was:"
  echo "$AUTH_RESPONSE"
  echo ""
  echo "Falling back to manual setup: open https://pihole.home.arpa/admin ->"
  echo "Group Management -> Adlists, add these URLs yourself, then click"
  echo "'Update Gravity':"
  for list in "${LISTS[@]}"; do
    echo "  $list"
  done
  exit 1
fi

for list in "${LISTS[@]}"; do
  echo "==> Adding adlist: $list"
  docker exec "$CONTAINER" curl -s -X POST http://127.0.0.1:8081/api/lists \
    -H "Content-Type: application/json" \
    -H "X-FTL-SID: ${SID}" \
    -d "{\"address\":\"${list}\",\"type\":\"block\"}" > /dev/null || true
done

echo "==> Pulling gravity (building the blocklist database)"
docker exec "$CONTAINER" pihole -g

echo "==> Enabling blocking"
docker exec "$CONTAINER" pihole enable

echo "Done. Check status any time with: docker exec pihole pihole status"
