# frozen_string_literal: true

require "yaml"

module Ucode
  module CodeChart
    module GapAnalyzer
      # Abstract manifest parser. Subclasses own ONE manifest schema
      # and expose a uniform `{block_id => covered_codepoints}` shape
      # to {GapAnalyzer}.
      #
      # Subclasses must implement {#parse}.
      class Manifest
        # @param path [Pathname, String] manifest file path
        def initialize(path)
          @path = Pathname.new(path)
        end

        # @return [String] the UCD version declared in the manifest
        def ucd_version
          raise NotImplementedError
        end

        # @return [Hash{String=>Array<Integer>}] block_id → array of
        #   codepoints the manifest's donor sources cover
        def coverage_by_block
          raise NotImplementedError
        end

        # @raise [ArgumentError] when the manifest file doesn't exist
        def read_text
          return @path.read unless @path.exist?

          @path.read
        end
      end
    end
  end
end
