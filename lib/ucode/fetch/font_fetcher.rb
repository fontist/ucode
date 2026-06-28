# frozen_string_literal: true

module Ucode
  module Fetch
    # Namespace for font-pipeline fetchers. Owns the shared {Result}
    # value object; concrete fetchers live as peer classes in
    # {Ucode::Fetch} (e.g. {SpecialistFontFetcher}).
    #
    # Open/closed: adding a new font source = adding a new fetcher
    # class that produces {Result} instances. The protocol is the
    # `Result`, not an abstract base class.
    module FontFetcher
      autoload :Result, "ucode/fetch/font_fetcher/result"
    end
  end
end
