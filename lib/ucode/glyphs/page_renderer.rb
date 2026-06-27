# frozen_string_literal: true

require "open3"
require "pathname"
require "tmpdir"

require "ucode/error"

module Ucode
  module Glyphs
    # Strategy interface for PDF-page-to-SVG rendering.
    #
    # Subclasses implement `renderer_name`, `binary_name`, and
    # `build_command`. The base class handles availability check,
    # command execution, error handling, and the renderer registry.
    #
    # **OCP**: a new renderer is a new subclass file + one entry in
    # `KNOWN_RENDERERS`. The base class and existing renderers are not
    # modified.
    #
    # **Vector-only requirement**: every renderer here must emit SVG
    # `<path>` elements (vector data) for the Code Charts PDFs, not
    # raster images. Callers verify this via `path_count` on the output.
    class PageRenderer
      OUTPUT_FORMAT = :svg

      # Fixture used by `works?` to smoke-test renderers. Resolved lazily
      # so missing-fixture environments (installed gem without spec assets)
      # don't fail at load time.
      DEFAULT_SMOKE_FIXTURE =
        File.expand_path("../../../spec/fixtures/pdfs/basic_latin.pdf", __dir__)

      # Ordered list of known concrete renderer class names (as symbols),
      # most-preferred first. Resolved lazily via `const_get` so that
      # loading any one renderer does not eagerly load all of them — this
      # avoids a circular require (each renderer file requires this file
      # to inherit from PageRenderer).
      KNOWN_RENDERERS = %i[
        MutoolRenderer
        Pdf2svgRenderer
        DvisvgmRenderer
        PdftocairoRenderer
      ].freeze
      private_constant :KNOWN_RENDERERS

      class << self
        # @return [Symbol] short identifier (e.g. :mutool)
        def renderer_name
          raise NotImplementedError
        end

        # @return [String, Symbol] the binary looked up on PATH
        def binary_name
          raise NotImplementedError
        end

        # @return [Symbol] always :svg for now; future formats (png, etc.)
        #   would warrant a separate renderer family.
        def output_format
          OUTPUT_FORMAT
        end

        # Build the argv for the renderer. Subclasses return an Array
        # suitable for `Open3.capture2e` (no shell interpolation).
        # @param pdf_path [Pathname, String]
        # @param page_num [Integer] 1-indexed
        # @param out_path [Pathname, String]
        # @return [Array<String>]
        def build_command(pdf_path, page_num, out_path)
          raise NotImplementedError
        end

        # @return [Boolean] true if the binary is on PATH
        def available?
          system("which", binary_name.to_s, out: "/dev/null", err: "/dev/null")
        end

        # Smoke-test the binary by actually rendering one page of the
        # fixture PDF AND verifying the output format is consumable by
        # the downstream `GridDetector` / `CellExtractor` pipeline.
        #
        # Three things can make a renderer unusable for this codebase:
        #   1. Binary not on PATH (`available?` catches this).
        #   2. Binary on PATH but silently broken (e.g. Ubuntu's
        #      `mupdf-tools` is built without LCMS, so `mutool` warns
        #      "ICC support is not available" and emits zero bytes for
        #      ICC-profiled PDFs).
        #   3. Binary works but emits a flat-path SVG that GridDetector
        #      can't parse (mutool's format: `<path id="font_X_Y">`
        #      directly in `<defs>`, no `<use>` references). The grid
        #      detector requires the `<g id="glyph-N-M">` + `<use>` form
        #      produced by pdftocairo / pdf2svg.
        #
        # The result is memoized per-renderer for the process lifetime —
        # the binary's capabilities don't change mid-run.
        #
        # When no fixture PDF is available (e.g. installed gem without
        # spec assets), degrades to `available?` — we can't smoke-test
        # without input, so we trust the binary's presence on PATH.
        #
        # @param fixture_pdf [String, Pathname] small one-page PDF used
        #   for the smoke render. Defaults to the project's
        #   `basic_latin.pdf` spec fixture.
        # @return [Boolean]
        def works?(fixture_pdf: DEFAULT_SMOKE_FIXTURE)
          if !available?
            false
          elsif !File.exist?(fixture_pdf.to_s)
            true # no fixture to verify against; trust PATH
          else
            smoke_render_ok?(fixture_pdf)
          end
        end

        # Render one page of `pdf_path` to `out_path` as SVG.
        # @param pdf_path [Pathname, String]
        # @param page_num [Integer] 1-indexed
        # @param out_path [Pathname, String]
        # @return [Symbol] :ok on success
        # @raise [Ucode::PdfRenderError] on failure (non-zero exit,
        #   output file missing, or binary unavailable)
        def render(pdf_path, page_num, out_path)
          unless available?
            raise PdfRenderError.new(
              "binary '#{binary_name}' not available on PATH",
              context: { renderer: name, binary: binary_name },
            )
          end

          out = Pathname.new(out_path)
          out.dirname.mkpath

          cmd = build_command(Pathname.new(pdf_path), page_num, out)
          output, status = Open3.capture2e(*cmd)

          unless status.success? && out.exist? && out.size.positive?
            raise PdfRenderError.new(
              "render failed for page #{page_num} of #{pdf_path} via '#{binary_name}'",
              context: {
                renderer: name,
                binary: binary_name,
                exit_status: status.exitstatus,
                output: output,
              },
            )
          end

          :ok
        end

        # ---- Registry ----

        # @return [Array<Class>] every known concrete renderer
        def all
          @all ||= KNOWN_RENDERERS.map { |n| Ucode::Glyphs.const_get(n) }.freeze
        end

        # @return [Array<Class>] renderers whose binary is installed
        def available
          all.select(&:available?)
        end

        # @return [Array<Class>] renderers that actually produce SVG in
        #   the format `GridDetector` consumes (smoke-tested once per
        #   process via `works?`, then cached). Subset of `available`.
        def working
          return @working if @working

          @working = all.select(&:works?).freeze
        end

        # Clear the cached `working` list. Useful when the environment
        # changes (e.g. a binary is installed mid-process) or in tests.
        def reset_working_cache!
          @working = nil
        end

        # @param name [Symbol, String]
        # @return [Class, nil]
        def find(name)
          all.find { |r| r.renderer_name == name.to_sym }
        end

        # @return [Class, nil] the first working renderer; falls back to
        #   the first available renderer if none have been smoke-tested
        #   yet (preserves eager-init paths). nil if nothing is installed.
        def default
          working.first || available.first
        end

        private

        # @param fixture_pdf [String] path to an existing PDF
        # @return [Boolean] true iff rendering page 1 produces an SVG
        #   with the `<g id="glyph-N-M">` + `<use>` form that
        #   `GridDetector` requires.
        def smoke_render_ok?(fixture_pdf)
          Dir.mktmpdir("renderer-smoke-") do |dir|
            out = File.join(dir, "smoke.svg")
            begin
              render(fixture_pdf, 1, out)
            rescue PdfRenderError
              break false
            end
            svg_has_pipeline_format?(out)
          end
        end

        def svg_has_pipeline_format?(out_path)
          return false unless File.exist?(out_path)
          return false unless File.size(out_path).positive?

          body = File.read(out_path)
          body.include?("<svg") &&
            body.include?("<use") &&
            body.match?("id=\"glyph-\\d+-\\d+\"")
        end
      end
    end
  end
end
