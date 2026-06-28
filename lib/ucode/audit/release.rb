# frozen_string_literal: true

module Ucode
  module Audit
    # Release-tree assembler (TODO 27).
    #
    # Composes a fontist.org-consumable release artifact from one or
    # more per-formula library audits plus the universal-set reference.
    # The release tree is the unit `fontist.org/scripts/fetch-data.sh`
    # consumes — a single tarball of `<output_root>/font_audit_release/`
    # is self-contained.
    #
    # Layout (per TODO 27):
    #
    #   <output_root>/font_audit_release/
    #   ├── audit/<formula_slug>/<postscript_name>/...  # per-face audit
    #   ├── universal_glyph_set/                        # TODO 24 build
    #   ├── library.json                                # formulas + faces
    #   └── manifest.json                               # versions + sha256s
    #
    # Components:
    #
    # - {FormulaAudits} — value object pairing a formula slug with its
    #   library-wide audit summary.
    # - {LibraryIndexBuilder} — pure builder for `library.json`.
    # - {ManifestBuilder} — pure builder for `manifest.json` (returns a
    #   {Models::Audit::ReleaseManifest}).
    # - {Emitter} — orchestrator that drives {Emitter::FaceDirectory}
    #   per formula and writes the two top-level indices.
    #
    # The emitter is pure I/O: it consumes ready-built
    # {Models::Audit::LibrarySummary} instances. Running the audits is
    # the caller's responsibility (see {Ucode::Commands::ReleaseCommand}).
    module Release
      autoload :FormulaAudits,        "ucode/audit/release/formula_audits"
      autoload :FaceCard,             "ucode/audit/release/face_card"
      autoload :LibraryIndexBuilder,  "ucode/audit/release/library_index_builder"
      autoload :ManifestBuilder,      "ucode/audit/release/manifest_builder"
      autoload :Emitter,              "ucode/audit/release/emitter"
    end
  end
end
