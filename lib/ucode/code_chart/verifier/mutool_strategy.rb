# frozen_string_literal: true

require "fileutils"
require "pathname"

module Ucode
  module CodeChart
    class Verifier
      # {Strategy} backed by `mutool draw`. Slower than resvg but
      # always available on a system that has the trace pipeline
      # working (mutool is already required elsewhere).
      #
      # Pixel diff: byte-wise comparison of the two rendered PNGs.
      # Crude (real pixel diff needs ChunkyPNG or vips), but
      # sufficient to catch the regression classes the REQ lists:
      # clipped glyphs, missing paths, wrong-cell content,
      # coordinate-flip errors. Returns the percentage of differing
      # bytes — a useful relative signal even when not a true
      # pixel-perfect diff.
      class MutoolStrategy < Strategy
        # @param runner [Ucode::Glyphs::EmbeddedFonts::Mutool::SystemRunner]
        #   injectable for tests
        def initialize(runner: Ucode::Glyphs::EmbeddedFonts::Mutool::SystemRunner.new)
          super()
          @runner = runner
        end

        def available?
          system("which mutool >/dev/null 2>&1")
        end

        def render_svg(svg_path, png_path, scale: 2.0)
          dpi = (72 * scale).round
          @runner.run("mutool", "draw", "-o", png_path.to_s,
                      "-r", dpi.to_s, svg_path.to_s)
          Pathname.new(png_path)
        end

        def render_pdf_region(pdf_path, page, rect, png_path, scale: 2.0)
          dpi = (72 * scale).round
          @runner.run("mutool", "draw", "-o", png_path.to_s,
                      "-r", dpi.to_s,
                      "-R", format_rect(rect, scale),
                      pdf_path.to_s, page.to_s)
          Pathname.new(png_path)
        end

        def diff(png_a, png_b)
          bytes_a = File.binread(png_a)
          bytes_b = File.binread(png_b)
          return 100.0 if bytes_a.bytesize != bytes_b.bytesize

          same = bytes_a.each_byte.with_index.count do |byte, idx|
            byte == bytes_b.getbyte(idx)
          end
          (100.0 * (1.0 - same.to_f / bytes_a.bytesize)).round(2)
        end

        def write_diff_artifact(png_a, png_b, dest)
          data_a = File.binread(png_a)
          data_b = File.binread(png_b)
          Pathname.new(dest).binwrite(data_a + data_b)
          Pathname.new(dest)
        end

        private

        # mutool's -R flag takes a bbox in page coordinates
        # pre-scaled by the DPI factor: `<x0,y0,x1,y1>`.
        def format_rect(rect, scale)
          x0 = (rect[:x] * scale).round
          y0 = (rect[:y] * scale).round
          x1 = x0 + (rect[:w] * scale).round
          y1 = y0 + (rect[:h] * scale).round
          "#{x0},#{y0},#{x1},#{y1}"
        end
      end
    end
  end
end
