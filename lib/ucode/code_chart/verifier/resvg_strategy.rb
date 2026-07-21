# frozen_string_literal: true

require "fileutils"
require "pathname"

module Ucode
  module CodeChart
    class Verifier
      # {Strategy} backed by the `resvg` CLI (`resvg --help`). Preferred
      # over {MutoolStrategy} for accuracy and speed when available —
      # resvg is purpose-built for SVG rendering and produces
      # pixel-stable output across platforms.
      #
      # Same byte-wise diff fallback as {MutoolStrategy}. PNG output
      # is normalized via resvg's `--quantize 8` to reduce byte-level
      # noise across renderer versions.
      class ResvgStrategy < Strategy
        # @param runner [Ucode::Glyphs::EmbeddedFonts::Mutool::SystemRunner]
        #   injectable for tests
        def initialize(runner: Ucode::Glyphs::EmbeddedFonts::Mutool::SystemRunner.new)
          super()
          @runner = runner
        end

        def available?
          system("which resvg >/dev/null 2>&1")
        end

        def render_svg(svg_path, png_path, scale: 2.0)
          width = (1000 * scale).round
          @runner.run("resvg", "-w", width.to_s,
                      "--quantize", "8",
                      svg_path.to_s, png_path.to_s)
          Pathname.new(png_path)
        end

        def render_pdf_region(pdf_path, page, _rect, png_path, scale: 2.0)
          # resvg doesn't render PDFs; we rely on mutool to first
          # convert the page region to SVG, then resvg to PNG. Two
          # subprocess hops, but reuses each tool's strength.
          intermediate = Pathname.new("#{png_path}.svg")
          dpi = (72 * scale).round
          @runner.run("mutool", "draw", "-F", "svg", "-o", intermediate.to_s,
                      "-r", dpi.to_s, pdf_path.to_s, page.to_s)
          @runner.run("resvg", "--quantize", "8",
                      intermediate.to_s, png_path.to_s)
          FileUtils.rm_f(intermediate.to_s)
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
      end
    end
  end
end
