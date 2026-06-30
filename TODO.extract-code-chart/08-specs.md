# TODO 08 — CodeChart specs

## Status

Pending. Depends on TODOs 01–07.

## Goal

Comprehensive spec coverage for every new module. Per the project
rules: real model instances (no doubles), tight focused tests,
behavior assertions (not interaction counts).

## Files

Already enumerated per TODO. Final spec coverage:

- `spec/ucode/fetch/code_charts_spec.rb` — happy path + HTTP 4xx +
  wrong content-type + non-PDF body. (TODO 01)
- `spec/ucode/parsers/blocks_spec.rb` (extend) — `find_by_name`
  happy path + nil on miss. (TODO 02)
- `spec/ucode/code_chart/extractor_spec.rb` — constructor invariants,
  Resolver wiring, integration test against fixture PDF. (TODO 04)
- `spec/ucode/code_chart/provenance_spec.rb` — value object
  construction + `to_h` schema. (TODO 05)
- `spec/ucode/code_chart/sidecar_spec.rb` — write sidecar, idempotent
  re-write. (TODO 05)
- `spec/ucode/code_chart/writer_spec.rb` — full lifecycle:
  extract → write → summary. Idempotent re-run produces byte-identical
  files. (TODO 06)
- `spec/ucode/cli_spec.rb` (extend) — verify `ucode code-chart fetch`,
  `extract`, `list` wire up. (TODO 07)

## Design

### Fixture strategy

The existing `spec/fixtures/pdfs/basic_latin.pdf` is the only PDF
fixture in the repo. It's tiny and validates the integration path.
The Sidetic + Egyptian Ext-B PDFs are large (whole-block) and would
inflate the repo. The integration spec uses `basic_latin.pdf` to
exercise the full pipeline; per-codepoint assertions cover
representative cases.

If Sidetic-specific behavior must be tested, a smaller fixture PDF
cropped to ~5 codepoints would be the right tool — out of scope for
this TODO.

### No doubles policy

The project's `~/.claude/CLAUDE.md` rule: no doubles. All specs use
real instances:
- `Ucode::Models::Block.new(...)` for test blocks.
- A temp directory + real `Blocks.txt` text for parser specs.
- The real `Ucode::Glyphs::Resolver` for extractor specs.

### Idempotency assertion pattern

`Writer#write` idempotency is asserted via byte-equality:

```ruby
first_run  = writer.write(block)
first_size = File.stat(svg_path).size
sleep 0.01  # ensure mtime changes would be detectable
second_run = writer.write(block)
second_size = File.stat(svg_path).size
expect(second_size).to eq(first_size)
expect(File.read(svg_path)).to eq(expected_svg_bytes)
```

This is the existing pattern from `spec/ucode/repo/aggregate_writer_spec.rb`
(idiempotency spec there). Reuse.

## Acceptance

- `bundle exec rspec spec/ucode/code_chart/ spec/ucode/fetch/code_charts_spec.rb spec/ucode/parsers/blocks_spec.rb`
  passes 100%.
- Coverage for the new files is ≥ 95% (per the project's per-file
  floor of 30% + the overall 80% minimum).
- No doubles are introduced (verify with `grep -r "double(" spec/ucode/code_chart/`).
- The integration spec exercises both the Extractor and Writer
  together end-to-end.

## Out of scope

- Performance benchmarks — separate concern.
- Sidetic-specific fixtures — requires PDF curation beyond the
  scope of this feature.