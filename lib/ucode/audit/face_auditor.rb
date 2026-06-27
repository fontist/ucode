# frozen_string_literal: true

require "fontisan"

module Ucode
  module Audit
    # Per-face orchestrator: takes a font path, runs every Extractor in
    # the {Registry}, and assembles a single {Models::Audit::AuditReport}.
    #
    # For standalone fonts (TTF/OTF/WOFF/WOFF2) #call returns one
    # AuditReport. For collections (TTC/OTC/dfont) it returns
    # Array<AuditReport> — one per face, in source order.
    #
    # Extracted as its own class so {LibraryAuditor} (per-file iteration)
    # and the future CLI AuditCommand (single face) share one orchestration
    # path. Neither caller enumerates extractors directly — they go
    # through this class and the {Registry}.
    class FaceAuditor
      # @param font_path [String, Pathname] font file to audit
      # @param options [Hash{Symbol=>Object}] forwarded to {Context}
      #   (ucd_version, all_codepoints, with_glyphs, audit_brief, …)
      # @param mode [Symbol] :full (default) or :brief
      # @param font_index [Integer, nil] when set and the source is a
      #   collection (TTC/OTC/dfong), audit only that face index and
      #   return a single AuditReport. Ignored for single-face sources.
      def initialize(font_path, options: {}, mode: :full, font_index: nil)
        @font_path = font_path.to_s
        @options = options
        @mode = mode
        @font_index = font_index
      end

      # @return [Models::Audit::AuditReport, Array<Models::Audit::AuditReport>]
      def call
        if Fontisan::FontLoader.collection?(@font_path)
          audit_collection
        else
          audit_face(load_face(0), 0, 1)
        end
      end

      private

      def audit_collection
        collection = Fontisan::FontLoader.load_collection(@font_path)
        num = collection.num_fonts
        indices = @font_index ? [@font_index] : (0...num).to_a
        results = indices.map do |index|
          font = Fontisan::FontLoader.load(@font_path, font_index: index)
          audit_face(font, index, num)
        end
        @font_index ? results.first : results
      end

      def audit_face(font, font_index, num_fonts_in_source)
        context = Context.new(
          font: font,
          font_path: @font_path,
          font_index: font_index,
          num_fonts_in_source: num_fonts_in_source,
          options: @options,
        )

        fields = {}
        Registry.each(mode: @mode) do |extractor_class|
          fields.merge!(extractor_class.new.extract(context))
        end

        fields[:warning] = context.baseline.warning

        Models::Audit::AuditReport.new(**fields)
      end

      def load_face(_index)
        Fontisan::FontLoader.load(@font_path)
      end
    end
  end
end
