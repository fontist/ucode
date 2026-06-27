# frozen_string_literal: true

require "pathname"

require "ucode/audit/emitter/paths"
require "ucode/audit/emitter/index_emitter"
require "ucode/audit/emitter/block_emitter"
require "ucode/audit/emitter/plane_emitter"
require "ucode/audit/emitter/script_emitter"
require "ucode/audit/emitter/codepoint_emitter"
require "ucode/audit/emitter/glyph_emitter"
require "ucode/audit/emitter/collection_emitter"
require "ucode/audit/emitter/library_emitter"

module Ucode
  module Audit
    module Emitter
      # Top-level Mode 2 orchestrator. Walks an AuditReport (or a list
      # of reports for a collection, or a library summary) and emits the
      # full directory tree per `03-directory-output-spec.md`.
      #
      # Owns the chunk-emitter composition: callers never touch
      # {IndexEmitter} / {BlockEmitter} / etc. directly. The chunk
      # emitters themselves stay single-purpose (one chunk kind each)
      # and take an explicit `face_dir` Pathname — they don't know
      # whether the face lives at `output/font_audit/<label>/` or under
      # a collection subdir.
      #
      # Three entry points:
      #
      #   - {#emit_face}       — one standalone face
      #   - {#emit_collection} — one TTC source (N sibling faces)
      #   - {#emit_library}    — directory-mode (M face labels)
      #
      # Idempotency is delegated to each chunk emitter via
      # {Ucode::Repo::AtomicWrites}; re-running the same audit produces
      # zero writes on the second pass.
      class FaceDirectory
        # @param output_root [String, Pathname] top-level output root
        #   (e.g. "output"). The library root is `<output_root>/font_audit`.
        # @param verbose [Boolean] emit codepoints/<NAME>.json per block
        # @param with_glyphs [Boolean] emit glyphs/U+XXXX.svg per covered cp
        # @param glyph_resolver [Proc(Integer) -> String, nil] SVG source
        #   for {GlyphEmitter}; defaults to a proc that returns nil
        #   (no glyphs emitted). Replaced by the canonical 4-tier
        #   resolver (TODO 20) when ready.
        # @param database [Ucode::Database, nil] baseline UCD lookup for
        #   {CodepointEmitter} enrichment
        def initialize(output_root:, verbose: false, with_glyphs: false,
                       glyph_resolver: GlyphEmitter::DEFAULT_RESOLVER,
                       database: nil)
          @output_root = output_root
          @verbose = verbose
          @with_glyphs = with_glyphs
          @database = database
          @index_emitter = IndexEmitter.new
          @block_emitter = BlockEmitter.new
          @plane_emitter = PlaneEmitter.new
          @script_emitter = ScriptEmitter.new
          @codepoint_emitter = CodepointEmitter.new
          @glyph_emitter = GlyphEmitter.new(glyph_resolver: glyph_resolver)
          @collection_emitter = CollectionEmitter.new
          @library_emitter = LibraryEmitter.new
        end

        # @param label [String] sanitized face label (caller-sanitized)
        # @param report [Models::Audit::AuditReport]
        # @return [Pathname] the per-face directory written
        def emit_face(label:, report:)
          emit_face_under(Paths.face_dir(@output_root, label), report)
        end

        # @param source_label [String] sanitized collection label
        # @param reports [Array<Models::Audit::AuditReport>]
        # @return [Array<String>] per-face subdirectory names
        def emit_collection(source_label:, reports:)
          @collection_emitter.emit(@output_root, source_label, reports,
                                   face_directory: self)
        end

        # @param summary [Models::Audit::LibrarySummary]
        # @return [Boolean] true if library index was written
        def emit_library(summary:)
          summary.per_face_reports.each do |report|
            emit_face(label: face_label(report), report: report)
          end
          @library_emitter.emit(@output_root, summary)
        end

        # Hook called by {CollectionEmitter} to write one face under a
        # collection root. Computes the per-face subdirectory name from
        # the face_index so the source order is preserved on disk.
        #
        # @api private
        # @param source_label [String]
        # @param face_index [Integer]
        # @param report [Models::Audit::AuditReport]
        # @return [String] the per-face subdirectory name (e.g. "00-Mona")
        def emit_collection_face(source_label:, face_index:, report:)
          face_label = format("%<idx>02d-%<label>s",
                              idx: face_index,
                              label: sanitize(report.postscript_name))
          emit_face_under(
            Paths.collection_face_dir(@output_root, source_label, face_index,
                                      sanitize(report.postscript_name)),
            report,
          )
          face_label
        end

        private

        def emit_face_under(face_dir, report)
          @index_emitter.emit(face_dir, report)
          report.blocks.each { |b| @block_emitter.emit(face_dir, b) }
          report.plane_summaries.each { |p| @plane_emitter.emit(face_dir, p) }
          report.scripts.each { |s| @script_emitter.emit(face_dir, s) }
          emit_codepoints(face_dir, report) if @verbose
          emit_glyphs(face_dir, report)     if @with_glyphs
          face_dir
        end

        def emit_codepoints(face_dir, report)
          report.blocks.each do |block|
            next if block.covered_codepoints.empty?

            @codepoint_emitter.emit(face_dir, block,
                                    database: @database,
                                    with_glyph_paths: @with_glyphs)
          end
        end

        def emit_glyphs(face_dir, report)
          report.blocks.flat_map(&:covered_codepoints).sort.each do |cp|
            @glyph_emitter.emit(face_dir, cp)
          end
        end

        def face_label(report)
          report.postscript_name || File.basename(report.source_file, ".*")
        end

        def sanitize(name)
          (name || "face").to_s.gsub(/[^A-Za-z0-9._-]/, "_")
        end
      end
    end
  end
end
