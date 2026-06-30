# frozen_string_literal: true

require "spec_helper"
require "support/emitter_spec_helpers"
require "tmpdir"
require "json"

RSpec.describe Ucode::Audit::Release::LibraryIndexBuilder, type: :emitter_spec do
  let(:builder) { described_class.new }
  let(:release_root) { Pathname.new(Dir.mktmpdir("ucode-release")) }
  let(:inter_report) do
    build_audit_report(postscript_name: "Inter-Regular", family_name: "Inter")
  end
  let(:noto_report) do
    build_audit_report(postscript_name: "NotoSans-Regular",
                       family_name: "Noto Sans", source_sha256: "b" * 64)
  end
  let(:formulas) do
    [
      Ucode::Audit::Release::FormulaAudits.new(
        slug: "inter",
        summary: build_library_summary(reports: [inter_report], root_path: "/fonts/inter"),
      ),
      Ucode::Audit::Release::FormulaAudits.new(
        slug: "noto-sans",
        summary: build_library_summary(reports: [noto_report], root_path: "/fonts/noto"),
      ),
    ]
  end

  after { safe_remove(release_root) if release_root.exist? }

  describe "#build" do
    let(:result) do
      builder.build(formulas: formulas, release_root: release_root,
                    generated_at: "2026-06-28T00:00:00Z", ucode_version: "0.2.0")
    end

    it "carries the generated_at + ucode_version" do
      expect(result["generated_at"]).to eq("2026-06-28T00:00:00Z")
      expect(result["ucode_version"]).to eq("0.2.0")
    end

    it "counts formulas + faces at the top level" do
      expect(result["formulas_total"]).to eq(2)
      expect(result["faces_total"]).to eq(2)
    end

    it "emits one formula card per FormulaAudits" do
      slugs = result["formulas"].map { |f| f["slug"] }
      expect(slugs).to eq(%w[inter noto-sans])
    end

    it "records source_path + scanned_extensions per formula" do
      inter = result["formulas"].first
      expect(inter["source_path"]).to eq("/fonts/inter")
      expect(inter["scanned_extensions"]).to eq([".otf"])
    end

    it "emits face cards with relative index_path + html_path" do
      face = result["formulas"].first["faces"].first
      expect(face["index_path"]).to eq("audit/inter/Inter-Regular/index.json")
      expect(face["html_path"]).to eq("audit/inter/Inter-Regular/index.html")
    end

    it "includes the block rollup in each face card" do
      face = result["formulas"].first["faces"].first
      expect(face["blocks_partial"]).to eq(1)
      expect(face["blocks_complete"]).to eq(0)
      expect(face["covered_total"]).to eq(3)
    end

    it "is pure — produces identical output for identical input" do
      first = builder.build(formulas: formulas, release_root: release_root,
                            generated_at: "2026-06-28T00:00:00Z", ucode_version: "0.2.0")
      second = builder.build(formulas: formulas, release_root: release_root,
                             generated_at: "2026-06-28T00:00:00Z", ucode_version: "0.2.0")
      expect(first).to eq(second)
    end
  end
end
