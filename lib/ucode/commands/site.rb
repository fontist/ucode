# frozen_string_literal: true

require "pathname"

require "ucode/site"
require "ucode/version_resolver"

module Ucode
  module Commands
    # `ucode site` — init the Vitepress scaffold + build config/pages
    # from the current `output/` tree. Two subactions.
    class SiteCommand
      # @param site_root [String, Pathname]
      # @return [Hash] { files_copied: }
      def init(site_root:)
        root = Pathname.new(site_root)
        count = Site::Generator.new(output_root: "/", site_root: root).init
        { files_copied: count }
      end

      # @param output_root [String, Pathname]
      # @param site_root [String, Pathname]
      # @return [Hash] the Generator's build tally
      def build(output_root:, site_root:, **_unused)
        gen = Site::Generator.new(
          output_root: Pathname.new(output_root),
          site_root: Pathname.new(site_root),
        )
        gen.build
      end
    end
  end
end
