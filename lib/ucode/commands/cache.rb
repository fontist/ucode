# frozen_string_literal: true

require "pathname"

require "ucode/cache"

module Ucode
  module Commands
    # `ucode cache` — inspect and manage the on-disk cache.
    # Three subactions: list, info, remove.
    class CacheCommand
      VersionInfo = Struct.new(:version, :path, :has_ucd, :has_unihan,
                               :has_pdfs, :has_sqlite, keyword_init: true)
      private_constant :VersionInfo

      # @return [Array<String>] sorted versions present in the cache
      def list
        Cache.cached_versions
      end

      # @param version [String]
      # @return [VersionInfo, nil] nil if version not in cache
      def info(version)
        return nil unless Cache.cached?(version)

        VersionInfo.new(
          version: version,
          path: Cache.version_dir(version),
          has_ucd: Cache.ucd_dir(version).join("UnicodeData.txt").exist?,
          has_unihan: Cache.unihan_dir(version).children.any?,
          has_pdfs: Cache.pdfs_dir(version).children.any?,
          has_sqlite: Cache.sqlite_path(version).exist?,
        )
      end

      # @param version [String]
      # @return [Boolean] true if a directory was removed
      def remove(version)
        return false unless Cache.cached?(version)

        Cache.remove_version(version)
        true
      end
    end
  end
end
