# frozen_string_literal: true

require "json"
require "pathname"
require "time"

require "ucode/repo/atomic_writes"

module Ucode
  module Repo
    # Emits the fontist.org-shaped Unicode data feed from ucode's
    # canonical output tree. fontist.org's `src/lib/unicode/data/loader.ts`
    # consumes three files at build time:
    #
    #   public/unicode-blocks.json
    #     [{ start, end, name, unicode_version }, ...]
    #
    #   public/unicode/blocks/<slug>.json
    #     { chars: [{ cp, n, c, s }, ...] }
    #
    #   public/unicode-version.json
    #     { version, blockCount, charCount, generatedAt }
    #
    # This emitter reads ucode's canonical output (blocks/index.json,
    # blocks/<ID>.json, index/labels.json) and translates shapes.
    # ucode stays canonical; the adapter is one-way.
    #
    # Block slug algorithm matches fontist.org's `blockSlug()` in
    # `src/lib/unicode/constants.ts`:
    #
    #   name.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "")
    #
    # Block display name replaces ucode's verbatim underscores (e.g.
    # "Basic_Latin") with the spaces fontist.org expects ("Basic Latin").
    class FontistConsumerEmitter
      include AtomicWrites

      # @param ucode_output_root [String, Pathname] ucode's `output/`
      # @param fontist_output_root [String, Pathname] target directory;
      #   `unicode-blocks.json`, `unicode-version.json`, and `unicode/`
      #   are written here.
      def initialize(ucode_output_root, fontist_output_root)
        @ucode_root = Pathname.new(ucode_output_root)
        @fontist_root = Pathname.new(fontist_output_root)
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
          unicode_blocks_path: @fontist_root.join("unicode-blocks.json"),
          unicode_version_path: @fontist_root.join("unicode-version.json"),
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
          }.reject { |_, v| v.nil? || v == "" }
        end
      end

      def write_block_file(slug, chars)
        path = @fontist_root.join("unicode", "blocks", "#{slug}.json")
        write_atomic(path, to_pretty_json("chars" => chars))
      end

      def write_unicode_blocks(per_block)
        path = @fontist_root.join("unicode-blocks.json")
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
        path = @fontist_root.join("unicode-version.json")
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
