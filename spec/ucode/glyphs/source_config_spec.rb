# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Glyphs::SourceConfig do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("ucode-config")) }

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  def write_config(content)
    path = tmpdir.join("tier1.yml")
    path.write(content)
    path
  end

  describe "#exist?" do
    it "is true when the file exists" do
      path = write_config("tier1_fonts: {}\n")
      expect(described_class.new(path: path)).to exist
    end

    it "is false when the file is missing" do
      expect(described_class.new(path: tmpdir.join("nope.yml"))).not_to exist
    end
  end

  describe "#tier1_fonts" do
    it "parses block names to font spec arrays" do
      path = write_config(<<~YAML)
        tier1_fonts:
          Sidetic:
            - Lentariso=/path/to/Lentariso.ttf
          Adlam:
            - noto-sans-adlam
      YAML
      config = described_class.new(path: path)
      expect(config.tier1_fonts["Sidetic"]).to eq(["Lentariso=/path/to/Lentariso.ttf"])
      expect(config.tier1_fonts["Adlam"]).to eq(["noto-sans-adlam"])
    end

    it "returns an empty hash when the file is missing" do
      config = described_class.new(path: tmpdir.join("nope.yml"))
      expect(config.tier1_fonts).to eq({})
    end

    it "returns an empty hash when tier1_fonts is absent" do
      path = write_config("other_section: {}\n")
      config = described_class.new(path: path)
      expect(config.tier1_fonts).to eq({})
    end

    it "preserves verbatim block names with underscores" do
      path = write_config(<<~YAML)
        tier1_fonts:
          CJK_Unified_Ideographs_Extension_J:
            - FSung-3=/path/to/FSung-3.ttf
      YAML
      config = described_class.new(path: path)
      expect(config.tier1_fonts.keys).to include("CJK_Unified_Ideographs_Extension_J")
    end
  end

  describe "#specs_for_block" do
    it "returns the spec array for a configured block" do
      path = write_config(<<~YAML)
        tier1_fonts:
          Sidetic:
            - Lentariso=/a.ttf
            - noto-sans-sidetic
      YAML
      config = described_class.new(path: path)
      expect(config.specs_for_block("Sidetic")).to eq(["Lentariso=/a.ttf", "noto-sans-sidetic"])
    end

    it "returns an empty array for an unconfigured block" do
      path = write_config("tier1_fonts: {}\n")
      config = described_class.new(path: path)
      expect(config.specs_for_block("Sidetic")).to eq([])
    end
  end

  describe "#configured_blocks" do
    it "lists every block name with at least one font" do
      path = write_config(<<~YAML)
        tier1_fonts:
          Sidetic:
            - Lentariso=/a.ttf
          Adlam:
            - noto-sans-adlam
      YAML
      config = described_class.new(path: path)
      expect(config.configured_blocks).to contain_exactly("Sidetic", "Adlam")
    end
  end

  describe "default path" do
    it "points at config/unicode17_tier1_fonts.yml" do
      config = described_class.new
      expect(config.path.to_s).to end_with("config/unicode17_tier1_fonts.yml")
    end
  end
end
