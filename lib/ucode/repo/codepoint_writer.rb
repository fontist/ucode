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
    class CodepointWriter
      include AtomicWrites

      # @param output_root [String, Pathname]
      # @param parallel_workers [Integer] size of the worker pool. Set to
      #   1 (or less) to run synchronously — useful in tests.
      def initialize(output_root, parallel_workers: 8)
        @output_root = Pathname.new(output_root)
        @parallel_workers = parallel_workers
      end

      # Write one codepoint synchronously.
      # @param codepoint [Ucode::Models::CodePoint]
      # @return [Pathname, nil] the path written, or nil if skipped
      #   (missing block_id or content-identical to existing file)
      def write(codepoint)
        return nil if codepoint.block_id.nil?

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
    end
  end
end
