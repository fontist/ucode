# frozen_string_literal: true

# Autoload hub for the Ucode::Audit::Extractors namespace.
#
# Each extractor is a small MECE class with a single `#extract(context)`
# method returning a hash of AuditReport fields. The Audit::Registry
# declares the ordered list.
module Ucode
  module Audit
    module Extractors
      # Cheap extractors (TODO 08) — brief-mode eligible.
      autoload :Base,       "ucode/audit/extractors/base"
      autoload :Provenance, "ucode/audit/extractors/provenance"
      autoload :Identity,   "ucode/audit/extractors/identity"
      autoload :Style,      "ucode/audit/extractors/style"
      autoload :Licensing,  "ucode/audit/extractors/licensing"
      autoload :Coverage,   "ucode/audit/extractors/coverage"

      # Expensive extractors (TODO 09) — full-mode only.
      autoload :Metrics,           "ucode/audit/extractors/metrics"
      autoload :Hinting,           "ucode/audit/extractors/hinting"
      autoload :ColorCapabilities, "ucode/audit/extractors/color_capabilities"
      autoload :VariationDetail,   "ucode/audit/extractors/variation_detail"
      autoload :OpenTypeLayout,    "ucode/audit/extractors/opentype_layout"

      # Aggregations (TODO 10) — full-mode only. Driven by ucode's own
      # UCD baseline, so it depends on baseline resolution succeeding.
      autoload :Aggregations, "ucode/audit/extractors/aggregations"
    end
  end
end
