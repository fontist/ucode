# frozen_string_literal: true

require "thor"

require "ucode/commands"
require "ucode/code_chart"
require "ucode/version_resolver"

module Ucode
  # Top-level CLI entry.
  #
  # **Thin Thor**: every method delegates to a `Commands::*Command`
  # class and only formats the result. The Command classes are pure
  # and testable in-process — Thor never holds business logic.
  #
  # **Version resolution lives here** — each top-level command resolves
  # the user-supplied intent (nil / :default / :latest / explicit string)
  # exactly once via `VersionResolver.resolve` and threads the resolved
  # string into the dispatched Command. Sub-commands never re-resolve.
  # See Candidate 4 of the 2026-06-29 architecture review.
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
        puts format_result Commands::FetchCommand.new.fetch_ucd(
          VersionResolver.resolve(version), force: options[:force],
        )
      end

      desc "unihan [VERSION]", "Download Unihan.zip"
      option :force, type: :boolean, default: false
      def unihan(version = nil)
        puts format_result Commands::FetchCommand.new.fetch_unihan(
          VersionResolver.resolve(version), force: options[:force],
        )
      end

      desc "charts [VERSION]", "Download per-block Code Charts PDFs"
      option :force, type: :boolean, default: false
      option :block, type: :array, desc: "Limit to these block ids"
      def charts(version = nil)
        cps = options[:block]&.map { |id| block_id_to_first_cp(id) }&.compact
        puts format_result Commands::FetchCommand.new
          .fetch_charts(VersionResolver.resolve(version),
                        block_first_cps: cps, force: options[:force])
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
      result = Commands::ParseCommand.new.call(
        VersionResolver.resolve(version), output_root: options[:to],
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

    # ─────────────── code-chart ───────────────
    # Extract per-codepoint SVG glyphs from a Unicode Code Charts PDF.
    # One folder per block under --to, with <U+XXXX>.svg + .json pairs.
    class CodeChartCmd < Thor
      desc "fetch --block BLOCK [VERSION]", "Download the Code Charts PDF for a block"
      option :block, type: :string, required: true,
                     desc: "Block identifier (e.g. Sidetic, Basic_Latin)"
      def fetch(version = nil)
        with_codechart_errors do
          block_first_cp = resolve_block_first_cp!(options[:block], version)
          result = Commands::FetchCommand.new.fetch_charts(
            VersionResolver.resolve(version),
            block_first_cps: [block_first_cp],
          )
          puts JSON.pretty_generate(result)
        end
      end

      desc "extract --block BLOCK --to DIR [VERSION]",
           "Extract per-codepoint SVG + provenance sidecars from a Code Charts PDF"
      option :block, type: :string, required: false,
                     desc: "Block identifier (required unless --missing-from is given)"
      option :to, type: :string, required: true,
                  desc: "Output directory (will contain <block_id>/<U+XXXX>.svg + .json)"
      option :verify, type: :boolean, default: false,
                      desc: "Run pixel-diff verification on every extracted glyph"
      option :missing_from, type: :string, default: nil,
                            desc: "Path to essenfont manifest; extracts only the gaps"
      def extract(version = nil)
        with_codechart_errors do
          version_str = VersionResolver.resolve(version)

          if options[:missing_from]
            run_batch_extract(version: version_str,
                              manifest_path: options[:missing_from],
                              to: options[:to], verify: options[:verify])
          else
            raise Thor::Error, "--block is required when --missing-from is not set" unless options[:block]

            run_single_block_extract(version: version_str,
                                     block_id: options[:block],
                                     to: options[:to], verify: options[:verify])
          end
        end
      end

      desc "list", "List cached Code Charts PDFs under the version's cache"
      option :coverage_gap_only, type: :boolean, default: false,
                                 desc: "Only list blocks with OFL coverage gaps"
      option :coverage, type: :string, default: nil,
                        desc: "Path to a coverage YAML (required with --coverage-gap-only)"
      def list
        with_codechart_errors do
          if options[:coverage_gap_only]
            run_coverage_gap_list
          else
            run_simple_list
          end
        end
      end

      private

      # Resolve a block name to its first codepoint via the cached
      # Blocks.txt. Raises {Ucode::UnknownBlockError} on miss.
      def resolve_block!(block_id, version)
        blocks_txt = Ucode::Cache.ucd_dir(VersionResolver.resolve(version)).join("Blocks.txt")
        Ucode::Parsers::Blocks.find_by_id!(blocks_txt, block_id)
      end

      def resolve_block_first_cp!(block_id, version)
        resolve_block!(block_id, version).range_first
      end

      def run_single_block_extract(version:, block_id:, to:, verify:)
        block = resolve_block!(block_id, version)
        fetcher = Ucode::CodeChart::Fetcher.new(version: version)
        pdf_path = fetcher.fetch(block: block)

        writer = Ucode::CodeChart::Writer.new(
          output_root: Pathname.new(to),
          pdf_path: pdf_path,
          ucd_version: version,
        )
        summary = writer.write(block)

        result = { **summary.to_h.compact }
        if verify
          result[:verification] = verify_block(block: block, pdf_path: pdf_path,
                                               output_root: Pathname.new(to))
        end
        puts JSON.pretty_generate(result)
      end

      def run_batch_extract(version:, manifest_path:, to:, verify:)
        manifest = Ucode::CodeChart::GapAnalyzer::EssenfontManifest.new(manifest_path)
        analyzer = Ucode::CodeChart::GapAnalyzer::Analyzer.new(
          manifest: manifest,
          blocks: load_all_blocks(version),
        )
        fetcher = Ucode::CodeChart::Fetcher.new(version: version)
        runner = Ucode::CodeChart::BatchRunner.new(
          output_root: Pathname.new(to), ucd_version: version,
          fetcher: fetcher,
        )
        aggregate = runner.run(gap_analyzer: analyzer,
                               blocks: load_all_blocks(version))
        result = aggregate.to_h
        result[:verification] = verify_aggregate(output_root: Pathname.new(to)) if verify
        puts JSON.pretty_generate(result.compact)
      end

      # Load all blocks from the cached Blocks.txt as a {block_id => Block} map.
      def load_all_blocks(version)
        blocks_txt = Ucode::Cache.ucd_dir(version).join("Blocks.txt")
        Ucode::Parsers::Blocks.each_record(blocks_txt).to_h do |b|
          [b.id, b]
        end
      end

      # Pixel-diff verification after single-block extract. Returns
      # a tally of Pass/Fail/Skipped counts + artifact paths for Fail.
      def verify_block(block:, pdf_path:, output_root:)
        verifier = Ucode::CodeChart::Verifier.new(diff_dir: output_root.join(".verify"))
        return { status: "skipped", reason: "no verifier strategy" } unless verifier.available?

        block_dir = output_root.join(block.id)
        tallies = { passed: 0, failed: 0, skipped: 0, failures: [] }
        Dir.glob(block_dir.join("U+*.svg")).each do |svg_path|
          cp = parse_cp_from_path(svg_path)
          next unless cp

          extractor_result = build_extractor_result_for_verification(block_dir, svg_path, cp)
          result = verifier.verify(extractor_result, pdf_path: pdf_path)
          update_tally(tallies, result)
        end
        tallies
      end

      def verify_aggregate(output_root:, **_kwargs)
        verifier = Ucode::CodeChart::Verifier.new(diff_dir: output_root.join(".verify"))
        return { status: "skipped", reason: "no verifier strategy" } unless verifier.available?

        tallies = { passed: 0, failed: 0, skipped: 0, failures: [] }
        Dir.glob(output_root.join("*", "U+*.svg")).each do |svg_path|
          cp = parse_cp_from_path(svg_path)
          next unless cp

          block_id = Pathname.new(svg_path).dirname.basename.to_s
          sidecar = Pathname.new(svg_path).sub_ext(".json")
          next unless sidecar.exist?

          data = JSON.parse(sidecar.read)
          pdf_path = Pathname.new(Ucode::Cache.pdfs_dir(data["ucd_version"])
                                  .join("U#{block_first_cp_hex(block_id)}.pdf"))
          next unless pdf_path.exist?

          extractor_result = build_extractor_result_for_verification(
            Pathname.new(svg_path).dirname, svg_path, cp
          )
          result = verifier.verify(extractor_result, pdf_path: pdf_path)
          update_tally(tallies, result)
        end
        tallies
      end

      def parse_cp_from_path(svg_path)
        basename = File.basename(svg_path, ".svg")
        return nil unless basename.start_with?("U+")

        basename.sub("U+", "").to_i(16)
      end

      def block_first_cp_hex(block_id)
        # Block IDs use underscored names but PDFs are keyed by first
        # codepoint hex. Resolve via Blocks.txt on disk.
        blocks_txt = Ucode::Cache.ucd_dir(VersionResolver.resolve(nil)).join("Blocks.txt")
        block = Ucode::Parsers::Blocks.find_by_id!(blocks_txt, block_id)
        block.range_first.to_s(16).upcase.rjust(4, "0")
      end

      def build_extractor_result_for_verification(_block_dir, svg_path, codepoint)
        sidecar = Pathname.new(svg_path).sub_ext(".json")
        data = sidecar.exist? ? JSON.parse(sidecar.read) : {}
        # sidecar JSON has string-keyed source_cell; restore symbol
        # keys so the Verifier's [:x] / [:y] lookup works.
        source_cell = (data["source_cell"] || {}).transform_keys(&:to_sym)
        Ucode::CodeChart::Extractor::Result.new(
          codepoint: codepoint,
          svg: File.read(svg_path),
          tier: :pillar1,
          provenance: data["extractor_version"] || "verify",
          base_font: data["base_font"],
          gid: data["gid"],
          source_page: data["source_page"],
          source_cell: source_cell,
        )
      end

      def update_tally(tally, result)
        case result
        when Ucode::CodeChart::Verifier::Result::Pass
          tally[:passed] += 1
        when Ucode::CodeChart::Verifier::Result::Fail
          tally[:failed] += 1
          tally[:failures] << { codepoint: result.codepoint,
                                percent: result.percent,
                                diff_path: result.diff_path.to_s }
        when Ucode::CodeChart::Verifier::Result::Skipped
          tally[:skipped] += 1
        end
      end

      def run_simple_list
        version = VersionResolver.resolve(nil)
        pdfs_dir = Ucode::Cache.pdfs_dir(version)
        files = pdfs_dir.exist? ? pdfs_dir.children.sort : []
        if files.empty?
          puts "(no cached Code Charts PDFs)"
          return
        end
        files.each do |f|
          puts f.basename
        end
      end

      def run_coverage_gap_list
        coverage_path = options[:coverage]
        raise Thor::Error, "--coverage <path.yml> is required with --coverage-gap-only" unless coverage_path

        version = VersionResolver.resolve(nil)
        blocks = load_all_blocks(version)
        index = Ucode::CodeChart::CoverageGapIndex.from_yaml(coverage_path, blocks: blocks)
        gaps = index.gap_blocks
        if gaps.empty?
          puts "(no coverage gaps)"
          return
        end
        printf "%<block_id>-40s %<assigned>10s %<covered>10s %<missing>10s\n",
               block_id: "block_id", assigned: "assigned",
               covered: "covered", missing: "missing"
        gaps.each do |gap|
          block = blocks[gap.block_id]
          assigned = block.range_last - block.range_first + 1
          covered = assigned - gap.size
          printf "%<block_id>-40s %<assigned>10d %<covered>10d %<missing>10d\n",
                 block_id: gap.block_id, assigned: assigned,
                 covered: covered, missing: gap.size
        end
      end

      # Convert semantic Ucode errors into Thor errors so Thor's
      # dispatch prints the message cleanly instead of a stack trace.
      # Thor's `start` rescues only `Thor::Error`; without this bridge,
      # any `Ucode::Error` subclass propagates as an uncaught exception.
      def with_codechart_errors
        yield
      rescue Ucode::Error => e
        raise Thor::Error, e.message
      end
    end

    # Register the subcommand under the underscored method name
    # (`code_chart`). Thor's `normalize_command_name` converts the
    # user's hyphenated form (`code-chart`) to the underscored form
    # before lookup, so `ucode code-chart <cmd>` dispatches correctly.
    # `desc` first registers the method as a Thor command so the
    # dispatch table has an entry; `subcommand` then attaches the
    # CodeChartCmd class to it.
    desc "code_chart <command>", "Extract SVG glyphs from Unicode Code Charts PDFs"
    subcommand "code_chart", CodeChartCmd

    # ─────────────── lookup ───────────────
    class Lookup < Thor
      desc "block CODEPOINT", "Block name covering CODEPOINT (integer or 0xNNNN)"
      option :version, type: :string, default: nil
      def block(codepoint)
        cp = parse_cp(codepoint)
        with_db_handling do
          result = Commands::LookupCommand.new.lookup_block(
            VersionResolver.resolve(options[:version]), codepoint: cp,
          )
          puts "#{format("U+%04X", cp)} → #{result.block || "(unassigned)"}"
        end
      end

      desc "script CODEPOINT", "Script name covering CODEPOINT"
      option :version, type: :string, default: nil
      def script(codepoint)
        cp = parse_cp(codepoint)
        with_db_handling do
          result = Commands::LookupCommand.new.lookup_script(
            VersionResolver.resolve(options[:version]), codepoint: cp,
          )
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
            .lookup_char(VersionResolver.resolve(options[:version]),
                         codepoint: cp, output_root: options[:from])
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
    desc "build [VERSION]", "Full pipeline: fetch + parse + site"
    option :to, type: :string, default: "./output"
    option :site, type: :string, default: nil, desc: "Build the site here (skipped if nil)"
    option :force_fetch, type: :boolean, default: false
    def build(version = nil)
      result = Commands::BuildCommand.new.call(
        version,
        output_root: options[:to],
        site_root: options[:site],
        force_fetch: options[:force_fetch],
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
        reference = Ucode::Audit::ReferenceFactory.build_from_cli(
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
        reference = Ucode::Audit::ReferenceFactory.build_from_cli(
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
        reference = Ucode::Audit::ReferenceFactory.build_from_cli(
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
          VersionResolver.resolve(version),
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
          VersionResolver.resolve(version),
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
          VersionResolver.resolve(version),
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
          version: options[:version] && VersionResolver.resolve(options[:version]),
        )
        puts JSON.pretty_generate(result)
        exit 1 unless result[:passed]
      end
    end

    desc "universal-set", "Build and inspect the universal glyph set reference"
    subcommand "universal-set", UniversalSetCmd

    # ─────────────── release ───────────────
    desc "release", "Assemble the fontist.org release tree from per-formula audits"
    long_desc <<~LONG
      Walks a directory of per-formula font subdirectories and produces
      the fontist.org-consumable release tree at
      `<output>/font_audit_release/`. The release tree contains:

        audit/<slug>/<postscript_name>/  — per-face audit subtrees
        universal_glyph_set/             — pre-staged universal set
        library.json                     — formula + face card index
        manifest.json                    — versions, sha256s, totals

      The universal-set directory is NOT copied by this command; the
      CI collector is expected to pre-stage it under
      `<output>/font_audit_release/universal_glyph_set/`.
    LONG
    option :from, type: :string, required: true,
                  desc: "Directory of per-formula font subdirectories"
    option :output, type: :string, default: "./output",
                    desc: "Parent of the release root"
    option :universal_set, type: :string, default: nil,
                           desc: "Path to the universal_glyph_set directory " \
                                 "(default: <release_root>/universal_glyph_set)"
    option :unicode_version, type: :string, default: nil
    option :brief, type: :boolean, default: false
    option :browse, type: :boolean, default: true,
                    desc: "Also write per-face HTML browsers + missing-glyph pages"
    option :source_config_sha256, type: :string, default: nil,
                                  desc: "sha256 of the Tier 1 source-config YAML"
    option :reference_universal_set, type: :string, default: nil,
                                     desc: "Path to universal-set manifest (or 'none') " \
                                           "for the per-face coverage reference"
    def release
      reference = Ucode::Audit::ReferenceFactory.build_from_cli(
        flag: options[:reference_universal_set],
        version: options[:unicode_version],
      )
      result = Commands::ReleaseCommand.new.call(
        from: options[:from],
        output_root: options[:output],
        universal_set_root: options[:universal_set],
        unicode_version: options[:unicode_version],
        brief: options[:brief],
        browse: options[:browse],
        source_config_sha256: options[:source_config_sha256],
        reference: reference,
      )
      puts JSON.pretty_generate(result_to_h(result))
    end

    # ─────────────── block-feed ───────────────
    desc "block-feed", "Emit per-block Unicode data feed from ucode output"
    long_desc <<~LONG
      Translates ucode's canonical output tree into a compact per-block
      Unicode data feed:

        <target>/unicode-blocks.json
        <target>/unicode-version.json
        <target>/unicode/blocks/<slug>.json

      Each per-block file contains the codepoints in that block with
      their compact metadata (name, general category, script, combining
      class, bidi class, mirrored flag). Block slugs are derived from
      the block name via the standard slug algorithm.
    LONG
    option :ucode_output, type: :string, default: "./output",
                          desc: "ucode's output/ directory"
    option :target, type: :string, default: "./output/block-feed",
                    desc: "Target directory for emitted files"
    option :unicode_version, type: :string, default: nil,
                             desc: "UCD version stamp (default: from manifest)"
    def block_feed
      result = Commands::BlockFeedCommand.new.call(
        ucode_output_root: options[:ucode_output],
        block_feed_output_root: options[:target],
        unicode_version: options[:unicode_version],
      )
      puts JSON.pretty_generate(result.to_h)
    end

    desc "emit-metadata [VERSION]", "Generate frozen Ruby metadata module from UCD data"
    option :gem_root, type: :string, default: nil,
                      desc: "Gem root for output path (default: auto-detect)"
    def emit_metadata(version = nil)
      version_str = VersionResolver.resolve(version)
      result = Commands::EmitMetadataCommand.new.call(
        version_str,
        gem_root: options[:gem_root],
      )
      puts JSON.pretty_generate(result)
    end

    private

    def result_to_h(result)
      return { error: result.error } if result.error

      result.to_h.compact.transform_values do |v|
        v.is_a?(Struct) ? v.to_h : v
      end
    end
  end
end
