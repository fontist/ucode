# frozen_string_literal: true

require "ucode/parsers/base"

module Ucode
  module Parsers
    # Parses `DerivedAge.txt` — the Unicode version in which each
    # codepoint was first assigned.
    #
    # Format (UAX #44):
    #   XXXX..YYYY; M.N
    #   XXXX; M.N
    #
    # The age is a Unicode version string like "1.1", "5.2", "15.0".
    # Coordinator merges each row into `CodePoint#age`.
    #
    # Ranges are expanded per-codepoint (one Tuple per cp) because the
    # Coordinator needs per-cp assignment for `CodePoint#age`.
    class DerivedAge < Base
      # Lightweight record yielded by `.each_record`. Models are
      # heavyweight for stream-only data — the Coordinator consumes
      # these immediately.
      Tuple = Struct.new(:cp, :age, keyword_init: true) do
        def cp_id
          format("U+%04X", cp)
        end
      end

      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            range = parse_codepoint_or_range(fields[0])
            age = fields[1]
            next if age.nil? || age.empty?

            each_cp(range) { |cp| yield Tuple.new(cp: cp, age: age) }
          end

          nil
        end

        private

        def each_cp(range)
          if range.is_a?(Range)
            range.each { |cp| yield cp }
          else
            yield range
          end
        end
      end
    end
  end
end
