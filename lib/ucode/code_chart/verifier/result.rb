# frozen_string_literal: true

module Ucode
  module CodeChart
    class Verifier
      # Typed result of verifying one {Extractor::Result}. One of
      # three concrete classes; pattern-match on the class to read
      # type-specific fields.
      module Result
        # Diff < {Verifier::Strategy::FAIL_THRESHOLD}. The extracted
        # SVG matches the source PDF cell within tolerance.
        Pass = Struct.new(:codepoint, :percent, keyword_init: true)

        # Diff ≥ threshold. Carries the diff artifact path so a human
        # can inspect the failure.
        Fail = Struct.new(:codepoint, :percent, :diff_path,
                          keyword_init: true)

        # No positional data on the {Extractor::Result}; no honest
        # cell-diff is possible. `reason` carries one of:
        #   * `:no_location` — source_page/source_cell were nil.
        #   * `:no_pdf` — the PDF path is missing/unreadable.
        Skipped = Struct.new(:codepoint, :reason, keyword_init: true)
      end
    end
  end
end
