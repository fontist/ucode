# frozen_string_literal: true

require "json"
require "pathname"
require "time"

require "ucode/repo/atomic_writes"

module Ucode
  module Repo
    # Emits a flat, per-block Unicode data feed from ucode's canonical
    # output tree. The feed is a denormalized shape: each block file
    # inlines all its codepoints (no joins needed at read time).
    #
    # Three files are emitted under `output_root`:
    #
    #   unicode-blocks.json
    #     [{ start, end, name, unicode_version }, ...]
    #
    #   unicode/blocks/<slug>.json
    #     { chars: [{ cp, n, c, s, cc?, bc?, mir? }, ...] }
    #
    #   unicode-version.json
    #     { version, blockCount, charCount, generatedAt }
    #
    # This emitter reads ucode's canonical output (blocks/index.json,
    # blocks/<ID>/index.json, index/labels.json) and translates shapes.
    # ucode stays canonical; the feed is one-way derived.
    #
    # Block slug algorithm (matches common practice; no consumer
    # assumptions baked in):
    #
    #   name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
    #
    # Block display name uses Unicode's verbatim spacing (e.g.
    # "Basic Latin", "Greek and Coptic") from ucode's canonical name.
    #
    # The shape of this feed is documented in
    # schema/block-feed.output.schema.yml — that YAML is the canonical
    # contract for any consumer of the feed.
    class BlockFeedEmitter
      include AtomicWrites

      # @param ucode_output_root [String, Pathname] ucode's `output/`
      # @param output_root [String, Pathname] target directory;
      #   `unicode-blocks.json`, `unicode-version.json`, and `unicode/`
      #   are written here.
      def initialize(ucode_output_root, output_root)
        @ucode_root = Pathname.new(ucode_output_root)
        @output_root = Pathname.new(output_root)
      end

      # @param ucd_version [String] e.g. "17.0.0"
      # @return [Hash] { blocks_written:, codepoints_written:,
      #   unicode_blocks_path:, unicode_version_path: }
      def emit(ucd_version:)
        labels = load_json(ucode_path("index", "labels.json"))
        blocks_index = load_json(ucode_path("blocks", "index.json"))

        per_block = blocks_index.map do |entry|
          emit_block(entry, labels)
        end

        write_unicode_blocks(per_block)
        version_payload = write_unicode_version(ucd_version, per_block)

        {
          blocks_written: per_block.length,
          codepoints_written: per_block.sum { |b| b[:char_count] },
          unicode_blocks_path: @output_root.join("unicode-blocks.json"),
          unicode_version_path: @output_root.join("unicode-version.json"),
          version: version_payload,
        }
      end

      private

      def emit_block(entry, labels)
        block_id = entry["id"]
        block_file = load_json(ucode_path("blocks", block_id, "index.json"))
        chars = chars_for(block_file["codepoint_ids"] || [], labels)
        slug = block_slug(entry["name"])

        write_block_file(slug, chars)

        {
          slug: slug,
          char_count: chars.length,
          summary: {
            "start" => entry["first_cp"],
            "end" => entry["last_cp"],
            "name" => entry["name"],
            "unicode_version" => entry["age"] || block_file["age"] || "1.1",
          },
        }
      end

      def chars_for(codepoint_ids, labels)
        codepoint_ids.map do |cp_id|
          label = labels[cp_id] || {}
          {
            "cp" => cp_id_to_i(cp_id),
            "n" => label["name"],
            "c" => label["gc"],
            "s" => label["sc"],
            "cc" => label["cc"],
            "bc" => label["bc"],
            "mir" => label["mir"],
          }.reject { |_, v| v.nil? || v == "" }
        end
      end

      def write_block_file(slug, chars)
        path = @output_root.join("unicode", "blocks", "#{slug}.json")
        write_atomic(path, to_pretty_json("chars" => chars))
      end

      def write_unicode_blocks(per_block)
        path = @output_root.join("unicode-blocks.json")
        summaries = per_block.map { |b| b[:summary] }
        write_atomic(path, to_pretty_json(summaries))
      end

      def write_unicode_version(ucd_version, per_block)
        payload = {
          "version" => ucd_version,
          "blockCount" => per_block.length,
          "charCount" => per_block.sum { |b| b[:char_count] },
          "generatedAt" => Time.now.utc.iso8601,
        }
        path = @output_root.join("unicode-version.json")
        write_atomic(path, to_pretty_json(payload))
        payload
      end

      def block_slug(name)
        name.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")
      end

      def cp_id_to_i(cp_id)
        cp_id.to_s.sub(/^U\+/i, "").to_i(16)
      end

      def ucode_path(*parts)
        @ucode_root.join(*parts)
      end

      def load_json(path)
        JSON.parse(path.read)
      end
    end
  end
end
