# frozen_string_literal: true

require "pathname"
require "ucode/repo/atomic_writes"

module Ucode
  module Repo
    module Writers
      # Writes one file per named sequence under
      # `output/named_sequences/<slug>.json`. Empty input writes nothing.
      #
      # One of the eight per-concern writers split out from
      # AggregateWriter — see Candidate 5 of the 2026-06-29 review.
      class NamedSequencesWriter
        include AtomicWrites

        # @param output_root [Pathname]
        # @param named_sequences [Array<Ucode::Models::NamedSequence>]
        def initialize(output_root:, named_sequences:)
          @output_root = output_root
          @named_sequences = named_sequences
        end

        # @return [Integer] number of named-sequence files written
        def write
          return 0 if @named_sequences.nil? || @named_sequences.empty?

          dir = Pathname(@output_root).join("named_sequences")
          @named_sequences.sum do |ns|
            path = dir.join("#{slug_for(ns)}.json")
            write_atomic(path, ns.to_json(pretty: true)) ? 1 : 0
          end
        end

        private

        # Slug derived from the name: downcase, non-alphanumerics → "_".
        def slug_for(named_sequence)
          named_sequence.name
            .downcase
            .gsub(/[^a-z0-9]+/, "_")
            .gsub(/^_+|_+$/, "")
        end
      end
    end
  end
end