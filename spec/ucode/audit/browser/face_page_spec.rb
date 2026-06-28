# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Browser::FacePage, type: :emitter_spec do
  let(:report) do
    build_audit_report(
      family_name: "MonaSans",
      subfamily_name: "Regular",
      postscript_name: "MonaSans-Regular",
      covered_codepoints: [0x41, 0x42, 0x43],
    )
  end
  let(:page) { described_class.new(report: report, verbose: true, with_glyphs: false) }

  let(:root) { Dir.mktmpdir("ucode-face-page") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#render" do
    let(:html) { page.render }

    it "emits a self-contained HTML5 document" do
      expect(html).to start_with("<!DOCTYPE html>")
      expect(html).to include("<html lang=\"en\">")
    end

    it "inlines the CSS — no external stylesheet" do
      expect(html).to include("<style>")
      expect(html).not_to include('rel="stylesheet"')
      expect(html).to include("--accent")
    end

    it "inlines the JS — no external script src" do
      expect(html).to include("<script>")
      expect(html.scan('src="').length).to eq(0)
      expect(html).to include("renderOverview")
    end

    it "uses the family + subfamily as the page title" do
      expect(html).to include("<title>MonaSans Regular — ucode audit</title>")
      expect(html).to include("<h1>MonaSans Regular</h1>")
    end

    it "reflects verbose/with_glyphs flags in body data attributes" do
      expect(html).to include('data-verbose="true"')
      expect(html).to include('data-with-glyphs="false"')
    end

    it "inlines the overview JSON in the audit-overview script tag" do
      expect(html).to include('id="audit-overview"')
      match = html.match(%r{<script type="application/json" id="audit-overview">(.*?)</script>}m)
      expect(match).not_to be_nil
      payload = JSON.parse(match[1])

      expect(payload["font"]["family_name"]).to eq("MonaSans")
      expect(payload["font"]["postscript_name"]).to eq("MonaSans-Regular")
      expect(payload["baseline"]["unicode_version"]).to eq("17.0.0")
    end

    it "produces the same shape as IndexEmitter#build_index" do
      canonical = Ucode::Audit::Emitter::IndexEmitter.new.build_index(report)
      match = html.match(%r{<script type="application/json" id="audit-overview">(.*?)</script>}m)
      inlined = JSON.parse(match[1])
      expect(inlined).to eq(canonical)
    end
  end

  describe "with universal_set_root" do
    let(:universal_set_root) { Pathname.new(root).join("universal_glyph_set") }

    before do
      universal_set_root.join("glyphs").mkpath
      universal_set_root.join("manifest.json").write(JSON.generate({
        "unicode_version" => "17.0.0",
        "ucode_version" => "0.2.0",
        "entries" => [],
      }))
    end

    it "inlines a universal_set section with relative paths" do
      face_dir_path = File.join(root, "MonaSans-Regular")
      FileUtils.mkdir_p(face_dir_path)
      page = described_class.new(report: report,
                                 universal_set_root: universal_set_root,
                                 face_dir: face_dir_path)
      html = page.render
      match = html.match(%r{<script type="application/json" id="audit-overview">(.*?)</script>}m)
      payload = JSON.parse(match[1])
      expect(payload["universal_set"]["available"]).to be(true)
      expect(payload["universal_set"]["manifest_path"]).to eq("../universal_glyph_set/manifest.json")
      expect(payload["universal_set"]["glyphs_dir"]).to eq("../universal_glyph_set/glyphs/")
    end

    it "exposes the universal-set availability in body data attributes" do
      face_dir_path = File.join(root, "MonaSans-Regular")
      FileUtils.mkdir_p(face_dir_path)
      page = described_class.new(report: report,
                                 universal_set_root: universal_set_root,
                                 face_dir: face_dir_path)
      html = page.render
      expect(html).to include('data-universal-set-available="true"')
      expect(html).to include('data-universal-set-glyphs-dir="../universal_glyph_set/glyphs/"')
    end

    it "falls back to available=false when face_dir is not provided" do
      page = described_class.new(report: report,
                                 universal_set_root: universal_set_root)
      html = page.render
      expect(html).to include('data-universal-set-available="false"')
    end

    it "falls back to available=false when the root does not exist" do
      face_dir_path = File.join(root, "MonaSans-Regular")
      FileUtils.mkdir_p(face_dir_path)
      page = described_class.new(report: report,
                                 universal_set_root: "/does/not/exist",
                                 face_dir: face_dir_path)
      html = page.render
      expect(html).to include('data-universal-set-available="false"')
    end
  end

  describe "#write" do
    it "writes <face_dir>/index.html atomically" do
      face_dir = File.join(root, "MonaSans-Regular")
      FileUtils.mkdir_p(face_dir)
      expect(page.write(face_dir)).to be(true)
      expect(File.exist?(File.join(face_dir, "index.html"))).to be(true)
      expect(File.read(File.join(face_dir, "index.html")))
        .to include("MonaSans Regular")
    end

    it "is idempotent on identical content" do
      face_dir = File.join(root, "MonaSans-Regular")
      FileUtils.mkdir_p(face_dir)
      page.write(face_dir)
      expect(page.write(face_dir)).to be(false)
    end
  end
end
