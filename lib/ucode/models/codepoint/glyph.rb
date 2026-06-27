# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    class CodePoint < Lutaml::Model::Serializable
      # Glyph bundle for one codepoint. Records where the SVG lives on
      # disk and which resolver tier produced it.
      #
      # The `svg_path` is relative to the codepoint's own directory
      # (always "glyph.svg" — the layout is fixed in {Ucode::Repo::Paths}).
      # The `source` bundle carries the resolver tier name and
      # provenance string, so the dataset is debuggable end-to-end:
      # every glyph in the build can be traced back to its origin
      # (real font, embedded ToUnicode, correlator, or Last Resort).
      class Glyph < Lutaml::Model::Serializable
        # Provenance bundle for a glyph — which tier of the 4-tier
        # resolver produced it. The Ruby class name `Source` mirrors
        # the wire field name; it is unrelated to the
        # {Ucode::Glyphs::Source} abstract base.
        class Source < Lutaml::Model::Serializable
          attribute :tier, :string
          attribute :provenance, :string

          key_value do
            map "tier", to: :tier
            map "provenance", to: :provenance
          end
        end

        attribute :svg_path, :string, default: -> { "glyph.svg" }
        attribute :source, Source

        key_value do
          map "svg_path", to: :svg_path
          map "source", to: :source
        end
      end
    end
  end
end
