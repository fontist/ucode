# frozen_string_literal: true

module Ucode
  module Audit
    # Common interface for any "what is the assigned codepoint set"
    # reference used by the audit pipeline.
    #
    # Two implementations:
    #
    # - {UcdOnlyReference} — derives the assigned set from the UCD
    #   database alone (block ranges). Carries no per-codepoint
    #   provenance. This is the legacy behaviour: a font audit
    #   compares against the abstract Unicode assigned-codepoint list.
    #
    # - {UniversalSetReference} — derives the assigned set from a
    #   universal-set manifest (TODO 24). Every codepoint carries
    #   tier + source provenance, so a missing-codepoint report can
    #   answer "what does the missing glyph look like, and where did
    #   the universal set get it from?".
    #
    # The audit pipeline (Context → Aggregations extractor →
    # BlockAggregator) talks exclusively to this interface. Adding a
    # new reference kind = one new subclass; no caller changes
    # (open/closed).
    class CoverageReference
      # Immutable per-codepoint row exposed by every reference. The
      # `tier` and `source` fields are nil for references that don't
      # carry provenance (e.g. {UcdOnlyReference}).
      Entry = Struct.new(:codepoint, :id, :tier, :source, keyword_init: true) do
        # True when this entry carries provenance from a universal-set
        # manifest. False for UCD-only references.
        def provenance?
          !tier.nil? || !source.nil?
        end
      end

      def initialize; end

      # Symbol identifying the reference kind. Used by the audit
      # report's `baseline.reference_kind` field so consumers know
      # which reference produced the per-block counts.
      #
      # @return [Symbol] e.g. :ucd, :universal_set
      def kind
        raise NotImplementedError
      end

      # @param codepoint [Integer]
      # @return [Boolean] true if the codepoint is in the reference set
      def include?(codepoint)
        raise NotImplementedError
      end

      # Block name (verbatim Unicode identifier, e.g. "Basic_Latin")
      # the codepoint falls under, or nil if it isn't in any known
      # block. Used by {BlockAggregator} to group a font's cmap by
      # block without needing direct access to the underlying
      # {Ucode::Database}.
      #
      # @param codepoint [Integer]
      # @return [String, nil]
      def block_name_for(codepoint)
        raise NotImplementedError
      end

      # Every assigned codepoint in the block, with tier + source
      # attached when the reference carries provenance.
      #
      # @param block_id [String] verbatim Unicode block name
      #   (e.g. "Basic_Latin", "Greek_and_Coptic")
      # @return [Array<Entry>] sorted by codepoint; empty for unknown
      #   block names or blocks with no assigned codepoints
      def entries_for_block(block_id)
        raise NotImplementedError
      end

      # Stable identifier for the reference, embedded in audit reports
      # so consumers can detect drift. Examples:
      #
      #   "ucd:17.0.0"
      #   "universal-set:17.0.0:abc12345"
      #
      # @return [String]
      def reference_id
        raise NotImplementedError
      end

      # Provenance rows for a list of codepoints, or nil when the
      # reference carries no provenance (UCD-only). Returning nil
      # (rather than an empty array) is the signal that the audit
      # report should omit the `missing_codepoint_provenance` field
      # entirely — preserving the legacy wire shape for UCD-only
      # audits.
      #
      # @param codepoints [Enumerable<Integer>]
      # @return [Array<Hash{Symbol=>Object}>, nil] one hash per
      #   codepoint with `:codepoint`, `:tier`, `:source` keys; or nil
      def provenance_for(codepoints)
        raise NotImplementedError
      end
    end
  end
end
