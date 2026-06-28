# 35 — Universal set production run + glyph provenance (Part 1 close)

## Goal

Run `ucode universal-set build 17.0.0` end-to-end with the curated
coverage matrix (TODO 32) and acquired fonts (TODO 33). Produce one
SVG glyph per assigned Unicode 17 codepoint (~299,382 files), plus
a manifest tracking which Tier 1 source produced each glyph.

Output goes under `output/universal_glyph_set/`:

```
output/universal_glyph_set/
  manifest.json                # version, counts, generated_at
  entries/
    U+0041.json                # { cp, source: { kind, label, tier }, sha256, ... }
    U+0042.json
    ...
  glyphs/
    U+0041.svg
    U+0042.svg
    ...
```

The manifest is the **glyph provenance** record — for every glyph,
which font (or pillar 2 PDF, or Last Resort) produced it. This is
what fontist.org's char page surfaces as "this glyph came from
NotoSerifTaiYo, OFL, version 1.0".

## Why a separate TODO

TODO 31 built the production infrastructure (`universal-set build` +
`validate` commands). It hasn't actually run against a complete
font set — every prior attempt failed at pre-check because fonts
were missing.

With TODO 32 (policy) and TODO 33 (acquisition) done, the production
run becomes possible. This TODO is the integration test: does the
end-to-end pipeline produce a complete, validated, provenance-tracked
universal set?

## Scope

### Phase A — Pre-check green

1. Run `ucode universal-set pre-check 17.0.0`. Must report zero
   missing fonts. If anything's still missing, bounce back to
   TODO 33.

2. Capture the pre-check report as a fixture under
   `spec/fixtures/universal_set/pre_check_17.json`. Future
   regressions are caught by diffing against this.

### Phase B — Full build

3. Run `ucode universal-set build 17.0.0 --to=./output/universal_glyph_set`.
   Expected duration: ~30–60 minutes for 299,382 glyphs (dependent
   on font cache warmth and pillar 2 PDF rendering for blocks that
   need it).

4. Capture build metrics:
   - Total codepoints processed
   - Per-tier breakdown (Tier 1 / Pillar 1 / Pillar 2 / Pillar 3)
   - Per-block coverage %
   - Wall-clock time

5. Validate: `ucode universal-set validate ./output/universal_glyph_set`.
   Must pass every check:
   - manifest_loadable
   - glyph_files_present (every codepoint has an SVG)
   - totals_reconcile (manifest counts match file counts)
   - provenance_complete (every entry has a source)
   - structural_yaml_valid

### Phase C — Provenance surfacing

6. Extend the manifest schema to include per-entry provenance that
   fontist.org can render. Each `entries/U+XXXX.json` carries:

   ```json
   {
     "cp": 65,
     "id": "U+0041",
     "block_id": "Basic_Latin",
     "source": {
       "tier": 1,
       "kind": "fontist",
       "label": "noto-sans",
       "version": "...",
       "license": "OFL"
     },
     "sha256": "...",
     "extracted_at": "2026-..."
   }
   ```

7. Pillar 2 entries carry:
   ```json
   {
     "source": {
       "tier": 2,
       "kind": "pdf_charts",
       "pdf_url": "https://www.unicode.org/charts/PDF/U1E6C0.pdf",
       "pdf_sha256": "...",
       "cid": 41
     }
   }
   ```

8. Pillar 3 entries (Last Resort tofu) carry:
   ```json
   {
     "source": {
       "tier": 3,
       "kind": "last_resort",
       "label": "Last Resort Font"
     }
   }
   ```

### Phase D — HTML browser

9. Generate `output/universal_glyph_set/index.html` — a static page
   summarizing the build:

   - Top-level stats (total codepoints, per-tier pie chart)
   - Per-block table with coverage % and a sample of glyphs
   - Click a glyph → see full provenance

   Reuse the existing audit browser generator (`ucode audit browser`)
   pattern. Output is dev-server-friendly — no JS build required.

### Phase E — Idempotency

10. Re-run the build without changing inputs. Every file must be
    byte-identical (mtime unchanged). The existing `Idempotency`
    module handles this; just verify it holds end-to-end.

11. Re-run after touching one font (re-fetch Lentariso at the same
    version). Only that font's glyphs should rewrite.

## Acceptance

- [ ] `output/universal_glyph_set/` exists with `manifest.json` +
      `entries/` + `glyphs/`
- [ ] 299,382+ glyph SVGs present (one per assigned codepoint)
- [ ] 0 pillar 3 fallbacks for blocks with known Tier 1 sources
- [ ] `universal-set validate` exits 0
- [ ] HTML browser renders locally with no JS errors
- [ ] Re-running build is a byte-identical no-op
- [ ] Provenance JSON for U+0041 (Tier 1 noto-sans) and U+1E6C0
      (Tier 1 NotoSerifTaiYo) and at least one pillar 2 entry

## References

- [TODO 24](24-universal-glyph-set-build.md) — build infrastructure
- [TODO 31](31-universal-set-production-build.md) — production design
- [TODO 32](32-uc17-coverage-matrix.md) — input policy
- [TODO 33](33-specialist-font-acquisition-refresh.md) — input fonts
- [TODO 38](38-fontist-org-glyph-consumer.md) — consumer wiring
