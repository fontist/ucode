# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Audit::Browser::MissingGlyphPage, type: :emitter_spec do
  let(:root) { Pathname.new(Dir.mktmpdir("ucode-missing-page")) }
  let(:face_dir) do
    root.join("face")
    Pathname.new(root).join("face").tap(&:mkpath)
  end

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  def write_universal_set(entries:, glyphs:)
    uset_root = root.join("universal_glyph_set")
    uset_root.mkpath
    uset_root.join("manifest.json").write(JSON.generate({
      "unicode_version" => "17.0.0",
      "ucode_version" => "0.2.0",
      "generated_at" => "2026-06-28T00:00:00Z",
      "source_config_sha256" => "abc",
      "totals" => {
        "codepoints_assigned" => entries.size,
        "codepoints_built" => entries.size,
        "codepoints_skipped" => 0,
        "codepoints_failed" => 0,
      },
      "by_tier" => {},
      "entries" => entries,
    }))
    glyphs_dir = uset_root.join("glyphs")
    glyphs_dir.mkpath
    glyphs.each do |cp, svg|
      glyphs_dir.join(format("U+%04X.svg", cp)).write(svg)
    end
    uset_root
  end

  describe "#render" do
    it "shows the no-missing hint when there are no missing codepoints" do
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: nil)
      page = described_class.new(block_name: "Basic_Latin",
                                 missing_codepoints: [],
                                 glyph_panel: panel)
      html = page.render
      expect(html).to include("No missing codepoints")
      expect(html).to include("<title>Basic_Latin")
    end

    it "renders one thumbnail per missing codepoint with inlined SVG" do
      svg = "<svg xmlns=\"http://www.w3.org/2000/svg\"/>"
      uset_root = write_universal_set(
        entries: [
          { "codepoint" => 0x42, "id" => "U+0042", "tier" => "tier-1",
            "source" => "noto-sans", "svg_sha256" => "x", "svg_size_bytes" => 1 },
          { "codepoint" => 0x43, "id" => "U+0043", "tier" => "tier-1",
            "source" => "noto-sans", "svg_sha256" => "y", "svg_size_bytes" => 1 },
        ],
        glyphs: { 0x42 => svg, 0x43 => svg },
      )
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: uset_root)
      page = described_class.new(block_name: "Basic_Latin",
                                 missing_codepoints: [0x43, 0x42],
                                 glyph_panel: panel)

      html = page.render
      expect(html.scan('class="glyph-cell"').length).to eq(2)
      expect(html).to include("U+0042")
      expect(html).to include("U+0043")
      expect(html).to include(svg)
      expect(html.scan('<span class="glyph-na">').length).to eq(0)
    end

    it "falls back to n/a thumbnails when the universal set is unavailable" do
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: nil)
      page = described_class.new(block_name: "Basic_Latin",
                                 missing_codepoints: [0x42],
                                 glyph_panel: panel)
      html = page.render
      expect(html).to include("glyph-na")
      expect(html).to include("U+0042")
      expect(html).to include("universal-set glyphs unavailable")
    end

    it "shows overflow notice when missing_codepoints exceeds page_size" do
      svg = "<svg/>"
      uset_root = write_universal_set(
        entries: (0x41..0x44).map do |cp|
          { "codepoint" => cp, "id" => format("U+%04X", cp), "tier" => "tier-1",
            "source" => "noto-sans", "svg_sha256" => "x", "svg_size_bytes" => 1 }
        end,
        glyphs: (0x41..0x44).to_h { |cp| [cp, svg] },
      )
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: uset_root)
      page = described_class.new(block_name: "Basic_Latin",
                                 missing_codepoints: (0x41..0x44).to_a,
                                 glyph_panel: panel,
                                 page_size: 2)
      html = page.render
      expect(html.scan('class="glyph-cell"').length).to eq(2)
      expect(html).to include("+2 more codepoints not shown")
    end
  end

  describe "#write" do
    it "writes <face_dir>/missing/<BLOCK>.html atomically" do
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: nil)
      page = described_class.new(block_name: "Greek_and_Coptic",
                                 missing_codepoints: [0x037D],
                                 glyph_panel: panel)
      expect(page.write(face_dir)).to be(true)
      written = face_dir.join("missing", "Greek_and_Coptic.html")
      expect(written.exist?).to be(true)
      expect(written.read).to include("Greek_and_Coptic")
    end

    it "is idempotent on identical content" do
      panel = Ucode::Audit::Browser::GlyphPanel.new(universal_set_root: nil)
      page = described_class.new(block_name: "Greek_and_Coptic",
                                 missing_codepoints: [0x037D],
                                 glyph_panel: panel)
      page.write(face_dir)
      expect(page.write(face_dir)).to be(false)
    end
  end
end
