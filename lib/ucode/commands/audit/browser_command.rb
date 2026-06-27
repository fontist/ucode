# frozen_string_literal: true

require "pathname"
require "json"

require "ucode/audit"
require "ucode/audit/browser"
require "ucode/audit/emitter/paths"

module Ucode
  module Commands
    module Audit
      # `ucode audit browser` — regenerate HTML browsers from existing
      # JSON audits, without re-running extractors.
      #
      # Walks the audit root and rewrites only `.html` files. Useful
      # when the audit ran without `--browse`, or after a CSS/JS
      # template tweak. No JSON is rewritten.
      #
      # Scopes:
      #   - default: regenerate both library-level + all face pages.
      #   - `faces_only: true` — only per-face pages.
      #   - `library_only: true` — only the library-level page.
      class BrowserCommand
        FaceRegen = Struct.new(:label, :path, :written, keyword_init: true)

        Result = Struct.new(:input, :library_html, :faces, :error,
                            keyword_init: true)

        # @param input [String, Pathname] audit root path. Must be a
        #   directory containing either `<input>/index.json` (library
        #   root) or per-face subdirectories each with their own
        #   `index.json` (face root). Either way the root is treated
        #   as the library root.
        # @param faces_only [Boolean]
        # @param library_only [Boolean]
        # @return [Result]
        def call(input:, faces_only: false, library_only: false)
          audit_root = Pathname.new(input)

          library_html =
            library_only || !faces_only ? write_library(audit_root) : nil
          faces =
            faces_only || !library_only ? write_faces(audit_root) : []

          Result.new(input: audit_root.to_s, library_html: library_html&.to_s,
                     faces: faces)
        rescue StandardError => e
          Result.new(input: input.to_s, error: "#{e.class}: #{e.message}")
        end

        private

        # The library index.json sits at `<audit_root>/index.json`;
        # the library index.html is written to the same directory.
        # {Browser::LibraryPage#write} takes the output_root (one
        # level up) so we pass `audit_root.parent`.
        def write_library(audit_root)
          index_json = audit_root.join("index.json")
          return nil unless index_json.exist?

          Ucode::Audit::Browser::LibraryPage.new(library_json: index_json.read)
            .write(audit_root.parent)
          Ucode::Audit::Emitter::Paths.library_html_path(audit_root.parent)
        end

        def write_faces(audit_root)
          audit_root.children.select(&:directory?).filter_map do |face_dir|
            json = face_dir.join("index.json")
            next unless json.exist?

            written = Ucode::Audit::Browser::FacePage.new(overview_json: json.read)
              .write(face_dir)
            FaceRegen.new(label: face_dir.basename.to_s,
                          path: face_dir.join("index.html").to_s,
                          written: written)
          end
        end
      end
    end
  end
end
