# 13 — fontisan FontWriter: clean API for writing fonts from scratch

## Goal

Add a `Fontisan::FontWriter` class that lets callers assemble a new
font file (TTF/OTF) from scratch — cmap + glyf + name + metrics +
required housekeeping tables. This is the missing primitive panglyph
(TODO.full/03) needs to actually produce a font.

## Why this is a separate TODO

fontisan today only **reads** fonts (cmap walk, glyf extraction) and
**converts** between formats (TTF → WOFF via re-serialization of
existing tables). Neither path can build a new font from scratch.

panglyph needs to:
1. Read outlines from N source fonts (fontisan already can)
2. Write a single merged font with those outlines + a fresh cmap

Step 2 is the gap. This TODO fills it with a clean, well-abstracted API.

## Architectural principles

Following the project's quality bar:

### OCP — one class per table

Each OpenType table is its own writer class, registered in a single
dispatch. Adding a new table = adding a new class, NOT modifying
existing code.

```
Fontisan::FontWriter (orchestrator)
  └── Tables::* (one per OpenType table)
        ├── Head
        ├── Cmap
        ├── Name
        ├── Hmtx
        ├── Hhea
        ├── Glyf
        ├── Loca
        ├── Maxp
        ├── Os2
        └── Post
```

### MECE — single responsibility per class

- `FontWriter` — orchestrates; holds the in-memory font model
- `Tables::Head` — knows head table layout (35 fields, byte order)
- `Tables::Cmap` — knows cmap subtable formats (4 for BMP, 12 for full)
- `Tables::Glyf` — knows TrueType outline serialization
- etc.

### SSOT — table tags live in one place

`Fontisan::FontWriter::TABLE_TAGS` constant. Adding a new table =
adding to this constant; the orchestrator auto-discovers and calls
the right writer.

### Model-driven — typed structures, not hashes

Outline points, name records, metrics — all typed structs/classes.
No `attribute :foo, :hash` anywhere (per global rule).

## API design

```ruby
# lib/fontisan/font_writer.rb

module Fontisan
  class FontWriter
    autoload :Tables, "fontisan/font_writer/tables"
    autoload :FontModel, "fontisan/font_writer/font_model"
    autoload :Outline, "fontisan/font_writer/outline"
    autoload :NameRecord, "fontisan/font_writer/name_record"
    autoload :Metrics, "fontisan/font_writer/metrics"

    def initialize(format: :ttf)
      @format = format
      @model = FontModel.new
    end

    # @param unicode_map [Hash{Integer => Integer}] cp → gid
    def set_cmap(unicode_map)
      @model.cmap = unicode_map
    end

    # @param gid [Integer]
    # @param outline [Outline] points + flags
    # @param metrics [Metrics] advance width + lsb
    def add_glyph(gid, outline:, metrics:)
      @model.glyphs[gid] = GlyphEntry.new(outline: outline, metrics: metrics)
    end

    # @param records [Array<NameRecord>] language-tagged name records
    def set_name_records(records)
      @model.names = records
    end

    # @param version [String] e.g. "Version 17.0.0"
    def set_version(version)
      @model.font_version = version
    end

    # Writes the font to +path+ in the initialized format (ttf or otf).
    # @return [Pathname]
    def write_to(path)
      Tables::Assembler.new(@model, format: @format).write(path)
    end
  end
end
```

## Typed data structures

```ruby
# lib/fontisan/font_writer/outline.rb
class Fontisan::FontWriter::Outline < Struct.new(
  :contours, :instructions, :is_composite, keyword_init: true
)
  # contours: Array<Array<Point>>
  # instructions: String (byte stream) or nil
  # is_composite: bool — true if this glyph is a composite reference
end

# lib/fontisan/font_writer/point.rb
class Fontisan::FontWriter::Point < Struct.new(
  :x, :y, :on_curve, keyword_init: true
)
end

# lib/fontisan/font_writer/name_record.rb
class Fontisan::FontWriter::NameRecord < Struct.new(
  :name_id, :platform_id, :encoding_id, :language_id, :string, keyword_init: true
)
  # Standard name_ids per OpenType spec (0=family, 1=subfamily, etc.)
end

# lib/fontisan/font_writer/metrics.rb
class Fontisan::FontWriter::Metrics < Struct.new(
  :advance_width, :left_side_bearing, keyword_init: true
)
end

# lib/fontisan/font_writer/glyph_entry.rb
class Fontisan::FontWriter::GlyphEntry < Struct.new(
  :outline, :metrics, keyword_init: true
)
end
```

## Scope

### Phase A — Foundation (this TODO)

1. Define `Fontisan::FontWriter` class with the API above.
2. Define typed structs (Outline, Point, NameRecord, Metrics, GlyphEntry).
3. Define `FontModel` — internal in-memory representation.
4. Define `Tables::Assembler` — orchestrates table serialization.
5. Implement `Tables::Head` (writes a fixed head table — simplest case).

### Phase B — Real table writers (TODO.full/14)

6. Implement `Tables::Cmap` (formats 4 + 12).
7. Implement `Tables::Hmtx` + `Tables::Hhea` (metrics).
8. Implement `Tables::Glyf` + `Tables::Loca` (TrueType outlines).
9. Implement `Tables::Maxp`, `Tables::Os2`, `Tables::Post`, `Tables::Name`.

### Phase C — Validation

10. After writing, re-open with `Fontisan::Font.open` to verify the
    output parses correctly (round-trip check).
11. Validate against the OpenType spec checklist.

## Acceptance

- [ ] `Fontisan::FontWriter` class exists with documented API
- [ ] All typed structs defined (no `:hash` attributes)
- [ ] `Tables::Head` writes a valid head table byte sequence
- [ ] Specs cover the public API + Head table serialization
- [ ] Uses Ruby autoload (no require_relative)
- [ ] No `send` to private methods; no `instance_variable_get/set`; no `respond_to?`

## References

- [TODO.full/03](03-panglyph-font-builder.md) — consumer (panglyph)
- [TODO.full/14](14-fontisan-table-writers.md) — Phase B
- OpenType specification: https://learn.microsoft.com/en-us/typography/opentype/spec/
