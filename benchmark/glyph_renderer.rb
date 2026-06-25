#!/usr/bin/env ruby
# frozen_string_literal: true

# Benchmark the available PDF→SVG renderers on representative pages.
#
# Usage:
#   bundle exec ruby benchmark/glyph_renderer.rb [fixture.pdf] [page]
#
# Output is a human-readable table printed to STDOUT. Picks the fastest
# renderer that emits clean SVG paths.
#
# This is a one-shot benchmark script, not library code — keep it
# dependency-light. Run from the project root.

require "benchmark"
require "fileutils"
require "pathname"
require "tmpdir"

require_relative "../lib/ucode"

fixture_path = ARGV[0] || File.expand_path("../spec/fixtures/pdfs/basic_latin.pdf", __dir__)
page_num = (ARGV[1] || 1).to_i

unless File.exist?(fixture_path)
  abort "fixture PDF not found: #{fixture_path} (pass path as first arg)"
end

renderers = Ucode::Glyphs::PageRenderer.available
if renderers.empty?
  abort "no PDF→SVG renderer found on PATH (looked for: " \
        "#{Ucode::Glyphs::PageRenderer.all.map(&:binary_name).join(', ')})"
end

puts "Benchmarking #{renderers.size} renderer(s) on #{fixture_path} page #{page_num}"
puts

results = Dir.mktmpdir("ucode-bench") do |tmp|
  tmp = Pathname.new(tmp)
  renderers.map do |renderer|
    out = tmp.join("#{renderer.renderer_name}.svg")
    elapsed = Benchmark.realtime do
      renderer.render(fixture_path, page_num, out)
    end
    body = out.read
    {
      renderer: renderer.renderer_name,
      elapsed: elapsed,
      bytes: body.bytesize,
      path_count: body.scan(/<path\b/).size,
      has_raster: body.match?(/<image\b/),
    }
  rescue Ucode::PdfRenderError => e
    {
      renderer: renderer.renderer_name,
      error: e.message,
      elapsed: nil,
    }
  end
end

widths = %i[renderer elapsed bytes path_count has_raster].map { |k| k.to_s.length }
puts format("%-#{widths[0]}s  %#{widths[1]}s  %#{widths[2]}s  %#{widths[3]}s  %s",
            "renderer", "sec", "bytes", "paths", "raster?")
puts "-" * 60
results.each do |r|
  if r[:error]
    puts format("%-#{widths[0]}s  ERROR: %s", r[:renderer], r[:error])
    next
  end

  puts format("%-#{widths[0]}s  %#{widths[1]}.3f  %#{widths[2]}d  %#{widths[3]}d  %s",
              r[:renderer], r[:elapsed], r[:bytes], r[:path_count], r[:has_raster])
end

clean = results.reject { |r| r[:error] || r[:has_raster] }
if clean.any?
  fastest = clean.min_by { |r| r[:elapsed] }
  puts
  puts "Recommended: :#{fastest[:renderer]} " \
        "(#{format('%.3f', fastest[:elapsed])}s, #{fastest[:path_count]} paths)"
  puts "Set via:  Ucode.configure { |c| c.pdf_renderer = :#{fastest[:renderer]} }"
else
  puts
  puts "No renderer produced clean vector SVG output."
end
