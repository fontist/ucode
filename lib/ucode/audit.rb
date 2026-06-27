# frozen_string_literal: true

# Autoload hub for the Ucode::Audit namespace.
#
# The audit pipeline takes a font face (or a library of faces) and
# produces a structured {Models::Audit::AuditReport} per face, plus a
# {Models::Audit::LibrarySummary} for directory-level rollups. The
# pipeline is:
#
#   CLI → AuditCommand → Context → Registry.each { |extractor| ... }
#                                      → merge hashes → AuditReport
#
# MECE: every concern (provenance, identity, style, licensing, coverage,
# aggregations, etc.) lives in exactly one Extractor. Adding a concern =
# one file under Extractors/ + one line in Registry.
module Ucode
  module Audit
    autoload :Context, "ucode/audit/context"
    autoload :Registry, "ucode/audit/registry"
    autoload :Extractors, "ucode/audit/extractors"
  end
end
