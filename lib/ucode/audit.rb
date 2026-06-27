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
    autoload :CodepointRangeCoalescer, "ucode/audit/codepoint_range_coalescer"
    autoload :BlockAggregator, "ucode/audit/block_aggregator"
    autoload :ScriptAggregator, "ucode/audit/script_aggregator"
    autoload :PlaneAggregator, "ucode/audit/plane_aggregator"
    autoload :DiscrepancyDetector, "ucode/audit/discrepancy_detector"

    # Per-face orchestrator (TODO 11) — shared by LibraryAuditor and
    # the future CLI AuditCommand.
    autoload :FaceAuditor, "ucode/audit/face_auditor"

    # Cross-report orchestration (TODO 11).
    autoload :Differ, "ucode/audit/differ"
    autoload :LibraryAuditor, "ucode/audit/library_auditor"
    autoload :LibraryAggregator, "ucode/audit/library_aggregator"

    # Human-readable text output (TODO 12).
    autoload :Formatters, "ucode/audit/formatters"

    # Mode 2 directory output writers (TODO 13).
    autoload :Emitter, "ucode/audit/emitter"

    # Standalone HTML browsers for Mode 2 output (TODOs 14+15).
    autoload :Browser, "ucode/audit/browser"
  end
end
