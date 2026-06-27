# frozen_string_literal: true

require "pathname"
require "thread"

require "ucode/repo/atomic_writes"
require "ucode/repo/paths"

module Ucode
  module Repo
    # Writes one `index.json` per codepoint under `output/blocks/<id>/<cp>/`.
    #
    # Streaming + threaded + idempotent:
    #
    #   - **Streaming**: callers pass an Enumerator; the writer pulls one
    #     codepoint at a time, never the full 160k set in memory.
    #   - **Threaded**: a fixed-size worker pool drains a shared queue.
    #     Each codepoint maps to a unique path → no per-file contention.
    #   - **Idempotent**: existing files are byte-compared to the new
    #     payload before writing; identical content is a no-op. Safe to
    #     re-run on the full dataset.
    #   - **Atomic**: writes go to `<path>.tmp`, then rename. A crash
    #     mid-write leaves either the old file or no file, never a
    #     truncated one.
    #
    # When a {Ucode::Glyphs::Resolver} is supplied via `resolver:`, each
    # write also resolves the codepoint's glyph, writes `glyph.svg`
    # alongside `index.json` (same atomic + idempotent semantics), and
    # records the resolver tier + provenance on the codepoint's `glyph`
    # attribute so it lands in the serialized JSON. When `resolver:` is
    # nil (default), the writer is glyph-agnostic and only writes
    # `index.json` — preserving backward compatibility.
    class CodepointWriter
      include AtomicWrites

      # @param output_root [String, Pathname]
      # @param parallel_workers [Integer] size of the worker pool. Set to
      #   1 (or less) to run synchronously — useful in tests.
      # @param resolver [Ucode::Glyphs::Resolver, nil] when non-nil, each
      #   write resolves the codepoint's glyph via this resolver and
      #   writes `glyph.svg` next to `index.json`. Sources inside the
      #   resolver must be safe for concurrent access — the worker pool
      #   calls into them from multiple threads.
      def initialize(output_root, parallel_workers: 8, resolver: nil)
        @output_root = Pathname.new(output_root)
        @parallel_workers = parallel_workers
        @resolver = resolver
      end

      # Write one codepoint synchronously.
      # @param codepoint [Ucode::Models::CodePoint]
      # @return [Pathname, nil] the path written, or nil if skipped
      #   (missing block_id or content-identical to existing file)
      def write(codepoint)
        return nil if codepoint.block_id.nil?

        resolve_glyph!(codepoint) if @resolver

        path = Paths.codepoint_json_path(@output_root, codepoint.block_id, codepoint.id)
        payload = serialize(codepoint)
        return nil unless write_atomic(path, payload)

        path
      end

      # Drain an Enumerator through the worker pool. Returns the total
      # count of codepoints seen (whether or not each one was written).
      # @param enum [Enumerator<Ucode::Models::CodePoint>, Enumerable]
      # @return [Integer]
      def write_each(enum)
        return drain_inline(enum) if @parallel_workers <= 1

        drain_threaded(enum)
      end

      private

      def drain_inline(enum)
        count = 0
        enum.each { |cp| write(cp); count += 1 }
        count
      end

      def drain_threaded(enum)
        queue = Queue.new
        mutex = Mutex.new
        count = 0

        workers = Array.new(@parallel_workers) do
          Thread.new do
            loop do
              cp = queue.pop
              break if cp.nil?

              write(cp)
              mutex.synchronize { count += 1 }
            end
          end
        end

        enum.each { |cp| queue << cp }
        @parallel_workers.times { queue << nil }
        workers.each(&:join)
        count
      end

      def serialize(codepoint)
        codepoint.to_json(pretty: true)
      end

      def resolve_glyph!(codepoint)
        result = @resolver.resolve(codepoint.cp)
        codepoint.glyph = build_glyph_bundle(result)
        return unless result

        path = Paths.codepoint_glyph_path(@output_root, codepoint.block_id, codepoint.id)
        write_atomic(path, result.svg)
      end

      def build_glyph_bundle(result)
        return nil unless result

        Ucode::Models::CodePoint::Glyph.new(
          svg_path: Paths.glyph_filename,
          source: Ucode::Models::CodePoint::Glyph::Source.new(
            tier: result.tier.to_s,
            provenance: result.provenance,
          ),
        )
      end
    end
  end
end
