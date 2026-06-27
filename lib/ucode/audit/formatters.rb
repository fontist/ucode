# frozen_string_literal: true

# Autoload hub for the Ucode::Audit::Formatters namespace.
#
# Presentation-only: every class here takes a model instance
# ({Models::Audit::AuditReport}, {Models::Audit::AuditDiff}, or
# {Models::Audit::LibrarySummary}) and returns a human-readable string.
# No font parsing, no I/O.
#
# MECE with the model layer: formatters READ from models; they never
# mutate them or carry audit logic. Adding a new output format (e.g.
# Markdown) = one new file here + one autoload line.
module Ucode
  module Audit
    module Formatters
      autoload :Color,                "ucode/audit/formatters/color"
      autoload :TextFormatter,        "ucode/audit/formatters/text_formatter"
      autoload :AuditText,            "ucode/audit/formatters/audit_text"
      autoload :AuditDiffText,        "ucode/audit/formatters/audit_diff_text"
      autoload :LibrarySummaryText,   "ucode/audit/formatters/library_summary_text"
    end
  end
end
