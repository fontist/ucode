# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe Ucode::Glyphs::Writer do
  let(:basic_latin_pdf) do
    Pathname.new(File.expand_path("../../fixtures/pdfs/basic_latin.pdf", __dir__))
  end

  describe "#write_block on the Basic Latin fixture", :integration do
    let(:block) do
      Ucode::Models::Block.new(
        id: "Basic_Latin",
        name: "Basic Latin",
        range_first: 0x0000,
        range_last: 0x007F,
        plane_number: 0,
        codepoint_ids: (0x0000..0x007F).map { |cp| format("U+%04X", cp) },
      )
    end

    it "writes glyph.svg for every visible codepoint in the block range" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        tally = writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        # U+0020..U+007F = 96 visible codepoints (controls are not on the page).
        expect(tally[:written]).to eq(96)
        expect(tally[:no_grid]).to eq(0)
      end
    end

    it "writes placeholder glyph.svg for assigned codepoints missing from the page" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        tally = writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        # U+0000..U+001F = 32 control chars: no glyph on the page → placeholders.
        expect(tally[:placeholder]).to eq(32)
        path = File.join(out, "blocks/Basic_Latin/U+0000/glyph.svg")
        expect(File).to exist(path)
        content = File.read(path)
        expect(content).to include("no glyph")
      end
    end

    it "writes a 1000×1000 viewBox SVG for U+0041" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        path = File.join(out, "blocks/Basic_Latin/U+0041/glyph.svg")
        expect(File).to exist(path)
        content = File.read(path)
        expect(content).to include("<svg")
        expect(content).to include('viewBox="0 0 1000 1000"')
        expect(content).to include("<path")
      end
    end

    it "skips codepoints outside the block range" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        # U+0080 (start of Latin-1 Supplement) shares the page but is outside the block.
        path = File.join(out, "blocks/Basic_Latin/U+0080/glyph.svg")
        expect(File).not_to exist(path)
      end
    end

    it "is idempotent: second run writes nothing" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        first = writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        second = writer.write_block(
          block: block,
          pdf_path: basic_latin_pdf,
          page_map: { 2 => 0x0020 },
        )
        expect(first[:written]).to eq(96)
        expect(first[:placeholder]).to eq(32)
        expect(second[:written]).to eq(0)
        expect(second[:placeholder]).to eq(0)
        expect(second[:skipped]).to eq(96)
      end
    end
  end

  describe "#write_block in strict mode" do
    let(:block) do
      Ucode::Models::Block.new(
        id: "Basic_Latin",
        name: "Basic Latin",
        range_first: 0x0000,
        range_last: 0x007F,
        plane_number: 0,
        codepoint_ids: [],
      )
    end

    it "raises GlyphError when the PDF is missing" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        expect {
          writer.write_block(
            block: block,
            pdf_path: "/nonexistent/U0000.pdf",
            page_map: { 2 => 0x0020 },
            strict: true,
          )
        }.to raise_error(Ucode::GlyphError, /no PDF available/) do |err|
          expect(err.context[:block_id]).to eq("Basic_Latin")
        end
      end
    end

    it "writes placeholders for all assigned codepoints when PDF missing and not strict" do
      block_with_cps = Ucode::Models::Block.new(
        id: "Basic_Latin",
        name: "Basic Latin",
        range_first: 0x0000,
        range_last: 0x0001,
        plane_number: 0,
        codepoint_ids: %w[U+0000 U+0001],
      )
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out)
        tally = writer.write_block(
          block: block_with_cps,
          pdf_path: "/nonexistent/U0000.pdf",
          page_map: { 2 => 0x0020 },
        )
        expect(tally[:placeholder]).to eq(2)
        expect(tally[:no_grid]).to eq(1)
        expect(File).to exist(File.join(out, "blocks/Basic_Latin/U+0000/glyph.svg"))
        expect(File).to exist(File.join(out, "blocks/Basic_Latin/U+0001/glyph.svg"))
      end
    end
  end

  describe "#write_page on an empty page" do
    let(:narrow_block) do
      Ucode::Models::Block.new(
        id: "Basic_Latin",
        name: "Basic Latin",
        range_first: 0x0000,
        range_last: 0x007F,
        plane_number: 0,
        codepoint_ids: [],
      )
    end

    it "returns no_grid: 1 when the renderer fails" do
      Dir.mktmpdir do |out|
        renderer = stub_failing_renderer
        writer = described_class.new(output_root: out, renderer: renderer)
        tally = writer.write_page(
          block: narrow_block,
          pdf_path: basic_latin_pdf,
          page_num: 999, # non-existent page
          first_cp: 0x0020,
        )
        expect(tally[:no_grid]).to eq(1)
      end
    end
  end

  describe "#write_all", :integration do
    let(:block_a) do
      Ucode::Models::Block.new(
        id: "Basic_Latin", name: "Basic Latin",
        range_first: 0x0000, range_last: 0x007F, plane_number: 0,
        codepoint_ids: (0x0000..0x007F).map { |cp| format("U+%04X", cp) },
      )
    end

    let(:block_b) do
      Ucode::Models::Block.new(
        id: "Latin_1_Supplement", name: "Latin-1 Supplement",
        range_first: 0x0080, range_last: 0x00FF, plane_number: 0,
        codepoint_ids: [],
      )
    end

    it "aggregates tallies across multiple block specs" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out, parallel_workers: 1)
        tally = writer.write_all([
          { block: block_a, pdf_path: basic_latin_pdf, page_map: { 2 => 0x0020 } },
          { block: block_b, pdf_path: basic_latin_pdf, page_map: { 2 => 0x0020 } },
        ])
        # Page 2 covers U+0020..U+009F (8 cols × 16 rows = 128 cells).
        # block_a (U+0000..U+007F) extracts U+0020..U+007F = 96 cells,
        #   plus 32 placeholders for the invisible U+0000..U+001F controls.
        # block_b (U+0080..U+00FF) extracts U+0080..U+009F = 32 cells;
        #   no placeholders (block_b has empty codepoint_ids).
        expect(tally[:written]).to eq(128)
        expect(tally[:placeholder]).to eq(32)
      end
    end

    it "drains blocks through a thread pool when parallel_workers > 1" do
      Dir.mktmpdir do |out|
        writer = described_class.new(output_root: out, parallel_workers: 2)
        tally = writer.write_all([
          { block: block_a, pdf_path: basic_latin_pdf, page_map: { 2 => 0x0020 } },
        ])
        expect(tally[:written]).to eq(96)
      end
    end
  end

  def stub_failing_renderer
    Class.new(Ucode::Glyphs::PageRenderer) do
      def self.render(*)
        raise Ucode::PdfRenderError.new(
          "stub renderer failure",
          context: { renderer: name },
        )
      end

      def self.available?
        true
      end

      def self.works?(**)
        true
      end
    end
  end
end
