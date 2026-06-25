# frozen_string_literal: true

require "ucode/index"
require "ucode/range_entry"

module Ucode
  # Streaming accumulator that turns a sequence of CodePoint records
  # into per-property sorted + coalesced Index instances.
  #
  # Lifecycle:
  #
  #   builder = IndexBuilder.new
  #   Coordinator.new.each_codepoint(...) { |cp| builder.add(cp) }
  #   builder.blocks_index   # => Index
  #   builder.scripts_index  # => Index
  #
  # The Coordinator yields cps in ascending cp order, so the per-name
  # cp arrays are already sorted. The final pass coalesces adjacent
  # cps (gap of 1) into RangeEntry runs.
  #
  # **Coalescing caveat**: ranges are derived from ASSIGNED cps only.
  # If a block has unassigned cps in the middle, the resulting range
  # will fragment around them. For lookup_block(cp) on an assigned cp,
  # the answer is correct. For an unassigned cp, the lookup returns
  # nil. This is a deliberate trade-off for streaming memory bounds —
  # the canonical block ranges are in `Coordinator#indices.blocks`,
  # not in the streamed cps.
  class IndexBuilder
    def initialize
      @cps_by_block = Hash.new { |h, k| h[k] = [] }
      @cps_by_script = Hash.new { |h, k| h[k] = [] }
    end

    # Fold one CodePoint into the per-property accumulators. No-ops if
    # the cp has no block_id / script_code (e.g. an unassigned cp
    # surfaced through UnicodeData, or a cp outside any fixture range).
    # @param cp [Ucode::Models::CodePoint]
    # @return [void]
    def add(cp)
      push_named(@cps_by_block, cp.block_id, cp.cp)
      push_named(@cps_by_script, cp.script_code, cp.cp)
    end

    # @return [Index]
    def blocks_index
      Index.new(to_entries(@cps_by_block))
    end

    # @return [Index]
    def scripts_index
      Index.new(to_entries(@cps_by_script))
    end

    private

    def push_named(target, name, cp)
      return if name.nil? || name.empty?

      target[name] << cp
    end

    # Flatten {name => [cp, cp, ...]} into Array<RangeEntry>, sorted
    # by first_cp. Within each name, adjacent cps (gap == 1) coalesce.
    def to_entries(cps_by_name)
      cps_by_name.flat_map do |name, cps|
        coalesce(cps).map { |first, last| RangeEntry.new(first, last, name) }
      end
    end

    # Coalesces a sorted cp list into [first, last] runs. cps already
    # arrive sorted (Coordinator yields in ascending cp order), but
    # we sort defensively in case the stream was reordered.
    def coalesce(cps)
      return [] if cps.empty?

      sorted = cps.sort
      runs = []
      first = sorted[0]
      last = sorted[0]

      sorted[1..].each do |cp|
        if cp == last + 1
          last = cp
        else
          runs << [first, last]
          first = cp
          last = cp
        end
      end
      runs << [first, last]
      runs
    end
  end
end
