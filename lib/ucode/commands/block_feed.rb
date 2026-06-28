# frozen_string_literal: true

require "pathname"

require "ucode/repo"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode block-feed` — emit a compact per-block Unicode data feed
    # from ucode's canonical output tree.
    #
    # Reads ucode's `output/` and produces three artifacts at the target
    # directory:
    #
    #   <target>/unicode-blocks.json
    #   <target>/unicode-version.json
    #   <target>/unicode/blocks/<slug>.json
    #
    # Each per-block file contains the codepoints in that block with
    # their compact Unicode metadata (name, general category, script,
    # combining class, bidi class, mirrored flag). Block slugs are
    # derived from the block name via the standard slug algorithm.
    class BlockFeedCommand
      Result = Struct.new(:ucode_output_root, :block_feed_output_root,
                          :unicode_version, :blocks_written,
                          :codepoints_written, :unicode_blocks_path,
                          :unicode_version_path, keyword_init: true)

      # @param ucode_output_root [String, Pathname] ucode's `output/`
      #   (must contain blocks/index.json, blocks/<ID>/index.json,
      #   index/labels.json).
      # @param block_feed_output_root [String, Pathname] target directory.
      # @param unicode_version [String, nil] UCD version to stamp on
      #   unicode-version.json. Defaults to the version recorded in
      #   ucode's manifest.json.
      # @return [Result]
      def call(ucode_output_root:, block_feed_output_root:, unicode_version: nil)
        ucode_root = Pathname.new(ucode_output_root)
        feed_root = Pathname.new(block_feed_output_root)
        version = unicode_version || manifest_version(ucode_root)

        emitter = Repo::BlockFeedEmitter.new(ucode_root, feed_root)
        outcome = emitter.emit(ucd_version: version)

        Result.new(
          ucode_output_root: ucode_root.to_s,
          block_feed_output_root: feed_root.to_s,
          unicode_version: version,
          blocks_written: outcome[:blocks_written],
          codepoints_written: outcome[:codepoints_written],
          unicode_blocks_path: outcome[:unicode_blocks_path],
          unicode_version_path: outcome[:unicode_version_path],
        )
      end

      private

      def manifest_version(ucode_root)
        manifest = ucode_root.join("manifest.json")
        return default_version unless manifest.exist?

        JSON.parse(manifest.read)["ucd_version"] || default_version
      rescue JSON::ParserError
        default_version
      end

      def default_version
        VersionResolver.resolve(nil)
      end
    end
  end
end
