# frozen_string_literal: true

module Ucode
  module Audit
    module Formatters
      # Human-readable, sectioned view of an {Models::Audit::AuditReport}.
      #
      # The text formatter is the default output for `ucode audit`. Every
      # section is nil-safe so the same renderer covers full OpenType /
      # TrueType faces, Type 1 fonts (no OS/2, no metrics, no layout),
      # and partial reports where the UCD baseline could not be resolved.
      #
      # ucode deltas vs fontisan's AuditTextRenderer:
      #
      # - Reads `report.baseline.unicode_version` instead of `ucd_version`.
      # - Renders `report.scripts` (ScriptSummary[]) as a coverage table.
      # - Renders `report.blocks` (BlockSummary[]) with explicit status
      #   and coverage_percent columns.
      # - Adds `plane_summaries` and `discrepancies` sections (no
      #   fontisan equivalent).
      # - Drops CLDR language coverage (out of scope).
      # - Honors `ENV["NO_COLOR"]` via {Color}.
      class AuditText
        SEPARATOR = "=" * 80
        LIST_LIMIT = 10

        # Map OS/2 width class → human label.
        WIDTH_NAMES = {
          1 => "Ultra-condensed", 2 => "Extra-condensed", 3 => "Condensed",
          4 => "Semi-condensed",  5 => "Medium (normal)", 6 => "Semi-expanded",
          7 => "Expanded",        8 => "Extra-expanded",  9 => "Ultra-expanded"
        }.freeze

        # @param report [Models::Audit::AuditReport]
        def initialize(report)
          @report = report
          @lines = []
          @helper = TextFormatter.new
        end

        # @return [String]
        def render
          render_header
          render_identity
          render_style
          render_metrics
          render_coverage
          render_planes
          render_blocks
          render_scripts
          render_licensing
          render_hinting
          render_color
          render_variation
          render_opentype_layout
          render_discrepancies
          render_warnings
          @lines.join("\n")
        end

        private

        def render_header
          @lines << Color.bold(@report.postscript_name || @report.family_name || "(unknown)")
          @lines << Color.dim(SEPARATOR)
          @lines << "  generated_at:    #{@report.generated_at}"
          @lines << "  ucode:           #{@report.ucode_version}"
          @lines << "  source_sha256:   #{@report.source_sha256}"
          @lines << "  source_file:     #{@report.source_file}"
          @lines << "  source_format:   #{@report.source_format || '(unknown)'}"
          @lines << "  layout:          #{layout_descriptor}"
        end

        def layout_descriptor
          if @report.num_fonts_in_source.nil? || @report.num_fonts_in_source <= 1
            "single face (1/1)"
          else
            format("collection face (%<idx>d/%<total>d)",
                   idx: (@report.font_index || 0) + 1,
                   total: @report.num_fonts_in_source)
          end
        end

        def render_identity
          section("IDENTITY")
          @lines << @helper.row("Family",     @report.family_name)
          @lines << @helper.row("Subfamily",  @report.subfamily_name)
          @lines << @helper.row("Full name",  @report.full_name)
          @lines << @helper.row("PostScript", @report.postscript_name)
          @lines << @helper.row("Version",    @report.version)
          @lines << @helper.row("Revision",   @report.font_revision)
          @lines.compact!
        end

        def render_style
          section("STYLE")
          @lines << @helper.row("Weight class", weight_descriptor)
          @lines << @helper.row("Width class",  width_descriptor)
          @lines << @helper.row("Bold",         yes_no(@report.bold))
          @lines << @helper.row("Italic",       yes_no(@report.italic))
          @lines << @helper.row("PANOSE",       @report.panose)
          @lines.compact!
        end

        def render_metrics
          return unless @report.metrics

          m = @report.metrics
          section("METRICS")
          @lines << @helper.row("unitsPerEm", m.units_per_em)
          if m.hhea_ascent
            @lines << @helper.row("hhea",
                                  "ascent: #{m.hhea_ascent} / descent: #{m.hhea_descent} / line gap: #{m.hhea_line_gap}")
          end
          if m.typo_ascender
            @lines << @helper.row("OS/2 typo",
                                  "ascent: #{m.typo_ascender} / descent: #{m.typo_descender} / line gap: #{m.typo_line_gap}")
          end
          if m.win_ascent
            @lines << @helper.row("OS/2 win",
                                  "ascent: #{m.win_ascent} / descent: #{m.win_descent}")
          end
          @lines << @helper.row("x-height", m.x_height)
          @lines << @helper.row("cap height", m.cap_height)
          if m.bbox_x_min || m.bbox_x_max
            @lines << @helper.row("bbox", "(#{m.bbox_x_min}, #{m.bbox_y_min}) → (#{m.bbox_x_max}, #{m.bbox_y_max})")
          end
          @lines << @helper.row("metrics consistent?", yes_no(m.metrics_consistent?))
          @lines.compact!
        end

        def render_coverage
          section("COVERAGE")
          @lines << @helper.row("Codepoints", @report.total_codepoints)
          @lines << @helper.row("Glyphs",     @report.total_glyphs)
          unless Array(@report.cmap_subtables).empty?
            @lines << @helper.row("cmap subtables", Array(@report.cmap_subtables).join(", "))
          end
          @lines << @helper.row("Ranges (top #{LIST_LIMIT})",
                                @helper.truncate_ranges(@report.codepoint_ranges))
          @lines << @helper.row("Baseline", baseline_descriptor)
          @lines.compact!
        end

        def baseline_descriptor
          v = @report.baseline&.unicode_version
          v ? "Unicode #{v} (#{@report.baseline.source})" : "(unresolved)"
        end

        def render_planes
          planes = Array(@report.plane_summaries)
          return if planes.empty?

          section("PLANE ROLLUP")
          planes.first(LIST_LIMIT).each do |p|
            @lines << format("  Plane %<plane>-2d  %<covered>d / %<assigned>d  (%<pct>s%%)",
                             plane: p.plane, covered: p.covered_total,
                             assigned: p.assigned_total,
                             pct: format_percent(p.coverage_percent))
          end
          if planes.size > LIST_LIMIT
            @lines << "  … (+#{planes.size - LIST_LIMIT} more planes)"
          end
        end

        def render_blocks
          blocks = Array(@report.blocks)
          return if blocks.empty?

          section(blocks_header(blocks))
          blocks.sort_by { |b| -(b.coverage_percent || 0) }.first(LIST_LIMIT).each do |block|
            @lines << format_block_row(block)
          end
          return unless blocks.size > LIST_LIMIT

          @lines << "  … (+#{blocks.size - LIST_LIMIT} more blocks; see report JSON for the full list)"
        end

        def blocks_header(blocks)
          complete = blocks.count { |b| b.status == Models::Audit::BlockSummary::STATUS_COMPLETE }
          partial  = blocks.count { |b| b.status == Models::Audit::BlockSummary::STATUS_PARTIAL }
          "UNICODE BLOCKS (#{blocks.size} touched: #{complete} complete, #{partial} partial, top #{LIST_LIMIT} by fill)"
        end

        def format_block_row(block)
          format("  %<name>-40s %<range>s  %<covered>d/%<total>d  (%<pct>s%%, %<status>s)",
                 name: "#{block.name}:",
                 range: block.range,
                 covered: block.covered_count,
                 total: block.total_assigned,
                 pct: format_percent(block.coverage_percent),
                 status: block.status)
        end

        def render_scripts
          scripts = Array(@report.scripts)
          return if scripts.empty?

          section("UNICODE SCRIPTS (#{scripts.size} touched, top #{LIST_LIMIT} by coverage)")
          scripts.sort_by { |s| -(s.coverage_percent || 0) }.first(LIST_LIMIT).each do |script|
            label = "#{script.script_code} (#{script.script_name}):"
            @lines << format("  %<name>-25s %<covered>d/%<total>d  (%<pct>s%%, %<status>s)",
                             name: label,
                             covered: script.covered_total,
                             total: script.assigned_total,
                             pct: format_percent(script.coverage_percent),
                             status: script.status)
          end
        end

        def render_licensing
          return unless @report.licensing

          l = @report.licensing
          section("LICENSING")
          @lines << @helper.row("Copyright",    l.copyright)
          @lines << @helper.row("Trademark",    l.trademark)
          @lines << @helper.row("Manufacturer", l.manufacturer)
          @lines << @helper.row("Designer",     l.designer)
          @lines << @helper.row("License",      l.license_description)
          @lines << @helper.row("License URL",  l.license_url)
          @lines << @helper.row("Vendor URL",   l.vendor_url)
          @lines << @helper.row("Designer URL", l.designer_url)
          @lines << @helper.row("Vendor ID",    l.vendor_id)
          @lines << @helper.row("Embedding",    l.embedding_type)
          @lines.compact!
        end

        def render_hinting
          return unless @report.hinting

          h = @report.hinting
          section("HINTING")
          @lines << @helper.row("Format", h.hinting_format || (h.is_unhinted ? "unhinted" : "unknown"))
          @lines << @helper.row("fpgm",   instruction_line(h.has_fpgm, h.fpgm_instruction_count))
          @lines << @helper.row("prep",   instruction_line(h.has_prep, h.prep_instruction_count))
          @lines << @helper.row("cvt",    cvt_line(h))
          @lines << @helper.row("gasp",   gasp_line(h))
          @lines << @helper.row("CFF hints", h.cff_hint_count)
          @lines.compact!
        end

        def render_color
          c = @report.color_capabilities
          return unless c
          return if Array(c.color_formats).empty?

          section("COLOR")
          @lines << @helper.row("Color formats", Array(c.color_formats).join(", "))
          append_color_rows(c)
          @lines.compact!
        end

        def append_color_rows(c)
          color_rows(c).each { |row| @lines << row }
        end

        def color_rows(c)
          [].tap do |rows|
            rows << colr_row(c) if c.has_colr
            rows << cpal_row(c) if c.has_cpal
            rows.concat(count_rows(c))
          end
        end

        # Returns rows for color formats that surface a strike/document count.
        # Each entry is gated by both presence flag and non-nil count.
        def count_rows(c)
          [].tap do |rows|
            rows << @helper.row("SVG documents", c.svg_document_count) if c.has_svg && c.svg_document_count
            rows << @helper.row("CBDT strikes", c.cbdt_strike_count) if c.has_cbdt && c.cbdt_strike_count
            rows << @helper.row("sbix strikes", c.sbix_strike_count) if c.has_sbix && c.sbix_strike_count
          end
        end

        def colr_row(c)
          @helper.row("COLR",
                      "v#{c.colr_version}, #{c.colr_base_glyph_count} base glyphs, #{c.colr_layer_count} layers")
        end

        def cpal_row(c)
          @helper.row("CPAL", "palettes: #{c.cpal_palette_count}, colors: #{c.cpal_color_count}")
        end

        def render_variation
          v = @report.variation
          section("VARIABLE FONT")
          if v.nil? || Array(v.axes).empty?
            @lines << "  (not variable)"
            return
          end

          v.axes.each do |axis|
            @lines << @helper.row(axis.tag,
                                  format("%<min>s .. %<max>s  default %<default>s",
                                         min: axis.min_value, max: axis.max_value,
                                         default: axis.default_value))
          end
          return if Array(v.named_instances).empty?

          @lines << "  Named instances:"
          v.named_instances.first(LIST_LIMIT).each do |inst|
            @lines << "    #{inst.postscript_name || inst.subfamily_name}: #{inst.coordinates}"
          end
        end

        def render_opentype_layout
          return unless @report.opentype_layout

          l = @report.opentype_layout
          section("OPENTYPE LAYOUT")
          @lines << @helper.row("GSUB", yes_no(l.has_gsub))
          @lines << @helper.row("GPOS", yes_no(l.has_gpos))
          @lines << @helper.row("Scripts (#{Array(l.scripts).size})",
                                @helper.truncate_list(l.scripts))
          @lines << @helper.row("Features (#{Array(l.features).size})",
                                @helper.truncate_list(l.features))
          @lines.compact!
        end

        def render_discrepancies
          discrepancies = Array(@report.discrepancies)
          section("DISCREPANCIES (#{discrepancies.size})")
          if discrepancies.empty?
            @lines << "  (none)"
            return
          end

          discrepancies.first(LIST_LIMIT).each do |d|
            @lines << "  [#{d.kind}] #{d.detail}"
          end
          if discrepancies.size > LIST_LIMIT
            @lines << "  … (+#{discrepancies.size - LIST_LIMIT} more; see report JSON for the full list)"
          end
        end

        def render_warnings
          section("WARNINGS")
          @lines << if @report.warning
                      "  #{@report.warning}"
                    else
                      "  (none)"
                    end
        end

        # ---- formatting helpers --------------------------------------------

        def section(title)
          @lines << ""
          @lines << Color.bold(title)
        end

        def yes_no(bool)
          bool ? "yes" : "no"
        end

        def format_percent(pct)
          pct.nil? ? "?" : format("%<v>.2f", v: pct)
        end

        def weight_descriptor
          return nil unless @report.weight_class

          name = weight_name(@report.weight_class)
          "#{@report.weight_class}#{" (#{name})" if name}"
        end

        def width_descriptor
          return nil unless @report.width_class

          name = WIDTH_NAMES[@report.width_class]
          "#{@report.width_class}#{" (#{name})" if name}"
        end

        def weight_name(value)
          case value
          when 100 then "Thin"
          when 200 then "Extra-light"
          when 300 then "Light"
          when 400 then "Regular"
          when 500 then "Medium"
          when 600 then "Semi-bold"
          when 700 then "Bold"
          when 800 then "Extra-bold"
          when 900 then "Black"
          end
        end

        def instruction_line(has, count)
          return "no" unless has

          count ? "#{count} instructions" : "present"
        end

        def cvt_line(hinting)
          return "no" unless hinting.has_cvt

          hinting.cvt_entry_count ? "#{hinting.cvt_entry_count} entries" : "present"
        end

        def gasp_line(hinting)
          ranges = Array(hinting.gasp_ranges)
          return "no" if ranges.empty?

          ppems = ranges.map(&:max_ppem).compact
          "#{ranges.size} ranges (#{ppems.join('/')} ppem)"
        end
      end
    end
  end
end
