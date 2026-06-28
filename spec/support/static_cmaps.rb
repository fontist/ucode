# frozen_string_literal: true

# Real in-memory implementation of the cmaps protocol used by
# {Ucode::Glyphs::SourceConfig::CoverageAssertion}. Used in specs to
# test the walker without loading real fonts. Not a double — this is
# a real class that satisfies the same `#covers?(source, codepoint)`
# contract as {Ucode::Glyphs::RealFonts::CmapCache}.
class StaticCmaps
  def initialize(mapping = {})
    @mapping = mapping.transform_values do |cps|
      cps.is_a?(Set) ? cps : cps.to_set
    end
  end

  # @param source [Ucode::Models::GlyphSource]
  # @param codepoint [Integer]
  # @return [Boolean]
  def covers?(source, codepoint)
    set = @mapping[source.label]
    !set.nil? && set.include?(codepoint)
  end
end
