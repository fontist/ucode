# frozen_string_literal: true

module Ucode
  module Audit
    module Extractors
      # Abstract extractor interface. Subclasses implement `#extract`.
      #
      # An extractor reads from a {Context} and returns a hash of fields
      # suitable for `Models::Audit::AuditReport.new(**fields)`.
      # Returning an empty hash is valid (no-op).
      class Base
        # @param context [Ucode::Audit::Context]
        # @return [Hash{Symbol=>Object}] fields merged into the AuditReport
        def extract(context)
          raise NotImplementedError,
                "#{self.class} must implement #extract"
        end
      end
    end
  end
end
