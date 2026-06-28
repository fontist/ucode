# frozen_string_literal: true

module Ucode
  module Audit
    # {CoverageReference} backed by a {Ucode::Database}. The "legacy"
    # reference: derives the assigned codepoint set from block ranges
    # alone, with no per-codepoint provenance.
    #
    # Used by the audit pipeline when no universal-set manifest is
    # available (or the user explicitly opts out via
    # `--reference-universal-set=none`). All audits before TODO 25
    # behaved this way.
    class UcdOnlyReference < CoverageReference
      # @param database [Ucode::Database, nil] when nil, every query
      #   returns empty / false — caller should surface a warning.
      def initialize(database:)
        super()
        @database = database
      end

      attr_reader :database

      # @return [Symbol] :ucd
      def kind
        :ucd
      end

      # (see CoverageReference#include?)
      def include?(codepoint)
        return false if @database.nil?

        !@database.lookup_block(codepoint).nil?
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

        ranges.flat_map { |r| expand_range(r) }
      end

      # (see CoverageReference#reference_id)
      def reference_id
        version = @database&.ucd_version || "unknown"
        "ucd:#{version}"
      end

      # UCD-only references carry no provenance. Returning nil signals
      # "do not populate `missing_codepoint_provenance`" so the audit
      # report preserves the legacy wire shape.
      #
      # @return [nil]
      def provenance_for(_codepoints)
        nil
      end

      private

      def expand_range(range)
        (range.first_cp..range.last_cp).map do |cp|
          Entry.new(codepoint: cp, id: format_id(cp), tier: nil, source: nil)
        end
      end

      def format_id(cp)
        width = cp <= 0xFFFF ? 4 : 6
        format("U+%0*X", width, cp)
      end
    end
  end
end
