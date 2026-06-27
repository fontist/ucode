# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

require "ucode/audit/emitter/paths"

RSpec.describe Ucode::Audit::Emitter::Paths do
  let(:root) { "/tmp/example-output" }

  describe "library root" do
    it "nests under <output_root>/font_audit" do
      expect(described_class.library_root(root).to_s)
        .to eq("/tmp/example-output/font_audit")
    end

    it "returns a Pathname" do
      expect(described_class.library_root(root)).to be_a(Pathname)
    end
  end

  describe "per-face directory" do
    it "is <library_root>/<label>" do
      expect(described_class.face_dir(root, "Mona").to_s)
        .to eq("/tmp/example-output/font_audit/Mona")
    end
  end

  describe "per-face chunk paths" do
    it "places index.json directly under the face dir" do
      expect(described_class.face_index_path(root, "Mona").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/index.json")
    end

    it "places index.html directly under the face dir" do
      expect(described_class.face_html_path(root, "Mona").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/index.html")
    end

    it "places blocks/<NAME>.json with verbatim block name" do
      path = described_class.block_path(root, "Mona", "Greek_And_Coptic")
      expect(path.to_s)
        .to eq("/tmp/example-output/font_audit/Mona/blocks/Greek_And_Coptic.json")
    end

    it "places planes/<N>.json keyed by integer plane" do
      expect(described_class.plane_path(root, "Mona", 2).to_s)
        .to eq("/tmp/example-output/font_audit/Mona/planes/2.json")
    end

    it "places scripts/<CODE>.json keyed by ISO 15924 code" do
      expect(described_class.script_path(root, "Mona", "Latn").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/scripts/Latn.json")
    end

    it "places codepoints/<NAME>.json under the face dir" do
      expect(described_class.codepoints_path(root, "Mona", "CJK_Ext_A").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/codepoints/CJK_Ext_A.json")
    end

    it "places glyphs/U+XXXX.svg under the face dir" do
      expect(described_class.glyph_path(root, "Mona", "U+0041").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/glyphs/U+0041.svg")
    end
  end

  describe "collection-face subdirectory" do
    it "prefixes the 0-based face index, zero-padded to two digits" do
      dir = described_class.collection_face_dir(root, "MonaTTC", 0, "Mona-Regular")
      expect(dir.to_s)
        .to eq("/tmp/example-output/font_audit/MonaTTC/00-Mona-Regular")
    end

    it "preserves source order for face indices > 9" do
      dir = described_class.collection_face_dir(root, "MonaTTC", 12, "Mona-Regular")
      expect(dir.to_s)
        .to end_with("/font_audit/MonaTTC/12-Mona-Regular")
    end
  end

  describe "library-level paths" do
    it "places the library index.json directly under the library root" do
      expect(described_class.library_index_path(root).to_s)
        .to eq("/tmp/example-output/font_audit/index.json")
    end

    it "places the library index.html directly under the library root" do
      expect(described_class.library_html_path(root).to_s)
        .to eq("/tmp/example-output/font_audit/index.html")
    end
  end

  describe "inner-path helpers (face_dir-relative)" do
    let(:face_dir) { Pathname.new("/tmp/example-output/font_audit/Mona") }

    it "places index.json directly under the supplied face_dir" do
      expect(described_class.index_under(face_dir).to_s)
        .to eq("/tmp/example-output/font_audit/Mona/index.json")
    end

    it "places block files under <face_dir>/blocks/" do
      expect(described_class.block_under(face_dir, "Basic_Latin").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/blocks/Basic_Latin.json")
    end

    it "places plane files under <face_dir>/planes/" do
      expect(described_class.plane_under(face_dir, 1).to_s)
        .to eq("/tmp/example-output/font_audit/Mona/planes/1.json")
    end

    it "places script files under <face_dir>/scripts/" do
      expect(described_class.script_under(face_dir, "Latn").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/scripts/Latn.json")
    end

    it "places codepoint files under <face_dir>/codepoints/" do
      expect(described_class.codepoints_under(face_dir, "Basic_Latin").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/codepoints/Basic_Latin.json")
    end

    it "places glyph files under <face_dir>/glyphs/" do
      expect(described_class.glyph_under(face_dir, "U+0041").to_s)
        .to eq("/tmp/example-output/font_audit/Mona/glyphs/U+0041.svg")
    end
  end
end
