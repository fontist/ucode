// ucode audit library browser — vanilla JS.
// Renders a card grid with search/sort/filter.

(function () {
  "use strict";

  var data = JSON.parse(
    document.getElementById("library-overview").textContent
  );

  var state = {
    search: "",
    sort: "name",
    status: "",
  };

  renderTagline();
  renderCards();

  document.getElementById("filter-search").addEventListener("input", function (e) {
    state.search = e.target.value.toLowerCase();
    renderCards();
  });
  document.getElementById("sort-select").addEventListener("change", function (e) {
    state.sort = e.target.value;
    renderCards();
  });
  document.getElementById("status-select").addEventListener("change", function (e) {
    state.status = e.target.value;
    renderCards();
  });

  function renderTagline() {
    var metrics = data.aggregate_metrics || {};
    var tagline = document.getElementById("library-tagline");
    tagline.textContent =
      (data.total_faces || 0) + " faces across " +
      (data.total_files || 0) + " source files · " +
      (metrics.total_codepoints || 0) + " codepoints (with duplicates)";
  }

  function renderCards() {
    var faces = (data.faces || []).filter(matchesFilter).sort(bySort);
    var container = document.getElementById("cards");
    container.setAttribute("aria-busy", "false");

    if (!faces.length) {
      container.innerHTML = '<p class="empty">No fonts match the current filter.</p>';
      return;
    }
    container.innerHTML = '<div class="cards">' + faces.map(renderCard).join("") + '</div>';
  }

  function renderCard(face) {
    var pct = (face.total_assigned_total && face.covered_total) ?
              (face.covered_total / face.total_assigned_total * 100) : 0;
    var badges = [];
    if (face.blocks_complete) badges.push('<span class="badge">' + face.blocks_complete + ' complete</span>');
    if (face.blocks_partial)  badges.push('<span class="badge">' + face.blocks_partial + ' partial</span>');

    var stats = (face.total_codepoints || 0).toLocaleString() + " cps";
    if (face.total_glyphs) stats += " · " + face.total_glyphs.toLocaleString() + " glyphs";

    return '<a class="font-card" href="' + escapeAttr(face.index_path) + '">' +
      '<h3 class="font-name">' + escapeHtml(face.family_name || face.label) + '</h3>' +
      '<p class="font-meta">' + escapeHtml(face.postscript_name || "") + ' · wght ' +
      (face.weight_class || 400) + '</p>' +
      '<div class="coverage-bar"><div style="width:' + pct.toFixed(1) + '%"></div></div>' +
      '<p class="quick-stats">' + stats + '</p>' +
      '<div class="badges">' + badges.join("") + '</div>' +
      '</a>';
  }

  function matchesFilter(face) {
    if (state.status === "complete" && !face.blocks_complete) return false;
    if (state.status === "partial" && !face.blocks_partial) return false;
    if (!state.search) return true;
    var haystack = ((face.family_name || "") + " " +
                    (face.postscript_name || "") + " " +
                    (face.label || "")).toLowerCase();
    return haystack.indexOf(state.search) !== -1;
  }

  function bySort(a, b) {
    var key = state.sort;
    if (key === "name") return (a.family_name || "").localeCompare(b.family_name || "");
    if (key === "codepoints") return (b.total_codepoints || 0) - (a.total_codepoints || 0);
    if (key === "glyphs") return (b.total_glyphs || 0) - (a.total_glyphs || 0);
    if (key === "weight") return (a.weight_class || 0) - (b.weight_class || 0);
    return 0;
  }

  function escapeHtml(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function escapeAttr(s) { return escapeHtml(s); }
})();
