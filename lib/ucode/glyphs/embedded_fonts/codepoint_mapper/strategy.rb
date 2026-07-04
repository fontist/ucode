# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Abstract base for the codepoint→GID resolution strategies.
        # Each subclass owns ONE mutool subcommand and ONE collaborator.
        # The orchestrator ({CodepointMapper}) tries strategies in
        # chain order, returning the first non-empty map.
        #
        # Adding a new strategy = one new subclass + one entry in the
        # chain. No edit to CodepointMapper#map (Open/Closed Principle).
        class Strategy
          # @param descriptor [RawFontDescriptor]
          def supports?(_descriptor)
            raise NotImplementedError
          end

          # @param descriptor [RawFontDescriptor]
          # @return [Hash{Integer=>Integer}] codepoint => gid; empty
          #   when the strategy cannot produce a mapping
          def map(_descriptor)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
