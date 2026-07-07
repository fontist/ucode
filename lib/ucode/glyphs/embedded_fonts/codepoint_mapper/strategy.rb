# frozen_string_literal: true

module Ucode
  module Glyphs
    module EmbeddedFonts
      class CodepointMapper
        # Abstract base for the codepoint→GID resolution strategies.
        #
        # Each subclass owns ONE mutool subcommand and ONE collaborator.
        # Subclasses declare their role via {#positional?}:
        #
        #   * `positional? == false` — the strategy reads the font's own
        #     intrinsic mapping (ToUnicode CMap). Authoritative for
        #     cross-reference typography, but can be misleading when
        #     the embedded font's CMap encodes composing characters
        #     rather than the chart specimens (Enclosed Ideographic
        #     Supplement, where CJKSymbols' CIDs map to the inner CJK
        #     ideographs, not the squared characters themselves).
        #   * `positional? == true` — the strategy attributes glyphs to
        #     codepoints via chart-grid geometry (mutool trace, content
        #     stream correlation). Authoritative for in-block specimens.
        #
        # The orchestrator ({CodepointMapper}) partitions strategies by
        # this predicate, gates positional strategies behind a
        # block-scope check, and merges with positional precedence
        # when both produce a result. Adding a new strategy = one
        # subclass + one `positional?` override + one entry in the
        # chain. No edit to CodepointMapper (Open/Closed Principle).
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

          # Declares whether this strategy attributes glyphs by chart
          # geometry (true) or by the font's intrinsic mapping (false).
          # The default is false; positional strategies override.
          #
          # @return [Boolean]
          def positional?
            false
          end
        end
      end
    end
  end
end
