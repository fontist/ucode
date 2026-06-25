# frozen_string_literal: true

require "pathname"

module Ucode
  # On-disk cache layout for fetched UCD sources and derived indices.
  #
  # Pure filesystem module. No network access, no parsing. Reads
  # Ucode.configuration.cache_root for the root path so tests can swap
  # roots without touching ENV.
  #
  # Layout per version:
  #
  #   <root>/<version>/
  #     ucd/              # extracted UCD.zip
  #     unihan/           # extracted Unihan.zip
  #     pdfs/             # per-block PDFs
  #     index/            # blocks.yml, scripts.yml (YAML bsearch index)
  #     sqlite/           # ucode.sqlite3 (primary lookup)
  module Cache
    UCD_DIR = "ucd"
    UNIHAN_DIR = "unihan"
    PDFS_DIR = "pdfs"
    INDEX_DIR = "index"
    SQLITE_DIR = "sqlite"
    SQLITE_FILENAME = "ucode.sqlite3"
    BLOCKS_INDEX_FILENAME = "blocks.yml"
    SCRIPTS_INDEX_FILENAME = "scripts.yml"

    private_constant :UCD_DIR, :UNIHAN_DIR, :PDFS_DIR, :INDEX_DIR,
                     :SQLITE_DIR, :SQLITE_FILENAME,
                     :BLOCKS_INDEX_FILENAME, :SCRIPTS_INDEX_FILENAME

    class << self
      # @return [Pathname]
      def root
        Ucode.configuration.cache_root
      end

      # @param version [String] e.g. "17.0.0"
      # @return [Pathname]
      def version_dir(version)
        root.join(version)
      end

      def ucd_dir(version)
        version_dir(version).join(UCD_DIR)
      end

      def unihan_dir(version)
        version_dir(version).join(UNIHAN_DIR)
      end

      def pdfs_dir(version)
        version_dir(version).join(PDFS_DIR)
      end

      def index_dir(version)
        version_dir(version).join(INDEX_DIR)
      end

      def sqlite_dir(version)
        version_dir(version).join(SQLITE_DIR)
      end

      def sqlite_path(version)
        sqlite_dir(version).join(SQLITE_FILENAME)
      end

      def blocks_index_path(version)
        index_dir(version).join(BLOCKS_INDEX_FILENAME)
      end

      def scripts_index_path(version)
        index_dir(version).join(SCRIPTS_INDEX_FILENAME)
      end

      # True if any extracted content exists for `version`.
      # @param version [String]
      # @return [Boolean]
      def cached?(version)
        version_dir(version).directory?
      end

      # All versions present in the cache, sorted ascending.
      # @return [Array<String>]
      def cached_versions
        return [] unless root.directory?

        root.children.select(&:directory?).map { |p| p.basename.to_s }.sort
      end

      # Idempotent: create the per-version subdirectory tree.
      # @param version [String]
      # @return [void]
      def ensure_version_dir!(version)
        ucd_dir(version).mkpath
        unihan_dir(version).mkpath
        pdfs_dir(version).mkpath
        index_dir(version).mkpath
        sqlite_dir(version).mkpath
      end

      # Remove a version from the cache. No-op if absent.
      # @param version [String]
      # @return [void]
      def remove_version(version)
        dir = version_dir(version)
        dir.rmtree if dir.exist?
      end
    end
  end
end
