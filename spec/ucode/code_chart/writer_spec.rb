# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "fileutils"
require "json"

# Test Pillar 3 source — returns one deterministic Result per
# codepoint so the Writer spec doesn't depend on mutool or fixture
# PDF content. Real class (no doubles). Lives at file scope to
# avoid leaky constant declarations.
class AlwaysPillar3 < Ucode::Glyphs::Source
  def tier = :pillar3

  def fetch(codepoint)
    Ucode::Glyphs::Source::Result.new(
      tier: :pillar3, codepoint: codepoint,
      svg: "<svg>glyph-#{codepoint.to_s(16)}</svg>",
      provenance: "stub:pillar3",
    )
  end
end

# Test Extractor — yields a deterministic Result per codepoint in
# the block range, no mutool required. Real class (no doubles). Used
# by the writer_spec's mutool-free path so writer.rb stays covered
# even where mutool isn't installed (CI on Windows/macOS without
# pre-installed mutool).
class StubExtractor
  Result = Struct.new(:codepoint, :svg, :tier, :provenance,
                      :base_font, :gid, :source_page, :source_cell,
                      keyword_init: true)

  def initialize(block:, codepoints: nil, **_rest)
    range = codepoints || (block.range_first..block.range_last).to_a
    @results = range.map do |cp|
      Result.new(
        codepoint: cp,
        svg: "<svg>stub-#{cp.to_s(16)}</svg>",
        tier: :pillar1,
        provenance: "stub:extractor",
        base_font: "STUB+Font",
        gid: cp & 0xFF,
        source_page: 1,
        source_cell: { x: 100.0, y: 200.0 },
      )
    end
  end

  def extract
    @results
  end
end

RSpec.describe Ucode::CodeChart::Writer do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-writer-")) }
  let(:output_root) { tmpdir.join("output") }
  let(:pdf_dir) { tmpdir.join("pdfs") }

  # Use the repo's real basic_latin.pdf fixture. Its font is
  # WinAnsiEncoding for the actual Basic Latin glyphs (no
  # /ToUnicode CMap), so the embedded-font catalog yields nothing
  # for U+0000..U+007F — which is exactly what we want for the
  # Writer spec: the Writer's job is to put bytes on disk and
  # Provenance next to them, not to test the catalog.
  let(:pdf_path) do
    Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
  end
  let(:pdf_sha) { Digest::SHA256.file(pdf_path).hexdigest }

  let(:basic_latin_block) do
    Ucode::Models::Block.new(
      id: "Basic_Latin", name: "Basic Latin",
      range_first: 0x0000, range_last: 0x007F,
      plane_number: 0,
    )
  end
  let(:writer) do
    described_class.new(
      output_root: output_root,
      pdf_path: pdf_path,
      ucd_version: "17.0.0",
      pillar3_source: AlwaysPillar3.new,
      now: Time.utc(2026, 6, 30, 12, 0, 0),
    )
  end

  # Mutool-free writer: injects a stub Extractor so the spec doesn't
  # depend on mutool being installed. This keeps writer.rb's line
  # coverage above the SimpleCov per-file threshold (30%) on CI
  # runners where mutool isn't pre-installed.
  let(:stub_extractor) { StubExtractor.new(block: basic_latin_block) }
  let(:mutool_free_writer) do
    described_class.new(
      output_root: output_root,
      pdf_path: pdf_path,
      ucd_version: "17.0.0",
      now: Time.utc(2026, 6, 30, 12, 0, 0),
      extractor: stub_extractor,
    )
  end

  before do
    skip "fixture PDF missing" unless pdf_path.exist?
  end

  after { safe_remove(tmpdir) if tmpdir.exist? }

  # Real-extractor path: needs mutool on PATH. Skipped where mutool
  # isn't pre-installed (some CI runners). The mutool-free context
  # below covers the same code paths without that dependency.
  describe "#write" do
    before { skip "mutool not on PATH" unless system("which mutool >/dev/null 2>&1") }

    it "creates a per-block folder under output_root" do
      writer.write(basic_latin_block)
      expect(output_root.join("Basic_Latin").directory?).to be(true)
    end

    it "writes one .svg + one .json per extracted codepoint" do
      summary = writer.write(basic_latin_block)
      expect(summary.svgs_written).to eq(128)
      expect(summary.sidecars_written).to eq(128)
      expect(output_root.join("Basic_Latin/U+0041.svg").exist?).to be(true)
      expect(output_root.join("Basic_Latin/U+0041.json").exist?).to be(true)
    end

    it "writes the SVG bytes verbatim from the extractor Result" do
      writer.write(basic_latin_block)
      content = output_root.join("Basic_Latin/U+0041.svg").read
      expect(content).to eq("<svg>glyph-41</svg>")
    end

    it "writes valid sidecar JSON with all REQ R5 fields" do
      writer.write(basic_latin_block)
      payload = JSON.parse(output_root.join("Basic_Latin/U+0041.json").read)
      expect(payload).to include(
        "codepoint" => "U+0041",
        "block" => "Basic_Latin",
        "ucd_version" => "17.0.0",
        "extractor_version" => Ucode::VERSION,
        "extracted_at" => "2026-06-30T12:00:00Z",
      )
      expect(payload["source_pdf_url"])
        .to eq("https://www.unicode.org/charts/PDF/U0000.pdf")
      expect(payload["source_pdf_sha256"]).to eq(pdf_sha)
    end

    it "is idempotent — re-running produces byte-identical files" do
      writer.write(basic_latin_block)
      first_svg_size = output_root.join("Basic_Latin/U+0041.svg").size
      first_svg_bytes = output_root.join("Basic_Latin/U+0041.svg").binread
      first_json_size = output_root.join("Basic_Latin/U+0041.json").size
      first_json_bytes = output_root.join("Basic_Latin/U+0041.json").binread

      second = writer.write(basic_latin_block)
      expect(second.svgs_written).to eq(128)
      expect(second.sidecars_written).to eq(128)

      # SVG: same bytes (writer skips when content matches)
      expect(output_root.join("Basic_Latin/U+0041.svg").size).to eq(first_svg_size)
      expect(output_root.join("Basic_Latin/U+0041.svg").binread).to eq(first_svg_bytes)

      # JSON: byte-identical (Repo::AtomicWrites is canonical-JSON idempotent)
      expect(output_root.join("Basic_Latin/U+0041.json").size).to eq(first_json_size)
      expect(output_root.join("Basic_Latin/U+0041.json").binread).to eq(first_json_bytes)
    end

    it "computes pdf_sha256 once for the summary" do
      summary = writer.write(basic_latin_block)
      expect(summary.pdf_sha256).to eq(pdf_sha)
    end
  end

  # Mutool-free context: runs on every CI runner regardless of
  # whether mutool is pre-installed. Exercises the same writer.rb
  # code paths via a stub Extractor that doesn't shell out.
  describe "#write with stub extractor" do
    before do
      skip "fixture PDF missing" unless pdf_path.exist?
    end

    it "writes one .svg + one .json per stubbed codepoint" do
      summary = mutool_free_writer.write(basic_latin_block)
      expect(summary.svgs_written).to eq(128)
      expect(summary.sidecars_written).to eq(128)
      expect(output_root.join("Basic_Latin/U+0041.svg")).to exist
      expect(output_root.join("Basic_Latin/U+0041.json")).to exist
    end

    it "threads base_font/gid/source_page/source_cell into the sidecar" do
      mutool_free_writer.write(basic_latin_block)
      payload = JSON.parse(output_root.join("Basic_Latin/U+0041.json").read)
      expect(payload["base_font"]).to eq("STUB+Font")
      expect(payload["gid"]).to eq(0x41)
      expect(payload["source_page"]).to eq(1)
      expect(payload["source_cell"]).to eq("x" => 100.0, "y" => 200.0)
    end

    it "honors codepoints: subset" do
      writer = described_class.new(
        output_root: output_root,
        pdf_path: pdf_path,
        ucd_version: "17.0.0",
        now: Time.utc(2026, 6, 30, 12, 0, 0),
        extractor: StubExtractor.new(block: basic_latin_block,
                                     codepoints: [0x0041, 0x0042]),
      )
      summary = writer.write(basic_latin_block)
      expect(summary.svgs_written).to eq(2)
    end
  end
end
