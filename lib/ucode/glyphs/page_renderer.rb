# frozen_string_literal: true

require "open3"
require "pathname"

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

        # @param name [Symbol, String]
        # @return [Class, nil]
        def find(name)
          all.find { |r| r.renderer_name == name.to_sym }
        end

        # @return [Class, nil] the first available renderer, or nil
        def default
          available.first
        end
      end
    end
  end
end
