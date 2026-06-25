# frozen_string_literal: true

require "ucode/parsers/base"
require "ucode/error"
require "ucode/models/names_list_entry"
require "ucode/models/relationship"

module Ucode
  module Parsers
    # Parses `NamesList.txt` — the human-curated annotated names file
    # Unicode uses to render the Code Charts' name pages.
    #
    # Format (per the file's own header):
    #
    #   cp; Name            ← header line at column 0 → new NamesListEntry
    #     → U+XXXX note    ← indented annotation lines
    #     × U+XXXX U+YYYY note
    #     ≡ U+XXXX note
    #     = alias text
    #     * footnote text
    #
    # Plus dropped lines:
    #
    #   `# comment`         ← file-level comment
    #   `% instruction`     ← dropped (instructional)
    #   `~ heading`         ← dropped (table-of-contents)
    #
    # Annotation scopes attach to the most recent header. Lines that do
    # not start a new header are silently ignored.
    #
    # Implemented as a small state machine: one current NamesListEntry is
    # held in a local; header lines flush the previous entry, annotation
    # lines append to the current entry. Regex cannot express this
    # scoping.
    class NamesList < Base
      HEADER_PATTERN = /\A([0-9A-Fa-f]{4,6})\s*;\s*(.+?)\s*\z/.freeze
      private_constant :HEADER_PATTERN

      CP_REF_PATTERN = /\AU\+([0-9A-Fa-f]{4,6})\b/.freeze
      private_constant :CP_REF_PATTERN

      RENDERED_PATTERN = /\(rendered:\s*(.+?)\)\z/.freeze
      private_constant :RENDERED_PATTERN

      MARKER_CROSS_REFERENCE = "→".freeze
      MARKER_SAMPLE_SEQUENCE = "×".freeze
      MARKER_COMPAT_EQUIV    = "≡".freeze
      MARKER_ALIAS           = "=".freeze
      MARKER_FOOTNOTE        = "*".freeze
      MARKER_INSTRUCTIONAL   = "%".freeze
      MARKER_HEADING         = "~".freeze

      SOURCE_TAG = "names_list".freeze
      private_constant :SOURCE_TAG

      class << self
        # Yields one NamesListEntry per codepoint header. Returns a lazy
        # Enumerator when no block is given.
        def each_record(path)
          return enum_for(:each_record, path) unless block_given?

          entry = nil
          lineno = 0
          path_str = path.to_s

          File.foreach(path_str) do |raw|
            lineno += 1
            line = raw.chomp

            begin
              if header_line?(line)
                yield entry if entry
                entry = build_header(line)
              elsif indented_line?(line) && entry
                parsed = parse_annotation(line)
                attach_annotation(entry, parsed) if parsed
              end
              # else: blank, comment, heading, or pre-header — skip
            rescue MalformedLineError => e
              e.context[:file] ||= path_str
              e.context[:line] ||= lineno
              raise
            end
          end

          yield entry if entry
          nil
        end

        private

        # Column-0 line whose first non-blank char is a hex digit and
        # which carries the `;` separator. Excludes `%`, `~`, `#`.
        def header_line?(line)
          return false if line.empty?
          return false if line.start_with?("#", "%", "~", "@")

          !line.match(HEADER_PATTERN).nil?
        end

        # Indented annotation: column 0 is whitespace and the line is
        # non-empty.
        def indented_line?(line)
          return false if line.empty?

          line[0] == " " || line[0] == "\t"
        end

        def build_header(line)
          m = line.match(HEADER_PATTERN)
          unless m
            raise MalformedLineError.new(
              "invalid NamesList.txt header: #{line.inspect}",
              context: { line: line }
            )
          end

          Models::NamesListEntry.new(
            codepoint: m[1].to_i(16),
            name: m[2]
          )
        end

        # Parses one indented annotation line. Returns a
        # `[container_attribute, Relationship]` pair, or `nil` if the
        # marker is dropped (`%`, `~`) or unknown.
        def parse_annotation(line)
          stripped = line.lstrip
          marker = stripped[0]
          rest = stripped[1..].to_s.lstrip

          case marker
          when MARKER_CROSS_REFERENCE
            target_ids, note = split_targets_and_note(rest)
            [
              :cross_references,
              build_cross_reference(target_ids, note),
            ]
          when MARKER_SAMPLE_SEQUENCE
            target_ids, note = split_targets_and_note(rest)
            [
              :sample_sequences,
              build_sample_sequence(target_ids, note),
            ]
          when MARKER_COMPAT_EQUIV
            target_ids, note = split_targets_and_note(rest)
            [
              :compatibility_equivalents,
              build_compat_equiv(target_ids, note),
            ]
          when MARKER_ALIAS
            [:informal_aliases, build_alias(rest)]
          when MARKER_FOOTNOTE
            [:footnotes, build_footnote(rest)]
          when MARKER_INSTRUCTIONAL, MARKER_HEADING
            nil
          else
            nil
          end
        end

        def build_cross_reference(target_ids, note)
          Models::Relationship::CrossReference.new(
            target_ids: target_ids,
            description: note.empty? ? nil : note,
            source: SOURCE_TAG
          )
        end

        def build_sample_sequence(target_ids, note)
          rendered = extract_rendered(note)
          Models::Relationship::SampleSequence.new(
            target_ids: target_ids,
            description: note.empty? ? nil : note,
            rendered_form: rendered,
            source: SOURCE_TAG
          )
        end

        def build_compat_equiv(target_ids, note)
          Models::Relationship::CompatEquiv.new(
            target_ids: target_ids,
            description: note.empty? ? nil : note,
            source: SOURCE_TAG
          )
        end

        def build_alias(text)
          Models::Relationship::InformalAlias.new(
            description: text.empty? ? nil : text,
            source: SOURCE_TAG
          )
        end

        def build_footnote(text)
          Models::Relationship::Footnote.new(
            description: text.empty? ? nil : text,
            category: detect_footnote_category(text),
            source: SOURCE_TAG
          )
        end

        # Splits a `U+XXXX [U+YYYY ...] note` payload into leading target
        # ids (zero-padded `U+XXXX` form) and the trailing prose note.
        def split_targets_and_note(rest)
          targets = []
          remaining = rest.dup

          while (m = remaining.match(CP_REF_PATTERN))
            targets << format("U+%04X", m[1].to_i(16))
            remaining = remaining[m[0].length..].to_s.lstrip
          end

          [targets, remaining]
        end

        # Pulls `(rendered: X)` suffix from sample-sequence notes when
        # present. Returns nil otherwise.
        def extract_rendered(note)
          m = note.match(RENDERED_PATTERN)
          return nil unless m

          m[1].strip
        end

        # Heuristic footnote category. The Unicode names list does not
        # tag these explicitly; the categories are useful for UI grouping.
        def detect_footnote_category(text)
          first = text.split(/\s+/, 2).first&.downcase
          case first
          when "cap", "capital", "small", "lowercase", "uppercase",
               "letter", "letterform", "glyph", "shape"
            "letterform"
          when "see", "compare", "vs", "versus", "distinguished"
            "comparison"
          when "history", "origin", "originally", "introduced"
            "history"
          else
            "general"
          end
        end

        def attach_annotation(entry, parsed)
          attr_name, instance = parsed
          entry.public_send(attr_name) << instance
        end
      end
    end
  end
end
