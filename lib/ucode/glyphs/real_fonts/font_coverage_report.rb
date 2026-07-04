# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Glyphs
    module RealFonts
      # Coverage report for a single font face. Produced by
      # {CoverageAuditor} from a {Fontisan::Models::Audit::AuditReport}
      # + the font's own cmap walk. Carries identity (so a consumer
      # reading the file knows which font produced it), coverage
      # totals, and the per-block detail restricted to Unicode 17 new
      # blocks (older blocks are noise for this audit).
      class FontCoverageReport < Lutaml::Model::Serializable
        attribute :generated_at, :string
        attribute :source_file, :string
        attribute :source_format, :string
        attribute :family_name, :string
        attribute :full_name, :string
        attribute :postscript_name, :string
        attribute :version, :string
        attribute :total_codepoints, :integer
        attribute :total_glyphs, :integer
        attribute :ucd_version, :string
        attribute :blocks, BlockCoverage, collection: true, default: -> { [] }

        key_value do
          map "generated_at",      to: :generated_at
          map "source_file",       to: :source_file
          map "source_format",     to: :source_format
          map "family_name",       to: :family_name
          map "full_name",         to: :full_name
          map "postscript_name",   to: :postscript_name
          map "version",           to: :version
          map "total_codepoints",  to: :total_codepoints
          map "total_glyphs",      to: :total_glyphs
          map "ucd_version",       to: :ucd_version
          map "blocks",            to: :blocks
        end
      end
    end
  end
end
