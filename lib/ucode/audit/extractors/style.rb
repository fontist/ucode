# frozen_string_literal: true

module Ucode
  module Audit
    module Extractors
      # Style fields: weight, width, italic/bold flags, Panose family
      # classification.
      #
      # Returned fields:
      #   weight_class, width_class, italic, bold, panose
      #
      # ucode delta vs fontisan: the standalone `StyleExtractor` class is
      # NOT ported. The OS/2 + head interpretation rules live inline here.
      #
      # MECE: this extractor owns OS/2 + head. fvar-derived fields (axes,
      # named instances, variable presence) live on the VariationDetail
      # extractor (TODO 09).
      #
      # Boundary: uses only `font.has_table?(tag)` and `font.table(tag)`.
      # No class-specific branching — any SFNT-compatible font works.
      class Style < Base
        FS_SELECTION_ITALIC_BIT = 0
        MAC_STYLE_BOLD_BIT      = 0
        private_constant :FS_SELECTION_ITALIC_BIT, :MAC_STYLE_BOLD_BIT

        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          font = context.font
          {
            weight_class: weight_class(font),
            width_class: width_class(font),
            italic: italic(font),
            bold: bold(font),
            panose: panose(font),
          }
        end

        private

        def weight_class(font)
          os2(font)&.us_weight_class&.to_i
        end

        def width_class(font)
          os2(font)&.us_width_class&.to_i
        end

        # OS/2.fsSelection bit 0 (ITALIC).
        def italic(font)
          table = os2(font)
          return nil if table.nil?

          (table.fs_selection.to_i & (1 << FS_SELECTION_ITALIC_BIT)).nonzero?
        end

        # head.macStyle bit 0 (BOLD). Per OpenType convention, bold is
        # read from head, not OS/2.
        def bold(font)
          table = head(font)
          return nil if table.nil?

          (table.mac_style.to_i & (1 << MAC_STYLE_BOLD_BIT)).nonzero?
        end

        # OS/2.panose as a space-joined 10-digit string,
        # e.g. "2 0 5 3 0 0 0 0 0 0". nil when no OS/2 table.
        def panose(font)
          bytes = os2(font)&.panose
          return nil if bytes.nil?

          bytes = bytes.to_a
          return nil if bytes.empty?

          bytes.join(" ")
        end

        def os2(font)
          font.has_table?("OS/2") ? font.table("OS/2") : nil
        end

        def head(font)
          font.has_table?("head") ? font.table("head") : nil
        end
      end
    end
  end
end
