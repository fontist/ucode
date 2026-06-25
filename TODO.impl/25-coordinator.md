# 25. Coordinator — orchestrates parsers, produces per-codepoint output

**Goal**: Single orchestrator that reads all 30+ UCD/Unihan text files in one pass and
emits per-codepoint records to a sink. **Streaming**: never holds all CodePoints in memory.

**Depends on**: 17–24, 14, 15, 16.

**Files**:
- `lib/ucode/coordinator.rb`
- `spec/ucode/coordinator_spec.rb` — integration spec over a sliced UCD fixture.

## Tasks

- [ ] Public API:
  ```ruby
  class Coordinator
    def initialize(config)
      @config = config
      @sink = nil
    end

    def build(ucd_dir:, unihan_dir:)
      each_codepoint(ucd_dir, unihan_dir) { |cp| @sink.call(cp) }
    end

    def sink(callable = nil, &block)
      @sink = callable || block
      self
    end

    def each_codepoint(ucd_dir, unihan_dir)
      return enum_for(:each_codepoint, ucd_dir, unihan_dir) unless block_given?
      # see implementation below
    end
  end
  ```
- [ ] Implementation strategy:
  1. `UnicodeData.each_record(ucd_dir)` is the **driver**: it yields one record per
     assigned codepoint (range expansion done).
  2. For each yielded record, Coordinator merges in data from the other parsers via
     `bsearch` lookups (sorted parsers) or accumulation passes.
  3. First pass: collect range-property data (Blocks, Scripts, ScriptExtensions,
     extracted/*, auxiliary/*, BinaryProperties) into sorted arrays indexed by first_cp.
  4. Second pass: for each UnicodeData-driven CodePoint, bsearch into the
     range-property arrays to set block_id, script_code, script_extensions, etc.
  5. Third pass: bsearch SpecialCasing, CaseFolding, BidiBrackets, BidiMirroring,
     NameAliases, CJKRadicals, StandardizedVariants.
  6. Fourth pass: bsearch DerivedAge, DerivedCoreProperties.
  7. NamesList and Unihan: not range-based — stream in parallel and index by `cp` first,
     then look up while iterating UnicodeData.
- [ ] Memory: peak is ~10 MB of bsearch indices, not 160 k CodePoints. The actual
      CodePoint instances are built, yielded, and then GC'd.
- [ ] Tests cover: Basic Latin, one CJK codepoint, one emoji, one Hangul, one Unihan char.
      Assert the final CodePoint matches expectations.

## Acceptance criteria

- Coordinator runs against the fixture without OOM.
- A sample CodePoint's `age`, `block_id`, `script_code`, `general_category`,
  `combining_class`, `bidi.mirroring_glyph_id`, `casing.full_upper_ids`,
  `relationships.first.kind`, and `unihan.fields["kMandarin"]` are all correctly set.
- Coordinator never holds more than ~20 MB of working memory (profile with
  `memory_profiler` gem if needed).

## Architectural notes

- **Why bsearch and not hash**: range data is sorted by `first_cp`; bsearch is O(log N)
  per lookup. With ~5 range lookups per codepoint and 160 k codepoints, that's ~5 M
  bsearch ops — sub-second.
- **Why stream NamesList/Unihan into per-cp arrays first**: NamesList.txt is small
  (~10 MB) and Unihan is ~30 MB. Building a `@names_by_cp = Hash.new { |h, k| h[k] = [] }`
  and `@unihan_by_cp` is cheap.
- **No CodePoint pooling**: we build fresh instances. They go out of scope after yield.
  The GC handles it.

## Performance notes

For 160 k codepoints × ~20 attribute merges each = 3.2 M Ruby method calls. Should run
in <60 s on modern hardware. If too slow: switch to Ractors for the per-codepoint merge
phase (each cp is independent).