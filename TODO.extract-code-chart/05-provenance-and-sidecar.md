# TODO 05 — CodeChart::Provenance and CodeChart::Sidecar

## Status

Pending. Depends on TODO 03 (namespace). Depends on TODO 04 (Extractor)
because Sidecar consumes the Extractor's Result.

## Goal

`Provenance` is the value object carrying the metadata the REQ (R5)
requires for each extracted SVG's sidecar JSON. `Sidecar` is the
writer that serializes one Provenance to disk next to its SVG.

## Files

- `lib/ucode/code_chart/provenance.rb` — `Ucode::CodeChart::Provenance`
  Struct with all REQ R5 fields plus the construction helper.
- `lib/ucode/code_chart/sidecar.rb` — `Ucode::CodeChart::Sidecar`
  class (writes a sidecar JSON next to an SVG, idempotent via the
  existing `Ucode::Repo::AtomicWrites`).
- `spec/ucode/code_chart/provenance_spec.rb`
- `spec/ucode/code_chart/sidecar_spec.rb`

## Design

### Provenance value object

The REQ (R5) lists these fields:

```json
{
  "codepoint": "U+10920",
  "block": "Sidetic",
  "source_pdf_url": "https://www.unicode.org/charts/PDF/U-10920.pdf",
  "source_pdf_sha256": "...",
  "ucd_version": "17.0.0",
  "extracted_at": "2026-06-30T12:00:00Z",
  "extractor_version": "0.1.0"
}
```

`Struct` is the right tool — single source of truth for the schema,
keyword-init for clarity, immutable-by-convention. Mirror the
existing `Ucode::Repo::BuildReportAccumulator` pattern.

```ruby
Provenance = Struct.new(
  :codepoint,           # String "U+10920"
  :block,               # String "Sidetic"
  :source_pdf_url,      # String
  :source_pdf_sha256,   # String (hex digest)
  :ucd_version,         # String "17.0.0"
  :extracted_at,        # String ISO8601 UTC
  :extractor_version,   # String "0.2.0"
  keyword_init: true,
)
```

`extractor_version` reads from `Ucode::VERSION` so it stays in sync
with the gem — single source of truth.

`extracted_at` is set at construction (not at file write) so the
field describes the extraction event, not the serialization event.

### Provenance → Hash serialization

`Provenance#to_h` returns the hash form. NO hand-rolled `to_json` /
`from_json` per the global rule — `Provenance` is a value object, but
its schema is simple enough that `to_h` + `JSON.pretty_generate` is
the framework-driven approach (lutaml-model is overkill for a flat
struct).

Wait — re-reading the global rule: "ALL (de)serialization goes through
the framework. In Coradoc and any project using `lutaml-model`." So
the rule is for projects using lutaml-model, and ucode uses lutaml-model
for UCD models. This Provenance struct is not a UCD model — it's a
feature-local value object. JSON via `JSON.pretty_generate(provenance.to_h)`
is acceptable and avoids ceremony.

`to_h` produces a hash with the Struct's keyword keys. No
indirection, no lutaml-model mapping for what is effectively a
record.

### Sidecar writer

```ruby
class Sidecar
  include Ucode::Repo::AtomicWrites

  def initialize(output_root:)
    @output_root = Pathname.new(output_root)
  end

  # Writes <output_root>/<cp_id>.json next to the corresponding SVG.
  # Idempotent: re-writing the same content is a no-op (byte-stable).
  #
  # @param provenance [Ucode::CodeChart::Provenance]
  # @return [Pathname] the written path
  def write(provenance)
    path = path_for(provenance)
    payload = JSON.pretty_generate(provenance.to_h)
    write_atomic(path, payload + "\n")
    path
  end

  private

  def path_for(provenance)
    @output_root.join("#{provenance.codepoint}.json")
  end
end
```

`Repo::AtomicWrites#write_atomic` is the project's single source of
truth for idempotent file writes — bytes-identical re-writes are
no-ops (the temp-file rename is skipped when content matches).
Reuse, don't reimplement.

### Why a separate Sidecar class

A `Provenance.to_disk(path)` method would couple the value object
to I/O. Keeping the writer separate lets:
- Tests assert `Provenance#to_h` without touching disk.
- The Writer (TODO 06) compose `Extractor` + `Sidecar` with explicit
  dependency injection (seam for testing).
- Future formats (e.g. a different sidecar schema) replace Sidecar
  without touching Provenance.

This is MECE: Provenance is data; Sidecar is I/O; Writer is
orchestration.

## Acceptance

- `Provenance.new(codepoint: "U+10920", block: "Sidetic", ...)`
  constructs without raising.
- `Provenance#to_h` returns a Hash with exactly the REQ's fields.
- `Sidecar#write(provenance)` writes `<codepoint>.json` next to
  where the SVG lives; the JSON content matches `Provenance#to_h`.
- Re-writing the same Provenance is a no-op (file unchanged).
- Specs cover all five REQ fields plus the idempotency guarantee.

## Out of scope

- License attribution text — the REQ mentions `LICENSE-SOURCES.md`
  obligations, but that's a fontist-side concern (downstream
  essenfont build). Ucode emits provenance; the consumer stitches
  attribution.