# Homelab stack

A self-hosted homelab for a Raspberry Pi, defined in a single `docker-compose.yml`. One ingress (Traefik), one certificate authority, one monitoring agent (Beszel), and one dashboard (Glance).

## Architecture

- **Ingress:** Traefik is the only reverse proxy and terminates all TLS. Every service is discovered through Docker labels and reached over HTTPS.
- **Networks:** `web` (Traefik + service frontends) and `backend` (`internal: true`, for databases and caches).
- **Certificates:** a private root CA (`rootCA.pem`) signs one leaf covering every `*.<DOMAIN_BASE>` name. The leaf is renewed automatically; the root CA never is.
- **Pi-hole** runs with `network_mode: host` so DNS/DHCP broadcast works on Wi-Fi. Its web UI is on `127.0.0.1:8081` and is routed through Traefik via a static route (`traefik/dynamic/pihole.yml`).

## Services

| Service | URL | Purpose |
| -- | -- | -- |
| Glance | `glance.<DOMAIN_BASE>` and the bare domain | Dashboard, CA download, setup notes |
| Beszel | `beszel.<DOMAIN_BASE>` | Host + per-container resource history and alerts |
| Authentik | `auth.<DOMAIN_BASE>` | Single sign-on / forward auth |
| Traefik | `traefik.<DOMAIN_BASE>` | Reverse proxy, TLS, container discovery |
| Immich | `immich.<DOMAIN_BASE>` | Photo/video library with mobile backup |
| Jellyfin | `jellyfin.<DOMAIN_BASE>` | Media streaming (direct play; software transcode only) |
| Nextcloud | `nextcloud.<DOMAIN_BASE>` | Files, calendar, mail |
| Collabora | internal only | Nextcloud document editor (proxied by Nextcloud) |
| ONLYOFFICE | `office.<DOMAIN_BASE>` | Heavier alternative document editor |
| Vaultwarden | `vaultwarden.<DOMAIN_BASE>` | Password manager |
| Stirling PDF | `pdf.<DOMAIN_BASE>` | Local PDF tools (behind Authentik) |
| AI (Open WebUI + Ollama) | `ai.<DOMAIN_BASE>` | Local LLM chat with built-in web search (behind Authentik) |
| OctoPrint | `octoprint.<DOMAIN_BASE>` | 3D printer management |
| Pi-hole | `pihole.<DOMAIN_BASE>` | DNS, ad-blocking, DHCP (host network) |
| Minecraft | `minecraft.<DOMAIN_BASE>:25565` | Java Edition server (not HTTP, no Traefik) |
| Tailscale | — | VPN and LAN subnet routing |
| Scheduler bot | — | Discord scheduling bot |
| cert-renew | — | Automatic leaf certificate renewal |
| Watchtower | — | Automatic image updates (label-controlled) |

Service state lives in named Docker volumes, with two deliberate exceptions: Immich's library and Jellyfin's media are host bind mounts (`IMMICH_UPLOAD_LOCATION`, `JELLYFIN_MEDIA_PATH`) so you can point them at an external disk and back them up with normal tools.

## Single sign-on

Authentik is the login for services that have no account system of their own. It is applied per service by adding a middleware label in `docker-compose.yml`; the forward-auth provider is defined in `traefik/dynamic/authentik.yml` and is inert until a router references it.

- **Fronted by Authentik:** Glance, Stirling PDF, AI (Open WebUI). Open WebUI has its own accounts but trusts Authentik's `X-authentik-email` header, so the single login covers it too.
- **OIDC providers pre-created** (app side needs a one-time manual step): Immich, Nextcloud, Jellyfin, Beszel. Credentials are seeded into `.env`.
- **Cannot be integrated:** Pi-hole, Vaultwarden, OctoPrint. The Traefik dashboard is deliberately left on basic auth so it still works if Authentik is down.
- **Keep native logins:** Immich, Jellyfin, Nextcloud and Vaultwarden — their mobile/desktop clients authenticate directly and would break behind a browser redirect.

If a service is only ever opened in a browser and has weak or no auth of its own, it is a good forward-auth candidate. Do not blanket-apply the middleware: anything a client calls directly, or that another service talks to server-to-server, will break.

## Monitoring

**Beszel** is the monitoring stack (replacing Prometheus, Grafana, Uptime Kuma and four exporters). The hub dials a host-networked agent over a unix socket in a shared volume. The agent reads the Docker socket, so every container on the host is monitored automatically with no per-service config.

**Glance** is the dashboard. Its `monitor` widgets use a `url` (the link you click) and a `check-url` (what is actually probed). `check-url` targets the container directly over the `web` network by service name and internal port — containers don't resolve `*.home.arpa`, so probing the public URL would always fail. The trade-off is that these checks report "the app is up", not "the ingress path works".

## Certificate renewal

The leaf certificate lasts 825 days. The `cert-renew` service checks daily and reissues it once it is inside its renewal window (`CERT_RENEW_BEFORE_DAYS`, default 30), then rewrites a marker file in Traefik's dynamic directory to trigger a reload. It never touches the root CA, so renewals are invisible to clients.

```
./scripts/maintenance/renew-certs.sh --check    # how long is left, change nothing
./scripts/maintenance/renew-certs.sh            # renew only if inside the window
./scripts/maintenance/renew-certs.sh --force    # renew now
```

When you add a new subdomain, add it to the SAN list in `scripts/05_setup-ca.sh` — renewal reissues whatever that list says.

## Performance notes

This box is an 8 GB Pi 5 running ~26 containers. A few things are worth understanding:

- **The memory cgroup is disabled by default** (`cgroup_disable=memory`). This makes `docker stats` report `0B` and means `deploy.resources.limits.memory` is silently ignored. `scripts/maintenance/tune-host-memory.sh --apply` enables it (plus zram and swappiness) and requires a reboot.
- **Minecraft** splits heap into `MINECRAFT_INIT_MEMORY`/`MINECRAFT_MAX_MEMORY` rather than a single `MEMORY`, so an idle server doesn't hold the full ceiling in RAM.
- **ONLYOFFICE** is the heaviest service (~1–1.5 GB idle, upstream asks for 4 GB). It duplicates Collabora, which does the same job for ~56 MB — run only one.
- **Jellyfin** cannot hardware-transcode on a Pi 5 (no VAAPI render node), so plan on direct play or pre-transcoding.
- **Ollama** runs models on the CPU, so only small ones are realistic — `qwen3:1.7b` is the default. It unloads the model after 5 minutes idle so an idle dashboard isn't holding ~1.5 GB of RAM. To switch models, set `OLLAMA_MODEL` in `.env`, run `scripts/07_setup-ai.sh`, then pick it in Open WebUI.

## Setup

On a fresh Pi with no Docker, run `./scripts/00_host-prep.sh` first.

1. Copy `.env.example` to `.env` and fill in every value, especially the passwords and `LOCAL_SUBNET`. Leave the blank credential values (`BESZEL_SYSTEM_USER`/`BESZEL_TOKEN`/`BESZEL_KEY` and the `*_OIDC_*` pairs) empty — the setup scripts generate them. Set `MINECRAFT_EULA=TRUE` to start the Minecraft server.
2. Run `./scripts/01_setup.sh` (add `--with-firewall` to also apply UFW rules). It checks prerequisites, detects the LAN IP, creates the media directories, pre-configures Beszel and Authentik, generates the CA and cert, brings the stack up, seeds Pi-hole, and pulls the Ollama model. It is safe to re-run.
3. Download and trust `rootCA.pem` on every device (served at `https://glance.<DOMAIN_BASE>/assets/rootCA.pem`).
4. Point your devices' DNS at Pi-hole — either from your router's DHCP settings, or let Pi-hole's own DHCP take over (turn the router's DHCP off first).
5. Complete the first-run steps that can't be scripted:
   - Create the **Authentik** admin account at `https://auth.<DOMAIN_BASE>/if/flow/initial-setup/`.
   - Create your **Beszel** account, then `docker compose restart beszel` once to attach the system.
   - Run **Jellyfin**'s setup wizard and add libraries; create the first **Immich** account and turn off Settings → Machine Learning.
   - Open `https://ai.<DOMAIN_BASE>` and sign in with Authentik — the first account becomes Open WebUI's admin. The Ollama model was already pulled by `01_setup.sh`.
6. Finish the optional OIDC integrations (Immich, Nextcloud, Jellyfin, Beszel) using the credentials already in `.env`.
7. Open `https://glance.<DOMAIN_BASE>`.

### Raspberry Pi OS gotcha

Raspberry Pi OS ships `systemd-resolved`, which usually already holds port 53. Pi-hole (host-networked) needs it. `01_setup.sh` detects this and stops with instructions. The fix:

```sh
sudo sed -i 's/#\?DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf
sudo rm -f /etc/resolv.conf
echo 'nameserver 127.0.0.1' | sudo tee /etc/resolv.conf
sudo systemctl restart systemd-resolved
```

## Troubleshooting

A blank page or connection error on a `*.home.arpa` address is a **DNS** problem, not a TLS problem. A cert-trust issue shows a full warning page instead. In order:

1. Does the name resolve? `nslookup glance.<DOMAIN_BASE>`.
2. Does the IP work? Try `https://<pi's-LAN-IP>` (past the cert warning).
3. Still stuck? `docker compose ps`, then `docker compose logs traefik pihole`.

## Adding a service

1. `docker-compose.yml` — the service block with its Traefik labels, plus any volumes at the top.
2. `docker-compose.yml` — one line in Pi-hole's `FTLCONF_dns_hosts`.
3. `scripts/05_setup-ca.sh` — a `DNS.n` entry in the SAN list, then re-run it and `docker compose restart traefik`.
4. `glance/glance.yml` — a site in the shared `core-sites`/`app-sites` anchors and a bookmark. Use a `check-url` pointing at the container, not the public URL.
5. Optional: add `- "traefik.http.routers.<name>.middlewares=authentik@file"` if it has no login of its own — but only if nothing but a browser calls it.

Beszel needs nothing: the agent discovers new containers automatically. A new non-HTTP service skips step 3 and publishes its port directly (see Minecraft).

## Layout

```
docker-compose.yml
.env.example
scripts/                      # numbered by execution order: 00 runs before setup,
                              #   01 is the orchestrator, 02+ are its steps
scripts/maintenance/          # run on their own, never from 01_setup.sh
                              #   (host memory tuning, cert renewal)
traefik/dynamic/              # tls.yml, pihole.yml, authentik.yml (file provider)
traefik/certs/                # generated, gitignored
glance/                       # glance.yml + themes.yml + widgets/ (dashboard config)
glance/assets/                # i18n/theme/weather JS+CSS (tracked) + generated CA files (gitignored)
authentik/blueprints/         # declarative SSO: providers, applications, outpost
beszel/                       # generated config + hub SSH key (gitignored)
nextcloud/onlyoffice.config.php
```
