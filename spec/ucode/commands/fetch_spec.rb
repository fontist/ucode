# frozen_string_literal: true

require "spec_helper"
require "support/local_http"
require "tmpdir"
require "pathname"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::FetchCommand do
  let(:version) { "17.0.0" }
  let(:cmd) { described_class.new }

  around do |example|
    Dir.mktmpdir do |cache_root|
      original = Ucode.configuration.cache_root
      Ucode.configuration.cache_root = Pathname.new(cache_root)
      Ucode::Cache.ensure_version_dir!(version)
      begin
        example.run
      ensure
        Ucode.configuration.cache_root = original
      end
    end
  end

  describe "#fetch_ucd" do
    it "delegates to Fetch::UcdZip and returns the version + ucd_dir" do
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/ucd"))

      result = cmd.fetch_ucd(version)
      expect(result[:version]).to eq(version)
      expect(result[:ucd_dir].to_s).to eq("/tmp/ucd")
    end

    it "passes force through" do
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: true)
        .and_return(Pathname.new("/tmp/ucd"))

      cmd.fetch_ucd(version, force: true)
    end

    it "accepts the already-resolved version string (resolution lives in the CLI)" do
      expect(Ucode::Fetch::UcdZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/ucd"))

      cmd.fetch_ucd(version)
    end
  end

  describe "#fetch_unihan" do
    it "delegates to Fetch::UnihanZip" do
      expect(Ucode::Fetch::UnihanZip).to receive(:call)
        .with(version, force: false)
        .and_return(Pathname.new("/tmp/unihan"))

      result = cmd.fetch_unihan(version)
      expect(result[:unihan_dir].to_s).to eq("/tmp/unihan")
    end
  end

  describe "#fetch_charts" do
    it "delegates to Fetch::CodeCharts with explicit cps" do
      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .with(version, block_first_cps: [0x0000, 0x0080], force: false)
        .and_return(2)

      result = cmd.fetch_charts(version, block_first_cps: [0x0000, 0x0080])
      expect(result[:downloaded]).to eq(2)
    end

    it "derives block_first_cps from Blocks.txt when nil" do
      ucd_dir = Ucode::Cache.ucd_dir(version)
      ucd_dir.join("Blocks.txt").write(<<~TXT)
        0000..007F; Basic Latin
        0080..00FF; Latin-1 Supplement
      TXT

      expect(Ucode::Fetch::CodeCharts).to receive(:call)
        .with(version, block_first_cps: [0x0000, 0x0080], force: false)
        .and_return(0)

      cmd.fetch_charts(version, block_first_cps: nil)
    end
  end

  describe "#fetch_fonts" do
    let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-cmd-fonts-")) }
    let(:manifest_path) { workdir.join("specialist_fonts.yml") }
    let(:source_file) { workdir.join("Lentariso.otf") }
    let(:url) { "https://example.com/Lentariso.otf" }
    let(:http) { LocalHttp.new(url => source_file) }
    let(:real_fetcher) do
      Ucode::Fetch::SpecialistFontFetcher.new(
        manifest_path: manifest_path, fonts_root: workdir.join("fonts"), http: http,
      )
    end

    after { safe_remove(workdir) if workdir.exist? }

    before do
      source_file.dirname.mkpath
      source_file.binwrite("FAKE-FONT-BYTES")
      manifest_path.write(YAML.dump("fonts" => [
        { "label" => "Lentariso", "license" => "OFL", "url" => url,
          "sha256" => nil, "path" => "Lentariso.otf", "extract" => false },
      ]))
    end

    it "delegates to SpecialistFontFetcher and returns a structured summary" do
      allow(Ucode::Fetch::SpecialistFontFetcher).to receive(:new)
        .with(hash_including(manifest_path: manifest_path,
                             allow_proprietary: false,
                             dry_run: false))
        .and_return(real_fetcher)

      result = cmd.fetch_fonts(manifest_path: manifest_path)
      expect(result[:manifest]).to eq(manifest_path.to_s)
      expect(result[:total]).to eq(1)
      expect(result[:downloaded]).to eq(1)
      expect(result[:failed]).to eq(0)
      expect(result[:results].first).to be_downloaded
    end
  end
end
