# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/database"
require "ucode/repo"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode lookup` — read-only lookups against the SQLite cache and
    # the output JSON tree. Three subactions: block, script, char.
    class LookupCommand
      BlockResult = Struct.new(:codepoint, :block, keyword_init: true)
      ScriptResult = Struct.new(:codepoint, :script, keyword_init: true)
      CharResult = Struct.new(:codepoint, :block_id, :glyph_path, keyword_init: true)
      private_constant :BlockResult, :ScriptResult, :CharResult

      # @param version_intent [nil, :default, :latest, String]
      # @param codepoint [Integer]
      # @return [BlockResult]
      def lookup_block(version_intent, codepoint:)
        version = VersionResolver.resolve(version_intent)
        with_db(version) { |db| db.lookup_block(codepoint) }
          .then { |block| BlockResult.new(codepoint: codepoint, block: block) }
      end

      # @param version_intent [nil, :default, :latest, String]
      # @param codepoint [Integer]
      # @return [ScriptResult]
      def lookup_script(version_intent, codepoint:)
        version = VersionResolver.resolve(version_intent)
        with_db(version) { |db| db.lookup_script(codepoint) }
          .then { |script| ScriptResult.new(codepoint: codepoint, script: script) }
      end

      # @param version_intent [nil, :default, :latest, String]
      # @param codepoint [Integer]
      # @param output_root [String, Pathname]
      # @return [CharResult]
      def lookup_char(version_intent, codepoint:, output_root:)
        version = VersionResolver.resolve(version_intent)
        block_id = with_db(version) { |db| db.lookup_block(codepoint) }
        glyph = block_id ? glyph_path(output_root, block_id, codepoint) : nil
        CharResult.new(codepoint: codepoint, block_id: block_id, glyph_path: glyph)
      end

      private

      def with_db(version)
        db = Database.open(version)
        yield db
      ensure
        db&.close
      end

      def glyph_path(output_root, block_id, codepoint)
        cp_id = Repo::Paths.cp_id(codepoint)
        path = Repo::Paths.codepoint_glyph_path(output_root, block_id, cp_id)
        path.exist? ? path : nil
      end
    end
  end
end
