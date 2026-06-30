# frozen_string_literal: true

require "pathname"
require "ucode/coordinator"
require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    module Writers
      # Writes one file per relationship table under
      # `output/relationships/`. The set of tables is enumerated by
      # `Coordinator::Indices#each_relationship` (see Candidate 1 of the
      # 2026-06-29 review).
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class RelationshipsWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param indices [Ucode::Coordinator::Indices]
        def initialize(output_root:, indices:)
          @output_root = output_root
          @indices = indices
        end

        # @return [Integer] number of relationship files written
        def write
          @indices.each_relationship.sum do |slug, records|
            write_relationship_file(slug, records)
          end
        end

        private

        def write_relationship_file(slug, records)
          return 0 if records.nil? || records.empty?

          path = Pathname(@output_root).join("relationships", "#{slug}.json")
          write_atomic(path, relationship_payload(records)) ? 1 : 0
        end

        # records is Hash<Integer, Record>, Hash<Integer, Array<Record>>,
        # Hash<String, Record>, or Hash<String, Array<Record>>.
        def relationship_payload(records)
          payload = records.each_with_object({}) do |(key, value), h|
            h[key_to_cp_id(key)] = serialize_value(value)
          end
          to_pretty_json(payload)
        end

        # Integer codepoint keys are formatted as "U+XXXX"; string id
        # keys (cjk_radicals, standardized_variants) pass through.
        def key_to_cp_id(key)
          key.is_a?(Integer) ? Paths.cp_id(key) : key
        end

        def serialize_value(value)
          return value.map { |v| serialize_one(v) } if value.is_a?(Array)

          serialize_one(value)
        end

        def serialize_one(record)
          record.to_yaml_hash
        end
      end
    end
  end
end
