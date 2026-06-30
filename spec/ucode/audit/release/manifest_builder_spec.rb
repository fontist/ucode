# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "json"
require "fileutils"

RSpec.describe Ucode::Audit::Release::ManifestBuilder, type: :emitter_spec do
  let(:builder) { described_class.new }
  let(:release_root) { Pathname.new(Dir.mktmpdir("ucode-release")) }
  let(:inter_report) { build_audit_report(postscript_name: "Inter-Regular") }
  let(:formulas) do
    [
      Ucode::Audit::Release::FormulaAudits.new(
        slug: "inter",
        summary: build_library_summary(reports: [inter_report]),
      ),
    ]
  end

  after { safe_remove(release_root) if release_root.exist? }

  def write_universal_set(root:, entries: [], glyphs: {}, unicode_version: "17.0.0")
    uset = root.join("universal_glyph_set")
    uset.mkpath
    uset.join("manifest.json").write(JSON.generate({
      "unicode_version" => unicode_version,
      "ucode_version" => "0.2.0",
      "entries" => entries,
      "totals" => { "codepoints_assigned" => entries.size },
    }))
    glyphs_dir = uset.join("glyphs")
    glyphs_dir.mkpath
    glyphs.each do |cp, svg|
      glyphs_dir.join(format("U+%04X.svg", cp)).write(svg)
    end
    uset
  end

  describe "#build" do
    it "records ucode + unicode versions and generated_at" do
      manifest = builder.build(
        formulas: formulas,
        release_root: release_root,
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
      )
      expect(manifest.ucode_version).to eq("0.2.0")
      expect(manifest.unicode_version).to eq("17.0.0")
      expect(manifest.generated_at).to eq("2026-06-28T00:00:00Z")
    end

    it "counts formulas + faces" do
      manifest = builder.build(
        formulas: formulas,
        release_root: release_root,
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
      )
      expect(manifest.formulas_total).to eq(1)
      expect(manifest.faces_total).to eq(1)
    end

    it "records source_config_sha256 when provided" do
      manifest = builder.build(
        formulas: formulas,
        release_root: release_root,
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
        source_config_sha256: "abc123",
      )
      expect(manifest.source_config_sha256).to eq("abc123")
    end

    it "emits a ReleaseFormulaEntry per FormulaAudits" do
      manifest = builder.build(
        formulas: formulas,
        release_root: release_root,
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
      )
      formula = manifest.formulas.first
      expect(formula).to be_a(Ucode::Models::Audit::ReleaseFormulaEntry)
      expect(formula.slug).to eq("inter")
      expect(formula.faces_total).to eq(1)
      expect(formula.faces.first).to be_a(Ucode::Models::Audit::ReleaseFaceEntry)
      expect(formula.faces.first.index_path)
        .to eq("audit/inter/Inter-Regular/index.json")
    end

    it "serializes via lutaml to_hash" do
      manifest = builder.build(
        formulas: formulas,
        release_root: release_root,
        unicode_version: "17.0.0",
        ucode_version: "0.2.0",
        generated_at: "2026-06-28T00:00:00Z",
      )
      hash = manifest.to_hash
      expect(hash["ucode_version"]).to eq("0.2.0")
      expect(hash["formulas_total"]).to eq(1)
      expect(hash["formulas"].first["slug"]).to eq("inter")
    end
  end

  describe "universal-set section" do
    context "when the universal_glyph_set is present at <release_root>/universal_glyph_set" do
      it "is available=true with relative manifest_path + glyphs_dir" do
        write_universal_set(root: release_root, entries: [
          { "codepoint" => 0x41, "id" => "U+0041", "tier" => "tier-1" },
        ])
        manifest = builder.build(
          formulas: formulas,
          release_root: release_root,
          unicode_version: "17.0.0",
          ucode_version: "0.2.0",
          generated_at: "2026-06-28T00:00:00Z",
        )
        expect(manifest.universal_set.available).to be(true)
        expect(manifest.universal_set.manifest_path)
          .to eq("universal_glyph_set/manifest.json")
        expect(manifest.universal_set.glyphs_dir)
          .to eq("universal_glyph_set/glyphs")
        expect(manifest.universal_set.unicode_version).to eq("17.0.0")
      end

      it "carries the totals block from the manifest" do
        write_universal_set(root: release_root, entries: [
          { "codepoint" => 0x41 }, { "codepoint" => 0x42 }
        ])
        manifest = builder.build(
          formulas: formulas,
          release_root: release_root,
          unicode_version: "17.0.0",
          ucode_version: "0.2.0",
          generated_at: "2026-06-28T00:00:00Z",
        )
        expect(manifest.universal_set.totals["codepoints_assigned"]).to eq(2)
      end
    end

    context "when the universal_glyph_set directory is missing" do
      it "is available=false with a directory-not-found reason" do
        manifest = builder.build(
          formulas: formulas,
          release_root: release_root,
          unicode_version: "17.0.0",
          ucode_version: "0.2.0",
          generated_at: "2026-06-28T00:00:00Z",
        )
        expect(manifest.universal_set.available).to be(false)
        expect(manifest.universal_set.reason).to include("not found")
      end
    end

    context "when the manifest.json is missing but glyphs dir exists" do
      it "is available=false with a manifest-not-found reason" do
        uset = release_root.join("universal_glyph_set")
        uset.join("glyphs").mkpath
        manifest = builder.build(
          formulas: formulas,
          release_root: release_root,
          unicode_version: "17.0.0",
          ucode_version: "0.2.0",
          generated_at: "2026-06-28T00:00:00Z",
        )
        expect(manifest.universal_set.available).to be(false)
        expect(manifest.universal_set.reason).to include("manifest.json")
      end
    end

    context "when an explicit universal_set_root is passed" do
      it "uses the explicit root rather than <release_root>/universal_glyph_set" do
        sandbox = Pathname.new(Dir.mktmpdir("ucode-external-sandbox"))
        begin
          target = sandbox.join("universal_glyph_set")
          write_universal_set(root: sandbox, entries: [])
          manifest = builder.build(
            formulas: formulas,
            release_root: release_root,
            unicode_version: "17.0.0",
            ucode_version: "0.2.0",
            generated_at: "2026-06-28T00:00:00Z",
            universal_set_root: target,
          )
          expect(manifest.universal_set.available).to be(true)
        ensure
          safe_remove(sandbox) if sandbox.exist?
        end
      end
    end
  end
end
