# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Repo::BuildReportAccumulator do
  # Concrete Source subclass — not a double. Returns a Result for
  # codepoints in its set, nil otherwise.
  let(:source_class) do
    Class.new(Ucode::Glyphs::Source) do
      def initialize(tier:, provenance:, svg:, codepoints:)
        super()
        @tier = tier
        @provenance = provenance
        @svg = svg
        @codepoints = codepoints
      end

      def tier = @tier
      def provenance = @provenance

      def fetch(codepoint)
        return nil unless @codepoints.include?(codepoint)

        Ucode::Glyphs::Source::Result.new(
          tier: @tier, codepoint: codepoint, svg: @svg,
          provenance: @provenance,
        )
      end
    end
  end

  let(:tier1_source) do
    source_class.new(tier: :tier1, provenance: "tier-1:fixture",
                     svg: "<svg/>", codepoints: [0x41, 0x42])
  end

  let(:pillar3_source) do
    source_class.new(tier: :pillar3, provenance: "pillar-3:last-resort",
                     svg: "<svg/>", codepoints: (0x0..0x10FFFF).to_a)
  end

  let(:resolver) do
    Ucode::Glyphs::Resolver.new(sources: [tier1_source, pillar3_source])
  end

  let(:accumulator) do
    described_class.new(unicode_version: "17.0.0",
                        ucode_version: "0.2.0")
  end

  def cp(int, block_id: "ASCII")
    Ucode::Models::CodePoint.new(
      cp: int, id: format("U+%04X", int), name: "L#{int}", block_id: block_id,
    )
  end

  describe "#call" do
    it "counts assigned + built when result is non-nil" do
      accumulator.call(cp(0x41), resolver.resolve(0x41))
      report = accumulator.to_report
      expect(report.totals.assigned).to eq(1)
      expect(report.totals.built).to eq(1)
      expect(report.totals.skipped).to eq(0)
    end

    it "counts assigned + skipped when result is nil" do
      accumulator.call(cp(0x99), nil)
      report = accumulator.to_report
      expect(report.totals.assigned).to eq(1)
      expect(report.totals.built).to eq(0)
      expect(report.totals.skipped).to eq(1)
    end

    it "records per-tier counts using wire names (tier-1, pillar-3)" do
      accumulator.call(cp(0x41), resolver.resolve(0x41)) # tier-1
      accumulator.call(cp(0x43), resolver.resolve(0x43)) # falls through to pillar-3
      report = accumulator.to_report
      expect(report.by_tier).to eq("tier-1" => 1, "pillar-3" => 1)
    end

    it "records per-block breakdown including tier_breakdown" do
      accumulator.call(cp(0x41, block_id: "ASCII"), resolver.resolve(0x41))
      accumulator.call(cp(0x1E900, block_id: "Adlam"), resolver.resolve(0x1E900))
      report = accumulator.to_report
      ascii = report.by_block.find { |b| b.name == "ASCII" }
      adlam = report.by_block.find { |b| b.name == "Adlam" }
      expect(ascii.assigned).to eq(1)
      expect(ascii.tier_breakdown).to eq("tier-1" => 1)
      expect(adlam.assigned).to eq(1)
      expect(adlam.tier_breakdown).to eq("pillar-3" => 1)
    end
  end

  describe "#record_failure" do
    it "increments failed count and appends a Failure record" do
      error = RuntimeError.new("boom")
      accumulator.record_failure(cp(0x41), error, tier: :tier1)
      report = accumulator.to_report
      expect(report.totals.failed).to eq(1)
      expect(report.failures.length).to eq(1)
      expect(report.failures.first.codepoint).to eq(0x41)
      expect(report.failures.first.error_class).to eq("RuntimeError")
      expect(report.failures.first.tier).to eq("tier1")
    end

    it "accepts a nil codepoint for structural failures" do
      accumulator.record_failure(nil, RuntimeError.new("db missing"))
      report = accumulator.to_report
      expect(report.totals.failed).to eq(1)
      expect(report.failures.first.codepoint).to be_nil
    end
  end

  describe "thread safety" do
    it "handles concurrent calls without losing updates" do
      threads = Array.new(8) do |i|
        Thread.new do
          25.times do |j|
            codepoint = cp(0x100 + i * 100 + j)
            accumulator.call(codepoint, resolver.resolve(codepoint.cp))
          end
        end
      end
      threads.each(&:join)
      report = accumulator.to_report
      expect(report.totals.assigned).to eq(200)
      expect(report.totals.built).to eq(200)
    end
  end

  describe "wire tier mapping" do
    it "maps :tier1 → tier-1, :pillar1 → pillar-1, :pillar2 → pillar-2, :pillar3 → pillar-3" do
      accumulator.call(cp(0x41), Ucode::Glyphs::Source::Result.new(
                                   tier: :pillar2, codepoint: 0x41, svg: "<svg/>", provenance: "p2",
                                 ))
      report = accumulator.to_report
      expect(report.by_tier).to eq("pillar-2" => 1)
    end
  end
end
