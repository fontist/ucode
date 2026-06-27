# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Models::GlyphSource do
  describe ".from_hash" do
    it "round-trips kind=fontist entries" do
      source = described_class.from_hash(
        "kind" => "fontist",
        "label" => "noto-sans",
        "priority" => 1,
        "license" => "OFL",
        "provenance" => "Google Noto Sans",
      )
      expect(source.kind).to eq("fontist")
      expect(source.label).to eq("noto-sans")
      expect(source.priority).to eq(1)
      expect(source.license).to eq("OFL")
      expect(source.provenance).to eq("Google Noto Sans")
    end

    it "round-trips kind=path entries" do
      source = described_class.from_hash(
        "kind" => "path",
        "label" => "FSung-3",
        "path" => "/tmp/FSung-3.ttf",
        "priority" => 1,
      )
      expect(source.kind).to eq("path")
      expect(source.path).to eq("/tmp/FSung-3.ttf")
    end

    it "applies the default priority of 100 when absent" do
      source = described_class.from_hash("kind" => "fontist", "label" => "fallback")
      expect(source.priority).to eq(100)
    end
  end

  describe "#kind_sym" do
    it "casts the kind string to a symbol" do
      source = described_class.from_hash("kind" => "path", "label" => "x")
      expect(source.kind_sym).to eq(:path)
    end

    it "raises when kind is missing" do
      source = described_class.new(label: "x")
      expect { source.kind_sym }.to raise_error(ArgumentError, /kind is required/)
    end
  end

  describe "#requires_path?" do
    it "is true for kind=path" do
      source = described_class.from_hash("kind" => "path", "label" => "x", "path" => "/a")
      expect(source.requires_path?).to be true
    end

    it "is false for kind=fontist" do
      source = described_class.from_hash("kind" => "fontist", "label" => "x")
      expect(source.requires_path?).to be false
    end
  end

  describe "#to_font_spec" do
    it "renders label=path for kind=path" do
      source = described_class.from_hash(
        "kind" => "path", "label" => "FSung-3", "path" => "/tmp/FSung-3.ttf",
      )
      expect(source.to_font_spec).to eq("FSung-3=/tmp/FSung-3.ttf")
    end

    it "renders label alone for kind=fontist" do
      source = described_class.from_hash("kind" => "fontist", "label" => "noto-sans")
      expect(source.to_font_spec).to eq("noto-sans")
    end

    it "renders label alone for kind=system" do
      source = described_class.from_hash("kind" => "system", "label" => "system-ui")
      expect(source.to_font_spec).to eq("system-ui")
    end

    it "raises when kind=path but path is missing" do
      source = described_class.from_hash("kind" => "path", "label" => "x")
      expect { source.to_font_spec }.to raise_error(ArgumentError, /no path/)
    end
  end

  describe ".to_hash round-trip" do
    it "serializes back to the original wire shape" do
      hash = {
        "kind" => "path", "label" => "x", "path" => "/a",
        "priority" => 1, "license" => "OFL", "provenance" => "p"
      }
      source = described_class.from_hash(hash)
      expect(source.to_hash).to include(hash)
    end
  end
end
