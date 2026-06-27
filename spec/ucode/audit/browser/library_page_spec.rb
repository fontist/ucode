# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Browser::LibraryPage, type: :emitter_spec do
  let(:reports) do
    [
      build_audit_report(
        family_name: "MonaSans",
        postscript_name: "MonaSans-Regular",
        source_file: "/tmp/Mona-Regular.otf",
        source_sha256: "a" * 64,
      ),
      build_audit_report(
        family_name: "Noto Sans",
        full_name: "Noto Sans Regular",
        postscript_name: "NotoSans-Regular",
        source_file: "/tmp/NotoSans.ttf",
        source_sha256: "b" * 64,
      ),
    ]
  end
  let(:summary) do
    build_library_summary(reports: reports,
                          aggregate_metrics: {
                            "total_codepoints" => 6,
                            "total_glyphs" => 16,
                          })
  end
  let(:page) { described_class.new(summary: summary) }

  let(:root) { Dir.mktmpdir("ucode-library-page") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  describe "#render" do
    let(:html) { page.render }

    it "emits a self-contained HTML5 document" do
      expect(html).to start_with("<!DOCTYPE html>")
      expect(html).to include("<html lang=\"en\">")
    end

    it "uses a fixed page title" do
      expect(html).to include("<title>ucode audit library</title>")
    end

    it "inlines the CSS" do
      expect(html).to include("<style>")
      expect(html).to include("--accent")
    end

    it "inlines the JS" do
      expect(html).to include("<script>")
      expect(html.scan('src="').length).to eq(0)
      expect(html).to include("renderCards")
    end

    it "inlines the library overview JSON in the library-overview script tag" do
      expect(html).to include('id="library-overview"')
      match = html.match(%r{<script type="application/json" id="library-overview">(.*?)</script>}m)
      expect(match).not_to be_nil
      payload = JSON.parse(match[1])

      expect(payload["total_faces"]).to eq(2)
      labels = payload["faces"].map { |f| f["label"] }
      expect(labels).to include("MonaSans-Regular", "NotoSans-Regular")
    end

    it "produces the same shape as LibraryEmitter#build_index" do
      canonical = Ucode::Audit::Emitter::LibraryEmitter.new.build_index(summary)
      match = html.match(%r{<script type="application/json" id="library-overview">(.*?)</script>}m)
      inlined = JSON.parse(match[1])
      expect(inlined).to eq(canonical)
    end

    it "embeds per-face rollup fields used by the card renderer" do
      match = html.match(%r{<script type="application/json" id="library-overview">(.*?)</script>}m)
      face = JSON.parse(match[1])["faces"].first
      expect(face).to include(
        "covered_total",
        "total_assigned_total",
        "blocks_complete",
        "blocks_partial",
        "index_path",
        "html_path",
      )
    end
  end

  describe "#write" do
    it "writes <library_root>/index.html atomically" do
      expect(page.write(root)).to be(true)
      written = File.join(root, "font_audit", "index.html")
      expect(File.exist?(written)).to be(true)
      expect(File.read(written)).to include("MonaSans")
    end

    it "is idempotent on identical content" do
      page.write(root)
      expect(page.write(root)).to be(false)
    end
  end
end
