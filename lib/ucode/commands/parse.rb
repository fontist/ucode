# frozen_string_literal: true

require "pathname"

require "ucode/cache"
require "ucode/coordinator"
require "ucode/parsers"
require "ucode/repo"

module Ucode
  module Commands
    # `ucode parse` — streams the Coordinator output into the on-disk
    # JSON tree at `output/`. Single pass: enrich + write per-cp JSON +
    # accumulate aggregates + final flush.
    #
    # Takes a resolved version string; CLI callers resolve via
    # {VersionResolver.resolve} once and thread it through. See
    # Candidate 4 of the 2026-06-29 architecture review.
    class ParseCommand
      # @param version [String] resolved UCD version
      # @param output_root [String, Pathname]
      # @return [Hash] { version:, codepoint_count: }
      def call(version, output_root:)
        root = Pathname.new(output_root)
        ucd_dir = Cache.ucd_dir(version)
        unihan_dir = Cache.unihan_dir(version)

        coordinator = Coordinator.new
        codepoint_writer = Repo::CodepointWriter.new(root, parallel_workers: workers)
        aggregate = Repo::AggregateWriter.new(root)
        indices_holder = nil

        coordinator.each_codepoint_with_indices(ucd_dir: ucd_dir, unihan_dir: unihan_dir) do |indices, cp|
          indices_holder ||= indices
          codepoint_writer.write(cp)
          aggregate.add(cp)
        end

        aggregate.flush(
          ucd_version: version,
          indices: indices_holder || coordinator.indices_for(ucd_dir: ucd_dir, unihan_dir: unihan_dir),
          property_aliases: load_records(ucd_dir, "PropertyAliases.txt", Parsers::PropertyAliases),
          property_value_aliases: load_records(ucd_dir, "PropertyValueAliases.txt", Parsers::PropertyValueAliases),
          named_sequences: load_records(ucd_dir, "NamedSequences.txt", Parsers::NamedSequences),
        )

        { version: version, codepoint_count: aggregate.codepoint_count }
      end

      private

      def workers
        Ucode.configuration.parallel_workers
      end

      def load_records(ucd_dir, filename, parser)
        path = ucd_dir.join(filename)
        return [] unless path.exist?

        parser.each_record(path).to_a
      end
    end
  end
end
