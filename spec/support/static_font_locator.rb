# frozen_string_literal: true

require "pathname"

# Real in-memory implementation of the FontLocator protocol used by
# {Ucode::Glyphs::UniversalSet::PreBuildCheck}. Used in specs to test
# the check without going through fontist's formula index. Not a
# double — this is a real class that satisfies the same
# `#locate(spec, install:) => LocateResult | nil` contract as
# {Ucode::Glyphs::RealFonts::FontLocator}.
class StaticFontLocator
  LocateResult = Struct.new(:name, :path, :via, keyword_init: true)

  # @param available [Array<String>, Set<String>] labels this locator
  #   claims to find. Anything else returns nil.
  def initialize(available:)
    @available = available.to_set
  end

  # @param spec [String] label or `name=path` form (we only look at
  #   the name half here — the real FontLocator handles both shapes).
  # @param install [Boolean] accepted to match the FontLocator protocol;
  #   ignored — static locator never installs.
  # @return [LocateResult, nil]
  def locate(spec, install: true) # rubocop:disable Lint/UnusedMethodArgument
    name = spec.include?("=") ? spec.split("=", 2).first : spec
    return nil unless @available.include?(name)

    LocateResult.new(name: name, path: Pathname.new("/tmp/#{name}"), via: :static)
  end
end
