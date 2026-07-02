# frozen_string_literal: true

require "spec_helper"
require "pathname"
require "tmpdir"

# Real stubs (no doubles) — Struct-based, matching the no-doubles rule.
CodepointStub = Struct.new(:cp) unless defined?(CodepointStub)

class SourceStub < Ucode::Glyphs::Source
  def initialize(responses)
    super()
    @responses = responses
    @calls = 0
  end

  def tier
    :test
  end

  def provenance
    "test-stub"
  end

  def fetch(codepoint)
    @responses[codepoint]
  end
end

RSpec.describe Ucode::Glyphs::ResolverFactory do
  let(:tmpdir) { Pathname.new(Dir.mktmpdir("resolver-factory-")) }
  let(:config_path) { tmpdir.join("config.yml") }

  before do
    config_path.write(<<~YAML)
      ---
      unicode_version: 17.0.0
      ucode_version: test
      generated_at: '2026-07-01T00:00:00Z'
      default_sources: []
    YAML
  end

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  describe ".build" do
    it "returns a configured Resolver" do
      skip "Database fixtures missing" unless File.exist?(Ucode::Cache.sqlite_path("17.0.0"))
      skip "source config requires real fontist setup" # real SourceBuilder needs fonts

      resolver = described_class.build(
        version: "17.0.0",
        source_config_path: config_path,
      )
      expect(resolver).to be_a(Ucode::Glyphs::Resolver)
    end

    it "accepts an already-open Database" do
      skip "requires real Database fixture" unless File.exist?(Ucode::Cache.sqlite_path("17.0.0"))

      db = Ucode::Database.open("17.0.0")
      resolver = described_class.build(
        version: "17.0.0",
        source_config_path: config_path,
        database: db,
      )
      expect(resolver).to be_a(Ucode::Glyphs::Resolver)
    end
  end

  describe "interface contract" do
    it "exposes only build as a public class method" do
      public_methods = described_class.methods(false)
      expect(public_methods).to include(:build)
      expect(public_methods).not_to include(:resolve_config_path)
    end

    it "defaults install to false" do
      const = described_class.const_get(:DEFAULT_INSTALL)
      expect(const).to be(false)
    end
  end
end
