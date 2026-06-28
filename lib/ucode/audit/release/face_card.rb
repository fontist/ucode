# frozen_string_literal: true

require "pathname"

require "ucode/audit/emitter/paths"
require "ucode/models/audit"

module Ucode
  module Audit
    module Release
      # Value object deriving the per-face card fields shared by
      # {LibraryIndexBuilder} (Hash for `library.json`) and
      # {ManifestBuilder} ({Models::Audit::ReleaseFaceEntry} for
      # `manifest.json`).
      #
      # Single source of truth for the rollup math (covered total,
      # assigned total, complete/partial block counts) and the path
      # conventions (face label sanitization, relative index/html
      # paths under `<release_root>/audit/<slug>/<label>/`).
      #
      # Pure: no I/O, no mutation. Callers compose the final shape
      # (Hash or model) from the derived fields.
      class FaceCard
        attr_reader :report, :slug, :release_root

        # @param report [Models::Audit::AuditReport]
        # @param slug [String] formula slug
        # @param release_root [String, Pathname]
        def initialize(report, slug, release_root)
          @report = report
          @slug = slug
          @release_root = release_root
        end

        # @return [String] sanitized face label (postscript name with
        #   non-filename chars replaced by underscore)
        def label
          name = report.postscript_name || File.basename(report.source_file.to_s, ".*")
          (name || "face").to_s.gsub(/[^A-Za-z0-9._-]/, "_")
        end

        # @return [Pathname] `<release_root>/audit/<slug>/<label>`
        def face_dir
          Ucode::Audit::Emitter::Paths.release_face_dir(release_root, slug, label)
        end

        # @return [Integer]
        def covered_total
          report.blocks.sum(&:covered_count)
        end

        # @return [Integer]
        def assigned_total
          report.blocks.sum(&:total_assigned)
        end

        # @return [Integer]
        def blocks_complete
          report.blocks.count do |b|
            b.status == Models::Audit::BlockSummary::STATUS_COMPLETE
          end
        end

        # @return [Integer]
        def blocks_partial
          report.blocks.count do |b|
            b.status == Models::Audit::BlockSummary::STATUS_PARTIAL
          end
        end

        # @return [String] relative path from release root to index.json
        def index_path
          relative_path(face_dir.join("index.json"))
        end

        # @return [String] relative path from release root to index.html
        def html_path
          relative_path(face_dir.join("index.html"))
        end

        private

        def relative_path(to)
          Pathname.new(to).expand_path
            .relative_path_from(Pathname.new(release_root).expand_path)
            .to_s
        rescue ArgumentError
          Pathname.new(to).to_s
        end
      end
    end
  end
end
