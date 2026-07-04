# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Abstract base for the three codepoint→GID resolution
        # strategies. Each subclass owns ONE mutool subcommand and
        # ONE collaborator. The orchestrator ({CodepointMapper})
        # tries strategies in chain order, returning the first
        # non-empty map.
        #
        # Adding a 4th strategy = one new subclass + one entry in
        # the chain. No edit to CodepointMapper#map.
        class Strategy
          # @param descriptor [RawFontDescriptor]
          # @return [Boolean] true if this strategy can attempt the
          #   given descriptor
          def supports?(_descriptor)
            raise NotImplementedError
          end

          # @param descriptor [RawFontDescriptor]
          # @return [Hash{Integer=>Integer}] codepoint => gid; empty
          #   when the strategy cannot produce a mapping for this
          #   descriptor
          def map(_descriptor)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
