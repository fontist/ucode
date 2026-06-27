# frozen_string_literal: true

require "lutaml/model"

module Ucode
  module Models
    module Audit
      # Structural diff between two {AuditReport}s.
      #
      # `left_source`/`right_source` are the original source_file paths
      # (or report paths) so a consumer reading the diff alone can locate
      # the inputs.
      #
      # `field_changes` lists scalar fields whose values changed.
      # `codepoints` is the cmap delta ({CodepointSetDiff}).
      # The remaining fields are array set-diffs over the report's
      # structural inventory: OpenType features, scripts, UCD blocks.
      # Each is split into `added_*` (in right, not left) and
      # `removed_*` (in left, not right).
      #
      # ucode delta vs fontisan: drops `added_languages` / `removed_languages`
      # (CLDR is out of scope).
      class AuditDiff < Lutaml::Model::Serializable
        attribute :left_source,      :string
        attribute :right_source,     :string
        attribute :field_changes,    FieldChange, collection: true, default: -> { [] }
        attribute :codepoints,       CodepointSetDiff
        attribute :added_features,   :string, collection: true, default: -> { [] }
        attribute :removed_features, :string, collection: true, default: -> { [] }
        attribute :added_scripts,    :string, collection: true, default: -> { [] }
        attribute :removed_scripts,  :string, collection: true, default: -> { [] }
        attribute :added_blocks,     :string, collection: true, default: -> { [] }
        attribute :removed_blocks,   :string, collection: true, default: -> { [] }

        key_value do
          map "left_source",      to: :left_source
          map "right_source",     to: :right_source
          map "field_changes",    to: :field_changes
          map "codepoints",       to: :codepoints
          map "added_features",   to: :added_features
          map "removed_features", to: :removed_features
          map "added_scripts",    to: :added_scripts
          map "removed_scripts",  to: :removed_scripts
          map "added_blocks",     to: :added_blocks
          map "removed_blocks",   to: :removed_blocks
        end

        # True when nothing differs. Useful for the text formatter.
        #
        # @return [Boolean]
        def empty?
          added_codepoints.zero? && removed_codepoints.zero? &&
            all_collections_empty?(
              field_changes,
              added_features, removed_features,
              added_scripts, removed_scripts,
              added_blocks, removed_blocks
            )
        end

        def added_codepoints
          codepoints&.added_count || 0
        end

        def removed_codepoints
          codepoints&.removed_count || 0
        end

        private

        def all_collections_empty?(*collections)
          collections.all? { |c| c.nil? || c.empty? }
        end
      end
    end
  end
end
