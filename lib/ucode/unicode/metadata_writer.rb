# frozen_string_literal: true

require "pathname"

module Ucode
  module Unicode
    # Generates frozen Ruby metadata modules from UCD text files.
    #
    # Pure logic: takes a UCD directory path and a version string,
    # returns the Ruby source for a metadata module. The CLI command
    # (EmitMetadataCommand) writes the output to disk.
    #
    # This is the build-time tool that produces the frozen constants
    # consumers query at runtime via {Catalog}. Run it when a new
    # Unicode version is adopted:
    #
    #   bin/ucode fetch ucd 18.0.0
    #   bin/ucode emit-metadata --version 18.0.0
    #   # commit the generated file + add to SUPPORTED_VERSIONS
    #
    module MetadataWriter
      EXCLUDED_GC = %w[Cn Co Cs].freeze
      private_constant :EXCLUDED_GC

      module_function

      # @param ucd_dir [String, Pathname] path to the unpacked UCD
      # @param version [String] e.g. "17.0.0"
      # @return [String] Ruby source for the metadata module
      def generate(ucd_dir:, version:)
        assigned_count, by_plane = compute_assigned(ucd_dir)
        blocks = parse_blocks(ucd_dir)
        mod_name = version_to_module(version)

        build_source(version: version, mod_name: mod_name,
                     assigned_count: assigned_count,
                     by_plane: by_plane, blocks: blocks)
      end

      # @param version [String] e.g. "17.0.0"
      # @return [String] e.g. "v17_0_0"
      def version_to_filename(version)
        "v#{version.tr('.', '_').downcase}"
      end

      # @param version [String] e.g. "17.0.0"
      # @return [String] e.g. "V17_0_0"
      def version_to_module(version)
        "V#{version.tr('.', '_')}"
      end

      # ---- Internal: data extraction -----------------------------------

      def compute_assigned(ucd_dir)
        count = 0
        by_plane = Hash.new(0)
        path = Pathname.new(ucd_dir).join("extracted", "DerivedGeneralCategory.txt")

        File.foreach(path) do |line|
          next if line.start_with?("#") || line.strip.empty?

          m = line.match(/^([0-9A-Fa-f]+)(?:\.\.([0-9A-Fa-f]+))?\s*;\s*(\w+)/)
          next unless m
          next if EXCLUDED_GC.include?(m[3])

          first = m[1].to_i(16)
          last = m[2] ? m[2].to_i(16) : first
          n = last - first + 1
          count += n
          by_plane[first >> 16] += n
        end

        [count, by_plane]
      end
      private_class_method :compute_assigned

      def parse_blocks(ucd_dir)
        path = Pathname.new(ucd_dir).join("Blocks.txt")
        blocks = []

        File.foreach(path) do |line|
          next if line.start_with?("#") || line.strip.empty?

          m = line.match(/^([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+)\s*;\s*(.+)/)
          next unless m

          name = m[3].strip
          blocks << {
            id: name.gsub(/\s+/, "_"),
            name: name,
            first_cp: m[1].to_i(16),
            last_cp: m[2].to_i(16),
          }
        end

        blocks
      end
      private_class_method :parse_blocks

      # ---- Internal: source generation ---------------------------------

      def build_source(version:, mod_name:, assigned_count:, by_plane:, blocks:)
        lines = []
        lines << "# frozen_string_literal: true"
        lines << ""
        lines << "# AUTO-GENERATED from UCD #{version}. Do not edit by hand."
        lines << "# Regenerate via: bin/ucode emit-metadata --version #{version}"
        lines << "# rubocop:disable all"
        lines << ""
        lines << "module Ucode"
        lines << "  module Unicode"
        lines << "    module Metadata"
        lines << "      module #{mod_name}"
        lines << "        UNICODE_VERSION = \"#{version}\""
        lines << "        ASSIGNED_COUNT = #{assigned_count}"
        lines << ""
        lines << "        ASSIGNED_BY_PLANE = {"
        by_plane.sort.each { |p, n| lines << "          #{p} => #{n}," }
        lines << "        }.freeze"
        lines << ""
        lines << "        BLOCKS = ["
        blocks.each do |b|
          lines << "          { id: \"#{b[:id]}\", name: \"#{b[:name]}\", first_cp: #{b[:first_cp]}, last_cp: #{b[:last_cp]} },"
        end
        lines << "        ].freeze"
        lines << "      end"
        lines << "    end"
        lines << "  end"
        lines << "end"
        lines << "# rubocop:enable all"
        "#{lines.join("\n")}\n"
      end
      private_class_method :build_source
    end
  end
end
