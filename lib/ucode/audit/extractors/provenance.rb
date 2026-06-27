# frozen_string_literal: true

require "digest"
require "time"

module Ucode
  module Audit
    module Extractors
      # Provenance fields: who generated this report, when, from what.
      #
      # Returned fields:
      #   generated_at, ucode_version, source_file, source_sha256,
      #   source_format, font_index, num_fonts_in_source
      #
      # ucode delta vs fontisan: `fontisan_version` is renamed to
      # `ucode_version` and reads from `Ucode::VERSION`.
      class Provenance < Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}]
        def extract(context)
          {
            generated_at: Time.now.utc.iso8601,
            ucode_version: Ucode::VERSION,
            source_file: File.expand_path(context.font_path),
            source_sha256: Digest::SHA256.file(context.font_path).hexdigest,
            source_format: context.source_format,
            font_index: context.font_index,
            num_fonts_in_source: context.num_fonts_in_source,
          }
        end
      end
    end
  end
end
