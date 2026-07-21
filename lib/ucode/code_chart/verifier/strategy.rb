# frozen_string_literal: true

require "pathname"

module Ucode
  module CodeChart
    class Verifier
      # Abstract base for one verification-renderer strategy. Each
      # subclass owns ONE external CLI tool (resvg, mutool, etc.)
      # and implements the three primitives the {Verifier} needs.
      #
      # Subclasses must implement:
      #   * {#available?} — is the underlying tool installed?
      #   * {#render_svg} — render an SVG to a PNG at the given scale.
      #   * {#render_pdf_region} — render a rectangular region of one
      #     PDF page to a PNG at the given scale.
      #   * {#diff} — pixel-diff percentage between two PNGs.
      #
      # Adding a new renderer = one subclass + one entry in {Builder}.
      # No edit to {Verifier}.
      class Strategy
        # Diff percentage at or above which a glyph is considered
        # visually different from the source. Tuned to absorb
        # anti-aliasing differences across renderers; callers can
        # override via the {Verifier} constructor.
        FAIL_THRESHOLD = 1.0

        # @return [Boolean] true iff the underlying tool is on PATH
        def available?
          raise NotImplementedError
        end

        # @param svg_path [Pathname, String] source SVG
        # @param png_path [Pathname, String] destination PNG
        # @param scale [Float] zoom factor (2.0 = 200%)
        # @return [Pathname] the written PNG path
        def render_svg(_svg_path, _png_path, scale: 2.0)
          raise NotImplementedError
        end

        # @param pdf_path [Pathname, String] source PDF
        # @param page [Integer] 1-based page number
        # @param rect [Hash{Symbol=>Float}] `{x:, y:, w:, h:}` in PDF
        #   user space (origin bottom-left) of the region to render.
        # @param png_path [Pathname, String] destination PNG
        # @param scale [Float] zoom factor
        # @return [Pathname]
        def render_pdf_region(_pdf_path, _page, _rect, _png_path, scale: 2.0)
          raise NotImplementedError
        end

        # @param png_a [Pathname, String]
        # @param png_b [Pathname, String]
        # @return [Float] percentage of differing pixels (0.0–100.0)
        def diff(_png_a, _png_b)
          raise NotImplementedError
        end

        # Optional: produce a visual diff artifact (e.g. side-by-side
        # or red/blue overlay). When unsupported, returns nil and the
        # {Verifier} skips writing the artifact.
        #
        # @param png_a [Pathname, String]
        # @param png_b [Pathname, String]
        # @param dest [Pathname, String]
        # @return [Pathname, nil]
        def write_diff_artifact(_png_a, _png_b, _dest)
          nil
        end
      end
    end
  end
end
