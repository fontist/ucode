# frozen_string_literal: true

module Ucode
  module Audit
    # Mode 2 output writers: turn an in-memory {Models::Audit::AuditReport}
    # (or {Models::Audit::LibrarySummary}) into the on-disk directory tree
    # documented in `TODO.new/03-directory-output-spec.md`.
    #
    # The emitter layer is pure I/O — no audit logic, no font parsing. Every
    # emitter writes one chunk kind and is idempotent via
    # {Ucode::Repo::AtomicWrites} (content-hash compare, then atomic rename).
    #
    # Top-level orchestrator: {Emitter::FaceDirectory}. Per-chunk emitters
    # are wired together by it; callers should never instantiate the chunk
    # emitters directly.
    module Emitter
      autoload :Paths,            "ucode/audit/emitter/paths"
      autoload :IndexEmitter,     "ucode/audit/emitter/index_emitter"
      autoload :BlockEmitter,     "ucode/audit/emitter/block_emitter"
      autoload :PlaneEmitter,     "ucode/audit/emitter/plane_emitter"
      autoload :ScriptEmitter,    "ucode/audit/emitter/script_emitter"
      autoload :CodepointEmitter, "ucode/audit/emitter/codepoint_emitter"
      autoload :GlyphEmitter,     "ucode/audit/emitter/glyph_emitter"
      autoload :CollectionEmitter, "ucode/audit/emitter/collection_emitter"
      autoload :LibraryEmitter,    "ucode/audit/emitter/library_emitter"
      autoload :FaceDirectory,     "ucode/audit/emitter/face_directory"
    end
  end
end
