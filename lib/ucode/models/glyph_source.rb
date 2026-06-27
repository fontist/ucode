# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One Tier 1 font entry inside a {GlyphSourceMap}. Corresponds to
    # one `- kind: …` item under a block's `sources:` list in
    # `config/unicode17_universal_glyph_set.yml`.
    #
    # This is the typed representation of a font curation choice. The
    # {Ucode::Glyphs::Sources::Tier1RealFont} source consumes it to
    # resolve and load the font; the resolver treats each entry as an
    # independent tier-1 attempt.
    #
    # Wire shape (YAML / JSON identical):
    #
    #   kind: fontist          # one of: fontist, path, system
    #   label: noto-sans       # human + provenance key
    #   priority: 1            # lower wins; resolver tries in order
    #   license: OFL           # optional; OFL / PROPRIETARY / etc.
    #   provenance: "Google Noto Sans"   # optional citation
    #   path: "/abs/font.ttf"  # required when kind == :path
    #
    # `kind` is stored as a plain string on the wire (lutaml-model has
    # no Symbol adapter for key_value); the {#kind_sym} reader casts it
    # for internal dispatch.
    class GlyphSource < Lutaml::Model::Serializable
      KIND_FONTIST = "fontist"
      KIND_PATH = "path"
      KIND_SYSTEM = "system"
      KINDS = [KIND_FONTIST, KIND_PATH, KIND_SYSTEM].freeze
      private_constant :KIND_FONTIST, :KIND_PATH, :KIND_SYSTEM, :KINDS

      attribute :kind, :string
      attribute :label, :string
      attribute :priority, :integer, default: -> { 100 }
      attribute :license, :string
      attribute :provenance, :string
      attribute :path, :string

      key_value do
        map "kind", to: :kind
        map "label", to: :label
        map "priority", to: :priority
        map "license", to: :license
        map "provenance", to: :provenance
        map "path", to: :path
      end

      # @return [Symbol] :fontist, :path, :system; raises if kind is
      #   blank — every entry must declare its kind.
      def kind_sym
        raise ArgumentError, "GlyphSource#kind is required" if kind.nil? || kind.empty?

        kind.to_sym
      end

      # @return [Boolean] true when this entry requires a `path` field
      #   (kind == :path). Used by the loader to validate structure.
      def requires_path?
        kind_sym == :path
      end

      # Renders this source as the legacy font-spec string consumed by
      # {Ucode::Glyphs::RealFonts::FontLocator}: `label=/path/to/font`
      # for kind=path, or `label` (the fontist formula name) for
      # kind=fontist. The locator's `locate` understands both shapes.
      #
      # This is the one adapter method that lets the typed model
      # integrate with the existing locator without rewriting it.
      #
      # @return [String]
      def to_font_spec
        case kind_sym
        when :path
          raise ArgumentError, "GlyphSource#{label} has kind=path but no path" if path.nil? || path.empty?

          "#{label}=#{path}"
        when :fontist, :system
          label
        end
      end
    end
  end
end
