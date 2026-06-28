// ucode audit face browser — vanilla JS, no dependencies.
// Reads inlined overview JSON, renders header + plane band + block table.
// Lazy-fetches per-block chunk on row click.

(function () {
  "use strict";

  var overview = JSON.parse(
    document.getElementById("audit-overview").textContent
  );
  var verbose = document.body.dataset.verbose === "true";
  var withGlyphs = document.body.dataset.withGlyphs === "true";
  var universalSet = {
    available: document.body.dataset.universalSetAvailable === "true",
    glyphsDir: document.body.dataset.universalSetGlyphsDir || "",
    manifestPath: document.body.dataset.universalSetManifestPath || ""
  };
  var chunkCache = new Map();
  var glyphCache = new Map();

  // Detect file:// — fetches blocked in some browsers
  if (location.protocol === "file:") {
    document.getElementById("file-url-hint").classList.remove("hidden");
  }

  renderOverview();
  renderBlocks();
  renderDiscrepancies();

  function renderOverview() {
    var font = overview.font || {};
    var baseline = overview.baseline || {};
    var totals = overview.totals || {};

    var html = '<div class="card">';
    html += '<dl class="identity-grid">';
    html += dt("PostScript name", font.postscript_name);
    html += dt("Family", font.family_name);
    html += dt("Subfamily", font.subfamily_name);
    html += dt("Version", font.version);
    html += dt("Source file", font.source_file);
    html += dt("SHA-256", font.source_sha256);
    html += dt("Baseline Unicode", baseline.unicode_version);
    html += dt("Generated", overview.generated_at);
    html += '</dl>';
    html += '<div class="totals">';
    html += cell("Codepoints covered", totals.covered_codepoints_total);
    html += cell("Blocks touched", totals.blocks_touched);
    html += cell("Complete", totals.blocks_complete);
    html += cell("Partial", totals.blocks_partial);
    html += cell("Scripts touched", totals.scripts_touched);
    html += '</div>';
    html += '</div>';

    document.getElementById("overview").innerHTML = html;
  }

  function renderBlocks() {
    var blocks = overview.block_summaries || [];
    if (!blocks.length) {
      document.getElementById("blocks").innerHTML = "";
      return;
    }
    var html = '<h2>Blocks</h2>';
    html += '<table class="block-table"><thead><tr>';
    html += '<th>Block</th><th class="num">Range</th>';
    html += '<th class="num">Covered</th><th class="num">Total</th>';
    html += '<th class="num">%</th><th>Status</th>';
    html += '</tr></thead><tbody>';
    blocks.forEach(function (block, i) {
      var name = escapeAttr(block.name);
      html += '<tr class="block-row" data-block="' + name + '" data-index="' + i + '">';
      html += '<td>' + escapeHtml(block.name) + '</td>';
      html += '<td class="num">' + escapeHtml(block.range || '') + '</td>';
      html += '<td class="num">' + escapeHtml(block.covered_count) + '</td>';
      html += '<td class="num">' + escapeHtml(block.total_assigned) + '</td>';
      html += '<td class="num">' + escapeHtml((block.coverage_percent || 0).toFixed(1)) + '%</td>';
      html += '<td><span class="status status-' + escapeAttr(block.status) + '">' +
              escapeHtml(block.status) + '</span></td>';
      html += '</tr>';
      html += '<tr class="block-detail hidden" data-detail-for="' + name + '"><td colspan="6"></td></tr>';
    });
    html += '</tbody></table>';
    document.getElementById("blocks").innerHTML = html;

    Array.prototype.forEach.call(
      document.querySelectorAll(".block-row"),
      function (row) {
        row.addEventListener("click", onBlockRowClick);
      }
    );
  }

  function renderDiscrepancies() {
    var discrepancies = overview.discrepancies || [];
    if (!discrepancies.length) return;

    var html = '<h2>Discrepancies</h2>';
    html += '<ul class="discrepancies-list">';
    discrepancies.forEach(function (d) {
      html += '<li><span class="kind">' + escapeHtml(d.kind) + '</span> — ' +
              escapeHtml(d.detail || '') + '</li>';
    });
    html += '</ul>';
    var section = document.getElementById("discrepancies");
    section.innerHTML = html;
    section.classList.remove("hidden");
  }

  function onBlockRowClick(event) {
    var row = event.currentTarget;
    var blockName = row.dataset.block;
    var detailRow = document.querySelector(
      '.block-detail[data-detail-for="' + blockName + '"]'
    );
    var cell = detailRow.querySelector("td");

    if (!detailRow.classList.contains("hidden")) {
      detailRow.classList.add("hidden");
      return;
    }
    detailRow.classList.remove("hidden");

    var block = overview.block_summaries[parseInt(row.dataset.index, 10)];
    cell.innerHTML = renderMissingChips(block);
    if (verbose || withGlyphs) {
      fetchBlockChunk(blockName).then(function (chunk) {
        cell.innerHTML = renderExpandedBlock(block, chunk);
        wireChipClicks(cell);
      }).catch(function () {
        // 404 or fetch blocked — keep the basic missing-chips view.
      });
    }
  }

  function renderMissingChips(block) {
    var missing = block.missing_codepoints || [];
    var html = '<p class="hint">Missing (' + escapeHtml(missing.length) + "):</p>";
    if (!missing.length) return html;
    html += '<div class="cp-chips">';
    missing.slice(0, 200).forEach(function (cp) {
      var cpInt = parseInt(cp, 10);
      var cpHex = isNaN(cpInt) ? "" : cpInt.toString(16).toUpperCase().padStart(4, "0");
      var glyphAttr = universalSet.available
        ? ' data-show-glyph="1"'
        : "";
      html += '<span class="cp-chip" data-cp="' + escapeAttr(cpInt) + '"' + glyphAttr + ">U+" +
              escapeHtml(cpHex) + "</span>";
    });
    if (missing.length > 200) {
      html += '<span class="cp-chip">… +' + escapeHtml(missing.length - 200) + " more</span>";
    }
    html += "</div>";
    return html;
  }

  function renderExpandedBlock(block, chunk) {
    var html = renderMissingChips(block);
    if (verbose && chunk && chunk.codepoints) {
      html += '<p class="hint">Verbose detail available — click a chip.</p>';
    }
    return html;
  }

  function wireChipClicks(container) {
    Array.prototype.forEach.call(
      container.querySelectorAll(".cp-chip[data-cp]"),
      function (chip) {
        chip.addEventListener("click", onChipClick);
      }
    );
  }

  function onChipClick(event) {
    var cp = parseInt(event.currentTarget.dataset.cp, 10);
    var blockName = event.currentTarget.closest("[data-detail-for]").dataset.detailFor;
    showDetail(cp, blockName);
  }

  function showDetail(cp, blockName) {
    var panel = document.getElementById("detail");
    panel.classList.remove("hidden");

    fetchCodepointChunk(blockName).then(function (chunk) {
      var detail = (chunk.codepoints || []).find(function (row) {
        return row.codepoint === cp;
      });
      if (!detail) {
        panel.innerHTML = '<div class="detail-panel">No detail for U+' +
                          escapeHtml(cp.toString(16).toUpperCase()) + "</div>";
        return;
      }
      var html = '<div class="detail-panel"><dl class="identity-grid">';
      html += dt("Codepoint", "U+" + cp.toString(16).toUpperCase().padStart(4, "0"));
      html += dt("Name", detail.name || "(unknown)");
      html += dt("General category", detail.general_category || "");
      html += dt("Script", detail.script || "");
      html += dt("Block", detail.block_name || blockName);
      html += dt("Age", detail.age || "");
      html += "</dl>";
      if (withGlyphs && detail.glyph_svg_path) {
        html += '<div class="glyph-preview" id="glyph-preview"></div>';
      }
      if (universalSet.available) {
        html += '<div class="glyph-preview universal-set-preview" id="universal-set-glyph">';
        html += '<p class="hint">Universal-set glyph (this font is missing this codepoint):</p>';
        html += "</div>";
      }
      html += "</div>";
      panel.innerHTML = html;
      if (withGlyphs && detail.glyph_svg_path) {
        fetchGlyph(detail.glyph_svg_path);
      }
      if (universalSet.available) {
        fetchUniversalSetGlyph(cp);
      }
    }).catch(function () {
      panel.innerHTML = '<div class="detail-panel">Detail fetch failed.</div>';
    });
  }

  function fetchGlyph(path) {
    fetchLocal(path).then(function (svg) {
      var preview = document.getElementById("glyph-preview");
      if (preview) preview.innerHTML = svg;
    }).catch(function () {});
  }

  function fetchUniversalSetGlyph(cp) {
    var hex = cp.toString(16).toUpperCase().padStart(4, "0");
    var path = universalSet.glyphsDir + "U+" + hex + ".svg";
    if (glyphCache.has(path)) {
      renderUniversalSetGlyph(path);
      return;
    }
    fetch(path)
      .then(function (res) {
        if (!res.ok) throw new Error("HTTP " + res.status);
        return res.text();
      })
      .then(function (svg) {
        glyphCache.set(path, svg);
        renderUniversalSetGlyph(path);
      })
      .catch(function () {
        var slot = document.getElementById("universal-set-glyph");
        if (slot) {
          slot.innerHTML = '<p class="hint">No universal-set glyph at U+' + escapeHtml(hex) + ".</p>";
        }
      });
  }

  function renderUniversalSetGlyph(path) {
    var slot = document.getElementById("universal-set-glyph");
    if (slot) slot.innerHTML = glyphCache.get(path);
  }

  function fetchBlockChunk(blockName) {
    return fetchLocal("blocks/" + blockName + ".json");
  }

  function fetchCodepointChunk(blockName) {
    return fetchLocal("codepoints/" + blockName + ".json");
  }

  function fetchLocal(path) {
    if (chunkCache.has(path)) {
      return Promise.resolve(chunkCache.get(path));
    }
    return fetch(path).then(function (res) {
      if (!res.ok) throw new Error("HTTP " + res.status);
      return res.json();
    }).then(function (data) {
      chunkCache.set(path, data);
      return data;
    });
  }

  // --- HTML helpers ----------------------------------------------------

  function dt(label, value) {
    return '<dt>' + escapeHtml(label) + '</dt><dd>' +
           escapeHtml(value == null ? '' : String(value)) + '</dd>';
  }
  function cell(label, value) {
    return '<div class="total-cell"><div class="label">' + escapeHtml(label) +
           '</div><div class="value">' + escapeHtml(value == null ? '' : String(value)) +
           '</div></div>';
  }
  function escapeHtml(s) {
    return String(s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function escapeAttr(s) {
    return escapeHtml(s).replace(/"/g, "&quot;");
  }
})();
