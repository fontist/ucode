# frozen_string_literal: true

module Ucode
  module Glyphs
    # Universal glyph set — one SVG per assigned Unicode codepoint,
    # sourced via the 4-tier resolver using the curated Tier 1 config
    # from TODO 23. The set is the canonical reference for "what
    # Unicode 17 looks like" — every codepoint has exactly one glyph,
    # with documented provenance, in a flat layout designed for fast
    # lookup by audits (TODO 25) and the fontist.org consumer
    # (TODO 27).
    #
    # Output layout (per TODO 24):
    #
    #   output/universal_glyph_set/
    #   ├── manifest.json             # one entry per codepoint + totals
    #   ├── glyphs/
    #   │   ├── U+0000.svg
    #   │   └── ...
    #   └── reports/
    #       ├── by_tier.json          # tier-1: N1, pillar-1: N2, ...
    #       ├── by_block.json         # per-block tier breakdown
    #       └── gaps.json             # assigned codepoints with no glyph
    #
    # Components:
    #
    # - {Builder} drains a codepoint stream through the resolver and
    #   writes glyphs + manifest atomically.
    # - {ManifestAccumulator} is the thread-safe tally that produces
    #   the final {Ucode::Models::UniversalSetManifest}.
    # - {ManifestWriter} emits the manifest and per-tier / per-block /
    #   gaps reports under the output root.
    # - {Idempotency} wraps {Ucode::Repo::AtomicWrites} with the
    #   "skip if SVG unchanged" semantic documented in TODO 24.
    module UniversalSet
      autoload :Builder, "ucode/glyphs/universal_set/builder"
      autoload :ManifestAccumulator, "ucode/glyphs/universal_set/manifest_accumulator"
      autoload :ManifestWriter, "ucode/glyphs/universal_set/manifest_writer"
      autoload :Idempotency, "ucode/glyphs/universal_set/idempotency"
    end
  end
end
