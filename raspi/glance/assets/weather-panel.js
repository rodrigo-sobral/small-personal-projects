/* Interactive weather panel.
 *
 * Replaces the built-in weather widget and the separate 7-day forecast with a
 * single panel: current conditions at the top, then a row of day tabs for
 * today + the next 7 days. Selecting a tab shows that day's 2-hourly forecast.
 *
 * Mounted on a plain <div id="glance-weather"> supplied by
 * widgets/weather-panel.yml. Data comes straight from Open-Meteo in the browser
 * (it is a keyless, CORS-enabled API).
 */
(function () {
  "use strict";

  var MOUNT_ID = "glance-weather";
  var REFRESH_MS = 30 * 60 * 1000;
  var DAYS = 8;
  var HOURS_PER_DAY = 24;
  var STEP = 2; // show a column every 2 hours

  // WMO weather codes, mirroring Glance's own table so the i18n map applies.
  var WMO = {
    0: { label: "Clear Sky", icon: "☀️", night: "🌙" },
    1: { label: "Mainly Clear", icon: "🌤️", night: "🌙" },
    2: { label: "Partly Cloudy", icon: "⛅", night: "☁️" },
    3: { label: "Overcast", icon: "☁️" },
    45: { label: "Fog", icon: "🌫️" },
    48: { label: "Rime Fog", icon: "🌫️" },
    51: { label: "Drizzle", icon: "🌦️" },
    53: { label: "Drizzle", icon: "🌦️" },
    55: { label: "Drizzle", icon: "🌧️" },
    56: { label: "Drizzle", icon: "🌦️" },
    57: { label: "Drizzle", icon: "🌧️" },
    61: { label: "Rain", icon: "🌧️" },
    63: { label: "Moderate Rain", icon: "🌧️" },
    65: { label: "Heavy Rain", icon: "🌧️" },
    66: { label: "Freezing Rain", icon: "🌧️" },
    67: { label: "Freezing Rain", icon: "🌧️" },
    71: { label: "Snow", icon: "🌨️" },
    73: { label: "Moderate Snow", icon: "🌨️" },
    75: { label: "Heavy Snow", icon: "🌨️" },
    77: { label: "Snow Grains", icon: "🌨️" },
    80: { label: "Rain", icon: "🌦️" },
    81: { label: "Moderate Rain", icon: "🌧️" },
    82: { label: "Heavy Rain", icon: "🌧️" },
    85: { label: "Snow", icon: "🌨️" },
    86: { label: "Snow", icon: "🌨️" },
    95: { label: "Thunderstorm", icon: "⛈️" },
    96: { label: "Thunderstorm", icon: "⛈️" },
    99: { label: "Thunderstorm", icon: "⛈️" }
  };

  var selected = 0; // persisted across re-renders
  var cache = null; // { place, forecast, fetchedAt }

  function t(value) { return window.glanceI18n ? window.glanceI18n.t(value) : value; }
  function locale() { return window.glanceI18n && window.glanceI18n.lang() === "pt-PT" ? "pt-PT" : "en-US"; }
  function escapeHtml(value) {
    return String(value).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function round(value) { return Math.round(Number(value)); }
  function getJson(url) {
    return fetch(url, { headers: { Accept: "application/json" } }).then(function (response) {
      if (!response.ok) throw new Error("HTTP " + response.status);
      return response.json();
    });
  }

  function load(location, units) {
    var geoUrl = "https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&format=json&name=" +
      encodeURIComponent(location);
    return getJson(geoUrl).then(function (geo) {
      if (!geo.results || !geo.results.length) throw new Error("Location not found");
      var place = geo.results[0];
      var params = [
        "latitude=" + place.latitude,
        "longitude=" + place.longitude,
        "current=temperature_2m,apparent_temperature,weather_code,is_day",
        "hourly=temperature_2m,weather_code,precipitation_probability,is_day",
        "daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset",
        "timezone=auto",
        "forecast_days=" + DAYS,
        "temperature_unit=" + (units === "imperial" ? "fahrenheit" : "celsius")
      ];
      return getJson("https://api.open-meteo.com/v1/forecast?" + params.join("&")).then(function (forecast) {
        return { place: place, forecast: forecast };
      });
    });
  }

  function condition(code, isDay) {
    var entry = WMO[code] || { label: "", icon: "❓" };
    return { label: t(entry.label), icon: (!isDay && entry.night) ? entry.night : entry.icon };
  }

  function hourFraction(iso) {
    var time = iso.split("T")[1] || "00:00";
    var parts = time.split(":");
    return Number(parts[0]) + Number(parts[1]) / 60;
  }

  function dayTempRange(temps, dayIndex) {
    var start = dayIndex * HOURS_PER_DAY;
    var min = Infinity, max = -Infinity;
    for (var i = 0; i < HOURS_PER_DAY; i++) {
      var v = Number(temps[start + i]);
      if (isNaN(v)) continue;
      if (v < min) min = v;
      if (v > max) max = v;
    }
    if (min === Infinity) { min = 0; max = 1; }
    return { min: min, max: max };
  }

  function currentBlock(data) {
    var cur = data.forecast.current;
    var c = condition(cur.weather_code, cur.is_day);
    var temp = round(cur.temperature_2m);
    var feels = round(cur.apparent_temperature);
    return (
      '<div class="wx-now">' +
        '<div class="wx-now-icon" aria-hidden="true">' + c.icon + '</div>' +
        '<div class="wx-now-main">' +
          '<div class="wx-now-temp">' + temp + '°</div>' +
          '<div class="wx-now-cond">' + escapeHtml(c.label) + '</div>' +
          '<div class="wx-now-feels">' + escapeHtml(t("Feels like")) + " " + feels + '°</div>' +
        '</div>' +
      '</div>' +
      '<div class="wx-place">' + escapeHtml(data.place.name + ", " + data.place.country) + '</div>'
    );
  }

  function tabsBlock(data) {
    var daily = data.forecast.daily;
    var html = '<div class="wx-tabs" role="tablist">';
    for (var i = 0; i < DAYS; i++) {
      var c = condition(daily.weather_code[i], 1);
      var date = new Date(daily.time[i] + "T12:00:00");
      var label = i === 0 ? t("Today") : date.toLocaleDateString(locale(), { weekday: "short" });
      html +=
        '<button type="button" class="wx-tab' + (i === selected ? " is-active" : "") + '" data-day="' + i + '" role="tab" aria-selected="' + (i === selected) + '">' +
          '<span class="wx-tab-dow">' + escapeHtml(label) + '</span>' +
          '<span class="wx-tab-icon" aria-hidden="true">' + c.icon + '</span>' +
          '<span class="wx-tab-temps"><span class="wx-max">' + round(daily.temperature_2m_max[i]) + '°</span><span class="wx-min">' + round(daily.temperature_2m_min[i]) + '°</span></span>' +
        '</button>';
    }
    return html + '</div>';
  }

  function panelBlock(data) {
    var hourly = data.forecast.hourly;
    var daily = data.forecast.daily;
    var day = selected;
    var start = day * HOURS_PER_DAY;
    var range = dayTempRange(hourly.temperature_2m, day);
    var span = Math.max(1, range.max - range.min);
    var sunrise = hourFraction(daily.sunrise[day]);
    var sunset = hourFraction(daily.sunset[day]);
    var nowHour = -1;
    if (day === 0 && data.forecast.current && data.forecast.current.time) {
      nowHour = Number(data.forecast.current.time.split("T")[1].split(":")[0]);
    }

    var html = '<div class="wx-hours">';
    for (var k = 0; k < HOURS_PER_DAY; k += STEP) {
      var index = start + k;
      var temp = Number(hourly.temperature_2m[index]);
      var code = hourly.weather_code[index];
      var isDay = hourly.is_day[index];
      var precip = Number(hourly.precipitation_probability[index] || 0);
      var c = condition(code, isDay);
      var height = Math.max(8, Math.round(((temp - range.min) / span) * 100));
      var center = k + STEP / 2;
      var classes = "wx-hour";
      if (center > sunrise && center < sunset) classes += " wx-daylight";
      if (nowHour >= k && nowHour < k + STEP) classes += " wx-now-col";
      var hourLabel = (k < 10 ? "0" : "") + k;
      html +=
        '<div class="' + classes + '">' +
          '<div class="wx-h-temp">' + round(temp) + '°</div>' +
          '<div class="wx-h-track"><div class="wx-h-bar" style="height:' + height + '%"></div></div>' +
          '<div class="wx-h-icon" aria-hidden="true">' + c.icon + '</div>' +
          '<div class="wx-h-time">' + hourLabel + '</div>' +
          '<div class="wx-h-precip' + (precip >= 20 ? " show" : "") + '">' + round(precip) + '%</div>' +
        '</div>';
    }
    return html + '</div>';
  }

  function render(mount) {
    if (!cache) {
      mount.innerHTML = '<div class="wx-status">' + escapeHtml(t("Loading weather…")) + '</div>';
      return;
    }
    mount.innerHTML = currentBlock(cache) + tabsBlock(cache) + panelBlock(cache);
  }

  function refresh(mount) {
    var fresh = cache && Date.now() - cache.fetchedAt < REFRESH_MS;
    if (fresh) { render(mount); return; }
    mount.innerHTML = '<div class="wx-status">' + escapeHtml(t("Loading weather…")) + '</div>';
    load(mount.getAttribute("data-location") || "", mount.getAttribute("data-units") || "metric")
      .then(function (result) {
        result.fetchedAt = Date.now();
        cache = result;
        var current = document.getElementById(MOUNT_ID);
        if (current) render(current);
      })
      .catch(function (error) {
        var current = document.getElementById(MOUNT_ID);
        if (current) current.innerHTML = '<div class="wx-status wx-error">' + escapeHtml(error.message || String(error)) + '</div>';
      });
  }

  function ensure() {
    var mount = document.getElementById(MOUNT_ID);
    if (!mount || mount.dataset.wxReady === "1") return;
    mount.dataset.wxReady = "1";
    mount.classList.add("glance-wx");
    refresh(mount);
  }

  function injectStyle() {
    if (document.getElementById("glance-wx-style")) return;
    var style = document.createElement("style");
    style.id = "glance-wx-style";
    style.textContent =
      ".glance-wx{--wx-radius:6px;}" +
      ".wx-now{display:flex;align-items:center;gap:12px;}" +
      ".wx-now-icon{font-size:2.6rem;line-height:1;}" +
      ".wx-now-temp{font-size:2.4rem;font-weight:600;color:var(--color-text-highlight);line-height:1.1;}" +
      ".wx-now-cond{color:var(--color-text-highlight);}" +
      ".wx-now-feels{color:var(--color-text-subdue);font-size:1.15rem;}" +
      ".wx-place{color:var(--color-text-subdue);font-size:1.1rem;margin-top:8px;}" +
      ".wx-tabs{display:flex;flex-wrap:wrap;gap:4px;margin-top:12px;}" +
      ".wx-tab{flex:1 0 22%;background:transparent;border:1px solid var(--color-separator);border-radius:var(--wx-radius);padding:5px 4px;color:var(--color-text-subdue);cursor:pointer;display:flex;flex-direction:column;align-items:center;gap:1px;font:inherit;}" +
      ".wx-tab:hover{border-color:var(--color-text-subdue);}" +
      ".wx-tab.is-active{border-color:var(--color-primary);color:var(--color-text-highlight);background:var(--color-widget-background-highlight);}" +
      ".wx-tab-dow{font-size:1.05rem;text-transform:uppercase;letter-spacing:.03em;}" +
      ".wx-tab-icon{font-size:1.5rem;line-height:1.2;}" +
      ".wx-tab-temps{display:flex;gap:5px;font-size:1.15rem;}" +
      ".wx-tab-temps .wx-min{color:var(--color-text-subdue);}" +
      ".wx-hours{display:flex;justify-content:space-between;gap:2px;margin-top:14px;}" +
      ".wx-hour{position:relative;flex:1 1 0;min-width:0;display:flex;flex-direction:column;align-items:center;gap:2px;padding:4px 0 2px;border-radius:var(--wx-radius);}" +
      ".wx-hour.wx-daylight{background:rgba(240,192,64,.16);}" +
      ".wx-hour.wx-now-col{outline:1px solid var(--color-primary);}" +
      ".wx-h-time{font-size:1rem;color:var(--color-text-subdue);}" +
      ".wx-h-icon{font-size:1.35rem;line-height:1;}" +
      ".wx-h-temp{font-size:1.15rem;color:var(--color-text-highlight);}" +
      ".wx-h-track{position:relative;width:6px;height:54px;display:flex;align-items:flex-end;}" +
      ".wx-h-bar{width:100%;border-radius:3px;background:linear-gradient(to top,var(--color-positive),var(--color-primary));min-height:4px;}" +
      ".wx-h-precip{font-size:.95rem;color:var(--color-primary);visibility:hidden;}" +
      ".wx-h-precip.show{visibility:visible;}" +
      ".wx-status{color:var(--color-text-subdue);padding:6px 0;}" +
      ".wx-error{color:var(--color-negative);}";
    document.head.appendChild(style);
  }

  function init() {
    injectStyle();
    ensure();
    document.addEventListener("click", function (event) {
      var tab = event.target.closest && event.target.closest(".wx-tab");
      if (!tab) return;
      var index = parseInt(tab.getAttribute("data-day"), 10);
      if (isNaN(index)) return;
      selected = index;
      var mount = document.getElementById(MOUNT_ID);
      if (mount && cache) render(mount);
    });
    document.addEventListener("glance-lang-change", function () {
      var mount = document.getElementById(MOUNT_ID);
      if (mount && cache) render(mount);
    });
    new MutationObserver(ensure).observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
