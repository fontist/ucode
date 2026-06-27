# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/scripts/<CODE>.json` — one rollup per ISO
      # 15924 script code (Latn, Grek, Hani, …).
      #
      # The browser fetches these when the user switches to a
      # script-grouped view; cheaper than iterating every block.
      class ScriptEmitter
        include Ucode::Repo::AtomicWrites

        # @param face_dir [String, Pathname]
        # @param script [Models::Audit::ScriptSummary]
        # @return [Boolean] true if written, false if skipped
        def emit(face_dir, script)
          write_atomic(Paths.script_under(face_dir, script.script_code),
                       to_pretty_json(script.to_hash))
        end
      end
    end
  end
end
