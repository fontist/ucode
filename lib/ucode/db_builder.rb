# frozen_string_literal: true

require "fileutils"
require "sqlite3"
require "time"

require "ucode/cache"
require "ucode/coordinator"
require "ucode/database"
require "ucode/error"
require "ucode/index_builder"

module Ucode
  # Builds the SQLite cache for one UCD version.
  #
  # Single entry point: `DbBuilder.build(version)`. Streams the
  # Coordinator output through an IndexBuilder, then persists the
  # coalesced block + script ranges into a SQLite DB at
  # `Cache.sqlite_path(version)`.
  #
  # **Streaming**: the Coordinator yields one CodePoint at a time; the
  # IndexBuilder folds it into per-property accumulators. Peak memory
  # is the in-progress accumulators (~10 MB for the full UCD) plus one
  # CodePoint — never all 160k CodePoints at once.
  module DbBuilder
    SCHEMA_SQL = <<~SQL
      PRAGMA journal_mode = DELETE;
      PRAGMA synchronous = NORMAL;

      CREATE TABLE schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );

      CREATE TABLE blocks (
        first_cp INTEGER NOT NULL,
        last_cp INTEGER NOT NULL,
        name TEXT NOT NULL
      );
      CREATE INDEX idx_blocks_first_cp ON blocks(first_cp);
      CREATE INDEX idx_blocks_name ON blocks(name);

      CREATE TABLE scripts (
        first_cp INTEGER NOT NULL,
        last_cp INTEGER NOT NULL,
        name TEXT NOT NULL
      );
      CREATE INDEX idx_scripts_first_cp ON scripts(first_cp);
      CREATE INDEX idx_scripts_name ON scripts(name);
    SQL
    private_constant :SCHEMA_SQL

    class << self
      # @param version [String]
      # @return [Pathname] path to the built SQLite file
      def build(version)
        Ucode::VersionResolver.validate!(version)

        ucd_dir = Cache.ucd_dir(version)
        unihan_dir = Cache.unihan_dir(version)
        db_path = Cache.sqlite_path(version)

        Cache.ensure_version_dir!(version)

        builder = IndexBuilder.new
        Coordinator.new.each_codepoint(ucd_dir: ucd_dir, unihan_dir: unihan_dir) do |cp|
          builder.add(cp)
        end

        write_db(db_path, version, builder.blocks_index, builder.scripts_index)
        db_path
      end

      private

      def write_db(db_path, version, blocks_index, scripts_index)
        SQLite3::Database.new(db_path.to_s) do |db|
          db.execute_batch(SCHEMA_SQL)
          insert_meta(db, "schema_version", Database::SCHEMA_VERSION)
          insert_meta(db, "ucd_version", version)
          insert_meta(db, "built_at", Time.now.utc.iso8601)

          db.transaction do
            insert_rows(db, "blocks", blocks_index.entries)
            insert_rows(db, "scripts", scripts_index.entries)
          end
        end
      end

      def insert_meta(db, key, value)
        db.execute(
          "INSERT INTO schema_meta (key, value) VALUES (?, ?)",
          [key.to_s, value.to_s],
        )
      end

      def insert_rows(db, table, entries)
        stmt = db.prepare("INSERT INTO #{table} (first_cp, last_cp, name) VALUES (?, ?, ?)")
        entries.each do |entry|
          stmt.execute(entry.first_cp, entry.last_cp, entry.name)
        end
      ensure
        stmt&.close
      end
    end
  end
end
