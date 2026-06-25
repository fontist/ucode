# frozen_string_literal: true

require "zip"

module Ucode
  module Fetch
    # Downloads UCD.zip from unicode.org and unpacks it into
    # `Cache.ucd_dir(version)`.
    module UcdZip
      URL_SUFFIX = "/ucd/UCD.zip"
      private_constant :URL_SUFFIX

      class << self
        # @param version [String] e.g. "17.0.0"
        # @param force [Boolean] re-download even if cached.
        # @return [Pathname] the ucd_dir after extraction.
        def call(version, force: false)
          Cache.ensure_version_dir!(version)
          target_dir = Cache.ucd_dir(version)

          marker = target_dir.join("UnicodeData.txt")
          return target_dir if marker.exist? && !force

          url = "#{Ucode.configuration.ucd_base_url}/#{version}#{URL_SUFFIX}"
          zip_path = Cache.version_dir(version).join("ucd.zip")
          Http.get(url, dest: zip_path)
          extract(zip_path, target_dir)
          zip_path.delete if zip_path.exist?
          target_dir
        end

        private

        def extract(zip_path, target_dir)
          target_dir.mkpath
          Zip::File.open(zip_path.to_s) do |zip|
            zip.each do |entry|
              next if entry.directory?
              next if entry.name.start_with?("__MACOSX/") || entry.name.include?("/._")

              relative = entry.name.sub(%r{^/+}, "")
              dest = target_dir.join(relative)
              dest.dirname.mkpath
              next if dest.exist?

              entry.get_input_stream do |input|
                File.open(dest, "wb") do |output|
                  IO.copy_stream(input, output)
                end
              end
            end
          end
        end
      end
    end
  end
end