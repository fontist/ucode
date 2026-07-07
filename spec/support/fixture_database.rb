# frozen_string_literal: true

require "fileutils"
require "pathname"
require "tmpdir"

# Shared context for audit specs that need a real Ucode::Database
# built from the spec/fixtures/ucd slice. Mirrors the pattern in
# spec/ucode/database_spec.rb: copies the UCD + Unihan fixture dirs
# into a temp cache root, then builds the SQLite database for the
# given version (default "17.0.0").
#
# Usage in a spec:
#
#   require "support/fixture_database"
#
#   RSpec.describe Ucode::Audit::BlockAggregator do
#     include_context "with fixture ucd database"
#
#     let(:my_version) { "17.0.0" }  # override fixture_version
#     ...
#   end
RSpec.shared_context "with fixture ucd database" do
  around do |example|
    # Dir.mktmpdir's block form propagates errors from its
    # FileUtils.remove_entry cleanup — on Windows, SQLite holds a
    # brief lock on the open .sqlite3 file even after #close, which
    # raises Errno::EACCES and surfaces as a test failure unrelated
    # to the example. Use the non-block form so we control cleanup
    # and can swallow lock errors (Windows CI runners are ephemeral
    # anyway, so leaving a temp dir behind is harmless).
    cache_root = Dir.mktmpdir
    original = Ucode.configuration.cache_root
    Ucode.configuration.cache_root = Pathname.new(cache_root)
    begin
      Ucode::Cache.ensure_version_dir!(fixture_version)
      # force_remove_dir (not safe_remove): these dirs are freshly
      # created by ensure_version_dir! and contain no files, so the
      # Windows OS-lock concern that makes safe_remove a no-op does
      # not apply. cp_r nests the source into an existing dst
      # directory, so we MUST clear the dst first.
      force_remove_dir(Ucode::Cache.ucd_dir(fixture_version))
      force_remove_dir(Ucode::Cache.unihan_dir(fixture_version))
      FileUtils.cp_r(fixture_ucd_dir, Ucode::Cache.ucd_dir(fixture_version))
      FileUtils.cp_r(fixture_unihan_dir, Ucode::Cache.unihan_dir(fixture_version))
      Ucode::DbBuilder.build(fixture_version)
      example.run
    ensure
      Ucode.configuration.cache_root = original
      safe_remove(cache_root)
    end
  end

  def fixture_ucd_dir
    Pathname.new(File.expand_path("../fixtures/ucd", __dir__))
  end

  def fixture_unihan_dir
    Pathname.new(File.expand_path("../fixtures/unihan", __dir__))
  end

  let(:fixture_version) { "17.0.0" }

  let(:fixture_database) { Ucode::Database.open(fixture_version) }

  after { fixture_database&.close }
end
