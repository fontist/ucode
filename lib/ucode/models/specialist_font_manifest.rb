# frozen_string_literal: true

require "lutaml/model"

require "ucode/models/specialist_font"

module Ucode
  module Models
    # Typed view over `config/specialist_fonts.yml`. Carries the full
    # list of {SpecialistFont} entries; provides lookup by label so
    # the fetcher can honor `--label Lentariso` without scanning the
    # array itself.
    #
    # The manifest is pure data — it does not know the path it was
    # loaded from. Persistence of computed SHA256 hashes back to disk
    # is the responsibility of {Ucode::Fetch::SpecialistFontFetcher},
    # which owns the file path and writes atomically after a run.
    class SpecialistFontManifest < Lutaml::Model::Serializable
      attribute :fonts, SpecialistFont, collection: true

      key_value do
        map "fonts", to: :fonts
      end

      # @param label [String] exact label match
      # @return [SpecialistFont, nil]
      def find_by_label(label)
        fonts.find { |font| font.label == label }
      end

      # @return [Array<String>] labels of every entry, in declared order
      def labels
        fonts.map(&:label)
      end

      # @param label [String]
      # @return [SpecialistFontManifest] a new manifest containing only
      #   the matching font. Returns self unchanged if the label is
      #   unknown (the fetcher reports it as a separate failure).
      def only(label)
        match = find_by_label(label)
        return self if match.nil?

        self.class.new(fonts: [match])
      end
    end
  end
end
