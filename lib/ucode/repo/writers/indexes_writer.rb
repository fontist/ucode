# frozen_string_literal: true

require "pathname"
require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes the three lookup indexes:
      #
      #   output/index/names.json              (cp_id → name)
      #   output/index/labels.json             (cp_id → {name, gc, sc, cc, bc, mir})
      #   output/index/codepoint_to_block.json (cp_id → block_id)
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class IndexesWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param names [Hash{String => String}] cp_id → name
        # @param labels [Hash{String => Hash}] cp_id → label fields
        # @param cp_to_block [Hash{String => String}] cp_id → block_id
        def initialize(output_root:, names:, labels:, cp_to_block:)
          @output_root = output_root
          @names = names
          @labels = labels
          @cp_to_block = cp_to_block
        end

        # @return [Integer] number of index files written (always 3
        #   when the directory is reachable)
        def write
          count = 0
          count += 1 if write_atomic(Paths.names_index_path(@output_root),
                                     to_pretty_json(@names))
          count += 1 if write_atomic(Paths.labels_index_path(@output_root),
                                     to_pretty_json(@labels))
          count += 1 if write_atomic(codepoint_to_block_path,
                                     to_pretty_json(@cp_to_block))
          count
        end

        private

        def codepoint_to_block_path
          Pathname(@output_root).join("index", "codepoint_to_block.json")
        end
      end
    end
  end
end
