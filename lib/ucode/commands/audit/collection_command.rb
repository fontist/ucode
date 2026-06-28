# frozen_string_literal: true

require "pathname"

require "fontisan"

require "ucode/commands/audit/font_command"
require "ucode/audit/face_auditor"

module Ucode
  module Commands
    module Audit
      # `ucode audit collection PATH` — explicit collection audit.
      # Wraps {FontCommand} with two collection-specific behaviors:
      #
      #   - Validates the source is actually a collection
      #     (TTC/OTC/dfong). Errors out otherwise.
      #   - Supports `font_index:` to audit only one face of the
      #     collection, producing a single-face tree.
      #
      # For unspecified collection options, delegates to FontCommand.
      class CollectionCommand
        # @param font_path [String, Pathname] must be a collection source.
        # @param font_index [Integer, nil] if set, audit only this face.
        # @param kwargs [Hash] forwarded to {FontCommand#call}.
        # @return [FontCommand::Result] when auditing all faces, or a
        #   single-face variant when `font_index:` is set.
        def call(font_path, font_index: nil, **kwargs)
          raise CollectionRequiredError, font_path unless collection?(font_path)
          return audit_single_face(font_path, font_index, kwargs) if font_index

          font_command.call(font_path, **kwargs)
        end

        private

        def collection?(path)
          Fontisan::FontLoader.collection?(path.to_s)
        end

        def audit_single_face(font_path, index, kwargs)
          output_root = kwargs.fetch(:output_root)
          options = build_options(kwargs)
          report = Ucode::Audit::FaceAuditor.new(font_path.to_s, options: options,
                                                                 mode: mode_from(kwargs),
                                                                 font_index: index,
                                                                 reference: kwargs[:reference]).call

          directory = Ucode::Audit::Emitter::FaceDirectory.new(
            output_root: output_root,
            verbose: kwargs.fetch(:verbose, false),
            with_glyphs: kwargs.fetch(:with_glyphs, false),
            emit_browser: kwargs.fetch(:browse, false),
            universal_set_root: kwargs[:universal_set_root],
            with_missing_glyph_pages: kwargs.fetch(:with_missing_glyph_pages, false),
          )

          label = sanitize(kwargs[:label] || report.postscript_name || "face-#{index}")
          face_dir = directory.emit_face(label: label, report: report)

          FontCommand::Result.new(
            spec: font_path.to_s,
            label: label,
            output_dir: face_dir.to_s,
            faces: [FontCommand::FaceOutcome.new(
              label: label,
              postscript_name: report.postscript_name,
              output_dir: face_dir.to_s,
            )],
          )
        end

        def build_options(kwargs)
          opts = {}
          opts[:ucd_version] = kwargs[:unicode_version] if kwargs[:unicode_version]
          opts[:audit_brief] = true if kwargs[:brief]
          opts
        end

        def mode_from(kwargs)
          kwargs[:brief] ? :brief : :full
        end

        def sanitize(name)
          (name || "face").to_s.gsub(/[^A-Za-z0-9._-]/, "_")
        end

        def font_command
          @font_command ||= FontCommand.new
        end
      end

      # Raised by {CollectionCommand} when the input is not a
      # collection source.
      class CollectionRequiredError < StandardError
        # @param path [String, Pathname]
        def initialize(path)
          super("#{path} is not a collection (TTC/OTC/dfong) source")
        end
      end
    end
  end
end
