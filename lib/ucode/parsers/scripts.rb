# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/models/script"

module Ucode
  module Parsers
    # Parses `Scripts.txt` — the primary Script property assignment per
    # codepoint range.
    #
    # Format (UAX #44):
    #   XXXX..XXXX ; Script_Name # trailing comment
    #   XXXX       ; Script_Name # trailing comment
    #
    # Yields one Script per line, with `range_first` and `range_last`
    # set. The Coordinator bsearches the resulting sorted array by cp.
    # The ISO 15924 `code` is resolved later by the Coordinator via
    # PropertyValueAliases (property=sc).
    class Scripts < Base
      class << self
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          each_line(path) do |line|
            fields = line.fields
            next if fields.length < 2

            name = fields[1]
            next if name.nil? || name.empty?
            next if name == "@missing"

            range = parse_codepoint_or_range(fields[0])
            yield build_script(range, name)
          end

          nil
        end

        private

        def build_script(range, name)
          first, last = bounds_of(range)
          Models::Script.new(
            name: name,
            range_first: first,
            range_last: last
          )
        end

        def bounds_of(range)
          if range.is_a?(Range)
            [range.begin, range.end]
          else
            [range, range]
          end
        end
      end
    end
  end
end
