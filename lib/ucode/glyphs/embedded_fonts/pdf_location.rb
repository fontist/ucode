# frozen_string_literal: true

require "pathname"

module Ucode
  module Glyphs
    module EmbeddedFonts
      # Locates the Code Charts PDF on disk and the directory where
      # extracted font streams are cached.
      #
      # PDF resolution order (first match wins):
      #
      #   1. Explicit `pdf:` argument.
      #   2. `UCODE_CODE_CHARTS_PDF` environment variable.
      #   3. Conventional `<gem_root>/CodeCharts.pdf`.
      #
      # Per-block PDFs (preferred for incremental runs) can be supplied
      # via the `pdf:` argument by the caller — typically the CLI.
      #
      # Cache resolution order:
      #
      #   1. Explicit `cache_dir:` argument.
      #   2. `UCODE_PDF_FONT_CACHE` environment variable.
      #   3. Conventional `<gem_root>/data/pdf-fonts/`.
      #
      # The cache holds one file per embedded font program, named after
      # the BaseFont (e.g. `CIAIIP+Uni2000Generalpunctuation.ttf`).
      # Re-runs skip extraction when the cached file is newer than the
      # PDF.
      class PdfLocation
        attr_reader :pdf_path, :cache_dir

        # @param pdf [String, Pathname, nil] path to a Code Charts PDF
        # @param cache_dir [String, Pathname, nil] directory for cached
        #   font files; created on demand
        # @param env [Hash{String=>String}] env var source (defaults to ENV)
        # @param gem_root [String, Pathname, nil] gem root for the
        #   conventional fallback; injectable for tests
        # @raise [Ucode::EmbeddedFontsMissingError] if the PDF is missing
        def initialize(pdf: nil, cache_dir: nil, env: ENV, gem_root: nil)
          @pdf_path = resolve_pdf(pdf, env, gem_root)
          raise Ucode::EmbeddedFontsMissingError,
                "Code Charts PDF not found at #{@pdf_path}" unless @pdf_path&.exist?

          @cache_dir = resolve_cache(cache_dir, env, gem_root)
          @cache_dir.mkpath unless @cache_dir.exist?
        end

        # @return [String] absolute path to the PDF, suitable for shelling
        #   out to `mutool`
        def pdf_to_s
          @pdf_path.to_s
        end

        # @param base_font [String] e.g. "CIAIIP+Uni2000Generalpunctuation"
        # @param extension [String] e.g. ".ttf" or ".cff"
        # @return [Pathname] cache path for the named font
        def font_cache_path(base_font, extension)
          @cache_dir.join("#{base_font}#{extension}")
        end

        private

        def resolve_pdf(explicit, env, gem_root)
          return Pathname.new(explicit).expand_path if explicit

          env_val = env["UCODE_CODE_CHARTS_PDF"]
          return Pathname.new(env_val).expand_path if env_val && !env_val.empty?

          base = gem_root ? Pathname.new(gem_root) : default_gem_root
          base.expand_path.join("CodeCharts.pdf")
        end

        def resolve_cache(explicit, env, gem_root)
          return Pathname.new(explicit).expand_path if explicit

          env_val = env["UCODE_PDF_FONT_CACHE"]
          return Pathname.new(env_val).expand_path if env_val && !env_val.empty?

          base = gem_root ? Pathname.new(gem_root) : default_gem_root
          base.expand_path.join("data", "pdf-fonts")
        end

        # __dir__ = lib/ucode/glyphs/embedded_fonts/. Five `..` get us
        # back to the project root (the directory containing `lib/`).
        def default_gem_root
          Pathname.new(__dir__).join("..", "..", "..", "..", "..")
        end
      end
    end
  end
end
