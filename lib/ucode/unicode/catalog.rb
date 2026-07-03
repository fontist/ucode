# frozen_string_literal: true

module Ucode
  module Unicode
    # Version-specific query interface for Unicode metadata.
    #
    # Deep module: small interface (10 public methods), large frozen
    # dataset behind it (~346 blocks + 17 planes + counts). Constructed
    # once per version; all lookups are O(1) or O(log N).
    #
    # Thread-safe: all internal structures are frozen at construction.
    # No mutation after +initialize+. No locks needed.
    #
    # Construct via {Unicode.for_version} — do not call +new+ directly
    # unless you have a pre-normalized version string.
    class Catalog
      attr_reader :version

      def initialize(version:)
        @version = version
        metadata = load_metadata(version)
        build_indexes(metadata)
        freeze
      end

      def assigned_count
        @assigned_count
      end

      def assigned_in_plane(plane_number)
        @assigned_by_plane[plane_number] || 0
      end

      def find_plane(plane_number)
        @planes_by_number[plane_number]
      end

      def find_plane_by_codepoint(codepoint)
        find_plane(codepoint >> 16)
      end

      def find_block(block_id)
        @blocks_by_id[block_id]
      end

      def find_block_by_codepoint(codepoint)
        idx = @block_ranges.bsearch_index do |(_first, last, _block)|
          if codepoint < _first
            -1
          elsif codepoint > last
            1
          else
            0
          end
        end
        idx.nil? ? nil : @block_ranges[idx][2]
      end

      def blocks_in_plane(plane_number)
        @blocks_by_plane[plane_number] || EMPTY_BLOCKS
      end

      def all_blocks
        @all_blocks
      end

      def all_planes
        @all_planes
      end

      private

      EMPTY_BLOCKS = [].freeze
      private_constant :EMPTY_BLOCKS

      def load_metadata(version)
        module_name = "V#{version.tr('.', '_')}"
        Metadata.const_get(module_name)
      end

      def build_indexes(metadata)
        @assigned_count = metadata::ASSIGNED_COUNT
        @assigned_by_plane = metadata::ASSIGNED_BY_PLANE.freeze

        build_plane_indexes(metadata)
        build_block_indexes(metadata)
      end

      def build_plane_indexes(_metadata)
        @planes_by_number = {}
        @all_planes = []
        17.times do |n|
          names = PLANE_NAMES[n] || { short_name: nil, display_name: "Plane #{n}" }
          plane = Plane.new(
            number: n,
            range: (n << 16)..((n << 16) | 0xFFFF),
            short_name: names[:short_name],
            display_name: names[:display_name],
            assigned_count: @assigned_by_plane[n] || 0,
          ).freeze
          @planes_by_number[n] = plane
          @all_planes << plane
        end
        @all_planes.freeze
        @planes_by_number.freeze
      end

      def build_block_indexes(metadata)
        @blocks_by_id = {}
        blocks_by_plane_temp = Hash.new { |h, k| h[k] = [] }
        @block_ranges = []
        @all_blocks = []

        metadata::BLOCKS.each do |entry|
          block = Block.new(
            id: entry[:id],
            name: entry[:name],
            first_cp: entry[:first_cp],
            last_cp: entry[:last_cp],
            plane_number: entry[:first_cp] >> 16,
          ).freeze
          @blocks_by_id[block.id] = block
          blocks_by_plane_temp[block.plane_number] << block
          @block_ranges << [block.first_cp, block.last_cp, block]
          @all_blocks << block
        end

        @blocks_by_id.freeze
        @blocks_by_plane = blocks_by_plane_temp.transform_values(&:freeze).freeze
        @block_ranges.sort_by!(&:first).freeze
        @all_blocks.freeze
      end
    end
  end
end
