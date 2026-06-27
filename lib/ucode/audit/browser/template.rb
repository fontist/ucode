# frozen_string_literal: true

require "erb"
require "pathname"

require "ucode/audit/browser"

module Ucode
  module Audit
    module Browser
      # Minimal ERB wrapper for the browser templates.
      #
      # Reads an `.erb` template plus its sibling `.css` and `.js`
      # assets from {Browser::TEMPLATE_DIR}, renders them with the
      # supplied binding, and returns a complete HTML document.
      #
      # Templates are plain ERB — no partials, no layouts, no helpers
      # beyond what the binding provides. The CSS/JS assets are
      # inlined into the rendered HTML so the page is fully
      # self-contained (no external requests).
      class Template
        # @param name [String, Symbol] template name without extension
        #   (e.g. `:face`, `:library`)
        def initialize(name)
          @name = name
        end

        # @param locals [Hash{Symbol=>Object}] variables exposed in the
        #   template binding
        # @return [String] rendered HTML
        def render(locals = {})
          erb = ERB.new(read("#{@name}.html.erb"), trim_mode: "-")
          erb.result_with_hash(locals.merge(
                                 _css: read("#{@name}.css"),
                                 _js: read("#{@name}.js"),
                               ))
        end

        private

        def read(filename)
          Browser.const_get(:TEMPLATE_DIR).join(filename).read
        end
      end
    end
  end
end
