# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::LibrarySummary do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        root_path: "/fonts",
        total_files: 4,
        total_faces: 6,
        scanned_extensions: %w[ttf otf],
        aggregate_metrics: { "total_glyphs" => 12_000 },
        script_coverage: [
          Ucode::Models::Audit::ScriptCoverageRow.new(
            script: "Latn", face_count: 4, faces: %w[Demo-Regular Demo-Bold],
          ),
        ],
        duplicate_groups: [
          Ucode::Models::Audit::DuplicateGroup.new(
            source_sha256: "abc", files: %w[a.ttf b.ttf],
          ),
        ],
        license_distribution: { "OFL" => 3, "Apache" => 1 },
        per_face_reports: [],
      )
    end
  end
end
