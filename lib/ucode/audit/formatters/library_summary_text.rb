# frozen_string_literal: true

module Ucode
  module Audit
    module Formatters
      # Human-readable overview of a {Models::Audit::LibrarySummary}.
      #
      # Lists the per-face rollup counts, aggregate metrics, script
      # coverage matrix, duplicate groups, and license distribution.
      # The full per-face AuditReports are attached to the model; this
      # view only shows the cross-face summaries (use YAML/JSON output
      # for the full per-face data).
      class LibrarySummaryText
        SEPARATOR = "=" * 80
        LIST_LIMIT = 15

        # @param summary [Models::Audit::LibrarySummary]
        def initialize(summary)
          @summary = summary
          @lines = []
          @helper = TextFormatter.new
        end

        # @return [String]
        def render
          render_header
          render_aggregates
          render_script_coverage
          render_duplicates
          render_license_distribution
          @lines.join("\n")
        end

        private

        def render_header
          @lines << Color.bold("LIBRARY SUMMARY")
          @lines << Color.dim(SEPARATOR)
          @lines << "  root:    #{@summary.root_path}"
          @lines << "  files:   #{@summary.total_files}   faces: #{@summary.total_faces}"
          exts = Array(@summary.scanned_extensions)
          @lines << "  formats: #{exts.empty? ? '(none)' : exts.join(', ')}"
        end

        def render_aggregates
          m = @summary.aggregate_metrics || {}
          section("AGGREGATES")
          @lines << "  codepoints:     #{m[:total_codepoints] || 0}"
          @lines << "  glyphs:         #{m[:total_glyphs] || 0}"
          @lines << "  total size:     #{@helper.format_bytes(m[:total_size_bytes] || 0)}"
        end

        def render_script_coverage
          rows = Array(@summary.script_coverage)
          return if rows.empty?

          section("SCRIPT COVERAGE (top #{LIST_LIMIT})")
          rows.first(LIST_LIMIT).each do |row|
            @lines << "  #{row.script}: #{row.face_count} face#{'s' unless row.face_count == 1}"
          end
          if rows.size > LIST_LIMIT
            @lines << "  … (+#{rows.size - LIST_LIMIT} more scripts)"
          end
        end

        def render_duplicates
          groups = Array(@summary.duplicate_groups)
          return if groups.empty?

          section("DUPLICATES (#{groups.size} group#{'s' unless groups.size == 1})")
          groups.first(LIST_LIMIT).each do |group|
            sha = group.source_sha256.to_s
            @lines << "  sha #{sha[0, 12]}:"
            group.files.each { |path| @lines << "    #{path}" }
          end
          if groups.size > LIST_LIMIT
            @lines << "  … (+#{groups.size - LIST_LIMIT} more duplicate groups)"
          end
        end

        def render_license_distribution
          dist = @summary.license_distribution || {}
          return if dist.empty?

          section("LICENSE DISTRIBUTION")
          dist.sort_by { |_url, count| -count }.each do |url, count|
            @lines << "  #{count}  #{url}"
          end
        end

        def section(title)
          @lines << ""
          @lines << Color.bold(title)
        end
      end
    end
  end
end
