# frozen_string_literal: true

module Ucode
  module Glyphs
    Grid = Struct.new(
      :origin_x, :origin_y,
      :column_pitch, :row_pitch,
      :columns, :rows,
      :block_first_cp,
      keyword_init: true,
    ) do
      def cell_position(codepoint)
        offset = codepoint - block_first_cp
        return nil if offset.negative?

        row, col = offset.divmod(columns)
        return nil if row >= rows

        [origin_x + (col * column_pitch), origin_y + (row * row_pitch)]
      end

      def codepoint_at(row, col)
        return nil if row.negative? || row >= rows
        return nil if col.negative? || col >= columns

        block_first_cp + (row * columns) + col
      end
    end
  end
end
