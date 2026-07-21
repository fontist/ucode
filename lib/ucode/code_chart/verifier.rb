# frozen_string_literal: true

require "fileutils"
require "pathname"

module Ucode
  module CodeChart
    # Pixel-diff verification for extracted SVG glyphs against the
    # source PDF cell. REQ R4.
    #
    # ## Strategy chain (OCP)
    #
    # One renderer strategy per external tool. The strategy exposes
    # three primitive operations: render an SVG to PNG, render a PDF
    # page region to PNG, and compute a pixel-diff percentage between
    # two PNGs. {Verifier} orchestrates these primitives; it has no
    # knowledge of any specific CLI tool.
    #
    # Adding a new renderer (cairo, imagemagick, …) = one Strategy
    # subclass + one entry in {Verifier::Builder.pick}. Verifier core
    # never changes.
    #
    # ## Result types (see Verifier::Result)
    #
    #   * `Pass` — diff < FAIL_THRESHOLD (default 1.0%).
    #   * `Fail` — diff ≥ threshold; carries the percent + diff
    #     artifact path for inspection.
    #   * `Skipped` — extractor produced no `source_page`/`source_cell`
    #     (e.g. ToUnicode-only path, or Last Resort placeholder), so no
    #     honest cell-diff is possible. Surfaces as a warning, NOT a
    #     pass.
    class Verifier
      autoload :Strategy, "ucode/code_chart/verifier/strategy"
      autoload :ResvgStrategy, "ucode/code_chart/verifier/resvg_strategy"
      autoload :MutoolStrategy, "ucode/code_chart/verifier/mutool_strategy"
      autoload :Builder, "ucode/code_chart/verifier/builder"
      autoload :PageRenderCache, "ucode/code_chart/verifier/page_render_cache"
      autoload :Result, "ucode/code_chart/verifier/result"

      DEFAULT_CELL_SIZE = 40.0
      private_constant :DEFAULT_CELL_SIZE

      # @param strategy [Strategy, nil] nil = {Builder.pick} auto.
      # @param diff_dir [Pathname, String] where diff artifacts land
      # @param threshold [Float, nil] override {Strategy::FAIL_THRESHOLD}
      def initialize(diff_dir:, strategy: nil, threshold: nil)
        @strategy = strategy || Builder.pick
        @diff_dir = Pathname.new(diff_dir)
        @threshold = threshold || (Strategy::FAIL_THRESHOLD if @strategy)
        if @strategy
          @page_cache = PageRenderCache.new(diff_dir: @diff_dir.join(".cache"),
                                            strategy: @strategy)
        end
      end

      # @return [Boolean] true iff a usable strategy was found
      def available?
        !@strategy.nil? && @strategy.available?
      end

      # @param result [Ucode::CodeChart::Extractor::Result]
      # @param pdf_path [Pathname, String, nil] source PDF
      # @return [Result::Pass, Result::Fail, Result::Skipped]
      def verify(result, pdf_path:)
        unless @strategy
          return Result::Skipped.new(codepoint: result.codepoint,
                                     reason: :no_strategy)
        end

        loc = extract_location(result)
        unless loc
          return Result::Skipped.new(codepoint: result.codepoint,
                                     reason: :no_location)
        end

        path = Pathname.new(pdf_path)
        unless path.exist?
          return Result::Skipped.new(codepoint: result.codepoint,
                                     reason: :no_pdf)
        end

        verify_with_location(result, path, loc)
      end

      private

      def extract_location(result)
        return nil unless result.source_page && result.source_cell

        {
          page: result.source_page,
          x: result.source_cell[:x],
          y: result.source_cell[:y],
        }
      end

      def verify_with_location(result, pdf_path, loc)
        svg_png = render_svg(result)
        cell_png = render_cell(pdf_path, loc)

        percent = @strategy.diff(svg_png, cell_png)
        if percent < @threshold
          Result::Pass.new(codepoint: result.codepoint, percent: percent)
        else
          artifact = write_artifact(result, svg_png, cell_png)
          Result::Fail.new(codepoint: result.codepoint,
                           percent: percent,
                           diff_path: artifact)
        end
      ensure
        [svg_png, cell_png].each { |p| FileUtils.rm_f(p.to_s) if p&.exist? }
      end

      def render_svg(result)
        svg_path = @diff_dir.join("#{format_cp(result.codepoint)}.svg")
        svg_path.dirname.mkpath
        svg_path.write(result.svg)
        png_path = Pathname.new("#{svg_path}.png")
        @strategy.render_svg(svg_path, png_path)
        png_path
      ensure
        FileUtils.rm_f(svg_path.to_s) if svg_path&.exist?
      end

      def render_cell(pdf_path, loc)
        rect = cell_rect(loc)
        png_path = @diff_dir.join(".cache",
                                  "cell-#{loc[:page]}-" \
                                  "#{format('%05.2f', loc[:x])}-" \
                                  "#{format('%05.2f', loc[:y])}.png")
        png_path.dirname.mkpath
        @strategy.render_pdf_region(pdf_path, loc[:page], rect, png_path)
        png_path
      end

      def cell_rect(loc)
        half = DEFAULT_CELL_SIZE / 2
        { x: loc[:x] - half, y: loc[:y] - half,
          w: DEFAULT_CELL_SIZE, h: DEFAULT_CELL_SIZE }
      end

      def write_artifact(result, png_a, png_b)
        dest = @diff_dir.join("#{format_cp(result.codepoint)}.diff.png")
        @strategy.write_diff_artifact(png_a, png_b, dest) || dest
      end

      def format_cp(codepoint)
        "U+#{codepoint.to_s(16).upcase.rjust(4, '0')}"
      end
    end
  end
end
