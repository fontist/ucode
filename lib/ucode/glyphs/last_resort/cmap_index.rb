# frozen_string_literal: true

require "nokogiri"

require "ucode/error"

module Ucode
  module Glyphs
    module LastResort
      # Parses the Last Resort Font `cmap-f13.ttx` once into a flat
      # `{codepoint_int => glyph_name}` lookup.
      #
      # The Format 13 cmap has 1,114,112 entries (every codepoint from
      # U+0000 to U+10FFFF). Each entry looks like:
      #
      #   <map code="0x0" name="lastresortlatin"/>
      #
      # We parse every `<map>` child of every `<cmap_format_*>` element,
      # ignore the platform/encoding attributes (Format 13 only here),
      # and build a single Hash. Memory cost is ~80 MB for the parsed
      # Hash on Ruby 3.x — acceptable for the CLI, paid once per run.
      #
      # For long-running processes (e.g. the site dev server), the
      # parsed index can be cached via the optional `cache:` constructor
      # argument. The cache contract is `cache.read(key) -> Hash | nil`
      # and `cache.write(key, hash) -> void`; pass an object with both
      # methods (e.g. `Ucode::Cache`).
      class CmapIndex
        CodeAttr = "code"
        private_constant :CodeAttr

        NameAttr = "name"
        private_constant :NameAttr

        # Parse the cmap file at `path` and return a frozen Hash.
        #
        # @param path [String, Pathname, #to_path] cmap-f13.ttx path
        # @return [Hash{Integer=>String}] codepoint → glyph name
        def self.parse(path)
          new(path).to_h
        end

        # @param path [String, Pathname, #to_path] cmap-f13.ttx path
        def initialize(path)
          @path = Pathname.new(path)
        end

        # @return [Hash{Integer=>String}] frozen codepoint → glyph name
        def to_h
          @to_h ||= build_index.freeze
        end

        # @param codepoint [Integer]
        # @return [String, nil] glyph name or nil if no entry
        def [](codepoint)
          to_h[codepoint]
        end

        # @return [Boolean]
        def key?(codepoint)
          to_h.key?(codepoint)
        end

        # @return [Integer] number of entries
        def size
          to_h.size
        end

        private

        def build_index
          doc = Nokogiri::XML(@path.read) do |config|
            config.noblanks.strict
          end
          index = {}
          doc.xpath("/ttFont/cmap/cmap_format_13/map").each do |node|
            code = parse_code(node[CodeAttr])
            name = node[NameAttr]
            next if code.nil? || name.nil? || name.empty?

            index[code] = name
          end
          index
        end

        def parse_code(raw)
          return nil if raw.nil? || raw.empty?

          raw.start_with?("0x", "0X") ? raw[2..].to_i(16) : raw.to_i(16)
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
