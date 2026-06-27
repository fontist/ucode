# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Hinting summary for one face.
      #
      # Answers the practical questions a designer or QA engineer asks:
      # "Is this font hinted at all? What flavour? How much hinting, by
      # byte / instruction count?" Unhinted fonts render poorly at small
      # sizes; heavily hinted fonts can be 20%+ bytecode by file size.
      #
      # TrueType hinting surfaces as the fpgm/prep/cvt programs plus the
      # gasp per-ppem policy. CFF/CFF2 hinting surfaces as stem hints
      # encoded inside each CharString. This model carries both, plus a
      # derived `is_unhinted` flag and `hinting_format` classification so
      # downstream tooling does not need to re-derive either.
      #
      # All counts are nil-safe: a face with no hinting at all produces
      # `Hinting.new` with every field falsy/nil rather than raising.
      class Hinting < Lutaml::Model::Serializable
        FORMAT_TRUETYPE = "truetype"
        FORMAT_CFF      = "cff"
        FORMAT_MIXED    = "mixed"
        FORMAT_NONE     = "none"

        # TrueType bytecode programs.
        attribute :has_fpgm,               Lutaml::Model::Type::Boolean
        attribute :fpgm_instruction_count, :integer
        attribute :has_prep,               Lutaml::Model::Type::Boolean
        attribute :prep_instruction_count, :integer

        # TrueType Control Value Table (hinting metrics).
        attribute :has_cvt,         Lutaml::Model::Type::Boolean
        attribute :cvt_entry_count, :integer

        # CVT variation table for variable TrueType fonts. Carried for
        # context only — never included in cvt_entry_count.
        attribute :has_cvar, Lutaml::Model::Type::Boolean

        # gasp policy ranges, ordered by ascending max_ppem.
        attribute :gasp_ranges, GaspRange, collection: true, default: -> { [] }

        # CFF/CFF2 hinting. cff_has_private_dict is true for every CFF
        # face (Private DICT is mandatory); cff_hint_count sums stem
        # declarations across all CharStrings, nil when unparsable.
        attribute :cff_has_private_dict, Lutaml::Model::Type::Boolean
        attribute :cff_hint_count,       :integer

        # Derived at extraction time so consumers read flat fields.
        attribute :is_unhinted,    Lutaml::Model::Type::Boolean
        attribute :hinting_format, :string

        key_value do
          map "has_fpgm",               to: :has_fpgm
          map "fpgm_instruction_count", to: :fpgm_instruction_count
          map "has_prep",               to: :has_prep
          map "prep_instruction_count", to: :prep_instruction_count
          map "has_cvt",                to: :has_cvt
          map "cvt_entry_count",        to: :cvt_entry_count
          map "has_cvar",               to: :has_cvar
          map "gasp_ranges",            to: :gasp_ranges
          map "cff_has_private_dict",   to: :cff_has_private_dict
          map "cff_hint_count",         to: :cff_hint_count
          map "is_unhinted",            to: :is_unhinted
          map "hinting_format",         to: :hinting_format
        end

        # Derive {is_unhinted} and {hinting_format} from individual flags.
        # Called by the extractor before construction so the values land
        # in serialized output without recomputation at read time.
        #
        # gasp is a TrueType-specific table, so it counts toward the
        # TrueType hinting bucket even when no fpgm/prep/cvt is present.
        #
        # @return [Hash] keys :is_unhinted, :hinting_format
        def self.derive_flags(has_tt:, has_cff:, has_gasp:)
          tt_hints = has_tt || has_gasp
          {
            is_unhinted: !(tt_hints || has_cff),
            hinting_format: format_for(tt_hints, has_cff),
          }
        end

        def self.format_for(has_tt, has_cff)
          case [has_tt, has_cff]
          when [true, true]  then FORMAT_MIXED
          when [true, false] then FORMAT_TRUETYPE
          when [false, true] then FORMAT_CFF
          else                    FORMAT_NONE
          end
        end
        private_class_method :format_for
      end
    end
  end
end
