# frozen_string_literal: true

module Ucode
  module Fetch
    module FontFetcher
      STATUSES = %i[downloaded skipped failed local planned].freeze
      private_constant :STATUSES

      # Typed outcome of fetching one font. The fetcher never raises
      # for a single font failure; it returns a `:failed` Result so
      # the aggregate run can keep going and report every problem.
      #
      # Statuses:
      # - `:downloaded` — fetched this run; bytes are on disk at `path`.
      # - `:skipped`    — already present with matching SHA256 (or dry-run).
      # - `:failed`     — license refused, checksum mismatch, network
      #                   error, or zip extraction error. `error` is set.
      # - `:local`      — `url: null`; the user supplies the file. May
      #                   or may not be present yet (see `note`).
      # - `:planned`    — dry-run only; this entry would have been fetched.
      Result = Struct.new(:status, :label, :path, :size_bytes, :license,
                          :provenance, :error, :note, keyword_init: true) do
        def initialize(status:, **opts)
          unless STATUSES.include?(status)
            raise ArgumentError, "unknown FontFetcher::Result status: #{status.inspect}"
          end

          super
        end

        def downloaded? = status == :downloaded
        def skipped? = status == :skipped
        def failed? = status == :failed
        def local? = status == :local
        def planned? = status == :planned
      end
    end
  end
end
