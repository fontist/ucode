# frozen_string_literal: true

require "fileutils"
require "find"
require "json"
require "pathname"

require "ucode/repo/atomic_writes"
require "ucode/site/config_emitter"
require "ucode/site/search_index"

module Ucode
  module Site
    # Orchestrates `ucode site init` and `ucode site build`.
    #
    # **init** copies the static Vitepress template from
    # `lib/ucode/site/template/` into the user's `site/`. The template
    # ships package.json, theme, and the dynamic route components
    # (`char/[codepoint].vue`, `block/[id].vue`, `plane/[n].md` stub).
    #
    # **build** regenerates only the parts that depend on the dataset:
    #   - `.vitepress/config.ts`           — ConfigEmitter
    #   - `public/data/`                   — symlinked or copied from `output/`
    #   - `public/data/index/search.json`  — SearchIndex
    #   - `plane/<n>.md`                   — one thin stub per plane (frontmatter)
    #   - `block/<id>.md`                  — one thin stub per block
    #
    # Static pages are markdown stubs that mount a Vue component; the
    # component fetches the JSON for that plane/block at runtime. This
    # keeps the generator cheap (~363 small writes) and the per-character
    # route dynamic (~160k static pages is infeasible).
    #
    # **Idempotent**: every write goes through AtomicWrites.
    class Generator
      include Repo::AtomicWrites

      TemplateDir = File.expand_path("template", __dir__).freeze
      private_constant :TemplateDir

      # @param output_root [String, Pathname] dataset root (read)
      # @param site_root [String, Pathname] Vitepress project root (write)
      def initialize(output_root:, site_root:)
        @output_root = Pathname.new(output_root)
        @site_root = Pathname.new(site_root)
      end

      # Copy the static template into `site_root`. No-op for any file
      # that already exists with identical content (AtomicWrites).
      # @return [Integer] number of files written
      def init
        count = 0
        each_template_file do |src, rel|
          dst = @site_root.join(rel)
          count += 1 if write_atomic(dst, src.read)
        end
        count
      end

      # Regenerate config + pages + search index from the current
      # `output/` tree. Returns a tally of what changed.
      # @return [Hash{Symbol => Integer}]
      def build
        tally = { config: 0, pages: 0, search: 0, data_link: 0 }

        tally[:config] = config_emitter.emit ? 1 : 0
        tally[:pages] = write_pages
        tally[:search] = search_index.build ? 1 : 0
        tally[:data_link] = link_data_dir ? 1 : 0

        tally
      end

      private

      def config_emitter
        ConfigEmitter.new(output_root: @output_root, site_root: @site_root)
      end

      def search_index
        SearchIndex.new(@output_root)
      end

      # Walk TemplateDir, yielding (src_path, relative_path) for each file.
      def each_template_file(&block)
        return unless Dir.exist?(TemplateDir)

        Find.find(TemplateDir) do |src|
          next if File.directory?(src)

          rel = Pathname.new(src).relative_path_from(Pathname.new(TemplateDir))
          yield Pathname.new(src), rel
        end
      end

      # Write plane and block markdown stubs from the output tree.
      def write_pages
        count  = 0
        count += write_plane_pages
        count += write_block_pages
        count
      end

      def write_plane_pages
        planes_dir = @output_root.join("planes")
        return 0 unless planes_dir.directory?

        planes_dir.children.sort.sum do |path|
          next 0 unless path.file? && path.extname == ".json"

          plane = JSON.parse(path.read)
          n = plane["number"]
          next 0 unless n

          payload = plane_md(n)
          write_atomic(@site_root.join("plane", "#{n}.md"), payload) ? 1 : 0
        end
      end

      def write_block_pages
        blocks = read_json_list(@output_root.join("blocks", "index.json"))
        blocks.sum do |block|
          id = block["id"]
          next 0 unless id

          payload = block_md(id)
          write_atomic(@site_root.join("block", "#{id}.md"), payload) ? 1 : 0
        end
      end

      def read_json_list(path)
        return [] unless path&.exist?

        JSON.parse(path.read)
      end

      def plane_md(plane_number)
        <<~MD
          ---
          layout: plane
          title: "Plane #{plane_number}"
          plane: #{plane_number}
          ---

          <PlaneView plane="#{plane_number}" />
        MD
      end

      def block_md(block_id)
        <<~MD
          ---
          layout: block
          title: "#{block_id}"
          block: "#{block_id}"
          ---

          <BlockView block="#{block_id}" />
        MD
      end

      # Vitepress serves `site/public/` at the site root. Symlink the
      # dataset into `public/data/` so the Vue components can fetch
      # `/data/...` URLs. Falls back to a recursive copy on filesystems
      # that don't support symlinks.
      def link_data_dir
        link = @site_root.join("public", "data")
        return 0 if link.symlink? && link.dirname.exist?

        link.dirname.mkpath
        begin
          File.symlink(@output_root.relative_path_from(link.dirname).to_s, link.to_s)
        rescue SystemCallError
          FileUtils.cp_r(@output_root, link)
        end
        1
      end
    end
  end
end
