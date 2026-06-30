# frozen_string_literal: true

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes `output/blocks/<ID>.json` for every block plus
      # `output/blocks/index.json` as a summary.
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class BlocksWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param blocks [Array<Ucode::Models::Block>]
        # @param block_codepoint_ids [Hash{String => Array<String>}]
        #   block_id → sorted cp_id list, accumulated during the
        #   streaming pass
        # @param block_ages [Hash{String => String}] block_id → earliest
        #   DerivedAge string; nil entries get written as nil
        def initialize(output_root:, blocks:, block_codepoint_ids:, block_ages:)
          @output_root = output_root
          @blocks = blocks
          @block_codepoint_ids = block_codepoint_ids
          @block_ages = block_ages
        end

        # @return [Integer] number of files written (one per block plus
        #   one for the index)
        def write
          count = @blocks.sum do |block|
            block.age = @block_ages[block.id]
            path = Paths.block_metadata_path(@output_root, block.id)
            write_atomic(path, block_payload(block)) ? 1 : 0
          end
          count + write_blocks_index
        end

        private

        def write_blocks_index
          path = Paths.blocks_index_path(@output_root)
          summary = @blocks.map do |block|
            {
              "id" => block.id,
              "name" => block.name,
              "first_cp" => block.range_first,
              "last_cp" => block.range_last,
              "plane_number" => block.plane_number,
              "age" => @block_ages[block.id],
            }
          end
          write_atomic(path, to_pretty_json(summary)) ? 1 : 0
        end

        def block_payload(block)
          to_pretty_json(
            "id" => block.id,
            "name" => block.name,
            "range_first" => block.range_first,
            "range_last" => block.range_last,
            "plane_number" => block.plane_number,
            "age" => @block_ages[block.id],
            "codepoint_ids" => @block_codepoint_ids[block.id] || [],
          )
        end
      end
    end
  end
end
