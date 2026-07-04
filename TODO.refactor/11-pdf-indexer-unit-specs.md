# TODO 11 — Add `PdfIndexer` unit specs (synthetic mutool fixtures)

## Status

Pending. Audit finding S1. **Depends on TODO 08.**

## Why

`lib/ucode/glyphs/embedded_fonts/pdf_indexer.rb` is the most complex
parser in the embedded-fonts pipeline (subprocess + regex dict
parsing + ref-collecting across 3 dict layers). It currently has
**zero unit specs** — only exercised through `integration_spec.rb`
(skipped without mutool).

The regex parsing of PDF dict bodies (`parse_dict` at line 181) is
the place most likely to silently break when Unicode Consortium
publishes a chart with a slightly different dict shape. There is no
spec to catch that regression.

## Files

- `spec/ucode/glyphs/embedded_fonts/pdf_indexer_spec.rb` (NEW).
- `spec/support/stub_mutool.rb` (NEW) — minimal stub conforming to
  the `Mutool` interface from TODO 08, returns canned outputs by
  argv shape.
- `spec/fixtures/mutool/info_basic_latin.txt` (NEW) — captured
  `mutool info` output from the basic_latin.pdf fixture.
- `spec/fixtures/mutool/show_type0_dict_5_0_R.txt` (NEW) — captured
  `mutool show -g` for one Type0 font dict.
- Similar small fixtures for descendant CIDFont + FontDescriptor.

## Design

### StubMutool

```ruby
class StubMutool
  def initialize(responses:)
    @responses = responses  # Hash keyed by argv-shape Signature
  end

  def run(*argv)
    @responses.fetch(signature(argv)) do
      raise "StubMutool: no canned response for #{argv.inspect}"
    end
  end

  private

  def signature(argv)
    # Match by subcommand + key positional args (e.g. "info:<pdf>",
    # "show:-g:<pdf>:<obj_ids>", "show:-b:-o:<tmp>:<pdf>:<obj>")
    ...
  end
end
```

### Specs to write

```ruby
describe EmbeddedFonts::PdfIndexer do
  let(:mutool) { StubMutool.new(responses: fixtures) }
  let(:source) { EmbeddedFonts::PdfSource.new(pdf: Pathname("fake.pdf")) }
  let(:indexer) { described_class.new(source: source, mutool: mutool) }

  describe "#page_count" do
    it "parses the Pages: line from mutool info" do
      expect(indexer.page_count).to eq(12)
    end
  end

  describe "#font_appears?" do
    it "returns true for a font named in mutool info" do
      expect(indexer.font_appears?("GPJAHB+WolofGaraySansSerif")).to be(true)
    end

    it "returns false for a font not in mutool info" do
      expect(indexer.font_appears?("NotInList")).to be(false)
    end
  end

  describe "#raw_descriptors" do
    it "returns one RawFontDescriptor per Type0 font with required refs" do
      descs = indexer.raw_descriptors
      expect(descs.size).to eq(1)
      expect(descs.first.base_font).to eq("GPJAHB+WolofGaraySansSerif")
      expect(descs.first.font_obj_id).to eq(5)
      expect(descs.first.cid_map_kind).to eq(:identity)
    end

    it "skips Type0 fonts missing DescendantFonts" do
      # fixture: Type0 dict without /DescendantFonts
      expect(indexer_with(missing_descendant_fixtures).raw_descriptors)
        .to eq([])
    end

    it "skips CIDFonts whose CIDToGIDMap is not /Identity" do
      # fixture: CIDFont with /CIDToGIDMap /Identity-H (we only support Identity)
      expect(indexer_with(identity_h_fixtures).raw_descriptors).to eq([])
    end

    it "prefers FontFile2 over FontFile3 when both present" do
      descs = indexer.raw_descriptors
      expect(descs.first.fontfile_kind).to eq(:ttf)
    end
  end
end
```

### Fixture capture

The fixture text files are captured once via:

```bash
mutool info spec/fixtures/pdfs/basic_latin.pdf > spec/fixtures/mutool/info_basic_latin.txt
mutool show -g spec/fixtures/pdfs/basic_latin.pdf 5 7 9 > spec/fixtures/mutool/show_type0_5_7_9.txt
```

These are tiny text files, committed to the repo.

## Acceptance

- `bundle exec rspec spec/ucode/glyphs/embedded_fonts/pdf_indexer_spec.rb`
  passes WITHOUT mutool on PATH (the entire point).
- Coverage of `pdf_indexer.rb` ≥ 90% (verify with `simplecov` if
  configured, or count paths manually).
- The `parse_dict` regex branches each have at least one spec
  exercising their match.
- Each "skip" path (missing DescendantFonts, missing FontDescriptor,
  non-Identity CIDToGIDMap) has its own spec.
