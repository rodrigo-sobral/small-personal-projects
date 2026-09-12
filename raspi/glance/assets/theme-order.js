/* Reorder the theme picker so the light presets sit at the end.
 *
 * Glance hard-codes two built-in presets and prepends them before any
 * user-defined ones: `default-dark` and `default-light`. There is no config
 * option to move them, so the very light `default-light` swatch ends up
 * sandwiched between the dark presets. This moves it to the end of every
 * `.theme-choices` container (the mobile list and the header clone).
 */
(function () {
  "use strict";

  var LIGHT = "default-light";

  function reorder() {
    document.querySelectorAll(".theme-choices").forEach(function (container) {
      var button = container.querySelector('.theme-preset[data-key="' + LIGHT + '"]');
      if (button && container.lastElementChild !== button) {
        container.appendChild(button);
      }
    });
  }

  function init() {
    reorder();
    // The header picker is a clone made by Glance's own JS after load, so keep
    // watching for (re)rendered .theme-choices.
    new MutationObserver(reorder).observe(document.body, {
      childList: true,
      subtree: true
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
