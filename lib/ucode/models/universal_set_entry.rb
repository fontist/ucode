# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    # One row in a {UniversalSetManifest}. Records the resolved glyph
    # for a single codepoint: which tier produced it, which source
    # font, and a stable content hash + size so downstream consumers
    # can detect changes without re-reading the SVG.
    #
    # Wire shape (one entry per assigned codepoint in the manifest's
    # `entries:` array):
    #
    #   {
    #     "codepoint": 65,
    #     "id": "U+0041",
    #     "tier": "tier-1",
    #     "source": "noto-sans",
    #     "svg_sha256": "abc...",
    #     "svg_size_bytes": 412
    #   }
    #
    # `source` is the source identifier extracted from the resolver
    # {Ucode::Glyphs::Source::Result#provenance} — i.e. the part after
    # the `tier:` prefix ("noto-sans" for "tier-1:noto-sans"). This is
    # what audits (TODO 25) group by when answering "how many
    # codepoints does font X cover in this set?".
    class UniversalSetEntry < Lutaml::Model::Serializable
      attribute :codepoint, :integer
      attribute :id, :string
      attribute :tier, :string
      attribute :source, :string
      attribute :svg_sha256, :string
      attribute :svg_size_bytes, :integer, default: 0

      key_value do
        map "codepoint", to: :codepoint
        map "id", to: :id
        map "tier", to: :tier
        map "source", to: :source
        map "svg_sha256", to: :svg_sha256
        map "svg_size_bytes", to: :svg_size_bytes
      end
    end
  end
end
