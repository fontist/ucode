# 15 — panglyph Builder real implementation (uses FontWriter)

## Goal

Wire panglyph's `Builder` to actually produce a TTF using
`Fontisan::FontWriter`. Replaces the stub from TODO.full/03 with a
real pipeline that:

1. Reads ucode's universal-set manifest
2. Opens each Tier 1 source font via `Fontisan::Font.open`
3. Walks the cmap → glyf for each codepoint
4. Assembles a single TTF via `Fontisan::FontWriter`
5. Validates the output

## Why this is a separate TODO

The skeleton classes exist (pushed in initial panglyph commit). They
warn "stub" because fontisan couldn't write fonts. TODO 13 + 14 add
that capability. This TODO makes panglyph USE it.

## Scope

1. Replace `OutlineExtractor#extract_many` stub with real fontisan calls:
   ```ruby
   font = Fontisan::Font.open(font_path, font_index:)
   codepoints.each do |cp|
     gid = font.cmap.unicode_map[cp]
     next unless gid
     outline_bytes = font.glyf.raw_bytes_for(gid)
     advance_width = font.hmtx.advance_width(gid)
     lsb = font.hmtx.lsb(gid)
     extracted[cp] = Outline.new(
       contours: parse_contours(outline_bytes),
       instructions: parse_instructions(outline_bytes),
       is_composite: font.glyf.composite?(gid),
     )
     metrics[cp] = Metrics.new(advance_width:, left_side_bearing: lsb)
   end
   ```

2. Replace `FontAssembler#assemble` stub:
   ```ruby
   writer = Fontisan::FontWriter.new(format: :ttf)
   writer.set_cmap(unicode_to_gid)
   writer.set_name_records([
     NameRecord.new(name_id: 1, platform_id: 3, encoding_id: 1, language_id: 0x409,
                    string: "panglyph Unicode #{major_version}"),
     # ...
   ])
   writer.set_version("Version #{ucd_version}")
   outlines.each do |cp, outline|
     gid = unicode_to_gid[cp]
     writer.add_glyph(gid, outline:, metrics: metrics[cp])
   end
   writer.write_to(ttf_path)
   ```

3. Real `CoverageReport` — walks the output TTF's cmap, compares to manifest.

4. Real `Publisher` — syncs to fontist-archive-public via git.

## Performance considerations

- 299,382 codepoints × ~1ms each = ~5 minutes for extraction
- Outline parsing dominates CPU; parallelize per source font
- Memory: hold all outlines in memory (~1.2GB estimated); use streaming
  write to disk if low-memory CI runners complain

## Acceptance

- [ ] `bundle exec panglyph build 17.0.0` produces a TTF
- [ ] Built TTF opens via `Fontisan::Font.open`
- [ ] Built TTF's cmap contains every codepoint in the manifest
- [ ] Built TTF renders in a browser (manual smoke test)
- [ ] Build completes in <30 minutes on a single runner
- [ ] No stubs remain in Builder / OutlineExtractor / FontAssembler

## References

- [TODO.full/03](03-panglyph-font-builder.md) — original skeleton
- [TODO.full/13](13-fontisan-font-writer-api.md) — FontWriter API
- [TODO.full/14](14-fontisan-table-writers.md) — table writers
