# frozen_string_literal: true

class Ucode::Coordinator
  # Registry of per-codepoint enrichment concerns. Each module under
  # {Enrichment} owns one slice of the UCD/Unihan merge: Script, Bidi,
  # Casing, Names, CJK, Display, Segmentation, Indic, Emoji, Binary.
  #
  # The registry is an ordered Array of modules. {Coordinator#enrich}
  # iterates it, calling `enrich(cp, indices)` on each. New UCD
  # properties land as a new module + one line in {REGISTRY}.
  #
  # Each module is pure: it reads from {Indices} and mutates the
  # CodePoint model. Range lookups go through {RangeLookup}.
  module Enrichment
    autoload :Identity, "ucode/coordinator/enrichment/identity"
    autoload :Bidi, "ucode/coordinator/enrichment/bidi"
    autoload :Casing, "ucode/coordinator/enrichment/casing"
    autoload :Binary, "ucode/coordinator/enrichment/binary"
    autoload :Names, "ucode/coordinator/enrichment/names"
    autoload :CJK, "ucode/coordinator/enrichment/cjk"
    autoload :Display, "ucode/coordinator/enrichment/display"
    autoload :Segmentation, "ucode/coordinator/enrichment/segmentation"
    autoload :Indic, "ucode/coordinator/enrichment/indic"
    autoload :Emoji, "ucode/coordinator/enrichment/emoji"

    # Order matters only for determinism — each module sets disjoint
    # fields on the CodePoint model. Preserved from the original flat
    # dispatch for stable diff comparisons.
    REGISTRY = [
      Identity,
      Bidi,
      Casing,
      Binary,
      Names,
      CJK,
      Display,
      Segmentation,
      Indic,
      Emoji,
    ].freeze

    # Apply every enrichment concern to `cp`, in registry order.
    # @param cp [Ucode::Models::CodePoint]
    # @param indices [Ucode::Coordinator::Indices]
    def self.apply(cp, indices)
      REGISTRY.each { |mod| mod.enrich(cp, indices) }
    end
  end
end
