# frozen_string_literal: true

module Ucode
  module Unicode
    # A Unicode block — a contiguous range of codepoints with a name.
    # There are ~346 blocks in Unicode 17.0.0.
    #
    # Pure value object like {Plane}. The +id+ field uses the underscore
    # form (e.g., +"Basic_Latin"+) for filesystem/JSON key compatibility;
    # the +name+ field preserves the original Unicode spelling.
    Block = Struct.new(
      :id,
      :name,
      :first_cp,
      :last_cp,
      :plane_number,
      keyword_init: true,
    ) do
      def range
        (first_cp..last_cp)
      end

      def cover?(codepoint)
        range.cover?(codepoint)
      end
    end
  end
end
