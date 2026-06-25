# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Ucode::Glyphs::LastResort::Writer do
  let(:fixture_root) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "last_resort")
  end

  let(:source) { Ucode::Glyphs::LastResort::Source.new(root: fixture_root) }

  let(:block_lookup) do
    ->(cp) do
      case cp
      when 0x0..0x7F    then "Basic_Latin"
      when 0x370..0x3FF then "Greek_And_Coptic"
      when 0xFFFE, 0xFFFF then "Specials"
      else nil
      end
    end
  end

  it "writes glyph.svg per codepoint under the block directory" do
    Dir.mktmpdir do |output_root|
      writer = described_class.new(output_root: output_root, source: source)
      tally = writer.write_many([0x41, 0x373, 0xFFFE], block_lookup: block_lookup)

      expect(tally).to eq({ written: 3, skipped: 0, missing: 0, total: 3 })
      expect(File.exist?(File.join(output_root, "blocks", "Basic_Latin", "U+0041", "glyph.svg"))).to be true
      expect(File.exist?(File.join(output_root, "blocks", "Greek_And_Coptic", "U+0373", "glyph.svg"))).to be true
      expect(File.exist?(File.join(output_root, "blocks", "Specials", "U+FFFE", "glyph.svg"))).to be true
    end
  end

  it "skips codepoints whose block lookup returns nil" do
    Dir.mktmpdir do |output_root|
      writer = described_class.new(output_root: output_root, source: source)
      tally = writer.write_many([0x41, 0x9999], block_lookup: block_lookup)
      expect(tally[:missing]).to eq(1)
      expect(tally[:written]).to eq(1)
    end
  end

  it "is idempotent on re-run (same content is a no-op)" do
    Dir.mktmpdir do |output_root|
      writer = described_class.new(output_root: output_root, source: source)
      first = writer.write_many([0x41], block_lookup: block_lookup)
      second = writer.write_many([0x41], block_lookup: block_lookup)

      expect(first[:written]).to eq(1)
      expect(second[:skipped]).to eq(1)
      expect(second[:written]).to eq(0)
    end
  end

  it "writes a non-empty SVG document" do
    Dir.mktmpdir do |output_root|
      writer = described_class.new(output_root: output_root, source: source)
      writer.write_many([0x41], block_lookup: block_lookup)
      svg = File.read(File.join(output_root, "blocks", "Basic_Latin", "U+0041", "glyph.svg"))
      expect(svg.length).to be > 100
      expect(svg).to include("<svg")
    end
  end
end
