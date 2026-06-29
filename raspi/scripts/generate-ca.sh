#!/usr/bin/env bash
# Generates a local root CA and a single SAN certificate covering every
# *.home.arpa host used by the stack. Run this once (and again whenever you
# add a new subdomain to the SAN list below).
#
# After running, import rootCA.pem into your OS/browser trust store on every
# device that needs to see the padlock instead of a warning:
#   - macOS: Keychain Access -> System -> import -> "Always Trust"
#   - Windows: certmgr.msc -> Trusted Root Certification Authorities -> Import
#   - Linux: copy to /usr/local/share/ca-certificates/, run update-ca-certificates
#   - iOS/Android: install profile / import cert, then enable full trust in settings

# Set TAILSCALE_IP to also cover that IP as a SAN, so the cert still
# validates when you hit the box by its raw Tailscale IP instead of a
# home.arpa hostname (e.g. before you've set up split-DNS over Tailscale):
#   TAILSCALE_IP=100.x.x.x ./scripts/generate-ca.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN_BASE="${DOMAIN_BASE:-home.arpa}"
TAILSCALE_IP="${TAILSCALE_IP:-}"
OUT_DIR="$SCRIPT_DIR/../traefik/certs"
DAYS_CA=3650
DAYS_CERT=825   # keep under browser max lifetime for a leaf cert

mkdir -p "$OUT_DIR"
cd "$OUT_DIR"

if [[ ! -f rootCA.key ]]; then
  echo "==> Generating root CA"
  openssl genrsa -out rootCA.key 4096
  openssl req -x509 -new -nodes -key rootCA.key -sha256 -days "$DAYS_CA" \
    -out rootCA.pem \
    -subj "/C=XX/ST=Homelab/L=Homelab/O=Homelab Local CA/CN=Homelab Root CA"
  echo "==> Root CA created: $OUT_DIR/rootCA.pem  (import this into your devices)"
else
  echo "==> Reusing existing root CA"
fi

echo "==> Generating leaf key + CSR for *.${DOMAIN_BASE}"
openssl genrsa -out home.arpa.key 2048

cat > san.cnf <<EOF
[req]
distinguished_name = dn
req_extensions = v3_req
prompt = no

[dn]
CN = ${DOMAIN_BASE}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN_BASE}
DNS.2 = *.${DOMAIN_BASE}
DNS.3 = vaultwarden.${DOMAIN_BASE}
DNS.4 = octoprint.${DOMAIN_BASE}
DNS.5 = pihole.${DOMAIN_BASE}
DNS.6 = nextcloud.${DOMAIN_BASE}
DNS.7 = portal.${DOMAIN_BASE}
DNS.8 = grafana.${DOMAIN_BASE}
DNS.9 = prometheus.${DOMAIN_BASE}
DNS.10 = traefik.${DOMAIN_BASE}
DNS.11 = status.${DOMAIN_BASE}
EOF

if [[ -n "$TAILSCALE_IP" ]]; then
  echo "IP.1 = ${TAILSCALE_IP}" >> san.cnf
  echo "==> Including Tailscale IP ${TAILSCALE_IP} as a SAN"
fi

openssl req -new -key home.arpa.key -out home.arpa.csr -config san.cnf

echo "==> Signing leaf cert with the local CA"
openssl x509 -req -in home.arpa.csr -CA rootCA.pem -CAkey rootCA.key \
  -CAcreateserial -out home.arpa.crt -days "$DAYS_CERT" -sha256 \
  -extfile san.cnf -extensions v3_req

rm -f home.arpa.csr san.cnf

echo "==> Publishing rootCA.pem to the portal (served at /cert/rootCA.pem)"
PORTAL_CERT_DIR="$SCRIPT_DIR/../portal/src/cert"
mkdir -p "$PORTAL_CERT_DIR"
cp rootCA.pem "$PORTAL_CERT_DIR/rootCA.pem"

echo ""
echo "Done. Files written to $OUT_DIR:"
echo "  rootCA.pem       <- import this on every client device"
echo "  rootCA.key       <- keep private, only needed to reissue certs"
echo "  home.arpa.crt    <- used by Traefik"
echo "  home.arpa.key    <- used by Traefik"
echo ""
echo "Point every *.${DOMAIN_BASE} name at Pi-hole (or your router) via Local DNS Records"
echo "so browsers resolve them to your server's LAN IP."
