# frozen_string_literal: true

module Ucode
  module Audit
    # Ordered list of extractor classes run for every audit face.
    #
    # Order matters only for human-readable output (text formatter).
    # All extractors are independent; their outputs are merged into
    # one big hash before constructing the AuditReport.
    #
    # MECE / OCP: a new concern = one file under
    # `Ucode::Audit::Extractors::*` + one line in the appropriate list
    # below. AuditCommand never enumerates extractors directly.
    #
    # Starts empty. TODOs 08 and 09 populate the lists in strict order.
    module Registry
      # Full audit: every concern. Populated by TODOs 08 and 09.
      ORDERED_EXTRACTORS = [].freeze

      # Brief audit: cheap, name-table-only extractors. Used by
      # `ucode audit --brief` for a fast inventory pass.
      BRIEF_EXTRACTORS = [].freeze

      # Iterate the extractors appropriate for the given mode.
      #
      # @param mode [Symbol] :full (default) or :brief
      # @yieldparam extractor_class [Class]
      # @return [void]
      def self.each(mode: :full, &)
        extractors_for(mode).each(&)
      end

      # @param mode [Symbol] :full or :brief
      # @return [Array<Class>] the extractor list for the given mode
      def self.extractors_for(mode)
        case mode
        when :brief then BRIEF_EXTRACTORS
        else ORDERED_EXTRACTORS
        end
      end
    end
  end
end
