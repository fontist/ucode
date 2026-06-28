# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "fontisan"
require "pathname"

RSpec.describe Ucode::Audit::Extractors::Aggregations do
  include_context "with fixture ucd database"

  let(:font_path) do
    Pathname.new(File.expand_path("../../../fixtures/fonts/NotoSansAdlam-Regular.ttf",
                                  __dir__))
  end
  let(:font) { Fontisan::FontLoader.load(font_path.to_s) }

  let(:manifest_entries) do
    [0x09, 0x0A, 0x28, 0x41, 0x42, 0x61].map do |cp|
      Ucode::Models::UniversalSetEntry.new(
        codepoint: cp,
        id: format("U+%04X", cp),
        tier: "tier-1",
        source: "noto-sans",
        svg_sha256: "deadbeef",
        svg_size_bytes: 100,
      )
    end
  end

  let(:manifest) do
    Ucode::Models::UniversalSetManifest.new(
      unicode_version: fixture_version,
      ucode_version: Ucode::VERSION,
      source_config_sha256: "abc123",
      entries: manifest_entries,
    )
  end

  let(:reference) do
    Ucode::Audit::UniversalSetReference.new(
      manifest: manifest, database: fixture_database,
    )
  end

  let(:context) do
    Ucode::Audit::Context.new(
      font: font,
      font_path: font_path,
      font_index: 0,
      num_fonts_in_source: 1,
      options: { ucd_version: fixture_version },
      reference: reference,
    )
  end

  let(:result) { described_class.new.extract(context) }
  let(:basic_latin) { result[:blocks].find { |b| b.name == "Basic_Latin" } }

  describe "with a UniversalSetReference wired through Context" do
    it "stamps the baseline with reference_kind = universal-set" do
      expect(result[:baseline].reference_kind).to eq("universal-set")
    end

    it "preserves the manifest's unicode_version on the baseline" do
      expect(result[:baseline].unicode_version).to eq(fixture_version)
    end

    it "attaches provenance rows to missing-codepoint lists in every block" do
      expect(basic_latin).not_to be_nil
      expect(basic_latin.missing_codepoint_provenance.length)
        .to eq(basic_latin.missing_count)
    end

    it "fills each provenance row with tier + source from the manifest" do
      sample = basic_latin.missing_codepoint_provenance.first
      expect(sample.tier).to eq("tier-1")
      expect(sample.source).to eq("noto-sans")
    end
  end
end
