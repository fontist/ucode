# frozen_string_literal: true

module Ucode
  module CodeChart
    module GapAnalyzer
      # Typed per-block result: which block, which codepoints the
      # manifest's donor sources DON'T cover, and the UCD version
      # the manifest declared.
      #
      # The unit of work {BatchRunner} iterates. Frozen on
      # construction so callers can pass it around without worry.
      BlockGap = Struct.new(
        :block_id,
        :missing_codepoints,
        :ucd_version,
        keyword_init: true,
      ) do
        def initialize(*)
          super
          self.missing_codepoints = Array(missing_codepoints).sort.freeze
        end

        # @return [Integer]
        def size
          missing_codepoints.size
        end

        # @return [Boolean]
        def empty?
          missing_codepoints.empty?
        end
      end
    end
  end
end
