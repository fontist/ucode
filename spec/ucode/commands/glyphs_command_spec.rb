# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"
require "stringio"

RSpec.describe Ucode::Commands::GlyphsCommand do
  # GlyphsCommand reads Blocks.txt from Cache.ucd_dir(<version>). The
  # default cache_root points at the operator's ~/.cache, which on a
  # developer machine (or a CI runner where another spec downloaded
  # UCD) can be populated — making block_count non-deterministic.
  # Pin cache_root to a per-example tmpdir so load_blocks sees no
  # Blocks.txt and the assertion on block_count is stable.
  around do |example|
    Dir.mktmpdir do |cache_root|
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = Pathname.new(cache_root)
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe ".experimental_warning" do
    it "exposes a non-empty banner that mentions experimental status" do
      warning = described_class.experimental_warning
      expect(warning).to be_a(String)
      expect(warning).to include("experimental")
    end
  end

  describe "#call without opt-in" do
    it "returns a skipped payload and writes nothing to disk" do
      Dir.mktmpdir do |root|
        result = described_class.new.call("17.0.0", output_root: root)
        expect(result[:skipped]).to be(true)
        expect(result[:reason]).to be(:experimental_v0_1)
        expect(result[:warning]).to eq(described_class.experimental_warning)
        expect(Pathname.new(root).children).to be_empty
      end
    end
  end

  describe "#call with opt-in" do
    let(:warning_io) { StringIO.new }

    it "emits the experimental warning exactly once via warn:" do
      Dir.mktmpdir do |root|
        result = described_class.new.call(
          "17.0.0",
          output_root: root,
          include_glyphs: true,
          warn: warning_io,
        )
        expect(result[:version]).to eq("17.0.0")
        expect(result[:block_count]).to eq(0)
      end
      expect(warning_io.string).to eq("#{described_class.experimental_warning}\n")
    end
  end

  describe "#call with an unknown version" do
    it "still returns a skipped payload without raising" do
      Dir.mktmpdir do |root|
        result = described_class.new.call("not-a-version", output_root: root)
        expect(result[:skipped]).to be(true)
        expect(result[:version]).to eq("not-a-version")
      end
    end
  end
end
