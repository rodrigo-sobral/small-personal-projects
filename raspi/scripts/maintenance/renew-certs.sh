#!/usr/bin/env bash
# Reissues the *.${DOMAIN_BASE} leaf certificate when it's close to expiring,
# then gets Traefik to load the new one. Runs on a daily loop inside the
# `cert-renew` container, and is also safe to run by hand on the host.
#
# ---------------------------------------------------------------------------
# Why this can be fully automatic
# ---------------------------------------------------------------------------
# The root CA and the leaf certificate have very different lifetimes and very
# different consequences:
#
#   - The root CA lasts 10 years and is the thing your devices trust. Rotating
#     it means reinstalling rootCA.pem on every phone, laptop and TV in the
#     house. Nothing here ever touches it.
#   - The leaf lasts 825 days and is only used by Traefik. Because it's signed
#     by the same unchanged CA, a new leaf is trusted by every device
#     immediately, with no action on their part.
#
# So renewing the leaf is invisible to clients, which is exactly what makes it
# safe to do unattended. This is the same split Let's Encrypt relies on.
#
# ---------------------------------------------------------------------------
# How Traefik picks up the new certificate
# ---------------------------------------------------------------------------
# Traefik loads certificate files when it parses its dynamic configuration,
# and it's already watching that directory (--providers.file.watch=true). It
# does NOT watch the certificate files themselves. So after reissuing, we
# rewrite a small marker file in the dynamic directory; the resulting reload
# re-reads tls.yml and, with it, the new certificate from disk.
#
# The marker is its own file rather than a `touch` of tls.yml because tls.yml
# is tracked in git and mounted read-only, and because a content change is a
# more reliable trigger than an mtime change alone.
#
# If that ever doesn't take effect, `docker compose restart traefik` is the
# unambiguous fallback - it costs a second of downtime on a home LAN.
#
# Usage:
#   ./scripts/maintenance/renew-certs.sh           # renew only if inside the window
#   ./scripts/maintenance/renew-certs.sh --force   # renew now, regardless
#   ./scripts/maintenance/renew-certs.sh --check   # report status, change nothing

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOMAIN_BASE="${DOMAIN_BASE:-home.arpa}"
CERT_DIR="${OUT_DIR:-$SCRIPT_DIR/../../traefik/certs}"
DYNAMIC_DIR="${TRAEFIK_DYNAMIC_DIR:-$SCRIPT_DIR/../../traefik/dynamic}"
# Renew once the leaf has fewer than this many days left. 30 is comfortable:
# the daily check has ~30 chances to succeed before anything breaks, so a few
# failed runs (host down, disk full) are harmless.
RENEW_BEFORE_DAYS="${CERT_RENEW_BEFORE_DAYS:-30}"

CERT_FILE="$CERT_DIR/home.arpa.crt"
MARKER_FILE="$DYNAMIC_DIR/cert-reload.yml"
MODE="${1:-}"

log() { printf '%s %s\n' "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')]" "$*"; }

# --- how long is left? ------------------------------------------------------
# Returns the seconds remaining on stdout; a missing cert reports 0 so the
# first run on a fresh checkout issues one.
#
# OpenSSL 3's `-dateopt iso_8601` gives "YYYY-MM-DD HH:MM:SSZ". That matters
# because the cert-renew container is Alpine: its busybox `date -d` CANNOT
# parse the legacy "Dec 15 23:10:32 2028 GMT" form, so the old version always
# returned 0 there and reissued the leaf on every daily check. Strip the
# trailing Z and busybox parses it. Fall back to the legacy form for older
# OpenSSL (parseable by GNU date on the host).
seconds_remaining() {
  [[ -f "$CERT_FILE" ]] || { echo 0; return; }
  local end_date end_epoch now_epoch
  end_date="$(openssl x509 -in "$CERT_FILE" -noout -enddate -dateopt iso_8601 2>/dev/null | cut -d= -f2)"
  if [[ -z "$end_date" ]]; then
    end_date="$(openssl x509 -in "$CERT_FILE" -noout -enddate | cut -d= -f2)"
  fi
  end_date="${end_date%Z}"
  end_epoch="$(date -d "$end_date" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  if [[ "$end_epoch" == "0" ]]; then echo 0; return; fi
  echo $(( end_epoch - now_epoch ))
}

REMAINING="$(seconds_remaining)"
REMAINING_DAYS=$(( REMAINING / 86400 ))
THRESHOLD=$(( RENEW_BEFORE_DAYS * 86400 ))

if [[ "$MODE" == "--check" ]]; then
  if [[ ! -f "$CERT_FILE" ]]; then
    log "No certificate at $CERT_FILE"
    exit 1
  fi
  log "Leaf certificate has ${REMAINING_DAYS}d left (renews under ${RENEW_BEFORE_DAYS}d)"
  exit 0
fi

if [[ "$MODE" != "--force" && "$REMAINING" -gt "$THRESHOLD" ]]; then
  log "Certificate has ${REMAINING_DAYS}d left, nothing to do"
  exit 0
fi

if [[ "$MODE" == "--force" ]]; then
  log "Forced renewal requested"
else
  log "Certificate has ${REMAINING_DAYS}d left, renewing (threshold ${RENEW_BEFORE_DAYS}d)"
fi

# --- reissue ----------------------------------------------------------------
# 05_setup-ca.sh reuses the existing root CA if it's there, so this only ever
# regenerates the leaf. TAILSCALE_IP is passed through so the SAN survives a
# renewal - forgetting it would silently drop tailnet-by-IP access.
OUT_DIR="$CERT_DIR" \
GLANCE_ASSETS_DIR="${GLANCE_ASSETS_DIR:-$SCRIPT_DIR/../../glance/assets}" \
DOMAIN_BASE="$DOMAIN_BASE" \
TAILSCALE_IP="${TAILSCALE_IP:-}" \
  "$SCRIPT_DIR/../05_setup-ca.sh"

# --- nudge Traefik ----------------------------------------------------------
# Written via a temp file and renamed into place, rather than truncating the
# marker directly. The cert-renew container runs as root, so once it has done
# one renewal the marker is owned by root:root - and a later `--force` run by
# a normal user on the host then fails with "Permission denied" even though the
# directory itself is writable. A rename only needs write permission on the
# DIRECTORY, so this works for both callers regardless of who wrote it last.
if [[ -d "$DYNAMIC_DIR" && -w "$DYNAMIC_DIR" ]]; then
  MARKER_TMP="${MARKER_FILE}.tmp.$$"
  cat > "$MARKER_TMP" <<EOF
# Written by scripts/maintenance/renew-certs.sh - not hand-maintained.
#
# Its only job is to make Traefik reload. Rewriting a file in the watched
# dynamic directory makes Traefik re-parse everything, which re-reads the
# certificate files referenced by tls.yml - that's how a renewed leaf gets
# served without restarting the container.
#
# Two things this file has to get right, both learned the hard way:
#
#  1. It must be VALID dynamic config. An empty 'http: {}' is rejected
#     ("http cannot be a standalone element") and Traefik aborts the whole
#     reload, silently leaving the old certificate in place. So this declares
#     a real - if unused - middleware.
#  2. Its CONTENT must change each time, not just its mtime. The timestamp in
#     the header value below does that, so Traefik can't treat the new
#     configuration as identical to the old one and skip it.
#
# Nothing routes through this middleware; it exists to be parsed.
http:
  middlewares:
    cert-reload-marker:
      headers:
        customResponseHeaders:
          X-Cert-Renewed: "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
EOF
  # Same permissions the container would produce, so neither caller is
  # surprised next time.
  chmod 644 "$MARKER_TMP"
  mv -f "$MARKER_TMP" "$MARKER_FILE"
  log "Traefik reload triggered via $MARKER_FILE"
else
  log "WARNING: $DYNAMIC_DIR not writable - certificate renewed but Traefik"
  log "         will keep serving the old one until you run:"
  log "           docker compose restart traefik"
fi

NEW_REMAINING_DAYS=$(( $(seconds_remaining) / 86400 ))
log "Done. New certificate valid for ${NEW_REMAINING_DAYS}d"
