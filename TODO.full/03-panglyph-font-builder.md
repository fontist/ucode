# 03 — Panglyph font builder (outline extraction + assembly)

## Goal

Implement the actual font-build pipeline: read ucode's universal-set
manifest, extract outlines from Tier 1 source fonts via fontisan,
assemble them into a single OpenType/TrueType font, and write the
result to disk in TTF / WOFF2 / OTF formats.

This is the heart of panglyph. The CLI commands (`build`, `validate`,
`publish`) are thin wrappers around these classes.

## Architecture

```
ucode universal-set manifest
       │
       │ {cp: 65, source: {font: "noto-sans", gid: 36}}
       │ {cp: 19968, source: {font: "FSung-1", gid: 18432}}
       │ {cp: 128512, source: {font: "NotoSerifTaiYo", gid: 41}}
       │ ...
       ▼
┌──────────────────────────────────────────────┐
│  Builder                                     │
│  - reads manifest                            │
│  - groups codepoints by source font          │
│  - for each source font:                     │
│      OutlineExtractor.extract_many(font, cps)│
│  - passes {cp → outline} to FontAssembler    │
└──────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  FontAssembler                               │
│  - opens an empty font skeleton              │
│  - for each codepoint:                       │
│      - allocates a GID in panglyph           │
│      - writes the outline into glyf/CFF      │
│      - sets cmap[cp] = GID                   │
│  - finalizes: OS/2, name, head, hhea, hmtx   │
│  - writes panglyph-unicode17.ttf             │
└──────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  Woff2Writer (via fontisan ConvertCommand)   │
│  - reads the TTF                             │
│  - writes panglyph-unicode17.woff2           │
└──────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────┐
│  CoverageReport                              │
│  - summarizes per-block source breakdown     │
│  - writes coverage-report.json               │
└──────────────────────────────────────────────┘
```

## Scope

### Phase A — Outline extraction (`OutlineExtractor`)

1. **Open source font** via `Fontisan::Font.open(path)`.
2. **For each codepoint** in the source's responsibility list:
   a. Look up GID via `font.cmap.unicode_map[cp]`
   b. Get the outline:
      - TrueType: `font.glyf.glyphs[gid]` → contour points
      - CFF/OpenType: `font.cff.charstrings[gid]` → charstring program
   c. Normalize to a uniform internal representation
      (`Panglyph::Outline` struct with point arrays + flags).
3. **Return** `{ cp => Outline }` hash.

#### Edge cases

- **Composite glyphs** (TrueType): if a glyph references other glyphs
  via component references, recursively flatten into a single outline.
  Track "this glyph was a composite" in the report.
- **TTC collections**: pass `font_index:` to `Fontisan::Font.open`.
- **Missing cmap entry**: the Tier 1 font claims to cover this cp but
  its cmap doesn't actually map it. Log + skip; the universal set's
  pre-check (TODO.new/35) catches this upstream.

### Phase B — Font assembly (`FontAssembler`)

4. **Initialize an empty font skeleton** with the standard required
   tables: `cmap`, `head`, `hhea`, `hmtx`, `maxp`, `name`, `OS/2`,
   `glyf`, `loca`, `post`. (For OTF: `CFF ` instead of `glyf`/`loca`.)
5. **For each codepoint**:
   a. Allocate next GID (`maxp.numGlyphs += 1`).
   b. Write the outline to `glyf` (or `CFF `).
   c. Add `cmap` subtable 4 entry: `unicode_map[cp] = gid`.
   d. Add `hmtx` entry (advance width from source font; default 1000
      if missing).
   e. Add `name` entries — actually, only the font-family / version
      name needs to be set; per-glyph names aren't required.
6. **Finalize metadata**:
   - `name`: family="panglyph Unicode 17", subfamily="Regular",
     full="panglyph-unicode17", version="Version 17.0.0"
   - `OS/2`: usWeightClass=400, fsSelection=REGULAR, ulUnicodeRange1..4
     bit-packed for every range panglyph covers
   - `head`: unitsPerEm=1000 (or 2048 for CJK-heavy), lowestRecPPEM=8
   - `hhea`: numberOfHMetrics matches glyphs
7. **Compute checksums + write final TTF**.

#### fontisan extension required

fontisan today only READS fonts + converts (WOFF). It needs new APIs:

```ruby
# lib/fontisan/font_writer.rb (NEW)
class Fontisan::FontWriter
  def initialize(format: :ttf)
    @tables = {}
    @format = format
  end

  def set_cmap(unicode_to_gid_map)
    # ...
  end

  def add_glyph(gid, outline, advance_width: 1000, lsb: 0)
    # ...
  end

  def set_name_records(records)
    # ...
  end

  def write_to(path)
    # computes checksums, writes head/glyf/loca/cmap/etc.
  end
end
```

This is a meaningful fontisan addition. Tracked separately as a
fontisan TODO (see TODO.new/19 — fontisan docs update).

### Phase C — WOFF2 conversion (`Woff2Writer`)

8. Use `Fontisan::Commands::ConvertCommand.new(ttf_path, to: "woff2", output: ...)`.
   No new code needed; just shell out from panglyph.

### Phase D — Coverage report (`CoverageReport`)

9. Walk the built font's cmap.
10. Compare against ucode's universal-set codepoint list.
11. Bucket per-block + per-source-tier:
    ```json
    {
      "total_codepoints": 299382,
      "covered": 297415,
      "missing": 1967,
      "by_block": [
        { "block_id": "Egyptian_Hieroglyphs_Extended-B", "covered": 599, "missing": 1, "tier": 1 }
      ],
      "by_tier": [
        { "tier": 1, "count": 295000 },
        { "tier": 2, "count": 2415 },
        { "tier": 3, "count": 1967 }
      ]
    }
    ```

## Performance considerations

- 299,382 glyph extractions × ~1ms each = ~5 minutes of extraction.
- Parallelize per-source-font: each source font's extractions are
  independent, so use parallel gem or `Concurrent::Map`.
- Memory: hold all outlines in memory at once (~1.2GB estimated). May
  need to stream to disk for low-memory CI runners (use a temp sqlite
  database keyed by GID).

## Specs

- **Builder** — fixture: 5 codepoints from 2 source fonts; assert
  output font's cmap matches the manifest.
- **OutlineExtractor** — fixture: a real font with known glyf layout;
  assert extracted outline matches a known-good serialization.
- **FontAssembler** — fixture: 3 outlines; assert output TTF parses
  via `Fontisan::Font.open` and has the expected cmap.
- **Woff2Writer** — fixture: a known TTF; assert WOFF2 output
  byte-identical to a fontisan-direct conversion (sanity check).
- **CoverageReport** — fixture: a built font with intentional gaps;
  assert report correctly identifies missing codepoints.

## Acceptance

- [ ] `panglyph build 17.0.0` produces a valid TTF, WOFF2, and OTF
- [ ] The built font's cmap contains every codepoint in the universal
      set's manifest
- [ ] `fontisan Font.open(panglyph.ttf)` succeeds (no corruption)
- [ ] Coverage report JSON validates against schema
- [ ] Build completes in <30 minutes on a single runner
- [ ] Built font renders correctly in a browser (manual smoke test)

## References

- [TODO 01](01-panglyph-vision.md) — vision
- [TODO 02](02-panglyph-repo-bootstrap.md) — repo skeleton
- [TODO.new/24](../TODO.new/24-universal-glyph-set-build.md) — ucode's universal-set SVG output (panglyph input)
- fontisan Font.open API (for reading source fonts)
