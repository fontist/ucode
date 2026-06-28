# frozen_string_literal: true

module Ucode
  # Fetchers — download UCD.zip, Unihan.zip, per-block Code Charts
  # PDFs, and the specialist Tier 1 fonts that fontist's formula
  # index does not carry.
  #
  # OCP: Http is the single network boundary. New source types add a
  # new Fetcher class that calls Http.get; no new HTTP stack.
  module Fetch
    autoload :Http, "ucode/fetch/http"
    autoload :UcdZip, "ucode/fetch/ucd_zip"
    autoload :UnihanZip, "ucode/fetch/unihan_zip"
    autoload :CodeCharts, "ucode/fetch/code_charts"
    autoload :FontFetcher, "ucode/fetch/font_fetcher"
    autoload :SpecialistFontFetcher, "ucode/fetch/specialist_font_fetcher"
  end
end
