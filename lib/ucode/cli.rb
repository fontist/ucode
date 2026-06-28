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

      desc "fonts", "Download specialist Tier 1 fonts (config/specialist_fonts.yml)"
      option :manifest, type: :string,
                        desc: "Override manifest path (default config/specialist_fonts.yml)"
      option :label, type: :string, desc: "Fetch only this font by label"
      option :allow_proprietary, type: :boolean, default: false,
                                 desc: "Permit non-OFL licensed fonts"
      option :dry_run, type: :boolean, default: false,
                       desc: "Plan only; no network or disk writes"
      def fonts
        result = Commands::FetchCommand.new.fetch_fonts(
          manifest_path: options[:manifest],
          only_label: options[:label],
          allow_proprietary: options[:allow_proprietary],
          dry_run: options[:dry_run],
        )
        puts format_fonts_result(result)
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

      def format_fonts_result(result)
        clean = result.merge(results: result[:results].map { |r| r.to_h.compact })
        JSON.pretty_generate(clean)
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

    # ─────────────── audit ───────────────
    class Audit < Thor
      desc "font PATH", "Audit a single font (or fontist formula name)"
      option :label,       type: :string, default: nil,
                           desc: "Output directory name (default: postscript_name)"
      option :unicode_version, type: :string, default: nil
      option :output,      type: :string,  default: "./output"
      option :verbose,     type: :boolean, default: false,
                           desc: "Emit per-codepoint detail chunks"
      option :with_glyphs, type: :boolean, default: false,
                           desc: "Emit per-codepoint SVG chunks (no-op until TODO 20)"
      option :brief,       type: :boolean, default: false,
                           desc: "Cheap-extractor-only mode"
      option :browse,      type: :boolean, default: false,
                           desc: "Also write the self-contained HTML browser"
      option :no_install,  type: :boolean, default: false,
                           desc: "Don't auto-install missing fonts via fontist"
      option :reference_universal_set, type: :string, default: nil,
                                       desc: "Path to universal-set manifest (or 'none'); " \
                                 "default: output/universal_glyph_set/manifest.json " \
                                 "if present, else UCD-only"
      option :universal_set_root, type: :string, default: nil,
                                  desc: "Path to universal-set build root (e.g. " \
                                       "output/universal_glyph_set). Required for " \
                                       "--with-missing-glyph-pages."
      option :with_missing_glyph_pages, type: :boolean, default: false,
                                        desc: "Emit per-block missing-glyph galleries " \
                                              "(requires --browse + --universal-set-root)"
      def font(path)
        reference = Commands::Audit::ReferenceBuilder.build(
          flag: options[:reference_universal_set],
          version: options[:unicode_version],
        )
        result = Commands::Audit::FontCommand.new.call(
          path,
          label: options[:label],
          unicode_version: options[:unicode_version],
          verbose: options[:verbose],
          with_glyphs: options[:with_glyphs],
          brief: options[:brief],
          output_root: options[:output],
          browse: options[:browse],
          install: !options[:no_install],
          reference: reference,
          universal_set_root: options[:universal_set_root],
          with_missing_glyph_pages: options[:with_missing_glyph_pages],
        )
        puts JSON.pretty_generate(result_to_h(result))
      end

      desc "collection PATH", "Audit a TTC/OTC/dfong collection"
      option :font_index,  type: :numeric, default: nil,
                           desc: "Audit only face N (single-face output)"
      option :label,       type: :string,  default: nil
      option :unicode_version, type: :string, default: nil
      option :output,      type: :string,  default: "./output"
      option :verbose,     type: :boolean, default: false
      option :with_glyphs, type: :boolean, default: false
      option :brief,       type: :boolean, default: false
      option :browse,      type: :boolean, default: false
      option :reference_universal_set, type: :string, default: nil,
                                       desc: "Path to universal-set manifest (or 'none')"
      option :universal_set_root, type: :string, default: nil,
                                  desc: "Path to universal-set build root"
      option :with_missing_glyph_pages, type: :boolean, default: false,
                                        desc: "Emit per-block missing-glyph galleries"
      def collection(path)
        reference = Commands::Audit::ReferenceBuilder.build(
          flag: options[:reference_universal_set],
          version: options[:unicode_version],
        )
        result = Commands::Audit::CollectionCommand.new.call(
          path,
          font_index: options[:font_index],
          label: options[:label],
          unicode_version: options[:unicode_version],
          verbose: options[:verbose],
          with_glyphs: options[:with_glyphs],
          brief: options[:brief],
          output_root: options[:output],
          browse: options[:browse],
          reference: reference,
          universal_set_root: options[:universal_set_root],
          with_missing_glyph_pages: options[:with_missing_glyph_pages],
        )
        puts JSON.pretty_generate(result_to_h(result))
      end

      desc "library DIR", "Walk a directory of fonts and audit each"
      option :recursive, type: :boolean, default: false
      option :unicode_version, type: :string, default: nil
      option :output,      type: :string,  default: "./output"
      option :verbose,     type: :boolean, default: false
      option :with_glyphs, type: :boolean, default: false
      option :brief,       type: :boolean, default: false
      option :browse,      type: :boolean, default: false,
                           desc: "Also write the library + face HTML browsers"
      option :reference_universal_set, type: :string, default: nil,
                                       desc: "Path to universal-set manifest (or 'none')"
      option :universal_set_root, type: :string, default: nil,
                                  desc: "Path to universal-set build root"
      option :with_missing_glyph_pages, type: :boolean, default: false,
                                        desc: "Emit per-block missing-glyph galleries"
      def library(dir)
        reference = Commands::Audit::ReferenceBuilder.build(
          flag: options[:reference_universal_set],
          version: options[:unicode_version],
        )
        result = Commands::Audit::LibraryCommand.new.call(
          dir,
          recursive: options[:recursive],
          unicode_version: options[:unicode_version],
          verbose: options[:verbose],
          with_glyphs: options[:with_glyphs],
          brief: options[:brief],
          output_root: options[:output],
          browse: options[:browse],
          reference: reference,
          universal_set_root: options[:universal_set_root],
          with_missing_glyph_pages: options[:with_missing_glyph_pages],
        )
        puts JSON.pretty_generate(result_to_h(result))
      end

      desc "compare LEFT RIGHT", "Diff two audits"
      option :unicode_version, type: :string, default: nil
      option :output,      type: :string, default: nil,
                           desc: "Write text diff to file (default: stdout)"
      def compare(left, right)
        result = Commands::Audit::CompareCommand.new.call(
          left, right,
          unicode_version: options[:unicode_version],
          output_file: options[:output],
        )
        if result.error
          warn "compare failed: #{result.error}"
          exit 1
        elsif options[:output].nil?
          puts result.text
        else
          puts "wrote #{options[:output]}"
        end
      end

      desc "browser", "Regenerate HTML browsers from existing JSON audits"
      option :input,       type: :string,  default: "./output/font_audit"
      option :faces_only,  type: :boolean, default: false
      option :library_only, type: :boolean, default: false
      def browser
        result = Commands::Audit::BrowserCommand.new.call(
          input: options[:input],
          faces_only: options[:faces_only],
          library_only: options[:library_only],
        )
        puts JSON.pretty_generate(result_to_h(result))
      end

      private

      def result_to_h(result)
        return { error: result.error } if result.error

        result.to_h.compact.transform_values do |v|
          v.is_a?(Struct) ? v.to_h : v
        end
      end
    end

    desc "audit", "Audit font coverage against the Unicode baseline"
    subcommand "audit", Audit

    # ─────────────── universal-set ───────────────
    class UniversalSetCmd < Thor
      desc "build [VERSION]", "Materialize the universal glyph set (one SVG per assigned codepoint)"
      option :to, type: :string, default: "./output/universal_glyph_set",
                  desc: "Output directory"
      option :source_config, type: :string, default: nil,
                             desc: "Path to a Tier 1 source config YAML " \
                                   "(default: config/unicode17_universal_glyph_set.yml)"
      option :block, type: :string, default: nil,
                     desc: "Limit the build to one block (canonical underscore form)"
      option :parallel, type: :numeric, default: nil,
                        desc: "Worker pool size (default: Ucode.configuration.parallel_workers)"
      def build(version = nil)
        result = Commands::UniversalSet::BuildCommand.new.call(
          version,
          output_root: options[:to],
          source_config_path: options[:source_config],
          block_filter: options[:block],
          parallel_workers: options[:parallel] || Ucode.configuration.parallel_workers,
        )
        puts JSON.pretty_generate(result)
      rescue Ucode::UniversalSetPreBuildError => e
        warn "pre-build validation failed:"
        warn JSON.pretty_generate(e.context)
        exit 1
      end

      desc "pre-check [VERSION]", "Validate source config + fonts + coverage assertion before a build"
      option :source_config, type: :string, default: nil,
                             desc: "Path to a Tier 1 source config YAML"
      def pre_check(version = nil)
        report = Commands::UniversalSet::PreCheckCommand.new.call(
          version,
          source_config_path: options[:source_config],
        )
        puts JSON.pretty_generate(report.to_h)
      rescue Ucode::UniversalSetPreBuildError => e
        warn "pre-build validation failed:"
        warn JSON.pretty_generate(e.context)
        exit 1
      end

      desc "report [VERSION]", "Emit per-tier / per-block / gaps reports from an existing manifest"
      option :from, type: :string, default: "./output/universal_glyph_set",
                    desc: "Output directory holding manifest.json"
      def report(version = nil)
        result = Commands::UniversalSet::ReportCommand.new.call(
          version,
          output_root: options[:from],
        )
        puts JSON.pretty_generate(result)
      end

      desc "validate [OUTPUT_ROOT]", "Run post-build structural validation on a manifest + glyphs dir"
      option :version, type: :string, default: nil,
                       desc: "Unicode version (stamps the report; defaults to manifest)"
      def validate(output_root = "./output/universal_glyph_set")
        result = Commands::UniversalSet::ValidateCommand.new.call(
          output_root,
          version_intent: options[:version],
        )
        puts JSON.pretty_generate(result)
        exit 1 unless result[:passed]
      end
    end

    desc "universal-set", "Build and inspect the universal glyph set reference"
    subcommand "universal-set", UniversalSetCmd
  end
end
