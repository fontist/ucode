# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Aggregate view over a directory (tree) of audited fonts.
      #
      # Built by the library auditor. Combines a flat list of per-face
      # {AuditReport}s with derived cross-face rollups: script coverage
      # matrix, duplicate detection (by source_sha256), and license
      # distribution. Lets a librarian inventory a font collection in
      # one pass.
      class LibrarySummary < Lutaml::Model::Serializable
        attribute :root_path,           :string
        attribute :total_files,         :integer
        attribute :total_faces,         :integer
        attribute :scanned_extensions,  :string, collection: true, default: -> { [] }
        attribute :aggregate_metrics,   :hash, default: -> { {} }
        attribute :script_coverage,     ScriptCoverageRow, collection: true, default: -> { [] }
        attribute :duplicate_groups,    DuplicateGroup,    collection: true, default: -> { [] }
        attribute :license_distribution, :hash, default: -> { {} }
        attribute :per_face_reports, AuditReport, collection: true, default: -> { [] }

        key_value do
          map "root_path",            to: :root_path
          map "total_files",          to: :total_files
          map "total_faces",          to: :total_faces
          map "scanned_extensions",   to: :scanned_extensions
          map "aggregate_metrics",    to: :aggregate_metrics
          map "script_coverage",      to: :script_coverage
          map "duplicate_groups",     to: :duplicate_groups
          map "license_distribution", to: :license_distribution
          map "per_face_reports",     to: :per_face_reports
        end
      end
    end
  end
end
