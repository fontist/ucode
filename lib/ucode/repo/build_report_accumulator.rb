# frozen_string_literal: true

require "time"

require "ucode/models/build_report"

module Ucode
  module Repo
    # Observes {CodepointWriter} and tallies per-tier + per-block
    # statistics for the canonical build report (TODO 21).
    #
    # Wire as the `observer:` kwarg on {CodepointWriter}:
    #
    #   accumulator = BuildReportAccumulator.new(unicode_version: "17.0.0")
    #   writer = CodepointWriter.new(root, resolver: resolver, observer: accumulator)
    #   coordinator.each_codepoint { |cp| writer.write(cp) }
    #   report = accumulator.to_report
    #
    # The accumulator is thread-safe — the writer's worker pool calls
    # `#call` from multiple threads.
    #
    # == Semantics
    #
    # `assigned` counts every codepoint the writer attempted (passed
    # the block_id guard). `built` counts codepoints whose resolver
    # returned a glyph. `skipped` counts codepoints that resolved to
    # nil (no tier produced a glyph). `failed` counts exceptions
    # recorded via {#record_failure} (the writer rescues nothing;
    # the orchestrating command decides what to surface).
    #
    # `by_tier` counts ONLY the winning tier per codepoint (not the
    # overlap semantics mentioned in TODO 21's example). TODO 21
    # notes the overlap counts as descriptive; the per-codepoint
    # winning tier is the load-bearing number for validation.
    class BuildReportAccumulator
      TIER_TO_WIRE = {
        tier1: "tier-1",
        pillar1: "pillar-1",
        pillar2: "pillar-2",
        pillar3: "pillar-3",
      }.freeze
      private_constant :TIER_TO_WIRE

      # @param unicode_version [String]
      # @param ucode_version [String]
      def initialize(unicode_version:, ucode_version:)
        @unicode_version = unicode_version
        @ucode_version = ucode_version
        @totals = { assigned: 0, built: 0, skipped: 0, failed: 0 }
        @by_tier = Hash.new(0)
        @by_block = Hash.new do |h, name|
          h[name] = { assigned: 0, built: 0, tier_breakdown: Hash.new(0) }
        end
        @failures = []
        @mutex = Mutex.new
      end

      # Observer entry point — invoked by {CodepointWriter#write} as
      # `observer.call(codepoint, result)`. Records one attempt.
      #
      # @param codepoint [Ucode::Models::CodePoint]
      # @param result [Ucode::Glyphs::Source::Result, nil]
      # @return [void]
      def call(codepoint, result)
        synchronize do
          @totals[:assigned] += 1
          block_stats = @by_block[codepoint.block_id]
          block_stats[:assigned] += 1

          if result
            @totals[:built] += 1
            tier = wire_tier(result.tier)
            @by_tier[tier] += 1
            block_stats[:built] += 1
            block_stats[:tier_breakdown][tier] += 1
          else
            @totals[:skipped] += 1
          end
        end
      end

      # Record an exception encountered while building a codepoint.
      # The orchestrating command calls this when rescuing around
      # writer.write; the writer itself does not rescue.
      #
      # @param codepoint [Ucode::Models::CodePoint, nil]
      # @param error [StandardError]
      # @param tier [Symbol, nil] resolver tier that raised, if known
      # @return [void]
      def record_failure(codepoint, error, tier: nil)
        synchronize do
          @totals[:failed] += 1
          @failures << Ucode::Models::BuildReport::Failure.new(
            codepoint: codepoint&.cp,
            block_name: codepoint&.block_id,
            tier: tier&.to_s,
            error_class: error.class.name,
            message: error.message,
            backtrace: Array(error.backtrace).first(10),
          )
        end
      end

      # Build the immutable {Ucode::Models::BuildReport} snapshot.
      # @return [Ucode::Models::BuildReport]
      def to_report
        synchronize do
          Ucode::Models::BuildReport.new(
            unicode_version: @unicode_version,
            ucode_version: @ucode_version,
            generated_at: Time.now.utc.iso8601,
            totals: Ucode::Models::BuildReport::Totals.new(@totals),
            by_tier: @by_tier.dup,
            by_block: @by_block.map do |name, stats|
              Ucode::Models::BuildReport::BlockSummary.new(
                name: name,
                assigned: stats[:assigned],
                built: stats[:built],
                tier_breakdown: stats[:tier_breakdown].dup,
              )
            end,
            failures: @failures.dup,
          )
        end
      end

      private

      def wire_tier(symbol)
        TIER_TO_WIRE.fetch(symbol, symbol.to_s)
      end

      def synchronize(&)
        @mutex.synchronize(&)
      end
    end
  end
end
