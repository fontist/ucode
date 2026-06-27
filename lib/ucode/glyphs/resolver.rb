# frozen_string_literal: true

module Ucode
  module Glyphs
    # Priority-ordered glyph resolver — the heart of the 4-tier sourcing
    # strategy.
    #
    # Holds a flat array of {Source} instances (any tier, any number per
    # tier) and tries them in `order:` until one returns a {Source::Result}.
    # Tries are tier-major, source-minor: within a tier, sources are
    # tried in the order they were passed to the constructor. This lets
    # callers express "try FSung-1 before FSung-2 before Noto CJK JP" by
    # simply ordering the Tier 1 sources that way.
    #
    # The default order is Tier 1 → Pillar 1 → Pillar 2 → Pillar 3, but
    # callers can override (e.g. tests may want [:pillar3] only).
    #
    # The resolver is a pure orchestrator: it doesn't know about UCD
    # blocks, fontist formulas, or PDF parsing. Those concerns live in
    # the individual Source subclasses and in {SourceBuilder}.
    class Resolver
      DEFAULT_ORDER = %i[tier1 pillar1 pillar2 pillar3].freeze
      private_constant :DEFAULT_ORDER

      # @param sources [Array<Source>] flat list; grouped by tier
      #   internally. Sources with the same tier are tried in the order
      #   they appear here.
      # @param order [Array<Symbol>] tier resolution order. Default:
      #   %i[tier1 pillar1 pillar2 pillar3].
      def initialize(sources:, order: DEFAULT_ORDER)
        @sources_by_tier = sources.group_by(&:tier)
        @order = order
      end

      # @param codepoint [Integer]
      # @return [Source::Result, nil] nil only when every source in
      #   every configured tier returned nil. With a Pillar 3 source
      #   configured, this should be unreachable for assigned
      #   codepoints — Pillar 3 catches the tail.
      def resolve(codepoint)
        @order.each do |tier|
          Array(@sources_by_tier[tier]).each do |source|
            result = source.fetch(codepoint)
            return result if result
          end
        end
        nil
      end

      # @return [Array<Source>] every source the resolver holds, flat.
      def sources
        @sources_by_tier.values.flatten
      end

      # @param tier [Symbol]
      # @return [Array<Source>] sources registered for the given tier
      def sources_for_tier(tier)
        Array(@sources_by_tier[tier])
      end
    end
  end
end
