# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-face entry in a {ReleaseFormulaEntry}.
      #
      # Compact card view derived from a per-face {AuditReport}. Carries
      # identity + coverage totals + relative paths into the release
      # tree. The fontist.org renderer iterates these cards to build its
      # font index; clicking a card fetches the per-face audit subtree
      # at `index_path`.
      class ReleaseFaceEntry < Lutaml::Model::Serializable
        attribute :postscript_name,    :string
        attribute :family_name,        :string
        attribute :weight_class,       :integer
        attribute :total_codepoints,   :integer
        attribute :covered_codepoints, :integer
        attribute :blocks_complete,    :integer
        attribute :blocks_partial,     :integer
        attribute :source_sha256,      :string
        attribute :index_path,         :string
        attribute :html_path,          :string

        key_value do
          map "postscript_name",    to: :postscript_name
          map "family_name",        to: :family_name
          map "weight_class",       to: :weight_class
          map "total_codepoints",   to: :total_codepoints
          map "covered_codepoints", to: :covered_codepoints
          map "blocks_complete",    to: :blocks_complete
          map "blocks_partial",     to: :blocks_partial
          map "source_sha256",      to: :source_sha256
          map "index_path",         to: :index_path
          map "html_path",          to: :html_path
        end
      end
    end
  end
end
