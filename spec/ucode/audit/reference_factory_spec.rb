# frozen_string_literal: true

require "spec_helper"
require "support/fixture_database"
require "tmpdir"
require "json"

RSpec.describe Ucode::Audit::ReferenceFactory do
  include_context "with fixture ucd database"

  describe ".build_from_cli" do
    it "returns nil when flag is 'none'" do
      result = described_class.build_from_cli(flag: "none", version: fixture_version)
      expect(result).to be_nil
    end

    it "returns nil when no flag and no default manifest on disk" do
      Dir.mktmpdir do |_|
        result = described_class.build_from_cli(flag: nil, version: fixture_version)
        expect(result).to be_nil
      end
    end

    it "returns a UniversalSetReference when the flag points to a real manifest" do
      manifest = Ucode::Models::UniversalSetManifest.new(
        unicode_version: fixture_version,
        ucode_version: Ucode::VERSION,
        source_config_sha256: "deadbeef",
        entries: [],
      )

      Dir.mktmpdir do |dir|
        path = Pathname.new(dir).join("manifest.json")
        path.write(JSON.pretty_generate(manifest.to_hash))

        reference = described_class.build_from_cli(flag: path.to_s, version: fixture_version)
        expect(reference).to be_a(Ucode::Audit::UniversalSetReference)
        expect(reference.reference_id)
          .to start_with("universal-set:#{fixture_version}:deadbeef")
      end
    end

    it "returns nil when the manifest path does not exist" do
      result = described_class.build_from_cli(flag: "/nonexistent/manifest.json",
                                              version: fixture_version)
      expect(result).to be_nil
    end
  end
end
