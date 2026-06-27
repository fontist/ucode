# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/repo/atomic_writes"
require "ucode/audit/browser"
require "ucode/audit/browser/template"
require "ucode/audit/emitter/paths"
require "ucode/audit/emitter/index_emitter"

module Ucode
  module Audit
    module Browser
      # Renders one face's `index.html` — a fully self-contained
      # browser page for one audited font.
      #
      # The page inlines the same JSON shape that {Emitter::IndexEmitter}
      # writes to `index.json`, plus inlined CSS and JS. Opening the
      # file via `file://` renders the overview immediately; lazy
      # fetches of the per-block chunks (`blocks/<NAME>.json`,
      # `codepoints/<NAME>.json`, `glyphs/U+XXXX.svg`) work when the
      # directory is served over HTTP.
      #
      # Self-contained: no external CSS, no external JS, no CDN.
      # Portable: the entire `<label>/` directory can be moved/served
      # whole and the page still works.
      #
      # Two construction modes — pass exactly one of:
      #   - `report:` — a live {Models::Audit::AuditReport}. The JSON
      #     shape is derived via {Emitter::IndexEmitter#build_index}.
      #     Used by {Emitter::FaceDirectory} when emitting alongside
      #     the audit.
      #   - `overview_json:` — a pre-built JSON string of the overview
      #     shape. Used by {Commands::AuditBrowserCommand} when
      #     regenerating HTML from an existing `index.json`.
      class FacePage
        include Ucode::Repo::AtomicWrites

        # @param report [Models::Audit::AuditReport, nil]
        # @param overview_json [String, nil] pre-built overview JSON
        # @param verbose [Boolean] when true, the rendered page
        #   advertises per-block codepoint detail chunks
        # @param with_glyphs [Boolean] when true, the rendered page
        #   advertises that `glyphs/U+XXXX.svg` chunks exist
        def initialize(report: nil, overview_json: nil, verbose: false,
                       with_glyphs: false)
          raise ArgumentError, "pass exactly one of report: / overview_json:" \
            unless report.nil? ^ overview_json.nil?

          @report = report
          @overview_json = overview_json
          @verbose = verbose
          @with_glyphs = with_glyphs
        end

        # Write the rendered page to `<face_dir>/index.html`.
        # @param face_dir [String, Pathname]
        # @return [Boolean] true if written, false if skipped
        def write(face_dir)
          write_atomic(Pathname.new(face_dir).join("index.html"), render)
        end

        # Render the page as a string. Useful in tests.
        # @return [String]
        def render
          Template.new(:face).render(
            overview_json: overview_json,
            page_title: page_title,
            verbose: @verbose,
            with_glyphs: @with_glyphs,
          )
        end

        private

        def overview_json
          @overview_json ||=
            JSON.generate(Ucode::Audit::Emitter::IndexEmitter.new.build_index(@report))
        end

        def page_title
          @report ? report_title : derived_title
        end

        def report_title
          [@report.family_name, @report.subfamily_name].compact.join(" ")
        end

        def derived_title
          font = JSON.parse(@overview_json)["font"] || {}
          [font["family_name"], font["subfamily_name"]].compact.join(" ")
        rescue JSON::ParserError
          "ucode audit"
        end
      end
    end
  end
end
