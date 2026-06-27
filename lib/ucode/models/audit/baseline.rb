# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Metadata about the UCD baseline that an {AuditReport} was
      # compared against.
      #
      # Replaces fontisan's bare `ucd_version: String` field. Carries
      # enough provenance that a consumer reading the report knows which
      # UCD build, which ucode/fontisan versions produced the baseline,
      # and when.
      class Baseline < Lutaml::Model::Serializable
        attribute :unicode_version, :string
        attribute :ucode_version, :string
        attribute :fontisan_version, :string
        attribute :source, :string
        attribute :generated_at, :string

        key_value do
          map "unicode_version",  to: :unicode_version
          map "ucode_version",    to: :ucode_version
          map "fontisan_version", to: :fontisan_version
          map "source",           to: :source
          map "generated_at",     to: :generated_at
        end
      end
    end
  end
end
