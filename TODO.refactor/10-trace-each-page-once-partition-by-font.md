# TODO 10 — Trace each PDF page once, partition by font

## Status

Pending. Audit finding A2 (performance bug). **Depends on TODOs 08
and 09.**

## Why

`CodepointMapper#map_from_trace` currently does this per font:

```ruby
def map_from_trace(base_font)
  return {} unless @indexer.font_appears?(base_font)
  runner = TraceRunner.new(@source.pdf_path)
  correlator = TraceCorrelator.new(specimen_font_name: base_font)
  (1..@indexer.page_count).each_with_object({}) do |page, mapping|
    glyphs = runner.trace([page])  # spawns mutool PER PAGE PER FONT
    page_mapping = correlator.correlate(glyphs)
    page_mapping.each { |cp, gid| mapping[cp] ||= gid }
  end
end
```

For a Code Charts PDF with `F` fonts lacking `/ToUnicode` and `P`
pages, this spawns **`F × P`** `mutool trace` subprocesses. Each
subprocess pays ~50-200ms of process startup + PDF reparse. For the
blocks in `BUG-code-chart-cid-font-extraction.md` (Garay, Ol Onal,
Kana Extended-A/B, Small Kana Extension) this is the hot path.

`mutool trace <pdf> 1-N` also accepts multiple pages in one call,
so even single-font tracing is over-spawning.

## Files

New `lib/ucode/glyphs/embedded_fonts/page_trace_cache.rb`:

```ruby
class EmbeddedFonts::PageTraceCache
  # @param pdf [Pathname]
  # @param mutool [Mutool::Trace]
  def initialize(pdf:, mutool:, page_count:)
    @pdf = pdf
    @mutool = mutool
    @page_count = page_count
  end

  # @return [Array<TraceGlyph>] every glyph on every page, flat.
  def glyphs
    @glyphs ||= begin
      return [] unless @page_count.positive?

      xml = @mutool.call(@pdf, *(1..@page_count))
      TraceParser.parse(xml)
    end
  end

  # @param base_font [String] specimen font BaseFont name
  # @return [Array<TraceGlyph>] only glyphs emitted by this font
  def for_font(base_font)
    glyphs.select { |g| g.font_name == base_font }
  end

  # @param base_font [String]
  # @return [Array<TraceGlyph>] every glyph NOT from this font
  #   (the label candidates — used by TraceCorrelator's auto-detect)
  def labels_for(base_font)
    glyphs.reject { |g| g.font_name == base_font }
  end
end
```

## Design

The Catalog builds one `PageTraceCache` lazily and passes it to the
`TraceStrategy` (TODO 09). `TraceStrategy#map(descriptor)` then:

```ruby
def map(descriptor)
  return {} unless @cache  # no trace configured

  specimens = @cache.for_font(descriptor.base_font)
  labels   = @cache.labels_for(descriptor.base_font)
  return {} if specimens.empty? || labels.empty?

  correlator = TraceCorrelator.new(specimen_font_name: descriptor.base_font)
  # TraceCorrelator already filters internally, but pre-partitioning
  # here keeps the correlator's input smaller.
  correlator.correlate(specimens + labels)
end
```

The Catalog decides whether to build the cache (eager `mutool info`
scan shows at least one font without `/ToUnicode`). If no font needs
trace, the cache is never built — no perf regression for the common
case (all fonts have `/ToUnicode`).

## Acceptance

- For a PDF with F trace-needing fonts and P pages, `mutool trace`
  is invoked **exactly once** with all pages in a single argv.
- The Catalog still produces the same FontEntry set with the same
  codepoint_to_gid maps.
- A new spec `spec/ucode/glyphs/embedded_fonts/page_trace_cache_spec.rb`
  verifies:
  - `glyphs` calls `Mutool::Trace#call` exactly once (regardless of
    how many times `for_font` / `labels_for` are called).
  - `for_font("X")` returns only glyphs where `font_name == "X"`.
  - `labels_for("X")` returns only glyphs where `font_name != "X"`.
- `BUG-code-chart-cid-font-extraction.md` can be marked Resolved in
  the same PR (or in a follow-up cleanup PR).
