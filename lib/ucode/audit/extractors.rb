# frozen_string_literal: true

# Autoload hub for the Ucode::Audit::Extractors namespace.
#
# Each extractor is a small MECE class with a single `#extract(context)`
# method returning a hash of AuditReport fields. The Audit::Registry
# declares the ordered list.
#
# Starts empty. TODOs 08 and 09 add extractors here in strict order:
#
#   08 (cheap):  Provenance, Identity, Style, Licensing, Coverage
#   09 (pricy):  Metrics, Hinting, ColorCapabilities, VariationDetail,
#                OpenTypeLayout, Aggregations
module Ucode
  module Audit
    module Extractors
    end
  end
end
