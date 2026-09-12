/* Runtime EN-US / PT-PT switch for the Glance dashboard.
 *
 * Glance has no built-in localization, so this script does three things:
 *
 *   1. Toggles inline <span class="i18n" lang="…"> prose pairs via the
 *      `data-lang` attribute on <html> (see assets/i18n.css).
 *   2. Translates plain-text strings that Glance renders from YAML - page
 *      names, widget titles, bookmark groups/titles/descriptions, monitor
 *      names - by matching normalized text nodes against TEXT_PT.
 *   3. Translates known `title` tooltips and the weather weekday labels.
 *
 * The chosen language is remembered in localStorage and defaults to the
 * browser language (Portuguese browsers get pt-PT).
 */
(function () {
  "use strict";

  var STORAGE_KEY = "glance-lang";
  var EN = "en-US";
  var PT = "pt-PT";

  // Plain-text strings (exact match after whitespace normalization).
  // English -> European Portuguese.
  var TEXT_PT = {
    // Pages / navigation
    "Home": "Início",
    "Services": "Serviços",
    "Docs": "Documentação",
    "Setup": "Configuração",

    // Widget titles
    "Core": "Base",
    "Apps": "Aplicações",
    "Applications": "Aplicações",
    "Infrastructure": "Infraestrutura",
    "Ingress & identity": "Entrada e identidade",
    "Host resources": "Recursos do sistema",
    "DNS Stats": "Estatísticas de DNS",
    "Tailscale devices": "Dispositivos Tailscale",
    "Immich library": "Biblioteca Immich",
    "Jellyfin · Next up": "Jellyfin · A seguir",
    "Scheduler bot": "Bot de agendamento",
    "Scheduler bot releases": "Versões do bot de agendamento",
    "Discord scheduler bot": "Bot de agendamento do Discord",
    "Weather Forecast": "Previsão do tempo",
    "Weather now": "Meteorologia agora",
    "Weather": "Meteorologia",
    "Today": "Hoje",
    "Feels like": "Sensação térmica de",
    "Loading weather…": "A carregar meteorologia…",

    // Built-in weather widget conditions (see weatherCodeTable in Glance)
    "Clear Sky": "Céu limpo",
    "Mainly Clear": "Maioritariamente limpo",
    "Partly Cloudy": "Parcialmente nublado",
    "Overcast": "Encoberto",
    "Fog": "Nevoeiro",
    "Rime Fog": "Nevoeiro gelado",
    "Drizzle": "Chuvisco",
    "Rain": "Chuva",
    "Moderate Rain": "Chuva moderada",
    "Heavy Rain": "Chuva forte",
    "Freezing Rain": "Chuva gelada",
    "Snow": "Neve",
    "Moderate Snow": "Neve moderada",
    "Heavy Snow": "Neve forte",
    "Snow Grains": "Grãos de neve",
    "Thunderstorm": "Trovoada",
    "Bookmarks": "Favoritos",
    "Containers": "Contentores",
    "Docker Containers": "Contentores Docker",
    "Calendar": "Calendário",
    "Releases": "Versões",

    // Bookmark groups
    "Admin": "Administração",
    "Media & files": "Multimédia e ficheiros",
    "Tools": "Ferramentas",
    "Monitoring & platform": "Monitorização e plataforma",

    // Bookmark titles
    "Add to Discord": "Adicionar ao Discord",
    "Minecraft server image": "Imagem do servidor Minecraft",

    // Bookmark descriptions
    "Photos and videos": "Fotografias e vídeos",
    "Movies, shows, music": "Filmes, séries, música",
    "Files, calendar, mail": "Ficheiros, calendário, correio",
    "Passwords": "Palavras-passe",
    "PDF tools, all local": "Ferramentas de PDF, tudo local",
    "Document editor behind Nextcloud": "Editor de documentos por trás do Nextcloud",
    "3D printer": "Impressora 3D",
    "Resource history and alerts": "Histórico de recursos e alertas",
    "Routers, services, TLS": "Routers, serviços, TLS",
    "DNS, DHCP, blocklists": "DNS, DHCP, listas de bloqueio",
    "Users, applications, outposts": "Utilizadores, aplicações, outposts",
    "Photo library, mobile backup, external libraries": "Biblioteca de fotografias, cópia de segurança móvel, bibliotecas externas",
    "Libraries, naming conventions, clients": "Bibliotecas, convenções de nomes, clientes",
    "Files, groupware, app store": "Ficheiros, groupware, loja de aplicações",
    "Admin page, backups, client setup": "Página de administração, cópias de segurança, configuração de clientes",
    "Every PDF operation, pipelines, OCR": "Todas as operações de PDF, pipelines, OCR",
    "JWT, reverse proxy, Nextcloud connector": "JWT, proxy reverso, conector Nextcloud",
    "Plugins, printer profiles, webcam": "Plugins, perfis de impressora, webcam",
    "Every env var, mod loaders, backups": "Todas as variáveis de ambiente, loaders de mods, cópias de segurança",
    "Routers, middlewares, file provider, TLS": "Routers, middlewares, file provider, TLS",
    "Providers, outposts, flows, blueprints": "Providers, outposts, fluxos, blueprints",
    "DNS, DHCP, blocklists, FTLCONF_ variables": "DNS, DHCP, listas de bloqueio, variáveis FTLCONF_",
    "Agents, alerts, config.yml, universal tokens": "Agentes, alertas, config.yml, tokens universais",
    "Every widget and option in this dashboard": "Todos os widgets e opções deste painel",
    "The compose file reference": "A referência do ficheiro Compose",
    "Subnet routes, split DNS, ACLs": "Rotas de sub-rede, split DNS, ACLs",
    "Install the bot to your server": "Instala o bot no teu servidor",
    "Local LLM chat with web search": "Conversa com um LLM local e pesquisa na web",
    "Models, web search, tools, RAG": "Modelos, pesquisa na web, ferramentas, RAG",

    // Built-in Glance strings
    "All sites are online": "Todos os sites estão online",
    "Timed Out": "Tempo esgotado",
    "ERROR": "ERRO",
    "Loading": "A carregar",
    "WORK IN PROGRESS": "EM DESENVOLVIMENTO",
    "Report issue": "Reportar problema",
    "No error information provided": "Nenhuma informação de erro disponível",
    "Change theme": "Mudar tema",
    "Logout": "Terminar sessão",
    "QUERIES": "CONSULTAS",
    "BLOCKED": "BLOQUEADOS",
    "LATENCY": "LATÊNCIA",
    "DOMAINS": "DOMÍNIOS",
    "Top blocked domains": "Domínios mais bloqueados",
    "PHOTOS": "FOTOGRAFIAS",
    "VIDEOS": "VÍDEOS",
    "LIBRARY": "BIBLIOTECA",
    "DISK": "DISCO",
    "update": "atualização",
    "offline": "offline",
    "Nothing waiting — start streaming something.": "Nada em espera — começa a ver algo.",

    // Calendar month names (rendered by Glance's calendar.js)
    "January": "janeiro",
    "February": "fevereiro",
    "March": "março",
    "April": "abril",
    "May": "maio",
    "June": "junho",
    "July": "julho",
    "August": "agosto",
    "September": "setembro",
    "October": "outubro",
    "November": "novembro",
    "December": "dezembro",

    // Calendar weekday abbreviations (calendar.js uses two-letter names)
    "Su": "Dom",
    "Mo": "Seg",
    "Tu": "Ter",
    "We": "Qua",
    "Th": "Qui",
    "Fr": "Sex",
    "Sa": "Sáb"
  };

  // Prefix/pattern translations for text with dynamic values (e.g. the built-in
  // weather widget's "Feels like 12°C"). Applied in order.
  var TEXT_PATTERNS_PT = [
    [/^(\s*)Feels like\b/, "$1Sensação térmica de"]
  ];

  // `title` tooltips. English -> European Portuguese.
  var ATTR_PT = {
    "Back to current month": "Voltar ao mês atual",
    "Previous month": "Mês anterior",
    "Next month": "Mês seguinte",
    "Total number of blocked domains from all adlists": "Número total de domínios bloqueados de todas as listas",
    "Release notes": "Notas de lançamento",
    "Logout": "Terminar sessão",
    // Weather conditions (weather.yml renders these as the <i> title)
    "Clear": "Limpo",
    "Part Clear": "Parcialmente limpo",
    "Cloudy": "Nublado",
    "Fog": "Nevoeiro",
    "Drizzle": "Chuvisco",
    "Rain": "Chuva",
    "Freezing Rain": "Chuva gelada",
    "Snow": "Neve",
    "Thunderstorm": "Trovoada",
    "Other": "Outro"
  };

  // Weather weekday labels, keyed by the full English day name that
  // weather.yml puts in the data-day attribute.
  var DAYS = {
    "Monday": { en: "M", pt: "Seg" },
    "Tuesday": { en: "Tu", pt: "Ter" },
    "Wednesday": { en: "W", pt: "Qua" },
    "Thursday": { en: "Th", pt: "Qui" },
    "Friday": { en: "F", pt: "Sex" },
    "Saturday": { en: "Sa", pt: "Sáb" },
    "Sunday": { en: "Su", pt: "Dom" }
  };

  var SKIP_TAGS = { SCRIPT: 1, STYLE: 1, TEXTAREA: 1, NOSCRIPT: 1 };
  var textOriginals = new WeakMap();
  var current = readInitialLang();

  function has(obj, key) {
    return Object.prototype.hasOwnProperty.call(obj, key);
  }

  function normalize(value) {
    return value.replace(/\s+/g, " ").trim();
  }

  // Translate a plain English string to the current language. Shared with other
  // dashboard scripts through window.glanceI18n.
  function translateString(value) {
    if (current !== PT) return value;
    var key = normalize(value);
    if (has(TEXT_PT, key)) return TEXT_PT[key];
    for (var i = 0; i < TEXT_PATTERNS_PT.length; i++) {
      if (TEXT_PATTERNS_PT[i][0].test(value)) {
        return value.replace(TEXT_PATTERNS_PT[i][0], TEXT_PATTERNS_PT[i][1]);
      }
    }
    return value;
  }

  window.glanceI18n = {
    lang: function () { return current; },
    t: translateString
  };

  function readInitialLang() {
    try {
      var stored = localStorage.getItem(STORAGE_KEY);
      if (stored === EN || stored === PT) return stored;
    } catch (e) { /* private mode */ }
    return (navigator.language || "").toLowerCase().indexOf("pt") === 0 ? PT : EN;
  }

  function setLang(lang) {
    current = lang;
    try { localStorage.setItem(STORAGE_KEY, lang); } catch (e) { /* ignore */ }
    var html = document.documentElement;
    html.setAttribute("data-lang", lang);
    html.setAttribute("lang", lang);
    apply();
    document.dispatchEvent(new CustomEvent("glance-lang-change"));
  }

  function translateTextNode(node) {
    if (!textOriginals.has(node)) textOriginals.set(node, node.nodeValue);
    var original = textOriginals.get(node);
    var value = original;
    if (current === PT) {
      var key = normalize(original);
      if (has(TEXT_PT, key)) {
        var lead = original.match(/^\s*/)[0];
        var trail = original.match(/\s*$/)[0];
        value = lead + TEXT_PT[key] + trail;
      } else {
        for (var i = 0; i < TEXT_PATTERNS_PT.length; i++) {
          if (TEXT_PATTERNS_PT[i][0].test(original)) {
            value = original.replace(TEXT_PATTERNS_PT[i][0], TEXT_PATTERNS_PT[i][1]);
            break;
          }
        }
      }
    }
    if (node.nodeValue !== value) node.nodeValue = value;
  }

  function walkText(root) {
    if (root.nodeType === 3) {
      translateTextNode(root);
      return;
    }
    if (root.nodeType !== 1 && root.nodeType !== 9 && root.nodeType !== 11) return;
    if (root.nodeType === 1) {
      if (SKIP_TAGS[root.tagName]) return;
      if (root.classList && root.classList.contains("i18n")) return;
    }
    for (var child = root.firstChild; child; child = child.nextSibling) {
      walkText(child);
    }
  }

  function collect(root, selector) {
    var list = [];
    if (root.nodeType === 1 && root.matches && root.matches(selector)) list.push(root);
    if (root.querySelectorAll) {
      list = list.concat(Array.prototype.slice.call(root.querySelectorAll(selector)));
    }
    return list;
  }

  function translateTitles(root) {
    collect(root, "[title]").forEach(function (el) {
      if (el.classList && el.classList.contains("lang-toggle")) return;
      var en = el.getAttribute("data-i18n-title-en");
      var cur = el.getAttribute("title");
      if (en === null || (cur !== en && cur !== ATTR_PT[en])) {
        en = cur;
        if (en !== null) el.setAttribute("data-i18n-title-en", en);
      }
      if (en === null) return;
      var value = current === PT && has(ATTR_PT, en) ? ATTR_PT[en] : en;
      if (cur !== value) el.setAttribute("title", value);
    });
  }

  function translateDays(root) {
    collect(root, "[data-day]").forEach(function (el) {
      var day = DAYS[el.getAttribute("data-day")];
      if (!day) return;
      var value = current === PT ? day.pt : day.en;
      if (el.textContent !== value) el.textContent = value;
    });
  }

  function translateDocumentTitle() {
    var html = document.documentElement;
    var en = html.getAttribute("data-title-en");
    var cur = document.title;
    if (en === null || (cur !== en && cur !== TEXT_PT[en])) {
      en = cur;
      html.setAttribute("data-title-en", en);
    }
    var value = current === PT && has(TEXT_PT, en) ? TEXT_PT[en] : en;
    if (document.title !== value) document.title = value;
  }

  function ensureToggle() {
    [".header", ".mobile-navigation-actions"].forEach(function (selector) {
      var host = document.querySelector(selector);
      if (!host || host.querySelector(".lang-toggle")) return;
      var button = document.createElement("button");
      button.type = "button";
      button.className = "lang-toggle";
      button.addEventListener("click", function () {
        setLang(current === EN ? PT : EN);
      });
      host.appendChild(button);
    });
  }

  function updateToggle() {
    var target = current === EN ? "PT" : "EN";
    var label = current === EN ? "Mudar para português" : "Switch to English";
    document.querySelectorAll(".lang-toggle").forEach(function (button) {
      if (button.textContent !== target) button.textContent = target;
      if (button.getAttribute("title") !== label) button.setAttribute("title", label);
      if (button.getAttribute("aria-label") !== label) button.setAttribute("aria-label", label);
    });
  }

  function apply() {
    ensureToggle();
    walkText(document.body);
    translateTitles(document.body);
    translateDays(document.body);
    translateDocumentTitle();
    updateToggle();
  }

  var scheduled = false;
  function schedule() {
    if (scheduled) return;
    scheduled = true;
    requestAnimationFrame(function () {
      scheduled = false;
      apply();
    });
  }

  function init() {
    var html = document.documentElement;
    html.setAttribute("data-lang", current);
    html.setAttribute("lang", current);
    apply();
    new MutationObserver(schedule).observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["title"]
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
