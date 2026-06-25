# frozen_string_literal: true

require "spec_helper"
require "support/model_round_trip"

RSpec.describe Ucode::Models::CodePoint::Normalization do
  it_behaves_like "a round-trippable model" do
    let(:instance) do
      described_class.new(
        nfc_qc: "N",
        nfd_qc: false,
        nfkc_qc: "M",
        nfkd_qc: false,
        composition_exclusion: true,
        is_cased: true,
        changes_when_casefolded: true,
        changes_when_casemapped: true,
        changes_when_nfkc_casefolded: false
      )
    end
  end

  it "defaults to QC=Y / QC=true for all four quick checks" do
    n = described_class.new
    expect(n.nfc_qc).to eq("Y")
    expect(n.nfd_qc).to be(true)
    expect(n.nfkc_qc).to eq("Y")
    expect(n.nfkd_qc).to be(true)
    expect(n.composition_exclusion).to be(false)
  end
end
