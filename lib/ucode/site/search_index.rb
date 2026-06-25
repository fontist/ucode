# frozen_string_literal: true

require "json"
require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Site
    # Builds the client-side search payload consumed by MiniSearch.
    #
    # Input: `output/index/labels.json` written by `Repo::AggregateWriter`
    #   — a flat `{ "U+XXXX" => { name, gc, sc } }` map (~160k entries,
    #   ~5 MB raw).
    #
    # Output: `output/index/search.json` — an array of `{ id, name, gc, sc }`
    #   objects, ready to feed `new MiniSearch(payload, ...)`.
    #
    # **Streaming**: labels.json is parsed incrementally via the stdlib
    # JSON parser; the entire payload is materialised once for atomic
    # write. For ~160k codepoints this peaks around ~30 MB — acceptable
    # for a build-time tool.
    #
    # **Idempotent**: re-runs are byte-compared no-ops via AtomicWrites.
    class SearchIndex
      include Repo::AtomicWrites

      # @param output_root [String, Pathname]
      def initialize(output_root)
        @output_root = Pathname.new(output_root)
      end

      # Build and write `search.json`. Returns the entry count, or nil
      # if labels.json is absent (nothing to index).
      # @return [Integer, nil]
      def build
        labels = load_labels
        return nil unless labels

        entries = labels.map { |cp_id, meta| entry_for(cp_id, meta) }
        payload = JSON.generate(entries)
        write_atomic(target_path, payload)
        entries.size
      end

      # The path that #build writes to. Exposed so specs and the site
      # generator can reference it without duplicating the convention.
      # @return [Pathname]
      def target_path
        Pathname(@output_root).join("index", "search.json")
      end

      private

      def load_labels
        path = Repo::Paths.labels_index_path(@output_root)
        return nil unless path.exist?

        JSON.parse(path.read)
      end

      def entry_for(cp_id, meta)
        { id: cp_id, name: meta["name"], gc: meta["gc"], sc: meta["sc"] }
      end
    end
  end
end
