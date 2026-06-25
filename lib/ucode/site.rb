# frozen_string_literal: true

module Ucode
  # Site — Vitepress app generator under site/.
  #
  # Generates ~363 static pages (17 planes + ~346 blocks). Character
  # detail is a single dynamic route that fetches JSON per codepoint.
  module Site
    autoload :Generator, "ucode/site/generator"
    autoload :ConfigEmitter, "ucode/site/config_emitter"
    autoload :SearchIndex, "ucode/site/search_index"
  end
end
