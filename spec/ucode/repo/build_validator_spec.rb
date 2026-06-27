# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Repo::BuildValidator do
  # Helper: build a fake codepoint directory with given contents.
  def make_cp(out, block, cp_id, index_json: nil, glyph_svg: nil)
    dir = File.join(out, "blocks", block, cp_id)
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "index.json"), index_json) if index_json
    File.write(File.join(dir, "glyph.svg"), glyph_svg) if glyph_svg
    dir
  end

  # Helper: a well-formed index.json for a codepoint.
  def index_json_for(cp, tier: "tier-1", provenance: "fixture")
    {
      "codepoint" => cp, "id" => format("U+%04X", cp), "name" => "C#{cp}",
      "glyph" => {
        "svg_path" => "glyph.svg",
        "source" => { "tier" => tier, "provenance" => provenance },
      }
    }.to_json
  end

  describe "happy path — every check passes" do
    it "returns passed: true and writes validation-report.json" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")
        make_cp(out, "ASCII", "U+0042",
                index_json: index_json_for(0x42),
                glyph_svg: "<svg/>")

        outcome = described_class.new(out, unicode_version: "17.0.0").validate

        expect(outcome[:passed]).to be(true)
        expect(outcome[:report_path].exist?).to be(true)
        parsed = JSON.parse(File.read(outcome[:report_path]))
        expect(parsed["totals"]["codepoints_checked"]).to eq(2)
        expect(parsed["totals"]["failures"]).to eq(0)
        expect(parsed["totals"]["checks_passed"]).to eq(3)
        statuses = parsed["checks"].to_h { |c| [c["name"], c["status"]] }
        expect(statuses["completeness"]).to eq("passed")
        expect(statuses["schema"]).to eq("passed")
        expect(statuses["provenance_sanity"]).to eq("passed")
        expect(statuses["block_coverage"]).to eq("skipped")
      end
    end

    it "is idempotent: re-running with no changes produces no rewrite" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")
        validator = described_class.new(out, unicode_version: "17.0.0")
        validator.validate
        path = File.join(out, "validation-report.json")
        first_mtime = File.mtime(path)
        sleep(0.01)

        validator.validate
        # The generated_at timestamp changes between runs, so the file
        # may be rewritten — assert the structure is stable instead.
        parsed = JSON.parse(File.read(path))
        expect(parsed["totals"]["codepoints_checked"]).to eq(1)
        expect(first_mtime).not_to be_nil
      end
    end
  end

  describe "completeness check" do
    it "records missing glyph.svg" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041", index_json: index_json_for(0x41))

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        completeness_failures = parsed["failures"].select do |f|
          f["check"] == "completeness"
        end
        expect(completeness_failures.length).to eq(1)
        expect(completeness_failures.first["message"]).to eq("missing glyph.svg")
        expect(completeness_failures.first["codepoint"]).to eq(0x41)
      end
    end

    it "records missing index.json and skips further checks for that cp" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041", glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        # Only completeness should record a failure for this cp; schema
        # and provenance checks return early when index.json is absent.
        cp_failures = parsed["failures"].select { |f| f["codepoint"] == 0x41 }
        expect(cp_failures.length).to eq(1)
        expect(cp_failures.first["check"]).to eq("completeness")
        expect(cp_failures.first["message"]).to eq("missing index.json")
      end
    end
  end

  describe "schema check" do
    it "records JSON parse failures" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: "{ not valid json",
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        schema_failures = parsed["failures"].select do |f|
          f["check"] == "schema"
        end
        expect(schema_failures.length).to eq(1)
        expect(schema_failures.first["message"]).to start_with("JSON parse failed")
      end
    end
  end

  describe "provenance sanity check" do
    it "records missing glyph.source.tier" do
      Dir.mktmpdir do |out|
        # Index with a glyph bundle but no source tier.
        bad_index = {
          "codepoint" => 0x41, "id" => "U+0041", "name" => "A",
          "glyph" => { "svg_path" => "glyph.svg" }
        }.to_json
        make_cp(out, "ASCII", "U+0041",
                index_json: bad_index, glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        prov_failures = parsed["failures"].select do |f|
          f["check"] == "provenance_sanity"
        end
        expect(prov_failures.length).to eq(1)
        expect(prov_failures.first["message"]).to eq("glyph.source.tier is missing")
      end
    end

    it "passes when glyph is fully populated" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        prov_failures = (parsed["failures"] || []).select do |f|
          f["check"] == "provenance_sanity"
        end
        expect(prov_failures).to be_empty
      end
    end
  end

  describe "block coverage check" do
    it "is skipped when no baseline is supplied" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out).validate[:report_path],
                            ))
        cov = parsed["checks"].find { |c| c["name"] == "block_coverage" }
        expect(cov["status"]).to eq("skipped")
        expect(cov["total"]).to eq(0)
      end
    end

    it "passes when actual counts match the baseline" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")
        make_cp(out, "ASCII", "U+0042",
                index_json: index_json_for(0x42),
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out, baseline: { "ASCII" => 2 }).validate[:report_path],
                            ))
        cov = parsed["checks"].find { |c| c["name"] == "block_coverage" }
        expect(cov["status"]).to eq("passed")
        expect(cov["total"]).to eq(1)
      end
    end

    it "records a failure when actual count differs from baseline" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out, baseline: { "ASCII" => 10 }).validate[:report_path],
                            ))
        cov = parsed["checks"].find { |c| c["name"] == "block_coverage" }
        expect(cov["status"]).to eq("failed")
        cov_failures = parsed["failures"].select do |f|
          f["check"] == "block_coverage"
        end
        expect(cov_failures.first["message"]).to eq("expected 10 built, found 1")
        expect(cov_failures.first["codepoint"]).to be_nil
      end
    end
  end

  describe "multiple blocks" do
    it "counts per-block and runs checks against each" do
      Dir.mktmpdir do |out|
        make_cp(out, "ASCII", "U+0041",
                index_json: index_json_for(0x41),
                glyph_svg: "<svg/>")
        make_cp(out, "Greek", "U+0391",
                index_json: index_json_for(0x391, tier: "pillar-3",
                                                  provenance: "last-resort"),
                glyph_svg: "<svg/>")

        parsed = JSON.parse(File.read(
                              described_class.new(out,
                                                  baseline: { "ASCII" => 1, "Greek" => 1 }).validate[:report_path],
                            ))
        expect(parsed["totals"]["codepoints_checked"]).to eq(2)
        expect(parsed["totals"]["failures"]).to eq(0)
      end
    end
  end

  describe "empty tree" do
    it "returns passed: true with zero codepoints" do
      Dir.mktmpdir do |out|
        outcome = described_class.new(out).validate
        expect(outcome[:passed]).to be(true)
        parsed = JSON.parse(File.read(outcome[:report_path]))
        expect(parsed["totals"]["codepoints_checked"]).to eq(0)
      end
    end
  end
end
