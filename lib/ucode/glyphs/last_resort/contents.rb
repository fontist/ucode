# frozen_string_literal: true

require "nokogiri"

module Ucode
  module Glyphs
    module LastResort
      # Parses the UFO `contents.plist` once into a
      # `{glyph_name => glif_basename}` lookup.
      #
      # The plist is the standard UFO v3 format:
      #
      #   <dict>
      #     <key>lastresortlatin</key>
      #     <string>lastresortlatin.glif</string>
      #     ...
      #   </dict>
      #
      # 380 entries (one per placeholder glyph). Tiny file, but parsing
      # it once per Writer avoids 380 redundant Nokogiri passes across
      # the per-codepoint loop.
      class Contents
        KeyEl = "key"
        private_constant :KeyEl

        StringEl = "string"
        private_constant :StringEl

        # Parse the plist file at `path` and return a frozen Hash.
        #
        # @param path [String, Pathname, #to_path] contents.plist path
        # @return [Hash{String=>String}] glyph name → glif basename
        def self.parse(path)
          new(path).to_h
        end

        # @param path [String, Pathname, #to_path] contents.plist path
        def initialize(path)
          @path = Pathname.new(path)
        end

        # @return [Hash{String=>String}] frozen glyph name → glif basename
        def to_h
          @to_h ||= build_index.freeze
        end

        # @param glyph_name [String]
        # @return [String, nil] glif basename (e.g. "lastresortlatin.glif")
        def [](glyph_name)
          to_h[glyph_name]
        end

        # @return [Boolean]
        def key?(glyph_name)
          to_h.key?(glyph_name)
        end

        private

        def build_index
          doc = Nokogiri::XML(@path.read) do |config|
            config.noblanks.strict
          end
          pairs = doc.xpath("/plist/dict/*").each_slice(2)
          pairs.each_with_object({}) do |(key_node, val_node), hash|
            next unless key_node.name == KeyEl && val_node&.name == StringEl

            hash[key_node.text] = val_node.text
          end
        end
      end
    end
  end
end
