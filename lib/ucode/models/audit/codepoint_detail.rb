# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Per-codepoint detail row, emitted only in `--verbose` mode.
      #
      # Lives in a separate `codepoints.json` file under the directory
      # emitter (TODO 13) so the main `audit.json` stays compact. Each
      # row pairs UCD metadata (name, gc, script, age) with the font's
      # glyph id and (optionally) a relative path to the rendered SVG.
      class CodepointDetail < Lutaml::Model::Serializable
        attribute :codepoint, :integer
        attribute :name, :string
        attribute :general_category, :string
        attribute :script, :string
        attribute :script_extensions, :string, collection: true, default: -> { [] }
        attribute :block_name, :string
        attribute :age, :string
        attribute :glyph_id, :integer
        attribute :glyph_svg_path, :string

        key_value do
          map "codepoint",         to: :codepoint
          map "name",              to: :name
          map "general_category",  to: :general_category
          map "script",            to: :script
          map "script_extensions", to: :script_extensions
          map "block_name",        to: :block_name
          map "age",               to: :age
          map "glyph_id",          to: :glyph_id
          map "glyph_svg_path",    to: :glyph_svg_path
        end

        # "U+XXXX" form for human display. Not serialized.
        # @return [String]
        def cp_id
          format("U+%04X", codepoint)
        end
      end
    end
  end
end
