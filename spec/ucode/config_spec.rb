# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Config do
  let(:config) { described_class.new }

  it "defaults cache_root to an XDG-style path" do
    expect(config.cache_root).to be_a(Pathname)
    expect(config.cache_root.to_s).to match(/ucode\/unicode\z/)
  end

  it "defaults default_version to a known version" do
    expect(config.default_version).to eq("17.0.0")
  end

  it "defaults known_versions to a non-empty array of strings" do
    expect(config.known_versions).to be_an(Array)
    expect(config.known_versions).not_to be_empty
    expect(config.known_versions).to all(be_a(String))
  end

  it "recognizes default_version as known" do
    expect(config.known?(config.default_version)).to be(true)
  end

  it "defaults parallel_workers to an Integer >= 1" do
    expect(config.parallel_workers).to be_an(Integer)
    expect(config.parallel_workers).to be >= 1
  end

  it "defaults http_timeout and http_retries to Integers" do
    expect(config.http_timeout).to be_an(Integer)
    expect(config.http_timeout).to be > 0
    expect(config.http_retries).to be_an(Integer)
    expect(config.http_retries).to be >= 0
  end

  it "defaults pdf_renderer to a Symbol" do
    expect(config.pdf_renderer).to be_a(Symbol)
  end

  it "honors UCODE_PARALLEL_WORKERS env override" do
    previous = ENV["UCODE_PARALLEL_WORKERS"]
    begin
      ENV["UCODE_PARALLEL_WORKERS"] = "2"
      expect(described_class.new.parallel_workers).to eq(2)
    ensure
      if previous.nil?
        ENV.delete("UCODE_PARALLEL_WORKERS")
      else
        ENV["UCODE_PARALLEL_WORKERS"] = previous
      end
    end
  end

  it "honors XDG_CACHE_HOME env override for cache_root" do
    previous = ENV["XDG_CACHE_HOME"]
    begin
      ENV["XDG_CACHE_HOME"] = "/tmp/ucode-xdg-test"
      expect(described_class.new.cache_root.to_s).to eq("/tmp/ucode-xdg-test/ucode/unicode")
    ensure
      if previous.nil?
        ENV.delete("XDG_CACHE_HOME")
      else
        ENV["XDG_CACHE_HOME"] = previous
      end
    end
  end

  it "exposes a non-empty set of extracted and auxiliary file names" do
    expect(config.extracted_files).to include("DerivedAge.txt")
    expect(config.auxiliary_files).to include("LineBreak.txt")
  end
end
