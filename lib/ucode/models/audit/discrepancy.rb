# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # One cheap audit signal on an {AuditReport}.
      #
      # Discrepancies are issues the audit noticed but that don't fit
      # neatly into a per-table summary (e.g. an OS/2 ulUnicodeRange
      # bit set with zero cmap codepoints in that block). They're the
      # "you should look at this" list — actionable without being a
      # hard error.
      class Discrepancy < Lutaml::Model::Serializable
        # Canonical `kind` values. New kinds = one constant here + one
        # extractor check. Extractors MUST use these constants rather
        # than hand-rolled strings.
        KIND_OS2_UNICODE_RANGE_BIT_WITHOUT_CMAP_CODEPOINTS =
          "os2_unicode_range_bit_without_cmap_codepoints"
        KIND_NAME_TABLE_BUG = "name_table_bug"
        KIND_METRICS_INCONSISTENT = "metrics_inconsistent"

        attribute :kind, :string
        attribute :detail, :string
        attribute :block_name, :string
        attribute :bit_position, :integer

        key_value do
          map "kind",         to: :kind
          map "detail",       to: :detail
          map "block_name",   to: :block_name
          map "bit_position", to: :bit_position
        end
      end
    end
  end
end
