# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Glyphs
    module RealFonts
      # Per-block coverage row on a {FontCoverageReport}.
      #
      # `assigned` is the UCD-assigned codepoint count for this block
      # (from {Unicode17Blocks}); `covered` is the count actually
      # present in the font's cmap; `missing_cps` is the human-readable
      # hex form (`U+XXXX`) of every assigned codepoint the font lacks,
      # so a downstream consumer can audit gaps without re-walking the
      # cmap.
      class BlockCoverage < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :first_cp, :integer
        attribute :last_cp, :integer
        attribute :assigned, :integer
        attribute :covered, :integer
        attribute :missing_cps, :string, collection: true, default: -> { [] }

        key_value do
          map "name",        to: :name
          map "first_cp",    to: :first_cp
          map "last_cp",     to: :last_cp
          map "assigned",    to: :assigned
          map "covered",     to: :covered
          map "missing_cps", to: :missing_cps
        end

        def fill_ratio
          return 0.0 if assigned.nil? || assigned.zero?

          (covered.to_f / assigned).round(4)
        end

        def complete?
          assigned.to_i.positive? && covered == assigned
        end
      end
    end
  end
end
