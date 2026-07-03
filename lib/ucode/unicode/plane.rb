# frozen_string_literal: true

module Ucode
  module Unicode
    # A Unicode plane — a contiguous range of 65_536 codepoints.
    # There are 17 planes (0–16). Only 7 have official short names.
    #
    # Pure value object: carries data, nothing else. Not a lutaml-model
    # (those are serialization DTOs). Constructed frozen by {Catalog}.
    Plane = Struct.new(
      :number,
      :range,
      :short_name,
      :display_name,
      :assigned_count,
      keyword_init: true,
    ) do
      def cover?(codepoint)
        range.cover?(codepoint)
      end
    end
  end
end
