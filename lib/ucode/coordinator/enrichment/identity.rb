# frozen_string_literal: true

class Ucode::Coordinator
  module Enrichment
    # Basic identity properties: primary script, script extensions,
    # and the Unicode version when the codepoint was introduced.
    module Identity
      class << self
        def enrich(cp, indices)
          assign_script(cp, indices)
          assign_script_extensions(cp, indices)
          assign_age(cp, indices)
        end

        private

        def assign_script(cp, indices)
          script = RangeLookup.find_in_range(cp.cp, indices.scripts)
          return unless script

          cp.script_code = script.code || script.name
        end

        def assign_script_extensions(cp, indices)
          tuples = indices.script_extensions[cp.cp]
          return unless tuples && !tuples.empty?

          tuples.each { |tuple| cp.script_extensions << tuple.script_code }
        end

        def assign_age(cp, indices)
          record = indices.derived_age[cp.cp]
          return unless record

          cp.age = record.age
        end
      end
    end
  end
end
