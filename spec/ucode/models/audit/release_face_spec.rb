# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::Audit::ReleaseFaceEntry do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        postscript_name: "Inter-Regular",
        family_name: "Inter",
        weight_class: 400,
        total_codepoints: 2857,
        covered_codepoints: 2857,
        blocks_complete: 12,
        blocks_partial: 12,
        source_sha256: "a" * 64,
        index_path: "audit/inter/Inter-Regular/index.json",
        html_path: "audit/inter/Inter-Regular/index.html",
      )
    end
  end
end
