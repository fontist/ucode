# frozen_string_literal: true

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes `output/scripts/<code>.json` for every assigned script.
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class ScriptsWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param scripts [Array<Ucode::Models::Script>] from
        #   Coordinator::Indices
        # @param script_codepoint_ids [Hash{String => Array<String>}]
        #   ISO 15924 code → cp_id list, accumulated during the
        #   streaming pass
        def initialize(output_root:, scripts:, script_codepoint_ids:)
          @output_root = output_root
          @scripts = scripts
          @script_codepoint_ids = script_codepoint_ids
        end

        # @return [Integer] number of script files written
        def write
          count = 0
          @scripts.group_by(&:code).each do |code, ranges|
            next if code.nil? || code.empty?

            path = Paths.script_metadata_path(@output_root, code)
            count += 1 if write_atomic(path, script_payload(code, ranges))
          end
          count
        end

        private

        def script_payload(code, ranges)
          to_pretty_json(
            "code"           => code,
            "name"           => ranges.first&.name,
            "range_first"    => ranges.map(&:range_first).min,
            "range_last"     => ranges.map(&:range_last).max,
            "codepoint_ids"  => (@script_codepoint_ids[code] || []),
          )
        end
      end
    end
  end
end