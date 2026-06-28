# 14 — fontisan table writers: real serialization for every required table

## Goal

Implement the per-table writer classes referenced by TODO 13. After
this TODO, `Fontisan::FontWriter#write_to(path)` produces a valid
TTF file that opens in any font consumer.

## Scope

One class per OpenType table, all under `Fontisan::FontWriter::Tables::*`:

### `Tables::Head`
- 35 fixed fields; writes the canonical head structure
- Uses `BinData`-style binary packing (or `pack("...")` templates)

### `Tables::Hhea` + `Tables::Hmtx`
- Hhea: 18 fixed fields
- Hmtx: per-glyph advanceWidth + lsb (long or short record based on glyph count)

### `Tables::Maxp`
- TrueType: 16 fields; numGlyphs populated from FontModel
- CFF: 5 fields

### `Tables::Name`
- Multi-record: name_id × platform_id × encoding_id × language_id
- Standard name_ids: 0=copyright, 1=family, 2=subfamily, 4=full name,
  5=version, 6=PostScript name

### `Tables::OS2`
- 60+ fields (varies by version: v0=58, v5=68)
- Includes the 4 ulUnicodeRange bitfields (computed from FontModel.cmap)

### `Tables::Post`
- Glyph names table; format 2 is most flexible
- Per-glyph PostScript name index

### `Tables::Cmap`
- Subtable 4 (BMP, format 4) — segment mapping to delta
- Subtable 12 (full Unicode, format 12) — sparse groups
- Spliced into a single cmap table with proper platform/encoding headers

### `Tables::Glyf` + `Tables::Loca`
- TrueType outline serialization: contour count → endpoints → flags → x-coords → y-coords → instructions
- Composite glyphs (referencing other glyphs by GID) supported
- Loca: offsets into glyf (short format if all glyphs fit in 2-byte words, long otherwise)

### `Tables::Assembler`
- Computes table order (head + hhea + maxp + os2 + hmtx + cmap + post + loca + glyf + name)
- Writes offset table + table directory
- Aligns each table to 4-byte boundaries
- Computes checksums per table + the head checkSumAdjustment

## Acceptance

- [ ] Each table class exists with `#bytes(model)` returning a String
- [ ] `Tables::Assembler#write(path)` produces a TTF that opens via `Fontisan::Font.open`
- [ ] All fields validate against the OpenType spec
- [ ] Composite glyphs serialize correctly
- [ ] Per-table specs cover edge cases (empty font, single glyph, full Unicode range)
- [ ] Uses Ruby autoload

## References

- [TODO.full/13](13-fontisan-font-writer-api.md) — API design
- OpenType spec (per-table reference)
