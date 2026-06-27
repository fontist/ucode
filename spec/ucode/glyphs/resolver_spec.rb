# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Glyphs::Resolver do
  # Minimal real Source subclass for resolver testing. Returns a
  # Result for codepoints in its set, nil otherwise. Not a double —
  # a concrete Source subclass with real behavior.
  let(:source_class) do
    Class.new(Ucode::Glyphs::Source) do
      def initialize(tier:, provenance:, codepoints:)
        super()
        @tier = tier
        @provenance = provenance
        @codepoints = codepoints
      end

      def tier = @tier
      def provenance = @provenance

      def fetch(codepoint)
        return nil unless @codepoints.include?(codepoint)

        Ucode::Glyphs::Source::Result.new(
          tier: @tier, codepoint: codepoint,
          svg: "<svg from=#{@provenance}/>", provenance: @provenance,
        )
      end
    end
  end

  let(:tier1_source) do
    source_class.new(tier: :tier1, provenance: "tier-1:fixture",
                     codepoints: [0x41, 0x42])
  end

  let(:pillar3_source) do
    source_class.new(tier: :pillar3, provenance: "pillar-3:fallback",
                     codepoints: (0x0..0x10FFFF).to_a)
  end

  describe "#resolve" do
    it "returns the Tier 1 result when Tier 1 covers the codepoint" do
      resolver = described_class.new(sources: [tier1_source, pillar3_source])
      result = resolver.resolve(0x41)
      expect(result.tier).to eq(:tier1)
      expect(result.provenance).to eq("tier-1:fixture")
    end

    it "falls through to Pillar 3 when Tier 1 returns nil" do
      resolver = described_class.new(sources: [tier1_source, pillar3_source])
      result = resolver.resolve(0x43)
      expect(result.tier).to eq(:pillar3)
      expect(result.provenance).to eq("pillar-3:fallback")
    end

    it "returns nil when every source returns nil" do
      resolver = described_class.new(sources: [tier1_source])
      expect(resolver.resolve(0x43)).to be_nil
    end

    it "tries sources within a tier in declared order" do
      first = source_class.new(tier: :tier1, provenance: "tier-1:first",
                               codepoints: [0x41])
      second = source_class.new(tier: :tier1, provenance: "tier-1:second",
                                codepoints: [0x41])
      resolver = described_class.new(sources: [first, second])
      expect(resolver.resolve(0x41).provenance).to eq("tier-1:first")
    end

    it "honors a custom order" do
      resolver = described_class.new(
        sources: [tier1_source, pillar3_source],
        order: %i[pillar3 tier1],
      )
      # Pillar 3 is tried first and covers everything; Tier 1 never runs.
      expect(resolver.resolve(0x41).tier).to eq(:pillar3)
    end
  end

  describe "#sources" do
    it "returns the flat list of all registered sources" do
      resolver = described_class.new(sources: [tier1_source, pillar3_source])
      expect(resolver.sources.length).to eq(2)
    end
  end

  describe "#sources_for_tier" do
    it "returns only sources matching the requested tier" do
      resolver = described_class.new(sources: [tier1_source, pillar3_source])
      expect(resolver.sources_for_tier(:tier1)).to eq([tier1_source])
      expect(resolver.sources_for_tier(:pillar3)).to eq([pillar3_source])
      expect(resolver.sources_for_tier(:pillar1)).to eq([])
    end
  end
end
