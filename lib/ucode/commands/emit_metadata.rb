# frozen_string_literal: true

require "pathname"

module Ucode
  module Commands
    # `ucode emit-metadata` — generates frozen Ruby metadata modules
    # from cached UCD text files.
    #
    # Run after `ucode fetch ucd <version>` to produce the metadata
    # module that ships with the gem. The output is written to
    # `lib/ucode/unicode/metadata/<vXX_Y_Z>.rb` and must be committed.
    class EmitMetadataCommand
      # @param version [String] e.g. "17.0.0"
      # @param gem_root [String, Pathname, nil] gem root for output path
      #   resolution; defaults to the conventional location.
      # @return [Hash] { version:, path:, bytes:, blocks:, assigned_count: }
      def call(version, gem_root: nil)
        ucd_dir = Cache.ucd_dir(version)
        raise Ucode::Error, "UCD not cached for #{version}. Run: ucode fetch ucd #{version}" unless ucd_dir.exist?

        source = Ucode::Unicode::MetadataWriter.generate(
          ucd_dir: ucd_dir, version: version,
        )

        out_path = resolve_output_path(version, gem_root)
        write_atomic(out_path, source)

        metadata = Ucode::Unicode::MetadataWriter
        metadata.version_to_module(version)
        {
          version: version,
          path: out_path.to_s,
          bytes: source.bytesize,
        }
      end

      private

      def resolve_output_path(version, gem_root)
        filename = Ucode::Unicode::MetadataWriter.version_to_filename(version)
        base = gem_root ? Pathname.new(gem_root) : default_gem_root
        dir = base.join("lib", "ucode", "unicode", "metadata")
        dir.mkpath unless dir.exist?
        dir.join("#{filename}.rb")
      end

      def default_gem_root
        Pathname.new(__dir__).join("..", "..", "..")
      end

      def write_atomic(path, content)
        return if path.exist? && path.read == content

        path.dirname.mkpath
        tmp = path.sub_ext(".rb.tmp")
        tmp.write(content)
        tmp.rename(path.to_s)
      end
    end
  end
end
