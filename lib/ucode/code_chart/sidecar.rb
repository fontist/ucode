# frozen_string_literal: true

require "json"
require "pathname"

require "ucode/repo/atomic_writes"

module Ucode
  module CodeChart
    # Writes a {Provenance} to disk as the sidecar JSON next to its
    # corresponding SVG.
    #
    # Path: `<output_root>/<codepoint>.json` — colocated with the
    # SVG so a downstream consumer can find both files by a single
    # directory listing.
    #
    # Idempotent via {Ucode::Repo::AtomicWrites#write_atomic}: a
    # re-write of byte-identical content is a no-op (no temp-file
    # rename). Provenance JSON is canonical (sorted keys via Ruby's
    # stdlib JSON), so the byte-equality test is sound.
    class Sidecar
      include Ucode::Repo::AtomicWrites

      # @param output_root [Pathname, String] directory the SVG +
      #   sidecar live in. Parent directories are created on demand.
      def initialize(output_root:)
        @output_root = Pathname.new(output_root)
      end

      # @param provenance [Ucode::CodeChart::Provenance]
      # @return [Pathname] the written sidecar path
      def write(provenance)
        path = path_for(provenance)
        payload = "#{JSON.pretty_generate(provenance.to_h)}\n"
        write_atomic(path, payload)
        path
      end

      # @param codepoint_id [String] e.g. "U+10920"
      # @return [Pathname] the would-be path for a sidecar
      def path_for_id(codepoint_id)
        @output_root.join("#{codepoint_id}.json")
      end

      private

      def path_for(provenance)
        path_for_id(provenance.codepoint)
      end
    end
  end
end
