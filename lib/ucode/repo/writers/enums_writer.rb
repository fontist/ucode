# frozen_string_literal: true

require "pathname"
require "ucode/repo/atomic_writes"

module Ucode
  module Repo
    module Writers
      # Writes `output/enums.json` carrying the full property-alias
      # and property-value-alias tables.
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class EnumsWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param property_aliases [Array<Ucode::Models::PropertyAlias>]
        # @param property_value_aliases [Array<Ucode::Models::PropertyValueAlias>]
        def initialize(output_root:, property_aliases:, property_value_aliases:)
          @output_root = output_root
          @property_aliases = property_aliases
          @property_value_aliases = property_value_aliases
        end

        # @return [Integer] 1 if written, 0 otherwise
        def write
          path = Pathname(@output_root).join("enums.json")
          payload = {
            "properties" => @property_aliases.map(&:to_yaml_hash),
            "property_values" => @property_value_aliases.map(&:to_yaml_hash),
          }
          write_atomic(path, to_pretty_json(payload)) ? 1 : 0
        end
      end
    end
  end
end
