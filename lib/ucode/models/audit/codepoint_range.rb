# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # A contiguous run of covered codepoints.
      #
      # `first_cp`/`last_cp` are inclusive integer endpoints. A single-codepoint
      # "range" has first_cp == last_cp and renders as `U+XXXX` (no dash).
      #
      # Produced by the cmap coverage coalescer from the font's cmap. The
      # range view replaces a flat per-codepoint list — a 60k-codepoint CJK
      # font produces tens of ranges rather than 60k strings.
      class CodepointRange < Lutaml::Model::Serializable
        attribute :first_cp, :integer
        attribute :last_cp, :integer

        key_value do
          map "first_cp", to: :first_cp
          map "last_cp",  to: :last_cp
        end

        # Human-readable form: `U+XXXX` for single codepoints,
        # `U+XXXX-U+XXXX` for true ranges.
        #
        # @return [String]
        def to_s
          if first_cp == last_cp
            format("U+%04<cp>X", cp: first_cp)
          else
            format("U+%04<first>X-U+%04<last>X", first: first_cp, last: last_cp)
          end
        end
      end
    end
  end
end
