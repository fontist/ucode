# frozen_string_literal: true

require "spec_helper"
require "support/local_http"
require "digest"
require "fileutils"
require "pathname"
require "tmpdir"
require "zip"

RSpec.describe Ucode::Fetch::SpecialistFontFetcher do
  let(:workdir) { Pathname.new(Dir.mktmpdir("ucode-font-fetch-")) }
  let(:fonts_root) { workdir.join("fonts") }
  let(:manifest_path) { workdir.join("specialist_fonts.yml") }
  let(:http) { LocalHttp.new }

  after { safe_remove(workdir) if workdir.exist? }

  def write_bytes(path, content)
    path = Pathname.new(path)
    path.dirname.mkpath
    path.binwrite(content)
  end

  def write_manifest(entries)
    yaml_hash = { "fonts" => entries }
    manifest_path.write(YAML.dump(yaml_hash))
  end

  def sha256_of(path)
    Digest::SHA256.file(path.to_s).hexdigest
  end

  describe "happy path: a single direct-download OFL font" do
    let(:source_file) { workdir.join("sources/Lentariso.otf") }
    let(:url) { "https://example.com/Lentariso.otf" }

    before do
      write_bytes(source_file, "FAKE-FONT-BYTES")
      http.register(url, source_file)
      write_manifest([
        { "label" => "Lentariso", "version" => "1.033", "license" => "OFL",
          "url" => url, "sha256" => nil,
          "path" => "Lentariso.otf", "extract" => false,
          "provenance" => "test font" },
      ])
    end

    it "downloads the file to fonts_root/<path>" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.size).to eq(1)
      expect(results.first).to be_downloaded
      expect(fonts_root.join("Lentariso.otf")).to exist
      expect(results.first.size_bytes).to eq(File.size(source_file))
    end

    it "records the computed SHA256 back into the manifest on first fetch" do
      described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      reloaded = Ucode::Models::SpecialistFontManifest.from_yaml(manifest_path.read)
      expect(reloaded.find_by_label("Lentariso").sha256).to eq(sha256_of(source_file))
    end
  end

  describe "idempotency: a second run skips when hash matches" do
    let(:source_file) { workdir.join("sources/Lentariso.otf") }
    let(:url) { "https://example.com/Lentariso.otf" }

    before do
      write_bytes(source_file, "FAKE-FONT-BYTES")
      http.register(url, source_file)
      write_manifest([
        { "label" => "Lentariso", "license" => "OFL", "url" => url,
          "sha256" => sha256_of(source_file),
          "path" => "Lentariso.otf", "extract" => false },
      ])
    end

    it "skips without re-downloading" do
      dest = fonts_root.join("Lentariso.otf")
      dest.dirname.mkpath
      FileUtils.cp(source_file, dest)

      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call

      expect(results.first).to be_skipped
      expect(results.first.size_bytes).to eq(dest.size)
    end
  end

  describe "checksum mismatch" do
    let(:source_file) { workdir.join("sources/Lentariso.otf") }
    let(:url) { "https://example.com/Lentariso.otf" }

    before do
      write_bytes(source_file, "FAKE-FONT-BYTES")
      http.register(url, source_file)
      write_manifest([
        { "label" => "Lentariso", "license" => "OFL", "url" => url,
          "sha256" => "0" * 64, # deliberately wrong
          "path" => "Lentariso.otf", "extract" => false },
      ])
    end

    it "records a FontChecksumError failure" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.first).to be_failed
      expect(results.first.error).to be_a(Ucode::FontChecksumError)
    end

    it "does not write the manifest back when no new hashes were computed" do
      original_text = manifest_path.read
      described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(manifest_path.read).to eq(original_text)
    end
  end

  describe "license refusal" do
    let(:source_file) { workdir.join("sources/Commercial.ttf") }
    let(:url) { "https://example.com/Commercial.ttf" }

    before do
      write_bytes(source_file, "BYTES")
      http.register(url, source_file)
      write_manifest([
        { "label" => "Commercial", "license" => "PROPRIETARY", "url" => url,
          "sha256" => nil, "path" => "Commercial.ttf", "extract" => false },
      ])
    end

    it "fails without --allow-proprietary" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.first).to be_failed
      expect(results.first.error).to be_a(Ucode::FontLicenseError)
    end

    it "downloads when --allow-proprietary is set" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
        allow_proprietary: true,
      ).call
      expect(results.first).to be_downloaded
    end
  end

  describe "zip extraction" do
    let(:url) { "https://example.com/Kedebideri.zip" }
    let(:zip_path) { workdir.join("sources/Kedebideri.zip") }
    let(:real_ttf) { workdir.join("sources/Kedebideri-Regular.ttf") }

    before do
      write_bytes(real_ttf, "REAL-TTF-BYTES")
      zip_path.dirname.mkpath
      Zip::File.open(zip_path.to_s, create: true) do |zip|
        zip.add("Kedebideri-Regular.ttf", real_ttf.to_s)
        zip.add("README.txt", real_ttf.to_s) # noise to ensure only member is lifted
      end
      http.register(url, zip_path)
    end

    it "extracts only extract_member to the destination" do
      write_manifest([
        { "label" => "Kedebideri", "license" => "OFL", "url" => url,
          "sha256" => nil, "path" => "Kedebideri-Regular.ttf",
          "extract" => true, "extract_member" => "Kedebideri-Regular.ttf" },
      ])
      described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(fonts_root.join("Kedebideri-Regular.ttf")).to exist
      expect(fonts_root.children.map(&:to_s)).not_to include(/README/)
    end

    it "fails with FontExtractMemberMissingError when the member is absent" do
      write_manifest([
        { "label" => "Kedebideri", "license" => "OFL", "url" => url,
          "sha256" => nil, "path" => "Kedebideri-Regular.ttf",
          "extract" => true, "extract_member" => "DoesNotExist.ttf" },
      ])
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.first).to be_failed
      expect(results.first.error).to be_a(Ucode::FontExtractMemberMissingError)
    end
  end

  describe "local-only entries" do
    before do
      write_manifest([
        { "label" => "FSung", "license" => "OFL", "url" => nil,
          "sha256" => nil, "path" => "~/nonexistent-ucode-test-dir/FSung-*.ttf",
          "extract" => false, "provenance" => "user-supplied" },
      ])
    end

    it "produces a :local result with a placement note when missing" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.first).to be_local
      expect(results.first.note).to include("place at")
    end

    it "does not call http.get for the local entry" do
      # LocalHttp raises MissingRoute on any GET. If the fetcher tried
      # to call it for the local-only FSung entry, the call would raise
      # and bubble out as a failure result with the MissingRoute error.
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call
      expect(results.first).to be_local
      expect(results.first.error).to be_nil
    end
  end

  describe "unknown label via only_label" do
    before do
      write_manifest([
        { "label" => "Lentariso", "license" => "OFL", "url" => "https://example.com/x",
          "sha256" => nil, "path" => "x.ttf", "extract" => false },
      ])
    end

    it "returns a single LookupError failure" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
      ).call(only_label: "DoesNotExist")
      expect(results.size).to eq(1)
      expect(results.first).to be_failed
      expect(results.first.error).to be_a(Ucode::LookupError)
    end
  end

  describe "dry-run" do
    let(:url) { "https://example.com/Lentariso.otf" }

    before do
      write_manifest([
        { "label" => "Lentariso", "license" => "OFL", "url" => url,
          "sha256" => nil, "path" => "Lentariso.otf", "extract" => false },
        { "label" => "FSung", "license" => "OFL", "url" => nil,
          "sha256" => nil, "path" => "~/nonexistent-ucode-test-dir/FSung-*.ttf",
          "extract" => false },
      ])
    end

    it "reports :planned for downloadable entries without touching the network" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
        dry_run: true,
      ).call
      planned = results.find { |r| r.label == "Lentariso" }
      expect(planned).to be_planned
    end

    it "still reports :local for local-only entries" do
      results = described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
        dry_run: true,
      ).call
      expect(results.find { |r| r.label == "FSung" }).to be_local
    end

    it "does not write the manifest back" do
      original = manifest_path.read
      described_class.new(
        manifest_path: manifest_path, fonts_root: fonts_root, http: http,
        dry_run: true,
      ).call
      expect(manifest_path.read).to eq(original)
    end
  end
end
