# frozen_string_literal: true

module Ucode
  module Audit
    module Release
      # Value object pairing a formula slug with the library-wide audit
      # summary produced by running {Audit::LibraryAuditor} on that
      # formula's font directory.
      #
      # Used as the input unit to {Emitter}: callers pass a list of
      # these and the emitter walks each one's `summary.per_face_reports`
      # to emit the per-face audit subtrees.
      #
      # The slug MUST be caller-sanitized (fontist formula slug form:
      # lowercase, hyphen-separated, filesystem-safe). The emitter does
      # not re-sanitize — it uses the slug verbatim as the directory
      # name under `<release_root>/audit/`.
      FormulaAudits = Struct.new(:slug, :summary, keyword_init: true) do
        # Sanity check at construction time so a malformed slug fails
        # fast at the call site instead of producing a broken tree.
        def initialize(slug:, summary:)
          raise ArgumentError, "slug must not be empty" if slug.to_s.strip.empty?
          raise ArgumentError, "slug contains path separators: #{slug.inspect}" if slug[%r{/}]
          raise ArgumentError, "summary is required" unless summary

          slug = slug.to_s
          raise ArgumentError, "slug is not filesystem-safe: #{slug.inspect}" unless safe_slug?(slug)

          super(slug: slug, summary: summary)
        end

        # @return [Integer] number of face reports in the summary
        def faces_total
          summary.total_faces
        end

        # @return [Enumerable<Models::Audit::AuditReport>]
        def face_reports
          summary.per_face_reports
        end

        private

        def safe_slug?(slug)
          slug.match?(/\A[A-Za-z0-9._-]+\z/)
        end
      end
    end
  end
end
