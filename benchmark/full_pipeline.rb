#!/usr/bin/env ruby
# frozen_string_literal: true

# End-to-end pipeline benchmark for one UCD version.
#
# Times each phase: fetch (ucd/unihan/charts), parse, glyphs, sqlite
# build, site build. Re-runs are resumable — idempotent phases report
# ~0s on warm cache.
#
# Usage:
#   bundle exec ruby benchmark/full_pipeline.rb [version] [--to=path] [--force]
#
# Output: a table of phase → elapsed seconds → output size, printed to
# STDOUT. Designed for `docs/performance.md` capture.

require "benchmark"
require "fileutils"
require "optparse"
require "pathname"

require_relative "../lib/ucode"

version = Ucode.configuration.default_version
output_root = Pathname.new("./tmp/bench_output")
site_root  = Pathname.new("./tmp/bench_site")
force = false

parser = OptionParser.new do |opts|
  opts.banner = "Usage: benchmark/full_pipeline.rb [options]"
  opts.on("--to=PATH", "Output directory (default: ./tmp/bench_output)") { |p| output_root = Pathname.new(p) }
  opts.on("--site=PATH", "Site directory (default: ./tmp/bench_site)") { |p| site_root = Pathname.new(p) }
  opts.on("--force", "Re-download sources even if cached") { force = true }
  opts.on("--version=V", "UCD version (default: #{version})") { |v| version = v }
end
parser.parse!(ARGV)

output_root.mkpath
site_root.mkpath

phases = []

def measure(label)
  elapsed = Benchmark.realtime { yield }
  { phase: label, elapsed: elapsed }
end

puts "ucode full-pipeline benchmark"
puts "  version:     #{version}"
puts "  output_root: #{output_root}"
puts "  site_root:   #{site_root}"
puts "  force:       #{force}"
puts

fetch = Ucode::Commands::FetchCommand.new

phases << measure("fetch_ucd") do
  fetch.fetch_ucd(version, force: force)
end

phases << measure("fetch_unihan") do
  fetch.fetch_unihan(version, force: force)
end

phases << measure("fetch_charts") do
  fetch.fetch_charts(version, force: force)
end

parse_result = nil
phases << measure("parse") do
  parse_result = Ucode::Commands::ParseCommand.new.call(version, output_root: output_root)
end

glyphs_result = nil
phases << measure("glyphs") do
  glyphs_result = Ucode::Commands::GlyphsCommand.new.call(
    version, output_root: output_root,
    monolith_path: "CodeCharts.pdf",
  )
end

sqlite_path = nil
phases << measure("sqlite_build") do
  sqlite_path = Ucode::DbBuilder.build(version)
end

lookup_latency_ms = nil
phases << measure("sqlite_lookup_latency_ms") do
  db = Ucode::Database.open(version)
  iterations = 1000
  elapsed = Benchmark.realtime do
    iterations.times { db.lookup_block(0x0041) }
  end
  db.close
  lookup_latency_ms = (elapsed / iterations) * 1000
end

site_result = nil
phases << measure("site_init") do
  site_result = Ucode::Commands::SiteCommand.new.init(site_root: site_root)
end

phases << measure("site_build") do
  site_result = Ucode::Commands::SiteCommand.new.build(
    output_root: output_root, site_root: site_root,
  )
end

# Reporting
puts format("%-26s  %10s", "phase", "elapsed")
puts "-" * 40
phases.each do |p|
  if p[:phase] == "sqlite_lookup_latency_ms"
    puts format("%-26s  %10.4f", "sqlite_lookup_latency_ms (avg)", lookup_latency_ms)
  else
    puts format("%-26s  %10.3f s", p[:phase], p[:elapsed])
  end
end

puts
puts "Counts:"
puts "  codepoints parsed: #{parse_result[:codepoint_count]}"
puts "  glyphs written:    #{glyphs_result[:written]} (placeholders: #{glyphs_result[:placeholder]})"
puts "  sqlite size:       #{sqlite_path.size} bytes"
puts "  search index:      #{output_root.join('index', 'search.json').size} bytes"

puts
puts "Targets (Unicode 17, modern hardware):"
puts "  cold pipeline < 10 min   warm pipeline < 5 min   lookup < 1 ms"
