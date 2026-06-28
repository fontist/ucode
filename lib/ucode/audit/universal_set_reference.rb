# frozen_string_literal: true

require "json"
require "pathname"

module Ucode
  module Audit
    # {CoverageReference} backed by a universal-set manifest (TODO 24).
    # Every codepoint in the set carries tier + source provenance, so
    # a missing-codepoint report can answer "what does the missing
    # glyph look like, and where did the universal set source it
    # from?".
    #
    # The manifest itself records codepoints but not block
    # membership, so a {Ucode::Database} is still required to map
    # block name -> assigned codepoints. The reference answers per
    # codepoint "is this in the universal set, and what tier/source
    # did it come from?".
    class UniversalSetReference < CoverageReference
      # @param manifest [Ucode::Models::UniversalSetManifest, String, Pathname]
      #   pre-loaded manifest, or a path to a manifest.json. A path is
      #   loaded lazily on first query.
      # @param database [Ucode::Database, nil] used for block lookups.
      def initialize(manifest:, database:)
        super()
        @manifest_source = manifest
        @database = database
      end

      # @return [Symbol] :universal_set
      def kind
        :universal_set
      end

      # (see CoverageReference#include?)
      def include?(codepoint)
        entries_by_cp.key?(codepoint)
      end

      # (see CoverageReference#block_name_for)
      def block_name_for(codepoint)
        return nil if @database.nil?

        @database.lookup_block(codepoint)
      end

      # (see CoverageReference#entries_for_block)
      def entries_for_block(block_id)
        return [] if @database.nil?

        ranges = @database.block_ranges_by_name(block_id)
        return [] if ranges.nil? || ranges.empty?

        ranges.flat_map { |r| expand_range(r) }.compact
      end

      # (see CoverageReference#reference_id)
      def reference_id
        sha = manifest.source_config_sha256
        short_sha = sha ? sha.to_s[0, 12] : "no-sha"
        "universal-set:#{manifest.unicode_version}:#{short_sha}"
      end

      # @return [Hash{String=>Object}] provenance metadata for the
      #   audit report's `baseline` field
      def baseline_metadata
        {
          "unicode_version" => manifest.unicode_version,
          "ucode_version" => manifest.ucode_version,
          "source_config_sha256" => manifest.source_config_sha256,
          "reference_kind" => "universal-set",
        }
      end

      # (see CoverageReference#provenance_for)
      # @return [Array<Hash{Symbol=>Object}>] one hash per codepoint,
      #   in input order
      def provenance_for(codepoints)
        codepoints.map { |cp| row_for(cp) }
      end

      # The underlying manifest model, loaded lazily from disk.
      # @return [Ucode::Models::UniversalSetManifest]
      def manifest
        @manifest ||= load_manifest
      end

      # The UCD database used for block lookups. Exposed so the
      # BlockAggregator can map codepoints -> block names through the
      # same Database instance the reference was built against.
      # @return [Ucode::Database, nil]
      attr_reader :database

      private

      def entries_by_cp
        @entries_by_cp ||= manifest.entries.to_h { |e| [e.codepoint, e] }
      end

      def expand_range(range)
        (range.first_cp..range.last_cp).map do |cp|
          entry = entries_by_cp[cp]
          next nil unless entry

          CoverageReference::Entry.new(
            codepoint: cp, id: entry.id,
            tier: entry.tier, source: entry.source,
          )
        end
      end

      def row_for(codepoint)
        entry = entries_by_cp[codepoint]
        {
          codepoint: codepoint,
          tier: entry&.tier,
          source: entry&.source,
        }
      end

      def load_manifest
        case @manifest_source
        when Ucode::Models::UniversalSetManifest
          @manifest_source
        when String, Pathname
          hash = JSON.parse(Pathname.new(@manifest_source).read)
          Ucode::Models::UniversalSetManifest.from_hash(hash)
        else
          raise ArgumentError,
                "manifest must be a UniversalSetManifest or a path, " \
                "got #{@manifest_source.class}"
        end
      end
    end
  end
end
