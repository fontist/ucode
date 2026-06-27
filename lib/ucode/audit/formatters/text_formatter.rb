# frozen_string_literal: true

module Ucode
  module Audit
    module Formatters
      # Shared utilities for the text-rendering formatters. Owns the
      # column helpers, list truncation, byte formatting, and ANSI
      # color hook that the audit/diff/library renderers all use.
      #
      # Formatters instantiate this class and delegate common formatting
      # chores to it; the renderer classes own the section shape and
      # model-walking logic.
      class TextFormatter
        LIST_LIMIT = 10
        LABEL_WIDTH = 18

        # Format a list of arbitrary items as a single-line truncated
        # comma-separated string. Returns "(none)" for empty input.
        #
        # @param items [Enumerable]
        # @return [String]
        def truncate_list(items, limit: LIST_LIMIT)
          list = Array(items)
          return "(none)" if list.empty?

          shown = list.first(limit).join(", ")
          if list.size > limit
            "#{shown}, … (+#{list.size - limit} more)"
          else
            shown
          end
        end

        # Format a codepoint range list as `U+XXXX-U+XXXX, …`, truncated.
        #
        # @param ranges [Enumerable<Models::Audit::CodepointRange>]
        # @return [String]
        def truncate_ranges(ranges, limit: LIST_LIMIT)
          list = Array(ranges)
          return "(none)" if list.empty?

          shown = list.first(limit).join(", ")
          if list.size > limit
            "#{shown}, … (+#{list.size - limit} more)"
          else
            shown
          end
        end

        # Format an integer byte count as `B` / `KB` / `MB`.
        #
        # @param bytes [Integer, nil]
        # @return [String]
        def format_bytes(bytes)
          return "0 B" if bytes.nil? || bytes.zero?

          if bytes < 1024
            "#{bytes} B"
          elsif bytes < 1024 * 1024
            format("%<v>.2f KB", v: bytes / 1024.0)
          else
            format("%<v>.2f MB", v: bytes / (1024.0 * 1024))
          end
        end

        # Right-pad a label to a column width, then append the value.
        # Returns nil if value is nil or empty-string (signal to skip).
        #
        # @param label [String, Symbol]
        # @param value [Object]
        # @return [String, nil]
        def row(label, value, width: LABEL_WIDTH)
          return if value.nil?
          return if value.is_a?(String) && value.empty?

          label_s = label.to_s
          padding = " " * [(width - label_s.length - 1), 1].max
          "  #{label_s}:#{padding}#{value}"
        end
      end
    end
  end
end
