# 30. Repo — aggregate writers + indexes

**Goal**: Write the auxiliary JSON files: per-block, per-script, per-plane, and the
client-side lookup indexes (`names.json`, `labels.json`, `enums.json`).

**Depends on**: 29.

**Files**:
- `lib/ucode/repo/aggregate_writer.rb`
- `lib/ucode/repo/index_writer.rb` (or fold into aggregate_writer).
- Specs.

## Tasks

- [ ] Aggregate writers produce these files under `output/`:
  ```
  output/planes/<n>.json                              # 17 files
  output/blocks/<ID>.json                             # ~346 files (block metadata + member IDs)
  output/scripts/<code>.json                          # ~160 files
  output/named_sequences/<slug>.json                  # one per named sequence
  output/relationships/special_casing.json            # full table
  output/relationships/case_folding.json
  output/relationships/bidi_mirroring.json
  output/relationships/bidi_brackets.json
  output/relationships/cjk_radicals.json
  output/relationships/standardized_variants.json
  output/relationships/name_aliases.json
  output/enums.json                                   # property aliases + value aliases
  output/index/names.json                             # { cp_id: name } for search
  output/index/labels.json                            # { cp_id: { name, gc, sc } } for grids
  output/index/codepoint_to_block.json                # { cp_id: block_id }
  output/manifest.json                                # version, generated_at, codepoint_count
  ```
- [ ] All JSON via `model.to_hash` (lutaml-model) — no hand-rolled serialization.
- [ ] `manifest.json` records: `ucd_version`, `generated_at` (ISO8601), `codepoint_count`,
      `glyph_count`, `schema_version`.
- [ ] Streaming: each aggregate file is built by streaming Coordinator output, not by
      re-reading per-codepoint JSON.

## Acceptance criteria

- After a full run, `output/planes/0.json` contains `{"number":0, "name":"Basic
  Multilingual Plane", ...}` with all BMP block IDs listed.
- `output/index/names.json` has one entry per assigned codepoint.
- `output/enums.json` contains both `properties` and `property_values` keys, mapping
  short ↔ long for every alias.

## Architectural notes

- **Single pass for all aggregates**: Coordinator emits each CodePoint once; the
  aggregate writers attach as additional sinks alongside `CodepointWriter`. This avoids
  re-reading 160 k JSON files.
- **enums.json is the SSOT for client-side expansion**: the site loads it once and uses
  it to expand every short code (`Lu` → `Uppercase_Letter`).