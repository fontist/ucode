# frozen_string_literal: true

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes `output/planes/<n>.json` for every plane (0..16).
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class PlanesWriter
        include AtomicWrites

        # Static metadata for the 17 Unicode planes. Planes 4–13 are
        # unassigned in Unicode 17; their entries use placeholder names.
        PLANE_TABLE = {
          0 => ["Basic Multilingual Plane",            "BMP"],
          1 => ["Supplementary Multilingual Plane",    "SMP"],
          2 => ["Supplementary Ideographic Plane",     "SIP"],
          3 => ["Tertiary Ideographic Plane",          "TIP"],
          4 => ["Unassigned Plane 4",                  "—"],
          5 => ["Unassigned Plane 5",                  "—"],
          6 => ["Unassigned Plane 6",                  "—"],
          7 => ["Unassigned Plane 7",                  "—"],
          8 => ["Unassigned Plane 8",                  "—"],
          9 => ["Unassigned Plane 9",                  "—"],
          10 => ["Unassigned Plane 10",                 "—"],
          11 => ["Unassigned Plane 11",                 "—"],
          12 => ["Unassigned Plane 12",                 "—"],
          13 => ["Unassigned Plane 13",                 "—"],
          14 => ["Supplementary Special-purpose Plane", "SSP"],
          15 => ["Supplementary Private Use Area-A",    "SPUA-A"],
          16 => ["Supplementary Private Use Area-B",    "SPUA-B"],
        }.freeze
        private_constant :PLANE_TABLE

        # @param output_root [Pathname]
        # @param blocks [Array<Ucode::Models::Block>]
        def initialize(output_root:, blocks:)
          @output_root = output_root
          @blocks = blocks
        end

        # @return [Integer] number of plane files written (always 17
        #   when the directory is reachable; one per plane number)
        def write
          plane_block_ids = group_block_ids_by_plane
          count = 0
          (0..16).each do |n|
            path = Paths.plane_metadata_path(@output_root, n)
            count += 1 if write_atomic(path, plane_payload(n, plane_block_ids[n] || []))
          end
          count
        end

        private

        def group_block_ids_by_plane
          @blocks.each_with_object(Hash.new { |h, k| h[k] = [] }) do |block, h|
            h[block.plane_number] << block.id
          end
        end

        def plane_payload(plane_number, block_ids)
          name, abbrev = PLANE_TABLE.fetch(plane_number)
          range_first = plane_number * 0x10000
          range_last  = range_first + 0xFFFF
          to_pretty_json(
            "number" => plane_number,
            "name" => name,
            "abbrev" => abbrev,
            "range_first" => range_first,
            "range_last" => range_last,
            "block_ids" => block_ids,
          )
        end
      end
    end
  end
end
