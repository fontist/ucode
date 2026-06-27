# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/repo/atomic_writes"
require "ucode/audit/browser"
require "ucode/audit/browser/template"
require "ucode/audit/emitter/paths"
require "ucode/audit/emitter/library_emitter"

module Ucode
  module Audit
    module Browser
      # Renders the library-level `index.html` — a card grid of all
      # audited fonts in a library, with search/sort/filter controls.
      #
      # The page inlines the same JSON shape that
      # {Emitter::LibraryEmitter} writes to `index.json`, plus inlined
      # CSS and JS. Clicking a card navigates to that face's
      # per-face browser (`<label>/index.html`).
      #
      # Self-contained: no external resources. The entire
      # `output/font_audit/` tree is portable as a unit.
      #
      # Two construction modes — pass exactly one of:
      #   - `summary:` — a live {Models::Audit::LibrarySummary}. The
      #     JSON shape is derived via {Emitter::LibraryEmitter#build_index}.
      #   - `library_json:` — a pre-built JSON string of the library
      #     overview shape. Used by {Commands::AuditBrowserCommand}
      #     when regenerating HTML from an existing `index.json`.
      class LibraryPage
        include Ucode::Repo::AtomicWrites

        # @param summary [Models::Audit::LibrarySummary, nil]
        # @param library_json [String, nil] pre-built library overview JSON
        def initialize(summary: nil, library_json: nil)
          raise ArgumentError, "pass exactly one of summary: / library_json:" \
            unless summary.nil? ^ library_json.nil?

          @summary = summary
          @library_json = library_json
        end

        # Write the rendered page to `<library_root>/index.html`.
        # @param output_root [String, Pathname]
        # @return [Boolean] true if written, false if skipped
        def write(output_root)
          path = Ucode::Audit::Emitter::Paths.library_html_path(output_root)
          write_atomic(path, render)
        end

        # Render the page as a string.
        # @return [String]
        def render
          Template.new(:library).render(
            library_json: library_json,
            page_title: "ucode audit library",
          )
        end

        private

        def library_json
          @library_json ||=
            begin
              hash = Ucode::Audit::Emitter::LibraryEmitter.new.build_index(@summary)
              JSON.generate(hash)
            end
        end
      end
    end
  end
end
