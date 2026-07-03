# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Ucode::Unicode::MetadataWriter do
  describe ".version_to_filename" do
    it "converts dotted version to lowercase filename" do
      expect(described_class.version_to_filename("17.0.0")).to eq("v17_0_0")
      expect(described_class.version_to_filename("15.1.0")).to eq("v15_1_0")
    end
  end

  describe ".version_to_module" do
    it "converts dotted version to CamelCase module name" do
      expect(described_class.version_to_module("17.0.0")).to eq("V17_0_0")
      expect(described_class.version_to_module("15.1.0")).to eq("V15_1_0")
    end
  end

  describe ".generate" do
    let(:tmp_ucd) do
      Dir.mktmpdir("ucode-metadata-").tap do |dir|
        FileUtils.mkdir_p(File.join(dir, "extracted"))
        File.write(File.join(dir, "Blocks.txt"), <<~BLOCKS)
          0000..007F; Basic Latin
          0080..00FF; Latin-1 Supplement
          0100..017F; Latin Extended-A
        BLOCKS
        File.write(File.join(dir, "extracted", "DerivedGeneralCategory.txt"), <<~DGC)
          0000..001F    ; Cc # [32] CONTROL
          0020..0020    ; Zs # SPACE
          0021..007E    ; Sm # PUNCTUATION + LETTERS
          007F..009F    ; Cc # CONTROLS
          00A0          ; Zs # NBSP
          00A1..00FF    ; So # SYMBOLS
          D800..DFFF    ; Cs # SURROGATES (excluded)
          E000..F8FF    ; Co # PUA (excluded)
        DGC
      end
    end

    after { FileUtils.remove_entry(tmp_ucd) if Dir.exist?(tmp_ucd) }

    it "generates valid Ruby source with the module header" do
      source = described_class.generate(ucd_dir: tmp_ucd, version: "99.0.0")
      expect(source).to include("module V99_0_0")
      expect(source).to include('UNICODE_VERSION = "99.0.0"')
      expect(source).to include("ASSIGNED_COUNT")
      expect(source).to include("BLOCKS = [")
      expect(source).to include("# rubocop:disable all")
    end

    it "computes assigned count excluding Cn, Co, Cs" do
      source = described_class.generate(ucd_dir: tmp_ucd, version: "99.0.0")
      # Cc (0x00-0x1F: 32, 0x7F-0x9F: 33) + Zs (0x20, 0xA0: 2) + Sm (0x21-0x7E: 94) + So (0xA1-0xFF: 95)
      # = 256 (Cs surrogates and Co PUA excluded)
      expect(source).to include("ASSIGNED_COUNT = 256")
    end

    it "generates all blocks from Blocks.txt" do
      source = described_class.generate(ucd_dir: tmp_ucd, version: "99.0.0")
      expect(source).to include('"Basic_Latin"')
      expect(source).to include('"Latin-1 Supplement"')
      expect(source).to include('"Latin Extended-A"')
    end

    it "is idempotent (same input produces same output)" do
      first = described_class.generate(ucd_dir: tmp_ucd, version: "99.0.0")
      second = described_class.generate(ucd_dir: tmp_ucd, version: "99.0.0")
      expect(first).to eq(second)
    end
  end
end
