# frozen_string_literal: true

require "sqlite3"
require "ucode/cache"
require "ucode/error"
require "ucode/range_entry"

module Ucode
  # SQLite-backed UCD lookup index for one Unicode version.
  #
  # One Database instance = one `.sqlite3` file at
  # `Cache.sqlite_path(version)`. The DB holds two range tables
  # (`blocks` and `scripts`), each pre-coalesced during build.
  #
  # Why SQLite (alongside the YAML Index):
  #
  # - Persistent across processes — build once, reuse across runs.
  # - Btree-indexed queries load only the requested rows.
  # - Small on disk (~hundreds of KB after coalescing).
  #
  # Lifecycle:
  #
  #   Database.build(version)   # streams Coordinator output → SQLite
  #   Database.open(version)    # opens existing SQLite (read-only)
  #   Database.cached?(version) # checks for .sqlite3 file
  #
  class Database
    SCHEMA_VERSION = "1"

    BLOCKS_TABLE = "blocks"
    SCRIPTS_TABLE = "scripts"
    private_constant :BLOCKS_TABLE, :SCRIPTS_TABLE

    class << self
      # Open an existing database. Raises DatabaseMissingError if the
      # file is absent, DatabaseSchemaError if the on-disk schema
      # version does not match `SCHEMA_VERSION`.
      # @param version [String]
      # @return [Database]
      def open(version)
        path = Cache.sqlite_path(version)
        unless path.exist?
          raise DatabaseMissingError.new(
            "No UCD SQLite cache for version #{version.inspect} at #{path}",
            context: { version: version, path: path.to_s },
          )
        end

        db = new(path.to_s)
        db.verify_schema_version!
        db
      end

      # Stream the Coordinator output for `version` into a new SQLite
      # cache, then open it. Replaces any existing file.
      # @param version [String]
      # @return [Database]
      def build(version)
        DbBuilder.build(version)
        open(version)
      end

      # True if a built SQLite cache exists for this version.
      # @param version [String]
      # @return [Boolean]
      def cached?(version)
        Cache.sqlite_path(version).exist?
      end
    end

    # @param path [String] path to the .sqlite3 file
    def initialize(path)
      @db = SQLite3::Database.new(path, readonly: true, results_as_hash: true)
      @db.busy_timeout = 5000
    end

    # @return [String] the UCD version this DB was built from.
    def ucd_version
      @ucd_version ||= meta("ucd_version")
    end

    # @return [String] the schema version recorded at build time.
    def schema_version
      @schema_version ||= meta("schema_version")
    end

    # Look up the block name covering `codepoint`. nil if not in any
    # known block (typically: cp is unassigned or outside the source
    # fixture).
    # @param codepoint [Integer]
    # @return [String, nil]
    def lookup_block(codepoint)
      lookup(BLOCKS_TABLE, codepoint)
    end

    # Look up the script name covering `codepoint`. nil if not in any
    # known script.
    # @param codepoint [Integer]
    # @return [String, nil]
    def lookup_script(codepoint)
      lookup(SCRIPTS_TABLE, codepoint)
    end

    # Enumerate every range in the blocks table that overlaps the
    # inclusive query range, sorted by first_cp.
    # @param first [Integer]
    # @param last [Integer]
    # @return [Enumerator<RangeEntry>] if no block given
    def each_block_overlapping(first, last, &block)
      each_overlapping(BLOCKS_TABLE, first, last, &block)
    end

    # Enumerate every range in the scripts table that overlaps the
    # inclusive query range, sorted by first_cp.
    # @param first [Integer]
    # @param last [Integer]
    # @return [Enumerator<RangeEntry>] if no block given
    def each_script_overlapping(first, last, &block)
      each_overlapping(SCRIPTS_TABLE, first, last, &block)
    end

    # All block ranges, sorted by first_cp. Mostly useful in specs.
    # @return [Array<RangeEntry>]
    def block_entries
      entries(BLOCKS_TABLE)
    end

    # All script ranges, sorted by first_cp. Mostly useful in specs.
    # @return [Array<RangeEntry>]
    def script_entries
      entries(SCRIPTS_TABLE)
    end

    # Close the underlying SQLite connection. Idempotent.
    # @return [void]
    def close
      @db.close
    end

    # Raises DatabaseSchemaError if the on-disk schema version does
    # not match `SCHEMA_VERSION`. Called by `.open`; exposed for
    # consumers that hold a long-lived connection.
    # @return [void]
    def verify_schema_version!
      return if schema_version == SCHEMA_VERSION

      raise DatabaseSchemaError.new(
        "SQLite schema mismatch: on-disk #{schema_version.inspect}, " \
        "expected #{SCHEMA_VERSION.inspect}",
        context: { on_disk: schema_version, expected: SCHEMA_VERSION },
      )
    end

    private

    def meta(key)
      @db.get_first_value(
        "SELECT value FROM schema_meta WHERE key = ?",
        [key.to_s],
      )
    end

    def lookup(table, codepoint)
      @db.get_first_value(
        "SELECT name FROM #{table} WHERE first_cp <= ? AND last_cp >= ? LIMIT 1",
        [codepoint, codepoint],
      )
    end

    def each_overlapping(table, first, last)
      return enum_for(:each_overlapping, table, first, last) unless block_given?

      @db.execute(
        "SELECT first_cp, last_cp, name FROM #{table} " \
        "WHERE first_cp <= ? AND last_cp >= ? ORDER BY first_cp",
        [last, first],
      ).each do |row|
        yield RangeEntry.new(row["first_cp"], row["last_cp"], row["name"])
      end
    end

    def entries(table)
      @db.execute(
        "SELECT first_cp, last_cp, name FROM #{table} ORDER BY first_cp",
      ).map { |row| RangeEntry.new(row["first_cp"], row["last_cp"], row["name"]) }
    end
  end
end
