# frozen_string_literal: true

require "ucode/error"

module Ucode
  module Parsers
    # Shared infrastructure for every UCD text-file parser. Subclasses
    # implement `.each_record(path) { |record| ... }` returning an
    # Enumerator when called without a block.
    #
    # All methods are class methods — parsers are stateless.
    #
    # UCD text-file format (UAX #44):
    #   - Fields separated by `;`
    #   - Lines starting with `#` are comments
    #   - Blank lines are ignored
    #   - Some lines carry an inline `# trailing comment` after the data
    class Base
      # One physical line from the source file, post-filter (blanks and
      # comment-only lines are skipped before yielding).
      Line = Struct.new(:number, :text, :comment, keyword_init: true) do
        # Returns the data part of the line — everything before the first
        # `#`, rstripped. For lines with no comment this is just the text.
        def data
          idx = text.index("#")
          idx.nil? ? text : text[0...idx].rstrip
        end

        # Splits the data part on `;` into stripped fields.
        def fields
          data.split(";").map(&:strip)
        end

        # Returns the n-th field (0-based), or nil if out of range.
        def field(n)
          fields[n]
        end
      end

      HEX_PATTERN = /\A[0-9A-Fa-f]{1,6}\z/.freeze
      private_constant :HEX_PATTERN

      RANGE_SEPARATOR = ".."
      private_constant :RANGE_SEPARATOR

      class << self
        # Iterates non-blank, non-comment lines from `path`, yielding Line
        # records. Returns an Enumerator when no block is given so callers
        # can chain (`.first(n)`, `.lazy.map`, etc.).
        #
        # Lines that are entirely whitespace or start with `#` are skipped
        # silently — comment text is preserved on data lines that carry an
        # inline `# trailing comment`.
        def each_line(path)
          return enum_for(:each_line, path) unless block_given?

          lineno = 0
          File.foreach(path.to_s) do |raw|
            lineno += 1
            stripped = raw.strip
            next if stripped.empty?
            next if stripped.start_with?("#")

            yield build_line(lineno, raw)
          end
        end

        # Parses an n-th `;`-separated field from a line of text or a Line
        # struct. Strips surrounding whitespace. Returns nil if the field
        # is missing or out of range.
        def parse_field(line, n)
          fields = line_fields(line)
          return nil if fields.length <= n

          fields[n]
        end

        # Parses a codepoint-or-range field per UAX #44. Accepts:
        #   "0041"           → 0x0041 (Integer)
        #   "3400..4DBF"     → 0x3400..0x4DBF (Range)
        #
        # Returns nil for blank input. Raises Ucode::MalformedLineError
        # for invalid hex.
        def parse_codepoint_or_range(field)
          return nil if field.nil? || field.empty?

          if field.include?(RANGE_SEPARATOR)
            first_str, last_str = field.split(RANGE_SEPARATOR, 2)
            first = parse_hex_cp(first_str)
            last = parse_hex_cp(last_str)
            Range.new(first, last)
          else
            parse_hex_cp(field)
          end
        end

        # Parses a single hex codepoint string into an Integer. Raises
        # Ucode::MalformedLineError with the offending input in context
        # for invalid input.
        def parse_hex_cp(input)
          s = input.to_s.strip
          unless s.match?(HEX_PATTERN)
            raise MalformedLineError.new(
              "invalid codepoint: #{input.inspect}",
              context: { input: input }
            )
          end
          s.to_i(16)
        end

        private

        # Builds a Line struct from a raw text line. Splits off any
        # trailing `# comment` into the Line's `comment` field.
        def build_line(number, raw)
          text = raw.chomp
          hash_idx = text.index("#")

          if hash_idx.nil?
            Line.new(number: number, text: text, comment: nil)
          else
            Line.new(
              number: number,
              text: text[0...hash_idx].rstrip,
              comment: text[(hash_idx + 1)..].strip
            )
          end
        end

        def line_fields(line)
          data = line.is_a?(Line) ? line.data : line.to_s
          data.split(";").map(&:strip)
        end
      end
    end
  end
end
