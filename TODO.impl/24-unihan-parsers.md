# 24. Unihan parsers (8 files)

**Goal**: Parse all 8 Unihan text files into a flat stream of `(cp, field_name,
values[])` tuples. Coordinator merges into `CodePoint.unihan.fields` (the hash).

**Depends on**: 17, 15.

**Files**:
- `lib/ucode/parsers/unihan.rb` — single parser handling all 8 files (uniform format).
- Specs + sliced fixtures.

## Tasks

- [ ] Each Unihan file has the same format:
  - `U+3400	kTotalStrokes	5` (TAB-separated; cp, field, value).
  - Some values are space-separated lists (`kDefinition`, `kRSUnicode`).
- [ ] One parser class, one method per file:
  ```ruby
  class Unihan
    FIELD_TO_METHOD = {
      "Unihan_DictionaryIndices.txt" => :dictionary_indices,
      "Unihan_DictionaryLikeData.txt" => :dictionary_like_data,
      "Unihan_IRGSources.txt" => :irg_sources,
      "Unihan_NumericValues.txt" => :numeric_values,
      "Unihan_RadicalStrokeCounts.txt" => :radical_stroke_counts,
      "Unihan_Readings.txt" => :readings,
      "Unihan_Variants.txt" => :variants,
      "Unihan_OtherMappings.txt" => :other_mappings,
    }.freeze

    def each_record(ucd_dir)
      FIELD_TO_METHOD.each do |filename, _method|
        path = File.join(ucd_dir, filename)
        File.foreach(path, chomp: true) do |line|
          next if line.start_with?("#")
          cp_hex, field, value = line.split("\t")
          yield UnihanRecord.new(cp: cp_hex.to_i(16), field: field, values: value.split)
        end
      end
    end
  end
  ```
- [ ] Yield a simple `UnihanRecord` value object (Struct.new(:cp, :field, :values)
      works — no lutaml-model needed since this is internal pipeline data).
- [ ] Coordinator groups records by `cp`, splits each value on space, and writes into
      `CodePoint.unihan.fields` (the hash).

## Acceptance criteria

- Parsing the Unihan dir yields one record per `kField` line.
- After Coordinator merges, `CodePoint.find(0x3400).unihan.fields["kTotalStrokes"] ==
  ["5"]`.
- Round-trip on the resulting UnihanEntry.

## Architectural notes

- **Why one parser, not eight**: format is uniform. The file→method mapping is the
  *output* side; the *parse* side is identical.
- Records are internal pipeline data; no need for a full lutaml-model class. A
  `Struct.new` is fine here. (Avoids unnecessary model ceremony.)