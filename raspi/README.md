# Homelab stack

Refactored from a single sprawling `docker-compose.yml` into one coherent stack:
one ingress (Traefik), one certificate authority, one monitoring pipeline, one
portal page tying it together.

## What changed from the original file

- **Removed two of the three reverse proxies.** The old file ran `nginx`,
  `traefik`, and `nginx-proxy-manager` simultaneously — all three wanted ports
  80/443. Traefik is now the only ingress; everything gets HTTPS through it.
- **Nextcloud moved off its isolated network.** It lived alone on a `cloud`
  network Traefik couldn't reach. It's now on `web` (for Traefik) plus
  `backend` (for its DB/Redis), same pattern as every other service.
- **Networks split by trust level:** `web` (Traefik + app frontends),
  `backend` (databases/caches, `internal: true`, no route out).
- **Pi-hole runs with `network_mode: host`,** not on a docker network at
  all. It originally used a `macvlan` network to get a real LAN IP for
  DHCP/DNS broadcast — that works fine on Ethernet, but macvlan gives a
  container its own virtual MAC address, and most Wi-Fi APs silently drop
  traffic from a second MAC on one physical radio connection (no 4-address/
  WDS mode on consumer routers). If your Pi is on Wi-Fi, macvlan is a dead
  end - DHCP/DNS broadcast and even outbound fetches from that container
  fail silently. Host networking reuses the Pi's own already-working
  interface and MAC, so it works on Wi-Fi or Ethernet. This is also Pi-hole's
  own recommended setup for full DHCP functionality.
- **Pi-hole's admin port mapping was fixed** (the original had `4443:43`, a
  typo) and it's now reached through Traefik like everything else, just via
  a static route instead of docker-label discovery (see below).
- **Added:** Prometheus, cAdvisor, node-exporter, blackbox-exporter,
  pihole-exporter, Grafana, Uptime Kuma, and the `portal` service.

## How Pi-hole's networking actually works now

Since this tripped things up once already, worth spelling out precisely:

- Pi-hole has `network_mode: host` — it shares the Pi's real network stack
  directly. No container IP, no docker network membership.
- Its web UI listens on `127.0.0.1:8081` on the host (moved off :80, since
  Traefik already owns that). DNS (53), DHCP (67), and NTP (123) bind
  directly on the host's real interfaces, same as if you'd installed Pi-hole
  without Docker at all.
- Traefik can't auto-discover it via docker labels (host-networked
  containers have no docker-network IP to route to), so
  `traefik/dynamic/pihole.yml` defines a static route to
  `http://host.docker.internal:8081` instead. `host.docker.internal` is
  resolved via the `extra_hosts: host-gateway` entry on the traefik service.
- **This means Pi-hole doesn't have a separate IP from the Pi itself
  anymore.** Every `*.home.arpa` name — including `pihole.home.arpa` —
  resolves to the same one address: the Raspberry Pi's normal LAN IP.
  There's no separate "Pi-hole IP" to track.

### A Raspberry Pi OS gotcha this setup will hit

Raspberry Pi OS (and most Debian/Ubuntu) ships `systemd-resolved`, which by
default already listens on port 53. Pi-hole (now host-networked) needs that
port and will fail to start until it's freed. `scripts/setup.sh` checks for
this and stops with instructions before it becomes a confusing container
crash-loop; the fix is:

```
sudo sed -i 's/#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo rm -f /etc/resolv.conf
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

## Setup order

**Fresh Raspberry Pi, Docker not installed yet?** Run `./scripts/host-prep.sh`
first.

1. Copy `.env.example` to `.env` and fill in every value — especially the
   passwords/tokens and `LOCAL_SUBNET`.
2. Run `./scripts/setup.sh` (add `--with-firewall` if you also want the UFW
   rules applied). This checks Docker's installed, checks port 53 is free,
   generates the cert, brings the stack up, and seeds Pi-hole. If it stops
   partway with an error (systemd-resolved, Docker missing, etc.), fix that
   one thing and re-run it — it's safe to run more than once. Or run the
   pieces by hand:
   1. Generate the local CA and certificate:
      ```
      DOMAIN_BASE=home.arpa TAILSCALE_IP=100.x.x.x ./scripts/generate-ca.sh
      ```
      (`TAILSCALE_IP` is optional — set it to this box's Tailscale IP so the
      cert also validates when you connect by raw IP over the tailnet.)
      This writes `traefik/certs/rootCA.pem` (also served at
      `https://portal.home.arpa/cert/rootCA.pem` for one-click download once
      the stack is up) and `traefik/certs/home.arpa.{crt,key}` (used by
      Traefik, stays on the server).
   2. Bring the stack up: `docker compose up -d` — do this *after* step (i),
      since Traefik reads `traefik/certs/home.arpa.{crt,key}` at startup and
      will fail to start if they don't exist yet.
   3. Seed Pi-hole's blocklists (a fresh Pi-hole has zero adlists until you
      do this): `./scripts/pihole-setup.sh`
3. Find the Pi's LAN IP: `hostname -I` on the Pi (first address shown).
4. Download and trust `rootCA.pem` on every device — either from the portal
   once DNS works (step 6), or right now via
   `https://<pi's-LAN-IP>/cert/rootCA.pem` (your browser will warn about the
   cert being untrusted at this URL, since you haven't trusted it yet —
   that's expected the first time; proceed past the warning just this once
   to grab the file).
5. In Pi-hole (`https://<pi's-LAN-IP>/admin`, or `https://pihole.home.arpa`
   once DNS resolves) → **Local DNS → DNS Records**, point every
   `*.home.arpa` name at that same LAN IP — `portal`, `vaultwarden`,
   `octoprint`, `pihole`, `nextcloud`, `grafana`, `status`, `traefik`,
   `prometheus`. They all point at the one IP.
6. Point your devices' DNS at Pi-hole:
   - Easiest: let your router hand out Pi-hole's IP as the DNS server via
     its own DHCP (edit the router's DHCP settings).
   - Or let Pi-hole's own DHCP (enabled in `.env`) take over — but only if
     you turn your router's DHCP server **off** first. Don't run both at
     once, they'll fight over IP assignment.
   - To test immediately without waiting on DHCP renewal, add temporary
     `/etc/hosts` entries on one device (e.g. your Mac:
     `sudo nano /etc/hosts`, add lines like
     `<pi's-LAN-IP> portal.home.arpa`) for each hostname. This bypasses DNS
     entirely so you can confirm TLS/Traefik work while you sort out DHCP
     separately.
7. Add your first monitors in Uptime Kuma (`https://status.home.arpa`) —
   point it at the same six HTTPS URLs the blackbox-exporter checks, listed
   in `monitoring/prometheus/prometheus.yml`.
8. Visit `https://portal.home.arpa`.

## Diagnosing "blank page / can't connect"

If a `*.home.arpa` address gives a blank page or a browser-level connection
error (not a certificate warning page), that's a **DNS problem, not a TLS
problem** — the hostname isn't resolving to anything yet. A cert-trust issue
looks different: you'd see a full warning page ("this connection is not
private"), not a blank one. Work through this order:

1. Does the hostname resolve at all? `nslookup portal.home.arpa` (or
   `dig portal.home.arpa`) from the device having trouble. If it fails,
   that device either isn't using Pi-hole as its DNS server yet, or Pi-hole
   doesn't have the Local DNS Record set (steps 5-6 above).
2. Does the IP work directly? Try `https://<pi's-LAN-IP>` — if that loads
   (past a cert warning, since SNI-based routing to the portal needs the
   Host header, so this mostly tests connectivity/TLS rather than the
   portal specifically), Traefik and certs are fine and it's purely DNS.
3. Still stuck? `docker compose ps` on the Pi to confirm every container is
   `Up`/`healthy`, and `docker compose logs traefik pihole` for errors.

## Resolving *.home.arpa only when Tailscale is connected

If you want `*.home.arpa` to resolve on a device (like a laptop) only while
it's connected to Tailscale — not as a permanent DNS change on your router —
use Tailscale's **Split DNS** feature. It still needs a real DNS server to
answer the queries (that's still Pi-hole), Split DNS just controls *when and
how* a device reaches it. Setup, after `docker compose up -d` picks up the
`tailscale` service changes:

1. **Approve the subnet route.** The `tailscale` container now advertises
   your LAN (`LOCAL_SUBNET` from `.env`) so tailnet devices can reach
   Pi-hole through the tunnel. This needs one manual approval: open the
   [Tailscale admin console](https://login.tailscale.com/admin/machines),
   find `raspi-server`, and approve its advertised route under
   **Edit route settings**. Nothing routes until you do this.
2. **Add Split DNS.** In the
   [DNS settings page](https://login.tailscale.com/admin/dns), add a
   nameserver: the Pi's actual **LAN IP** (e.g. `192.168.1.32` — find it with
   `hostname -I` on the Pi), restricted to the domain `home.arpa`. Don't use
   any `100.x.x.x` Tailscale IP here — Pi-hole isn't a tailnet device itself,
   it's reachable *through* the subnet route you just approved, so the
   nameserver needs to be its real LAN IP.
3. **Verify** from your Mac: `nslookup portal.home.arpa` should now return
   the Pi's LAN IP, whether you're on the home Wi-Fi or fully remote.

Worth knowing: this only covers devices actually running Tailscale. Anything
else on your network (smart TVs, guests, a phone with Tailscale off) won't
get ad-blocking or resolve these names unless you *also* point your router's
DHCP at Pi-hole directly. That's a separate, optional step — skip it if
Tailscale-only resolution on your own devices is genuinely all you want.

## Known trade-offs, worth knowing about

- **The Tailscale subnet router needs IP forwarding on the host.** The
  compose file sets `net.ipv4.ip_forward=1` via `sysctls:`, which works on
  most modern kernels, but isn't guaranteed depending on your host's config.
  If devices still can't reach the LAN through Tailscale after approving the
  route, check on the Pi: `sudo sysctl net.ipv4.ip_forward` should print `1`.
  If it's `0`, set it directly on the host instead:
  `sudo sysctl -w net.ipv4.ip_forward=1`, and make it persist across reboots
  by adding `net.ipv4.ip_forward=1` to `/etc/sysctl.d/99-tailscale.conf`.
- **Self-signed CA, not a public CA.** Every `*.home.arpa` cert is signed by
  a CA you generated yourself. That's the right call with no public domain,
  but it means every device needs `rootCA.pem` imported once, and the cert
  needs manual renewal (`generate-ca.sh` re-run) before it expires in ~825
  days — nothing rotates this automatically the way Let's Encrypt would.
- **Blackbox-exporter skips TLS chain verification** (`insecure_skip_verify:
  true` in `monitoring/prometheus/blackbox.yml`) so it doesn't need the CA
  mounted in. It still reports real cert-expiry dates. It also resolves
  every `*.home.arpa` target via `extra_hosts` pointing at the Docker host
  directly, since containers don't use Pi-hole as their DNS resolver - so
  these health checks work independent of whatever DNS state your LAN is in.
- **Collabora (Nextcloud's office suite)** is deployed but not exposed
  through Traefik — it wasn't in your required browser-access list. It's
  reachable from Nextcloud internally for document editing. Say the word if
  you want it public with its own subdomain and cert too.
- **Grafana anonymous access is scoped to Viewer** on the whole default org,
  which is what makes the no-login embed on the portal possible. That also
  means anyone who can reach `grafana.home.arpa` (or the portal) can view
  those dashboards without a password. Fine on a Tailscale-only home LAN;
  worth revisiting if this ever gets exposed wider.
- **If you change `DOMAIN_BASE` away from `home.arpa`**, update it in four
  more places by hand: `monitoring/prometheus/prometheus.yml` (blackbox
  target URLs), `portal/src/index.html` (Grafana iframe `src` URLs and
  service links), `traefik/dynamic/pihole.yml` (the static route's `Host`
  rule), and re-run `generate-ca.sh` with the new value.

## Ported from the old setup.sh

Your earlier `setup.sh` had some genuinely good ideas that weren't in my
first pass — folded in here:

- **`/cert/` download endpoint.** Instead of telling you to go find the cert
  file on the server's filesystem, the portal now serves it directly at
  `/cert/rootCA.pem`.
- **Tailscale IP as a cert SAN.** `generate-ca.sh` now accepts an optional
  `TAILSCALE_IP` to add as an IP SAN, so the cert validates over the tailnet
  by raw IP too.
- **`pihole-exporter` + real block stats.** The dashboard previously only
  knew "is Pi-hole's admin UI reachable" via blackbox-exporter. It now scrapes
  Pi-hole's actual block stats (queries blocked, % blocked, blocklist size) —
  more in the spirit of "make sure it's actually blocking ads."
- **Uptime Kuma.** Your old script scaffolded a directory for it but the
  compose file it paired with wasn't included — added it as `status.home.arpa`,
  a simple public up/down page that complements Grafana's deeper telemetry.
- **A one-command `setup.sh`** that ties cert generation, `docker compose up`,
  and Pi-hole seeding together with the same colored-output style, plus
  `host-prep.sh` and `setup-firewall.sh` as optional extras.w

One thing I deliberately did **not** carry over as-is: the old firewall step
ran `ufw default allow incoming` before adding specific `allow` rules. That
line means everything is open by default and the allow rules underneath it
don't actually restrict anything — the opposite of what a firewall script is
for. `scripts/setup-firewall.sh` here defaults to deny-incoming instead, with
explicit allows for SSH (LAN only), Traefik's 80/443 (LAN only), Pi-hole's
DNS/DHCP/NTP (LAN only, now that it's host-networked and needs explicit
rules), and Tailscale. It's optional — the stack works fine without it if
your router is already the firewall — but if you do run it, it'll actually
restrict access.

## Layout

```
docker-compose.yml
.env.example
traefik/dynamic/tls.yml        # points Traefik at the local CA cert
traefik/dynamic/pihole.yml     # static route to host-networked Pi-hole
traefik/certs/                 # generated by generate-ca.sh, gitignore this
scripts/setup.sh               # one-command orchestrator
scripts/generate-ca.sh         # local CA + cert issuance
scripts/pihole-setup.sh        # blocklist seed + gravity pull
scripts/setup-firewall.sh      # optional UFW lockdown
scripts/host-prep.sh           # optional Docker install on a fresh Pi
monitoring/prometheus/         # scrape config + blackbox probe module
monitoring/grafana/            # datasource + dashboard auto-provisioning
portal/src/                    # the portal page itself (plain HTML/CSS/JS)
```
