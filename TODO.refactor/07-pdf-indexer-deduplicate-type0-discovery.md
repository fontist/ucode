# TODO 07 — Deduplicate Type0 font discovery in PdfIndexer

## Status

Pending. Audit finding A1 (DRY violation).

## Why

`lib/ucode/glyphs/embedded_fonts/pdf_indexer.rb` walks
`mutool_info_text` lines twice with the SAME regex pattern but
produces different shapes:

- `:135` `discover_type0_fonts` → `{font_obj_id => base_font}`
- `:219` `font_entries_cache`   → `{base_font => true}`

Both iterate `mutool_info_text.each_line`, both match
`/Type0\s+'([^']+)'/`, both de-duplicate.

If `mutool info` ever changes its output format, two places need to
change in sync — and they're 80 lines apart, so the coupling is
invisible.

## Files

- `lib/ucode/glyphs/embedded_fonts/pdf_indexer.rb`.

## Design

Parse `mutool_info_text` ONCE into an Array of `Type0Entry =
Struct.new(:font_obj_id, :base_font)` instances. Both consumers
derive their view from that single parse:

```ruby
Type0Entry = Struct.new(:font_obj_id, :base_font, keyword_init: true)

def type0_entries
  @type0_entries ||= parse_type0_entries
end

def parse_type0_entries
  seen = Set.new
  mutool_info_text.each_line.filter_map do |line|
    next unless line.include?("Type0")

    m = line.match(/Type0\s+'([^']+)'\s+\S+\s+\((\d+)\s+0\s+R\)/)
    next unless m

    font_obj_id = m[2].to_i
    next if seen.include?(font_obj_id)

    seen << font_obj_id
    Type0Entry.new(font_obj_id: font_obj_id, base_font: m[1])
  end
end

def discover_type0_fonts
  type0_entries.each_with_object({}) do |e, h|
    h[e.font_obj_id] = e.base_font
  end
end

def font_entries_cache
  type0_entries.each_with_object({}) do |e, h|
    h[e.base_font] = true
  end
end
```

The `font_appears?(base_font)` method then delegates to
`font_entries_cache.key?(base_font)` — unchanged public API.

## Acceptance

- Single parse method, single source of truth.
- Public API unchanged (`font_count`, `font_appears?`,
  `raw_descriptors`, `page_count` all behave identically).
- Existing catalog_spec.rb passes (including the CodepointMapper
  failure-path specs that exercise the indexer via StubIndexer).
- No behavior change observable from outside.
