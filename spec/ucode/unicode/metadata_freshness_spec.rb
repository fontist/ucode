# frozen_string_literal: true

require "spec_helper"

# Cross-cutting freshness guard across metadata modules + Catalog.
# rubocop:disable RSpec/DescribeClass
RSpec.describe "metadata freshness guard" do
  describe "structural integrity of committed metadata modules" do
    Ucode::Unicode::SUPPORTED_VERSIONS.each do |version|
      context "when checking #{version}" do
        it "has a committed metadata file" do
          filename = Ucode::Unicode::MetadataWriter.version_to_filename(version)
          path = Pathname.new(__dir__)
            .join("..", "..", "..", "lib", "ucode", "unicode", "metadata", "#{filename}.rb")
          expect(path.exist?).to be(true), "#{filename}.rb is missing"
        end

        it "loads without error" do
          expect { Ucode::Unicode.for_version(version) }.not_to raise_error
        end

        it "has the correct UNICODE_VERSION constant" do
          mod_name = Ucode::Unicode::MetadataWriter.version_to_module(version)
          metadata = Ucode::Unicode::Metadata.const_get(mod_name)
          expect(metadata::UNICODE_VERSION).to eq(version)
        end

        it "has a positive ASSIGNED_COUNT" do
          mod_name = Ucode::Unicode::MetadataWriter.version_to_module(version)
          metadata = Ucode::Unicode::Metadata.const_get(mod_name)
          expect(metadata::ASSIGNED_COUNT).to be_positive
        end

        it "has BLOCKS as a non-empty frozen Array" do
          mod_name = Ucode::Unicode::MetadataWriter.version_to_module(version)
          metadata = Ucode::Unicode::Metadata.const_get(mod_name)
          expect(metadata::BLOCKS).to be_a(Array)
          expect(metadata::BLOCKS).not_to be_empty
          expect(metadata::BLOCKS).to be_frozen
        end

        it "has ASSIGNED_BY_PLANE as a frozen Hash" do
          mod_name = Ucode::Unicode::MetadataWriter.version_to_module(version)
          metadata = Ucode::Unicode::Metadata.const_get(mod_name)
          expect(metadata::ASSIGNED_BY_PLANE).to be_a(Hash)
          expect(metadata::ASSIGNED_BY_PLANE).to be_frozen
        end
      end
    end

    it "every supported version has a corresponding metadata file" do
      Ucode::Unicode::SUPPORTED_VERSIONS.each do |version|
        filename = Ucode::Unicode::MetadataWriter.version_to_filename(version)
        path = Pathname.new(__dir__)
          .join("..", "..", "..", "lib", "ucode", "unicode", "metadata", "#{filename}.rb")
        expect(path.exist?).to be(true), "#{filename}.rb missing for #{version}"
      end
    end
  end

  describe "data freshness against cached UCD", :requires_ucd do
    Ucode::Unicode::SUPPORTED_VERSIONS.each do |version|
      context "when UCD #{version} is cached" do
        it "committed metadata matches generator output" do
          ucd_dir = Ucode::Cache.ucd_dir(version)
          skip "UCD #{version} not cached" unless ucd_dir&.exist?

          generated = Ucode::Unicode::MetadataWriter.generate(
            ucd_dir: ucd_dir, version: version,
          )

          filename = Ucode::Unicode::MetadataWriter.version_to_filename(version)
          committed_path = Pathname.new(__dir__)
            .join("..", "..", "..", "lib", "ucode", "unicode", "metadata", "#{filename}.rb")
          committed = committed_path.read

          expect(generated).to eq(committed),
                               "Metadata for #{version} is stale. " \
                               "Run: bin/ucode emit-metadata #{version}"
        end
      end
    end
  end

  describe "catalog consistency with metadata" do
    Ucode::Unicode::SUPPORTED_VERSIONS.each do |version|
      context "when version #{version}" do
        let(:catalog) { Ucode::Unicode.for_version(version) }
        let(:metadata) do
          mod_name = Ucode::Unicode::MetadataWriter.version_to_module(version)
          Ucode::Unicode::Metadata.const_get(mod_name)
        end

        it "catalog assigned_count matches metadata ASSIGNED_COUNT" do
          expect(catalog.assigned_count).to eq(metadata::ASSIGNED_COUNT)
        end

        it "catalog block count matches metadata BLOCKS size" do
          expect(catalog.all_blocks.size).to eq(metadata::BLOCKS.size)
        end

        it "catalog plane count is always 17" do
          expect(catalog.all_planes.size).to eq(17)
        end
      end
    end
  end
end
# rubocop:enable RSpec/DescribeClass
