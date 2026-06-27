# frozen_string_literal: true

require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/audit/emitter/paths"

module Ucode
  module Audit
    module Emitter
      # Writes `<face_dir>/blocks/<NAME>.json` — one file per touched
      # block.
      #
      # The filename uses the block name verbatim (no slugifying) per
      # `03-directory-output-spec.md` §"Block filename encoding". The
      # only character that needs escaping is `/`, which Unicode block
      # names never contain today.
      #
      # Each file is a single BlockSummary serialized via lutaml-model.
      # The browser fetches these lazily when the user expands a block
      # in the coverage map.
      class BlockEmitter
        include Ucode::Repo::AtomicWrites

        # @param face_dir [String, Pathname]
        # @param block [Models::Audit::BlockSummary]
        # @return [Boolean] true if written, false if skipped
        def emit(face_dir, block)
          path = Paths.block_under(face_dir, encode_name(block.name))
          write_atomic(path, to_pretty_json(serialize_block(block)))
        end

        private

        # Spec: per-block `missing_codepoints` is always embedded even
        # when empty. lutaml-model omits empty arrays by default, so we
        # restore the key post-serialization.
        def serialize_block(block)
          block.to_hash.tap do |hash|
            hash["missing_codepoints"] = block.missing_codepoints
          end
        end

        # Unicode block names are filesystem-safe as-is (no slashes).
        # This is a defensive guard.
        def encode_name(name)
          name.to_s.tr("/", "_")
        end
      end
    end
  end
end
