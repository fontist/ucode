# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/planes/<N>.json` — one rollup per Unicode
      # plane that has any coverage.
      #
      # The browser fetches these when the user switches to a
      # plane-grouped view; cheaper than iterating every block.
      class PlaneEmitter
        include Ucode::Repo::AtomicWrites

        # @param face_dir [String, Pathname]
        # @param plane [Models::Audit::PlaneSummary]
        # @return [Boolean] true if written, false if skipped
        def emit(face_dir, plane)
          write_atomic(Paths.plane_under(face_dir, plane.plane),
                       to_pretty_json(plane.to_hash))
        end
      end
    end
  end
end
