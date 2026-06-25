# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe Ucode::Cache do
  around do |example|
    original = Ucode.configuration.cache_root
    Ucode.configuration.cache_root = Pathname.new(Dir.mktmpdir("ucode-cache-spec"))
    example.run
  ensure
    Ucode.configuration.cache_root = original
  end

  it "returns Pathname objects for every path method" do
    expect(described_class.root).to be_a(Pathname)
    %i[version_dir ucd_dir unihan_dir pdfs_dir index_dir sqlite_dir
       sqlite_path blocks_index_path scripts_index_path].each do |method|
      expect(described_class.public_send(method, "17.0.0")).to be_a(Pathname), method.to_s
    end
  end

  it "returns false for cached? on a fresh root" do
    expect(described_class.cached?("17.0.0")).to be(false)
  end

  it "returns true for cached? after ensure_version_dir!" do
    described_class.ensure_version_dir!("17.0.0")
    expect(described_class.cached?("17.0.0")).to be(true)
  end

  it "ensure_version_dir! is idempotent" do
    described_class.ensure_version_dir!("17.0.0")
    expect { described_class.ensure_version_dir!("17.0.0") }.not_to raise_error
  end

  it "creates all five subdirectories" do
    described_class.ensure_version_dir!("17.0.0")
    %w[ucd unihan pdfs index sqlite].each do |sub|
      path = described_class.version_dir("17.0.0").join(sub)
      expect(path).to be_directory, sub
    end
  end

  it "cached_versions lists versions present" do
    described_class.ensure_version_dir!("17.0.0")
    described_class.ensure_version_dir!("16.0.0")
    expect(described_class.cached_versions).to eq(%w[16.0.0 17.0.0])
  end

  it "remove_version wipes a version" do
    described_class.ensure_version_dir!("17.0.0")
    described_class.remove_version("17.0.0")
    expect(described_class.cached?("17.0.0")).to be(false)
  end
end
