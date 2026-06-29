// Service catalog for the patch panel. Add an entry here whenever a new
// service gets a Traefik router, and it shows up on the portal automatically.
const SERVICES = [
  {
    ru: "RU-01",
    name: "Vaultwarden",
    desc: "Self-hosted password manager, Bitwarden-compatible clients work out of the box.",
    host: "vaultwarden.home.arpa",
  },
  {
    ru: "RU-02",
    name: "OctoPrint",
    desc: "Remote monitoring and control for the 3D printer, plus a live camera feed.",
    host: "octoprint.home.arpa",
  },
  {
    ru: "RU-03",
    name: "Pi-hole",
    desc: "Network-wide ad blocking, DNS and DHCP for every device on the LAN.",
    host: "pihole.home.arpa/admin",
  },
  {
    ru: "RU-04",
    name: "Nextcloud",
    desc: "Files, calendar and mail, synced across every device you own.",
    host: "nextcloud.home.arpa",
  },
  {
    ru: "RU-05",
    name: "Grafana",
    desc: "Dashboards behind the telemetry section below — same data, more room to dig in.",
    host: "grafana.home.arpa",
  },
  {
    ru: "RU-06",
    name: "Uptime Kuma",
    desc: "The one-glance public status page — no login, just up or down.",
    host: "status.home.arpa",
  },
];

function renderRack() {
  const rack = document.getElementById("rack");
  rack.innerHTML = SERVICES.map((svc) => `
    <div class="rack-unit">
      <div class="rack-unit__top">
        <span class="rack-unit__ru">${svc.ru}</span>
        <span class="led led--green" title="Status shown live in the Health section below"></span>
      </div>
      <h3 class="rack-unit__name">${svc.name}</h3>
      <p class="rack-unit__desc">${svc.desc}</p>
      <span class="rack-unit__host">${svc.host}</span>
      <a class="rack-unit__open" href="https://${svc.host}" target="_blank" rel="noopener">Open →</a>
    </div>
  `).join("");
}

renderRack();
