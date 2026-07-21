# frozen_string_literal: true

require "pathname"

module Ucode
  module CodeChart
    class Verifier
      # Caches per-page PDF→PNG renders so multiple glyphs on the
      # same page share one `mutool draw` invocation. The Verifier
      # asks for the rendered page; the cache either reuses the
      # existing PNG or renders it on demand.
      #
      # PNG path layout: `<diff_dir>/.cache/page-<N>-<sha>.png`
      # where `<sha>` is a short hash of the PDF path (so two
      # different PDFs with page 1 don't collide).
      class PageRenderCache
        # @param diff_dir [Pathname, String]
        # @param strategy [Strategy]
        def initialize(diff_dir:, strategy:)
          @diff_dir = Pathname.new(diff_dir)
          @strategy = strategy
          @cache = {}
        end

        # @param pdf_path [Pathname, String]
        # @param page [Integer] 1-based page number
        # @param scale [Float]
        # @return [Pathname] the rendered page PNG path
        def render_page(pdf_path, page, scale: 2.0)
          key = [pdf_path.to_s, page, scale]
          return @cache[key] if @cache.key?(key)

          @diff_dir.mkpath
          png = @diff_dir.join("page-#{page}-#{short_hash(pdf_path)}.png")
          unless png.exist?
            @strategy.render_pdf_region(
              pdf_path, page,
              full_page_rect, png,
              scale: scale,
            )
          end
          @cache[key] = png
          png
        end

        private

        # Naive "full page" rect. Per-cell cropping is the
        # strategy's responsibility when the caller passes a
        # specific rect; the cache only handles "give me the whole
        # page so I can derive cell rects from it".
        def full_page_rect
          { x: 0, y: 0, w: 612, h: 792 }
        end

        def short_hash(path)
          require "digest"
          Digest::SHA256.file(path).hexdigest[0, 8]
        end
      end
    end
  end
end
