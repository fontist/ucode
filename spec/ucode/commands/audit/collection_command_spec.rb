# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "json"

RSpec.describe Ucode::Commands::Audit::CollectionCommand do
  let(:fixture_ttc) do
    # Build a small TTC by collecting two real fixtures is non-trivial;
    # fall back to a single-face source and assert the collection-required
    # guard fires. The collection happy-path is exercised via FontCommand
    # auto-detection; this spec focuses on the guard.
    "spec/fixtures/fonts/MonaSans/MonaSans-Regular.otf"
  end
  let(:root) { Dir.mktmpdir("ucode-audit-collection-cmd") }

  after { FileUtils.remove_entry(root) if File.exist?(root) }

  it "raises CollectionRequiredError when the source is not a collection" do
    expect do
      described_class.new.call(fixture_ttc, output_root: root)
    end.to raise_error(Ucode::Commands::Audit::CollectionRequiredError)
  end

  it "exposes a readable error message naming the path" do
    err = Ucode::Commands::Audit::CollectionRequiredError.new(fixture_ttc)
    expect(err.message).to include(fixture_ttc)
    expect(err.message).to include("collection")
  end
end
