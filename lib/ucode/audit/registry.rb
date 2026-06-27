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
    module Registry
      # Full audit: every concern. The five cheap extractors come from
      # TODO 08; the five expensive extractors come from TODO 09. The
      # Aggregations extractor (TODO 10) is still pending — it sits
      # last because it depends on UCD baseline resolution.
      ORDERED_EXTRACTORS = [
        Extractors::Provenance,
        Extractors::Identity,
        Extractors::Style,
        Extractors::Licensing,
        Extractors::Coverage,
        Extractors::Metrics,
        Extractors::Hinting,
        Extractors::ColorCapabilities,
        Extractors::VariationDetail,
        Extractors::OpenTypeLayout,
      ].freeze

      # Brief audit: cheap, name-table-only extractors. Used by
      # `ucode audit --brief` for a fast inventory pass. Stable list —
      # the expensive extractors are never part of brief mode.
      BRIEF_EXTRACTORS = [
        Extractors::Provenance,
        Extractors::Identity,
        Extractors::Style,
        Extractors::Licensing,
        Extractors::Coverage,
      ].freeze

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
