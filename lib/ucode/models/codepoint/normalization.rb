# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Normalization Quick Check fields (NFC/NFD/NFKC/NFKD QC) plus the
      # derived "Changes_When_*" booleans.
      class Normalization < Lutaml::Model::Serializable
        attribute :nfc_qc, :string, default: "Y"
        attribute :nfd_qc, :boolean, default: true
        attribute :nfkc_qc, :string, default: "Y"
        attribute :nfkd_qc, :boolean, default: true
        attribute :composition_exclusion, :boolean, default: false
        attribute :is_cased, :boolean, default: false
        attribute :changes_when_casefolded, :boolean, default: false
        attribute :changes_when_casemapped, :boolean, default: false
        attribute :changes_when_nfkc_casefolded, :boolean, default: false

        key_value do
          map "nfc_qc", to: :nfc_qc
          map "nfd_qc", to: :nfd_qc
          map "nfkc_qc", to: :nfkc_qc
          map "nfkd_qc", to: :nfkd_qc
          map "composition_exclusion", to: :composition_exclusion
          map "is_cased", to: :is_cased
          map "changes_when_casefolded", to: :changes_when_casefolded
          map "changes_when_casemapped", to: :changes_when_casemapped
          map "changes_when_nfkc_casefolded", to: :changes_when_nfkc_casefolded
        end
      end
    end
  end
end
