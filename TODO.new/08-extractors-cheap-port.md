# 08 — Cheap extractors port

## Goal

Port the 5 cheap extractors from fontisan to ucode. These are the
"brief mode" extractors — fast, name-table-only path that doesn't need
UCD or expensive table loads. Plus the Coverage extractor (cheap, but
excluded from brief mode in fontisan because it needs cmap; in ucode we
keep it cheap because cmap is the Tier 1 foundation).

After this TODO, `Ucode::Audit::Registry.each(mode: :brief)` produces
a minimal-but-real audit report (identity + style + coverage totals,
no aggregations).

## Files to create

```
lib/ucode/audit/extractors/
├── base.rb               # port from fontisan
├── provenance.rb         # port from fontisan
├── identity.rb           # port from fontisan
├── style.rb              # port from fontisan (the older StyleExtractor, not the registry-listed Extractors::Style)
├── licensing.rb          # port from fontisan
└── coverage.rb           # port from fontisan
```

Plus update `lib/ucode/audit/registry.rb` to populate `BRIEF_EXTRACTORS`
and add these to `ORDERED_EXTRACTORS` (the latter stays incomplete
until TODO 09).

Specs: `spec/ucode/audit/extractors/<name>_spec.rb` for each.

## Port from fontisan

- `fontisan/lib/fontisan/audit/extractors/base.rb`
- `fontisan/lib/fontisan/audit/extractors/provenance.rb`
- `fontisan/lib/fontisan/audit/extractors/identity.rb`
- `fontisan/lib/fontisan/audit/extractors/style.rb`
- `fontisan/lib/fontisan/audit/extractors/licensing.rb`
- `fontisan/lib/fontisan/audit/extractors/coverage.rb`

## Adjustments vs fontisan

Each extractor returns a hash of `AuditReport` fields. The fontisan
versions read font tables via `Context#font.table(...)` — this stays
the same; ucode's `Context` still wraps a fontisan font handle.

### Provenance

- `fontisan_version` → `ucode_version` (read from `Ucode::VERSION`).
- Otherwise unchanged.

### Identity

- Unchanged. Reads `name` table via fontisan's public API.

### Style

- The standalone `StyleExtractor` class
  (`fontisan/lib/fontisan/audit/style_extractor.rb`) is older
  fontisan code. The registry-listed `Extractors::Style` is the newer
  thin version. Port the registry-listed version; do not port the
  standalone `StyleExtractor` class.
- Reads OS/2 + head via fontisan's public API. Same shape.

### Licensing

- Unchanged.

### Coverage

- Output `codepoints` field uses `"U+XXXX"` string form (per
  `02-audit-schema-design.md`).
- Output `codepoint_ranges` uses `CodepointRange` model — port the
  `CodepointRangeCoalescer` helper too (`fontisan/lib/fontisan/audit/codepoint_range_coalescer.rb`).
- Does **not** emit aggregations (blocks/scripts) — that's the
  Aggregations extractor in TODO 10. Coverage only emits the raw
  codepoint set.

## Boundary with fontisan

These extractors call **only** fontisan's public font-reading API:

- `fontisan_font.table("name")`
- `fontisan_font.table("OS/2")`
- `fontisan_font.table("head")`
- `fontisan_font.table("cmap")`
- `fontisan_font.sfnt_table("cmap").parse.unicode_mappings`

No reaching into `Fontisan::Constants`, no `send`, no
`instance_variable_get`. If a field needs a table fontisan doesn't
expose, file a fontisan-side issue; do not work around it in ucode.

## Acceptance

- All 6 extractor files exist; each has a passing spec with real
  fixture fonts (use `spec/fixtures/fonts/`).
- `Ucode::Audit::Registry.each(mode: :brief)` iterates these 5:
  `Provenance, Identity, Style, Licensing, Coverage`.
- A "brief audit" of a fixture font produces an `AuditReport` with
  provenance, identity, style, licensing, and coverage fields
  populated. Aggregation fields (`baseline`, `blocks`, `scripts`,
  `plane_summaries`) are nil.
- No `double()` in any spec.
- Rubocop clean.

## References

- Models: `TODO.new/07-audit-models-port.md`
- Source: `fontisan/lib/fontisan/audit/extractors/{base,provenance,identity,style,licensing,coverage}.rb`
- Coalescer helper: `fontisan/lib/fontisan/audit/codepoint_range_coalescer.rb`
- fontisan API boundary: `docs/architecture.md` §"Dependency arrows"
- Follow-up: `TODO.new/09-extractors-expensive-port.md`
