# frozen_string_literal: true

require "spec_helper"

RSpec.describe Ucode::Fetch::FontFetcher::Result do
  it "rejects unknown statuses" do
    expect { described_class.new(status: :bogus, label: "X") }
      .to raise_error(ArgumentError, /unknown FontFetcher::Result status/)
  end

  it "exposes predicate readers for each status" do
    downloaded = described_class.new(status: :downloaded, label: "A")
    skipped = described_class.new(status: :skipped, label: "A")
    failed = described_class.new(status: :failed, label: "A")
    local = described_class.new(status: :local, label: "A")
    planned = described_class.new(status: :planned, label: "A")

    expect(downloaded).to be_downloaded
    expect(skipped).to be_skipped
    expect(failed).to be_failed
    expect(local).to be_local
    expect(planned).to be_planned
  end
end
