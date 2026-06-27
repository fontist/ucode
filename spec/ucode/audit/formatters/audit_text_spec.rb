# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Formatters::AuditText do
  let(:report) { build_report }
  let(:renderer) { described_class.new(report) }
  let(:output) { renderer.render }

  it "is a String" do
    expect(output).to be_a(String)
  end

  it "includes the postscript name as the title" do
    expect(output).to include("Inter-Regular")
  end

  it "includes the family name in the IDENTITY section" do
    expect(output).to include("Inter")
    expect(output).to include("IDENTITY")
  end

  it "includes all the canonical sections" do
    %w[IDENTITY STYLE COVERAGE LICENSING HINTING COLOR VARIABLE FONT
       OPENTYPE LAYOUT DISCREPANCIES WARNINGS].each do |section|
      expect(output).to include(section)
    end
  end

  it "includes the source_file path" do
    expect(output).to include("/tmp/Inter-Regular.ttf")
  end

  it "includes the source_sha256 hex" do
    expect(output).to include("deadbeef")
  end

  it "includes the total codepoints count" do
    expect(output).to include("Codepoints:")
    expect(output).to include("357")
  end

  it "renders Unicode blocks when present" do
    expect(output).to include("Basic_Latin")
    expect(output).to include("COMPLETE")
  end

  it "renders Unicode scripts when present" do
    expect(output).to include("Latn")
  end

  it "renders discrepancies when present" do
    expect(output).to include("DISCREPANCIES")
    expect(output).to include("os2_unicode_range_bit_without_cmap_codepoints")
  end

  it "renders warnings when present" do
    expect(output).to include("WARNINGS")
    expect(output).to include("UCD resolution failed")
  end

  it "shows '(none)' for warnings when warning is nil" do
    no_warning = described_class.new(build_report(warning: nil)).render
    expect(no_warning).to include("(none)")
  end

  describe "with NO_COLOR set" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV["NO_COLOR"] = "1"
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    it "suppresses ANSI escape sequences" do
      expect(output).not_to include("\e[")
    end
  end

  describe "with NO_COLOR unset (default)" do
    around do |example|
      previous = ENV["NO_COLOR"]
      ENV.delete("NO_COLOR")
      example.run
    ensure
      ENV["NO_COLOR"] = previous
    end

    it "emits ANSI escape sequences for the title and section headers" do
      expect(output).to include("\e[") # at least one ANSI sequence
    end
  end

  describe "long codepoint range list" do
    let(:many_ranges) do
      # 50 disjoint ranges, way past the LIST_LIMIT of 10.
      Array.new(50) { |i| Ucode::Models::Audit::CodepointRange.new(first_cp: i * 1000, last_cp: i * 1000) }
    end
    let(:report) { build_report(codepoint_ranges: many_ranges) }

    it "truncates the range preview" do
      expect(output).to include("… (+40 more)")
    end
  end

  # ---- helpers --------------------------------------------------------

  def build_report(overrides = {})
    Ucode::Models::Audit::AuditReport.new(
      generated_at: "2026-01-01T00:00:00Z",
      ucode_version: "0.1.0",
      source_file: "/tmp/Inter-Regular.ttf",
      source_sha256: "deadbeef#{'a' * 56}",
      source_format: "ttf",
      font_index: 0,
      num_fonts_in_source: 1,
      family_name: "Inter",
      subfamily_name: "Regular",
      full_name: "Inter Regular",
      postscript_name: "Inter-Regular",
      version: "Version 4.000",
      font_revision: 4.0,
      weight_class: 400,
      width_class: 5,
      total_codepoints: 357,
      total_glyphs: 400,
      cmap_subtables: [4, 12],
      codepoint_ranges: overrides.fetch(:codepoint_ranges) do
        [Ucode::Models::Audit::CodepointRange.new(first_cp: 0x20, last_cp: 0x7E)]
      end,
      baseline: Ucode::Models::Audit::Baseline.new(
        unicode_version: "17.0.0",
        ucode_version: "0.1.0",
        fontisan_version: "1.0.0",
        source: "ucode SQLite index (blocks + scripts tables)",
        generated_at: "2026-01-01T00:00:00Z",
      ),
      blocks: overrides.fetch(:blocks) do
        [Ucode::Models::Audit::BlockSummary.new(
          name: "Basic_Latin", first_cp: 0, last_cp: 0x7F,
          range: "U+0000–U+007F", plane: 0, total_assigned: 128,
          covered_count: 128, missing_count: 0, coverage_percent: 100.0,
          status: Ucode::Models::Audit::BlockSummary::STATUS_COMPLETE,
          missing_codepoints: [], covered_codepoints: [],
        )]
      end,
      scripts: [
        Ucode::Models::Audit::ScriptSummary.new(
          script_code: "Latn", script_name: "Latin",
          blocks_total: 1, assigned_total: 128, covered_total: 100,
          coverage_percent: 78.13, status: "PARTIAL",
        ),
      ],
      plane_summaries: [
        Ucode::Models::Audit::PlaneSummary.new(
          plane: 0, blocks_total: 1, assigned_total: 128,
          covered_total: 100, coverage_percent: 78.13,
        ),
      ],
      licensing: Ucode::Models::Audit::Licensing.new(
        copyright: "© 2026", trademark: "Inter(TM)",
        manufacturer: "Inter Foundry", license_url: "https://ofl.com",
      ),
      metrics: Ucode::Models::Audit::Metrics.new(
        units_per_em: 1000, hhea_ascent: 900, hhea_descent: -200, hhea_line_gap: 0,
        typo_ascender: 900, typo_descender: -200, typo_line_gap: 0,
        win_ascent: 900, win_descent: 200,
      ),
      hinting: Ucode::Models::Audit::Hinting.new(
        hinting_format: "truetype", is_unhinted: false,
        has_fpgm: true, fpgm_instruction_count: 50,
        has_prep: true, prep_instruction_count: 20,
        has_cvt: true, cvt_entry_count: 30,
      ),
      color_capabilities: Ucode::Models::Audit::ColorCapabilities.new(
        has_colr: true, colr_version: 0,
        colr_base_glyph_count: 10, colr_layer_count: 30,
        color_formats: ["colr_v0"],
      ),
      variation: Ucode::Models::Audit::VariationDetail.new(
        axes: [Ucode::Models::Audit::AuditAxis.new(
          tag: "wght", min_value: 100.0, default_value: 400.0, max_value: 900.0,
          name: "Weight",
        )],
        named_instances: [Ucode::Models::Audit::NamedInstance.new(
          subfamily_name: "Bold", postscript_name: "Inter-Bold",
          coordinates: "wght=700",
        )],
      ),
      opentype_layout: Ucode::Models::Audit::OpenTypeLayout.new(
        scripts: ["DFLT", "latn"], features: ["kern", "liga"], has_gsub: true,
        has_gpos: true,
      ),
      discrepancies: [Ucode::Models::Audit::Discrepancy.new(
        kind: Ucode::Models::Audit::Discrepancy::KIND_OS2_UNICODE_RANGE_BIT_WITHOUT_CMAP_CODEPOINTS,
        detail: "OS/2 ulUnicodeRange bit 7 set but cmap has 0 Greek codepoints",
        bit_position: 7,
      )],
      warning: overrides.fetch(:warning, "UCD resolution failed: 99.9.9"),
    )
  end
end
