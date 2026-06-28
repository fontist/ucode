# frozen_string_literal: true

require "spec_helper"
require "support/local_http"
require "fileutils"
require "pathname"
require "tmpdir"
require "zip"

RSpec.describe Ucode::Models::SpecialistFontManifest do
  describe ".from_yaml round-trip" do
    let(:yaml) do
      <<~YAML
        ---
        fonts:
        - label: Lentariso
          version: '1.033'
          license: OFL
          url: https://example.com/Lentariso.otf
          sha256: abc123
          path: data/fonts/Lentariso.otf
          extract: false
          provenance: Imperial Aramaic
        - label: FSung
          version: '2024'
          license: OFL
          url: null
          path: "~/Downloads/全宋體/FSung-*.ttf"
          extract: false
          provenance: Taiwan MOE
      YAML
    end

    it "parses fonts in declared order" do
      manifest = described_class.from_yaml(yaml)
      expect(manifest.labels).to eq(%w[Lentariso FSung])
    end

    it "exposes typed SpecialistFont entries" do
      manifest = described_class.from_yaml(yaml)
      first = manifest.fonts.first
      expect(first).to be_a(Ucode::Models::SpecialistFont)
      expect(first.label).to eq("Lentariso")
      expect(first.extract?).to be(false)
      expect(first.hash_known?).to be(true)
    end

    it "marks url:null entries as local-only" do
      manifest = described_class.from_yaml(yaml)
      expect(manifest.find_by_label("FSung")).to be_local_only
      expect(manifest.find_by_label("Lentariso")).not_to be_local_only
    end

    it "round-trips through to_yaml preserving fields" do
      manifest = described_class.from_yaml(yaml)
      reparsed = described_class.from_yaml(manifest.to_yaml)
      expect(reparsed.labels).to eq(manifest.labels)
      expect(reparsed.find_by_label("Lentariso").sha256).to eq("abc123")
    end
  end

  describe "#find_by_label" do
    it "returns nil for an unknown label" do
      manifest = described_class.new(fonts: [
        Ucode::Models::SpecialistFont.new(label: "X"),
      ])
      expect(manifest.find_by_label("nope")).to be_nil
    end
  end

  describe "#only" do
    it "returns a single-font manifest for a known label" do
      manifest = described_class.new(fonts: [
        Ucode::Models::SpecialistFont.new(label: "A"),
        Ucode::Models::SpecialistFont.new(label: "B"),
      ])
      only_a = manifest.only("A")
      expect(only_a.labels).to eq(%w[A])
    end

    it "returns self unchanged for an unknown label" do
      manifest = described_class.new(fonts: [
        Ucode::Models::SpecialistFont.new(label: "A"),
      ])
      expect(manifest.only("nope")).to be(manifest)
    end
  end
end
