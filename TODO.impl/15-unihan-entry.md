# 15. UnihanEntry

**Goal**: Unihan dictionary data for CJK codepoints. Grouped by Unihan source file (8
groups). Empty/null for non-CJK codepoints.

**Depends on**: 09.

**Files**:
- `lib/ucode/models/unihan_entry.rb`
- `spec/ucode/models/unihan_entry_spec.rb`

## Tasks

- [ ] One `Hash<String, Array<String>>` attribute per Unihan source file:
  - `attribute :dictionary_indices, :string, collection: true` — with a mapping that
        serializes as `{ "<field>": [...], ... }`. Implementation: use a custom type or a
        nested model `UnihanGroup` that has `attribute :fields, :hash` (verify
        lutaml-model's hash support; otherwise use a serialization adapter).

  Alternative simpler design: model the whole UnihanEntry as one flat
  `attribute :fields, :hash` where keys are `kFoo` strings and values are arrays of
  strings. Group view is derived client-side from key prefixes. **Pick this unless
  lutaml-model's nested-hash support is solid** — simpler, more flexible, no per-group
  class explosion.

- [ ] With the flat-hash design:
  ```ruby
  class UnihanEntry < Lutaml::Model::Serializable
    attribute :fields, :hash    # { "kMandarin" => ["qiū"], "kCantonese" => ["jau1"], ... }

    key_value do
      map "fields", to: :fields
    end
  end
  ```
  The wire shape becomes:
  ```json
  "unihan": {
    "fields": {
      "kMandarin": ["qiū"],
      "kCantonese": ["jau1"],
      "kDefinition": ["(same as 丘) hillock or mound"],
      "kRSUnicode": ["1.4"],
      "kTotalStrokes": ["5"],
      ...
    }
  }
  ```
  The site groups by prefix (`kRS*`, `kMandarin`/`kCantonese`/etc. → "readings",
  `kIRG_*` → "sources", etc.).

- [ ] Update `CodePoint.unihan` to be nullable (default `nil`).

## Acceptance criteria

- Round-trip on a sample Unihan char (U+3400 from the existing ucd.all.flat.xml snippet).
- `UnihanEntry.new(fields: { "kMandarin" => ["qiū"] }).to_hash["fields"]["kMandarin"]`
  returns `["qiū"]`.
- Non-CJK CodePoint has `unihan: nil`.

## Architectural notes

- **Flat hash beats per-group classes**: Unihan adds fields across versions; a hash
  absorbs additions without model changes. The semantic grouping is a presentation
  concern (site-side), not a data concern.
- Values are arrays even when singular (`kTotalStrokes` has one value) — Unihan fields
  are space-separated lists; uniform array-of-strings is the simplest correct shape.
