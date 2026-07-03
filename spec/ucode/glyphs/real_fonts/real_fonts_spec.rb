# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

require "ucode/glyphs/real_fonts/font_locator"
require "ucode/glyphs/real_fonts/coverage_auditor"
require "ucode/glyphs/real_fonts/writer"

RSpec.describe Ucode::Glyphs::RealFonts::FontLocator do
  let(:real_font) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "fonts",
                               "NotoSansAdlam-Regular.ttf")
  end

  describe "#locate with a direct path" do
    before { skip "fixture font missing" unless real_font.exist? }

    it "returns the path with via: :direct when the file exists" do
      result = described_class.new.locate(real_font.to_s, install: false)
      expect(result.path).to eq(real_font)
      expect(result.via).to eq(:direct)
    end

    it "accepts a label=path spec to decouple the display name from the file" do
      result = described_class.new.locate("MyLabel=#{real_font}", install: false)
      expect(result.name).to eq("MyLabel")
      expect(result.path).to eq(real_font)
    end

    it "raises Errno::ENOENT when the path does not exist and fontist cannot resolve" do
      expect {
        described_class.new.locate("/nonexistent/font.ttf", install: false)
      }.to raise_error(Errno::ENOENT, /Font not found/)
    end
  end
end

RSpec.describe Ucode::Glyphs::RealFonts::CoverageAuditor do
  let(:real_font) do
    Pathname.new(__dir__).join("..", "..", "..", "fixtures", "fonts",
                               "NotoSansAdlam-Regular.ttf")
  end

  describe "#audit" do
    before do
      skip "fixture font missing" unless real_font.exist?
      unless Fontisan::Commands.const_defined?(:AuditCommand)
        skip "Fontisan::Commands::AuditCommand not available in this fontisan version"
      end
    end

    it "produces a FontCoverageReport with identity pulled from the name table" do
      report = described_class.new.audit(real_font)
      expect(report).to be_a(Ucode::Glyphs::RealFonts::FontCoverageReport)
      expect(report.family_name).to eq("Noto Sans Adlam")
      expect(report.total_codepoints).to be_positive
      expect(report.blocks.length).to eq(Ucode::Glyphs::RealFonts::Unicode17Blocks::ALL.length)
    end

    it "computes covered by intersecting the font cmap with each block's assigned ranges" do
      report = described_class.new.audit(real_font)
      # Adlam is U+1E00-U+1E9F — outside every Unicode 17 new block,
      # so every block should report 0 covered codepoints.
      expect(report.blocks.map(&:covered)).to all(eq(0))
    end
  end
end

RSpec.describe Ucode::Glyphs::RealFonts::Writer do
  let(:report) do
    Ucode::Glyphs::RealFonts::FontCoverageReport.new(
      source_file: "Test.ttf",
      family_name: "Test",
      total_codepoints: 100,
      total_glyphs: 100,
      blocks: [
        Ucode::Glyphs::RealFonts::BlockCoverage.new(
          name: "Sidetic", first_cp: 0x10940, last_cp: 0x1095F,
          assigned: 26, covered: 26, missing_cps: [],
        ),
      ],
    )
  end

  it "writes one JSON file under <output>/font_coverage/<basename>.json" do
    Dir.mktmpdir do |dir|
      path = described_class.new(dir).write(report)
      expect(path).to eq(Pathname(dir).join("font_coverage", "Test.json"))
      expect(path).to exist
      parsed = JSON.parse(path.read)
      expect(parsed["family_name"]).to eq("Test")
      expect(parsed["blocks"].first["name"]).to eq("Sidetic")
    end
  end

  it "sanitizes the basename so non-alphanumeric characters become underscores" do
    weird_report = Ucode::Glyphs::RealFonts::FontCoverageReport.new(
      source_file: "weird name (1).ttf",
    )
    Dir.mktmpdir do |dir|
      path = described_class.new(dir).write(weird_report)
      expect(path.basename.to_s).to eq("weird_name__1_.json")
    end
  end
end
