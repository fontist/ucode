# frozen_string_literal: true

require "thor"

require "ucode/commands"

module Ucode
  # Top-level CLI entry.
  #
  # **Thin Thor**: every method delegates to a `Commands::*Command`
  # class and only formats the result. The Command classes are pure
  # and testable in-process — Thor never holds business logic.
  class Cli < Thor
    package_name "ucode"

    def self.exit_on_failure?
      true
    end

    # ─────────────── version ───────────────
    desc "version", "Print ucode version"
    def version
      puts "ucode #{Ucode::VERSION}"
    end

    # ─────────────── fetch ───────────────
    class Fetch < Thor
      desc "ucd [VERSION]", "Download UCD.zip"
      option :force, type: :boolean, default: false, desc: "Re-download even if cached"
      def ucd(version = nil)
        puts format_result Commands::FetchCommand.new.fetch_ucd(version, force: options[:force])
      end

      desc "unihan [VERSION]", "Download Unihan.zip"
      option :force, type: :boolean, default: false
      def unihan(version = nil)
        puts format_result Commands::FetchCommand.new.fetch_unihan(version, force: options[:force])
      end

      desc "charts [VERSION]", "Download per-block Code Charts PDFs"
      option :force, type: :boolean, default: false
      option :block, type: :array, desc: "Limit to these block ids"
      def charts(version = nil)
        cps = options[:block]&.map { |id| block_id_to_first_cp(id) }&.compact
        puts format_result Commands::FetchCommand.new
          .fetch_charts(version, block_first_cps: cps, force: options[:force])
      end

      private

      def block_id_to_first_cp(id)
        return Integer(id) if id.match?(/\A\d+\z/)

        warn "Warning: --block=#{id.inspect} cannot be resolved to a first codepoint; skipping"
        nil
      end

      def format_result(result)
        JSON.pretty_generate(result)
      end
    end

    desc "fetch", "Download UCD sources"
    subcommand "fetch", Fetch

    # ─────────────── parse ───────────────
    desc "parse [VERSION]", "Stream UCD → output/"
    option :to, type: :string, default: "./output", desc: "Output directory"
    def parse(version = nil)
      result = Commands::ParseCommand.new.call(version, output_root: options[:to])
      puts JSON.pretty_generate(result)
    end

    # ─────────────── glyphs ───────────────
    desc "glyphs [VERSION]", "Extract per-codepoint SVGs from Code Charts PDFs (experimental)"
    long_desc <<~LONG
      EXPERIMENTAL in v0.1. The cell extractor currently includes cell-border
      decorations alongside the actual character outline, so the output is not
      yet suitable for end-user display. Opt in with --include-glyphs to run
      the pipeline anyway; otherwise it returns a skipped payload.
    LONG
    option :to, type: :string, default: "./output"
    option :block, type: :array, desc: "Limit to these block ids"
    option :force, type: :boolean, default: false
    option :monolith, type: :string, default: "CodeCharts.pdf",
                      desc: "Path to CodeCharts.pdf for fallback slicing"
    option :include_glyphs, type: :boolean, default: false,
                            desc: "Opt into the experimental v0.1 pipeline"
    def glyphs(version = nil)
      result = Commands::GlyphsCommand.new.call(
        version,
        output_root: options[:to],
        block_filter: options[:block],
        force: options[:force],
        monolith_path: options[:monolith],
        include_glyphs: options[:include_glyphs],
        warn: $stderr,
      )
      puts JSON.pretty_generate(result)
    end

    # ─────────────── site ───────────────
    class Site < Thor
      desc "init", "Copy the Vitepress scaffold into site/"
      option :to, type: :string, default: "./site"
      def init
        puts JSON.pretty_generate(Commands::SiteCommand.new.init(site_root: options[:to]))
      end

      desc "build", "Regenerate site/.vitepress/config.ts + pages from output/"
      option :from, type: :string, default: "./output", desc: "Dataset root"
      option :to, type: :string, default: "./site", desc: "Site root"
      def build
        puts JSON.pretty_generate(
          Commands::SiteCommand.new.build(output_root: options[:from], site_root: options[:to]),
        )
      end
    end

    desc "site", "Generate the Vitepress site"
    subcommand "site", Site

    # ─────────────── lookup ───────────────
    class Lookup < Thor
      desc "block CODEPOINT", "Block name covering CODEPOINT (integer or 0xNNNN)"
      option :version, type: :string, default: nil
      def block(codepoint)
        cp = parse_cp(codepoint)
        with_db_handling do
          result = Commands::LookupCommand.new.lookup_block(options[:version], codepoint: cp)
          puts "#{format("U+%04X", cp)} → #{result.block || "(unassigned)"}"
        end
      end

      desc "script CODEPOINT", "Script name covering CODEPOINT"
      option :version, type: :string, default: nil
      def script(codepoint)
        cp = parse_cp(codepoint)
        with_db_handling do
          result = Commands::LookupCommand.new.lookup_script(options[:version], codepoint: cp)
          puts "#{format("U+%04X", cp)} → #{result.script || "(none)"}"
        end
      end

      desc "char CODEPOINT", "Block + glyph path for CODEPOINT"
      option :version, type: :string, default: nil
      option :from, type: :string, default: "./output"
      def char(codepoint)
        cp = parse_cp(codepoint)
        with_db_handling do
          result = Commands::LookupCommand.new
            .lookup_char(options[:version], codepoint: cp, output_root: options[:from])
          puts "#{format("U+%04X", cp)} block=#{result.block_id} glyph=#{result.glyph_path}"
        end
      end

      private

      def parse_cp(s)
        Integer(s.gsub(/^U\+/i, ""), 16)
      rescue ArgumentError
        raise Thor::Error, "Invalid codepoint: #{s.inspect} (try '0x0041' or 'U+0041')"
      end

      def with_db_handling
        yield
      rescue Ucode::DatabaseMissingError => e
        version = e.context[:version]
        raise Thor::Error, "No SQLite cache for version #{version.inspect}. " \
                           "Run: ucode build #{version} --to ./output"
      end
    end

    desc "lookup", "Read-only lookups against the SQLite cache"
    subcommand "lookup", Lookup

    # ─────────────── cache ───────────────
    class Cache < Thor
      desc "list", "List cached UCD versions"
      def list
        Commands::CacheCommand.new.list.each { |v| puts v }
      end

      desc "info VERSION", "Show what's cached for VERSION"
      def info(version)
        result = Commands::CacheCommand.new.info(version)
        if result.nil?
          puts "Nothing cached for #{version}"
        else
          puts JSON.pretty_generate(result.to_h)
        end
      end

      desc "remove VERSION", "Remove VERSION from the cache"
      def remove(version)
        ok = Commands::CacheCommand.new.remove(version)
        puts(ok ? "Removed #{version}" : "#{version} not in cache")
      end
    end

    desc "cache", "Inspect and manage the cache"
    subcommand "cache", Cache

    # ─────────────── build ───────────────
    desc "build [VERSION]", "Full pipeline: fetch + parse + (optional) glyphs + site"
    option :to, type: :string, default: "./output"
    option :site, type: :string, default: nil, desc: "Build the site here (skipped if nil)"
    option :monolith, type: :string, default: "CodeCharts.pdf"
    option :force_fetch, type: :boolean, default: false
    option :include_glyphs, type: :boolean, default: false,
                            desc: "Opt into the experimental v0.1 glyph step"
    def build(version = nil)
      result = Commands::BuildCommand.new.call(
        version,
        output_root: options[:to],
        site_root: options[:site],
        monolith_path: options[:monolith],
        force_fetch: options[:force_fetch],
        include_glyphs: options[:include_glyphs],
        warn: $stderr,
      )
      puts JSON.pretty_generate(result)
    end

    # ─────────────── font-coverage ───────────────
    desc "font-coverage FONT [FONT...]", "Audit Unicode 17 block coverage for one or more fonts"
    long_desc <<~LONG
      Each FONT argument is either a fontist formula name (resolved via
      `Fontist::Font.find` then `install`) or `label=/path/to/font.ttf`
      (uses the local file directly). For every font, walks the cmap via
      fontisan and emits per-Unicode-17-block coverage to
      `<to>/font_coverage/<label>.json`.

      Examples:

        ucode font-coverage Lentariso=/tmp/lentariso/TTFs/Lentariso-Re.ttf \\
                             Kedebideri=/tmp/kedebideri/Kedebideri-3.001/Kedebideri-Regular.ttf

        ucode font-coverage Kedebideri  # resolves + installs via fontist
    LONG
    option :to, type: :string, default: "./output"
    option :no_install, type: :boolean, default: false,
                        desc: "Don't auto-install missing fonts via fontist"
    def font_coverage(*fonts)
      raise Thor::Error, "Provide at least one font" if fonts.empty?

      results = Commands::FontCoverageCommand.new.call(
        fonts,
        output_root: options[:to],
        install: !options[:no_install],
      )
      puts JSON.pretty_generate(results.map { |r| result_to_h(r) })
    end

    private

    def result_to_h(result)
      if result.error
        { spec: result.spec, error: result.error }
      else
        {
          spec: result.spec,
          label: result.located.name,
          source: result.located.path.to_s,
          via: result.located.via,
          output_path: result.output_path.to_s,
          complete_blocks: result.complete_blocks,
        }
      end
    end
  end
end
