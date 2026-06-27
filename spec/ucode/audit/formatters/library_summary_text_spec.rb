# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Audit::Formatters::LibrarySummaryText do
  let(:summary) { build_summary }
  let(:renderer) { described_class.new(summary) }
  let(:output) { renderer.render }

  it "includes the LIBRARY SUMMARY header" do
    expect(output).to include("LIBRARY SUMMARY")
  end

  it "shows the root path" do
    expect(output).to include("/fonts/noto")
  end

  it "shows the file and face counts" do
    expect(output).to include("files:")
    expect(output).to include("3")
    expect(output).to include("faces:")
  end

  it "lists scanned extensions" do
    expect(output).to include("formats:")
    expect(output).to include(".otf")
    expect(output).to include(".ttf")
  end

  it "includes the AGGREGATES section with codepoints + size" do
    expect(output).to include("AGGREGATES")
    expect(output).to include("codepoints:")
    expect(output).to include("total size:")
  end

  it "includes the SCRIPT COVERAGE section" do
    expect(output).to include("SCRIPT COVERAGE")
    expect(output).to include("Latn:")
  end

  it "includes the DUPLICATES section when groups are present" do
    expect(output).to include("DUPLICATES")
    expect(output).to include("/fonts/noto/Noto-Regular.otf")
    expect(output).to include("/fonts/noto/Noto-Regular-copy.otf")
  end

  it "includes the LICENSE DISTRIBUTION section" do
    expect(output).to include("LICENSE DISTRIBUTION")
    expect(output).to include("https://ofl.com")
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

  describe "with an empty summary" do
    let(:summary) do
      Ucode::Models::Audit::LibrarySummary.new(
        root_path: "/empty", total_files: 0, total_faces: 0,
      )
    end

    it "still renders the header and aggregates" do
      expect(output).to include("LIBRARY SUMMARY")
      expect(output).to include("AGGREGATES")
      expect(output).to include("codepoints:     0")
    end

    it "omits the script / duplicate / license sections" do
      expect(output).not_to include("SCRIPT COVERAGE")
      expect(output).not_to include("DUPLICATES")
      expect(output).not_to include("LICENSE DISTRIBUTION")
    end
  end

  # ---- helpers --------------------------------------------------------

  def build_summary
    Ucode::Models::Audit::LibrarySummary.new(
      root_path: "/fonts/noto",
      total_files: 3,
      total_faces: 3,
      scanned_extensions: [".otf", ".ttf"],
      aggregate_metrics: {
        total_codepoints: 1500, total_glyphs: 1800, total_size_bytes: 2_500_000
      },
      script_coverage: [
        Ucode::Models::Audit::ScriptCoverageRow.new(
          script: "Latn", face_count: 3, faces: ["Noto-Regular", "Noto-Bold"],
        ),
        Ucode::Models::Audit::ScriptCoverageRow.new(
          script: "Cyrl", face_count: 1, faces: ["Noto-Regular"],
        ),
      ],
      duplicate_groups: [
        Ucode::Models::Audit::DuplicateGroup.new(
          source_sha256: "abc123def456",
          files: ["/fonts/noto/Noto-Regular.otf",
                  "/fonts/noto/Noto-Regular-copy.otf"],
        ),
      ],
      license_distribution: { "https://ofl.com" => 3 },
      per_face_reports: [],
    )
  end
end
