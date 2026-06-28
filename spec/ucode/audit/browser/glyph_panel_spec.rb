# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Browser::GlyphPanel, type: :emitter_spec do
  let(:root) { Pathname.new(Dir.mktmpdir("ucode-glyph-panel")) }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  def write_universal_set(entries:, glyphs:)
    root.join("manifest.json").write(JSON.generate({
      "unicode_version" => "17.0.0",
      "ucode_version" => "0.2.0",
      "generated_at" => "2026-06-28T00:00:00Z",
      "source_config_sha256" => "abc",
      "totals" => {
        "codepoints_assigned" => entries.size,
        "codepoints_built" => entries.size,
        "codepoints_skipped" => 0,
        "codepoints_failed" => 0,
      },
      "by_tier" => {},
      "entries" => entries,
    }))
    glyphs_dir = root.join("glyphs")
    glyphs_dir.mkpath
    glyphs.each do |cp, svg|
      glyphs_dir.join(format("U+%04X.svg", cp)).write(svg)
    end
  end

  describe "#available?" do
    it "is false when universal_set_root is nil" do
      panel = described_class.new(universal_set_root: nil)
      expect(panel.available?).to be(false)
    end

    it "is false when the root directory does not exist" do
      panel = described_class.new(universal_set_root: root.join("does-not-exist"))
      expect(panel.available?).to be(false)
    end

    it "is false when the manifest file is missing" do
      root.join("glyphs").mkpath
      panel = described_class.new(universal_set_root: root)
      expect(panel.available?).to be(false)
    end

    it "is false when the glyphs directory is missing" do
      root.join("manifest.json").write("{}")
      panel = described_class.new(universal_set_root: root)
      expect(panel.available?).to be(false)
    end

    it "is true when manifest + glyphs dir both present" do
      write_universal_set(entries: [], glyphs: {})
      panel = described_class.new(universal_set_root: root)
      expect(panel.available?).to be(true)
    end
  end

  describe "#to_hash" do
    let(:svg_a) { "<svg xmlns=\"http://www.w3.org/2000/svg\"/>" }
    let(:entries) do
      [
        { "codepoint" => 0x41, "id" => "U+0041", "tier" => "tier-1",
          "source" => "noto-sans", "svg_sha256" => "x", "svg_size_bytes" => 100 },
      ]
    end

    before do
      write_universal_set(entries: entries, glyphs: { 0x41 => svg_a })
    end

    it "returns full panel data when the glyph is present" do
      panel = described_class.new(universal_set_root: root)
      result = panel.to_hash(0x41)
      expect(result).to eq(
        "codepoint" => 0x41,
        "id" => "U+0041",
        "available" => true,
        "svg" => svg_a,
        "tier" => "tier-1",
        "source" => "noto-sans",
      )
    end

    it "returns available=false when the glyph file is missing" do
      panel = described_class.new(universal_set_root: root)
      result = panel.to_hash(0x42)
      expect(result["available"]).to be(false)
      expect(result["svg"]).to be_nil
      expect(result["id"]).to eq("U+0042")
    end

    it "returns tier/source nil when the codepoint is not in the manifest" do
      panel = described_class.new(universal_set_root: root)
      result = panel.to_hash(0x99)
      expect(result["tier"]).to be_nil
      expect(result["source"]).to be_nil
    end

    context "when universal_set_root is nil" do
      it "returns a stub with available=false and nil fields" do
        panel = described_class.new(universal_set_root: nil)
        result = panel.to_hash(0x41)
        expect(result).to eq(
          "codepoint" => 0x41,
          "id" => "U+0041",
          "available" => false,
          "svg" => nil,
          "tier" => nil,
          "source" => nil,
        )
      end
    end
  end
end
