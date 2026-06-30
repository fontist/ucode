# TODO 06 — CodeChart::Writer

## Status

Pending. Depends on TODO 04 (Extractor) and TODO 05 (Provenance +
Sidecar).

## Goal

`Ucode::CodeChart::Writer` is the single entry point for
"extract every codepoint in block X and write SVG + sidecar JSON
files under output_dir." It's the orchestration layer the CLI
calls and the only thing that touches disk.

## Files

- `lib/ucode/code_chart/writer.rb` — `Ucode::CodeChart::Writer` class.
- `spec/ucode/code_chart/writer_spec.rb`

## Design

### Class shape

```ruby
class Ucode::CodeChart::Writer
  Summary = Struct.new(:block, :codepoints_total, :svgs_written,
                       :sidecars_written, :pdf_sha256, keyword_init: true)

  def initialize(output_root:, pdf_path:, cache_dir: nil,
                 last_resort_root: nil, blocks_txt: nil)
    @output_root = Pathname.new(output_root)
    @pdf_path = Pathname.new(pdf_path)
    @cache_dir = cache_dir
    @last_resort_root = last_resort_root
    @blocks_txt = blocks_txt || Ucode::Cache.ucd_dir(Ucode::VersionResolver.resolve(nil)).join("Blocks.txt")
    @sidecar = Sidecar.new(output_root: @output_root)
  end

  # Extracts every codepoint in @block (a Models::Block) and writes
  # SVG + sidecar JSON under @output_root. Returns a Summary.
  #
  # @param block [Ucode::Models::Block]
  # @return [Summary]
  def write(block)
  end
end
```

### Per-codepoint flow (single source of truth)

```ruby
def write(block)
  output_root_for(block).mkpath
  pdf_sha = sha256(@pdf_path)

  extractor = Extractor.new(
    block: block,
    blocks_txt: @blocks_txt,
    pdf_path: @pdf_path,
    cache_dir: @cache_dir,
    last_resort_root: @last_resort_root,
  )
  results = extractor.extract

  svgs = 0
  sidecars = 0
  results.each do |result|
    svg_path = output_root_for(block).join("#{cp_id(result.codepoint)}.svg")
    File.write(svg_path, result.svg) unless svg_path.exist? && File.read(svg_path) == result.svg
    svgs += 1 if svg_path.exist?

    provenance = build_provenance(block, result.codepoint, pdf_sha)
    @sidecar.write(provenance)
    sidecars += 1
  end

  Summary.new(
    block: block.id,
    codepoints_total: results.size,
    svgs_written: svgs,
    sidecars_written: sidecars,
    pdf_sha256: pdf_sha,
  )
end
```

### Why not use `Repo::AtomicWrites` for the SVGs

The Sidecar uses `Repo::AtomicWrites` because JSON has a stable
canonical form. SVG output from `EmbeddedFonts::Svg#to_s` is also
byte-stable, but the writer pattern is simpler with `File.write` —
the byte-equality check above guarantees idempotency at the I/O
layer. Both paths reach the same outcome.

If future output formats gain non-stable serialization (timestamps,
random IDs), the SVG path will need `Repo::AtomicWrites` too. Until
then, simpler is better.

### Why compute `pdf_sha256` once

Every Provenance in this block carries the same `source_pdf_sha256`.
Computing it once avoids 32+ disk reads of the PDF per block
extraction. The Writer is the single place that knows "one block,
one PDF, one hash" — pushing the calculation into Sidecar or
Provenance would require either (a) repeated computation per
Provenance or (b) a parameter-passing thread through Extractor. Both
violate locality.

### Output layout

`<output_root>/<block_id>/<U+XXXX>.svg` and `<U+XXXX>.json`.

One folder per block keeps the `Writer`'s output self-contained and
discoverable — a downstream consumer (fontisan) can iterate a block's
folder without scanning the whole tree. This mirrors the existing
`Ucode::Repo::Writers::BlocksWriter` output convention (one folder
per block, index.json inside).

## Acceptance

- `Writer#write(block)` creates `<output_root>/<block_id>/` and
  fills it with `<U+XXXX>.svg` + `<U+XXXX>.json` for every
  extracted codepoint.
- Re-running `Writer#write(block)` with no changes produces
  byte-identical files (no rewrites).
- `Summary#svgs_written` equals the number of extracted codepoints.
- Specs cover the full lifecycle including idempotency.

## Out of scope

- Per-block write isolation — concurrent `Writer#write` calls for
  different blocks are safe (different folders), but the Writer is
  not thread-safe within a single block. That's a parallel-extraction
  concern, not a per-block concern.