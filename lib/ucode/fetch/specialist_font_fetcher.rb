# frozen_string_literal: true

require "digest"
require "fileutils"
require "pathname"
require "tmpdir"
require "zip"

require "ucode/error"
require "ucode/fetch/font_fetcher"
require "ucode/fetch/http"
require "ucode/models/specialist_font_manifest"

module Ucode
  module Fetch
    # Concrete font fetcher: walks a {Models::SpecialistFontManifest}
    # and materializes each font's `path` on disk.
    #
    # Behavior (per acceptance in TODO 30):
    #
    # - **Idempotent.** A font whose `path` already exists with the
    #   manifest's SHA256 is `:skipped`. A file with a mismatched hash
    #   is re-downloaded.
    # - **Hashed.** On download, SHA256 is computed. If the manifest
    #   has a hash, mismatch raises {Ucode::FontChecksumError}. If the
    #   manifest hash is null, the computed hash is written back to the
    #   YAML at the end of the run (atomic write).
    # - **License-checked.** Non-OFL entries require `allow_proprietary:
    #   true`; otherwise the result is `:failed` with {Ucode::FontLicenseError}.
    # - **Extracted.** `extract: true` entries unzip to a temp dir and
    #   only `extract_member` is moved into place.
    # - **Local-only.** `url: null` entries are never fetched over the
    #   network; the result is `:local` whether or not the file is yet
    #   present (with a `note` instructing placement when missing).
    #
    # A single font failure does not abort the run. The fetcher returns
    # an array of {FontFetcher::Result}; the caller decides how to
    # report failures.
    class SpecialistFontFetcher
      # @param manifest_path [String, Pathname] path to the YAML manifest.
      #   The file is rewritten in place when SHA256 hashes are populated.
      # @param fonts_root [String, Pathname] root for relative `path:`
      #   values. Defaults to the project root (current working dir).
      #   Absolute paths in the manifest bypass this.
      # @param allow_proprietary [Boolean] when true, non-OFL entries
      #   are fetched; when false, they produce a `:failed` result.
      # @param dry_run [Boolean] when true, no network or disk writes;
      #   each font that would have been fetched yields a `:planned`
      #   result.
      # @param http [Module, nil] injectable HTTP module responding to
      #   `.get(url, dest:)`. Defaults to {Fetch::Http}. Real-in-class
      #   test stubs can substitute a module that writes local fixture
      #   bytes; never use a double.
      def initialize(manifest_path:, fonts_root: ".", allow_proprietary: false,
                     dry_run: false, http: Fetch::Http)
        @manifest_path = Pathname.new(manifest_path)
        @fonts_root = Pathname.new(fonts_root)
        @allow_proprietary = allow_proprietary
        @dry_run = dry_run
        @http = http
        @computed_hashes = {}
      end

      # @param only_label [String, nil] restrict the run to a single
      #   manifest entry by label. nil (default) = run all entries.
      # @return [Array<FontFetcher::Result>] one per manifest entry
      #   actually visited, in declared order.
      def call(only_label: nil)
        manifest = load_manifest
        return [unknown_label_result(only_label)] if only_label && manifest.find_by_label(only_label).nil?

        entries = only_label ? [manifest.find_by_label(only_label)] : manifest.fonts
        results = entries.map { |font| fetch_one(font) }
        persist_computed_hashes(manifest) unless @dry_run
        results
      end

      private

      def load_manifest
        Ucode::Models::SpecialistFontManifest.from_yaml(@manifest_path.read)
      end

      def unknown_label_result(label)
        FontFetcher::Result.new(
          status: :failed,
          label: label,
          error: Ucode::LookupError.new(
            "label #{label.inspect} is not in #{@manifest_path}",
            context: { manifest: @manifest_path.to_s, requested_label: label },
          ),
        )
      end

      def fetch_one(font)
        if font.local_only?
          local_result(font)
        elsif @dry_run
          dry_run_result(font)
        else
          download_result(font)
        end
      end

      def local_result(font)
        resolved = expand_local_path(font.path)
        existing = resolved.find(&:exist?)
        if existing
          FontFetcher::Result.new(
            status: :local,
            label: font.label,
            path: existing,
            size_bytes: existing.size,
            license: font.license,
            provenance: font.provenance,
          )
        else
          FontFetcher::Result.new(
            status: :local,
            label: font.label,
            path: font.path,
            license: font.license,
            provenance: font.provenance,
            note: "place at #{font.path}",
          )
        end
      end

      def dry_run_result(font)
        existing = destination_path(font)
        if existing&.exist? && hash_matches?(existing, font)
          FontFetcher::Result.new(status: :skipped, label: font.label,
                                  path: existing, license: font.license,
                                  provenance: font.provenance)
        else
          FontFetcher::Result.new(status: :planned, label: font.label,
                                  path: destination_for_display(font),
                                  license: font.license,
                                  provenance: font.provenance)
        end
      end

      def download_result(font)
        unless font.ofl? || @allow_proprietary
          return FontFetcher::Result.new(
            status: :failed, label: font.label, license: font.license,
            error: Ucode::FontLicenseError.new(
              "#{font.label} license=#{font.license.inspect} requires --allow-proprietary",
              context: { label: font.label, license: font.license },
            ),
          )
        end

        dest = destination_path(font)
        return skipped_result(font, dest) if dest.exist? && hash_matches?(dest, font)

        download_and_install(font, dest)
      rescue Ucode::Error => e
        FontFetcher::Result.new(status: :failed, label: font.label,
                                license: font.license, error: e)
      rescue StandardError => e
        FontFetcher::Result.new(status: :failed, label: font.label,
                                license: font.license,
                                error: Ucode::FetchError.new(
                                  "#{font.label} fetch failed: #{e.class}: #{e.message}",
                                  context: { label: font.label, original: e.class.name },
                                ))
      end

      def skipped_result(font, dest)
        FontFetcher::Result.new(status: :skipped, label: font.label,
                                path: dest, size_bytes: dest.size,
                                license: font.license, provenance: font.provenance)
      end

      def download_and_install(font, dest)
        dest.dirname.mkpath
        if font.extract?
          download_and_extract(font, dest)
        else
          @http.get(font.url, dest: dest.to_s)
        end
        verify_or_record_hash(font, dest)
        FontFetcher::Result.new(status: :downloaded, label: font.label,
                                path: dest, size_bytes: dest.size,
                                license: font.license, provenance: font.provenance)
      end

      def download_and_extract(font, dest)
        Dir.mktmpdir("ucode-font-") do |tmp|
          zip_path = File.join(tmp, "download.zip")
          @http.get(font.url, dest: zip_path)
          extract_member(zip_path, font.extract_member, dest)
        end
      end

      def extract_member(zip_path, member_name, dest)
        Zip::File.open(zip_path) do |zip|
          entry = zip.find_entry(member_name) ||
            zip.find { |e| !e.directory? && e.name.end_with?("/#{member_name}", member_name) }
          unless entry
            raise Ucode::FontExtractMemberMissingError.new(
              "zip #{File.basename(zip_path)} does not contain #{member_name.inspect}",
              context: { zip: zip_path, expected_member: member_name },
            )
          end

          entry.get_input_stream do |input|
            File.open(dest, "wb") { |out| IO.copy_stream(input, out) }
          end
        end
      end

      def verify_or_record_hash(font, dest)
        actual = sha256_of(dest)
        if font.hash_known?
          unless actual.casecmp(font.sha256).zero?
            raise Ucode::FontChecksumError.new(
              "#{font.label} SHA256 mismatch: expected #{font.sha256}, got #{actual}",
              context: { label: font.label, expected: font.sha256, actual: actual },
            )
          end
        else
          @computed_hashes[font.label] = actual
        end
      end

      def hash_matches?(path, font)
        return true unless font.hash_known?

        sha256_of(path).casecmp?(font.sha256)
      end

      def sha256_of(path)
        Digest::SHA256.file(path.to_s).hexdigest
      end

      def destination_path(font)
        return nil if font.path.nil? || font.path.empty?

        path = expand_path_for_display(font.path)
        return path if path.absolute?

        @fonts_root.join(path)
      end

      def destination_for_display(font)
        destination_path(font) || font.path
      end

      def expand_path_for_display(raw)
        return Pathname.new(raw) unless raw.start_with?("~")

        Pathname.new(File.expand_path(raw))
      end

      def expand_local_path(raw)
        expanded = File.expand_path(raw)
        Dir.glob(expanded).map { |p| Pathname.new(p) }
      end

      def persist_computed_hashes(manifest)
        return if @computed_hashes.empty?

        manifest.fonts.each do |font|
          next unless @computed_hashes.key?(font.label)

          font.sha256 = @computed_hashes[font.label]
        end
        atomic_write(@manifest_path, manifest.to_yaml)
      end

      def atomic_write(path, content)
        tmp = path.dirname.join("#{path.basename}.tmp")
        tmp.write(content)
        File.rename(tmp.to_s, path.to_s)
      end
    end
  end
end
